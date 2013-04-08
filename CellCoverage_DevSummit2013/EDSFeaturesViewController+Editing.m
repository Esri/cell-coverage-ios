/*
 Copyright 2013 Esri
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "EDSFeaturesViewController+Editing.h"

//Category of EDSFeaturesViewController for editing.  Based heavily on the following sample:
//
//  http://www.arcgis.com/home/item.html?id=2ddb261648074b9aabb22240b6975918
//
@implementation EDSFeaturesViewController (Editing)

-(void)sketchComplete{
    self.popupVC.doneButton = self.clearButton;
    self.mapView.touchDelegate = self.previousMapTouchDelegate;
    
    //unsubscribe to notifications
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AGSSketchGraphicsLayerGeometryDidChangeNotification object:nil];
}

#pragma mark -  AGSPopupsContainerDelegate methods

- (AGSGeometry *)popupsContainer:(id) popupsContainer wantsNewMutableGeometryForPopup:(AGSPopup *) popup {
    //Return an empty mutable geometry of the type that our feature layer uses
    return AGSMutableGeometryFromType( ((AGSFeatureLayer*)popup.graphic.layer).geometryType, self.mapView.spatialReference);
}

- (void)popupsContainer:(id) popupsContainer readyToEditGraphicGeometry:(AGSGeometry *) geometry forPopup:(AGSPopup *) popup{

    //subscribe to sketch layer geometry changed notification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(respondToGeomChanged:) name:AGSSketchGraphicsLayerGeometryDidChangeNotification object:nil];

    //Prepare the current view controller for sketch mode
    //save previous touch delegate
    self.previousMapTouchDelegate = self.mapView.touchDelegate;
    self.mapView.touchDelegate = self.sketchLayer; //activate the sketch layer
    self.mapView.callout.hidden = YES;
    
    //Assign the sketch layer the geometry that is being passed to us for
    //the active popup's graphic. This is the starting point of the sketch
    self.sketchLayer.geometry = geometry;
        
    //zoom to the existing feature's geometry
    AGSEnvelope* env = nil;
    AGSGeometryType geoType = AGSGeometryTypeForGeometry(self.sketchLayer.geometry);
    if(geoType == AGSGeometryTypePolygon){
        env = ((AGSPolygon*)self.sketchLayer.geometry).envelope;
    }else if(geoType == AGSGeometryTypePolyline){
        env = ((AGSPolyline*)self.sketchLayer.geometry).envelope ;
    }
    
    if(env!=nil){
        AGSMutableEnvelope* mutableEnv  = [env mutableCopy];
        [mutableEnv expandByFactor:1.4];
        [self.mapView zoomToEnvelope:mutableEnv animated:YES];
    }
    
    //replace the button in the navigation bar to allow a user to
    //indicate that the sketch is done
	self.popupVC.doneButton = self.sketchCompleteButton;
	self.navigationItem.rightBarButtonItem = self.sketchCompleteButton;
    self.sketchCompleteButton.enabled = NO;
}

- (void)popupsContainer:(id<AGSPopupsContainer>) popupsContainer wantsToDeleteGraphicForPopup:(AGSPopup *) popup {
    //Call method on feature layer to delete the feature
    NSNumber* number = [NSNumber numberWithInteger: [self.activeFeatureLayer objectIdForFeature:popup.graphic]];
    NSArray* oids = [NSArray arrayWithObject: number ];
    [self.activeFeatureLayer deleteFeaturesWithObjectIds:oids ];
    self.loadingView = [LoadingView loadingViewInView:self.popupVC.view withText:@"Deleting feature..."];
    
}

-(void)popupsContainer:(id<AGSPopupsContainer>)popupsContainer didFinishEditingGraphicForPopup:(AGSPopup*)popup{
	// simplify the geometry, this will take care of self intersecting polygons and
	popup.graphic.geometry = [[AGSGeometryEngine defaultGeometryEngine]simplifyGeometry:popup.graphic.geometry];
    //normalize the geometry, this will take care of geometries that extend beyone the dateline
    //(ifwraparound was enabled on the map)
	popup.graphic.geometry = [[AGSGeometryEngine defaultGeometryEngine]normalizeCentralMeridianOfGeometry:popup.graphic.geometry];
	
    
	int oid = [self.activeFeatureLayer objectIdForFeature:popup.graphic];
	
	if (oid > 0){
		//feature has a valid objectid, this means it exists on the server
        //and we simply update the exisiting feature
		[self.activeFeatureLayer updateFeatures:[NSArray arrayWithObject:popup.graphic]];
	} else {
		//objectid does not exist, this means we need to add it as a new feature
		[self.activeFeatureLayer addFeatures:[NSArray arrayWithObject:popup.graphic]];
	}
    
    //Tell the user edits are being saved int the background
    self.loadingView = [LoadingView loadingViewInView:self.popupVC.view withText:@"Saving feature details..."];
    
    //we will wait to post attachments till when the updates succeed
}

- (void)popupsContainerDidFinishViewingPopups:(id) popupsContainer {
    //dismiss the popups view controller
    
    NSLog(@"popupsContainerDidFinishViewingPopups");    
}

- (void)popupsContainer:(id) popupsContainer didCancelEditingGraphicForPopup:(AGSPopup *) popup {

    //if we had begun adding a new feature, remove it from the layer because the user hit cancel.
    if(self.createdFeature != nil){
        [self.activeFeatureLayer removeGraphic:self.createdFeature];
        self.createdFeature = nil;
    }
    
    //reset any sketch related changes we made to our main view controller
    [self.sketchLayer clear];
    self.mapView.touchDelegate = self.previousMapTouchDelegate;
}

#pragma mark -

- (void) warnUserOfErrorWithMessage:(NSString*) message {
    //Display an alert to the user
    self.alertView = [[UIAlertView alloc] initWithTitle:@"Error" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
    [self.alertView show];
    
    //Restart editing the popup so that the user can attempt to save again
    [self.popupVC startEditingCurrentPopup];
}

#pragma mark - AGSFeatureLayerEditingDelegate methods

-(void)featureLayer:(AGSFeatureLayer *)featureLayer operation:(NSOperation *)op didFeatureEditsWithResults:(AGSFeatureLayerEditResults *)editResults{
    
    //Remove the activity indicator
    [self.loadingView removeView];
    
    //We will assume we have to update the attachments unless
    //1) We were adding a feature and it failed
    //2) We were updating a feature and it failed
    //3) We were deleting a feature
    BOOL _updateAttachments = YES;
    
    if([editResults.addResults count]>0){
        //we were adding a new feature
        AGSEditResult* result = (AGSEditResult*)[editResults.addResults objectAtIndex:0];
        if(!result.success){
            //Add operation failed. We will not update attachments
            _updateAttachments = NO;
            //Inform user
            [self warnUserOfErrorWithMessage:@"Could not add feature. Please try again"];
        }
        
    }else if([editResults.updateResults count]>0){
        //we were updating a feature
        AGSEditResult* result = (AGSEditResult*)[editResults.updateResults objectAtIndex:0];
        if(!result.success){
            //Update operation failed. We will not update attachments
            _updateAttachments = NO;
            //Inform user
            [self warnUserOfErrorWithMessage:@"Could not update feature. Please try again"];
        }
    }else if([editResults.deleteResults count]>0){
        //we were deleting a feature
        _updateAttachments = NO;
        AGSEditResult* result = (AGSEditResult*)[editResults.deleteResults objectAtIndex:0];
        if(!result.success){
            //Delete operation failed. Inform user
            [self warnUserOfErrorWithMessage:@"Could not delete feature. Please try again"];
        }else{
            //Delete operation succeeded
            //Dismiss the popup view controller and hide the callout which may have been shown for
            //the deleted feature.
            self.mapView.callout.hidden = YES;
            self.popupVC = nil;
        }
    }
    
    //if edits pertaining to the feature were successful...
    if (_updateAttachments){
        
        [self.sketchLayer clear];
        
        //...we post edits to the attachments
		AGSAttachmentManager *attMgr = [featureLayer attachmentManagerForFeature:self.popupVC.currentPopup.graphic];
		attMgr.delegate = self;
        
        if([attMgr hasLocalEdits]){
			[attMgr postLocalEditsToServer];
            self.loadingView = [LoadingView loadingViewInView:self.popupVC.view withText:@"Saving feature attachments..."];
        }
	}
}

-(void)featureLayer:(AGSFeatureLayer *)featureLayer operation:(NSOperation *)op didFailFeatureEditsWithError:(NSError *)error{
    NSLog(@"Could not commit edits because: %@", [error localizedDescription]);
    
    [self.loadingView removeView];
    [self warnUserOfErrorWithMessage:@"Could not save edits. Please try again"];
}

#pragma mark - AGSSketchGraphicsLayer notifications

- (void)respondToGeomChanged: (NSNotification*) notification {
    
    //Check if the sketch geometry is valid to decide whether to enable
    //the sketchCompleteButton
    if([self.sketchLayer.geometry isValid] && ![self.sketchLayer.geometry isEmpty]) {
        self.sketchCompleteButton.enabled   = YES;
    }
}

@end

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

#import "EDSViewController+Analysis.h"
#import "EDSViewController.h"
#import "EDSRouteViewController.h"

//Category of EDSViewController for analysis.  Uses code and concepts from the following sample:
//
//  http://www.arcgis.com/home/item.html?id=759c80ef60bb4ef993737a3d41a8d9f7
//
@implementation EDSViewController (Analysis)

-(void)analyzeWithGraphic:(AGSGraphic *)graphic {
    
    //
    //query all cell coverage features that intersect with our route.
    //  use the coverageFeatureLayer for this.
    
	AGSQuery *query = [AGSQuery query];
	query.outFields = [NSArray arrayWithObjects:@"*", nil];
    query.geometry = graphic.geometry.envelope;
    query.spatialRelationship = AGSSpatialRelationshipIntersects;
    query.outSpatialReference = self.mapView.spatialReference;

    self.coverageFeatureLayer.queryDelegate = self;
    self.featureLayerQueryOperation = [self.coverageFeatureLayer queryFeatures:query];
    
    self.routeLoadingView = [LoadingView loadingViewInView:self.routeVC.view withText:@"Analyzing route..."];
}

#pragma mark AGSFeatureLayerQueryTaskDelegate

/** Tells the delegate that @c AGSFeatureLayer completed the query successfully
 with the provided results.
 @param featureLayer The feature layer which performed the query.
 @param op The operation that performed the query.
 @param featureSet The feature set returned by executing query.
 @since 1.0
 */
- (void)featureLayer:(AGSFeatureLayer *)featureLayer operation:(NSOperation*)op didQueryFeaturesWithFeatureSet:(AGSFeatureSet *)featureSet {
    
    if (op == self.featureLayerQueryOperation) {
        [self signalStrengthAnalysis:featureSet];
    }

    [self.routeLoadingView removeView];
}

/**  Tells the delegate that @c AGSFeatureLayer encountered an error while
 performing the query.
 @param featureLayer The feature layer which performed the query.
 @param op The operation that performed the query.
 @param error Information about the error that was encountered.
 @since 1.0
 */
- (void)featureLayer:(AGSFeatureLayer *)featureLayer operation:(NSOperation*)op didFailQueryFeaturesWithError:(NSError *)error {
 
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Feature Layer Query Error"
                                                        message:[error localizedDescription]
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
    [alertView show];
   
    self.featureLayerQueryOperation = nil;

    [self.routeLoadingView removeView];
}

- (void)signalStrengthAnalysis:(AGSFeatureSet *)featureSet {
    
    //get feature, and load in into table
    self.featureSet = featureSet;
    
    AGSGeometryEngine *geometryEngine = [AGSGeometryEngine defaultGeometryEngine];
    
    //
    // We know that our cell coverage layer has only 1 feature, so grab it.
    // Then determine if the route graphic intersects with the coverage feature.
    //
    AGSGraphic *feature = [featureSet.features objectAtIndex:0];
    AGSGeometry *featureGeometry = feature.geometry;
    
    EDSSignalStrength previousSignalStrength = edsNoSignal;
    BOOL bFirst = YES;
    AGSGraphic *previousDirection = nil;
    for (AGSGraphic *direction in self.routeResult.directions.graphics) {
        
        EDSSignalStrength currentSignalStrength;
        BOOL bIntersects = [geometryEngine geometry:direction.geometry intersectsGeometry:featureGeometry];
        
        // if bIntersects = NO, then we're out of the coverage area and the signal strength is edsNoSignal
        // if bIntersects = YES, then the signal strenghth is strong, unless the previous or next signal strength
        //      was edsNoSignal, in which case the signal strength is weak.
        //
        // if we're the first one, assume the signal strength is tied to bIntersects,
        //      unless the next one is different, but that is handled in the next iteration
        //
        if (bFirst) {
            currentSignalStrength = bIntersects ? edsStrongSignal : edsNoSignal;
            bFirst = NO;
        }
        else {
            if (bIntersects) {
                //we intersected, so we're either strong (if the previous was not no signal)
                // or weak, if the previous was no signal
                if (previousSignalStrength == edsNoSignal) {
                    currentSignalStrength = edsWeakSignal;
                }
                else {
                    currentSignalStrength = edsStrongSignal;
                }
            }
            else {
                //doesn't intersect, no signal
                currentSignalStrength = edsNoSignal;
                
                //if previous has a strong signal, set it to weak
                if (previousSignalStrength == edsStrongSignal && previousDirection) {
                    [previousDirection setAttribute:[NSNumber numberWithInt:edsWeakSignal] forKey:@"Signal Strength"];
                }
            }
        }
        
        previousSignalStrength = currentSignalStrength;
        previousDirection = direction;
        
        [direction setAttribute:[NSNumber numberWithInt:currentSignalStrength] forKey:@"Signal Strength"];
    }
    
    //since we updated our route graphics, reset them into the routeVC
    self.routeVC.directionGraphics = self.routeResult.directions.graphics;
    
    //clear the query operation
    self.featureLayerQueryOperation = nil;
}

@end

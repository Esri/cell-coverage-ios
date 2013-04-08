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

#import "EDSViewController+Routing.h"
#import "EDSRouteViewController.h"
#import "EDSViewController+Analysis.h"
#import "EDSPlacesViewController.h"

//Category of EDSViewController for routing.  Based heavily on the following sample:
//
//  http://www.arcgis.com/home/item.html?id=e4fa8dafbe83475882ac9c0fd0a075c7
//
@implementation EDSViewController (Routing)

//
// perform the route task's solve operation
//
- (void)routeIt:(AGSGraphic *)destination {

	NSMutableArray *stops = [NSMutableArray array];
    
    //add start (current location)
    AGSPoint *currentLocation = self.mapView.locationDisplay.location.point;
    NSMutableDictionary *properties = [NSMutableDictionary dictionary];
    AGSStopGraphic *currentGraphic = [AGSStopGraphic graphicWithGeometry:currentLocation symbol:[AGSSimpleMarkerSymbol simpleMarkerSymbol] attributes:properties infoTemplateDelegate:nil];
    currentGraphic.sequence = 1;
    [stops addObject:currentGraphic];
    
    AGSStopGraphic *destinationGraphic = [AGSStopGraphic graphicWithGeometry:destination.geometry symbol:[AGSSimpleMarkerSymbol simpleMarkerSymbol] attributes:properties infoTemplateDelegate:nil];
    currentGraphic.sequence = 2;
    [stops addObject:destinationGraphic];
	
	// set the stop and polygon barriers on the parameters object
	if (stops.count > 0) {
		[self.routeTaskParams setStopsWithFeatures:stops];
	}
	
	// this generalizes the route graphics that are returned
	self.routeTaskParams.outputGeometryPrecision = 5.0;
	self.routeTaskParams.outputGeometryPrecisionUnits = AGSUnitsMeters;
    
    // return the graphic representing the entire route, generalized by the previous
    // 2 properties: outputGeometryPrecision and outputGeometryPrecisionUnits
	self.routeTaskParams.returnRouteGraphics = YES;
    
	// this returns turn-by-turn directions
	self.routeTaskParams.returnDirections = YES;
	
	// the next 3 lines will cause the task to find the
	// best route regardless of the stop input order
	self.routeTaskParams.findBestSequence = YES;
	self.routeTaskParams.preserveFirstStop = YES;
	self.routeTaskParams.preserveLastStop = NO;
	
	// since we used "findBestSequence" we need to
	// get the newly reordered stops
	self.routeTaskParams.returnStopGraphics = YES;
	
	// ensure the graphics are returned in our map's spatial reference
	self.routeTaskParams.outSpatialReference = self.mapView.spatialReference;
	
	// let's ignore invalid locations
	self.routeTaskParams.ignoreInvalidLocations = YES;
	
	// you can also set additional properties here that should
	// be considered during analysis.
	// See the conceptual help for Routing task.
	
	// execute the route task
	[self.routeTask solveWithParameters:self.routeTaskParams];
    
    self.placeLoadingView = [LoadingView loadingViewInView:self.placesVC.view withText:@"Planning route..."];
}

//
// create our route symbol
//
- (AGSCompositeSymbol*)routeSymbol {
	AGSCompositeSymbol *cs = [AGSCompositeSymbol compositeSymbol];
	
	AGSSimpleLineSymbol *sls1 = [AGSSimpleLineSymbol simpleLineSymbol];
	sls1.color = [UIColor yellowColor];
	sls1.style = AGSSimpleLineSymbolStyleSolid;
	sls1.width = 8;
	[cs addSymbol:sls1];
	
	AGSSimpleLineSymbol *sls2 = [AGSSimpleLineSymbol simpleLineSymbol];
	sls2.color = [UIColor blueColor];
	sls2.style = AGSSimpleLineSymbolStyleSolid;
	sls2.width = 4;
	[cs addSymbol:sls2];
	
	return cs;
}

#pragma mark - AGSRouteTaskDelegate

//
// we got the default parameters from the service
//
- (void)routeTask:(AGSRouteTask *)routeTask operation:(NSOperation *)op didRetrieveDefaultRouteTaskParameters:(AGSRouteTaskParameters *)routeParams {
	self.routeTaskParams = routeParams;
}

//
// an error was encountered while getting defaults
//
- (void)routeTask:(AGSRouteTask *)routeTask operation:(NSOperation *)op didFailToRetrieveDefaultRouteTaskParametersWithError:(NSError *)error {
	
	// Create an alert to let the user know the retrieval failed
	// Click Retry to attempt to retrieve the defaults again
	UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Error"
												 message:@"Failed to retrieve default route parameters"
												delegate:nil
									   cancelButtonTitle:@"Ok" otherButtonTitles:@"Retry",nil];
	[av show];
}


//
// route was solved
//
- (void)routeTask:(AGSRouteTask *)routeTask operation:(NSOperation *)op didSolveWithResult:(AGSRouteTaskResult *)routeTaskResult {
	
    //add routelayer to map if we need to
    if (![self.mapView.mapLayers containsObject:self.routeLayer]) {
        [self.mapView addMapLayer:self.routeLayer withName:@"Route"];
    }
    
    [self.routeLayer removeAllGraphics];
	
	// we know that we are only dealing with 1 route...
	self.routeResult = [routeTaskResult.routeResults lastObject];
	if (self.routeResult) {
		// symbolize the returned route graphic
		self.routeResult.routeGraphic.symbol = [self routeSymbol];
        
        // add the route graphic to the graphic's layer
		[self.routeLayer addGraphic:self.routeResult.routeGraphic];
	}
    
    //zoom to envelope
    AGSMutableEnvelope *envelope = [self.routeLayer.fullEnvelope mutableCopy];
    [envelope expandByFactor:1.3];
    [self.mapView zoomToEnvelope:envelope animated:YES];
    
    //set routeResult into the VC
    self.routeVC.directionGraphics = self.routeResult.directions.graphics;
    
    //select route button, which will show the routeVC
    self.selectedButton = self.routeButton;
    
    //start the analysis...
    [self analyzeWithGraphic:self.routeResult.routeGraphic];
    
    [self.placeLoadingView removeView];
}

//
// solve failed
//
- (void)routeTask:(AGSRouteTask *)routeTask operation:(NSOperation *)op didFailSolveWithError:(NSError *)error {
	
    [self.placeLoadingView removeView];

	// the solve route failed...
	// let the user know
	UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Solve Route Failed"
												 message:[NSString stringWithFormat:@"Error: %@", error]
												delegate:nil
									   cancelButtonTitle:@"Ok"
									   otherButtonTitles:nil];
	[av show];
}


@end

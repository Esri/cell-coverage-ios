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

#import "EDSViewController.h"
#import "EDSPlacesViewController.h"
#import "EDSRouteViewController.h"
#import "EDSLayersViewController.h"
#import "EDSFeaturesViewController.h"
#import "EDSFeaturesViewController.h"
#import "EDSViewController+Analysis.h"

#define kWebMapUrl @"http://geobrew.maps.arcgis.com/sharing/rest/content/items/3f96952cd3d043db862a7eb6db57f04d/data"
#define kRouteTaskUrl @"http://sampleserver3.arcgisonline.com/ArcGIS/rest/services/Network/USA/NAServer/Route"

@interface EDSViewController () <UIPopoverControllerDelegate, AGSMapViewLayerDelegate, AGSMapViewTouchDelegate, AGSWebMapDelegate, AGSLayerDelegate, AGSPopupsContainerDelegate, AGSMapViewCalloutDelegate>

@property (nonatomic, strong) IBOutlet UIView *panelView;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *panelViewXConstraint;

@property (nonatomic, strong) NSMutableArray *viewControllers;
@property (nonatomic, strong) UIViewController *currentVC;

@property (nonatomic, assign) CGFloat panelViewInitialXConstraintConstant;
@property (nonatomic, assign) CGFloat panelViewWidth;

@property (nonatomic, strong) AGSPopupsContainerViewController *popupVC;
@property (nonatomic, strong) AGSWebMap *webMap;

@property (nonatomic, strong) AGSGraphicsLayer *placesLayer;

-(IBAction)buttonPressed:(id)sender;
-(void)addViewControllers;
-(void)addViewControllerToPanel:(UIViewController *)viewController;

@end

@implementation EDSViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    //set mapVeiw delegates
    self.mapView.touchDelegate = self;
    self.mapView.calloutDelegate = self;
    self.mapView.layerDelegate = self;
    
    self.webMap = [AGSWebMap webMapWithURL:[NSURL URLWithString:kWebMapUrl] credential:nil];
    self.webMap.delegate = self;
    [self.webMap openIntoMapView:self.mapView];
    
    NSURL *routeTaskUrl = [NSURL URLWithString:kRouteTaskUrl];
	self.routeTask = [AGSRouteTask routeTaskWithURL:routeTaskUrl];

    // assign delegate to this view controller
	self.routeTask.delegate = (id<AGSRouteTaskDelegate>)self;
	
	// kick off asynchronous method to retrieve default parameters
	// for the route task
	[self.routeTask retrieveDefaultRouteTaskParameters];
    
    //turn off detail disclosure button on callout
    self.mapView.callout.accessoryButtonHidden = YES;
        
    //set up panel initial values
    self.panelViewInitialXConstraintConstant = self.panelViewXConstraint.constant;
    self.panelViewWidth = self.panelView.frame.size.width;

    //unselect all command buttons
    self.selectedButton = nil;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - AGSMapViewLayerDelegate

-(void)mapViewDidLoad:(AGSMapView *)mapView {
    
    //create necessary layers, but don't add them to map until we need them
    self.placesLayer = [AGSGraphicsLayer graphicsLayer];
    self.routeLayer = [AGSGraphicsLayer graphicsLayer];

    //add our view controllers to panel view
    [self addViewControllers];
    
    //
    //turn on the simulated gps
    //
    AGSSimulatedLocationDisplayDataSource *simulatedDS = [[AGSSimulatedLocationDisplayDataSource alloc]init];
    AGSLocation *location = [[AGSLocation alloc] init];
    location.point = [AGSPoint pointWithX:-13531351.087449 y:4319196.96450 spatialReference:self.mapView.spatialReference];
    simulatedDS.locations = [NSArray arrayWithObject:location];
    self.mapView.locationDisplay.dataSource = simulatedDS;
    [self.mapView.locationDisplay startDataSource];
}

#pragma mark - AGSWebMapDelegate

- (void)webMapDidLoad:(AGSWebMap *)webMap {
    
    NSLog(@"Web Map Did Load.");
}

- (void)webMap:(AGSWebMap *)webMap didFailToLoadWithError:(NSError *)error {
    
    NSLog(@"Web Map Failed To Load.");
}

-(void)webMap:(AGSWebMap*)webMap didLoadLayer:(AGSLayer*)layer {

    //setup our fuel stations and coverage layers
    //Note that the layer names are defined in the web map; if those change,
    //this code needs to change as well.
    if ([layer.name isEqualToString:@"Fuel Stations"]) {
        self.fuelStationsFeatureLayer = (AGSFeatureLayer *)layer;
    }
    
    if ([layer.name isEqualToString:@"Cell Coverage"]) {
        self.coverageFeatureLayer = (AGSFeatureLayer *)layer;
    }
}

#pragma mark - AGSLayerDelegate

- (void)layerDidLoad:(AGSLayer *)layer {

    NSLog(@"Layer loaded.");
}

- (void)layer:(AGSLayer *)layer didFailToLoadWithError:(NSError *)error {
    
    NSLog(@"Layer Failed To Load.");
}

#pragma mark - AGSMapViewTouchDelegate

- (void)mapView:(AGSMapView *)mapView didClickAtPoint:(CGPoint)screen mapPoint:(AGSPoint *)mappoint graphics:(NSDictionary *)graphics {
    
    AGSPopupInfo *popupInfo = [self.webMap popupInfoForFeatureLayer:self.fuelStationsFeatureLayer];
    NSArray *graphicsForLayer = [graphics objectForKey:self.fuelStationsFeatureLayer.name];

    NSMutableArray *popups = [NSMutableArray array];
    for (AGSGraphic *graphic in graphicsForLayer) {
        //add popup
        AGSPopup *popup = [AGSPopup popupWithGraphic:graphic popupInfo:popupInfo];
        [popups addObject:popup];
    }
    
    if ([popups count] > 0) {
        //set popups into features VC
        
        //select features button if it's not already selected
        if (self.selectedButton != self.featuresButton) {
            self.selectedButton = self.featuresButton;
        }
    }

    //set the popups - if there are none, this will clear the list...
    self.featuresVC.popups = popups;
    self.featuresVC.activeFeatureLayer = self.fuelStationsFeatureLayer;
}

#pragma mark - AGSMapViewCalloutDelegate

- (BOOL)mapView:(AGSMapView *)mapView shouldShowCalloutForGraphic:(AGSGraphic *)graphic {
    
    //only show callouts for places layer; features will use featuresVC and popups
    return (graphic.layer == self.placesLayer);
}

#pragma mark - IBActions

-(IBAction)buttonPressed:(id)sender {

    //let the selectedButton setter (setSelectedButton) do all the work...
    self.selectedButton = (UIButton *)sender;
}

#pragma mark - Internal

-(void)setSelectedButton:(UIButton *)selectedButton {

    //send command changed message so individual view controllers can prepare for display if necessary
    [[NSNotificationCenter defaultCenter]postNotificationName:@"EDSCommandChangedNotification" object:self];
    
    if (!selectedButton || selectedButton == _selectedButton) {
        //we're clearing the selected button, set it to nil and hide panel
        _selectedButton.selected = NO;
        _selectedButton = nil;
        [self showPanelView:NO];
        return;
    }
    
    //we need to show the panel if our constraint is < 0
    BOOL needShowPanel = (self.panelViewXConstraint.constant < 0);
    
    //unselect old button
    _selectedButton.selected = NO;
    
    //select new buton
    _selectedButton = selectedButton;
    _selectedButton.selected = YES;
    
    //show correct vc
    NSInteger buttonIndex = selectedButton.tag;
    UIViewController *newVC = [self.viewControllers objectAtIndex:buttonIndex];
    if (newVC != (id)[NSNull null]) {
        [self.panelView bringSubviewToFront:newVC.view];
    }
    
    if (needShowPanel) {
        [self showPanelView:YES];
    }
}

-(void)addViewControllers {
    
    self.viewControllers = [NSMutableArray arrayWithCapacity:5];    
    
    //
    //create layers VC
    //
    self.layersVC = [[EDSLayersViewController alloc] initWithNibName:@"EDSLayersViewController" bundle:nil];
    self.layersVC.mapView = self.mapView;
    [self addViewControllerToPanel:self.layersVC];

    //
    //create places vc
    //
    self.placesVC = [[EDSPlacesViewController alloc] initWithNibName:@"EDSPlacesViewController" bundle:nil];
    self.placesVC.mapView = self.mapView;
    self.placesVC.routeDelegate = self;
    self.placesVC.routeAction = @selector(routeIt:);
    self.placesVC.placesLayer = self.placesLayer;
    self.placesVC.title = @"Places";
    self.placesVC.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
    //add places VC to panel view
    [self addViewControllerToPanel:self.placesVC];
    
    //
    //create features VC
    //
    self.featuresVC = [[EDSFeaturesViewController alloc] initWithNibName:@"EDSFeaturesViewController" bundle:nil];
    self.featuresVC.mapView = self.mapView;
    self.featuresVC.title = @"Fuel Stations";
    [self addViewControllerToPanel:self.featuresVC];

    //
    //create route vc
    //
    self.routeVC = [[EDSRouteViewController alloc] initWithNibName:@"EDSRouteViewController" bundle:nil];
    self.routeVC.mapView = self.mapView;
    self.routeVC.title = @"Route";

    //add route VC to panel view
    [self addViewControllerToPanel:self.routeVC];
}

-(void)addViewControllerToPanel:(UIViewController *)viewController {
    
    viewController.view.frame = self.panelView.bounds;
    [self.panelView addSubview:viewController.view];
    [self.viewControllers addObject:viewController];
    
    //add view constraints
    //
    //The following code is part of the Auto Layout stuff in iOS 6.0.
    //The @"|[view]|" visual format tells the system to keep the left and right
    //sides of view anchored to it's superview; the same with the @"V:|[view]|"
    //visual format, except that one says keep the top and bottom anchored.
    //
    UIView *view = viewController.view;
    NSArray *hcs = [NSLayoutConstraint constraintsWithVisualFormat:@"|[view]|"
                                                           options:0
                                                           metrics:nil
                                                             views:NSDictionaryOfVariableBindings(view)];
    [self.panelView addConstraints:hcs];
    
    NSArray *vcs = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[view]|"
                                                           options:0
                                                           metrics:nil
                                                             views:NSDictionaryOfVariableBindings(view)];
    [self.panelView addConstraints:vcs];
}

-(void)showPanelView:(BOOL)show {

    //This code uses an NSLayoutConstraint, which is set up as an IBOutlet in EDSViewController.xib
    //to manage hiding and showing the panel view.  This is substantially less code than calculating and
    //setting the view's frame, especially considering that in our app the mapview is anchored to the right
    //side of the panel view and needs to resize when the panel view is shown/hidden.
    //
    //Unfortunately, setting the constraint constant is not animatable in iOS; it IS animatable in OS X, so
    //I'm hopeful it will be so in a future version of iOS.
    //
    CGFloat newX = show ? self.panelViewInitialXConstraintConstant : self.panelViewInitialXConstraintConstant - self.panelViewWidth;
    [UIView animateWithDuration:1.0
                          delay: 0.0
                        options: UIViewAnimationOptionCurveEaseIn
                     animations:^{
                         self.panelViewXConstraint.constant = newX;
                     }
                     completion:nil];
}

@end

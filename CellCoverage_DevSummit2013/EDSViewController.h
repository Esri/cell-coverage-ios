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

#import <UIKit/UIKit.h>
#import <ArcGIS/ArcGIS.h>
#import "LoadingView.h"

@class EDSLayersViewController;
@class EDSPlacesViewController;
@class EDSFeaturesViewController;
@class EDSRouteViewController;

@interface EDSViewController : UIViewController

@property (nonatomic, strong) IBOutlet AGSMapView *mapView;
@property (nonatomic, strong) AGSGraphicsLayer *routeLayer;

@property (nonatomic, strong) EDSLayersViewController *layersVC;
@property (nonatomic, strong) EDSPlacesViewController *placesVC;
@property (nonatomic, strong) EDSFeaturesViewController *featuresVC;
@property (nonatomic, strong) EDSRouteViewController *routeVC;

@property (nonatomic, strong) UIButton *selectedButton;

@property (nonatomic, strong) IBOutlet UIButton *layersButton;
@property (nonatomic, strong) IBOutlet UIButton *placesButton;
@property (nonatomic, strong) IBOutlet UIButton *featuresButton;
@property (nonatomic, strong) IBOutlet UIButton *routeButton;

@property (nonatomic, strong) AGSRouteTask *routeTask;
@property (nonatomic, strong) AGSRouteTaskParameters *routeTaskParams;
@property (nonatomic, strong) AGSRouteResult *routeResult;

@property (nonatomic, strong) AGSFeatureLayer *fuelStationsFeatureLayer;
@property (nonatomic, strong) AGSFeatureLayer *coverageFeatureLayer;

@property (nonatomic, retain) AGSQuery *fuelStationQuery;
@property (nonatomic, retain) AGSFeatureSet *featureSet;
@property (nonatomic, strong) NSOperation* featureLayerQueryOperation;
@property (nonatomic, strong) NSOperation* fuelStationQueryOperartion;

@property (nonatomic, strong) LoadingView *placeLoadingView;
@property (nonatomic, strong) LoadingView *routeLoadingView;
@end

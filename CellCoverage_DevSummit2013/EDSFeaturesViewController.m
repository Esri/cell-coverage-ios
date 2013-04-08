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

#import "EDSFeaturesViewController.h"

@interface EDSFeaturesViewController () <AGSPopupsContainerDelegate>

@end

@implementation EDSFeaturesViewController

-(void)dealloc {
    
    [[NSNotificationCenter defaultCenter]removeObserver:self];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        _popups = [NSArray array];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)setPopups:(NSArray *)popups {
    
    _popups = [popups copy];
    
    //    self.navBar
    self.popupVC = [[AGSPopupsContainerViewController alloc] initWithPopups:self.popups usingNavigationControllerStack:NO];
    self.popupVC.style = AGSPopupsContainerStyleBlack;
    self.popupVC.delegate = self;
    self.clearButton = [[UIBarButtonItem alloc] initWithTitle:@"Clear" style:UIBarButtonItemStylePlain target:self action:@selector(clearButtonPressed:)];
    self.popupVC.doneButton = self.clearButton;
    [self.popupVC.view setAutoresizingMask:UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth];
    [self.popupVC.view setFrame:self.view.bounds];
    [self.view addSubview:self.popupVC.view];
    [self.popupVC setPopups:popups];
    
    if (!self.sketchLayer) {
        self.sketchLayer = [[AGSSketchGraphicsLayer alloc] init];
        [self.mapView addMapLayer:self.sketchLayer withName:@"Sketch Layer"];
    }

    if (!self.sketchCompleteButton) {
        self.sketchCompleteButton = [[UIBarButtonItem alloc]initWithTitle:@"Sketch Done" style:UIBarButtonItemStylePlain target:self action:@selector(sketchComplete)];
    }
}

-(void)clearButtonPressed:(id)sender {
    self.popups = [NSArray array];
    [self.popupVC clearAllPopups];
}

-(void)setActiveFeatureLayer:(AGSFeatureLayer *)activeFeatureLayer {
    _activeFeatureLayer = activeFeatureLayer;
    _activeFeatureLayer.editingDelegate = self;
}

#pragma mark - AGSPopupsContainerDelegate

-(void)popupsContainer:(id<AGSPopupsContainer>)popupsContainer didChangeToCurrentPopup:(AGSPopup*)popup {
    
    if (popup && [self.popups count] > 0) {
        AGSPoint *point = popup.graphic.geometry.envelope.center;
        [self.mapView centerAtPoint:point animated:YES];
        
        //show the callout]
        [self.mapView.callout showCalloutAtPoint:point forGraphic:popup.graphic animated:YES];
    } else {
        [self.mapView.callout setHidden:YES];
    }
}
@end

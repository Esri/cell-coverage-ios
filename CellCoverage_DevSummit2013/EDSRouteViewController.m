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

#import "EDSRouteViewController.h"
#import "EDSRouteViewController+Elevation.h"

#define MAINLABEL_TAG 1
#define SECONDLABEL_TAG 2

@interface EDSRouteViewController ()

@property (nonatomic, strong) IBOutlet UITableView *tableView;
@property (nonatomic, strong) IBOutlet UISegmentedControl *segmentedControl;
@property (nonatomic, strong) AGSGraphic *currentDirectionGraphic;
@property (nonatomic, strong) AGSGraphicsLayer *routeLayer;

@property (nonatomic, strong) NSMutableArray *weakSignals;

-(IBAction)selectedSegmentChanged:(id)sender;
-(AGSCompositeSymbol*)currentDirectionSymbol:(EDSSignalStrength) signalStrength;
-(void)processGraphics:(NSArray *)graphics;

@end

// The table view cell customization was based on information in Apple's Table View Programming Guide for iOS,
// specifically the section on 'Programmatically Adding Subviews to a Cell’s Content View'
//
// http://developer.apple.com/library/ios/#documentation/UserExperience/Conceptual/TableView_iPhone/TableViewCells/TableViewCells.html
//
@implementation EDSRouteViewController

-(void)dealloc {
    
    [[NSNotificationCenter defaultCenter]removeObserver:self];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
        
    self.weakSignals = [NSMutableArray array];

    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(commandDidChange:) name:@"EDSCommandChangedNotification" object:nil];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)commandDidChange:(id)sender {
    [self.tableView reloadData];
}

-(void)setDirectionGraphics:(NSArray *)directionGraphics {
    
    _directionGraphics = [directionGraphics copy];
    //set routeLayer
    self.routeLayer = (AGSGraphicsLayer *)[self.mapView mapLayerForName:@"Route"];
    [self processGraphics:_directionGraphics];
    [self.tableView reloadData];
}

-(IBAction)selectedSegmentChanged:(id)sender {

    // remove current direction graphic
    if ([self.routeLayer.graphics containsObject:self.currentDirectionGraphic]) {
        [self.routeLayer removeGraphic:self.currentDirectionGraphic];
    }

    [self.tableView reloadData];
}

#pragma mark -
#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    //if results is not nil and we have results, return that number
    NSInteger numRows = 1;
    
    if (self.segmentedControl.selectedSegmentIndex == 0) {
        if (self.directionGraphics != nil && [self.directionGraphics count] > 0) {
            numRows = [self.directionGraphics count];
        }
    }
    else {
        if (self.weakSignals != nil && [self.weakSignals count] > 0) {
            numRows = [self.weakSignals count];
        }
    }
    
    return numRows;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    
    UILabel *mainLabel, *secondLabel;
    UIButton *signalStrengthButton;
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        
        CGFloat imageViewOriginX = cell.frame.size.width - 38.0;
        
        mainLabel = [[UILabel alloc] initWithFrame:CGRectMake(12.0, 5.0, imageViewOriginX - 16.0, 15.0)];
        mainLabel.tag = MAINLABEL_TAG;
        mainLabel.font = [UIFont systemFontOfSize:14.0];
        mainLabel.adjustsFontSizeToFitWidth = YES;
        mainLabel.minimumScaleFactor = 0.7;
        mainLabel.textColor = [UIColor blackColor];
        mainLabel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleHeight;
        [cell.contentView addSubview:mainLabel];
        
        secondLabel = [[UILabel alloc] initWithFrame:CGRectMake(12.0, 24.0, imageViewOriginX - 16.0, 15.0)];
        secondLabel.tag = SECONDLABEL_TAG;
        secondLabel.font = [UIFont systemFontOfSize:12.0];
        secondLabel.textColor = [UIColor darkGrayColor];
        secondLabel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleHeight;
        [cell.contentView addSubview:secondLabel];
        
        signalStrengthButton = [UIButton buttonWithType:UIButtonTypeCustom];
        signalStrengthButton.frame = CGRectMake(imageViewOriginX, 6.0, 32.0, 32.0);
        signalStrengthButton.autoresizingMask = UIViewAutoresizingNone;
        [signalStrengthButton addTarget:self action:@selector(signalStrengthButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        
        [cell.contentView addSubview:signalStrengthButton];

        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    else {
        mainLabel = (UILabel *)[cell.contentView viewWithTag:MAINLABEL_TAG];
        secondLabel = (UILabel *)[cell.contentView viewWithTag:SECONDLABEL_TAG];
        
        //since we're using the 'tag' property to denote which row the button is in
        //we need to manually find the button
        for (UIView *view in cell.contentView.subviews) {
            if ([view isKindOfClass:[UIButton class]]) {
                signalStrengthButton = (UIButton *)view;
            }
        }
    }
    
    // Set up the cell...
    
    //set tag to be the index row, so we can get the row the button was in
    AGSDirectionGraphic *direction = nil;
    if (self.segmentedControl.selectedSegmentIndex == 0) {
        if ([self.directionGraphics count] > 0) {
            direction = (AGSDirectionGraphic *)[self.directionGraphics objectAtIndex:indexPath.row];
        }
    }
    else {
        if ([self.weakSignals count] > 0) {
            direction = (AGSDirectionGraphic *)[self.weakSignals objectAtIndex:indexPath.row];
        }
    }
    
    if (direction) {
        //we have a routeResult...
        mainLabel.text = direction.text;
        secondLabel.text = [NSString stringWithFormat:@"%0.2f", direction.length];
        cell.textLabel.text = nil;
        
        //get signal strength and set appropriate image...
        EDSSignalStrength signalStrength = (EDSSignalStrength)[direction attributeAsIntegerForKey:@"Signal Strength" exists:nil];
        UIImage *signalImage;
        if (signalStrength == edsNoSignal) {
            signalImage = [UIImage imageNamed:@"RedSignal.png"];
        }
        else if (signalStrength == edsWeakSignal) {
            signalImage = [UIImage imageNamed:@"YellowSignal.png"];
        }
        else {
            signalImage = [UIImage imageNamed:@"GreenSignal.png"];
        }
        
        [signalStrengthButton setImage:signalImage forState:UIControlStateNormal];

        signalStrengthButton.tag = indexPath.row;
    }
    else {
        //no results...
        cell.textLabel.text = @"No route results.";
        [signalStrengthButton setImage:nil forState:UIControlStateNormal];
        mainLabel.text = nil;
        secondLabel.text = nil;
        signalStrengthButton.tag = -1;;
    }
    
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSInteger directionIndex = indexPath.row;
    
    // remove current direction graphic, so we can display next one
    if ([self.routeLayer.graphics containsObject:self.currentDirectionGraphic]) {
        [self.routeLayer removeGraphic:self.currentDirectionGraphic];
    }

    if (self.segmentedControl.selectedSegmentIndex == 0) {
        // get current direction and add it to the graphics layer
        self.currentDirectionGraphic = [self.directionGraphics objectAtIndex:directionIndex];
    }
    else {
        self.currentDirectionGraphic = [self.weakSignals objectAtIndex:directionIndex];
    }
    
    //get signalStrength
    NSInteger signalStrength = (EDSSignalStrength)[self.currentDirectionGraphic attributeAsIntegerForKey:@"Signal Strength" exists:nil];
    self.currentDirectionGraphic.symbol = [self currentDirectionSymbol:signalStrength];
    [self.routeLayer addGraphic:self.currentDirectionGraphic];
    
    // zoom to envelope of the current direction (expanded by factor of 1.3)
    AGSMutableEnvelope *env = [self.currentDirectionGraphic.geometry.envelope mutableCopy];
    [env expandByFactor:1.3];
    [self.mapView zoomToEnvelope:env animated:YES];
}

#pragma mark - Internal

-(void)processGraphics:(NSArray *)graphics {
    
    self.weakSignals = [NSMutableArray array];
    for (AGSGraphic *graphic in graphics) {
        EDSSignalStrength signalStrength = [graphic attributeAsIntegerForKey:@"Signal Strength" exists:nil];
        if (signalStrength == edsNoSignal || signalStrength == edsWeakSignal) {
            [self.weakSignals addObject:graphic];
        }
    }
}

-(void)signalStrengthButtonPressed:(id)sender {

    UIButton *button = ((UIButton *)sender);
    NSInteger tag = button.tag;
    if (tag >= 0) {
        AGSGraphic *currentGraphic;
        if (self.segmentedControl.selectedSegmentIndex == 0) {
            currentGraphic = [self.directionGraphics objectAtIndex:tag];
        }
        else {
            currentGraphic = [self.weakSignals objectAtIndex:tag];
        }

        AGSGeometry *geometry = currentGraphic.geometry;
        if ([geometry isKindOfClass:[AGSPolyline class]]) {
            
            //the buttonFrame is used when displaying the popover
            CGRect buttonFrame = [self.view convertRect:button.frame fromView:button.superview];
            [self displayElevationProfile:currentGraphic fromRect:buttonFrame inView:self.view.superview];
        }
        
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:tag inSection:0];
        [self.tableView selectRowAtIndexPath:indexPath animated:YES scrollPosition:UITableViewScrollPositionNone];
        [self tableView:self.tableView didSelectRowAtIndexPath:indexPath];
    }
}

//
// represents the current direction
//
- (AGSCompositeSymbol*)currentDirectionSymbol:(EDSSignalStrength) signalStrength {
	AGSCompositeSymbol *cs = [AGSCompositeSymbol compositeSymbol];
	
	AGSSimpleLineSymbol *sls0 = [AGSSimpleLineSymbol simpleLineSymbol];
	sls0.color = [UIColor blackColor];
	sls0.style = AGSSimpleLineSymbolStyleSolid;
	sls0.width = 12;
	[cs addSymbol:sls0];
	
	AGSSimpleLineSymbol *sls1 = [AGSSimpleLineSymbol simpleLineSymbol];
	sls1.color = [UIColor whiteColor];
	sls1.style = AGSSimpleLineSymbolStyleSolid;
	sls1.width = 8;
	[cs addSymbol:sls1];
    
    UIColor *signalColor;
    if (signalStrength == edsNoSignal) {
        signalColor = [UIColor redColor];
    }
    else if (signalStrength == edsWeakSignal) {
        signalColor = [UIColor yellowColor];
    }
    else {
        signalColor = [UIColor greenColor];
    }
    
	AGSSimpleLineSymbol *sls2 = [AGSSimpleLineSymbol simpleLineSymbol];
	sls2.color = signalColor;
	sls2.style = AGSSimpleLineSymbolStyleDash;
	sls2.width = 4;
	[cs addSymbol:sls2];
	
	return cs;
}


@end

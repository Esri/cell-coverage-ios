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

#import "EDSPlacesViewController.h"

#define EDSSuppressClangPerformSelectorLeakWarning(targetActionCode) \
do { \
_Pragma("clang diagnostic push") \
_Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") \
targetActionCode; \
_Pragma("clang diagnostic pop") \
} while (0)

//This class handles Geocoding, among other things.  Based heavily on the following sample:
//
//  http://www.arcgis.com/home/item.html?id=c1e9abdacf524c2f99d39fbac14b3e0d
//
// The table view cell customization was based on information in Apple's Table View Programming Guide for iOS,
// specifically the section on 'Programmatically Adding Subviews to a Cell’s Content View'
//
// http://developer.apple.com/library/ios/#documentation/UserExperience/Conceptual/TableView_iPhone/TableViewCells/TableViewCells.html
//
@interface EDSPlacesViewController () <UISearchBarDelegate, AGSLocatorDelegate, AGSCalloutDelegate>

@property (nonatomic, strong) IBOutlet UISearchBar *searchBar;
@property (nonatomic, strong) IBOutlet UITableView *tableView;

@property (nonatomic, strong) AGSLocator *locator;
@property (nonatomic, strong) AGSCalloutTemplate *calloutTemplate;
@property (nonatomic, strong) NSArray *results;

//This is the method that starts the geocoding operation
- (void)startGeocoding;

@end

#define MAINLABEL_TAG 1
#define SECONDLABEL_TAG 2

@implementation EDSPlacesViewController

//The geocode service
static NSString *kGeoLocatorURL = @"http://tasks.arcgisonline.com/ArcGIS/rest/services/Locators/ESRI_Places_World/GeocodeServer";

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

- (void)startGeocoding
{
    //clear results from table
    self.results = [NSArray array];
    [self.tableView reloadData];
    
    //add placesLayer to map if we need to
    if (![self.mapView.mapLayers containsObject:self.placesLayer]) {
        [self.mapView addMapLayer:self.placesLayer withName:@"Places"];
    }

    //clear out previous results
    [self.placesLayer removeAllGraphics];
    
    //create the AGSLocator with the geo locator URL
    //and set the delegate to self, so we get AGSLocatorDelegate notifications
    self.locator = [AGSLocator locatorWithURL:[NSURL URLWithString:kGeoLocatorURL]];
    self.locator.delegate = self;
    
    //we want all out fields
    //Note that the "*" for out fields is supported for geocode services of
    //ArcGIS Server 10 and above
    //NSArray *outFields = [NSArray arrayWithObject:@"*"];
    
    //for pre-10 ArcGIS Servers, you need to specify all the out fields:
    NSArray *outFields = [NSArray arrayWithObjects:@"Loc_name",
                          @"Shape",
                          @"Score",
                          @"Name",
                          @"Rank",
                          @"Match_addr",
                          @"Descr",
                          @"Latitude",
                          @"Longitude",
                          @"City",
                          @"County",
                          @"State",
                          @"State_Abbr",
                          @"Country",
                          @"Cntry_Abbr",
                          @"Type",
                          @"North_Lat",
                          @"South_Lat",
                          @"West_Lon",
                          @"East_Lon",
                          nil];
    
    //Create the address dictionary with the contents of the search bar
    NSDictionary *addresses = [NSDictionary dictionaryWithObjectsAndKeys:self.searchBar.text, @"PlaceName", nil];
    
    //now request the location from the locator for our address
    [self.locator locationsForAddress:addresses returnFields:outFields outSpatialReference:self.mapView.spatialReference];
    
    self.loadingView = [LoadingView loadingViewInView:self.view withText:@"Finding places..."];
}

#pragma mark -
#pragma mark AGSLocatorDelegate

- (void)locator:(AGSLocator *)locator operation:(NSOperation *)op didFindLocationsForAddress:(NSArray *)candidates
{    
    //check and see if we didn't get any results
	if (candidates == nil || [candidates count] == 0)
	{
        //show alert if we didn't get results
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No Results"
                                                        message:@"No Results Found By Locator"
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        
        [alert show];
	}
	else
	{
        self.results = candidates;
        
        //use these to calculate extent of results
        double xmin = DBL_MAX;
        double ymin = DBL_MAX;
        double xmax = -DBL_MAX;
        double ymax = -DBL_MAX;
		
		//create the callout template, used when the user displays the callout
		self.calloutTemplate = [[AGSCalloutTemplate alloc]init];
        
        //loop through all candidates/results and add to graphics layer
		for (int i=0; i<[candidates count]; i++)
		{
			AGSAddressCandidate *addressCandidate = (AGSAddressCandidate *)[candidates objectAtIndex:i];
            
            //get the location from the candidate
            AGSPoint *pt = addressCandidate.location;
            
            //accumulate the min/max
            if (pt.x  < xmin)
                xmin = pt.x;
            
            if (pt.x > xmax)
                xmax = pt.x;
            
            if (pt.y < ymin)
                ymin = pt.y;
            
            if (pt.y > ymax)
                ymax = pt.y;
            
			//create a marker symbol to use in our graphic
            AGSPictureMarkerSymbol *marker = [AGSPictureMarkerSymbol pictureMarkerSymbolWithImageNamed:@"BluePushpin.png"];
            marker.offset = CGPointMake(9,16);
            marker.leaderPoint = CGPointMake(-9, 11);
            
            //set the text and detail text based on 'Name' and 'Descr' fields in the attributes
            self.calloutTemplate.titleTemplate = @"${Name}";
            self.calloutTemplate.detailTemplate = @"${Descr}";
			
            //create the graphic
			AGSGraphic *graphic = [[AGSGraphic alloc] initWithGeometry: pt
																symbol:marker
															attributes:[addressCandidate.attributes mutableCopy]
                                                  infoTemplateDelegate:self.calloutTemplate];
            
            
            //add the graphic to the graphics layer
			[self.placesLayer addGraphic:graphic];
            
            if ([candidates count] == 1)
            {
                //we have one result, center at that point
                [self.mapView centerAtPoint:pt animated:NO];
                
				// set the width of the callout
				self.mapView.callout.width = 250;
                
                //show the callout
                [self.mapView.callout showCalloutAtPoint:(AGSPoint*)graphic.geometry forGraphic:graphic animated:YES];
            }
			
			//release the graphic bb
		}
        
        //if we have more than one result, zoom to the extent of all results
        int nCount = [candidates count];
        if (nCount > 1)
        {
            AGSMutableEnvelope *extent = [AGSMutableEnvelope envelopeWithXmin:xmin ymin:ymin xmax:xmax ymax:ymax spatialReference:self.mapView.spatialReference];
            [extent expandByFactor:1.5];
			[self.mapView zoomToEnvelope:extent animated:YES];
        }
	}

    [self.tableView reloadData];
    
    [self.loadingView removeView];
}

- (void)locator:(AGSLocator *)locator operation:(NSOperation *)op didFailLocationsForAddress:(NSError *)error
{
    [self.tableView reloadData];
    
    //The location operation failed, display the error
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Locator Failed"
                                                    message:[NSString stringWithFormat:@"Error: %@", error.description]
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    
    [alert show];

    [self.loadingView removeView];
}

#pragma mark _
#pragma mark UISearchBarDelegate

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
	
	//hide the callout
	self.mapView.callout.hidden = YES;
	
    //First, hide the keyboard, then starGeocoding
    [searchBar resignFirstResponder];
    [self startGeocoding];
}


- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    //hide the keyboard
    [searchBar resignFirstResponder];
}

#pragma mark -
#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    //if results is not nil and we have results, return that number
    return ((self.results != nil && [self.results count] > 0) ? [self.results count] : 0);
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    
    UILabel *mainLabel, *secondLabel;
    UIButton *routeButton;

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
        
        CGFloat routeButtonOriginX = cell.frame.size.width - 38.0;
        
        mainLabel = [[UILabel alloc] initWithFrame:CGRectMake(12.0, 5.0, routeButtonOriginX - 16.0, 15.0)];
        mainLabel.tag = MAINLABEL_TAG;
        mainLabel.font = [UIFont systemFontOfSize:14.0];
        mainLabel.textColor = [UIColor blackColor];
        mainLabel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleHeight;
        [cell.contentView addSubview:mainLabel];
        
        secondLabel = [[UILabel alloc] initWithFrame:CGRectMake(12.0, 24.0, routeButtonOriginX - 16.0, 15.0)];
        secondLabel.tag = SECONDLABEL_TAG;
        secondLabel.font = [UIFont systemFontOfSize:12.0];
        secondLabel.textColor = [UIColor darkGrayColor];
        secondLabel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleHeight;
        [cell.contentView addSubview:secondLabel];
        
        routeButton = [[UIButton alloc] initWithFrame:CGRectMake(routeButtonOriginX, 6.0, 32.0, 32.0)];
        [routeButton setImage:[UIImage imageNamed:@"Route.png"] forState:UIControlStateNormal];
        routeButton.autoresizingMask = UIViewAutoresizingNone;
        [routeButton addTarget:self action:@selector(routeButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        
        [cell.contentView addSubview:routeButton];
    }
    else {
        mainLabel = (UILabel *)[cell.contentView viewWithTag:MAINLABEL_TAG];
        secondLabel = (UILabel *)[cell.contentView viewWithTag:SECONDLABEL_TAG];
    }

    // Set up the cell...
    cell.accessoryType = UITableViewCellAccessoryNone;
    
    //set tag to be the index row, so we can get the row the buton was in
    routeButton.tag = indexPath.row;
    
    AGSAddressCandidate *addressCandidate = (AGSAddressCandidate *)[self.results objectAtIndex:indexPath.row];

    //text is the key at the given indexPath
    mainLabel.text = [addressCandidate.attributes objectForKey:@"Name"];
    
    //detail text is the value associated with the key above
    id detailValue = [addressCandidate.attributes objectForKey:@"Descr"];
    
    //figure out if the value is a NSDecimalNumber or NSString
    if ([detailValue isKindOfClass:[NSString class]])
    {
        //value is a NSString, just set it
        secondLabel.text = (NSString *)detailValue;
    }
    else if ([detailValue isKindOfClass:[NSDecimalNumber class]])
    {
        //value is a NSDecimalNumber, format the result as a double
        secondLabel.text = [NSString stringWithFormat:@"%0.0f", [detailValue doubleValue]];
    }
    else {
        //not a NSDecimalNumber or a NSString,
        secondLabel.text = @"N/A";
    }
	
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    AGSAddressCandidate *addressCandidate = (AGSAddressCandidate *)[self.results objectAtIndex:indexPath.row];
    
    //we have one result, center at that point
    [self.mapView centerAtPoint:addressCandidate.location animated:YES];
    
    //show the callout
    [self.mapView.callout showCalloutAtPoint:addressCandidate.location forGraphic:[self.placesLayer.graphics objectAtIndex:indexPath.row] animated:YES];
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - Routing stuff

-(void)routeButtonTapped:(id)sender {
    
    NSInteger index = ((UIButton *)sender).tag;

    if (self.routeDelegate && [self.routeDelegate canPerformAction:self.routeAction withSender:nil]) {
        EDSSuppressClangPerformSelectorLeakWarning([self.routeDelegate performSelector:self.routeAction withObject:[self.placesLayer.graphics objectAtIndex:index]]);
    }
}

@end

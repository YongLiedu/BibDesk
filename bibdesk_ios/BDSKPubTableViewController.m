//
//  BDSKPubTableViewController.m
//  BibDesk
//
//  Created by Colin A. Smith on 3/10/12.
/*
 This software is Copyright (c) 2012-2012
 Colin A. Smith. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Colin A. Smith nor the names of any
    contributors may be used to endorse or promote products derived
    from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "BDSKPubTableViewController.h"

#import "BDSKDetailViewController.h"
#import "BibDocument.h"
#import "BibItem.h"
#import "BDSKFileStore.h"
#import "BDSKGroupsArray.h"
#import "BDSKLinkedFile.h"
#import "BDSKPublicationsArray.h"
#import "BDSKSmartGroup.h"
#import "BDSKStaticGroup.h"
#import "BDSKTableSortDescriptor.h"
#import "BDSKStringConstants.h"
#import "BDSKStringConstants_iOS.h"
#import "NSString_BDSKExtensions.h"
#import "NSArray_BDSKExtensions.h"
#import "BDSKTemplate.h"
#import "BDSKTemplateObjectProxy.h"


@interface BDSKPubTableViewController () {

    BDSKFileStore *_fileStore;
    NSString *_bibFileName;
    BDSKGroupType _groupType;
    NSString *_groupName;
    NSArray *_bibItems;
    NSMutableArray *_filteredBibItems;
    BOOL _firstAppearance;
}

@end

@implementation BDSKPubTableViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        _fileStore = nil;
        _bibFileName = nil;
        _groupType = Library;
        _groupName = nil;
        _bibItems = nil;
        _filteredBibItems = [[NSMutableArray alloc] init];
        _firstAppearance = YES;
    }
    return self;
}

- (void)awakeFromNib
{
    _fileStore = nil;
    _bibFileName = nil;
    _groupType = Library;
    _groupName = nil;
    _bibItems = nil;
    _filteredBibItems = [[NSMutableArray alloc] init];
    _firstAppearance = YES;
}

- (void)dealloc {

    [_fileStore release];
    [_bibFileName release];
    [_groupName release];
    [_bibItems release];
    [_filteredBibItems release];
    [super dealloc];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    [self updateActivityIndicator];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated {

    [super viewWillAppear:animated];

    if (_firstAppearance) {
        self.tableView.contentOffset = CGPointMake(0, self.searchDisplayController.searchBar.bounds.size.height);
        _firstAppearance = NO;
    }
    self.navigationItem.title = self.groupName;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
    } else {
        return YES;
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (tableView == self.searchDisplayController.searchResultsTableView) {
        return [_filteredBibItems count];
    }
    
    // Return the number of rows in the section.
    return self.bibItems.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    BibItem *bibItem = [self tableView:tableView bibItemForRowAtIndexPath:indexPath];
    
    cell.textLabel.text = bibItem.title;
    
    NSString *year = [bibItem stringValueOfField:@"Year"];
    NSString *container = [bibItem container];
    NSString *volume = [bibItem stringValueOfField:@"Volume"];
    NSString *pages = [bibItem stringValueOfField:@"Pages"];
    
    NSString *volpages = [volume stringByAppendingString:pages withDelimiter:@":"];
    
    NSString *contvolpages = [container stringByAppendingString:volpages withDelimiter:@" "];
    
    cell.detailTextLabel.text = [year stringByAppendingString:contvolpages withDelimiter:@" - "];
    
    //NSLog(@"File Count: %i", bibItem.files.count);
    
    if ([self localLinkedFilePathForBibItem:bibItem]) {
        //cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.accessoryView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"pdf.png"]] autorelease];
        //cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    } else {
        //cell.accessoryType = UITableViewCellAccessoryNone;
        cell.accessoryView = nil;
        //cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    
    return cell;
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.splitViewController) {
        UINavigationController *navigationController = [self.splitViewController.viewControllers objectAtIndex:1];
        BDSKDetailViewController *viewController = (BDSKDetailViewController *)[navigationController.viewControllers objectAtIndex:0];
        NSURL *url = [self tableView:tableView urlForRowAtIndexPath:indexPath];
        viewController.displayedURL = url;
    } else {
        [self performSegueWithIdentifier:@"showPDF" sender:self];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"showPDF"]) {
        UITableView *tableView;
        if (self.searchDisplayController.active) {
            tableView = self.searchDisplayController.searchResultsTableView;
        } else {
            tableView = self.tableView;
        }
        BDSKDetailViewController *viewController = segue.destinationViewController;
        NSIndexPath *indexPath = [tableView indexPathForSelectedRow];
        NSURL *url = [self tableView:tableView urlForRowAtIndexPath:indexPath];
        viewController.displayedURL = url;
    }
}

- (NSArray *)bibItems {

    return _bibItems;
}

- (void)setBibItems:(NSArray *)newBibItems {

    if (_bibItems != newBibItems) {
        [_bibItems release];
        BDSKTableSortDescriptor *sortDescriptor = [BDSKTableSortDescriptor tableSortDescriptorForIdentifier:BDSKPubDateString ascending:NO];
        _bibItems = [[newBibItems sortedArrayUsingMergesortWithDescriptors:[NSArray arrayWithObject:sortDescriptor]] retain];
        
        [self.tableView reloadData];
        
        // Template Testing Code
        if ([_bibItems count] && NO) {
        
            BDSKTemplate *testTemplate = [BDSKTemplate templateWithString:@"<$publications><$authors.abbreviatedNormalizedName.stringByRemovingTeX.@componentsJoinedByCommaAndAnd/> (<$fields.Year/>). <$fields.Title.stringByRemovingTeX/>, <$fields.Journal.stringByRemovingTeX/>, <$fields.Volume/>(<$fields.Number/>), <$fields.Pages/>\n</$publications>" fileType:@"txt"];
            
            BibItem *firstBibItem = [_bibItems objectAtIndex:0];
            
            NSString *templateString = [BDSKTemplateObjectProxy stringByParsingTemplate:testTemplate withObject:[firstBibItem owner] publications:_bibItems];
                
            NSLog(@"Template Text:\n%@", templateString);
        }
    }
}

#pragma mark -
#pragma mark Content Filtering

- (void)filterContentForSearchText:(NSString*)searchText scope:(NSString*)scope
{
	/*
	 Update the filtered array based on the search text and scope.
	 */
	
	[_filteredBibItems removeAllObjects]; // First clear the filtered array.
	
	/*
	 Search the main list for products whose type matches the scope (if selected) and whose name matches searchText; add items that match to the filtered array.
	 */
	for (BibItem *bibItem in self.bibItems) {
		NSString *bibString = [bibItem allFieldsString];
        if ([bibString rangeOfString:searchText options:NSCaseInsensitiveSearch].location != NSNotFound) {
            [_filteredBibItems addObject:bibItem];
        }
	}
}

#pragma mark -
#pragma mark UISearchDisplayController Delegate Methods

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString
{
    [self filterContentForSearchText:searchString scope:
			[[self.searchDisplayController.searchBar scopeButtonTitles] objectAtIndex:[self.searchDisplayController.searchBar selectedScopeButtonIndex]]];
    
    // Return YES to cause the search result table view to be reloaded.
    return YES;
}

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchScope:(NSInteger)searchOption
{
    [self filterContentForSearchText:[self.searchDisplayController.searchBar text] scope:
			[[self.searchDisplayController.searchBar scopeButtonTitles] objectAtIndex:searchOption]];
    
    // Return YES to cause the search result table view to be reloaded.
    return YES;
}

- (void)searchDisplayController:(UISearchDisplayController *)controller didLoadSearchResultsTableView:(UITableView *)tableView {

    tableView.rowHeight = self.tableView.rowHeight;
}

- (void)searchDisplayController:(UISearchDisplayController *)controller willHideSearchResultsTableView:(UITableView *)tableView {

    NSIndexPath *indexPath = tableView.indexPathForSelectedRow;
    if (indexPath) {
        BibItem *bibItem = [_filteredBibItems objectAtIndex:indexPath.row];
        NSUInteger row = [self.bibItems indexOfObject:bibItem];
        NSIndexPath *indexPathToSelect = [NSIndexPath indexPathForRow:row inSection:0];
        [self.tableView selectRowAtIndexPath:indexPathToSelect animated:NO scrollPosition:UITableViewScrollPositionMiddle];
    }
}

#pragma mark -
#pragma mark Property Methods

- (BibDocument *)document {

    return [self.fileStore bibDocumentForName:self.bibFileName];
}

- (BOOL)documentReady {

    return self.bibFileName && self.fileStore && [self.fileStore bibDocumentForName:self.bibFileName].documentState != UIDocumentStateClosed;
}

- (BDSKFileStore *)fileStore {

    return _fileStore;
}

- (void)setFileStore:(BDSKFileStore *)fileStore {

    if (fileStore != _fileStore) {
        [self unregisterForNotifications];
        [_fileStore release];
        _fileStore = [fileStore retain];
        [self registerForNotifications];
        [self updateBibItems];
    }
}

- (NSString *)bibFileName {

    return _bibFileName;
}

- (void)setBibFileName:(NSString *)bibFileName {

    if (![bibFileName isEqual:_bibFileName]) {
        [_bibFileName release];
        _bibFileName = [bibFileName retain];
        [self updateBibItems];
    }
}

- (BDSKGroupType)groupType {

    return _groupType;
}

- (void)setGroupType:(BDSKGroupType)groupType {

    if (groupType != _groupType) {
        _groupType = groupType;
        [self updateBibItems];
    }
}

- (NSString *)groupName {

    return _groupName;
}

- (void)setGroupName:(NSString *)groupName {

    if (![groupName isEqual:_groupName]) {
        [_groupName release];
        _groupName = [groupName retain];
        [self updateBibItems];
    }
}

- (void)updateBibItems {

    NSArray *newBibItems = nil;

    if ([self documentReady]) {
    
        if (self.groupType == Library) {
            newBibItems = [NSArray arrayWithArray:self.document.publications];
        } else if (self.groupType == Smart) {
            if (self.groupName) {
                NSUInteger index = [[[self.document groups] smartGroups] indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
                    return [self.groupName isEqualToString:[(BDSKSmartGroup *)obj name]];
                }];
                if (index != NSNotFound) {
                    BDSKSmartGroup *group = [[[self.document groups] smartGroups] objectAtIndex:index];
                    newBibItems = [group filterItems:self.document.publications];
                }
            }
        } else if (self.groupType = Static) {
            if (self.groupName) {
                NSUInteger index = [[[self.document groups] staticGroups] indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
                    return [self.groupName isEqualToString:[(BDSKStaticGroup *)obj name]];
                }];
                if (index != NSNotFound) {
                    BDSKStaticGroup *group = [[[self.document groups] staticGroups] objectAtIndex:index];
                    newBibItems = [group publications];
                }
            }
        }
    }
    
    [self setBibItems:newBibItems];
    
    [self.tableView reloadData];
    [self updateActivityIndicator];
}

- (void)updateActivityIndicator
{
    if (self.documentReady) {
        self.navigationItem.rightBarButtonItem = nil;
    } else {

        UIActivityIndicatorViewStyle activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
        
        // barStyle is 3 (undocumented) when in a popover controller
        if (self.navigationController.navigationBar.barStyle > 2) activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhite;
        UIActivityIndicatorView *activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:activityIndicatorViewStyle];
        UIBarButtonItem *refreshButton = [[UIBarButtonItem alloc] initWithCustomView:activityIndicator];
        self.navigationItem.rightBarButtonItem = refreshButton;
        [activityIndicator startAnimating];
        [refreshButton release];
        [activityIndicator release];
    }
}

- (BibItem *)tableView:(UITableView *)tableView bibItemForRowAtIndexPath:(NSIndexPath *)indexPath {

    if (tableView == self.searchDisplayController.searchResultsTableView) {
        return [_filteredBibItems objectAtIndex:indexPath.row];
    }
    
   return [self.bibItems objectAtIndex:indexPath.row];
}

- (NSURL *)tableView:(UITableView *)tableView urlForRowAtIndexPath:(NSIndexPath *)indexPath {

    BibItem *bibItem = [self tableView:tableView bibItemForRowAtIndexPath:indexPath];
    NSString *urlPath = [NSString stringWithFormat:@"/%@?citeKey=%@", self.bibFileName, bibItem.citeKey];
    NSURL *url = [[[NSURL alloc] initWithScheme:@"bibdesk" host:[self.fileStore.class storeName] path:urlPath] autorelease];
    
    return url;
}

- (NSString *)localLinkedFilePathForBibItem:(BibItem *)bibItem {

    NSString *localPath = nil;
    
    for (BDSKLinkedFile *file in bibItem.localFiles) {
        NSString *linkedFilePath = [self.fileStore pathForLinkedFilePath:file.relativePath relativeToBibFileName:self.bibFileName];
        if ([self.fileStore availabilityForLinkedFilePath:linkedFilePath] != NotAvailable) {
            localPath = [self.fileStore localPathForLinkedFilePath:linkedFilePath];
            break;
        }
    }
    
    return localPath;
}

#pragma mark - Notification support

- (void)handleBibDocumentChangedNotification:(NSNotification *)notification {

    if ([[notification.userInfo objectForKey:BDSKBibDocumentChangedNotificationBibFileNameKey] isEqual:self.bibFileName]) {
        if (self.document) {
            [self updateBibItems];
        } else {
            [self.navigationController popToRootViewControllerAnimated:YES];
        }
    }
}

- (void)registerForNotifications {

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleBibDocumentChangedNotification:) name:BDSKBibDocumentChangedNotification object:self.fileStore];
}

- (void)unregisterForNotifications {

    [[NSNotificationCenter defaultCenter] removeObserver:self name:BDSKBibDocumentChangedNotification object:self.fileStore];
}

@end

//
//  BDSKGroupTableViewController.m
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

#import "BDSKGroupTableViewController.h"

#import "BDSKPubTableViewController.h"
#import "BibDocument.h"
#import "BDSKFileStore.h"
#import "BDSKGroupsArray.h"
#import "BDSKSmartGroup.h"
#import "BDSKStaticGroup.h"
#import "BDSKStringConstants_iOS.h"

@interface BDSKGroupTableViewController () {

    BDSKFileStore *_fileStore;
    NSString *_bibFileName;
}

@property (readonly) BibDocument *document;
@property (readonly) BOOL documentReady;

- (void)updateActivityIndicator;

@end

@implementation BDSKGroupTableViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        _fileStore = nil;
        _bibFileName = nil;
    }
    return self;
}

- (void)dealloc {

    [_fileStore release];
    [_bibFileName release];
    [super dealloc];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    self.clearsSelectionOnViewWillAppear = YES;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    [self updateActivityIndicator];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    [self unregisterForNotifications];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
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
    if (self.documentReady) return 3;
    
    return 0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) return 1;
    if (section == 1) return [[[self.document groups] smartGroups] count];
    if (section == 2) return [[[self.document groups] staticGroups] count];
    if (section == 3) return [[[self.document groups] categoryGroups] count];
    
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == 1 && [[[self.document groups] smartGroups] count]) return @"Smart";
    if (section == 2 && [[[self.document groups] staticGroups] count]) return @"Static";
    if (section == 3 && [[[self.document groups] categoryGroups] count]) return @"Keywords";
    
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if (indexPath.section == 0 && indexPath.row == 0) {
    
        cell.textLabel.text = @"Library";
        if (self.document) {
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%i", [self.document.publications count]];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else {
            cell.detailTextLabel.text = nil;
        }
    
    } else if (indexPath.section == 1) {
    
        BDSKSmartGroup *group = [[[self.document groups] smartGroups] objectAtIndex:indexPath.row];
        cell.textLabel.text = [group name];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%i", [group count]];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    } else if (indexPath.section == 2) {
    
        BDSKStaticGroup *group = [[[self.document groups] staticGroups] objectAtIndex:indexPath.row];
        cell.textLabel.text = [group name];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%i", [group count]];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    } else if (indexPath.section == 3) {
    
    
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
    [self performSegueWithIdentifier:@"publications" sender:self];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"publications"]) {

        NSIndexPath *indexPath = self.tableView.indexPathForSelectedRow;        
        BDSKPubTableViewController *viewController = segue.destinationViewController;
        
        viewController.fileStore = self.fileStore;
        viewController.bibFileName = self.bibFileName;
        
        if (indexPath.section == 0 && indexPath.row == 0) {
            viewController.groupType = Library;
            viewController.groupName = @"Library";
        } else if (indexPath.section == 1) {
            BDSKSmartGroup *group = [[[self.document groups] smartGroups] objectAtIndex:indexPath.row];
            viewController.groupType = Smart;
            viewController.groupName = [group name];
        } else if (indexPath.section == 2) {
            BDSKStaticGroup *group = [[[self.document groups] staticGroups] objectAtIndex:indexPath.row];
            viewController.groupType = Static;
            viewController.groupName = [group name];
        } else if (indexPath.section == 3) {
            
        
        }
    }
}

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
        [self.tableView reloadData];
        [self updateActivityIndicator];
    }
}

- (NSString *)bibFileName {

    return _bibFileName;
}

- (void)setBibFileName:(NSString *)bibFileName {

    if (![bibFileName isEqual:_bibFileName]) {
        [_bibFileName release];
        _bibFileName = [bibFileName retain];
        [self.tableView reloadData];
        [self updateActivityIndicator];
    }
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

#pragma mark - Notification support

- (void)handleBibDocumentChangedNotification:(NSNotification *)notification {

    if ([[notification.userInfo objectForKey:BDSKBibDocumentChangedNotificationBibFileNameKey] isEqual:self.bibFileName]) {
        if (self.document) {
            [self.tableView reloadData];
            [self updateActivityIndicator];
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

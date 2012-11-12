//
//  BDSKMasterViewController.m
//  BibDesk
//
//  Created by Colin A. Smith on 3/3/12.
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

#import "BDSKMasterViewController.h"

#import "BDSKDetailViewController.h"
#import "BDSKAppDelegate.h"
#import "BDSKDropboxStore.h"
#import "BDSKGroupTableViewController.h"
#import "BDSKPDFTableViewController.h"
#import <DropboxSDK/DropboxSDK.h>

#import "BibDocument.h"

@interface BDSKMasterViewController () {
    NSMutableArray *_objects;
    BOOL _pdfsVisible;
    id _dropboxBibDocumentChangedObserver;
}

- (void)updateRefreshButton;

@end

@implementation BDSKMasterViewController

@synthesize detailViewController = _detailViewController;

- (void)awakeFromNib
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        //self.clearsSelectionOnViewWillAppear = NO;
        //self.contentSizeForViewInPopover = CGSizeMake(320.0, 600.0);
    }
    [super awakeFromNib];
}

- (void)dealloc
{
    [_detailViewController release];
    [_objects release];
    [_dropboxBibDocumentChangedObserver release];
    [super dealloc];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.navigationItem.title = NSLocalizedString(@"Bibliographies", @"Bibliographies");

    BDSKDropboxStore *dropboxStore = [BDSKDropboxStore sharedStore];
    [dropboxStore addObserver:self forKeyPath:@"bibFileNames" options:0 context:nil];

    _pdfsVisible = [dropboxStore.linkedFilePaths count] != 0;
    [dropboxStore addObserver:self forKeyPath:@"linkedFilePaths" options:0 context:nil];

    BDSKAppDelegate *appDelegate = (BDSKAppDelegate *)[[UIApplication sharedApplication] delegate];

    NSString *title = appDelegate.dropboxLinked ? @"Logout" : @"Login";
    UIBarButtonItem *dropboxButton = [[UIBarButtonItem alloc] initWithTitle:title style:UIBarButtonItemStylePlain target:appDelegate action:@selector(toggleDropboxLink)];
    self.navigationItem.leftBarButtonItem = dropboxButton;
    [dropboxButton release];
    
    [appDelegate addObserver:self forKeyPath:@"dropboxLinked" options:NSKeyValueObservingOptionNew context:nil];
    
    [self updateRefreshButton];
    
    [dropboxStore addObserver:self forKeyPath:@"isSyncing" options:0 context:nil];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:@"BDSKBibDocumentChanged" object:dropboxStore queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        [(UITableView *)self.view reloadData];
    }];
    
    self.detailViewController = (BDSKDetailViewController *)[[self.splitViewController.viewControllers lastObject] topViewController];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    BDSKAppDelegate *appDelegate = (BDSKAppDelegate *)[[UIApplication sharedApplication] delegate];
    [appDelegate removeObserver:self forKeyPath:@"dropboxLinked"];
    BDSKDropboxStore *dropboxStore = [BDSKDropboxStore sharedStore];
    [dropboxStore removeObserver:self forKeyPath:@"bibFileNames"];
    [dropboxStore removeObserver:self forKeyPath:@"linkedFilePaths"];
    [dropboxStore removeObserver:self forKeyPath:@"iSyncing"];
    [[NSNotificationCenter defaultCenter] removeObserver:_dropboxBibDocumentChangedObserver];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
    } else {
        return YES;
    }
}

/*
- (void)insertNewObject:(id)sender
{
    if (!_objects) {
        _objects = [[NSMutableArray alloc] init];
    }
    [_objects insertObject:[NSDate date] atIndex:0];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
    [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
}
*/

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    BDSKDropboxStore *dropboxStore = [BDSKDropboxStore sharedStore];

    if ([dropboxStore.linkedFilePaths count]) {
        return 2;
        _pdfsVisible = YES;
    }
    
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 1) return 1;    

    BDSKDropboxStore *dropboxStore = [BDSKDropboxStore sharedStore];
    return dropboxStore.bibFileNames.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];

    if (indexPath.section == 0){
        BDSKDropboxStore *dropboxStore = [BDSKDropboxStore sharedStore];
        NSString *name = [dropboxStore.bibFileNames objectAtIndex:indexPath.row];
        cell.textLabel.text = [name stringByDeletingPathExtension];
        cell.imageView.image = [UIImage imageNamed:@"bib.png"];
        if ([dropboxStore bibDocumentForName:name].documentState == UIDocumentStateNormal) {
            cell.imageView.alpha = 1;
        } else {
            cell.imageView.alpha = 0.25;
        }
    } else {
        cell.textLabel.text = @"Linked Files";
        cell.imageView.image = [UIImage imageNamed:@"pdf.png"];
    }
    
    return cell;
}

/*boo
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [_objects removeObjectAtIndex:indexPath.row];
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
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

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        [self performSegueWithIdentifier:@"documentGroups" sender:self];
    } else if (indexPath.section == 1) {
        [self performSegueWithIdentifier:@"allPDFFiles" sender:self];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    BDSKDropboxStore *dropboxStore = [BDSKDropboxStore sharedStore];
    
    if ([[segue identifier] isEqualToString:@"documentGroups"]) {

        NSIndexPath *indexPath = self.tableView.indexPathForSelectedRow;        
        NSString *name = [dropboxStore.bibFileNames objectAtIndex:indexPath.row];
        
        BDSKGroupTableViewController *viewController = segue.destinationViewController;
        viewController.navigationItem.title = [name stringByDeletingPathExtension];
        viewController.fileStore = dropboxStore;
        viewController.bibFileName = name;
    
    } else if ([[segue identifier] isEqualToString:@"allPDFFiles"]) {
    
        BDSKPDFTableViewController *viewController = segue.destinationViewController;
        viewController.fileStore = dropboxStore;
    }
}

- (void)updateRefreshButton {

    BDSKDropboxStore *dropboxStore = [BDSKDropboxStore sharedStore];
    BDSKAppDelegate *appDelegate = (BDSKAppDelegate *)[[UIApplication sharedApplication] delegate];

    if (dropboxStore.isSyncing) {

        UIActivityIndicatorViewStyle activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
        
        //NSLog(@"Navigation Bar Style: %i", self.navigationController.navigationBar.barStyle);
        // barStyle is 3 (undocumented) when in a popover controller
        if (self.navigationController.navigationBar.barStyle > 2) activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhite;
        
        UIActivityIndicatorView *activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:activityIndicatorViewStyle];
        UIBarButtonItem *refreshButton = [[UIBarButtonItem alloc] initWithCustomView:activityIndicator];
        self.navigationItem.rightBarButtonItem = refreshButton;
        [activityIndicator startAnimating];
        [refreshButton release];
        [activityIndicator release];
    
    } else if (appDelegate.dropboxLinked) {
    
        UIBarButtonItem *refreshButton = [[UIBarButtonItem alloc] initWithTitle:@"Refresh" style:UIBarButtonItemStylePlain target:self action:@selector(refresh)];
        self.navigationItem.rightBarButtonItem = refreshButton;
        [refreshButton release];
    
    } else {
    
        self.navigationItem.rightBarButtonItem = nil;
    }
}

- (void)refresh {

    [[BDSKDropboxStore sharedStore] startSync];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {

    if (keyPath == @"dropboxLinked") {
    
        BOOL linked = [(NSNumber *)[change objectForKey:NSKeyValueChangeNewKey] boolValue];
        self.navigationItem.leftBarButtonItem.title = linked ? @"Logout" : @"Login";
        [self updateRefreshButton];
    
    } else if (keyPath == @"isSyncing") {
    
        [self updateRefreshButton];
    
    } else if (keyPath == @"bibFileNames") {
    
        [(UITableView *)self.view reloadData];
    
    } else if (keyPath == @"linkedFilePaths") {
    
        BDSKDropboxStore *dropboxStore = [BDSKDropboxStore sharedStore];
        if ([dropboxStore.linkedFilePaths count]) {
            if (!_pdfsVisible) [self.tableView insertSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationAutomatic];
            _pdfsVisible = YES;
        } else {
            if (_pdfsVisible) [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationAutomatic];
            _pdfsVisible = NO;
        }
    }
}

@end

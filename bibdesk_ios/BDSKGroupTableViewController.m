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
#import "BDSKPublicationsArray.h"
#import "BDSKGroupsArray.h"
#import "BDSKSmartGroup.h"
#import "BDSKStaticGroup.h"

@interface BDSKGroupTableViewController ()

- (void)updateActivityIndicator;

@end

@implementation BDSKGroupTableViewController

@synthesize document;

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
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
    if (self.document) return 3;
    
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
    
        BDSKSmartGroup *group = [[[document groups] smartGroups] objectAtIndex:indexPath.row];
        cell.textLabel.text = [group name];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%i", [group count]];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    } else if (indexPath.section == 2) {
    
        BDSKStaticGroup *group = [[[document groups] staticGroups] objectAtIndex:indexPath.row];
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
        
        if (indexPath.section == 0 && indexPath.row == 0) {
            viewController.navigationItem.title = @"Library";
            viewController.bibItems = [NSArray arrayWithArray:self.document.publications];
        } else if (indexPath.section == 1) {
            BDSKSmartGroup *group = [[[document groups] smartGroups] objectAtIndex:indexPath.row];
            viewController.navigationItem.title = [group name];
            viewController.bibItems = [group filterItems:document.publications];
        } else if (indexPath.section == 2) {
            BDSKStaticGroup *group = [[[document groups] staticGroups] objectAtIndex:indexPath.row];
            viewController.navigationItem.title = [group name];
            viewController.bibItems = [group publications];
        } else if (indexPath.section == 3) {
            
        
        }
    }
}

- (void)setDocument:(BibDocument *)newDocument {

    if (document != newDocument) {
        [document release];
        document = [newDocument retain];
        NSArray *smartGroups = [[document groups] smartGroups];
        for (BDSKSmartGroup *group in smartGroups) {
            [group filterItems:document.publications];
        }
        [self.tableView reloadData];
        [self updateActivityIndicator];
    }
}

- (void)updateActivityIndicator
{
    if (self.document) {
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

@end

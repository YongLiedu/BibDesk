//
//  BDSKSettingsTableViewController.m
//  BibDesk
//
//  Created by Colin Smith on 12/16/12.
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

#import "BDSKSettingsTableViewController.h"

#import "BDSKAppDelegate.h"
#import "BDSKDropboxStore.h"

@interface BDSKSettingsTableViewController ()

@end

@implementation BDSKSettingsTableViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)dealloc {

    BDSKAppDelegate *appDelegate = (BDSKAppDelegate *)[[UIApplication sharedApplication] delegate];
    [appDelegate removeObserver:self forKeyPath:@"dropboxLinked"];
    BDSKDropboxStore *dropboxStore = [BDSKDropboxStore sharedStore];
    [dropboxStore removeObserver:self forKeyPath:@"dropboxBibFilePath"];
    [super dealloc];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    BDSKAppDelegate *appDelegate = (BDSKAppDelegate *)[[UIApplication sharedApplication] delegate];
    [appDelegate addObserver:self forKeyPath:@"dropboxLinked" options:NSKeyValueObservingOptionNew context:nil];
    BDSKDropboxStore *dropboxStore = [BDSKDropboxStore sharedStore];
    [dropboxStore addObserver:self forKeyPath:@"dropboxBibFilePath" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    if (section == 0) {
        BDSKAppDelegate *appDelegate = (BDSKAppDelegate *)[[UIApplication sharedApplication] delegate];
        return appDelegate.dropboxLinked ? 2 : 1;
    }
    
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = nil;
    
    if (indexPath.section == 0) {
    
        if (indexPath.row == 0) {
        
            static NSString *ToggleDropboxLinkCellIdentifier = @"ToggleDropboxLinkCell";
            cell = [tableView dequeueReusableCellWithIdentifier:ToggleDropboxLinkCellIdentifier];
        
            BDSKAppDelegate *appDelegate = (BDSKAppDelegate *)[[UIApplication sharedApplication] delegate];

            cell.textLabel.text = appDelegate.dropboxLinked ? @"Unlink from Dropbox" : @"Link to Dropbox";
        
        } else if (indexPath.row == 1) {
        
            static NSString *BibPathCellIdentifier = @"BibPathCell";
            cell = [tableView dequeueReusableCellWithIdentifier:BibPathCellIdentifier];
            
            BDSKDropboxStore *dropboxStore = [BDSKDropboxStore sharedStore];
            
            if (dropboxStore.dropboxBibFilePath) {
                NSString *text = dropboxStore.dropboxBibFilePath;
                if (text.length > 1) text = [text substringFromIndex:1];
                cell.detailTextLabel.text = text;
            } else {
                cell.detailTextLabel.text = @"None";
            }
        }
    }
    
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {

    if (section == 0) return @"Dropbox";
    
    return nil;
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
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
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
    if (indexPath.section == 0) {
    
        if (indexPath.row == 0) {
        
            BDSKAppDelegate *appDelegate = (BDSKAppDelegate *)[[UIApplication sharedApplication] delegate];
            [appDelegate toggleDropboxLink];
        }
    }
}

- (IBAction)doneButton:(id)sender {

    [self.delegate settingsTableViewControllerDone];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {

    if ([keyPath isEqualToString:@"dropboxLinked"]) {
    
        BDSKAppDelegate *appDelegate = (BDSKAppDelegate *)[[UIApplication sharedApplication] delegate];
        
        [self.tableView beginUpdates];
        NSArray *dropboxIndexPaths = @[[NSIndexPath indexPathForRow:1 inSection:0]];
        if (appDelegate.dropboxLinked) {
            [self.tableView insertRowsAtIndexPaths:dropboxIndexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
        } else {
            [self.tableView deleteRowsAtIndexPaths:dropboxIndexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
        }
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:0]] withRowAnimation:UITableViewRowAnimationFade];
        [self.tableView endUpdates];
    
    } else if ([keyPath isEqualToString:@"dropboxBibFilePath"]) {
    
        BDSKAppDelegate *appDelegate = (BDSKAppDelegate *)[[UIApplication sharedApplication] delegate];
        
        if (appDelegate.dropboxLinked) {
            [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:1 inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
        }
    }
}

@end

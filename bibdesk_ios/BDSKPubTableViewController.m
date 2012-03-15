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
#import "BDSKDropboxStore.h"
#import "BDSKLocalFile.h"
#import "BibItem.h"
#import "BDSKLinkedFile.h"
#import "BDSKTableSortDescriptor.h"
#import "BDSKStringConstants.h"
#import "NSString_BDSKExtensions.h"
#import "NSArray_BDSKExtensions.h"

@interface BDSKPubTableViewController () {

    NSMutableArray *_pdfFiles;
}

@end

@implementation BDSKPubTableViewController

@synthesize bibItems;

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)awakeFromNib
{
    self.bibItems = [NSArray array];
    _pdfFiles = nil;
}

- (void)dealloc {

    [_pdfFiles release];
    [super dealloc];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
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
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return self.bibItems.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    BibItem *bibItem = [bibItems objectAtIndex:indexPath.row];
    
    cell.textLabel.text = bibItem.title;
    
    NSString *year = [bibItem stringValueOfField:@"Year"];
    NSString *container = [bibItem container];
    NSString *volume = [bibItem stringValueOfField:@"Volume"];
    NSString *pages = [bibItem stringValueOfField:@"Pages"];
    
    NSString *volpages = [volume stringByAppendingString:pages withDelimiter:@":"];
    
    NSString *contvolpages = [container stringByAppendingString:volpages withDelimiter:@" "];
    
    cell.detailTextLabel.text = [year stringByAppendingString:contvolpages withDelimiter:@" - "];
    
    //NSLog(@"File Count: %i", bibItem.files.count);
    
    if (((BDSKLocalFile *)[_pdfFiles objectAtIndex:indexPath.row]).path) {
        //cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.accessoryView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"pdf.png"]] autorelease];
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    } else {
        //cell.accessoryType = UITableViewCellAccessoryNone;
        cell.accessoryView = nil;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
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

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {

    BDSKLocalFile *pdfFile = [_pdfFiles objectAtIndex:indexPath.row];

    if (pdfFile.path) return indexPath;
    
    return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    BDSKLocalFile *pdfFile = [_pdfFiles objectAtIndex:indexPath.row];

    if (pdfFile.path) {
        if (self.splitViewController) {
            UINavigationController *navigationController = [self.splitViewController.viewControllers objectAtIndex:1];
            BDSKDetailViewController *viewController = (BDSKDetailViewController *)[navigationController.viewControllers objectAtIndex:0];
            [viewController setDisplayedFile:pdfFile];
        } else {
            [self performSegueWithIdentifier:@"showPDF" sender:self];
        }
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"showPDF"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        BDSKLocalFile *pdfFile = [_pdfFiles objectAtIndex:indexPath.row];
        [[segue destinationViewController] setDisplayedFile:pdfFile];
    }
}

- (void)setBibItems:(NSArray *)newBibItems {

    if (bibItems != newBibItems) {
        [bibItems release];
        BDSKTableSortDescriptor *sortDescriptor = [BDSKTableSortDescriptor tableSortDescriptorForIdentifier:BDSKPubDateString ascending:NO];
        bibItems = [[newBibItems sortedArrayUsingMergesortWithDescriptors:[NSArray arrayWithObject:sortDescriptor]] retain];
        
        [_pdfFiles release];
        _pdfFiles = [[NSMutableArray alloc] init];
        
        BDSKDropboxStore *dropboxStore = [BDSKDropboxStore sharedStore];
        for (BibItem *bibItem in newBibItems) {
            BDSKLocalFile *localFile = nil;
            for (BDSKLinkedFile *file in bibItem.files) {
                //NSLog(@"Relative Path: %@", file.relativePath);
                if ((localFile = [dropboxStore.pdfFilePaths objectForKey:file.relativePath])) {
                    break;
                }
            }
            if (localFile) {
                [_pdfFiles addObject:localFile];
            } else {
                [_pdfFiles addObject:[[[BDSKLocalFile alloc] initWithDropboxPath:nil lastModifiedDate:nil totalByets:0] autorelease]];
            }
        }
        
        [self.tableView reloadData];
    }
}

@end

//
//  BDSKBibFilePathsTableViewController.m
//  BibDesk
//
//  Created by Colin Smith on 12/23/12.
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

#import "BDSKBibFilePathsTableViewController.h"

#import "BDSKDropboxStore.h"

@interface BDSKBibFilePathsTableViewController () {

    NSArray *_bibFilePaths;
    bool _updating;
    NSMutableSet *_selectedIndexes;
}

@end

@implementation BDSKBibFilePathsTableViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        _bibFilePaths = nil;
        _selectedIndexes = [[NSMutableSet alloc] init];
        _updating = NO;
    }
    return self;
}

- (void)awakeFromNib {

    _bibFilePaths = nil;
    _selectedIndexes = [[NSMutableSet alloc] init];
    _updating = NO;
}

- (void)dealloc {

    BDSKDropboxStore *dropboxStore = [BDSKDropboxStore sharedStore];
    [dropboxStore removeObserver:self forKeyPath:@"allBibFilePaths"];
    [_bibFilePaths release];
    [_selectedIndexes release];
    [super dealloc];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    BDSKDropboxStore *dropboxStore = [BDSKDropboxStore sharedStore];
    [dropboxStore updateAllBibFilePaths];
    [self updateBibFilePaths];
    [dropboxStore addObserver:self forKeyPath:@"allBibFilePaths" options:0 context:nil];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    BDSKDropboxStore *dropboxStore = [BDSKDropboxStore sharedStore];
    
    if (dropboxStore.allBibFilePaths && dropboxStore.allBibFilePaths.count != 0) {
        return _bibFilePaths.count;
    }
    
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = nil;
    
    if (indexPath.section == 0) {
        
        if (_updating) {
            static NSString *ActivityCellIdentifier = @"ActivityCell";
            cell = [tableView dequeueReusableCellWithIdentifier:ActivityCellIdentifier];
        } else {
            if (_bibFilePaths.count) {
                static NSString *BibFilePathCellIdentifier = @"BibFilePathCell";
                cell = [tableView dequeueReusableCellWithIdentifier:BibFilePathCellIdentifier];
                NSString *text = [_bibFilePaths objectAtIndex:indexPath.row];
                BDSKDropboxStore *dropboxStore = [BDSKDropboxStore sharedStore];
                NSArray *bibFiles = [dropboxStore.allBibFilePaths objectForKey:text];
                if (text.length > 1) text = [text substringFromIndex:1];
                cell.textLabel.text = text;
                if (bibFiles) {
                    cell.detailTextLabel.text = [bibFiles componentsJoinedByString:@", "];
                } else {
                    cell.detailTextLabel.text = @"No *.bib Files Found";
                }
                if ([_selectedIndexes containsObject:[NSIndexPath indexPathWithIndex:indexPath.row]]) {
                    cell.accessoryType = UITableViewCellAccessoryCheckmark;
                } else {
                    cell.accessoryType = UITableViewCellAccessoryNone;
                }
            } else {
                static NSString *NoneFoundCellIdentifier = @"NoneFoundCell";
                cell = [tableView dequeueReusableCellWithIdentifier:NoneFoundCellIdentifier forIndexPath:indexPath];
            }
        }
    }
    
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        if (indexPath.row < _bibFilePaths.count) {
            NSIndexPath *newSelection = [NSIndexPath indexPathWithIndex:indexPath.row];
            NSMutableArray *cellsToReload = [NSMutableArray arrayWithObject:indexPath];
            for (NSIndexPath *previousIndexPath in _selectedIndexes) {
                [cellsToReload addObject:[NSIndexPath indexPathForRow:[previousIndexPath indexAtPosition:0] inSection:0]];
            }
            [_selectedIndexes removeAllObjects];
            [_selectedIndexes addObject:newSelection];
            [self.tableView reloadRowsAtIndexPaths:cellsToReload withRowAnimation:UITableViewRowAnimationFade];
            BDSKDropboxStore *dropboxStore = [BDSKDropboxStore sharedStore];
            dropboxStore.dropboxBibFilePath = _bibFilePaths[indexPath.row];
        }
    }
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {

    if (indexPath.section == 0) {
        if (indexPath.row < _bibFilePaths.count) {
            if ([_selectedIndexes containsObject:[NSIndexPath indexPathWithIndex:indexPath.row]]) {
                return nil;
            }
        }
    }
    
    return indexPath;
}

#pragma mark - Manage directory list

- (void)updateBibFilePaths {

    BDSKDropboxStore *dropboxStore = [BDSKDropboxStore sharedStore];
    
    if (dropboxStore.allBibFilePaths) {
        NSArray *bibFilePaths = [dropboxStore.allBibFilePaths allKeys];
        if (dropboxStore.dropboxBibFilePath && ![dropboxStore.allBibFilePaths objectForKey:dropboxStore.dropboxBibFilePath]) {
            bibFilePaths = [bibFilePaths arrayByAddingObject:dropboxStore.dropboxBibFilePath];
        }
        bibFilePaths = [bibFilePaths sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            return [obj1 compare:obj2];
        }];
        [_selectedIndexes removeAllObjects];
        NSUInteger selectedIndex = [bibFilePaths indexOfObject:dropboxStore.dropboxBibFilePath];
        if (selectedIndex != NSNotFound) {
            [_selectedIndexes addObject:[NSIndexPath indexPathWithIndex:selectedIndex]];
        }
        [_bibFilePaths release];
        _bibFilePaths = [bibFilePaths retain];
        _updating = NO;
    } else {
        [_bibFilePaths release];
        [_selectedIndexes removeAllObjects];
        _updating = YES;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {

    if ([keyPath isEqualToString:@"allBibFilePaths"]) {
        [self updateBibFilePaths];
        [self.tableView reloadData];
    }
}

@end

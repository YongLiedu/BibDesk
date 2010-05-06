//
//  BDSKNotesWindowController.h
//  Bibdesk
//
//  Created by Christiaan Hofman on 2/25/07.
/*
 This software is Copyright (c) 2007-2010
 Christiaan Hofman. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Christiaan Hofman nor the names of any
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

#import <Cocoa/Cocoa.h>
#import "BDSKOutlineView.h"


@interface BDSKNotesWindowController : NSWindowController <BDSKNotesOutlineViewDelegate, NSOutlineViewDataSource, NSSplitViewDelegate> {
    NSURL *url;
    NSMutableArray *notes;
    NSArray *tags;
    double rating;
    CGFloat lastTagsHeight;
    IBOutlet NSOutlineView *outlineView;
    IBOutlet NSTokenField *tokenField;
    IBOutlet NSSplitView *splitView;
    IBOutlet NSObjectController *ownerController;
}

- (id)initWithURL:(NSURL *)aURL;

- (NSArray *)tags;
- (void)setTags:(NSArray *)newTags;
- (double)rating;
- (void)setRating:(double)newRating;

- (IBAction)refresh:(id)sender;
- (IBAction)openInSkim:(id)sender;

@end


@protocol BDSKNotesOutlineViewDelegate <BDSKOutlineViewDelegate>
@optional
- (BOOL)outlineView:(NSOutlineView *)ov canResizeRowByItem:(id)item;
- (void)outlineView:(NSOutlineView *)ov setHeightOfRow:(NSInteger)newHeight byItem:(id)item;
@end


@interface BDSKNotesOutlineView : BDSKOutlineView
SUBCLASS_DELEGATE_DECLARATION(BDSKNotesOutlineViewDelegate)
@end

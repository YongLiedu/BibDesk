//
//  BDSKFilerErrorController.h
//  Bibdesk
//
//  Created by Christiaan Hofman on 1/23/10.
/*
 This software is Copyright (c) 2010-2012
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
 
 - Neither the name of Michael McCracken nor the names of any
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

@class BibDocument;

@interface BDSKFilerErrorController : NSWindowController <NSTableViewDelegate, NSTableViewDataSource> {
	IBOutlet NSTableView *tv;
	IBOutlet NSTextField *infoTextField;
	IBOutlet NSImageView *iconView;
	IBOutlet NSButton *forceCheckButton;
	IBOutlet NSMenu *contextMenu;
    
    BibDocument *document;
    NSString *fieldName;
    NSInteger options;
    
	NSArray *errorInfoDicts;
}

- (id)initWithErrors:(NSArray *)infoDicts forField:(NSString *)field fromDocument:(BibDocument *)doc options:(NSInteger)masks;

- (IBAction)done:(id)sender;
- (IBAction)tryAgain:(id)sender;
- (IBAction)dump:(id)sender;
- (IBAction)selectAll:(id)sender;
- (IBAction)showFile:(id)sender;

- (BibDocument *)sourceDocument;

- (NSArray *)errorInfoDicts;
- (NSUInteger)countOfErrorInfoDicts;
- (id)objectInErrorInfoDictsAtIndex:(NSUInteger)index;

@end

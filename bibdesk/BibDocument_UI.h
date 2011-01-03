//
//  BibDocument_UI.h
//  Bibdesk
//
//  Created by Christiaan Hofman on 5/26/09.
/*
 This software is Copyright (c) 2009-2011
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
 
 - Neither the name of Adam Maxwell nor the names of any
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
#import "BibDocument.h"


@interface BibDocument (UI) <NSSplitViewDelegate, NSMenuDelegate>

- (void)updatePreviews;
- (void)updatePreviewer:(BDSKPreviewer *)aPreviewer;
- (void)updateBottomPreviewPane;
- (void)updateSidePreviewPane;

- (NSArray *)shownFiles;
- (void)updateFileViews;

- (void)setStatus:(NSString *)status;
- (void)setStatus:(NSString *)status immediate:(BOOL)now;

- (void)updateStatus;

- (BOOL)isDisplayingSearchButtons;
- (BOOL)isDisplayingFileContentSearch;
- (BOOL)isDisplayingSearchGroupView;
- (BOOL)isDisplayingWebGroupView;

- (void)insertControlView:(NSView *)controlView atTop:(BOOL)atTop;
- (void)removeControlView:(NSView *)controlView;

- (NSMenu *)columnsMenu;

- (void)registerForNotifications;
- (void)startObserving;
- (void)endObserving;

- (void)handleTableSelectionChangedNotification:(NSNotification *)notification;

@end

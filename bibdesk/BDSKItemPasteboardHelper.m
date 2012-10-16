//
//  BDSKItemPasteboardHelper.m
//
//  Created by Christiaan Hofman on 13/10/06.
/*
 This software is Copyright (c) 2006-2012
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

#import "BDSKItemPasteboardHelper.h"
#import "BibDocument.h"
#import "BibItem.h"
#import "NSArray_BDSKExtensions.h"
#import "NSPasteboard_BDSKExtensions.h"


@interface BDSKItemPasteboardHelper (Private)

- (NSMutableArray *)promisedTypesForPasteboard:(NSPasteboard *)pboard;
- (NSInteger)promisedDragCopyTypeForPasteboard:(NSPasteboard *)pboard;
- (NSString *)promisedBibTeXStringForPasteboard:(NSPasteboard *)pboard;
- (NSArray *)promisedCiteKeysForPasteboard:(NSPasteboard *)pboard;
- (void)removePromisedType:(NSString *)type forPasteboard:(NSPasteboard *)pboard;
- (void)removePromisedTypesForPasteboard:(NSPasteboard *)pboard;

- (void)absolveDelegateResponsibility;
- (void)absolveResponsibility;

- (void)handleApplicationWillTerminateNotification:(NSNotification *)aNotification;

@end

@implementation BDSKItemPasteboardHelper

- (id)init{
    if(self = [super init]){
		promisedPboardTypes = [[NSMutableDictionary alloc] initWithCapacity:2];
		texTask = [[BDSKTeXTask alloc] initWithFileName:@"bibcopy"];
		[texTask setDelegate:self];
        delegate = nil;
        
        [self retain]; // we should stay around as pboard owner
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleApplicationWillTerminateNotification:) name:NSApplicationWillTerminateNotification object:nil];
    }
    return self;
}

- (void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [texTask terminate];
    BDSKDESTROY(texTask);
    BDSKDESTROY(promisedPboardTypes);
    [super dealloc];
}

#pragma mark Delegate

- (id<BDSKItemPasteboardHelperDelegate>)delegate{
    return delegate;
}

- (void)setDelegate:(id<BDSKItemPasteboardHelperDelegate>)newDelegate{
    if (newDelegate == nil && delegate != nil)
        [self absolveDelegateResponsibility];
    delegate = newDelegate;
}

#pragma mark Promising and adding data

- (void)writeObjects:(NSArray *)objects items:(NSArray *)items forDragCopyType:(NSInteger)dragCopyType toPasteboard:(NSPasteboard *)pboard{
	NSMutableArray *types = [NSMutableArray arrayWithObjects:BDSKPasteboardTypePublications, nil];
    NSPasteboardItem *item;
    
    // we should be starting with a cleared pasteboard
    BDSKASSERT([[pboard pasteboardItems] count] == 0);
    BDSKASSERT([promisedPboardTypes objectForKey:[pboard name]] == nil);
    
    if (objects == nil) {
        NSString *type = nil;
        switch (dragCopyType) {
            case BDSKPDFDragCopyType:
                type = NSPasteboardTypePDF;
                break;
            case BDSKRTFDragCopyType:
                type = NSPasteboardTypeRTF;
                break;
            case BDSKLaTeXDragCopyType:
            case BDSKLTBDragCopyType:
                type = NSPasteboardTypeString;
                break;
            default:
                break;
        }
        if (type) {
            item = [[[NSPasteboardItem alloc] init] autorelease];
            [item setDataProvider:self forTypes:[NSArray arrayWithObjects:type, nil]];
            objects = [NSArray arrayWithObjects:item, nil];
            [types addObject:type];
        }
    }
    if ([objects count] > 0) {
        if (dragCopyType == BDSKURLDragCopyType && [objects count] == [items count])
            [pboard writeURLs:objects names:[items valueForKey:@"citeKey"]];
        else
            [pboard writeObjects:objects];
    }
    item = [[[NSPasteboardItem alloc] init] autorelease];
    [item setDataProvider:self forTypes:[NSArray arrayWithObjects:BDSKPasteboardTypePublications, nil]];
    [pboard writeObjects:[NSArray arrayWithObjects:item, nil]];

	NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:items, @"items", types, @"types", [NSNumber numberWithInteger:dragCopyType], @"dragCopyType", nil];
	[promisedPboardTypes setObject:dict forKey:[pboard name]];
}

#pragma mark NSPasteboardItemDataProvider protocol methods

// we generate PDF, RTF, LaTeX, LTB, and archived items data only when they are dropped or pasted
- (void)pasteboard:(NSPasteboard *)pboard item:(NSPasteboardItem *)item provideDataForType:(NSString *)type {
	NSArray *items = [self promisedItemsForPasteboard:pboard];
    
    if([type isEqualToString:BDSKPasteboardTypePublications]){
        NSData *data = nil;
        
        if(items != nil)
            data = [BibItem archivedPublications:items];
        else NSBeep();
        
        [item setData:data forType:BDSKPasteboardTypePublications];
    }else{
        NSString *bibString = nil;
        NSArray *citeKeys = nil;
        if(items != nil){
            bibString = [delegate pasteboardHelper:self bibTeXStringForItems:items];
            citeKeys = [items valueForKey:@"citeKey"];
        }else{
            bibString = [self promisedBibTeXStringForPasteboard:pboard];
            citeKeys = [self promisedCiteKeysForPasteboard:pboard];
        }
        if(bibString != nil){
            NSInteger dragCopyType = [self promisedDragCopyTypeForPasteboard:pboard];
            if([type isEqualToString:NSPasteboardTypePDF]){
                BDSKASSERT(dragCopyType == BDSKPDFDragCopyType);
                NSData *data = nil;
                if([texTask runWithBibTeXString:bibString citeKeys:citeKeys generatedTypes:BDSKGeneratePDF])
                    data = [texTask PDFData];
                [item setData:data forType:NSPasteboardTypePDF];
            }else if([type isEqualToString:NSPasteboardTypeRTF]){
                BDSKASSERT(dragCopyType == BDSKRTFDragCopyType);
                NSData *data = nil;
                if([texTask runWithBibTeXString:bibString citeKeys:citeKeys generatedTypes:BDSKGenerateRTF])
                    data = [texTask RTFData];
                [item setData:data forType:NSPasteboardTypeRTF];
            }else if([type isEqualToString:NSPasteboardTypeString]){
                BDSKASSERT(dragCopyType == BDSKLTBDragCopyType || dragCopyType == BDSKLaTeXDragCopyType);
                NSString *string = nil;
                if(dragCopyType == BDSKLTBDragCopyType){
                    if([texTask runWithBibTeXString:bibString citeKeys:citeKeys generatedTypes:BDSKGenerateLTB])
                        string = [texTask LTBString];
                }else if(dragCopyType == BDSKLaTeXDragCopyType){
                    if([texTask runWithBibTeXString:bibString citeKeys:citeKeys generatedTypes:BDSKGenerateLaTeX])
                        string = [texTask LaTeXString];
                }
                [item setString:string forType:NSPasteboardTypeString];
                if(string == nil) NSBeep();
            }else{
                [item setData:nil forType:type];
                NSBeep();
            }
        }else{
            [item setData:nil forType:type];
            NSBeep();
        }
    }
	[self removePromisedType:type forPasteboard:pboard];
}

- (void)pasteboardFinishedWithDataProvider:(NSPasteboard *)pboard {
	[self removePromisedTypesForPasteboard:pboard];
}

#pragma mark Promised items and types

- (NSArray *)promisedItemsForPasteboard:(NSPasteboard *)pboard {
	return [[promisedPboardTypes objectForKey:[pboard name]] objectForKey:@"items"];
}

- (void)clearPromisedTypesForPasteboard:(NSPasteboard *)pboard {
    for (NSString *type in [[[self promisedTypesForPasteboard:pboard] copy] autorelease]) {
        @try {
            // can raise NSPasteboardCommunicationException
            [pboard setData:nil forType:type];
        }
        @catch(id exception) {
            NSLog(@"ignoring exception %@ in -[%@ %@]", exception, [self class], NSStringFromSelector(_cmd));
        }
    }
    [self removePromisedTypesForPasteboard:pboard];
}

#pragma mark TeXTask delegate

- (BOOL)texTaskShouldStartRunning:(BDSKTeXTask *)aTexTask{
    if([delegate respondsToSelector:@selector(pasteboardHelperWillBeginGenerating:)])
        [delegate pasteboardHelperWillBeginGenerating:self];
	return YES;
}

- (void)texTask:(BDSKTeXTask *)aTexTask finishedWithResult:(BOOL)success{
    if([delegate respondsToSelector:@selector(pasteboardHelperDidEndGenerating:)])
        [delegate pasteboardHelperDidEndGenerating:self];
}

@end


@implementation BDSKItemPasteboardHelper (Private)

static NSPasteboardItem *pasteboardItemForType(NSPasteboard *pboard, NSString *type) {
    for (NSPasteboardItem *item in [pboard pasteboardItems]) {
        if ([[item types] containsObject:type])
            return item;
    }
    return nil;
}

- (BOOL)pasteboardIsValid:(NSPasteboard *)pboard
{
    // see bug #1791132 https://sourceforge.net/tracker/index.php?func=detail&aid=1791132&group_id=61487&atid=497423
    // the system pboard server seems to go down periodically, which gives us various objectForKey:nil exceptions
    static BOOL didAlert = NO;
    BOOL isValid = (nil != [pboard name]);
    
    // only show the panel once; this may be called when closing/quitting after seeing the warning
    if (NO == didAlert && NO == isValid) {
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Unable to access clipboard", @"alert title for system problem")
                                         defaultButton:nil
                                       alternateButton:nil
                                           otherButton:nil
                             informativeTextWithFormat:NSLocalizedString(@"The system clipboard is not working.  If restarting your system does not solve this problem, please report a bug using BibDesk's Help menu.", @"error message when copy/paste fails")];
        [alert runModal];
        didAlert = YES;
    }
    else if (NO == isValid) {
        // more subtle reminder in case the user ignores the warning
        NSBeep();
    }
    return isValid;
}

- (NSMutableArray *)promisedTypesForPasteboard:(NSPasteboard *)pboard {
	return [self pasteboardIsValid:pboard] ? [[promisedPboardTypes objectForKey:[pboard name]] objectForKey:@"types"] : nil;
}

- (NSInteger)promisedDragCopyTypeForPasteboard:(NSPasteboard *)pboard {
	return [self pasteboardIsValid:pboard] ? [[[promisedPboardTypes objectForKey:[pboard name]] objectForKey:@"dragCopyType"] integerValue] : -1;
}

- (NSString *)promisedBibTeXStringForPasteboard:(NSPasteboard *)pboard {
	return [self pasteboardIsValid:pboard] ? [[promisedPboardTypes objectForKey:[pboard name]] objectForKey:@"bibTeXString"] : nil;
}

- (NSArray *)promisedCiteKeysForPasteboard:(NSPasteboard *)pboard {
	return [self pasteboardIsValid:pboard] ? [[promisedPboardTypes objectForKey:[pboard name]] objectForKey:@"citeKeys"] : nil;
}

- (void)removePromisedType:(NSString *)type forPasteboard:(NSPasteboard *)pboard {
	NSMutableArray *types = [self promisedTypesForPasteboard:pboard];
	[types removeObject:type];
	if([types count] == 0)
		[self removePromisedTypesForPasteboard:pboard];
}

- (void)removePromisedTypesForPasteboard:(NSPasteboard *)pboard {
    if ([self pasteboardIsValid:pboard]) {
        [promisedPboardTypes removeObjectForKey:[pboard name]];
        if([promisedPboardTypes count] == 0 && promisedPboardTypes != nil && delegate == nil)   
            [self absolveResponsibility];
    }
}

- (void)absolveDelegateResponsibility{
    if(delegate == nil)
        return;
    
	for (NSString *name in [promisedPboardTypes allKeys]) {
        NSPasteboard *pboard = [NSPasteboard pasteboardWithName:name];
        
        // if we have BDSKPasteboardTypePublications, call to pasteboard:item:provideDataForType: will make this array go away
        NSMutableArray *types = [self promisedTypesForPasteboard:pboard];
        
        if([types containsObject:BDSKPasteboardTypePublications])
            [self pasteboard:pboard item:pasteboardItemForType(pboard, BDSKPasteboardTypePublications) provideDataForType:BDSKPasteboardTypePublications];
        
        // now operate on any remaining types
        types = [self promisedTypesForPasteboard:pboard];
        
        if([types count]){
            NSArray *items = [self promisedItemsForPasteboard:pboard];
            NSString *bibString = nil;
            if(items != nil)
                bibString = [delegate pasteboardHelper:self bibTeXStringForItems:items];
            if(bibString != nil){
                NSMutableDictionary *dict = [promisedPboardTypes objectForKey:name];
                [dict setObject:bibString forKey:@"bibTeXString"];
                [dict setObject:[items valueForKey:@"citeKey"] forKey:@"citeKeys"];
                [dict removeObjectForKey:@"items"];
            }else{
                [self clearPromisedTypesForPasteboard:pboard];
            }
        }
    }
    delegate = nil;
    if([promisedPboardTypes count] == 0)
        [self absolveResponsibility];
}

- (void)absolveResponsibility {
    if(promisedPboardTypes != nil && delegate == nil){
        [promisedPboardTypes release];
        promisedPboardTypes = nil; // this is a sign that we have released ourselves
        [texTask terminate];
        [texTask release];
        texTask = nil;
        [self autorelease]; // using release leads to a crash
    }
}

- (void)handleApplicationWillTerminateNotification:(NSNotification *)aNotification{
    // the built-in AppKit variant of this comes too late, when the temporary workingDir of the texTask is already removed
	for (NSString *name in [promisedPboardTypes allKeys]) {
        NSPasteboard *pboard = [NSPasteboard pasteboardWithName:name];
        NSArray *types = [[self promisedTypesForPasteboard:pboard] copy]; // we need to copy as types can be removed
        for (NSString *type in types)
            [self pasteboard:pboard item:pasteboardItemForType(pboard, type) provideDataForType:type];
        [types release];
    }
}

@end

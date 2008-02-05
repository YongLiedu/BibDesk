//
//  BibDocument+Scripting.m
//  BibDesk
//
//  Created by Sven-S. Porst on Thu Jul 08 2004.
/*
 This software is Copyright (c) 2004-2008
 Sven-S. Porst. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 - Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in
 the documentation and/or other materials provided with the
 distribution.
 
 - Neither the name of Sven-S. Porst nor the names of any
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
#import "BibDocument+Scripting.h"
#import "BibDocument_Groups.h"
#import "BibAuthor.h"
#import "BibItem.h"
#import "BDSKMacro.h"
#import "BDSKTeXTask.h"
#import "BDSKItemPasteboardHelper.h"
#import "BDSKOwnerProtocol.h"
#import "BDSKPublicationsArray.h"
#import "BDSKGroup.h"
#import "BDSKSharedGroup.h"
#import "BDSKURLGroup.h"
#import "BDSKScriptGroup.h"
#import "BDSKSearchGroup.h"
#import "BDSKSmartGroup.h"
#import "BDSKStaticGroup.h"
#import "BDSKCategoryGroup.h"
#import "BDSKWebGroup.h"
#import "BDSKGroupsArray.h"
#import "NSObject_BDSKExtensions.h"
#import "NSArray_BDSKExtensions.h"
#import "BDSKMacroResolver.h"
#import "BDSKMacroResolver+Scripting.h"
#import "BDSKPreviewer.h"
#import "BibAuthor.h"
#import "BibAuthor+Scripting.h"
#import "BDSKTypeManager.h"
#import <Quartz/Quartz.h>
#import <OmniFoundation/OFCFCallbacks.h>


const CFArrayCallBacks BDSKCaseInsensitiveStringArrayCallBacks = {
    0,
    OFNSObjectRetain,
    OFCFTypeRelease,
    OFCFTypeCopyDescription,
    OFCaseInsensitiveStringIsEqual
};

@implementation BibDocument (Scripting)

+ (BOOL)accessInstanceVariablesDirectly {
	return NO;
}

// fix a bug in Apple's implementation, which ignores the file type (for export)
- (id)handleSaveScriptCommand:(NSScriptCommand *)command {
	NSDictionary *args = [command evaluatedArguments];
    id fileURL = [args objectForKey:@"File"];
    id fileType = [args objectForKey:@"FileType"];
    if ([fileType isEqualToString:@"BibTeX"]) {
        fileType = BDSKBibTeXDocumentType;
        NSMutableDictionary *arguments = [[command arguments] mutableCopy];
        [arguments setObject:fileType forKey:@"FileType"];
        [command setArguments:arguments];
        [arguments release];
    } else if ([fileType isEqualToString:@"Minimal BibTeX"]) {
        fileType = BDSKMinimalBibTeXDocumentType;
        NSMutableDictionary *arguments = [[command arguments] mutableCopy];
        [arguments setObject:fileType forKey:@"FileType"];
        [command setArguments:arguments];
        [arguments release];
    } else if ([fileType isEqualToString:@"RIS"]) {
        fileType = BDSKRISDocumentType;
        NSMutableDictionary *arguments = [[command arguments] mutableCopy];
        [arguments setObject:fileType forKey:@"FileType"];
        [command setArguments:arguments];
        [arguments release];
    }
    if ([fileType isEqualToString:@"BibTeX"]) {
        fileType = BDSKBibTeXDocumentType;
        NSMutableDictionary *arguments = [[command arguments] mutableCopy];
        [arguments setObject:fileType forKey:@"FileType"];
        [command setArguments:arguments];
        [arguments release];
    }
    if (fileURL) {
        if ([fileURL isKindOfClass:[NSURL class]] == NO) {
            [command setScriptErrorNumber:NSArgumentsWrongScriptError];
            [command setScriptErrorString:@"The file is not a file or alias."];
        } else {
            NSArray *fileExtensions = [[NSDocumentController sharedDocumentController] fileExtensionsFromType:fileType ? fileType : [self fileType]];
            NSString *extension = [[fileURL path] pathExtension];
            if (extension == nil) {
                extension = [fileExtensions objectAtIndex:0];
                fileURL = [NSURL fileURLWithPath:[[fileURL path] stringByAppendingPathExtension:extension]];
            }
            if ([fileExtensions containsObject:[extension lowercaseString]] == NO) {
                [command setScriptErrorNumber:NSArgumentsWrongScriptError];
                [command setScriptErrorString:[NSString stringWithFormat:@"Invalid file extension for this file type."]];
            } else if (fileType) {
                if ([self saveToURL:fileURL ofType:fileType forSaveOperation:NSSaveToOperation error:NULL] == NO) {
                    [command setScriptErrorNumber:NSInternalScriptError];
                    [command setScriptErrorString:@"Unable to export."];
                }
            } else if ([self saveToURL:fileURL ofType:[self fileType] forSaveOperation:NSSaveAsOperation error:NULL] == NO) {
                [command setScriptErrorNumber:NSInternalScriptError];
                [command setScriptErrorString:@"Unable to save."];
            }
        }
    } else if (fileType) {
        [command setScriptErrorNumber:NSArgumentsWrongScriptError];
        [command setScriptErrorString:@"Missing file argument."];
    } else {
        return [super handleSaveScriptCommand:command];
    }
    return nil;
}

- (id)handlePrintScriptCommand:(NSScriptCommand *)command {
    if([currentPreviewView isEqual:previewerBox] || [currentPreviewView isEqual:previewBox]) {
        // we let the PDFView handle printing
        
        NSDictionary *args = [command evaluatedArguments];
        id settings = [args objectForKey:@"PrintSettings"];
        // PDFView does not allow printing without showing the dialog, so we just ignore that setting
        
        NSPrintInfo *printInfo = [self printInfo];
        PDFView *pdfView = (PDFView *)[(NSBox *)currentPreviewView contentView];
        
        if ([settings isKindOfClass:[NSDictionary class]]) {
            settings = [[settings mutableCopy] autorelease];
            id value;
            if (value = [settings objectForKey:NSPrintDetailedErrorReporting])
                [settings setObject:[NSNumber numberWithBool:[value intValue] == 'lwdt'] forKey:NSPrintDetailedErrorReporting];
            if ((value = [settings objectForKey:NSPrintPrinterName]) && (value = [NSPrinter printerWithName:value]))
                [settings setObject:value forKey:NSPrintPrinter];
            if ([settings objectForKey:NSPrintFirstPage] || [settings objectForKey:NSPrintLastPage]) {
                [settings setObject:[NSNumber numberWithBool:NO] forKey:NSPrintAllPages];
                if ([settings objectForKey:NSPrintFirstPage] == nil)
                    [settings setObject:[NSNumber numberWithInt:1] forKey:NSPrintLastPage];
                if ([settings objectForKey:NSPrintLastPage] == nil)
                    [settings setObject:[NSNumber numberWithInt:[[pdfView document] pageCount]] forKey:NSPrintLastPage];
            }
            [[printInfo dictionary] addEntriesFromDictionary:settings];
        }
        
        [pdfView printWithInfo:printInfo autoRotate:NO];
        
        return nil;
    } else {
        return [super handlePrintScriptCommand:command];
    }
}

#pragma mark Publications

- (unsigned int)countOfPublications {
    return [[self publications] count];
}

- (BibItem *)objectInPublicationsAtIndex:(unsigned int)idx {
    return [self valueInPublicationsAtIndex:idx];
}

- (BibItem *)valueInPublicationsAtIndex:(unsigned int)idx {
    return [publications objectAtIndex:idx];
}

- (void)insertInPublications:(BibItem *)pub  atIndex:(unsigned int)idx {
    if ([pub owner])
        pub = [[pub copyWithMacroResolver:[self macroResolver]] autorelease];
    [self insertPublication:pub atIndex:idx];
	[[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
}

- (void)insertInPublications:(BibItem *)pub {
	[self addPublication:pub];
	[[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
}

- (void)insertObject:(BibItem *)pub inPublicationsAtIndex:(unsigned int)idx {
    return [self insertInPublications:pub atIndex:idx];
}

- (void)removeFromPublicationsAtIndex:(unsigned int)idx {
	[self removePublicationsAtIndexes:[NSIndexSet indexSetWithIndex:idx]];
	[[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
}

- (void)removeObjectFromPublicationsAtIndex:(unsigned int)idx {
    return [self removeFromPublicationsAtIndex:idx];
}

#pragma mark Macros

- (BDSKMacro *)valueInMacrosWithName:(NSString *)aName {
    return [[self macroResolver] valueInMacrosWithName:aName];
}

- (NSArray *)macros {
    return [[self macroResolver] macros];
}

#pragma mark Authors and Editors

- (NSArray *)authors {
    return [BibAuthor authorsInPublications:[self publications]];
}

- (BibAuthor *)valueInAuthorsWithName:(NSString *)aName {
    return [BibAuthor authorWithName:aName inPublications:[self publications]];
}

- (NSArray *)editors {
    return [BibAuthor editorsInPublications:[self publications]];
}

- (BibAuthor *)valueInEditorsWithName:(NSString *)aName {
    return [BibAuthor editorWithName:aName inPublications:[self publications]];
}

#pragma mark Groups

- (unsigned int)countOfGroups {
    return [groups count];
}

- (BDSKGroup *)valueInGroupsAtIndex:(unsigned int)idx {
    return [groups objectAtIndex:idx];
}

- (BDSKGroup *)objectInGroupsAtIndex:(unsigned int)idx {
    return [self valueInGroupsAtIndex:idx];
}

- (BDSKGroup *)valueInGroupsWithName:(NSString *)name {
    unsigned int idx = [[groups valueForKey:@"stringValue"] indexOfObject:name];
    return idx == NSNotFound ? nil : [groups objectAtIndex:idx];
}


- (unsigned int)countOfStaticGroups {
    return [[groups staticGroups] count];
}

- (BDSKGroup *)valueInStaticGroupsAtIndex:(unsigned int)idx {
    return [[groups staticGroups] objectAtIndex:idx];
}

- (BDSKGroup *)objectInStaticGroupsAtIndex:(unsigned int)idx {
    return [self valueInGroupsAtIndex:idx];
}

- (BDSKGroup *)valueInStaticGroupsWithName:(NSString *)name {
    unsigned int idx = [[[groups staticGroups] valueForKey:@"name"] indexOfObject:name];
    return idx == NSNotFound ? nil : [[groups staticGroups] objectAtIndex:idx];
}


- (unsigned int)countOfSmartGroups {
    return [[groups smartGroups] count];
}

- (BDSKGroup *)valueInSmartGroupsAtIndex:(unsigned int)idx {
    return [[groups smartGroups] objectAtIndex:idx];
}

- (BDSKGroup *)objectInSmartGroupsAtIndex:(unsigned int)idx {
    return [self valueInSmartGroupsAtIndex:idx];
}

- (BDSKGroup *)valueInSmartGroupsWithName:(NSString *)name {
    unsigned int idx = [[[groups smartGroups] valueForKey:@"name"] indexOfObject:name];
    return idx == NSNotFound ? nil : [[groups smartGroups] objectAtIndex:idx];
}


- (unsigned int)countOfFieldGroups {
    return [[groups categoryGroups] count];
}

- (BDSKGroup *)valueInFieldGroupsAtIndex:(unsigned int)idx {
    return [[groups categoryGroups] objectAtIndex:idx];
}

- (BDSKGroup *)objectInFieldGroupsAtIndex:(unsigned int)idx {
    return [self valueInFieldGroupsAtIndex:idx];
}

- (BDSKGroup *)valueInFieldGroupsWithName:(NSString *)name {
    id field = [self currentGroupField];
    NSArray *names = [[groups categoryGroups] valueForKey:@"name"];
    id fuzzyName = name;
    NSMutableArray *fuzzyNames = nil;
    if ([field isPersonField]) {
        fuzzyNames = (NSMutableArray *)CFArrayCreateMutable(kCFAllocatorDefault, [names count], &BDSKAuthorFuzzyArrayCallBacks);
        fuzzyName = [NSString isEmptyString:name] ? [BibAuthor emptyAuthor] : [BibAuthor authorWithName:name andPub:nil];
    } else {
        fuzzyNames = (NSMutableArray *)CFArrayCreateMutable(kCFAllocatorDefault, [names count], &BDSKCaseInsensitiveStringArrayCallBacks);
    }
    [fuzzyNames addObjectsFromArray:names];
    unsigned int idx = [fuzzyNames indexOfObject:fuzzyName];
    [fuzzyNames release];
    return idx == NSNotFound ? nil : [[groups categoryGroups] objectAtIndex:idx];
}


- (unsigned int)countOfExternalFileGroups {
    return [[groups URLGroups] count];
}

- (BDSKGroup *)valueInExternalFileGroupsAtIndex:(unsigned int)idx {
    return [[groups URLGroups] objectAtIndex:idx];
}

- (BDSKGroup *)objectInExternalFileGroupsAtIndex:(unsigned int)idx {
    return [self valueInExternalFileGroupsAtIndex:idx];
}

- (BDSKGroup *)valueInExternalFileGroupsWithName:(NSString *)name {
    unsigned int idx = [[[groups URLGroups] valueForKey:@"name"] indexOfObject:name];
    return idx == NSNotFound ? nil : [[groups URLGroups] objectAtIndex:idx];
}


- (unsigned int)countOfScriptGroups {
    return [[groups scriptGroups] count];
}

- (BDSKGroup *)valueInScriptGroupsAtIndex:(unsigned int)idx {
    return [[groups scriptGroups] objectAtIndex:idx];
}

- (BDSKGroup *)objectInScriptGroupsAtIndex:(unsigned int)idx {
    return [self valueInScriptGroupsAtIndex:idx];
}

- (BDSKGroup *)valueInScriptGroupsWithName:(NSString *)name {
    unsigned int idx = [[[groups scriptGroups] valueForKey:@"name"] indexOfObject:name];
    return idx == NSNotFound ? nil : [[groups scriptGroups] objectAtIndex:idx];
}


- (unsigned int)countOfSharedGroups {
    return [[groups sharedGroups] count];
}

- (BDSKGroup *)valueInSharedGroupsAtIndex:(unsigned int)idx {
    return [[groups sharedGroups] objectAtIndex:idx];
}

- (BDSKGroup *)objectInSharedGroupsAtIndex:(unsigned int)idx {
    return [self valueInSharedGroupsAtIndex:idx];
}

- (BDSKGroup *)valueInSharedGroupsWithName:(NSString *)name {
    unsigned int idx = [[[groups sharedGroups] valueForKey:@"name"] indexOfObject:name];
    return idx == NSNotFound ? nil : [[groups sharedGroups] objectAtIndex:idx];
}


- (unsigned int)countOfLibraryGroups {
    return 1;
}

- (BDSKGroup *)valueInLibraryGroupsAtIndex:(unsigned int)idx {
    return [[self groups] libraryGroup];
}

- (BDSKGroup *)objectInLibraryGroupsAtIndex:(unsigned int)idx {
    return [[self groups] libraryGroup];
}

- (BDSKGroup *)valueInLibraryGroupsWithName:(NSString *)name {
    BDSKGroup *group = [[self groups] libraryGroup];
    return [[group name] isEqualToString:name] ? group : nil;
}


- (unsigned int)countOfLastImportGroups {
    BDSKGroup *group = [[self groups] lastImportGroup];
    return [group count] ? 1 : 0;
}

- (BDSKGroup *)valueInLastImportGroupsAtIndex:(unsigned int)idx {
    return [[self groups] lastImportGroup];
}

- (BDSKGroup *)objectInLastImportGroupsAtIndex:(unsigned int)idx {
    return [[self groups] lastImportGroup];
}

- (BDSKGroup *)valueInLastImportGroupsWithName:(NSString *)name {
    BDSKGroup *group = [[self groups] lastImportGroup];
    return [[group name] isEqualToString:name] && [group count] ? group : nil;
}


- (unsigned int)countOfWebGroups {
    return [[self groups] webGroup] ? 1 : 0;
}

- (BDSKGroup *)valueInWebGroupsAtIndex:(unsigned int)idx {
    return [[self groups] webGroup];
}

- (BDSKGroup *)objectInWebGroupsAtIndex:(unsigned int)idx {
    return [[self groups] webGroup];
}

- (BDSKGroup *)valueInWebGroupsWithName:(NSString *)name {
    BDSKGroup *group = [[self groups] webGroup];
    return [[group name] isEqualToString:name] ? group : nil;
}

#pragma mark Properties

- (NSArray*) selection { 
    return [self selectedPublications];
}

- (void) setSelection: (NSArray *) newSelection {
	// on Tiger: debugging revealed that we get an array of NSIndexSpecifiers and not of BibItem
    // the index is relative to all the publications the document (AS container), not the shownPublications
	NSArray *pubsToSelect = [[newSelection lastObject] isKindOfClass:[BibItem class]] ? newSelection : [publications objectsAtIndexSpecifiers:newSelection];
	[self selectPublications:pubsToSelect];
}

- (NSTextStorage*) textStorageForPublications:(NSArray *)pubs {
    NSPasteboard *pboard = [NSPasteboard pasteboardWithUniqueName];
    [pboardHelper declareType:NSRTFPboardType dragCopyType:BDSKRTFDragCopyType forItems:pubs forPasteboard:pboard];
    NSData *data = [pboard dataForType:NSRTFPboardType];
    [pboardHelper clearPromisedTypesForPasteboard:pboard];
    
    if(data == nil) return [[[NSTextStorage alloc] init] autorelease];
    	
	return [[[NSTextStorage alloc] initWithRTF:data documentAttributes:NULL] autorelease];
}

- (id)clipboard {
    NSScriptClassDescription *containerClassDescription = (NSScriptClassDescription *)[NSClassDescription classDescriptionForClass:[NSApp class]];
    return [[[NSPropertySpecifier allocWithZone: [self zone]] 
          initWithContainerClassDescription: containerClassDescription 
                         containerSpecifier: nil // the application is the null container
                                        key: @"clipboard"] autorelease];
}

@end

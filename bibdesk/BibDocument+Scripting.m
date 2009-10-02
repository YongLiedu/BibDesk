//
//  BibDocument+Scripting.m
//  BibDesk
//
//  Created by Sven-S. Porst on Thu Jul 08 2004.
/*
 This software is Copyright (c) 2004-2009
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
#import "BDSKItemPasteboardHelper.h"
#import "BDSKOwnerProtocol.h"
#import "BDSKPublicationsArray.h"
#import "BDSKGroup.h"
#import "BDSKGroup+Scripting.h"
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
#import "NSWorkspace_BDSKExtensions.h"
#import "BDSKServerInfo.h"
#import "BDSKBibTeXParser.h"


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
    if (fileURL) {
        if ([fileURL isKindOfClass:[NSURL class]] == NO) {
            [command setScriptErrorNumber:NSArgumentsWrongScriptError];
            [command setScriptErrorString:@"The file is not a file or alias."];
        } else {
            NSArray *fileExtensions = [[NSDocumentController sharedDocumentController] fileExtensionsFromType:fileType ?: [self fileType]];
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
    if (bottomPreviewDisplay == BDSKPreviewDisplayTeX) {
        // we let the PDFView handle printing
        
        NSDictionary *args = [command evaluatedArguments];
        id settings = [args objectForKey:@"PrintSettings"];
        // PDFView does not allow printing without showing the dialog, so we just ignore that setting
        
        NSPrintInfo *printInfo = [self printInfo];
        PDFView *pdfView = [previewer pdfView];
        
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

- (id)newScriptingObjectOfClass:(Class)class forValueForKey:(NSString *)key withContentsValue:(id)contentsValue properties:(NSDictionary *)properties {
    if ([class isKindOfClass:[BDSKGroup class]]) {
        id group = nil;
        if ([class isKindOfClass:[BDSKScriptGroup class]]) {
            NSString *path = [[properties objectForKey:@"scriptURL"] path];
            NSString *arguments = [properties objectForKey:@"scriptingScriptArguments"];
            if (path == nil) {
                NSScriptCommand *cmd = [NSScriptCommand currentCommand];
                [cmd setScriptErrorNumber:NSRequiredArgumentsMissingScriptError]; 
                [cmd setScriptErrorString:NSLocalizedString(@"New script groups need a script file.", @"Error description")];
                return nil;
            }
            NSMutableDictionary *mutableProperties = [[properties mutableCopy] autorelease];
            [mutableProperties removeObjectForKey:@"scriptURL"];
            [mutableProperties removeObjectForKey:@"scriptingScriptArguments"];
            properties = mutableProperties;
            group = [[BDSKScriptGroup alloc] initWithName:nil scriptPath:path scriptArguments:arguments scriptType:[[NSWorkspace sharedWorkspace] isAppleScriptFileAtPath:path] ? BDSKAppleScriptType : BDSKShellScriptType];
        } else if ([class isKindOfClass:[BDSKSearchGroup class]]) {
            NSString *aType = BDSKSearchGroupEntrez;
            NSDictionary *info = [properties objectForKey:@"scriptingServerInfo"];
            if ([properties objectForKey:@"type"]) {
                switch ([[info objectForKey:@"type"] intValue]) {
                    case BDSKScriptingSearchGroupEntrez: aType = BDSKSearchGroupEntrez; break;
                    case BDSKScriptingSearchGroupZoom: aType = BDSKSearchGroupZoom; break;
                    case BDSKScriptingSearchGroupISI: aType = BDSKSearchGroupISI; break;
                    case BDSKScriptingSearchGroupDBLP: aType = BDSKSearchGroupDBLP; break;
                    default: break;
                }
            }
            group = [[BDSKSearchGroup alloc] initWithType:aType serverInfo:[BDSKServerInfo defaultServerInfoWithType:aType] searchTerm:nil];
        } else if ([class isKindOfClass:[BDSKURLGroup class]]) {
            NSURL *theURL = [NSURL URLWithString:@"http://"];
            NSMutableDictionary *mutableProperties = [[properties mutableCopy] autorelease];
            if ([properties objectForKey:@"fileURL"]) {
                theURL = [properties objectForKey:@"fileURL"];
                [mutableProperties removeObjectForKey:@"fileURL"];
            } else if ([properties objectForKey:@"URLString"]) {
                theURL = [NSURL URLWithString:[properties objectForKey:@"URLString"]];
                [mutableProperties removeObjectForKey:@"URLString"];
            } else {
                NSScriptCommand *cmd = [NSScriptCommand currentCommand];
                [cmd setScriptErrorNumber:NSRequiredArgumentsMissingScriptError]; 
                [cmd setScriptErrorString:NSLocalizedString(@"New external file groups need a file or a URL.", @"Error description")];
                return nil;
            }
            properties = mutableProperties;
            group = [[BDSKURLGroup alloc] initWithURL:theURL];
        } else if ([class isKindOfClass:[BDSKStaticGroup class]] || [class isKindOfClass:[BDSKSmartGroup class]]) {
            group = [[class alloc] init];
        } else {
            NSScriptCommand *cmd = [NSScriptCommand currentCommand];
            [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
            [cmd setScriptErrorString:NSLocalizedString(@"Groups must be created with a specific class.", @"Error description")];
        }
        if ([properties count])
            [group setScriptingProperties:properties];
        return group;
    } else if ([class isKindOfClass:[BibItem class]]) {
        BibItem *item = nil;
        NSString *bibtexString = [properties objectForKey:@"bibTeXString"];
        if (bibtexString) {
            NSError *error = nil;
            BOOL isPartialData;
            NSArray *newPubs = [BDSKBibTeXParser itemsFromString:bibtexString document:self isPartialData:&isPartialData error:&error];
            if (isPartialData) {
                NSScriptCommand *cmd = [NSScriptCommand currentCommand];
                [cmd setScriptErrorNumber:NSInternalScriptError];
                [cmd setScriptErrorString:[NSString stringWithFormat:NSLocalizedString(@"BibDesk failed to process the BibTeX entry %@ with error %@. It may be malformed.",@"Error description"), bibtexString, [error localizedDescription]]];
                return nil;
            }
            item = [[newPubs objectAtIndex:0] retain];
            properties = [[properties mutableCopy] autorelease];
            [(NSMutableDictionary *)properties removeObjectForKey:@"bibTeXString"];
        } else if (contentsValue) {
            [NSString setMacroResolverForUnarchiving:[self macroResolver]];
            item = [[NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:contentsValue]] retain];
            [NSString setMacroResolverForUnarchiving:nil];
            [item setMacroResolver:[self macroResolver]];
        } else {
            item = [[BibItem alloc] init];
        }
        if ([properties count])
            [item setScriptingProperties:properties];
        return item;
    }
    return [super newScriptingObjectOfClass:class forValueForKey:key withContentsValue:contentsValue properties:properties];
}

- (id)copyScriptingValue:(id)value forKey:(NSString *)key withProperties:(NSDictionary *)properties {
    if ([key isEqualToString:@"scriptingPublications"]) {
        [NSString setMacroResolverForUnarchiving:[self macroResolver]];
        id copiedValue = [[NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:value]] retain];
        [NSString setMacroResolverForUnarchiving:nil];
        [copiedValue makeObjectsPerformSelector:@selector(setMacroResolver:) withObject:[self macroResolver]];
        if ([properties count])
            [copiedValue makeObjectsPerformSelector:@selector(setScriptingProperties:) withObject:properties];
        return copiedValue;
    } else if ([[NSSet setWithObjects:@"scriptingGroups", @"staticGroups", @"smartGroups", @"externalFileGroups", @"scriptGroups", @"searchGroups", nil] containsObject:key]) {
        NSMutableArray *copiedValue = [[NSMutableArray alloc] init];
        for (id group in value) {
            id copiedGroup = nil;
            if ([group isStatic]) {
                copiedGroup = [[BDSKStaticGroup alloc] initWithName:[group name] publications:([group document] == self ? [group publications] : nil)];
            } else if ([group isSmart]) {
                copiedGroup = [[BDSKSmartGroup alloc] initWithName:[group name] count:[group count] filter:[group filter]];
            } else if ([group isURL]) {
                copiedGroup = [[BDSKURLGroup alloc] initWithName:[group name] URL:[group URL]];
            } else if ([group isScript]) {
                copiedGroup = [[BDSKScriptGroup alloc] initWithName:[group name] scriptPath:[group scriptPath] scriptArguments:[group scriptArguments] scriptType:[group scriptType]];
            } else if ([group isSearch]) {
                copiedGroup = [[BDSKSearchGroup alloc] initWithType:[group type] serverInfo:[group serverInfo] searchTerm:[group searchTerm]];
            }
            if (copiedGroup == nil) {
                NSScriptCommand *cmd = [NSScriptCommand currentCommand];
                [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
                [cmd setScriptErrorString:NSLocalizedString(@"Cannot add group.",@"Error description")];
                [copiedValue release];
                copiedValue = nil;
            } else {
                if ([properties count])
                    [copiedGroup setScriptingProperties:properties];
                [copiedValue addObject:copiedGroup];
                [copiedGroup release];
            }
            return copiedValue;
        }
    } else if ([[NSSet setWithObjects:@"libraryGroups", @"lastImportGroups", @"fieldGroups", @"sharedGroups", @"webGroups", nil] containsObject:key]) {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot add group.",@"Error description")];
        return nil;
    }
    return [super copyScriptingValue:value forKey:key withProperties:properties];
}

#pragma mark Publications

- (id)valueInScriptingPublicationsWithUniqueID:(NSString *)aUniqueID {
	NSURL *identifierURL = [NSURL URLWithString:aUniqueID];
    id item = identifierURL ? [[self publications] itemForIdentifierURL:identifierURL] : nil;
    return item ?: [NSNull null];
}

- (NSArray *)scriptingPublications {
    return [self publications];
}

- (void)insertInScriptingPublications:(BibItem *)pub {
	if ([pub macroResolver] == nil || [pub macroResolver] == macroResolver) {
        [self addPublication:pub];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    } else if ([[pub owner] isEqual:self] == NO) {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot add publication from another document or external group.",@"Error description")];
    } 
}

- (void)insertObject:(BibItem *)pub inScriptingPublicationsAtIndex:(NSUInteger)idx {
	if ([pub macroResolver] == nil || [pub macroResolver] == macroResolver) {
        [self insertPublication:pub atIndex:idx];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    } else if ([[pub owner] isEqual:self] == NO) {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot add publication from another document or external group, use duplicate.",@"Error description")];
    } 
}

- (void)removeObjectFromScriptingPublicationsAtIndex:(NSUInteger)idx {
	[self removePublicationsAtIndexes:[NSIndexSet indexSetWithIndex:idx]];
	[[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
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

- (NSArray *)scriptingGroups {
    return [groups allChildren];
}

- (BDSKGroup *)valueInScriptingGroupsWithUniqueID:(NSString *)aUniqueID {
    NSArray *allGroups = [self scriptingGroups];
    NSUInteger idx = [[allGroups valueForKey:@"scriptingUniqueID"] indexOfObject:aUniqueID];
    return idx == NSNotFound ? nil : [allGroups objectAtIndex:idx];
}

- (BDSKGroup *)valueInScriptingGroupsWithName:(NSString *)name {
    for (BDSKGroup *group in [self scriptingGroups]) {
        if ([[group stringValue] caseInsensitiveCompare:name] == NSOrderedSame)
            return group;
    }
    return nil;
}

- (void)insertInScriptingGroups:(BDSKGroup *)group {
    if ([group document]) {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot add group.",@"Error description")];
        return;
    } else if ([group isSmart]) {
        [groups addSmartGroup:(BDSKSmartGroup *)group];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    } else if ([group isStatic] && [group isKindOfClass:[BDSKLastImportGroup class]] == NO) {
        [groups addStaticGroup:(BDSKStaticGroup *)group];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    } else if ([group isURL]) {
        [groups addURLGroup:(BDSKURLGroup *)group];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    } else if ([group isScript]) {
        [groups addScriptGroup:(BDSKScriptGroup *)group];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    } else if ([group isSearch]) {
        [groups addSearchGroup:(BDSKSearchGroup *)group];
    } else {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot add group.",@"Error description")];
        return;
    }
}

- (void)insertObject:(BDSKGroup *)group inScriptingGroupsAtIndex:(NSUInteger)idx {
    [self insertInScriptingGroups:group];
}

- (void)removeObjectFromScriptingGroupsAtIndex:(NSUInteger)idx {
    BDSKGroup *group = [[groups staticGroups] objectAtIndex:idx];
    if ([group isSmart]) {
        [groups removeSmartGroup:(BDSKSmartGroup *)group];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    } else if ([group isStatic] && [group isEqual:[groups lastImportGroup]] == NO) {
        [groups removeStaticGroup:(BDSKStaticGroup *)group];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    } else if ([group isURL]) {
        [groups removeURLGroup:(BDSKURLGroup *)group];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    } else if ([group isScript]) {
        [groups removeScriptGroup:(BDSKScriptGroup *)group];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    } else if ([group isSearch]) {
        [groups removeSearchGroup:(BDSKSearchGroup *)group];
    } else {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot remove group.",@"Error description")];
        return;
    }
    [self displaySelectedGroups];
}

#pragma mark -

- (NSArray *)staticGroups {
    return [groups staticGroups];
}

- (BDSKStaticGroup *)valueInStaticGroupsWithUniqueID:(NSString *)aUniqueID {
    NSUInteger idx = [[[groups staticGroups] valueForKey:@"scriptingUniqueID"] indexOfObject:aUniqueID];
    return idx == NSNotFound ? nil : [[groups staticGroups] objectAtIndex:idx];
}

- (BDSKStaticGroup *)valueInStaticGroupsWithName:(NSString *)name {
    NSUInteger idx = [[[groups staticGroups] valueForKey:@"name"] indexOfObject:name];
    return idx == NSNotFound ? nil : [[groups staticGroups] objectAtIndex:idx];
}

- (void)insertInStaticGroups:(BDSKStaticGroup *)group {
    if ([group document]) {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot add group.",@"Error description")];
    } else {
        [groups addStaticGroup:group];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    }
}

- (void)insertObject:(BDSKStaticGroup *)group inStaticGroupsAtIndex:(NSUInteger)idx {
    [self insertInStaticGroups:group];
}

- (void)removeObjectFromStaticGroupsAtIndex:(NSUInteger)idx {
	[groups removeStaticGroup:[[groups staticGroups] objectAtIndex:idx]];
	[[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
}

#pragma mark -

- (NSArray *)smartGroups {
    return [groups smartGroups];
}

- (BDSKSmartGroup *)valueInSmartGroupsWithUniqueID:(NSString *)aUniqueID {
    NSUInteger idx = [[[groups smartGroups] valueForKey:@"scriptingUniqueID"] indexOfObject:aUniqueID];
    return idx == NSNotFound ? nil : [[groups smartGroups] objectAtIndex:idx];
}

- (BDSKSmartGroup *)valueInSmartGroupsWithName:(NSString *)name {
    NSUInteger idx = [[[groups smartGroups] valueForKey:@"name"] indexOfObject:name];
    return idx == NSNotFound ? nil : [[groups smartGroups] objectAtIndex:idx];
}

- (void)insertInSmartGroups:(BDSKSmartGroup *)group {
    if ([group document]) {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot add group.",@"Error description")];
    } else {
        [groups addSmartGroup:group];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    }
}

- (void)insertObject:(BDSKSmartGroup *)group inSmartGroupsAtIndex:(NSUInteger)idx {
    [self insertInSmartGroups:group];
}

- (void)removeObjectFromSmartGroupsAtIndex:(NSUInteger)idx {
	[groups removeSmartGroup:[[groups smartGroups] objectAtIndex:idx]];
	[[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
}

#pragma mark -

- (NSArray *)fieldGroups {
    return [groups categoryGroups];
}

- (BDSKCategoryGroup *)valueInFieldGroupsWithUniqueID:(NSString *)aUniqueID {
    NSUInteger idx = [[[groups categoryGroups] valueForKey:@"scriptingUniqueID"] indexOfObject:aUniqueID];
    return idx == NSNotFound ? nil : [[groups categoryGroups] objectAtIndex:idx];
}

- (BDSKCategoryGroup *)valueInFieldGroupsWithName:(NSString *)name {
    if ([[self currentGroupField] isPersonField]) {
        BibAuthor *fuzzyName = [NSString isEmptyString:name] ? [BibAuthor emptyAuthor] : [BibAuthor authorWithName:name andPub:nil];
        for (BDSKCategoryGroup *group in [groups categoryGroups])
            if ([[group name] fuzzyEqual:fuzzyName] == NSOrderedSame)
                return group;
    } else {
        for (BDSKCategoryGroup *group in [groups categoryGroups])
            if ([[group name] caseInsensitiveCompare:name] == NSOrderedSame)
                return group;
    }
    return nil;
}

#pragma mark -

- (NSArray *)externalFileGroups {
    return [groups URLGroups];
}

- (BDSKURLGroup *)valueInExternalFileGroupsWithUniqueID:(NSString *)aUniqueID {
    NSUInteger idx = [[[groups URLGroups] valueForKey:@"scriptingUniqueID"] indexOfObject:aUniqueID];
    return idx == NSNotFound ? nil : [[groups URLGroups] objectAtIndex:idx];
}

- (BDSKURLGroup *)valueInExternalFileGroupsWithName:(NSString *)name {
    NSUInteger idx = [[[groups URLGroups] valueForKey:@"name"] indexOfObject:name];
    return idx == NSNotFound ? nil : [[groups URLGroups] objectAtIndex:idx];
}

- (void)insertInExternalFileGroups:(BDSKURLGroup *)group {
    if ([group document]) {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot add group.",@"Error description")];
    } else {
        [groups addURLGroup:group];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    }
}

- (void)insertObject:(BDSKURLGroup *)group inExternalFileGroupsAtIndex:(NSUInteger)idx {
    [self insertInExternalFileGroups:group];
}

- (void)removeObjectFromExternalFileGroupsAtIndex:(NSUInteger)idx {
	[groups removeURLGroup:[[groups scriptGroups] objectAtIndex:idx]];
	[[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
}

#pragma mark -

- (NSArray *)scriptGroups {
    return [groups scriptGroups];
}

- (BDSKScriptGroup *)valueInScriptGroupsWithUniqueID:(NSString *)aUniqueID {
    NSUInteger idx = [[[groups scriptGroups] valueForKey:@"scriptingUniqueID"] indexOfObject:aUniqueID];
    return idx == NSNotFound ? nil : [[groups scriptGroups] objectAtIndex:idx];
}

- (BDSKScriptGroup *)valueInScriptGroupsWithName:(NSString *)name {
    NSUInteger idx = [[[groups scriptGroups] valueForKey:@"name"] indexOfObject:name];
    return idx == NSNotFound ? nil : [[groups scriptGroups] objectAtIndex:idx];
}

- (void)insertInScriptGroups:(BDSKScriptGroup *)group {
    if ([group document]) {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot add group.",@"Error description")];
    } else {
        [groups addScriptGroup:group];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    }
}

- (void)insertObject:(BDSKScriptGroup *)group inScriptGroupsAtIndex:(NSUInteger)idx {
    [self insertInScriptGroups:group];
}

- (void)removeObjectFromScriptGroupsAtIndex:(NSUInteger)idx {
	[groups removeScriptGroup:[[groups scriptGroups] objectAtIndex:idx]];
	[[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
}

#pragma mark -

- (NSArray *)searchGroups {
    return [groups searchGroups];
}

- (BDSKSearchGroup *)valueInSearchGroupsWithUniqueID:(NSString *)aUniqueID {
    NSUInteger idx = [[[groups searchGroups] valueForKey:@"scriptingUniqueID"] indexOfObject:aUniqueID];
    return idx == NSNotFound ? nil : [[groups searchGroups] objectAtIndex:idx];
}

- (BDSKSearchGroup *)valueInSearchGroupsWithName:(NSString *)name {
    NSUInteger idx = [[[groups searchGroups] valueForKey:@"name"] indexOfObject:name];
    return idx == NSNotFound ? nil : [[groups searchGroups] objectAtIndex:idx];
}

- (void)insertInSearchGroups:(BDSKSearchGroup *)group {
    if ([group document]) {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot add group.",@"Error description")];
    } else {
        [groups addSearchGroup:group];
    }
}

- (void)insertObject:(BDSKSearchGroup *)group inSearchGroupsAtIndex:(NSUInteger)idx {
    [self insertInSearchGroups:group];
}

- (void)removeObjectFromSearchGroupsAtIndex:(NSUInteger)idx {
	[groups removeSearchGroup:[[groups searchGroups] objectAtIndex:idx]];
}

#pragma mark -

- (NSArray *)sharedGroups {
    return [groups sharedGroups];
}

- (BDSKSharedGroup *)valueInSharedGroupsWithUniqueID:(NSString *)aUniqueID {
    NSUInteger idx = [[[groups sharedGroups] valueForKey:@"scriptingUniqueID"] indexOfObject:aUniqueID];
    return idx == NSNotFound ? nil : [[groups sharedGroups] objectAtIndex:idx];
}

- (BDSKSharedGroup *)valueInSharedGroupsWithName:(NSString *)name {
    NSUInteger idx = [[[groups sharedGroups] valueForKey:@"name"] indexOfObject:name];
    return idx == NSNotFound ? nil : [[groups sharedGroups] objectAtIndex:idx];
}

#pragma mark -

- (NSArray *)libraryGroups {
    return [NSArray arrayWithObject:[groups libraryGroup]];
}

- (BDSKGroup *)valueInLibraryGroupsWithUniqueID:(NSString *)aUniqueID {
    BDSKGroup *group = [[self groups] libraryGroup];
    return [[group scriptingUniqueID] isEqualToString:aUniqueID] == NSOrderedSame ? group : nil;
}

- (BDSKGroup *)valueInLibraryGroupsWithName:(NSString *)name {
    BDSKGroup *group = [[self groups] libraryGroup];
    return [[group name] caseInsensitiveCompare:name] == NSOrderedSame ? group : nil;
}

#pragma mark -

- (NSArray *)lastImportGroups {
    BDSKGroup *group = [groups lastImportGroup];
    return [group count] ? [NSArray arrayWithObject:group] : [NSArray array];
}

- (BDSKGroup *)valueInLastImportGroupsWithUniqueID:(NSString *)aUniqueID {
    BDSKGroup *group = [groups lastImportGroup];
    return [[group scriptingUniqueID] isEqualToString:aUniqueID] == NSOrderedSame ? group : nil;
}

- (BDSKGroup *)valueInLastImportGroupsWithName:(NSString *)name {
    BDSKGroup *group = [groups lastImportGroup];
    return [[group name] caseInsensitiveCompare:name] == NSOrderedSame && [group count] ? group : nil;
}

#pragma mark -

- (NSArray *)webGroups {
    return [NSArray arrayWithObjects:[groups webGroup], nil];
}

- (BDSKWebGroup *)valueInWebGroupsWithUniqueID:(NSString *)aUniqueID {
    BDSKWebGroup *group = [groups webGroup];
    return [[group scriptingUniqueID] isEqualToString:aUniqueID] == NSOrderedSame ? group : nil;
}

- (BDSKWebGroup *)valueInWebGroupsWithName:(NSString *)name {
    BDSKWebGroup *group = [groups webGroup];
    return [[group name] caseInsensitiveCompare:name] == NSOrderedSame ? group : nil;
}

#pragma mark Properties

- (NSArray *)selection { 
    return [self selectedPublications];
}

- (void)setSelection:(NSArray *)newSelection {
	// on Tiger: debugging revealed that we get an array of NSIndexSpecifiers and not of BibItem
    // the index is relative to all the publications the document (AS container), not the shownPublications
	NSArray *pubsToSelect = newSelection;
    id lastObject = [newSelection lastObject];
    if ([lastObject isKindOfClass:[BibItem class]] == NO && [lastObject respondsToSelector:@selector(objectsByEvaluatingSpecifier)])
        pubsToSelect = [newSelection arrayByPerformingSelector:@selector(objectsByEvaluatingSpecifier)];
	[self selectPublications:pubsToSelect];
}

- (NSArray *)groupSelection { 
    return [self selectedGroups];
}

- (void)setGroupSelection:(NSArray *)newSelection {
	// on Tiger: debugging revealed that we get an array of NSIndexSpecifiers and not of BibItem
    // the index is relative to all the publications the document (AS container), not the shownPublications
    NSArray *groupsToSelect = newSelection;
    id lastObject = [newSelection lastObject];
    if ([lastObject isKindOfClass:[BDSKGroup class]] == NO && [lastObject respondsToSelector:@selector(objectsByEvaluatingSpecifier)])
        groupsToSelect = [newSelection arrayByPerformingSelector:@selector(objectsByEvaluatingSpecifier)];
    [self selectGroups:groupsToSelect];
}

- (id)clipboard {
    NSScriptClassDescription *containerClassDescription = (NSScriptClassDescription *)[NSClassDescription classDescriptionForClass:[NSApplication class]];
    return [[[NSPropertySpecifier allocWithZone: [self zone]] 
          initWithContainerClassDescription: containerClassDescription 
                         containerSpecifier: nil // the application is the null container
                                        key: @"clipboard"] autorelease];
}

#pragma mark -

// The following "indicesOf..." methods are in support of scripting.  They allow more flexible range and relative specifiers to be used with the different group keys of a SKTDrawDocument.
// The scripting engine does not know about the fact that the "static groups" key is really just a subset of the "groups" key, so script code like "groups from static group 1 to field group 4" don't make sense to it.  But BibDesk does know and can answer such questions itself, with a little work.
// This is copied from Apple's Sketch sample code
- (NSArray *)indicesOfObjectsByEvaluatingRangeSpecifier:(NSRangeSpecifier *)rangeSpec {
    NSString *key = [rangeSpec key];
    NSSet *groupKeys = [NSSet setWithObjects:@"groups", @"staticGroups", @"smartGroups", @"fieldGroups", @"externalFileGroups", @"scriptGroups", @"searchGroups", @"sharedGroups", @"libraryGroups", @"lastImportGroups", @"webGroups", nil];

    if ([groupKeys containsObject:key]) {
        // This is one of the keys we might want to deal with.
        NSScriptObjectSpecifier *startSpec = [rangeSpec startSpecifier];
        NSScriptObjectSpecifier *endSpec = [rangeSpec endSpecifier];
        NSString *startKey = [startSpec key];
        NSString *endKey = [endSpec key];
        NSArray *allGroups = [self scriptingGroups];
        
        if ((startSpec == nil) && (endSpec == nil))
            // We need to have at least one of these...
            return nil;
        
        if ([allGroups count] == 0)
            // If there are no groups, there can be no match.  Just return now.
            return [NSArray array];

        if ((startSpec == nil || [groupKeys containsObject:startKey]) && (endSpec == nil || [groupKeys containsObject:endKey])) {
            NSInteger startIndex;
            NSInteger endIndex;

            // The start and end keys are also ones we want to handle.

            // The strategy here is going to be to find the index of the start and stop object in the full groups array, regardless of what its key is.  Then we can find what we're looking for in that range of the groups key (weeding out objects we don't want, if necessary).

            // First find the index of the first start object in the groups array
            if (startSpec) {
                id startObject = [startSpec objectsByEvaluatingSpecifier];
                if ([startObject isKindOfClass:[NSArray class]]) {
                    startObject = [startObject count] ? [startObject objectAtIndex:0] : nil;
                }
                if (startObject == nil)
                    // Oops.  We could not find the start object.
                    return nil;
                
                startIndex = [allGroups indexOfObjectIdenticalTo:startObject];
                if (startIndex == NSNotFound)
                    // Oops.  We couldn't find the start object in the groups array.  This should not happen.
                    return nil;
                
            } else {
                startIndex = 0;
            }

            // Now find the index of the last end object in the groups array
            if (endSpec) {
                id endObject = [endSpec objectsByEvaluatingSpecifier];
                if ([endObject isKindOfClass:[NSArray class]]) {
                    endObject = [endObject count] ? [endObject lastObject] : nil;
                }
                if (endObject == nil)
                    // Oops.  We could not find the end object.
                    return nil;
                
                endIndex = [allGroups indexOfObjectIdenticalTo:endObject];
                if (endIndex == NSNotFound)
                    // Oops.  We couldn't find the end object in the groups array.  This should not happen.
                    return nil;
                
            } else {
                endIndex = [allGroups count] - 1;
            }

            if (endIndex < startIndex) {
                // Accept backwards ranges gracefully
                NSInteger temp = endIndex;
                endIndex = startIndex;
                startIndex = temp;
            }

            // Now startIndex and endIndex specify the end points of the range we want within the groups array.
            // We will traverse the range and pick the objects we want.
            // We do this by getting each object and seeing if it actually appears in the real key that we are trying to evaluate in.
            NSMutableArray *result = [NSMutableArray array];
            BOOL keyIsGroups = [key isEqual:@"groups"];
            NSArray *rangeKeyObjects = (keyIsGroups ? nil : [self valueForKey:key]);
            id curObj;
            NSUInteger curKeyIndex;
            NSInteger i;

            for (i = startIndex; i <= endIndex; i++) {
                if (keyIsGroups) {
                    [result addObject:[NSNumber numberWithInt:i]];
                } else {
                    curObj = [allGroups objectAtIndex:i];
                    curKeyIndex = [rangeKeyObjects indexOfObjectIdenticalTo:curObj];
                    if (curKeyIndex != NSNotFound)
                        [result addObject:[NSNumber numberWithInt:curKeyIndex]];
                }
            }
            return result;
        }
    }
    return nil;
}

- (NSArray *)indicesOfObjectsByEvaluatingRelativeSpecifier:(NSRelativeSpecifier *)relSpec {
    NSString *key = [relSpec key];
    NSSet *groupKeys = [NSSet setWithObjects:@"groups", @"staticGroups", @"smartGroups", @"fieldGroups", @"externalFileGroups", @"scriptGroups", @"searchGroups", @"sharedGroups", @"libraryGroups", @"lastImportGroups", @"webGroups", nil];

    if ([groupKeys containsObject:key]) {
        // This is one of the keys we might want to deal with.
        NSScriptObjectSpecifier *baseSpec = [relSpec baseSpecifier];
        NSString *baseKey = [baseSpec key];
        NSRelativePosition relPos = [relSpec relativePosition];
        NSArray *allGroups = [self scriptingGroups];
        
        if (baseSpec == nil)
            // We need to have one of these...
            return nil;
        
        if ([allGroups count] == 0)
            // If there are no groups, there can be no match.  Just return now.
            return [NSArray array];

        if ([groupKeys containsObject:baseKey]) {
            NSInteger baseIndex;

            // The base key is also one we want to handle.

            // The strategy here is going to be to find the index of the base object in the full groups array, regardless of what its key is.  Then we can find what we're looking for before or after it.

            // First find the index of the first or last base object in the groups array
            // Base specifiers are to be evaluated within the same container as the relative specifier they are the base of.  That's this document.
            id baseObject = [baseSpec objectsByEvaluatingWithContainers:self];
            if ([baseObject isKindOfClass:[NSArray class]]) {
                if ([baseObject count] == 0)
                    // Oops.  We could not find the base object.
                    return nil;
                
                baseObject = (relPos == NSRelativeBefore ? [baseObject objectAtIndex:0] : [baseObject lastObject]);
            }

            baseIndex = [allGroups indexOfObjectIdenticalTo:baseObject];
            if (baseIndex == NSNotFound)
                // Oops.  We couldn't find the base object in the groups array.  This should not happen.
                return nil;

            // Now baseIndex specifies the base object for the relative spec in the groups array.
            // We will start either right before or right after and look for an object that matches the type we want.
            // We do this by getting each object and seeing if it actually appears in the real key that we are trying to evaluate in.
            NSMutableArray *result = [NSMutableArray array];
            BOOL keyIsGroups = [key isEqual:@"groups"];
            NSArray *relKeyObjects = (keyIsGroups ? nil : [self valueForKey:key]);
            id curObj;
            NSUInteger curKeyIndex;
            NSInteger groupCount = [allGroups count];

            if (relPos == NSRelativeBefore)
                baseIndex--;
            else
                baseIndex++;
            
            while ((baseIndex >= 0) && (baseIndex < groupCount)) {
                if (keyIsGroups) {
                    [result addObject:[NSNumber numberWithInt:baseIndex]];
                    break;
                } else {
                    curObj = [allGroups objectAtIndex:baseIndex];
                    curKeyIndex = [relKeyObjects indexOfObjectIdenticalTo:curObj];
                    if (curKeyIndex != NSNotFound) {
                        [result addObject:[NSNumber numberWithInt:curKeyIndex]];
                        break;
                    }
                }
                if (relPos == NSRelativeBefore)
                    baseIndex--;
                else
                    baseIndex++;
            }

            return result;
        }
    }
    return nil;
}
    
- (NSArray *)indicesOfObjectsByEvaluatingObjectSpecifier:(NSScriptObjectSpecifier *)specifier {
    // We want to handle some range and relative specifiers ourselves in order to support such things as "groups from static group 3 to static group 5" or "static groups from groups 7 to groups 10" or "static group before smart group 1".
    // Returning nil from this method will cause the specifier to try to evaluate itself using its default evaluation strategy.
	
    if ([specifier isKindOfClass:[NSRangeSpecifier class]])
        return [self indicesOfObjectsByEvaluatingRangeSpecifier:(NSRangeSpecifier *)specifier];
    else if ([specifier isKindOfClass:[NSRelativeSpecifier class]])
        return [self indicesOfObjectsByEvaluatingRelativeSpecifier:(NSRelativeSpecifier *)specifier];

    // If we didn't handle it, return nil so that the default object specifier evaluation will do it.
    return nil;
}

@end

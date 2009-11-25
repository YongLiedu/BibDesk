//  BDSKDocumentController.m

//  Created by Christiaan Hofman on 5/31/06.
/*
 This software is Copyright (c) 2006-2009
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

#import "BDSKDocumentController.h"
#import "BDSKStringConstants.h"
#import "BDSKRuntime.h"
#import <AGRegex/AGRegex.h>
#import "BDSKStringEncodingManager.h"
#import "BDSKAppController.h"
#import "BibDocument.h"
#import "BibDocument_Groups.h"
#import "BibDocument_Search.h"
#import "NSTask_BDSKExtensions.h"
#import "NSArray_BDSKExtensions.h"
#import "BDAlias.h"
#import "NSWorkspace_BDSKExtensions.h"
#import "BibItem.h"
#import "BDSKTemplate.h"
#import "NSString_BDSKExtensions.h"
#import "NSError_BDSKExtensions.h"
#import "BDSKSearchGroup.h"
#import "BDSKGroupsArray.h"
#import "NSFileManager_BDSKExtensions.h"
#import "BDSKTemplateDocument.h"
#import "BDSKTask.h"

#define MAX_FILTER_HISTORY 7

enum {
    BDSKOpenDefault,
    BDSKOpenUsingPhonyCiteKeys,
    BDSKOpenUsingFilter,
    BDSKOpenTemplate
};

@interface BDSKDocumentController (BDSKPrivate)
- (void)handleWindowDidBecomeMainNotification:(NSNotification *)notification;
@end

@implementation BDSKDocumentController

- (id)init {
    if ((self = [super init]) && didInitialize == NO) {
		[[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleWindowDidBecomeMainNotification:)
                                                     name:NSWindowDidBecomeMainNotification
                                                   object:nil];
        openType = BDSKOpenDefault;
        lastSelectedEncoding = BDSKNoStringEncoding;
        lastSelectedFilterCommand = nil;
        
        didInitialize = YES;
    }
    return self;
}

- (void)awakeFromNib {
    [openUsingFilterAccessoryView retain];
}

- (id)mainDocument {
    return mainDocument;
}

- (void)handleWindowDidBecomeMainNotification:(NSNotification *)notification{
    id currentDocument = [self currentDocument];
    if(currentDocument && [currentDocument isEqual:mainDocument] == NO){
        mainDocument = currentDocument;
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKDocumentControllerDidChangeMainDocumentNotification object:self];
    }
}

- (void)addDocument:(id)aDocument{
    [super addDocument:aDocument];
    if(mainDocument == nil){
        mainDocument = [[NSApp orderedDocuments] firstObject];
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKDocumentControllerDidChangeMainDocumentNotification object:aDocument];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKDocumentControllerAddDocumentNotification object:aDocument];
}

- (void)removeDocument:(id)aDocument{
    [aDocument retain];
    [super removeDocument:aDocument];
    if([mainDocument isEqual:aDocument]){
        mainDocument = [[NSApp orderedDocuments] firstObject];
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKDocumentControllerDidChangeMainDocumentNotification object:aDocument];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKDocumentControllerRemoveDocumentNotification object:aDocument];
    [aDocument release];
}

- (NSStringEncoding)lastSelectedEncoding {
    return lastSelectedEncoding != BDSKNoStringEncoding ? lastSelectedEncoding : [BDSKStringEncodingManager defaultEncoding];
}

- (void)noteNewRecentDocument:(NSDocument *)aDocument{
    
    // may need to revisit this for new document classes
    
    if ([aDocument respondsToSelector:@selector(documentStringEncoding)]) {
        BDSKPRECONDITION([aDocument isKindOfClass:[BibDocument class]]);
        
        NSStringEncoding encoding = [(BibDocument *)aDocument documentStringEncoding];
        
        // only add it to the list of recent documents if it can be opened without manually selecting an encoding
        if(encoding == NSASCIIStringEncoding || encoding == [BDSKStringEncodingManager defaultEncoding])
            [super noteNewRecentDocument:aDocument]; 

    }
}

- (IBAction)openDocument:(id)sender {
    lastSelectedEncoding = [BDSKStringEncodingManager defaultEncoding];
    [super openDocument:sender];
    lastSelectedEncoding = BDSKNoStringEncoding;
}

- (IBAction)openDocumentUsingPhonyCiteKeys:(id)sender {
    openType = BDSKOpenUsingPhonyCiteKeys;
    lastSelectedEncoding = [BDSKStringEncodingManager defaultEncoding];
    [super openDocument:sender];
    lastSelectedEncoding = BDSKNoStringEncoding;
    openType = BDSKOpenDefault;
}

- (IBAction)openDocumentUsingFilter:(id)sender {
    openType = BDSKOpenUsingFilter;
    lastSelectedEncoding = [BDSKStringEncodingManager defaultEncoding];
    [lastSelectedFilterCommand release];
    lastSelectedFilterCommand = nil;
    [super openDocument:sender];
    lastSelectedEncoding = BDSKNoStringEncoding;
    [lastSelectedFilterCommand release];
    lastSelectedFilterCommand = nil;
    openType = BDSKOpenDefault;
}

- (IBAction)newTemplateDocument:(id)sender {
    openType = BDSKOpenTemplate;
    [super newDocument:sender];
    openType = BDSKOpenDefault;
}

- (IBAction)openTemplateDocument:(id)sender {
    openType = BDSKOpenTemplate;
    [super openDocument:sender];
    openType = BDSKOpenDefault;
}

- (NSInteger)runModalOpenPanel:(NSOpenPanel *)openPanel forTypes:(NSArray *)extensions {
    NSView *accessoryView = nil;
    NSMutableArray *commandHistory = nil;
    
    switch (openType) {
        case BDSKOpenUsingPhonyCiteKeys:
            extensions = [NSArray arrayWithObject:@"bib"];
        case BDSKOpenDefault:
            accessoryView = openTextEncodingAccessoryView;
            break;
        case BDSKOpenUsingFilter:
            extensions = nil;
            
            [openTextEncodingAccessoryView setFrameOrigin:NSZeroPoint];
            [openUsingFilterAccessoryView addSubview:openTextEncodingAccessoryView];
            accessoryView = openUsingFilterAccessoryView;

            commandHistory = [NSMutableArray array];
            // this is a workaround for older versions which added the same command multiple times
            [commandHistory addNonDuplicateObjectsFromArray:[[NSUserDefaults standardUserDefaults] stringArrayForKey:BDSKFilterFieldHistoryKey]];
            
            // this is also a workaround for older versions
            if([commandHistory count] > MAX_FILTER_HISTORY)
                [commandHistory removeObjectsInRange:NSMakeRange(MAX_FILTER_HISTORY, [commandHistory count] - MAX_FILTER_HISTORY)];
            [openUsingFilterComboBox removeAllItems];
            [openUsingFilterComboBox addItemsWithObjectValues:commandHistory];
            
            if ([commandHistory count]) {
                [openUsingFilterComboBox selectItemAtIndex:0];
                [openUsingFilterComboBox setObjectValue:[openUsingFilterComboBox objectValueOfSelectedItem]];
            }
            break;
        case BDSKOpenTemplate:
            extensions = [NSArray arrayWithObjects:@"txt", @"rtf", nil];
            break;
    }
    if (accessoryView) {
        [openTextEncodingPopupButton setEncoding:[BDSKStringEncodingManager defaultEncoding]];
        [openPanel setAccessoryView:accessoryView];
    }
    
    NSInteger result = [super runModalOpenPanel:openPanel forTypes:extensions];
    
    if (result == NSOKButton) {
        if (accessoryView)
            lastSelectedEncoding = [openTextEncodingPopupButton encoding];
        
        if (openType == BDSKOpenUsingFilter) {
            [lastSelectedFilterCommand release];
            lastSelectedFilterCommand = [[openUsingFilterComboBox stringValue] copy];
            
            NSUInteger commandIndex = [commandHistory indexOfObject:lastSelectedFilterCommand];
            if (commandIndex == NSNotFound) {
                // not in the array, so add it and then remove the tail
                [commandHistory insertObject:lastSelectedFilterCommand atIndex:0];
                if([commandHistory count] > MAX_FILTER_HISTORY)
                    [commandHistory removeLastObject];
            } else if (commandIndex != 0) {
                // already in the array, so move it to the head of the list
                [commandHistory removeObject:lastSelectedFilterCommand];
                [commandHistory insertObject:lastSelectedFilterCommand atIndex:0];
            }
            [[NSUserDefaults standardUserDefaults] setObject:commandHistory forKey:BDSKFilterFieldHistoryKey];
        }
    }
    
    return result;
}

- (id)makeUntitledBibTeXDocumentWithString:(NSString *)fileString error:(NSError **)outError {
    // @@ we could also use [[NSApp delegate] temporaryFilePath:[filePath lastPathComponent] createDirectory:NO];
    // or [[NSFileManager defaultManager] uniqueFilePath:[filePath lastPathComponent] createDirectory:NO];
    // or move aside the original file
    NSString *tmpFilePath = [[[NSFileManager defaultManager] temporaryFileWithBasename:nil] stringByAppendingPathExtension:@"bib"];
    NSURL *tmpFileURL = [NSURL fileURLWithPath:tmpFilePath];
    NSData *data = [fileString dataUsingEncoding:lastSelectedEncoding];
    
    // If data is nil, then [data writeToFile:error:] is interpreted as NO since it's a message to nil...but doesn't initialize &error, so we crash!
    if (nil == data) {
        if (outError) {
            *outError = [NSError mutableLocalErrorWithCode:kBDSKStringEncodingError localizedDescription:NSLocalizedString(@"Incorrect string encoding", @"")];
            [*outError setValue:[NSNumber numberWithUnsignedInteger:lastSelectedEncoding] forKey:NSStringEncodingErrorKey];
            [*outError setValue:[NSString stringWithFormat:NSLocalizedString(@"The file could not be converted to encoding \"%@\".  Please try a different encoding.", @""), [NSString localizedNameOfStringEncoding:lastSelectedEncoding]] forKey:NSLocalizedRecoverySuggestionErrorKey];
        }
        return nil;
    }
    
    // bail out if we can't write the temp file
    if ([data writeToFile:tmpFilePath options:NSAtomicWrite error:outError] == NO) {
        return nil;
    }
    
    // make a fresh document, and don't display it until we can set its name.
    BibDocument *doc = [self makeDocumentWithContentsOfURL:tmpFileURL ofType:BDSKBibTeXDocumentType error:outError];    
    
    if (doc) {
        [doc setFileURL:nil];
        // set date-added for imports
        NSString *importDate = [[NSCalendarDate date] description];
        for (BibItem *pub in [doc publications])
            [pub setField:BDSKDateAddedString toValue:importDate];
        [[doc undoManager] removeAllActions];
        // mark as dirty, since we've changed the content
        [doc updateChangeCount:NSChangeDone];
    }
    
    return doc;
}

- (id)makeDocumentWithContentsOfURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError {
    id doc = nil;
    if (openType == BDSKOpenUsingPhonyCiteKeys) {
        NSString *stringFromFile = [[NSString stringWithContentsOfURL:absoluteURL encoding:lastSelectedEncoding error:outError] stringWithPhoneyCiteKeys:@"FixMe"];
        if (stringFromFile)
            doc = [self makeUntitledBibTeXDocumentWithString:stringFromFile error:outError];
    } else if (openType == BDSKOpenUsingFilter) {
        NSString *fileInputString = [NSString stringWithContentsOfURL:absoluteURL encoding:lastSelectedEncoding error:outError];
        
        lastSelectedEncoding = NSUTF8StringEncoding;
        
        if (fileInputString) {
            NSString *filterOutput = [BDSKTask runShellCommand:lastSelectedFilterCommand withInputString:fileInputString];
            
            if ([NSString isEmptyString:filterOutput] == NO) {
                doc = [self makeUntitledBibTeXDocumentWithString:fileInputString error:outError];
            } else if (outError) {
                *outError = [NSError mutableLocalErrorWithCode:kBDSKDocumentOpenError localizedDescription:NSLocalizedString(@"Unable To Open With Filter", @"Error description")];
                [*outError setValue:NSLocalizedString(@"Unable to read the file correctly. Please ensure that the shell command specified for filtering is correct by testing it in Terminal.app.", @"Error description") forKey:NSLocalizedRecoverySuggestionErrorKey];
            }
        }    
    } else {
        doc = [super makeDocumentWithContentsOfURL:absoluteURL ofType:typeName error:outError];
    }
    return doc;
}

- (id)openDocumentWithContentsOfURL:(NSURL *)absoluteURL display:(BOOL)displayDocument error:(NSError **)outError{
            
    NSString *theUTI = [[NSWorkspace sharedWorkspace] typeOfFile:[[[absoluteURL path] stringByStandardizingPath] stringByResolvingSymlinksInPath] error:NULL];
    id document = nil;
    
    if ([theUTI isEqualToUTI:@"net.sourceforge.bibdesk.bdskcache"]) {
        
        NSDictionary *dictionary = [NSDictionary dictionaryWithContentsOfURL:absoluteURL];
        BDAlias *fileAlias = [BDAlias aliasWithData:[dictionary valueForKey:@"FileAlias"]];
        // if the alias didn't work, let's see if we have a filepath key...
        NSString *fullPath = [fileAlias fullPath] ?: [dictionary valueForKey:@"net_sourceforge_bibdesk_owningfilepath"];
        
        if (fullPath == nil) {
            if(outError != nil) 
                *outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Unable to find the file associated with this item.", @"Error description"), NSLocalizedDescriptionKey, nil]];
            return nil;
        }
            
        NSURL *fileURL = [NSURL fileURLWithPath:fullPath];
        
        // use a local variable in case it wasn't passed in, so we can always log this failure
        NSError *error;
        document = [super openDocumentWithContentsOfURL:fileURL display:YES error:&error];
        
        if (document == nil) {
            NSLog(@"document at URL %@ failed to open for reason: %@", fileURL, [error localizedFailureReason]);
            // assign to the outError or we'll crash...
            if (outError) *outError = error;
        } else if(![document selectItemForPartialItem:dictionary]) {
                NSBeep();
        }
        
    } else if ([theUTI isEqualToUTI:@"net.sourceforge.bibdesk.bdsksearch"]) {
        
        NSDictionary *dictionary = [NSDictionary dictionaryWithContentsOfURL:absoluteURL];
        Class aClass = NSClassFromString([dictionary objectForKey:@"class"]);
        if (aClass == Nil) aClass = [BDSKSearchGroup class];
        BDSKSearchGroup *group = [[aClass alloc] initWithDictionary:dictionary];
        
        if (nil == group) {
            if (outError) *outError = [NSError mutableLocalErrorWithCode:kBDSKPropertyListDeserializationFailed localizedDescription:NSLocalizedString(@"Unable to read this file as a search group property list", @"error when opening search group file")];
            NSLog(@"Unable to instantiate BDSKSearchGroup of class %@", [dictionary objectForKey:@"class"]);
            // make sure we return nil
            document = nil;
            
        } else {
            // try the main document first
            document = [self mainDocument];
            if (nil == document)
                document = [self openUntitledDocumentAndDisplay:YES error:outError];
            
            [[document groups] addSearchGroup:group];
            [group release];
        }
        
    } else {
        
        document = [super openDocumentWithContentsOfURL:absoluteURL display:displayDocument error:outError];
        
        if (openType == BDSKOpenUsingPhonyCiteKeys)
            [(BibDocument *)document reportTemporaryCiteKeys:@"FixMe" forNewDocument:YES];
        
    }
    
    return document;
}

#pragma mark Document types

- (NSString *)defaultType {
    if (openType == BDSKOpenTemplate)
        return BDSKTextTemplateDocumentType;
    return [super defaultType];
}

- (NSArray *)fileExtensionsFromType:(NSString *)documentTypeName
{
    NSArray *fileExtensions = [super fileExtensionsFromType:documentTypeName];
    if([fileExtensions count] == 0){
    	NSString *fileExtension = [[BDSKTemplate templateForStyle:documentTypeName] fileExtension];
        if(fileExtension != nil)
            fileExtensions = [NSArray arrayWithObject:fileExtension];
    }
	return fileExtensions;
}

- (NSString *)typeForContentsOfURL:(NSURL *)inAbsoluteURL error:(NSError **)outError {
    if (openType == BDSKOpenTemplate)
        return [[[inAbsoluteURL path] pathExtension] caseInsensitiveCompare:@"rtf"] == NSOrderedSame ? BDSKRichTextTemplateDocumentType : BDSKTextTemplateDocumentType;
    return [super typeForContentsOfURL:inAbsoluteURL error:outError];
}

- (Class)documentClassForType:(NSString *)documentTypeName
{
    Class docClass = [super documentClassForType:documentTypeName];
	if ([documentTypeName isEqualToString:BDSKTextTemplateDocumentType] || [documentTypeName isEqualToString:BDSKRichTextTemplateDocumentType])
        docClass = [BDSKTemplateDocument class];
    else if (docClass == Nil && [[BDSKTemplate allStyleNames] containsObject:documentTypeName])
        docClass = [BibDocument class];
    return docClass;
}

- (NSString *)displayNameForType:(NSString *)documentTypeName{
    NSString *displayName = nil;
    if([documentTypeName isEqualToString:BDSKMinimalBibTeXDocumentType])
        displayName = NSLocalizedString(@"Minimal BibTeX", @"Popup menu title for Minimal BibTeX");
    else if([documentTypeName isEqualToString:[BDSKTemplate defaultStyleNameForFileType:@"html"]])
        displayName = @"HTML";
    else if([documentTypeName isEqualToString:[BDSKTemplate defaultStyleNameForFileType:@"rss"]])
        displayName = @"RSS";
    else if([documentTypeName isEqualToString:[BDSKTemplate defaultStyleNameForFileType:@"rtf"]])
        displayName = NSLocalizedString(@"Rich Text (RTF)", @"Popup menu title for Rich Text (RTF)");
    else if([documentTypeName isEqualToString:[BDSKTemplate defaultStyleNameForFileType:@"rtfd"]])
        displayName = NSLocalizedString(@"Rich Text with Graphics (RTFD)", @"Popup menu title for Rich Text (RTFD)");
    else if([documentTypeName isEqualToString:[BDSKTemplate defaultStyleNameForFileType:@"doc"]])
        displayName = NSLocalizedString(@"Word Format (Doc)", @"Popup menu title for Word Format (Doc)");
    else
        displayName = [super displayNameForType:documentTypeName];
    return displayName;
}

@end

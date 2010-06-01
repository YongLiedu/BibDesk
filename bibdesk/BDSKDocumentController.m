//  BDSKDocumentController.m

//  Created by Christiaan Hofman on 5/31/06.
/*
 This software is Copyright (c) 2006-2010
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
#import "BDSKStringEncodingManager.h"
#import "BibDocument.h"
#import "NSTask_BDSKExtensions.h"
#import "NSArray_BDSKExtensions.h"
#import "BDAlias.h"
#import "NSWorkspace_BDSKExtensions.h"
#import "BDSKTemplate.h"
#import "NSString_BDSKExtensions.h"
#import "NSError_BDSKExtensions.h"
#import "BDSKSearchGroup.h"
#import "BDSKGroupsArray.h"
#import "NSFileManager_BDSKExtensions.h"
#import "BDSKTemplateDocument.h"
#import "BDSKTask.h"
#import "BDSKOpenAccessoryViewController.h"

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
    [super openDocument:sender];
    lastSelectedEncoding = BDSKNoStringEncoding;
}

- (IBAction)openDocumentUsingPhonyCiteKeys:(id)sender {
    openType = BDSKOpenUsingPhonyCiteKeys;
    [self openDocument:sender];
    openType = BDSKOpenDefault;
}

- (IBAction)openDocumentUsingFilter:(id)sender {
    openType = BDSKOpenUsingFilter;
    [lastSelectedFilterCommand release];
    lastSelectedFilterCommand = nil;
    [self openDocument:sender];
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
    BDSKOpenAccessoryViewController *accessoryController = nil;
    
    switch (openType) {
        case BDSKOpenUsingPhonyCiteKeys:
            extensions = [NSArray arrayWithObject:@"bib"];
        case BDSKOpenDefault:
            accessoryController = [[BDSKOpenAccessoryViewController alloc] init];
            accessoryView = [accessoryController openTextEncodingAccessoryView];
            break;
        case BDSKOpenUsingFilter:
            extensions = nil;
            accessoryController = [[BDSKOpenAccessoryViewController alloc] init];
            accessoryView = [accessoryController openUsingFilterAccessoryView];
            break;
        case BDSKOpenTemplate:
            extensions = [NSArray arrayWithObjects:@"txt", @"rtf", nil];
            break;
    }
    if (accessoryController) {
        [accessoryController setEncoding:[BDSKStringEncodingManager defaultEncoding]];
        [openPanel setAccessoryView:accessoryView];
    }
    
    NSInteger result = [super runModalOpenPanel:openPanel forTypes:extensions];
    
    if (accessoryController) {
        if (result == NSOKButton) {
            lastSelectedEncoding = [accessoryController encoding];
            
            if (openType == BDSKOpenUsingFilter) {
                [lastSelectedFilterCommand release];
                lastSelectedFilterCommand = [[accessoryController filterCommand] copy];
            }
        }
        [accessoryController release];
    }
    
    return result;
}

- (id)makeDocumentWithContentsOfURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError {
    id doc = nil;
    if (openType == BDSKOpenUsingPhonyCiteKeys || openType == BDSKOpenUsingFilter) {
        NSStringEncoding encoding = [self lastSelectedEncoding];
        NSString *filteredString = nil;
        
        if (openType == BDSKOpenUsingPhonyCiteKeys) {
            NSError *error = nil;
            filteredString = [[NSString stringWithContentsOfURL:absoluteURL encoding:encoding error:&error] stringWithPhoneyCiteKeys:@"FixMe"];
            if ([NSString isEmptyString:filteredString] && outError)
                *outError = error ?: [NSError localErrorWithCode:kBDSKDocumentOpenError localizedDescription:NSLocalizedString(@"Unable To Open With Phony Cite Keys", @"Error description")];
        } else {
            NSData *filteredData = [BDSKTask outputDataFromTaskWithLaunchPath:@"/bin/sh" arguments:[NSArray arrayWithObjects:@"-c", lastSelectedFilterCommand, nil] inputData:[NSData dataWithContentsOfURL:absoluteURL]];
            filteredString = [[[NSString alloc] initWithData:filteredData encoding:encoding] autorelease];
            if ([NSString isEmptyString:filteredString] && outError) {
                *outError = [NSError mutableLocalErrorWithCode:kBDSKDocumentOpenError localizedDescription:NSLocalizedString(@"Unable To Open With Filter", @"Error description")];
                [*outError setValue:NSLocalizedString(@"Unable to read the file correctly. Please ensure that the shell command specified for filtering is correct by testing it in Terminal.app.", @"Error description") forKey:NSLocalizedRecoverySuggestionErrorKey];
            }
        }
        if ([NSString isEmptyString:filteredString] == NO) {
            NSString *tmpFileName = [[[[absoluteURL path] lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:@"bib"];
            NSURL *tmpFileURL = [NSURL fileURLWithPath:[[NSFileManager defaultManager] temporaryFileWithBasename:tmpFileName]];
            
            if ([filteredString writeToURL:tmpFileURL atomically:YES encoding:encoding error:outError]) {
                if (doc = [super makeDocumentWithContentsOfURL:tmpFileURL ofType:BDSKBibTeXDocumentType error:outError])
                    [(BibDocument *)doc markAsImported];
                [[NSFileManager defaultManager] removeItemAtPath:[tmpFileURL path] error:NULL];
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
            if (outError) *outError = [NSError localErrorWithCode:kBDSKPropertyListDeserializationFailed localizedDescription:NSLocalizedString(@"Unable to read this file as a search group property list", @"error when opening search group file")];
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
        
        if (displayDocument && openType == BDSKOpenUsingPhonyCiteKeys)
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

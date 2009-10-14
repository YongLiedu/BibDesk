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

@implementation BDSKDocumentController

- (id)init
{
    if(self = [super init]){
		[[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleWindowDidBecomeMainNotification:)
                                                     name:NSWindowDidBecomeMainNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidBecomeMainNotification object:nil];
    mainDocument = nil;
    [super dealloc];
}

- (void)awakeFromNib{
    [openUsingFilterAccessoryView retain];
}

- (id)mainDocument{
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

- (NSArray *)allReadableTypesForOpenPanel {
    NSMutableArray *types = [NSMutableArray array];
    for (NSString *className in [self documentClassNames])
        [types addObjectsFromArray:[NSClassFromString(className) readableTypes]];
    
    NSMutableArray *openPanelTypes = [NSMutableArray array];
    for (NSString *type in types)
        [openPanelTypes addObjectsFromArray:[self fileExtensionsFromType:type]];
    
    return [openPanelTypes count] ? openPanelTypes : types;
}

- (NSArray *)URLsFromRunningOpenPanelForTypes:(NSArray *)types encoding:(NSStringEncoding *)encoding{
    
    NSParameterAssert(encoding);
    
    NSOpenPanel *oPanel = [NSOpenPanel openPanel];
    [oPanel setAllowsMultipleSelection:YES];
    [oPanel setAccessoryView:openTextEncodingAccessoryView];
    [openTextEncodingPopupButton setEncoding:[BDSKStringEncodingManager defaultEncoding]];
    [oPanel setDirectory:[self currentDirectory]];
		
    NSInteger result = [self runModalOpenPanel:oPanel forTypes:types];
    if(result == NSOKButton){
        *encoding = [openTextEncodingPopupButton encoding];
        return [oPanel URLs];
    }else 
        return nil;
}

- (void)openDocument:(id)sender{

    NSStringEncoding encoding;
    for (NSURL *aURL in [self URLsFromRunningOpenPanelForTypes:[self allReadableTypesForOpenPanel] encoding:&encoding]) {
        if (nil == [self openDocumentWithContentsOfURL:aURL encoding:encoding])
            break;
	}
}

- (IBAction)openDocumentUsingPhonyCiteKeys:(id)sender{
    NSStringEncoding encoding;
    for (NSURL *aURL in [self URLsFromRunningOpenPanelForTypes:[NSArray arrayWithObject:@"bib"] encoding:&encoding]) {
        [self openDocumentWithContentsOfURLUsingPhonyCiteKeys:aURL encoding:encoding];
	}
}

- (IBAction)openDocumentUsingFilter:(id)sender
{
    NSInteger result;
    
    NSOpenPanel *oPanel = [NSOpenPanel openPanel];
    [oPanel setAllowsMultipleSelection:YES];
    [oPanel setDirectory:[self currentDirectory]];

    [openTextEncodingPopupButton setEncoding:[BDSKStringEncodingManager defaultEncoding]];
    [openTextEncodingAccessoryView setFrameOrigin:NSZeroPoint];
    [openUsingFilterAccessoryView addSubview:openTextEncodingAccessoryView];
    [oPanel setAccessoryView:openUsingFilterAccessoryView];

    NSMutableArray *commandHistory = [NSMutableArray arrayWithArray:[[NSUserDefaults standardUserDefaults] stringArrayForKey:BDSKFilterFieldHistoryKey]];
    NSSet *uniqueCommandHistory = [NSSet setWithArray:commandHistory];
    
    // this is a workaround for older versions which added the same command multiple times; it screws up the order
    if ([commandHistory count] != [uniqueCommandHistory count])
        commandHistory = [NSMutableArray arrayWithArray:[uniqueCommandHistory allObjects]];
    
    // this is also a workaround for older versions
    NSUInteger MAX_HISTORY = 7;
    if([commandHistory count] > MAX_HISTORY)
        [commandHistory removeObjectsInRange:NSMakeRange(MAX_HISTORY, [commandHistory count] - MAX_HISTORY)];
    [openUsingFilterComboBox addItemsWithObjectValues:commandHistory];
    
    if([commandHistory count]){
        [openUsingFilterComboBox selectItemAtIndex:0];
        [openUsingFilterComboBox setObjectValue:[openUsingFilterComboBox objectValueOfSelectedItem]];
    }
    result = [self runModalOpenPanel:oPanel forTypes:nil];
    
    if (result == NSOKButton) {
        NSString *shellCommand = [openUsingFilterComboBox stringValue];
        NSStringEncoding encoding = [openTextEncodingPopupButton encoding];
        for (NSURL *aURL in [oPanel URLs])
            [self openDocumentWithContentsOfURL:aURL usingFilter:shellCommand encoding:encoding];
        
        NSUInteger commandIndex = [commandHistory indexOfObject:shellCommand];
        // already in the array, so move it to the head of the list
        if(commandIndex != NSNotFound && commandIndex != 0) {
            [[shellCommand retain] autorelease];
            [commandHistory removeObject:shellCommand];
            [commandHistory insertObject:shellCommand atIndex:0];
        } else {
            // not in the array, so add it and then remove the tail
            [commandHistory insertObject:shellCommand atIndex:0];
            [commandHistory removeLastObject];
        }
        [[NSUserDefaults standardUserDefaults] setObject:commandHistory forKey:BDSKFilterFieldHistoryKey];
    }
}

- (id)openDocumentWithContentsOfURL:(NSURL *)fileURL encoding:(NSStringEncoding)encoding{
    NSParameterAssert(encoding != 0);
	// first see if we already have this document open
    id doc = [self documentForURL:fileURL];
    
    if(doc == nil){
        BOOL success;
        // make a fresh document, and don't display it until we can set its name.
        
        NSError *error;
        doc = [self openUntitledDocumentAndDisplay:NO error:&error];
        
        if (nil == doc) {
            [self presentError:error];
            return nil;
        }
        
        NSString *type = [self typeForContentsOfURL:fileURL error:&error];
        
        if (nil == type) {
            [self presentError:error];
            return nil;
        }

        [doc setFileURL:fileURL]; // this effectively makes it not an untitled document anymore.
        success = [doc readFromURL:fileURL ofType:type encoding:encoding error:&error];
        if (success == NO) {
            [self removeDocument:doc];
            [self presentError:error];
            return nil;
        }
    }
    
    [doc makeWindowControllers];
    [doc showWindows];
    
    return doc;
}

- (id)openUntitledBibTeXDocumentWithString:(NSString *)fileString encoding:(NSStringEncoding)encoding error:(NSError **)outError{
    // @@ we could also use [[NSApp delegate] temporaryFilePath:[filePath lastPathComponent] createDirectory:NO];
    // or [[NSFileManager defaultManager] uniqueFilePath:[filePath lastPathComponent] createDirectory:NO];
    // or move aside the original file
    NSString *tmpFilePath = [[[NSFileManager defaultManager] temporaryFileWithBasename:nil] stringByAppendingPathExtension:@"bib"];
    NSURL *tmpFileURL = [NSURL fileURLWithPath:tmpFilePath];
    NSData *data = [fileString dataUsingEncoding:encoding];
    
    // If data is nil, then [data writeToFile:error:] is interpreted as NO since it's a message to nil...but doesn't initialize &error, so we crash!
    if (nil == data) {
        if (outError) {
            *outError = [NSError mutableLocalErrorWithCode:kBDSKStringEncodingError localizedDescription:NSLocalizedString(@"Incorrect string encoding", @"")];
            [*outError setValue:[NSNumber numberWithInt:encoding] forKey:NSStringEncodingErrorKey];
            [*outError setValue:[NSString stringWithFormat:NSLocalizedString(@"The file could not be converted to encoding \"%@\".  Please try a different encoding.", @""), [NSString localizedNameOfStringEncoding:encoding]] forKey:NSLocalizedRecoverySuggestionErrorKey];
        }
        return nil;
    }
    
    NSError *error;
    
    // bail out if we can't write the temp file
    if([data writeToFile:tmpFilePath options:NSAtomicWrite error:&error] == NO) {
        if (outError) *outError = error;
        return nil;
    }
    
    // make a fresh document, and don't display it until we can set its name.
    BibDocument *doc = [self openUntitledDocumentAndDisplay:NO error:outError];    
    [doc setFileURL:tmpFileURL]; // required for error handling
    BOOL success = [doc readFromURL:tmpFileURL ofType:BDSKBibTeXDocumentType encoding:encoding error:outError];
    
    if (success == NO) {
        [self removeDocument:doc];
        doc = nil;
    } else {
        [doc setFileURL:nil];
        // set date-added for imports
        NSString *importDate = [[NSCalendarDate date] description];
        [[doc publications] makeObjectsPerformSelector:@selector(setField:toValue:) withObject:BDSKDateAddedString withObject:importDate];
        [[doc undoManager] removeAllActions];
        [doc makeWindowControllers];
        [doc showWindows];
        // mark as dirty, since we've changed the content
        [doc updateChangeCount:NSChangeDone];
    }
    
    return doc;
}

- (id)openDocumentWithContentsOfURLUsingPhonyCiteKeys:(NSURL *)fileURL encoding:(NSStringEncoding)encoding;
{
    NSString *stringFromFile = [NSString stringWithContentsOfURL:fileURL encoding:encoding error:NULL];
    stringFromFile = [stringFromFile stringWithPhoneyCiteKeys:@"FixMe"];
    
    NSError *error;
	BibDocument *doc = [self openUntitledBibTeXDocumentWithString:stringFromFile encoding:encoding error:&error];
    if (nil == doc)
        [self presentError:error];
    
    [doc reportTemporaryCiteKeys:@"FixMe" forNewDocument:YES];
    
    return doc;
}

- (id)openDocumentWithContentsOfURL:(NSURL *)fileURL usingFilter:(NSString *)shellCommand encoding:(NSStringEncoding)encoding;
{
    NSError *error;
    NSString *fileInputString = [NSString stringWithContentsOfURL:fileURL encoding:encoding error:&error];
    BibDocument *doc = nil;
        
    if (nil == fileInputString){
        [self presentError:error];
    } else {
        NSString *filterOutput = [BDSKTask runShellCommand:shellCommand withInputString:fileInputString];
        
        if ([NSString isEmptyString:filterOutput]){
            NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Unable To Open With Filter", @"Message in alert dialog when unable to open a document with filter")
                                             defaultButton:nil
                                           alternateButton:nil
                                               otherButton:nil
                                 informativeTextWithFormat:NSLocalizedString(@"Unable to read the file correctly. Please ensure that the shell command specified for filtering is correct by testing it in Terminal.app.", @"Informative text in alert dialog")];
            [alert runModal];
        } else {
            doc = [self openUntitledBibTeXDocumentWithString:filterOutput encoding:NSUTF8StringEncoding error:&error];
            if (nil == doc)
                [self presentError:error];
        }
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
        
        if(fullPath == nil){
            if(outError != nil) 
                *outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Unable to find the file associated with this item.", @"Error description"), NSLocalizedDescriptionKey, nil]];
            return nil;
        }
            
        NSURL *fileURL = [NSURL fileURLWithPath:fullPath];
        
        // use a local variable in case it wasn't passed in, so we can always log this failure
        NSError *error;
        document = [super openDocumentWithContentsOfURL:fileURL display:YES error:&error];
        
        if(document == nil) {
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
            if (nil == document) {
                document = [self openUntitledDocumentAndDisplay:YES error:outError];
                [document showWindows];
            }
            
            [[document groups] addSearchGroup:group];
            [group release];
        }
        
    } else {
        document = [super openDocumentWithContentsOfURL:absoluteURL display:displayDocument error:outError];
    }
    
    return document;
}

#pragma mark Template documents

- (IBAction)newTemplateDocument:(id)sender {
    [self openUntitledDocumentOfType:BDSKTextTemplateDocumentType display:YES];
    NSDocument *document = [[[BDSKTemplateDocument alloc] init] autorelease];

    if (document == nil)
        return;

    [self addDocument:document];
    if ([self shouldCreateUI]) {
        [document makeWindowControllers];
        [document showWindows];
    }
}

- (IBAction)openTemplateDocument:(id)sender {
    NSOpenPanel *oPanel = [NSOpenPanel openPanel];
    [oPanel setAllowsMultipleSelection:YES];
    [oPanel setDirectory:[self currentDirectory]];
		
    NSInteger result = [self runModalOpenPanel:oPanel forTypes:[NSArray arrayWithObjects:@"txt", @"rtf", nil]];
    if(result == NSOKButton){
        for (NSURL *aURL in [oPanel URLs]) {
            if (nil == [self openTemplateDocumentWithContentsOfURL:aURL])
                break;
        }
    }
}

- (id)openTemplateDocumentWithContentsOfURL:(NSURL *)fileURL{
	// first see if we already have this document open
    id doc = [self documentForURL:fileURL];
    
    if(doc == nil){
        NSError *error;
        NSString *type = [[[fileURL path] pathExtension] caseInsensitiveCompare:@"rtf"] == NSOrderedSame ? BDSKRichTextTemplateDocumentType : BDSKTextTemplateDocumentType;
        doc = [[[BDSKTemplateDocument alloc] initWithContentsOfURL:fileURL ofType:type error:&error] autorelease];
        
        if (nil == doc) {
            [self presentError:error];
            return nil;
        }
        
        [self addDocument:doc];
        
        [doc makeWindowControllers];
    }
    [doc showWindows];
    
    return doc;
}

#pragma mark Document types

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

- (NSString *)typeFromFileExtension:(NSString *)fileExtensionOrHFSFileType
{
    NSString *type = nil;
    
    // @@ revisit this if we compile against 10.5 SDK
    type = [super typeFromFileExtension:fileExtensionOrHFSFileType];
    if(type == nil){
        type = [[BDSKTemplate defaultStyleNameForFileType:fileExtensionOrHFSFileType] valueForKey:BDSKTemplateNameString];
    }else if ([type isEqualToString:BDSKMinimalBibTeXDocumentType]){
        // fix of bug when reading a .bib file
        // this is interpreted as Minimal BibTeX, even though we don't declare that as a readable type
        type = BDSKBibTeXDocumentType;
    }
	return type;
}

- (Class)documentClassForType:(NSString *)documentTypeName
{
	Class docClass = [super documentClassForType:documentTypeName];
    if (docClass == Nil && [[BDSKTemplate allStyleNames] containsObject:documentTypeName]) {
        docClass = [BibDocument class];
    }
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

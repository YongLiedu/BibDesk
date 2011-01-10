//
//  BDSKTemplate.m
//  Bibdesk
//
//  Created by Adam Maxwell on 05/23/06.
/*
 This software is Copyright (c) 2006-2011
 Adam Maxwell. All rights reserved.
 
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

#import "BDSKTemplate.h"
#import "BDAlias.h"
#import "NSFileManager_BDSKExtensions.h"
#import "NSURL_BDSKExtensions.h"
#import "NSCharacterSet_BDSKExtensions.h"
#import "NSString_BDSKExtensions.h"

// do not localized these strings
NSString *BDSKTemplateRoleString = @"role";
NSString *BDSKTemplateNameString = @"name";
NSString *BDSKTemplateFileURLString = @"representedFileURL";
NSString *BDSKTemplateAliasString = @"_BDAlias";
NSString *BDSKTemplateFilePathString = @"filePath";
NSString *BDSKTemplateStringString = @"string";
NSString *BDSKTemplateAttributedStringString = @"attributedString";
NSString *BDSKExportTemplateTree = @"BDSKExportTemplateTree";
NSString *BDSKServiceTemplateTree = @"BDSKServiceTemplateTree";
NSString *BDSKTemplateAccessoryString = @"Accessory File";
NSString *BDSKTemplateMainPageString = @"Main Page";
NSString *BDSKTemplateDefaultItemString = @"Default Item";
NSString *BDSKTemplateScriptString = @"Postprocess Script";

static inline NSString *itemTemplateSubstring(NSString *templateString){
    NSInteger start, end, length = [templateString length];
    NSUInteger nonwsLoc;
    NSRange range = [templateString rangeOfString:@"<$publications>"];
    start = NSMaxRange(range);
    if (start != NSNotFound) {
        nonwsLoc = [templateString rangeOfCharacterFromSet:[NSCharacterSet nonWhitespaceCharacterSet] options:0 range:NSMakeRange(start, length - start)].location;
        if (nonwsLoc != NSNotFound) {
            unichar firstChar = [templateString characterAtIndex:nonwsLoc];
            if ([[NSCharacterSet newlineCharacterSet] characterIsMember:firstChar]) {
                if (firstChar == NSCarriageReturnCharacter && (NSInteger)nonwsLoc + 1 < length && [templateString characterAtIndex:nonwsLoc + 1] == NSNewlineCharacter)
                    start = nonwsLoc + 2;
                else 
                    start = nonwsLoc + 1;
            }
        }
        range = [templateString rangeOfString:@"</$publications>" options:0 range:NSMakeRange(start, length - start)];
        end = range.location;
        if (end != NSNotFound) {
            range = [templateString rangeOfString:@"<?$publications>" options:0 range:NSMakeRange(start, end - start)];
            if (range.location != NSNotFound)
                end = range.location;
            nonwsLoc = [templateString rangeOfCharacterFromSet:[NSCharacterSet nonWhitespaceCharacterSet] options:NSBackwardsSearch range:NSMakeRange(start, end - start)].location;
            if (nonwsLoc != NSNotFound) {
                if ([[NSCharacterSet newlineCharacterSet] characterIsMember:[templateString characterAtIndex:nonwsLoc]])
                    end = nonwsLoc + 1;
            }
        } else
            return nil;
    } else
        return nil;
    return [templateString substringWithRange:NSMakeRange(start, end - start)];
}

@implementation BDSKTemplate

+ (NSString *)localizedAccessoryString {
    static NSString *localizedAccessoryString = nil;
    if (localizedAccessoryString == nil)
        localizedAccessoryString = [NSLocalizedString(@"Accessory File", @"additional file used with export template") copy];
    return localizedAccessoryString;
}

+ (NSString *)localizedMainPageString {
    static NSString *localizedMainPageString = nil;
    if (localizedMainPageString == nil)
        localizedMainPageString = [NSLocalizedString(@"Main Page", @"template file used for the main page") copy];
    return localizedMainPageString;
}

+ (NSString *)localizedDefaultItemString {
    static NSString *localizedDefaultItemString = nil;
    if (localizedDefaultItemString == nil)
        localizedDefaultItemString = [NSLocalizedString(@"Default Item", @"template file used for a generic pub type") copy];
    return localizedDefaultItemString;
}

+ (NSString *)localizedScriptString {
    static NSString *localizedScriptString = nil;
    if (localizedScriptString == nil)
        localizedScriptString = [NSLocalizedString(@"Postprocess Script", @"script for postprocessing template") copy];
    return localizedScriptString;
}

+ (NSString *)localizedRoleString:(NSString *)string {
    if ([string isEqualToString:BDSKTemplateAccessoryString])
        string = [self localizedAccessoryString];
    else if ([string isEqualToString:BDSKTemplateMainPageString])
        string = [self localizedMainPageString];
    else if ([string isEqualToString:BDSKTemplateDefaultItemString])
        string = [self localizedDefaultItemString];
    else if ([string isEqualToString:BDSKTemplateScriptString])
        string = [self localizedScriptString];
    return string;
}

+ (NSString *)unlocalizedRoleString:(NSString *)string {
    if ([string isEqualToString:[self localizedAccessoryString]])
        string = BDSKTemplateAccessoryString;
    else if ([string isEqualToString:[self localizedMainPageString]])
        string = BDSKTemplateMainPageString;
    else if ([string isEqualToString:[self localizedDefaultItemString]])
        string = BDSKTemplateDefaultItemString;
    else if ([string isEqualToString:[self localizedScriptString]])
        string = BDSKTemplateScriptString;
    return string;
}

#pragma mark Class methods

+ (NSArray *)defaultExportTemplates
{
    NSMutableArray *itemNodes = [[NSMutableArray alloc] initWithCapacity:4];
    NSString *appSupportPath = [[NSFileManager defaultManager] currentApplicationSupportPathForCurrentUser];
    NSString *templatesPath = [appSupportPath stringByAppendingPathComponent:@"Templates"];
    BDSKTemplate *template = nil;
    NSURL *fileURL = nil;
    
    // HTML template
    fileURL = [NSURL fileURLWithPath:[templatesPath stringByAppendingPathComponent:@"htmlExportTemplate.html"]];
    template = [BDSKTemplate templateWithName:NSLocalizedString(@"Default HTML template", @"template name") mainPageURL:fileURL fileType:@"html"];
    // a user could potentially have templates for multiple BibTeX types; we could add all of those, as well
    fileURL = [NSURL fileURLWithPath:[templatesPath stringByAppendingPathComponent:@"htmlItemExportTemplate.html"]];
    [template addChildWithURL:fileURL role:BDSKTemplateDefaultItemString];
    fileURL = [NSURL fileURLWithPath:[templatesPath stringByAppendingPathComponent:@"htmlExportStyleSheet.css"]];
    [template addChildWithURL:fileURL role:BDSKTemplateAccessoryString];
    [itemNodes addObject:template];
    
    // RTF template
    fileURL = [NSURL fileURLWithPath:[templatesPath stringByAppendingPathComponent:@"rtfExportTemplate.rtf"]];
    template = [BDSKTemplate templateWithName:NSLocalizedString(@"Default RTF template", @"template name") mainPageURL:fileURL fileType:@"rtf"];
    [itemNodes addObject:template];
    
    // RTFD template
    fileURL = [NSURL fileURLWithPath:[templatesPath stringByAppendingPathComponent:@"rtfdExportTemplate.rtfd"]];
    template = [BDSKTemplate templateWithName:NSLocalizedString(@"Default RTFD template", @"template name") mainPageURL:fileURL fileType:@"rtfd"];
    [itemNodes addObject:template];
        
    // RSS template
    fileURL = [NSURL fileURLWithPath:[templatesPath stringByAppendingPathComponent:@"rssExportTemplate.rss"]];
    template = [BDSKTemplate templateWithName:NSLocalizedString(@"Default RSS template", @"template name") mainPageURL:fileURL fileType:@"rss"];
    [itemNodes addObject:template];
        
    // Doc template
    fileURL = [NSURL fileURLWithPath:[templatesPath stringByAppendingPathComponent:@"docExportTemplate.doc"]];
    template = [BDSKTemplate templateWithName:NSLocalizedString(@"Default Doc template", @"template name") mainPageURL:fileURL fileType:@"doc"];
    [itemNodes addObject:template];
            
    return [itemNodes autorelease];
}

+ (NSArray *)defaultServiceTemplates
{
    NSMutableArray *itemNodes = [[NSMutableArray alloc] initWithCapacity:2];
    NSString *appSupportPath = [[NSFileManager defaultManager] currentApplicationSupportPathForCurrentUser];
    BDSKTemplate *template = nil;
    NSURL *fileURL = nil;
    
    // Citation template
    fileURL = [NSURL fileURLWithPath:[appSupportPath stringByAppendingPathComponent:@"Templates/citeServiceTemplate.txt"]];
    template = [BDSKTemplate templateWithName:NSLocalizedString(@"Citation Service template", @"template name") mainPageURL:fileURL fileType:@"txt"];
    [itemNodes addObject:template];
    
    // Text template
    fileURL = [NSURL fileURLWithPath:[appSupportPath stringByAppendingPathComponent:@"Templates/textServiceTemplate.txt"]];
    template = [BDSKTemplate templateWithName:NSLocalizedString(@"Text Service template", @"template name") mainPageURL:fileURL fileType:@"txt"];
    [itemNodes addObject:template];
    
    // RTF template
    fileURL = [NSURL fileURLWithPath:[appSupportPath stringByAppendingPathComponent:@"Templates/rtfServiceTemplate.rtf"]];
    template = [BDSKTemplate templateWithName:NSLocalizedString(@"RTF Service template", @"template name") mainPageURL:fileURL fileType:@"rtf"];
    [template setValue:NSLocalizedString(@"RTF Service template", @"template name") forKey:BDSKTemplateNameString];
    fileURL = [NSURL fileURLWithPath:[appSupportPath stringByAppendingPathComponent:@"Templates/rtfServiceTemplate default item.rtf"]];
    [template addChildWithURL:fileURL role:BDSKTemplateDefaultItemString];
    fileURL = [NSURL fileURLWithPath:[appSupportPath stringByAppendingPathComponent:@"Templates/rtfServiceTemplate book.rtf"]];
    [template addChildWithURL:fileURL role:BDSKBookString];
    [itemNodes addObject:template];
            
    return [itemNodes autorelease];
}

+ (NSArray *)exportTemplates{
    NSArray *templates = nil;
    NSData *prefData = [[NSUserDefaults standardUserDefaults] objectForKey:BDSKExportTemplateTree];
    if ([prefData length])
        templates = [NSKeyedUnarchiver unarchiveObjectWithData:prefData];
    if ([templates count] == 0)
        templates = [BDSKTemplate defaultExportTemplates];
    return templates;
}

+ (NSArray *)serviceTemplates{
    NSArray *templates = nil;
    NSData *prefData = [[NSUserDefaults standardUserDefaults] objectForKey:BDSKServiceTemplateTree];
    if ([prefData length])
        templates = [NSKeyedUnarchiver unarchiveObjectWithData:prefData];
    if ([templates count] == 0)
        templates = [BDSKTemplate defaultServiceTemplates];
    return templates;
}

+ (NSArray *)allStyleNames;
{
    NSMutableArray *names = [NSMutableArray array];
    NSString *name;
    for (id aNode in [self exportTemplates]) {
        if ([aNode isLeaf] == NO && [aNode mainPageTemplateURL] != nil) {
            name = [aNode valueForKey:BDSKTemplateNameString];
            if(name != nil)
                [names addObject:name];
        }
    }
    return names;
}

+ (NSArray *)allStyleNamesForFormat:(BDSKTemplateFormat)format;
{
    NSMutableArray *names = [NSMutableArray array];
    NSString *name;
    for (id aNode in [self exportTemplates]) {
        if ([aNode isLeaf] == NO && [aNode mainPageTemplateURL] != nil) {
            name = [aNode valueForKey:BDSKTemplateNameString];
            if (name != nil && ([aNode templateFormat] & format))
                [names addObject:name];
        }
    }
    return names;
}

+ (NSString *)defaultStyleNameForFileType:(NSString *)fileType;
{
    NSString *name;
    for (id aNode in [self exportTemplates]) {
        if ([aNode isLeaf] == NO && [aNode mainPageTemplateURL] != nil) {
            name = [aNode valueForKey:BDSKTemplateNameString];
            if (name != nil && [fileType isCaseInsensitiveEqual:[aNode valueForKey:BDSKTemplateRoleString]])
                return name;
        }
    }
    return nil;
}

// accesses the node array in prefs
+ (BDSKTemplate *)templateForStyle:(NSString *)styleName;
{
    id aNode = nil;
    for (aNode in [self exportTemplates]) {
        if (NO == [aNode isLeaf] && [[aNode valueForKey:BDSKTemplateNameString] isEqualToString:styleName])
            break;
    }
    return aNode;
}

+ (BDSKTemplate *)templateForCiteService;
{
    return [[self serviceTemplates] objectAtIndex:0];
}

+ (BDSKTemplate *)templateForTextService;
{
    return [[self serviceTemplates] objectAtIndex:1];
}

+ (BDSKTemplate *)templateForRTFService;
{
    return [[self serviceTemplates] lastObject];
}

+ (BDSKTemplate *)templateWithName:(NSString *)name mainPageURL:(NSURL *)fileURL fileType:(NSString *)fileType;
{
    BDSKTemplate *template = [[[BDSKTemplate alloc] init] autorelease];
    [template setValue:name forKey:BDSKTemplateNameString];
    [template setValue:fileType forKey:BDSKTemplateRoleString];
    [template addChildWithURL:fileURL role:BDSKTemplateMainPageString];
    return template;
}

+ (id)templateWithString:(NSString *)string fileType:(NSString *)fileType;
{
    BDSKTemplate *template = [[[BDSKTemplate alloc] init] autorelease];
    [template setValue:fileType forKey:BDSKTemplateRoleString];
    [template setValue:string forKey:BDSKTemplateStringString];
    return template;
}

+ (id)templateWithAttributedString:(NSAttributedString *)attributedString fileType:(NSString *)fileType;
{
    BDSKTemplate *template = [[[BDSKTemplate alloc] init] autorelease];
    [template setValue:fileType forKey:BDSKTemplateRoleString];
    [template setValue:attributedString forKey:BDSKTemplateAttributedStringString];
    return template;
}

#pragma mark Instance methods

- (BDSKTemplateFormat)templateFormat;
{
    BDSKASSERT([self parent] == nil);
    NSString *extension = [[self valueForKey:BDSKTemplateRoleString] lowercaseString];
    BDSKTemplateFormat format = BDSKUnknownTemplateFormat;
    NSURL *url = [self mainPageTemplateURL];
    NSString *string = nil;
    NSAttributedString *attrString = nil;
    BOOL isValid = (url = [self mainPageTemplateURL]) || (string = [self mainPageString]) || (attrString = [self mainPageAttributedStringWithDocumentAttributes:NULL]);
    
    if (extension == nil || isValid == NO) {
        format = BDSKUnknownTemplateFormat;
    } else if ([extension isEqualToString:@"rtf"]) {
        format = BDSKRTFTemplateFormat;
    } else if ([extension isEqualToString:@"rtfd"]) {
        format = BDSKRTFDTemplateFormat;
    } else if ([extension isEqualToString:@"doc"]) {
        format = BDSKDocTemplateFormat;
    } else if ([extension isEqualToString:@"docx"]) {
        format = BDSKDocTemplateFormat;
    } else if ([extension isEqualToString:@"odt"]) {
        format = BDSKOdtTemplateFormat;
    } else if ([extension isEqualToString:@"webarchive"]) {
        format = BDSKWebArchiveTemplateFormat;
    } else if ([extension isEqualToString:@"html"] || [extension isEqualToString:@"htm"]) {
        NSString *htmlString = url == nil ? string : [[[NSString alloc] initWithData:[NSData dataWithContentsOfURL:url] encoding:NSUTF8StringEncoding] autorelease];
        if (attrString)
            format = BDSKRichHTMLTemplateFormat;
        else if (htmlString == nil)
            format = BDSKUnknownTemplateFormat;
        else if ([htmlString rangeOfString:@"<$"].location == NSNotFound && [htmlString rangeOfString:@"&lt;$"].location != NSNotFound)
            format = BDSKRichHTMLTemplateFormat;
        else
            format = BDSKPlainHTMLTemplateFormat;
    } else {
        format = BDSKTextTemplateFormat;
    }
    return format;
}

- (NSString *)documentType {
    NSString *docType = nil;
    BDSKTemplateFormat templateFormat = [self templateFormat];
    if(templateFormat == BDSKRichHTMLTemplateFormat)
        docType = NSHTMLTextDocumentType;
    if(templateFormat == BDSKRTFTemplateFormat)
        docType = NSRTFTextDocumentType;
    else if(templateFormat == BDSKRTFDTemplateFormat)
        docType = NSRTFDTextDocumentType;
    else if(templateFormat == BDSKDocTemplateFormat)
        docType = NSDocFormatTextDocumentType;
    else if(templateFormat == BDSKDocxTemplateFormat)
        docType = NSOfficeOpenXMLTextDocumentType;
    else if(templateFormat == BDSKOdtTemplateFormat)
        docType = NSOpenDocumentTextDocumentType;
    else if(templateFormat == BDSKWebArchiveTemplateFormat)
        docType = NSWebArchiveTextDocumentType;
    else if(templateFormat & BDSKPlainTextTemplateFormat)
        docType = NSPlainTextDocumentType;
    return docType;
}

- (NSString *)fileExtension;
{
    BDSKASSERT([self parent] == nil);
    return [self valueForKey:BDSKTemplateRoleString];
}

- (NSString *)mainPageString;
{
    BDSKASSERT([self parent] == nil);
    NSURL *mainPageURL = [self mainPageTemplateURL];
    if (mainPageURL) {
        return [NSString stringWithContentsOfURL:[self mainPageTemplateURL] encoding:NSUTF8StringEncoding error:NULL];
    } else {
        return [self valueForKey:BDSKTemplateStringString];
    }
}

- (NSAttributedString *)mainPageAttributedStringWithDocumentAttributes:(NSDictionary **)docAttributes;
{
    BDSKASSERT([self parent] == nil);
    NSURL *mainPageURL = [self mainPageTemplateURL];
    if (mainPageURL) {
        return [[[NSAttributedString alloc] initWithURL:[self mainPageTemplateURL] documentAttributes:docAttributes] autorelease];
    } else {
        if (docAttributes) *docAttributes = nil;        
        return [self valueForKey:BDSKTemplateAttributedStringString];
    }
}

- (NSString *)stringForType:(NSString *)type;
{
    BDSKASSERT([self parent] == nil);
    NSURL *theURL = nil;
    if(nil != type)
        theURL = [self templateURLForType:type];
    // return default template string if no type or no type-specific template
    if(nil == theURL)
        theURL = [self defaultItemTemplateURL];
    if(nil != theURL)
        return [NSString stringWithContentsOfURL:theURL encoding:NSUTF8StringEncoding error:NULL];
    if([type isEqualToString:BDSKTemplateMainPageString] == NO)
        return nil;
    // get the item template from the main page template
    return itemTemplateSubstring([self mainPageString]);
}

- (NSAttributedString *)attributedStringForType:(NSString *)type;
{
    BDSKASSERT([self parent] == nil);
    NSURL *theURL = nil;
    if(nil != type)
        theURL = [self templateURLForType:type];
    // return default template string if no type or no type-specific template
    if(nil == theURL)
        theURL = [self defaultItemTemplateURL];
    return [[[NSAttributedString alloc] initWithURL:theURL documentAttributes:NULL] autorelease];
}

- (NSString *)scriptPath;
{
    BDSKASSERT([self parent] == nil);
    return [[self scriptURL] path];
}

- (NSURL *)mainPageTemplateURL;
{
    BDSKASSERT([self parent] == nil);
    return [self templateURLForType:BDSKTemplateMainPageString];
}

- (NSURL *)defaultItemTemplateURL;
{
    BDSKASSERT([self parent] == nil);
    return [self templateURLForType:BDSKTemplateDefaultItemString];
}

- (NSURL *)templateURLForType:(NSString *)pubType;
{
    BDSKASSERT([self parent] == nil);
    NSParameterAssert(nil != pubType);
    return [[self childForRole:pubType] representedFileURL];
}

- (NSArray *)accessoryFileURLs;
{
    BDSKASSERT([self parent] == nil);
    NSMutableArray *fileURLs = [NSMutableArray array];
    NSURL *fileURL;
    for (BDSKTemplate *aChild in [self children]) {
        if ([[aChild valueForKey:BDSKTemplateRoleString] isEqualToString:BDSKTemplateAccessoryString]) {
            fileURL = [aChild representedFileURL];
            if (fileURL)
                [fileURLs addObject:fileURL];
        }
    }
    return fileURLs;
}

- (NSURL *)scriptURL;
{
    BDSKASSERT([self parent] == nil);
    return [[self childForRole:BDSKTemplateScriptString] representedFileURL];
}

- (BOOL)addChildWithURL:(NSURL *)fileURL role:(NSString *)role;
{
    BOOL retVal;
    retVal = [[NSFileManager defaultManager] objectExistsAtFileURL:fileURL];
    BDSKTemplate *newChild = [[BDSKTemplate alloc] init];
    
    [newChild setValue:fileURL forKey:BDSKTemplateFileURLString];
    [newChild setValue:role forKey:BDSKTemplateRoleString];
    [self insertObject:newChild inChildrenAtIndex:[self countOfChildren]];
    [newChild release];
    if([newChild representedFileURL] == nil)
        retVal = NO;
    return retVal;
}

- (id)childForRole:(NSString *)role;
{
    BDSKASSERT([self parent] == nil);
    NSParameterAssert(nil != role);
    
    // assume roles are unique by grabbing the first one; this works for any case except the accessory files
    id aNode = nil;
    for (aNode in [self children]) {
        if ([[aNode valueForKey:BDSKTemplateRoleString] isEqualToString:role])
            break;
    }
    return aNode;
}

- (void)setRepresentedFileURL:(NSURL *)aURL;
{
    BDSKASSERT([self isLeaf]);
    BDAlias *alias = nil;
    alias = [[BDAlias alloc] initWithURL:aURL];
    
    if (alias) {
        NSString *name = [aURL lastPathComponent];
        
        [self setValue:[alias aliasData] forKey:BDSKTemplateAliasString];
        
        [self setValue:[[aURL path] stringByAbbreviatingWithTildeInPath] forKey:BDSKTemplateFilePathString];
        
        [self setValue:name forKey:BDSKTemplateNameString];
        
        if ([[self valueForKey:BDSKTemplateRoleString] isEqualToString:BDSKTemplateMainPageString]) {
            if ([[self parent] valueForKey:BDSKTemplateRoleString] == nil) {
                NSString *extension = [aURL pathExtension];
                if ([NSString isEmptyString:extension] == NO) 
                    [[self parent] setValue:extension forKey:BDSKTemplateRoleString];
            }
            if ([[self parent] valueForKey:BDSKTemplateNameString] == nil) {
                name = [name stringByDeletingPathExtension];
                if ([NSString isEmptyString:name] == NO) 
                    [[self parent] setValue:name forKey:BDSKTemplateNameString];
            }
        }
    }
    [alias release];
}

- (NSURL *)representedFileURL;
{
    BDSKASSERT([self isLeaf]);
    BDAlias *alias = [[BDAlias alloc] initWithData:[self valueForKey:BDSKTemplateAliasString]];
    NSURL *theURL = [alias fileURLNoUI];
    [alias release];
    if (theURL == nil) {
        NSString *path = [[self valueForKey:BDSKTemplateFilePathString] stringByExpandingTildeInPath];
        if (path && [[NSFileManager defaultManager] fileExistsAtPath:path])
            theURL = [NSURL fileURLWithPath:path];
    }
    return theURL;
}

@end

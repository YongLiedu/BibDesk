//
//  NSURL_BDSKExtensions.m
//  Bibdesk
//
//  Created by Adam Maxwell on 12/19/05.
/*
 This software is Copyright (c) 2005-2009
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

#import "NSURL_BDSKExtensions.h"
#import "CFString_BDSKExtensions.h"
#import "NSImage_BDSKExtensions.h"
#import "NSAppleEventDescriptor_BDSKExtensions.h"
#import <FileView/FileView.h>
#import "NSWorkspace_BDSKExtensions.h"
#import <SkimNotes/SkimNotes.h>
#import "NSFileManager_BDSKExtensions.h"
#import "NSAttributedString_BDSKExtensions.h"

@implementation NSURL (BDSKExtensions)

+ (NSURL *)fileURLWithAEDesc:(NSAppleEventDescriptor *)desc {
    return [desc fileURLValue];
}

- (NSAppleEventDescriptor *)aeDescriptorValue {
    NSAppleEventDescriptor *resultDesc = nil;
    
    NSData *data = (NSData *)CFURLCreateData(nil, (CFURLRef)self, kCFStringEncodingUTF8, true);
    if (data)
        resultDesc = [NSAppleEventDescriptor descriptorWithDescriptorType:typeFileURL data:data];
    [data release];
    
    return resultDesc;
}

/* This could as easily have been implemented in the NSFileManager category, but it mainly uses CFURL (and Carbon File Manager) functionality.  Omni has a method in their NSFileManager category that does the same thing, but it assumes PATH_MAX*4 for a max path length, uses malloc instead of NSZoneMalloc, uses path buffers instead of string/URL objects, uses some unnecessary autoreleases, and will resolve aliases on remote volumes.  Of course, it's also been debugged more thoroughly than my version. */

CFURLRef BDCopyFileURLResolvingAliases(CFURLRef fileURL)
{
    NSCParameterAssert([(NSURL *)fileURL isFileURL]);
    
    FSRef fileRef;
    OSErr err;
    Boolean isFolder, wasAliased;
    CFAllocatorRef allocator = CFGetAllocator(fileURL);
    
    // take ownership temporarily, since we use this as a local variable later on
    fileURL = CFRetain(fileURL);
    
    CFMutableArrayRef strippedComponents = CFArrayCreateMutable(allocator, 0, &kCFTypeArrayCallBacks);
    CFStringRef lastPathComponent;
    
    // use this to keep a reference to the previous "version" of the file URL, so we can dispose of it properly
    CFURLRef oldURL;
    
    // remove path components until we have a resolvable URL; in the common case, this returns true immediately
    while (CFURLGetFSRef(fileURL, &fileRef) == FALSE) {

        // returns empty string if there was nothing to copy
        lastPathComponent = CFURLCopyLastPathComponent(fileURL);
        
        if(BDIsEmptyString(lastPathComponent) == FALSE)
            CFArrayAppendValue(strippedComponents, lastPathComponent);
        CFRelease(lastPathComponent);
        
        oldURL = fileURL;
        NSCParameterAssert(oldURL);
        
        fileURL = CFURLCreateCopyDeletingLastPathComponent(allocator, fileURL);
        CFRelease(oldURL);
    }
    
    // we now have a valid FSRef, since the last call to CFURLGetFSRef succeeded (assuming that / will always work)
    // use kARMNoUI to avoid blocking while the Finder tries to mount idisk or other remote volues; this could be an option
    err = FSResolveAliasFileWithMountFlags(&fileRef, TRUE, &isFolder, &wasAliased, kARMNoUI);
    
    // remainder of this code assumes that fileURL is non-NULL, which should always be true
    NSCParameterAssert(fileURL != NULL);
    
    if (noErr != err) {
        
        CFRelease(fileURL);
        fileURL = NULL;
        
    } else {
        
        // try to resolve the FSRef and figure out if it's a directory

        // create a new URL based on the resolved FSRef
        oldURL = fileURL;
        fileURL = CFURLCreateFromFSRef(allocator, &fileRef);
        CFRelease(oldURL);
        
        // now we have an array of stripped components, and an alias-free URL to use as a base
        // start appending stuff to it again, then resolve the resulting FSRef at each step
        CFIndex idx = CFArrayGetCount(strippedComponents);
        while (idx--) {
            
            oldURL = fileURL;
            fileURL = CFURLCreateCopyAppendingPathComponent(allocator, fileURL, CFArrayGetValueAtIndex(strippedComponents, idx), isFolder);
            CFRelease(oldURL);
            
            if (CFURLGetFSRef(fileURL, &fileRef) == FALSE) {
                CFRelease(fileURL);
                fileURL = NULL;
                break;
            }
            
            err = FSResolveAliasFileWithMountFlags(&fileRef, TRUE, &isFolder, &wasAliased, kARMNoUI);
            if (err != noErr) {
                CFRelease(fileURL);
                fileURL = NULL;
                break;
            }
            
            oldURL = fileURL;
            fileURL = CFURLCreateFromFSRef(allocator, &fileRef);
            CFRelease(oldURL);
        }
        
    }
    CFRelease(strippedComponents);
    
    return fileURL;
}

- (NSURL *)fileURLByResolvingAliases
{
    return [(NSURL *)BDCopyFileURLResolvingAliases((CFURLRef)self) autorelease];
}

- (NSURL *)fileURLByResolvingAliasesBeforeLastPathComponent;
{
    CFURLRef theURL = (CFURLRef)self;
    CFStringRef lastPathComponent = CFURLCopyLastPathComponent((CFURLRef)theURL);
    CFAllocatorRef allocator = CFGetAllocator(theURL);
    CFURLRef newURL = CFURLCreateCopyDeletingLastPathComponent(allocator,(CFURLRef)theURL);
    
    if(newURL == NULL){
        if (lastPathComponent) CFRelease(lastPathComponent);
        return nil;
    }
    
    theURL = BDCopyFileURLResolvingAliases(newURL);
    if (newURL) CFRelease(newURL);
    
    if(theURL == nil){
        if (lastPathComponent) CFRelease(lastPathComponent);
        return nil;
    }
    
    // non-last path components have to be folders, right?
    newURL = CFURLCreateCopyAppendingPathComponent(allocator, (CFURLRef)theURL, lastPathComponent, FALSE);
    if (lastPathComponent) CFRelease(lastPathComponent);
    if (theURL) CFRelease(theURL);
    
    return [(id)newURL autorelease];
}

- (NSURL *)URLByDeletingLastPathComponent;
{
    return [(id)CFURLCreateCopyDeletingLastPathComponent(CFGetAllocator((CFURLRef)self), (CFURLRef)self) autorelease];
}

- (NSURL *)URLByDeletingPathExtension;
{
    return [(id)CFURLCreateCopyDeletingPathExtension(CFGetAllocator((CFURLRef)self), (CFURLRef)self) autorelease];
}

+ (NSURL *)URLWithStringByNormalizingPercentEscapes:(NSString *)string;
{
    return [self URLWithStringByNormalizingPercentEscapes:string baseURL:nil];
}

+ (NSURL *)URLWithStringByNormalizingPercentEscapes:(NSString *)string baseURL:(NSURL *)baseURL;
{
    CFStringRef urlString = (CFStringRef)string;

    if(BDIsEmptyString(urlString))
       return nil;

    CFAllocatorRef allocator = baseURL ? CFGetAllocator((CFURLRef)baseURL) : CFAllocatorGetDefault();
    // normalize the URL string; CFURLCreateStringByAddingPercentEscapes appears to have a bug where it replaces some existing percent escapes with a %25, which is the percent character escape, rather than ignoring them as it should
    CFStringRef unescapedString = CFURLCreateStringByReplacingPercentEscapes(allocator, urlString, CFSTR(""));
    if(unescapedString == NULL) return nil;
    
    // we need to validate URL strings, as some DOI URL's contain characters that need to be escaped
    // CFURLCreateStringByAddingPercentEscapes incorrectly escapes fragment separators, so we'll ignore those
    urlString = CFURLCreateStringByAddingPercentEscapes(allocator, unescapedString, CFSTR("#"), NULL, kCFStringEncodingUTF8);
    CFRelease(unescapedString);
    
    CFURLRef theURL = CFURLCreateWithString(allocator, urlString, (CFURLRef)baseURL);
    CFRelease(urlString);
    
    return [(NSURL *)theURL autorelease];
}  

// these characters are not valid in any part of a URL; taken from CFURL.c, sURLValidCharacters[] array
+ (NSCharacterSet *)illegalURLCharacterSet;
{
    static NSCharacterSet *charSet = nil;
    if(charSet == nil){
        NSMutableCharacterSet *validSet = (NSMutableCharacterSet *)[NSMutableCharacterSet characterSetWithCharactersInString:@"!$"];
        [validSet addCharactersInRange:NSMakeRange('&', 22)]; // '&' - ';'
        [validSet addCharactersInString:@"="];
        [validSet addCharactersInRange:NSMakeRange('?', 28)]; // '?' - 'Z'
        [validSet addCharactersInString:@"_"];
        [validSet addCharactersInRange:NSMakeRange('a', 26)]; // 'a' - 'z'
        [validSet addCharactersInString:@"~"];
        charSet = [[validSet invertedSet] copy];
    }
    return charSet;
}

- (NSString *)lastPathComponent;
{
    return [(id)CFURLCopyLastPathComponent((CFURLRef)self) autorelease];
}

- (NSString *)precomposedPath;
{
    return [[self path] precomposedStringWithCanonicalMapping];
}

- (NSString *)pathExtension;
{
    return [(id)CFURLCopyPathExtension((CFURLRef)self) autorelease];
}

#pragma mark Skim Notes

static CFStringRef getUTIForURL(CFURLRef theURL) {
    FSRef fileRef;
    CFStringRef theUTI = NULL;
    if (CFURLGetFSRef(theURL, &fileRef))
        LSCopyItemAttribute(&fileRef, kLSRolesAll, kLSItemContentType, (CFTypeRef *)&theUTI);
    return theUTI;
}

- (NSArray *)SkimNotes {
    NSArray *array = nil;
    if ([self isFileURL]) {
        NSFileManager *fm = [NSFileManager defaultManager];
        CFStringRef theUTI = getUTIForURL((CFURLRef)self);
        if (UTTypeConformsTo(theUTI, CFSTR("net.sourceforge.skim-app.pdfd")))
            array = [fm readSkimNotesFromPDFBundleAtURL:self error:NULL];
        else if (UTTypeConformsTo(theUTI, CFSTR("net.sourceforge.skim-app.skimnotes")))
            array = [fm readSkimNotesFromSkimFileAtURL:self error:NULL];
        else
            array = [fm readSkimNotesFromExtendedAttributesAtURL:self error:NULL];
    }
    return array;
}

- (NSString *)textSkimNotes {
    NSString *string = nil;
    if ([self isFileURL]) {
        NSFileManager *fm = [NSFileManager defaultManager];
        CFStringRef theUTI = getUTIForURL((CFURLRef)self);
        if (UTTypeConformsTo(theUTI, CFSTR("net.sourceforge.skim-app.pdfd")))
            string = [fm readSkimTextNotesFromPDFBundleAtURL:self error:NULL];
        else
            string = [fm readSkimTextNotesFromExtendedAttributesAtURL:self error:NULL];
        if (string == nil) {
            NSArray *notes = [self SkimNotes];
            if (notes)
                string = SKNSkimTextNotes(notes);
        }
    }
    return string;
}

- (NSAttributedString *)richTextSkimNotes {
    NSData *data = nil;
    if ([self isFileURL]) {
        NSFileManager *fm = [NSFileManager defaultManager];
        CFStringRef theUTI = getUTIForURL((CFURLRef)self);
        if (UTTypeConformsTo(theUTI, CFSTR("net.sourceforge.skim-app.pdfd")))
            data = [fm readSkimRTFNotesFromPDFBundleAtURL:self error:NULL];
        else
            data = [fm readSkimRTFNotesFromExtendedAttributesAtURL:self error:NULL];
        if (data == nil) {
            NSArray *notes = [self SkimNotes];
            if (notes)
                data = SKNSkimRTFNotes(notes);
        }
    }
    return data ? [[[NSAttributedString alloc] initWithRTF:data documentAttributes:NULL] autorelease] : nil;
}

#pragma mark Metadata

- (NSInteger)finderLabel{
    return [FVFinderLabel finderLabelForURL:self];
}

- (void)setFinderLabel:(NSInteger)label{
    if (label < 0 || label > 7) label = 0;
    [FVFinderLabel setFinderLabel:label forURL:self];
}

- (NSArray *)openMetaTags{
    return [[NSFileManager defaultManager] openMetaTagsAtPath:[self path] error:NULL] ?: [NSArray array];
}

- (double)openMetaRating{
    return [[[NSFileManager defaultManager] openMetaRatingAtPath:[self path] error:NULL] doubleValue];
}

#pragma mark Templating

- (NSAttributedString *)linkedText {
    return [[[NSAttributedString alloc] initWithString:[self absoluteString] attributeName:NSLinkAttributeName attributeValue:self] autorelease];
}

- (NSAttributedString *)icon {
    NSImage *image = [NSImage imageForURL:self];
    NSString *name = ([self isFileURL]) ? [self path] : [self relativeString];
    name = [[[name lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:@"tiff"];
    
    NSFileWrapper *wrapper = [[NSFileWrapper alloc] initRegularFileWithContents:[image TIFFRepresentation]];
    [wrapper setFilename:name];
    [wrapper setPreferredFilename:name];

    NSTextAttachment *attachment = [[NSTextAttachment alloc] initWithFileWrapper:wrapper];
    [wrapper release];
    NSAttributedString *attrString = [NSAttributedString attributedStringWithAttachment:attachment];
    [attachment release];
    
    return attrString;
}

- (NSAttributedString *)smallIcon {
    NSImage *image = [[[NSImage imageForURL:self] copy] autorelease];
    [image setSize:NSMakeSize(16, 16)];
    NSString *name = ([self isFileURL]) ? [self path] : [self relativeString];
    name = [[[name lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:@"tiff"];
    
    NSFileWrapper *wrapper = [[NSFileWrapper alloc] initRegularFileWithContents:[image TIFFRepresentation]];
    [wrapper setFilename:name];
    [wrapper setPreferredFilename:name];

    NSTextAttachment *attachment = [[NSTextAttachment alloc] initWithFileWrapper:wrapper];
    [wrapper release];
    NSAttributedString *attrString = [NSAttributedString attributedStringWithAttachment:attachment];
    [attachment release];
    
    return attrString;
}

- (NSAttributedString *)linkedIcon {
    NSImage *image = [NSImage imageForURL:self];
    NSString *name = ([self isFileURL]) ? [self path] : [self relativeString];
    name = [[[name lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:@"tiff"];
    
    NSFileWrapper *wrapper = [[NSFileWrapper alloc] initRegularFileWithContents:[image TIFFRepresentation]];
    [wrapper setFilename:name];
    [wrapper setPreferredFilename:name];

    NSTextAttachment *attachment = [[NSTextAttachment alloc] initWithFileWrapper:wrapper];
    [wrapper release];
    NSMutableAttributedString *attrString = [[NSAttributedString attributedStringWithAttachment:attachment] mutableCopy];
    [attachment release];
    [attrString addAttribute:NSLinkAttributeName value:self range:NSMakeRange(0, [attrString length])];
    
    return [attrString autorelease];
}

- (NSAttributedString *)linkedSmallIcon {
    NSImage *image = [[[NSImage imageForURL:self] copy] autorelease];
    [image setSize:NSMakeSize(16, 16)];
    NSString *name = ([self isFileURL]) ? [self path] : [self relativeString];
    name = [[[name lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:@"tiff"];
    
    NSFileWrapper *wrapper = [[NSFileWrapper alloc] initRegularFileWithContents:[image TIFFRepresentation]];
    [wrapper setFilename:name];
    [wrapper setPreferredFilename:name];

    NSTextAttachment *attachment = [[NSTextAttachment alloc] initWithFileWrapper:wrapper];
    [wrapper release];
    NSMutableAttributedString *attrString = [[NSAttributedString attributedStringWithAttachment:attachment] mutableCopy];
    [attachment release];
    [attrString addAttribute:NSLinkAttributeName value:self range:NSMakeRange(0, [attrString length])];
    
    return [attrString autorelease];
}

- (NSTextStorage *)styledTextSkimNotes {
    NSAttributedString *richTextSkimNotes = [self richTextSkimNotes];
    return richTextSkimNotes ? [[[NSTextStorage alloc] initWithAttributedString:richTextSkimNotes] autorelease] : nil;
}

- (NSArray *)scriptingSkimNotes {
    NSMutableArray *notes = [NSMutableArray array];
    for (NSDictionary *note in [self SkimNotes]) {
        note = [note mutableCopy];
        id value;
        if (value = [note objectForKey:SKNPDFAnnotationBoundsKey]) {
            NSRect nsBounds = NSRectFromString(value);
            Rect qdBounds;
            qdBounds.left = BDSKRound(NSMinX(nsBounds));
            qdBounds.bottom = BDSKRound(NSMinY(nsBounds));
            qdBounds.right = BDSKRound(NSMaxX(nsBounds));
            qdBounds.top = BDSKRound(NSMaxY(nsBounds));
            [note setValue:[NSData dataWithBytes:&qdBounds length:sizeof(Rect)] forKey:SKNPDFAnnotationBoundsKey];
        }
        if (value = [note objectForKey:SKNPDFAnnotationPageIndexKey]) {
            [note setValue:[NSNumber numberWithUnsignedInt:[value unsignedIntValue] + 1] forKey:SKNPDFAnnotationPageIndexKey];
        }
        if (value = [note objectForKey:SKNPDFAnnotationBorderStyleKey]) {
            NSString *style = nil;
            switch ([value intValue]) {
                case kPDFBorderStyleSolid: style = @"solid"; break;
                case kPDFBorderStyleDashed: style = @"dashed"; break;
                case kPDFBorderStyleBeveled: style = @"beveled"; break;
                case kPDFBorderStyleInset: style = @"inset"; break;
                case kPDFBorderStyleUnderline: style = @"underline"; break;
            }
            [note setValue:style forKey:SKNPDFAnnotationBorderStyleKey];
        }
        if (value = [note objectForKey:SKNPDFAnnotationStartPointKey]) {
            NSPoint nsPoint = NSPointFromString(value);
            Point qdPoint;
            qdPoint.h = BDSKRound(nsPoint.x);
            qdPoint.v = BDSKRound(nsPoint.y);
            [note setValue:[NSData dataWithBytes:&qdPoint length:sizeof(Point)] forKey:SKNPDFAnnotationStartPointKey];
        }
        if (value = [note objectForKey:SKNPDFAnnotationEndPointKey]) {
            NSPoint nsPoint = NSPointFromString(value);
            Point qdPoint;
            qdPoint.h = BDSKRound(nsPoint.x);
            qdPoint.v = BDSKRound(nsPoint.y);
            [note setValue:[NSData dataWithBytes:&qdPoint length:sizeof(Point)] forKey:SKNPDFAnnotationEndPointKey];
        }
        if (value = [note objectForKey:SKNPDFAnnotationStartLineStyleKey]) {
            NSString *style = nil;
            switch ([value intValue]) {
                case kPDFLineStyleNone: style = @"none"; break;
                case kPDFLineStyleSquare: style = @"square"; break;
                case kPDFLineStyleCircle: style = @"circle"; break;
                case kPDFLineStyleDiamond: style = @"diamond"; break;
                case kPDFLineStyleOpenArrow: style = @"open arrow"; break;
                case kPDFLineStyleClosedArrow: style = @"closed arrow"; break;
            }
            [note setValue:style forKey:SKNPDFAnnotationStartLineStyleKey];
        }
        if (value = [note objectForKey:SKNPDFAnnotationEndLineStyleKey]) {
            NSString *style = nil;
            switch ([value intValue]) {
                case kPDFLineStyleNone: style = @"none"; break;
                case kPDFLineStyleSquare: style = @"square"; break;
                case kPDFLineStyleCircle: style = @"circle"; break;
                case kPDFLineStyleDiamond: style = @"diamond"; break;
                case kPDFLineStyleOpenArrow: style = @"open arrow"; break;
                case kPDFLineStyleClosedArrow: style = @"closed arrow"; break;
            }
            [note setValue:style forKey:SKNPDFAnnotationEndLineStyleKey];
        }
        if (value = [note objectForKey:SKNPDFAnnotationIconTypeKey]) {
            NSString *style = nil;
            switch ([value intValue]) {
                case kPDFTextAnnotationIconComment: style = @"comment"; break;
                case kPDFTextAnnotationIconKey: style = @"key"; break;
                case kPDFTextAnnotationIconNote: style = @"note"; break;
                case kPDFTextAnnotationIconHelp: style = @"help"; break;
                case kPDFTextAnnotationIconNewParagraph: style = @"new paragraph"; break;
                case kPDFTextAnnotationIconParagraph: style = @"paragraph"; break;
                case kPDFTextAnnotationIconInsert: style = @"insert"; break;
            }
            [note setValue:style forKey:SKNPDFAnnotationIconTypeKey];
        }
        if (value = [note objectForKey:SKNPDFAnnotationTextKey]) {
            [note setValue:[[[NSTextStorage alloc] initWithAttributedString:value] autorelease] forKey:SKNPDFAnnotationTextKey];
        }
        if (value = [note objectForKey:SKNPDFAnnotationImageKey]) {
            [note setValue:[NSAppleEventDescriptor descriptorWithDescriptorType:typeTIFF data:[value TIFFRepresentation]] forKey:SKNPDFAnnotationImageKey];
        }
        if (value = [note objectForKey:SKNPDFAnnotationQuadrilateralPointsKey]) {
            NSMutableArray *pathList = [NSMutableArray array];
            NSMutableArray *points = [NSMutableArray array];
            for (NSString *pointString in value) {
                NSPoint nsPoint = NSPointFromString(pointString);
                Point qdPoint;
                qdPoint.h = BDSKRound(nsPoint.x);
                qdPoint.v = BDSKRound(nsPoint.y);
                [points addObject:[NSData dataWithBytes:&qdPoint length:sizeof(Point)]];
                if ([points count] == 4) {
                    [pathList addObject:points];
                    points = [NSMutableArray array];
                }
            }
            [note setValue:nil forKey:SKNPDFAnnotationQuadrilateralPointsKey];
            [note setValue:pathList forKey:SKNPDFAnnotationPointListsKey];
        }
        if (value = [note objectForKey:SKNPDFAnnotationPointListsKey]) {
            NSMutableArray *pathList = [NSMutableArray array];
            for (NSArray *path in value) {
                NSMutableArray *points = [NSMutableArray array];
                for (NSString *pointString in path) {
                    NSPoint nsPoint = NSPointFromString(pointString);
                    Point qdPoint;
                    qdPoint.h = BDSKRound(nsPoint.x);
                    qdPoint.v = BDSKRound(nsPoint.y);
                    [points addObject:[NSData dataWithBytes:&qdPoint length:sizeof(Point)]];
                }
                [pathList addObject:points];
            }
            [note setValue:pathList forKey:SKNPDFAnnotationPointListsKey];
        }
        [notes addObject:note];
        [note release];
    }
    return notes;
}

@end
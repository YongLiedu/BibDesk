//
//  NSURL_BDSKExtensions.m
//  Bibdesk
//
//  Created by Adam Maxwell on 12/19/05.
/*
 This software is Copyright (c) 2005,2006
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
#import "NSImage+Toolbox.h"

static NSString *BDSKAliasResolutionException = @"BDSKAliasResolutionException";

@implementation NSURL (BDSKExtensions)

/* This could as easily have been implemented in the NSFileManager category, but it mainly uses CFURL (and Carbon File Manager) functionality.  Omni has a method in their NSFileManager category that does the same thing, but it assumes PATH_MAX*4 for a max path length, uses malloc instead of NSZoneMalloc, uses path buffers instead of string/URL objects, uses some unnecessary autoreleases, and will resolve aliases on remote volumes.  Of course, it's also been debugged more thoroughly than my version. */

CFURLRef BDCopyFileURLResolvingAliases(CFURLRef fileURL)
{
    NSCParameterAssert([(NSURL *)fileURL isFileURL]);
    
    FSRef fileRef;
    OSErr err;
    Boolean isFolder, wasAliased;
    CFAllocatorRef allocator = CFAllocatorGetDefault();
    
    // take ownership temporarily, since we use this as a local variable later on
    fileURL = CFRetain(fileURL);
    
    CFMutableArrayRef strippedComponents = CFArrayCreateMutable(allocator, 0, &kCFTypeArrayCallBacks);
    CFStringRef lastPathComponent;
    
    // use this to keep a reference to the previous "version" of the file URL, so we can dispose of it properly
    CFURLRef oldURL;
    
    // remove path components until we have a resolvable URL; Apple says that CFURLGetFSRef
    while(CFURLGetFSRef(fileURL, &fileRef) == FALSE){

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
    
    // we now have a valid FSRef, since the last call to CFURLGetFSRef succeeded (assuming that the root will always work)
    // try to resolve the FSRef and figure out if it's a directory or not; use exceptions to avoid if-then madness
    @try{
        
        // use kARMNoUI to avoid blocking while the Finder tries to mount idisk or other remote volues; this could be an option in future
        err = FSResolveAliasFileWithMountFlags(&fileRef, TRUE, &isFolder, &wasAliased, kARMNoUI);
        if(err != noErr)
            @throw BDSKAliasResolutionException;
        
        // create a new URL based on the resolved FSRef
        oldURL = fileURL;
        fileURL = CFURLCreateFromFSRef(allocator, &fileRef);
        CFRelease(oldURL);
        
        // now we have an array of stripped components, and an alias-free URL to use as a base, so start appending stuff to it again, then resolve the resulting FSRef at each step
        CFIndex idx = CFArrayGetCount(strippedComponents);
        while(idx--){
            
            oldURL = fileURL;
            fileURL = CFURLCreateCopyAppendingPathComponent(allocator, fileURL, CFArrayGetValueAtIndex(strippedComponents, idx), isFolder);
            CFRelease(oldURL);
            
            if(CFURLGetFSRef(fileURL, &fileRef) == FALSE)
                @throw BDSKAliasResolutionException;
            
            err = FSResolveAliasFileWithMountFlags(&fileRef, TRUE, &isFolder, &wasAliased, kARMNoUI);
            if(err != noErr)
                @throw BDSKAliasResolutionException;
            
            oldURL = fileURL;
            fileURL = CFURLCreateFromFSRef(allocator, &fileRef);
            CFRelease(oldURL);
        }
    }
    @catch(id exception){
        if(exception == BDSKAliasResolutionException){
            // dispose of the unresolvable fileURL and return NULL in case of error
            CFRelease(fileURL);
            return NULL;
        } else {
            @throw;
        }
    }
    @finally{
        CFRelease(strippedComponents);
    }
    
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
    CFAllocatorRef allocator = CFAllocatorGetDefault();
    CFURLRef newURL = CFURLCreateCopyDeletingLastPathComponent(allocator,(CFURLRef)theURL);
    
    theURL = BDCopyFileURLResolvingAliases(newURL);
    CFRelease(newURL);
    
    if(theURL == nil){
        CFRelease(lastPathComponent);
        return nil;
    }
    
    // non-last path components have to be folders, right?
    newURL = CFURLCreateCopyAppendingPathComponent(allocator, (CFURLRef)theURL, lastPathComponent, FALSE);
    CFRelease(lastPathComponent);
    CFRelease(theURL);
    
    return [(id)newURL autorelease];
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

    CFAllocatorRef allocator = CFAllocatorGetDefault();
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
    NSImage *image = [NSImage smallImageForURL:self];
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

@end
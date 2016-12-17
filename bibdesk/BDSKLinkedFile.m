//
//  BDSKLinkedFile.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 11/12/07.
/*
 This software is Copyright (c) 2007-2016
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

#import "BDSKLinkedFile.h"
#import <CoreServices/CoreServices.h>
#import "BDSKRuntime.h"
#import "NSData_BDSKExtensions.h"

#define BDSKSaveLinkedFilesAsRelativePathOnlyKey @"BDSKSaveLinkedFilesAsRelativePathOnly"

static void BDSKDisposeAliasHandle(AliasHandle inAlias);
static AliasHandle BDSKDataToAliasHandle(CFDataRef inData);
static CFDataRef BDSKCopyAliasHandleToData(AliasHandle inAlias);
static const FSRef *BDSKBaseRefIfOnSameVolume(const FSRef *inBaseRef, const FSRef *inRef);
static Boolean BDSKAliasHandleToFSRef(const AliasHandle inAlias, const FSRef *inBaseRef, FSRef *outRef, Boolean *shouldUpdate);
static AliasHandle BDSKFSRefToAliasHandle(const FSRef *inRef, const FSRef *inBaseRef);
static Boolean BDSKPathToFSRef(CFStringRef inPath, FSRef *outRef);
static AliasHandle BDSKPathToAliasHandle(CFStringRef inPath, CFStringRef inBasePath);

// Private placeholder subclass

@interface BDSKPlaceholderLinkedFile : BDSKLinkedFile
@end

// Private concrete subclasses

@interface BDSKLinkedAliasFile : BDSKLinkedFile {
    AliasHandle alias;
    const FSRef *fileRef;
    NSString *relativePath;
    NSURL *fileURL;
    BOOL isInitial;
    id delegate;
}

- (id)initWithPath:(NSString *)aPath delegate:(id)aDelegate;

- (void)updateFileRef;

- (NSData *)aliasDataRelativeToPath:(NSString *)newBasePath;

- (void)updateWithPath:(NSString *)path basePath:(NSString *)basePath baseRef:(const FSRef *)baseRef;

@end

#pragma mark -

@interface BDSKLinkedURL : BDSKLinkedFile {
    NSURL *URL;
}
@end

#pragma mark -

// Abstract superclass

@implementation BDSKLinkedFile

static BDSKPlaceholderLinkedFile *defaultPlaceholderLinkedFile = nil;
static Class BDSKLinkedFileClass = Nil;
static BOOL saveRelativePathOnly = NO;

+ (void)initialize
{
    BDSKINITIALIZE;
    BDSKLinkedFileClass = self;
    defaultPlaceholderLinkedFile = (BDSKPlaceholderLinkedFile *)NSAllocateObject([BDSKPlaceholderLinkedFile class], 0, NSDefaultMallocZone());
    saveRelativePathOnly = [[NSUserDefaults standardUserDefaults] boolForKey:BDSKSaveLinkedFilesAsRelativePathOnlyKey];
}

+ (id)allocWithZone:(NSZone *)aZone
{
    return BDSKLinkedFileClass == self ? defaultPlaceholderLinkedFile : NSAllocateObject(self, 0, aZone);
}

+ (id)linkedFileWithURL:(NSURL *)aURL delegate:(id<BDSKLinkedFileDelegate>)aDelegate;
{
    return [[[self alloc] initWithURL:aURL delegate:aDelegate] autorelease];
}

+ (id)linkedFileWithBase64String:(NSString *)base64String delegate:(id<BDSKLinkedFileDelegate>)aDelegate;
{
    return [[[self alloc] initWithBase64String:base64String delegate:aDelegate] autorelease];
}

+ (id)linkedFileWithURLString:(NSString *)aString;
{
    return [[[self alloc] initWithURLString:aString] autorelease];
}

- (id)initWithURL:(NSURL *)aURL delegate:(id<BDSKLinkedFileDelegate>)aDelegate;
{
    BDSKRequestConcreteImplementation(self, _cmd);
    return nil;
}

- (id)initWithBase64String:(NSString *)base64String delegate:(id<BDSKLinkedFileDelegate>)aDelegate;
{
    BDSKRequestConcreteImplementation(self, _cmd);
    return nil;
}

- (id)initWithURLString:(NSString *)aString;
{
    BDSKRequestConcreteImplementation(self, _cmd);
    return nil;
}

- (id)copyWithZone:(NSZone *)aZone
{
    BDSKRequestConcreteImplementation(self, _cmd);
    return nil;
}

- (id)initWithCoder:(NSCoder *)coder
{
    BDSKRequestConcreteImplementation(self, _cmd);
    return nil;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    BDSKRequestConcreteImplementation(self, _cmd);
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: URL=%@>", [self class], [self URL]];
}

- (NSURL *)URL
{
    BDSKRequestConcreteImplementation(self, _cmd);
    return nil;
}

- (NSURL *)displayURL;
{
    return [self URL];
}

- (NSString *)path;
{
    return [[self URL] path];
}

- (NSString *)stringRelativeToPath:(NSString *)newBasePath;
{
    BDSKRequestConcreteImplementation(self, _cmd);
    return nil;
}

- (BOOL)isFile { return NO; }

- (void)updateWithPath:(NSString *)aPath {}

- (NSString *)relativePath { return nil; }

- (void)setDelegate:(id<BDSKLinkedFileDelegate>)aDelegate {}
- (id<BDSKLinkedFileDelegate>)delegate { return nil; }

- (NSString *)stringValue {
    return [[self URL] absoluteString];
}

- (NSString *)bibTeXString {
    return [[self stringRelativeToPath:nil] stringAsBibTeXString];
}

// for templating
- (id)valueForUndefinedKey:(NSString *)key {
    return [[self URL] valueForKey:key];
}

@end

#pragma mark -

@implementation BDSKPlaceholderLinkedFile

- (id)init {
    return nil;
}

- (id)initWithURL:(NSURL *)aURL delegate:(id<BDSKLinkedFileDelegate>)aDelegate;
{
    if([aURL isFileURL])
        return (id)[[BDSKLinkedAliasFile alloc] initWithURL:aURL delegate:aDelegate];
    else if (aURL)
        return (id)[[BDSKLinkedURL alloc] initWithURL:aURL delegate:aDelegate];
    else
        return nil;
}

- (id)initWithBase64String:(NSString *)base64String delegate:(id<BDSKLinkedFileDelegate>)aDelegate;
{
    return (id)[[BDSKLinkedAliasFile alloc] initWithBase64String:base64String delegate:aDelegate];
}

- (id)initWithURLString:(NSString *)aString;
{
    return (id)[[BDSKLinkedURL alloc] initWithURLString:aString];
}

- (id)retain { return self; }

- (id)autorelease { return self; }

- (oneway void)release {}

- (NSUInteger)retainCount { return NSUIntegerMax; }

@end

#pragma mark -

// Alias- and FSRef-based concrete subclass for local files

@implementation BDSKLinkedAliasFile

// takes possession of anAlias, even if it fails
- (id)initWithAlias:(AliasHandle)anAlias relativePath:(NSString *)relPath delegate:(id<BDSKLinkedFileDelegate>)aDelegate;
{
    BDSKASSERT(nil != anAlias || nil != relPath);
    BDSKASSERT(nil == aDelegate || [aDelegate respondsToSelector:@selector(basePathForLinkedFile:)]);
    
    self = [super init];
    if (anAlias == nil && relPath == nil) {
        [self release];
        self = nil;
    } else if (self == nil) {
        BDSKDisposeAliasHandle(anAlias);
    } else {
        fileRef = NULL; // this is updated lazily, as we don't know the base path at this point
        alias = anAlias;
        relativePath = [relPath copy];
        delegate = aDelegate;
        fileURL = nil;
        isInitial = YES;
    }
    return self;    
}

- (id)initWithAliasData:(NSData *)data relativePath:(NSString *)relPath delegate:(id<BDSKLinkedFileDelegate>)aDelegate;
{
    AliasHandle anAlias = BDSKDataToAliasHandle((CFDataRef)data);
    return [self initWithAlias:anAlias relativePath:relPath delegate:aDelegate];
}

- (id)initWithBase64String:(NSString *)base64String delegate:(id<BDSKLinkedFileDelegate>)aDelegate;
{
    BDSKASSERT(nil != base64String);
    
    if ([base64String rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].location != NSNotFound || ([base64String length] % 4) != 0) {
        // make a valid base64 string: remove newline and white space characters, and add padding "=" if necessary
        NSMutableString *tmpString = [[base64String mutableCopy] autorelease];
        [tmpString replaceOccurrencesOfCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] withString:@""];
        while (([tmpString length] % 4) != 0)
            [tmpString appendString:@"="];
        base64String = tmpString;
    }
    
    NSData *data = nil;
    NSDictionary *dictionary = nil;
    @try {
        data = [[NSData alloc] initWithBase64String:base64String];
    }
    @catch(id exception) {
        [data release];
        data = nil;
        NSLog(@"Ignoring exception \"%@\" while getting data from base 64 string.", exception);
    }
    @try {
        dictionary = data ? [NSKeyedUnarchiver unarchiveObjectWithData:data] : nil;
    }
    @catch(id exception) {
        NSLog(@"Ignoring exception \"%@\" while unarchiving data from base 64 string.", exception);
    }
    [data release];
    return [self initWithAliasData:[dictionary objectForKey:@"aliasData"] relativePath:[dictionary objectForKey:@"relativePath"] delegate:aDelegate];
}

- (id)initWithPath:(NSString *)aPath delegate:(id<BDSKLinkedFileDelegate>)aDelegate;
{
    BDSKASSERT(nil != aPath);
    BDSKASSERT(nil == aDelegate || [aDelegate respondsToSelector:@selector(basePathForLinkedFile:)]);
    
    NSString *basePath = [aDelegate basePathForLinkedFile:self];
    NSString *relPath = basePath ? [aPath relativePathFromPath:basePath] : nil;
    AliasHandle anAlias = BDSKPathToAliasHandle((CFStringRef)aPath, (CFStringRef)basePath);
    
    if (anAlias == NULL) {
        [self release];
        self = nil;
    } else {
        self = [self initWithAlias:anAlias relativePath:relPath delegate:aDelegate];
        if (self) {
            if (basePath)
                // this initalizes the FSRef and update the alias
                [self updateFileRef];
        }
    }
    return self;
}

- (id)initWithURL:(NSURL *)aURL delegate:(id<BDSKLinkedFileDelegate>)aDelegate;
{
    BDSKASSERT([aURL isFileURL]);
    
    return [self initWithPath:[aURL path] delegate:aDelegate];
}

- (id)initWithURLString:(NSString *)aString;
{
    BDSKASSERT_NOT_REACHED("Attempt to initialize BDSKLinkedAliasFile with a URL string");
    return nil;
}

- (id)initWithCoder:(NSCoder *)coder
{
    NSData *data = nil;
    NSString *relPath = nil;
    if ([coder allowsKeyedCoding]) {
        data = [coder decodeObjectForKey:@"aliasData"];
        relPath = [coder decodeObjectForKey:@"relativePath"];
    } else {
        data = [coder decodeObject];
        relPath = [coder decodeObject];
    }
    return [self initWithAliasData:data relativePath:relPath delegate:nil];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    if ([coder allowsKeyedCoding]) {
        [coder encodeObject:[self aliasDataRelativeToPath:[delegate basePathForLinkedFile:self]] forKey:@"aliasData"];
        [coder encodeObject:relativePath forKey:@"relativePath"];
    } else {
        [coder encodeObject:[self aliasDataRelativeToPath:[delegate basePathForLinkedFile:self]]];
        [coder encodeObject:relativePath];
    }
}

- (void)dealloc
{
    BDSKZONEDESTROY(fileRef);
    BDSKDisposeAliasHandle(alias); alias = NULL;
    BDSKDESTROY(relativePath);
    BDSKDESTROY(fileURL);
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)aZone
{
    return [[[self class] allocWithZone:aZone] initWithAliasData:[self aliasDataRelativeToPath:[delegate basePathForLinkedFile:self]] relativePath:relativePath delegate:delegate];
}

// Should we implement -isEqual: and -hash?

- (NSString *)stringValue {
    return [self path] ?: @"";
}

- (BOOL)isFile
{
    return YES;
}

- (id<BDSKLinkedFileDelegate>)delegate {
    return delegate;
}

- (void)setDelegate:(id<BDSKLinkedFileDelegate>)newDelegate {
    BDSKASSERT(nil == newDelegate || [newDelegate respondsToSelector:@selector(basePathForLinkedFile:)]);
    
    delegate = newDelegate;
}

- (NSString *)relativePath {
    return relativePath;
}

- (void)setFileRef:(FSRef *)aRef {
    BDSKZONEDESTROY(fileRef);
    if (aRef != NULL) {
        FSRef *newRef = (FSRef *)NSZoneMalloc([self zone], sizeof(FSRef));
        if (newRef) {
            bcopy(aRef, newRef, sizeof(FSRef));
            fileRef = newRef;
        }
    }
}

- (void)updateFileRef;
{
    NSString *basePath = [delegate basePathForLinkedFile:self];
    FSRef baseRef;
    Boolean hasBaseRef = BDSKPathToFSRef((CFStringRef)basePath, &baseRef);
    Boolean shouldUpdate = false;
    
    if (fileRef == NULL) {
        FSRef aRef;
        Boolean hasRef = false;
        
        if (fileURL) {
            hasRef = BDSKPathToFSRef((CFStringRef)[fileURL path], &aRef);
            shouldUpdate = hasBaseRef && hasRef;
        }
        
        if (hasRef == false && hasBaseRef && relativePath) {
            NSString *path = [basePath stringByAppendingPathComponent:relativePath];
            shouldUpdate = hasRef = BDSKPathToFSRef((CFStringRef)path, &aRef);
        }
        
        if (hasRef == false && alias != NULL) {
            hasRef = BDSKAliasHandleToFSRef(alias, hasBaseRef ? &baseRef : NULL, &aRef, &shouldUpdate);
            shouldUpdate = (shouldUpdate || relativePath == nil) && hasBaseRef && hasRef;
        }
        
        if (hasRef)
            [self setFileRef:&aRef];
    } else if (relativePath == nil) {
        shouldUpdate = hasBaseRef;
    }
    
    if ((shouldUpdate || fileURL == nil) && fileRef != NULL) {
        NSURL *aURL = (NSURL *)CFURLCreateFromFSRef(NULL, fileRef);
        if (aURL != nil) {
            if (fileURL == nil)
                fileURL = [aURL retain];
            if (shouldUpdate)
                [self updateWithPath:[aURL path] basePath:basePath baseRef:&baseRef];
            [aURL release];
        }
    }
}

- (NSURL *)URL;
{
    BOOL hadFileRef = fileRef != NULL;
    BOOL hadFileURL = fileURL != nil;
    
    if (hadFileRef == NO)
        [self updateFileRef];
    
    CFURLRef aURL = fileRef ? CFURLCreateFromFSRef(NULL, fileRef) : NULL;
    
    if (aURL == NULL && hadFileRef) {
        // fileRef was invalid, try to update it
        [self setFileRef:NULL];
        [self updateFileRef];
        if (fileRef != NULL)
            aURL = CFURLCreateFromFSRef(NULL, fileRef);
    }
    
    BOOL changed = [(NSURL *)aURL isEqual:fileURL] == NO && (aURL != NULL || hadFileURL);
    if (changed) {
        FSRef aRef;
        if (BDSKPathToFSRef((CFStringRef)[fileURL path], &aRef)) {
            // the file was replaced, reference the replacement rather than the moved file
            // this is what Dropbox does with file updates
            [self setFileRef:&aRef];
            BDSKCFDESTROY(aURL);
            aURL = (CFURLRef)[fileURL retain];
            NSString *basePath = [delegate basePathForLinkedFile:self];
            if (BDSKPathToFSRef((CFStringRef)basePath, &aRef))
                [self updateWithPath:[fileURL path] basePath:basePath baseRef:&aRef];
        } else {
            [fileURL release];
            fileURL = [(NSURL *)aURL retain];
        }
        if (isInitial == NO)
            [delegate performSelector:@selector(linkedFileURLChanged:) withObject:self afterDelay:0.0];
    }
    isInitial = NO;
    return [(NSURL *)aURL autorelease];
}

- (NSURL *)displayURL;
{
    NSURL *displayURL = [self URL];
    if (displayURL == nil && relativePath) {
        NSString *basePath = [delegate basePathForLinkedFile:self];
        displayURL = basePath ? [NSURL URLWithString:relativePath relativeToURL:[NSURL fileURLWithPath:basePath]] : [NSURL fileURLWithPath:relativePath];
    }
    return displayURL;
}

- (NSData *)aliasDataRelativeToPath:(NSString *)basePath;
{
    // make sure the fileRef is valid
    [self URL];
    // not sure if this is still needed after the previous call, only does something when there was a valid fileRef, relativePath, and baseRef, then it updates
    [self updateFileRef];
    
    FSRef baseRef;
    AliasHandle anAlias = NULL;
    CFDataRef data = NULL;
    
    if (fileRef) {
        BOOL hasBaseRef = BDSKPathToFSRef((CFStringRef)basePath, &baseRef);
        anAlias = BDSKFSRefToAliasHandle(fileRef, hasBaseRef ? &baseRef : NULL);
    } else if (relativePath && basePath) {
        anAlias = BDSKPathToAliasHandle((CFStringRef)[basePath stringByAppendingPathComponent:relativePath], (CFStringRef)basePath);
    }
    if (anAlias != NULL) {
        data = BDSKCopyAliasHandleToData(anAlias);
        BDSKDisposeAliasHandle(anAlias);
    } else if (alias != NULL) {
        data = BDSKCopyAliasHandleToData(alias);
    }
    
    return [(NSData *)data autorelease];
}

- (NSString *)stringRelativeToPath:(NSString *)newBasePath;
{
    BOOL noAlias = saveRelativePathOnly && newBasePath != nil;
    if (newBasePath == nil)
        newBasePath = [delegate basePathForLinkedFile:self];
    NSData *data = noAlias ? nil : [self aliasDataRelativeToPath:newBasePath];
    NSString *path = [self path];
    path = path && newBasePath ? [path relativePathFromPath:newBasePath] : relativePath;
    if (path == nil && noAlias)
        data = [self aliasDataRelativeToPath:newBasePath];
    NSDictionary *dictionary = data ? [NSDictionary dictionaryWithObjectsAndKeys:data, @"aliasData", path, @"relativePath", nil] : [NSDictionary dictionaryWithObjectsAndKeys:path, @"relativePath", nil];
    return [[NSKeyedArchiver archivedDataWithRootObject:dictionary] base64String];
}

- (void)updateAliasWithPath:(NSString *)aPath basePath:(NSString *)basePath {
    AliasHandle anAlias = BDSKPathToAliasHandle((CFStringRef)aPath, (CFStringRef)basePath);
    if (anAlias != NULL) {
        AliasHandle saveAlias = alias;
        alias = anAlias;
        [self updateFileRef];
        if (fileRef == NULL) {
            BDSKDisposeAliasHandle(anAlias);
            alias = saveAlias;
            [self updateFileRef];
        } else {
            BDSKDisposeAliasHandle(saveAlias);
        }
    }
}

// this could be called when the document fileURL changes
- (void)updateWithPath:(NSString *)aPath {
    NSString *basePath = [delegate basePathForLinkedFile:self];
    
    if (fileRef == NULL) {
        // this does the updating if possible
        [self updateFileRef];
    } else {
        CFURLRef aURL = CFURLCreateFromFSRef(NULL, fileRef);
        if (aURL != NULL) {
            FSRef baseRef;
            if (BDSKPathToFSRef((CFStringRef)basePath, &baseRef))
                [self updateWithPath:[(NSURL *)aURL path] basePath:basePath baseRef:&baseRef];
            CFRelease(aURL);
        } else {
            // the fileRef was invalid, reset it and update
            [self setFileRef:NULL];
            [self updateFileRef];
            if (fileRef == NULL && aPath)
                // this can happen after an auto file to a volume, as the file is actually not moved but copied
                [self updateAliasWithPath:aPath basePath:basePath];
        }
    }
    if (aPath && [[self path] isEqualToString:aPath] == NO) {
        FSRef aRef;
        if (BDSKPathToFSRef((CFStringRef)basePath, &aRef))
            [self updateWithPath:aPath basePath:basePath baseRef:&aRef];
        else
            [self updateAliasWithPath:aPath basePath:basePath];
        if (BDSKPathToFSRef((CFStringRef)aPath, &aRef)) {
            [self setFileRef:&aRef];
            [fileURL release];
            fileURL = [[NSURL alloc] initFileURLWithPath:aPath];
        }
    }
}

- (void)updateWithPath:(NSString *)path basePath:(NSString *)basePath baseRef:(const FSRef *)baseRef {
    BDSKASSERT(path != nil);
    BDSKASSERT(basePath != nil);
    BDSKASSERT(baseRef != NULL);
    BDSKASSERT(fileRef != NULL);
    
    Boolean didUpdate;
    
    // update the alias
    if (alias != NULL)
        FSUpdateAlias(BDSKBaseRefIfOnSameVolume(baseRef, fileRef), fileRef, alias, &didUpdate);
    else
        alias = BDSKFSRefToAliasHandle(fileRef, baseRef);
    
    // update the relative path
    [relativePath autorelease];
    relativePath = [[path relativePathFromPath:basePath] retain];
}

@end

#pragma mark -

// URL based concrete subclass for remote URLs

@implementation BDSKLinkedURL

- (id)initWithURL:(NSURL *)aURL delegate:(id<BDSKLinkedFileDelegate>)aDelegate;
{
    self = [super init];
    if (self) {
        if (aURL) {
            URL = [aURL copy];
        } else {
            [self release];
            self = nil;
        }
            
    }
    return self;
}

- (id)initWithURLString:(NSString *)aString;
{
    return [self initWithURL:[NSURL URLWithString:aString] delegate:nil];
}

- (id)initWithBase64String:(NSString *)base64String delegate:(id<BDSKLinkedFileDelegate>)aDelegate;
{
    BDSKASSERT_NOT_REACHED("Attempt to initialize BDSKLinkedURL with a base 64 string");
    return nil;
}

- (id)copyWithZone:(NSZone *)aZone
{
    return [[[self class] allocWithZone:aZone] initWithURL:URL delegate:nil];
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        if ([coder allowsKeyedCoding]) {
            URL = [[coder decodeObjectForKey:@"URL"] retain];
        } else {
            URL = [[coder decodeObject] retain];
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    if ([coder allowsKeyedCoding]) {
        [coder encodeObject:URL forKey:@"URL"];
    } else {
        [coder encodeObject:URL];
    }
}

- (void)dealloc
{
    BDSKDESTROY(URL);
    [super dealloc];
}

- (NSURL *)URL
{
    return URL;
}

- (NSString *)stringRelativeToPath:(NSString *)newBasePath;
{
    return [URL absoluteString];
}

@end

#pragma mark -

// File reference functions

static void BDSKDisposeAliasHandle(AliasHandle inAlias)
{
    if (inAlias != NULL)
        DisposeHandle((Handle)inAlias);
}

static AliasHandle BDSKDataToAliasHandle(CFDataRef inData)
{
    CFIndex len;
    Handle handle = NULL;
    
    if (inData != NULL) {
        len = CFDataGetLength(inData);
        handle = NewHandle(len);
        
        if ((handle != NULL) && (len > 0)) {
            HLock(handle);
            memmove((void *)*handle, (const void *)CFDataGetBytePtr(inData), len);
            HUnlock(handle);
        }
    }
    return (AliasHandle)handle;
}

static CFDataRef BDSKCopyAliasHandleToData(AliasHandle inAlias)
{
    Handle inHandle = (Handle)inAlias;
    CFDataRef data = NULL;
    CFIndex len;
    SInt8 handleState;
    
    if (inHandle != NULL) {
        len = GetHandleSize(inHandle);
        handleState = HGetState(inHandle);
        
        HLock(inHandle);
        
        data = CFDataCreate(kCFAllocatorDefault, (const UInt8 *) *inHandle, len);
        
        HSetState(inHandle, handleState);
    }
    return data;
}

static const FSRef *BDSKBaseRefIfOnSameVolume(const FSRef *inBaseRef, const FSRef *inRef)
{
    FSCatalogInfo baseCatalogInfo, catalogInfo;
    BOOL sameVolume = NO;
    if (inBaseRef != NULL && inRef != NULL &&
        noErr == FSGetCatalogInfo(inBaseRef, kFSCatInfoVolume, &baseCatalogInfo, NULL, NULL, NULL) &&
        noErr == FSGetCatalogInfo(inRef, kFSCatInfoVolume, &catalogInfo, NULL, NULL, NULL))
        sameVolume = baseCatalogInfo.volume == catalogInfo.volume;
    return sameVolume ? inBaseRef : NULL;
}

static Boolean BDSKAliasHandleToFSRef(const AliasHandle inAlias, const FSRef *inBaseRef, FSRef *outRef, Boolean *shouldUpdate)
{
    OSStatus err = noErr;
    short aliasCount = 1;
    
    // it would be preferable to search the (relative) path before the fileID, but than links to symlinks will always be resolved to the target
    err = FSMatchAliasBulk(inBaseRef, kARMNoUI | kARMSearch | kARMSearchRelFirst | kARMTryFileIDFirst, inAlias, &aliasCount, outRef, shouldUpdate, NULL, NULL);
    
    return noErr == err;
}

static AliasHandle BDSKFSRefToAliasHandle(const FSRef *inRef, const FSRef *inBaseRef)
{
    OSStatus err = noErr;
    AliasHandle	alias = NULL;
    
    err = FSNewAlias(BDSKBaseRefIfOnSameVolume(inBaseRef, inRef), inRef, &alias);
    
    if (err != noErr) {
        BDSKDisposeAliasHandle(alias);
        alias = NULL;
    }
    
    return alias;
}

static Boolean BDSKPathToFSRef(CFStringRef inPath, FSRef *outRef)
{
    OSStatus err = noErr;
    
    if (inPath == NULL)
        err = fnfErr;
    else
        err = FSPathMakeRefWithOptions((UInt8 *)[(NSString *)inPath fileSystemRepresentation], kFSPathMakeRefDoNotFollowLeafSymlink, outRef, NULL); 
    
    return noErr == err;
}

static AliasHandle BDSKPathToAliasHandle(CFStringRef inPath, CFStringRef inBasePath)
{
    FSRef ref, baseRef;
    AliasHandle alias = NULL;
    
    if (BDSKPathToFSRef(inPath, &ref)) {
        if (inBasePath != NULL) {
            if (BDSKPathToFSRef(inBasePath, &baseRef))
                alias = BDSKFSRefToAliasHandle(&ref, &baseRef);
        } else {
            alias = BDSKFSRefToAliasHandle(&ref, NULL);
        }
    }
    
    return alias;
}

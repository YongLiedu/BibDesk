//
//  BDSKLinkedFile.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 11/12/07.
/*
 This software is Copyright (c) 2007-2012
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

#define WEAK_NULL NULL

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

// Private placeholder subclass

@interface BDSKPlaceholderLinkedFile : BDSKLinkedFile
@end

// Private concrete subclasses

@interface BDSKLinkedAliasFile : BDSKLinkedFile
{
    AliasHandle alias;
    const FSRef *fileRef;
    NSString *relativePath;
    NSURL *lastURL;
    BOOL isInitial;
    id delegate;
}

- (id)initWithPath:(NSString *)aPath delegate:(id)aDelegate;

- (const FSRef *)fileRef;

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

+ (void)initialize
{
    BDSKINITIALIZE;
    BDSKLinkedFileClass = self;
    defaultPlaceholderLinkedFile = (BDSKPlaceholderLinkedFile *)NSAllocateObject([BDSKPlaceholderLinkedFile class], 0, NSDefaultMallocZone());
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

- (void)update { [self updateWithPath:nil]; }
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
        return [[BDSKLinkedAliasFile alloc] initWithURL:aURL delegate:aDelegate];
    else if (aURL)
        return [[BDSKLinkedURL alloc] initWithURL:aURL delegate:aDelegate];
    else
        return nil;
}

- (id)initWithBase64String:(NSString *)base64String delegate:(id<BDSKLinkedFileDelegate>)aDelegate;
{
    return [[BDSKLinkedAliasFile alloc] initWithBase64String:base64String delegate:aDelegate];
}

- (id)initWithURLString:(NSString *)aString;
{
    return [[BDSKLinkedURL alloc] initWithURLString:aString];
}

- (id)retain { return self; }

- (id)autorelease { return self; }

- (void)release {}

- (NSUInteger)retainCount { return NSUIntegerMax; }

@end

#pragma mark -

// Alias- and FSRef-based concrete subclass for local files

@implementation BDSKLinkedAliasFile

// takes possession of anAlias, even if it fails
- (id)initWithAlias:(AliasHandle)anAlias relativePath:(NSString *)relPath delegate:(id<BDSKLinkedFileDelegate>)aDelegate;
{
    BDSKASSERT(nil == aDelegate || [aDelegate respondsToSelector:@selector(basePathForLinkedFile:)]);
    self = [super init];
    if (anAlias == NULL) {
        [self release];
        self = nil;
    } else if (self == nil) {
        BDSKDisposeAliasHandle(anAlias);
    } else {
        fileRef = NULL; // this is updated lazily, as we don't know the base path at this point
        alias = anAlias;
        relativePath = [relPath copy];
        delegate = aDelegate;
        lastURL = nil;
        isInitial = YES;
    }
    return self;    
}

- (id)initWithAliasData:(NSData *)data relativePath:(NSString *)relPath delegate:(id<BDSKLinkedFileDelegate>)aDelegate;
{
    BDSKASSERT(nil != data);
    
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
    NSString *relPath = [aPath relativePathFromPath:basePath];
    AliasHandle anAlias = BDSKPathToAliasHandle((CFStringRef)aPath, (CFStringRef)basePath);
    
    self = [self initWithAlias:anAlias relativePath:relPath delegate:aDelegate];
    if (self) {
        if (basePath)
            // this initalizes the FSRef and update the alias
            [self fileRef];
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
    BDSKDESTROY(lastURL);
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

- (void)setRelativePath:(NSString *)newRelativePath {
    if (relativePath != newRelativePath) {
        [relativePath release];
        relativePath = [newRelativePath retain];
    }
}

- (void)setFileRef:(const FSRef *)newFileRef;
{
    if (fileRef != NULL) {
        NSZoneFree([self zone], (void *)fileRef);
        fileRef = NULL;
    }
    if (newFileRef != NULL) {
        FSRef *newRef = (FSRef *)NSZoneMalloc([self zone], sizeof(FSRef));
        if (newRef) {
            bcopy(newFileRef, newRef, sizeof(FSRef));
            fileRef = newRef;
        }
    }
}

- (const FSRef *)fileRef;
{
    NSString *basePath = [delegate basePathForLinkedFile:self];
    FSRef baseRef;
    Boolean hasBaseRef = basePath && BDSKPathToFSRef((CFStringRef)basePath, &baseRef);
    Boolean shouldUpdate = false;
    
    if (fileRef == NULL) {
        FSRef aRef;
        Boolean hasRef = false;
        
        if (hasBaseRef && relativePath) {
            NSString *path = [basePath stringByAppendingPathComponent:relativePath];
            shouldUpdate = hasRef = BDSKPathToFSRef((CFStringRef)path, &aRef);
        }
        
        if (hasRef == false && alias != NULL) {
            hasRef = BDSKAliasHandleToFSRef(alias, hasBaseRef ? &baseRef : NULL, &aRef, &shouldUpdate);
            shouldUpdate = shouldUpdate && hasBaseRef && hasRef;
        }
        
        if (hasRef)
            [self setFileRef:&aRef];
    } else if (relativePath == nil) {
        shouldUpdate = hasBaseRef;
    }
    
    if (shouldUpdate) {
        CFURLRef aURL = CFURLCreateFromFSRef(NULL, fileRef);
        if (aURL != NULL) {
            [self updateWithPath:[(NSURL *)aURL path] basePath:basePath baseRef:&baseRef];
            CFRelease(aURL);
        }
    }
    
    return fileRef;
}

- (NSURL *)URL;
{
    BOOL hadFileRef = fileRef != NULL;
    CFURLRef aURL = (hadFileRef || [self fileRef]) ? CFURLCreateFromFSRef(NULL, fileRef) : NULL;
    
    if (aURL == NULL && hadFileRef) {
        // fileRef was invalid, try to update it
        [self setFileRef:NULL];
        if ([self fileRef] != NULL)
            aURL = CFURLCreateFromFSRef(NULL, fileRef);
    }
    BOOL changed = [(NSURL *)aURL isEqual:lastURL] == NO && (aURL != NULL || lastURL != nil);
    if (changed) {
        [lastURL release];
        lastURL = [(NSURL *)aURL retain];
        if (isInitial == NO)
            [delegate performSelector:@selector(linkedFileURLChanged:) withObject:self afterDelay:0.0];
    }
    isInitial = NO;
    return [(NSURL *)aURL autorelease];
}

- (NSURL *)displayURL;
{
    NSURL *displayURL = [self URL];
    if (displayURL == nil && relativePath)
        displayURL = [NSURL fileURLWithPath:relativePath];
    return displayURL;
}

- (NSData *)aliasDataRelativeToPath:(NSString *)basePath;
{
    // make sure the fileRef is valid
    [self URL];
    
    FSRef *fsRef = (FSRef *)[self fileRef];
    FSRef baseRef;
    AliasHandle anAlias = NULL;
    CFDataRef data = NULL;
    
    if (fsRef) {
        BOOL hasBaseRef = (basePath && BDSKPathToFSRef((CFStringRef)basePath, &baseRef));
        anAlias = BDSKFSRefToAliasHandle(fsRef, hasBaseRef ? &baseRef : NULL);
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
    NSData *data = [self aliasDataRelativeToPath:newBasePath];
    NSString *path = [self path];
    path = path && newBasePath ? [path relativePathFromPath:newBasePath] : relativePath;
    NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:data, @"aliasData", path, @"relativePath", nil];
    return [[NSKeyedArchiver archivedDataWithRootObject:dictionary] base64String];
}

// this could be called when the document fileURL changes
- (void)updateWithPath:(NSString *)aPath {
    NSString *basePath = [delegate basePathForLinkedFile:self];
    
    if (fileRef == NULL) {
        // this does the updating if possible
        [self fileRef];
    } else {
        CFURLRef aURL = CFURLCreateFromFSRef(NULL, fileRef);
        if (aURL != NULL) {
            FSRef baseRef;
            if (basePath && BDSKPathToFSRef((CFStringRef)basePath, &baseRef))
                [self updateWithPath:[(NSURL *)aURL path] basePath:basePath baseRef:&baseRef];
            CFRelease(aURL);
        } else {
            // the fileRef was invalid, reset it and update
            [self setFileRef:NULL];
            [self fileRef];
            if (fileRef == NULL) {
                // this can happen after an auto file to a volume, as the file is actually not moved but copied
                AliasHandle anAlias = BDSKPathToAliasHandle((CFStringRef)aPath, (CFStringRef)basePath);
                if (anAlias != NULL) {
                    AliasHandle saveAlias = alias;
                    alias = anAlias;
                    [self fileRef];
                    if (fileRef == NULL) {
                        alias = saveAlias;
                        [self fileRef];
                    } else {
                        BDSKDisposeAliasHandle(saveAlias);
                    }
                }
            }
        }
    }
    if (aPath && [[self path] isEqualToString:aPath] == NO) {
        FSRef baseRef;
        if (basePath && BDSKPathToFSRef((CFStringRef)basePath, &baseRef)) {
            [self updateWithPath:aPath basePath:basePath baseRef:&baseRef];
        } else {
            AliasHandle anAlias = BDSKPathToAliasHandle((CFStringRef)aPath, (CFStringRef)basePath);
            if (anAlias != NULL) {
                AliasHandle saveAlias = alias;
                alias = anAlias;
                [self fileRef];
                if (fileRef == NULL) {
                    alias = saveAlias;
                    [self fileRef];
                } else {
                    BDSKDisposeAliasHandle(saveAlias);
                }
                
            }
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

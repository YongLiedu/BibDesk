//
//  BDSKLinkedFile.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 11/12/07.
/*
 This software is Copyright (c) 2007
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
#import "BDAlias.h"
#import <OmniFoundation/NSData-OFExtensions.h>

// Private concrete subclasses

@interface BDSKLinkedAliasFile : BDSKLinkedFile
{
    BDAlias *alias;
    const FSRef *fileRef;
    NSString *relativePath;
    id delegate;
}

- (id)initWithPath:(NSString *)aPath delegate:(id)aDelegate;

- (void)setRelativePath:(NSString *)newRelativePath;

- (const FSRef *)fileRef;
- (NSString *)path;

- (NSData *)aliasDataRelativeToPath:(NSString *)newBasePath;

@end

#pragma mark -

@interface BDSKLinkedURL : BDSKLinkedFile {
    NSURL *URL;
}
@end

#pragma mark -

// Abstract superclass

@implementation BDSKLinkedFile

static BDSKLinkedFile *defaultPlaceholderLinkedObject = nil;
static Class BDSKLinkedObjectClass = Nil;

+ (void)initialize
{
    OBINITIALIZE;
    if(self == [BDSKLinkedFile class]){
        BDSKLinkedObjectClass = self;
        defaultPlaceholderLinkedObject = (BDSKLinkedFile *)NSAllocateObject(BDSKLinkedObjectClass, 0, NSDefaultMallocZone());
    }
}

+ (id)allocWithZone:(NSZone *)aZone
{
    return BDSKLinkedObjectClass == self ? defaultPlaceholderLinkedObject : NSAllocateObject(self, 0, aZone);
}

- (id)initWithURL:(NSURL *)aURL delegate:(id)aDelegate;
{
    OBASSERT(self == defaultPlaceholderLinkedObject);
    if([aURL isFileURL]){
        self = [[BDSKLinkedAliasFile alloc] initWithURL:aURL delegate:aDelegate];
    } else if (aURL){
        self = [[BDSKLinkedURL alloc] initWithURL:aURL delegate:aDelegate];
    } else {
        self = nil;
    }
    return self;
}

- (id)initWithBase64String:(NSString *)base64String delegate:(id)aDelegate;
{
    OBASSERT(self == defaultPlaceholderLinkedObject);
    return [[BDSKLinkedAliasFile alloc] initWithBase64String:base64String delegate:aDelegate];
}

- (id)initWithURLString:(NSString *)aString;
{
    OBASSERT(self == defaultPlaceholderLinkedObject);
    return [[BDSKLinkedURL alloc] initWithURLString:aString];
}

- (id)copyWithZone:(NSZone *)aZone
{
    OBRequestConcreteImplementation(self, _cmd);
    return nil;
}

- (id)initWithCoder:(NSCoder *)coder
{
    OBRequestConcreteImplementation(self, _cmd);
    return nil;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    OBRequestConcreteImplementation(self, _cmd);
}

- (void)dealloc
{
    if ([self class] != BDSKLinkedObjectClass)
        [super dealloc];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: URL=%@>", [self class], [self URL]];
}

- (NSURL *)URL
{
    OBRequestConcreteImplementation(self, _cmd);
    return nil;
}

- (NSURL *)displayURL;
{
    return [self URL];
}

- (NSString *)stringRelativeToPath:(NSString *)newBasePath;
{
    OBRequestConcreteImplementation(self, _cmd);
    return nil;
}

- (BOOL)isFile { return NO; }

- (void)update {}

- (NSString *)relativePath { return nil; }

- (void)setDelegate:(id)aDelegate {}
- (id)delegate { return nil; }

// for templating
- (id)valueForUndefinedKey:(NSString *)key {
    return [[self URL] valueForKey:key];
}

@end

#pragma mark -

// Alias- and FSRef-based concrete subclass for local files

@implementation BDSKLinkedAliasFile

// guaranteed to be called with a non-nil alias
- (id)initWithAlias:(BDAlias *)anAlias relativePath:(NSString *)relPath delegate:(id)aDelegate;
{
    NSParameterAssert(nil == aDelegate || [aDelegate respondsToSelector:@selector(baseURLForLinkedFile:)]);
    NSParameterAssert(nil != anAlias);
    if (self = [super init]) {
        fileRef = NULL; // this is updated lazily, as we don't know the base path at this point
        alias = [anAlias retain];
        relativePath = [relPath copy];
        delegate = aDelegate;
    }
    return self;    
}

- (id)initWithAliasData:(NSData *)data relativePath:(NSString *)relPath delegate:(id)aDelegate;
{
    NSParameterAssert(nil != data);
    BDAlias *anAlias = [[BDAlias alloc] initWithData:data];
    self = [self initWithAlias:anAlias relativePath:relPath delegate:aDelegate];
    [anAlias release];
    return self;
}

- (id)initWithBase64String:(NSString *)base64String delegate:(id)aDelegate;
{
    NSParameterAssert(nil != base64String);
    NSData *data = [[NSData alloc] initWithBase64String:base64String];
    NSDictionary *dictionary = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    [data release];
    return [self initWithAliasData:[dictionary objectForKey:@"aliasData"] relativePath:[dictionary objectForKey:@"relativePath"] delegate:aDelegate];
}

- (id)initWithPath:(NSString *)aPath delegate:(id)aDelegate;
{
    NSParameterAssert(nil != aPath);
    NSParameterAssert(nil == aDelegate || [aDelegate respondsToSelector:@selector(baseURLForLinkedFile:)]);
    BDAlias *anAlias = nil;
    NSURL *baseURL = [aDelegate baseURLForLinkedFile:self];
    NSString *basePath = [baseURL path];
    NSString *relPath = nil;
    // BDAlias has a different interpretation of aPath, which is inconsistent with the way it handles FSRef
    if (basePath) {
        relPath = [basePath relativePathToFilename:aPath];
        anAlias = [[BDAlias alloc] initWithPath:relPath relativeToPath:basePath];
    } else {
        anAlias = [[BDAlias alloc] initWithPath:aPath];
    }
    if (anAlias) {
        if ((self = [self initWithAlias:anAlias relativePath:relPath delegate:aDelegate])) {
            if (baseURL)
                // this initalizes the FSRef and update the alias
                [self fileRef];
        }
        [anAlias release];
    } else {
        [[super init] release];
        self = nil;
    }
    return self;
}

- (id)initWithURL:(NSURL *)aURL delegate:(id)aDelegate;
{
    return [self initWithPath:[aURL path] delegate:aDelegate];
}

- (id)initWithURLString:(NSString *)aString;
{
    OBASSERT_NOT_REACHED("Attempt to initialize BDSKLocalFile with a URL string");
    return nil;
}

- (id)initWithCoder:(NSCoder *)coder
{
    OBASSERT_NOT_REACHED("BDSKLinkedAliasFile needs a base path for encoding");
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
    OBASSERT_NOT_REACHED("BDSKLinkedAliasFile needs a base path for encoding");
    if ([coder allowsKeyedCoding]) {
        [coder encodeObject:[self aliasDataRelativeToPath:[[delegate baseURLForLinkedFile:self] path]] forKey:@"aliasData"];
        [coder encodeObject:relativePath forKey:@"relativePath"];
    } else {
        [coder encodeObject:[self aliasDataRelativeToPath:[[delegate baseURLForLinkedFile:self] path]]];
        [coder encodeObject:relativePath];
    }
}

- (void)dealloc
{
    NSZoneFree([self zone], (void *)fileRef);
    [alias release];
    [relativePath release];
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)aZone
{
    // or should this be a real copy, as it is mutable?
    return [self retain];
}

// Should we implement -isEqual: and -hash?

- (NSString *)stringDescription {
    return [self path];
}

- (BOOL)isFile
{
    return YES;
}

- (id)delegate {
    return delegate;
}

- (void)setDelegate:(id)newDelegate {
    NSParameterAssert(nil == newDelegate || [newDelegate respondsToSelector:@selector(baseURLForLinkedFile:)]);
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
    NSURL *baseURL = [delegate baseURLForLinkedFile:self];
    FSRef baseRef;
    Boolean hasBaseRef = baseURL && CFURLGetFSRef((CFURLRef)baseURL, &baseRef);
    Boolean shouldUpdate = false;
    
    if (fileRef == NULL) {
        FSRef aRef;
        short aliasCount = 1;
        Boolean hasRef = false;
        
        if (baseURL && relativePath) {
            NSString *path = [[baseURL path] stringByAppendingPathComponent:relativePath];
            NSURL *tmpURL = [NSURL fileURLWithPath:path];
            
            shouldUpdate = hasRef = hasBaseRef && tmpURL && CFURLGetFSRef((CFURLRef)tmpURL, &aRef);
        }
        
        if (hasRef == false && alias) {
            if (hasBaseRef) {
                hasRef = noErr == FSMatchAliasNoUI(&baseRef, kARMNoUI | kARMSearch | kARMSearchRelFirst, [alias alias], &aliasCount, &aRef, &shouldUpdate, NULL, NULL);
                shouldUpdate = shouldUpdate && hasRef;
            } else {
                hasRef = noErr == FSMatchAliasNoUI(NULL, kARMNoUI | kARMSearch | kARMSearchRelFirst, [alias alias], &aliasCount, &aRef, &shouldUpdate, NULL, NULL);
                shouldUpdate = false;
            }
        }
        
        if (hasRef)
            [self setFileRef:&aRef];
    } else if (relativePath == nil) {
        shouldUpdate = hasBaseRef;
    }
    
    if (shouldUpdate) {
        if (alias)
            FSUpdateAlias(&baseRef, fileRef, [alias alias], &shouldUpdate);
        else
            alias = [[BDAlias alloc] initWithFSRef:(FSRef *)fileRef relativeToFSRef:&baseRef];
        if (baseURL) {
            CFURLRef tmpURL = CFURLCreateFromFSRef(CFAllocatorGetDefault(), fileRef);
            if (tmpURL) {
                [self setRelativePath:[[baseURL path] relativePathToFilename:[(NSURL *)tmpURL path]]];
                CFRelease(tmpURL);
            }
        }
    }
    
    return fileRef;
}

- (NSURL *)URL;
{
    BOOL hadFileRef = fileRef != NULL;
    const FSRef *aRef = [self fileRef];
    NSURL *aURL = aRef == NULL ? nil : [(id)CFURLCreateFromFSRef(CFAllocatorGetDefault(), aRef) autorelease];
    if (aURL == nil && hadFileRef) {
        // apparently fileRef is invalid, try to update it
        [self setFileRef:NULL];
        if (aRef = [self fileRef])
            aURL = [(id)CFURLCreateFromFSRef(CFAllocatorGetDefault(), aRef) autorelease];
    }
    return aURL;
}

- (NSURL *)displayURL;
{
    NSURL *displayURL = [self URL];
    if (displayURL == nil && relativePath)
        displayURL = [NSURL fileURLWithPath:relativePath];
    return displayURL;
}

- (NSString *)path;
{
    return [[self URL] path];
}

- (NSData *)aliasDataRelativeToPath:(NSString *)newBasePath;
{
    // make sure the fileRef is valid
    [self URL];
    
    FSRef *fsRef = (FSRef *)[self fileRef];
    FSRef baseRef;
    NSURL *baseURL;
    BDAlias *anAlias = nil;
    
    if (fsRef) {
        baseURL = newBasePath ? [NSURL fileURLWithPath:newBasePath] : nil;
        if (baseURL && CFURLGetFSRef((CFURLRef)baseURL, &baseRef))
            anAlias = [[[BDAlias alloc] initWithFSRef:fsRef relativeToFSRef:&baseRef] autorelease];
        else
            anAlias = [[[BDAlias alloc] initWithFSRef:fsRef] autorelease];
    } else if (relativePath && newBasePath) {
        anAlias = [[[BDAlias alloc] initWithPath:relativePath relativeToPath:newBasePath] autorelease];
    }
    if (anAlias == nil)
        anAlias = alias;
    
    return [anAlias aliasData];
}

- (NSString *)stringRelativeToPath:(NSString *)newBasePath;
{
    NSData *data = [self aliasDataRelativeToPath:newBasePath];
    NSString *path = [self path];
    path = path && newBasePath ? [newBasePath relativePathToFilename:path] : relativePath;
    NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:data, @"aliasData", path, @"relativePath", nil];
    return [[NSKeyedArchiver archivedDataWithRootObject:dictionary] base64String];
}

// this could be called when the document fileURL changes
- (void)update {
    NSURL *baseURL = [delegate baseURLForLinkedFile:self];
    FSRef baseRef;
    
    if (fileRef == NULL) {
        // this does the updating if possible
        [self fileRef];
    } else {
        CFURLRef aURL = CFURLCreateFromFSRef(CFAllocatorGetDefault(), fileRef);
        if (aURL == NULL) {
            // the fileRef was invalid, reset it and update
            [self setFileRef:NULL];
            [self fileRef];
        } else {
            CFRelease(aURL);
            if (baseURL && CFURLGetFSRef((CFURLRef)baseURL, &baseRef)) {
                Boolean didUpdate;
                if (alias)
                    FSUpdateAlias(&baseRef, fileRef, [alias alias], &didUpdate);
                else
                    alias = [[BDAlias alloc] initWithFSRef:(FSRef *)fileRef relativeToFSRef:&baseRef];
                if (baseURL) {
                    CFURLRef tmpURL = CFURLCreateFromFSRef(CFAllocatorGetDefault(), fileRef);
                    if (tmpURL) {
                        [self setRelativePath:[[baseURL path] relativePathToFilename:[(NSURL *)tmpURL path]]];
                        CFRelease(tmpURL);
                    }
                }
            }
        }
    }
}

@end

#pragma mark -

// URL based concrete subclass for remote URLs

@implementation BDSKLinkedURL

- (id)initWithURL:(NSURL *)aURL delegate:(id)aDelegate;
{
    if (self = [super init]) {
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

- (id)initWithBase64String:(NSString *)base64String delegate:(id)aDelegate;
{
    OBASSERT_NOT_REACHED("Attempt to initialize BDSKLocalURL with a base 64 string");
    return nil;
}

- (id)copyWithZone:(NSZone *)aZone
{
    return [[[self class] alloc] initWithURL:URL];
}

- (id)initWithCoder:(NSCoder *)coder
{
    if (self = [super init]) {
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
    [URL release];
    [super dealloc];
}

- (NSString *)stringDescription {
    return [[self URL] absoluteString];
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

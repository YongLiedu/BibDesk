//
//  BDSKFile.m
//  Bibdesk
//
//  Created by Adam Maxwell on 08/17/06.
/*
 This software is Copyright (c) 2006
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

#import "BDSKFile.h"

@interface NSURL (BDSKPathEquality)
- (BOOL)isEqualToFileURL:(NSURL *)other;
@end

// private subclasses returned by -[BDSKFile init...] methods
@class BDSKURLFile, BDSKFSRefFile;

// singleton returned by -[BDSKFile allocWithZone:]
static BDSKFile *defaultPlaceholderFile = nil;
static Class BDSKFileClass = Nil;

@implementation BDSKFile

/* Lightweight object wrapper for an FSRef, but can also refer to a non-existent file by falling back to an NSURL.  Should not be archived to disk (use BDAlias), but can be passed between processes or threads via DO.  Not safe to use in hashing containers; uses FSRef-based comparison to determine equality if possible, and falls back to comparing paths non-literally and case-insensitively.

   Has some convenience accessors for other data representations.

   TODO:  add copyToDirectory: (FSCopyObject), moveToDirectory: (FSMoveObject), rename: (FSRenameUnicode).  Could also add option to create the file in init... if it doesn't exist.
*/

+ (void)initialize
{
    if(self == [BDSKFile class]){
        BDSKFileClass = self;
        defaultPlaceholderFile = (BDSKFile *)NSAllocateObject(BDSKFileClass, 0, NSDefaultMallocZone());
    }
}

// alloc always returns a placeholder, so concrete subclasses must override it
+ (id)allocWithZone:(NSZone *)aZone
{
    return defaultPlaceholderFile;
}

// designated initializer for the class cluster is -init; all subclasses should call it

// returns an FSRef wrapper
- (id)initWithFSRef:(FSRef *)aRef;
{
    return [[BDSKFSRefFile alloc] initWithFSRef:aRef];
}

// This is a common, convenient initializer, but we prefer to return the FSRef variant so we can use FSCompareFSRefs and survive external name changes.  If the file doesn't exist (yet), though, we return an NSURL variant.
- (id)initWithURL:(NSURL *)aURL;
{
    FSRef aRef;
    
    // return a concrete subclass or nil
    if(aURL && CFURLGetFSRef((CFURLRef)aURL, &aRef)){
        self = [[BDSKFSRefFile alloc] initWithFSRef:&aRef];
    } else if(aURL){
        self = [[BDSKURLFile alloc] initWithURL:aURL];
    } else {
        // nil URL
        self = nil;
    }
    return self;
}

- (id)initWithPath:(NSString *)aPath;
{
    return [self initWithURL:[NSURL fileURLWithPath:aPath]];
}

+ (id)fileWithURL:(NSURL *)aURL { 
    return [[[self allocWithZone:NULL] initWithURL:aURL] autorelease]; 
}

// improved variant of NSObject's pointer-based hash; unsafe to return anything based on name, since it could change
- (unsigned int)hash
{
    return( ((unsigned int) self >> 4) | 
            (unsigned int) self << (32 - 4));
}

// we only want to encode the public superclass
- (Class)classForCoder { return BDSKFileClass; }

// we want NSPortCoder to default to bycopy
- (id)replacementObjectForPortCoder:(NSPortCoder *)encoder
{
    return [encoder isByref] ? (id)[NSDistantObject proxyWithLocal:self connection:[encoder connection]] : self;
}

// convenience if these are used for display directly
- (NSComparisonResult)localizedCaseInsensitiveCompare:(BDSKFile *)other;
{
    return [[self fileName] localizedCaseInsensitiveCompare:[other fileName]];
}

// we support only non-keyed archiving, since NSPortCoder doesn't support keyed archives; use BDAlias for on-disk storage
- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:[self fileURL]];
}

- (id)initWithCoder:(NSCoder *)coder
{
    NSURL *aURL = [coder decodeObject];
    return [self initWithURL:aURL]; // handles [super init]
}

// immutable subclasses may override
- (id)copyWithZone:(NSZone *)aZone
{
    return [[BDSKFile allocWithZone:aZone] initWithURL:[self fileURL]];
}

- (BOOL)isEqual:(id)other
{
    BOOL isEqual = NO;
    if(other == self){
        isEqual = YES;
    
    } else if([other isKindOfClass:BDSKFileClass]){
        const FSRef *otherRef = [other fsRef];
        
        // use accessors for encapsulation...
        const FSRef *fileRef = [self fsRef];
        NSURL *fileURL = [self fileURL];
        
        if(fileRef && otherRef){
            
            // compare the FSRefs directly
            isEqual = (noErr == FSCompareFSRefs(otherRef, fileRef));
            
        } else if(fileRef){ 
            
            // other didn't have an FSRef when created, but let's see if it exists now...
            NSURL *otherURL = [other fileURL];
            FSRef aRef;
            if(CFURLGetFSRef((CFURLRef)otherURL, &aRef)){
                otherRef = &aRef;
                isEqual = (noErr == FSCompareFSRefs(otherRef, fileRef));
            }
            
        } else if(otherRef){ 
            
            // I didn't have an FSRef when created, but let's see if we can create one now...
            FSRef myRef;
            if(CFURLGetFSRef((CFURLRef)fileURL, &myRef)){
                const FSRef *myRefPtr = &myRef;
                isEqual = (noErr == FSCompareFSRefs(otherRef, myRefPtr));
            }
            
        } else { 
            
            // neither object has an FSRef; compare the file URLs as paths
            isEqual = [[other fileURL] isEqualToFileURL:fileURL];
        }
    }
    return isEqual;
}

// primitive methods: subclass responsibility

- (NSURL *)fileURL;
{
    OBRequestConcreteImplementation(self, _cmd);
    return nil;
}

- (const FSRef *)fsRef;
{
    OBRequestConcreteImplementation(self, _cmd);
    return NULL;
}

- (NSString *)fileName;
{
    OBRequestConcreteImplementation(self, _cmd);
    return nil;
}

// following properties are derived using the primitive methods, but subclasses may override for better performance

- (NSString *)path;
{
    return [[self fileURL] path];
}

- (NSString *)tildePath;
{
    return [[self path] stringByAbbreviatingWithTildeInPath];
}

@end

#pragma mark -
#pragma mark NSURL-based concrete subclass

@interface BDSKURLFile : BDSKFile <NSCopying>
{
    NSURL *fileURL;
}
@end

@implementation BDSKURLFile

+ (id)allocWithZone:(NSZone *)aZone
{
    return NSAllocateObject(self, 0, aZone);
}

- (id)initWithURL:(NSURL *)aURL;
{
    self = [super init];
    if(self){
        fileURL = [aURL copy];
    }
    return self;
}

- (void)dealloc
{
    [fileURL release];
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)aZone
{
    return [self retain];
}

- (NSURL *)fileURL;
{
    return fileURL;
}

- (const FSRef *)fsRef;
{
    return NULL;
}

- (NSString *)fileName;
{
    return [(id)CFURLCopyLastPathComponent((CFURLRef)fileURL) autorelease];
}

@end

#pragma mark -
#pragma mark FSRef-based concrete subclass

@interface BDSKFSRefFile : BDSKFile <NSCopying>
{
    const FSRef *fileRef;
}
@end

@implementation BDSKFSRefFile

+ (id)allocWithZone:(NSZone *)aZone
{
    return NSAllocateObject(self, 0, aZone);
}

// guaranteed to be called with a non-NULL FSRef
- (id)initWithFSRef:(FSRef *)aRef;
{
    self = [super init];
    fileRef = NULL;
    
    if(self && aRef){
        FSRef *newRef = NSZoneMalloc([self zone], sizeof(FSRef));
        if(newRef)
            bcopy(aRef, newRef, sizeof(FSRef));
        fileRef = newRef;
    }
    return self;    
}

- (void)dealloc
{
    NSZoneFree([self zone], (void *)fileRef);
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)aZone
{
    return [self retain];
}

- (NSURL *)fileURL;
{
    return [(id)CFURLCreateFromFSRef(CFAllocatorGetDefault(), fileRef) autorelease];
}

- (const FSRef *)fsRef;
{
    return fileRef;
}

static inline CFStringRef copyFileNameFromFSRef(const FSRef *fsRef)
{
    HFSUniStr255 fileName;
    OSErr err = FSGetCatalogInfo(fsRef, kIconServicesCatalogInfoMask, NULL, &fileName, NULL, NULL);
    return noErr == err ? CFStringCreateWithCharacters(CFAllocatorGetDefault(), fileName.unicode, fileName.length) : NULL;
}

- (NSString *)fileName;
{
    return [(NSString *)copyFileNameFromFSRef(fileRef) autorelease];
}

@end

#pragma mark NSURL file equality fix

@implementation NSURL (BDSKPathEquality)

- (BOOL)isEqualToFileURL:(NSURL *)other;
{
    BOOL isEqual = NO;
    if(self == other){
        isEqual = YES;
    } else {
        CFStringRef path1 = CFURLCopyFileSystemPath((CFURLRef)self, kCFURLPOSIXPathStyle);
        CFStringRef path2 = CFURLCopyFileSystemPath((CFURLRef)other, kCFURLPOSIXPathStyle);
        
        // handle case-insensitivity and precomposition
        if(path1 && path2)
            isEqual = CFStringCompareWithOptions(path1, path2, CFRangeMake(0, CFStringGetLength(path1)), kCFCompareCaseInsensitive | kCFCompareNonliteral) == kCFCompareEqualTo;
        
        [(id)path1 release];
        [(id)path2 release];
    }
    return isEqual;
}

@end

//
//  BDSKFile.m
//  Bibdesk
//
//  Created by Adam Maxwell on 08/17/06.
/*
 This software is Copyright (c) 2006,2007
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
#import <OmniBase/assertions.h>
#import <OmniFoundation/NSData-OFExtensions.h>
#import <OmniFoundation/NSString-OFPathExtensions.h>
#import "NSURL_BDSKExtensions.h"
#import "BDAlias.h"

// private subclasses returned by -[BDSKFile init...] methods

@interface BDSKFSRefFile : BDSKFile <NSCopying>
{
    const FSRef *fileRef;
    UInt32 hash;
}
@end

@interface BDSKURLFile : BDSKFile
{
    NSURL *fileURL;
    unsigned int hash;
}
@end

@interface NSURL (BDSKPathEquality)
- (BOOL)isEqualToFileURL:(NSURL *)other;
@end

// singleton returned by -[BDSKFile allocWithZone:]
static BDSKFile *defaultPlaceholderFile = nil;
static Class BDSKFileClass = Nil;

@implementation BDSKFile

/* Lightweight object wrapper for an FSRef, but can also refer to a non-existent file by falling back to an NSURL.  Should not be archived to disk (use BDAlias), but can be passed between processes or threads via DO.  Safe to use in hashing containers; uses FSRef-based comparison to determine equality if possible, and falls back to comparing paths non-literally and case-insensitively.

   Has some convenience accessors for other data representations.

   TODO:  add copyToDirectory: (FSCopyObject), moveToDirectory: (FSMoveObject), rename: (FSRenameUnicode).  Could also add option to create the file in init... if it doesn't exist.
*/

+ (void)initialize
{
    OBINITIALIZE;
    if(self == [BDSKFile class]){
        BDSKFileClass = self;
        defaultPlaceholderFile = (BDSKFile *)NSAllocateObject(BDSKFileClass, 0, NSDefaultMallocZone());
    }
}

+ (id)allocWithZone:(NSZone *)aZone
{
    return BDSKFileClass == self ? defaultPlaceholderFile : NSAllocateObject(self, 0, aZone);
}

// designated initializer for the class cluster is -init; all subclasses should call it

// returns an FSRef wrapper
- (id)initWithFSRef:(FSRef *)aRef;
{
    if(aRef != NULL){
        self = [[BDSKFSRefFile alloc] initWithFSRef:aRef];
    } else {
        self = nil;
    }
    return self;
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

- (void)dealloc
{
    if ([self class] != BDSKFileClass)
        [super dealloc];
}

- (NSString *)description
{
    NSMutableString *desc = [[super description] mutableCopy];
    [desc appendFormat:@" \"%@\"", [self path]];
    return [desc autorelease];
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

@implementation BDSKURLFile

- (id)initWithURL:(NSURL *)aURL;
{
    self = [super init];
    if(self){
        fileURL = [aURL copy];
        
        // @@ case-insensitive because of isEqualToFileURL:; this is true for HFS+, SMB, and AFP, but not UFS or NFS (can we check FS type?)
        hash = BDCaseInsensitiveStringHash([fileURL lastPathComponent]);
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

- (unsigned int)hash
{ 
    return hash; 
}

- (BOOL)isEqual:(id)other
{
    BOOL isEqual = NO;
    if(self == other){
        isEqual = YES;
    } else if([other fsRef] != NULL){
        // always return NO if comparing against an instance with a valid FSRef, since self isn't a valid file (or wasn't when instantiated) and hashes aren't guaranteed to be the same for differend subclasses
        isEqual = [fileURL isEqualToFileURL:[other fileURL]];
    }
#if OMNI_FORCE_ASSERTIONS
    if(isEqual)
        NSAssert([self hash] == [other hash], @"inconsistent hash and isEqual:");
#endif
    return isEqual; 
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

@implementation BDSKFSRefFile

// guaranteed to be called with a non-NULL FSRef
- (id)initWithFSRef:(FSRef *)aRef;
{
    self = [super init];
    fileRef = NULL;
    
    if(self && aRef){
        FSRef *newRef = (FSRef *)NSZoneMalloc([self zone], sizeof(FSRef));
        if(newRef)
            bcopy(aRef, newRef, sizeof(FSRef));
        fileRef = newRef;
        
        // this should be unique per file for our purposes, even across volumes (since FSRefs are not valid across volumes)
        // nodeID is preserved when using Carbon FileManager or NSFileManager to move a file, whereas parentDirID would change
        FSCatalogInfo catalogInfo;
        OSErr err = FSGetCatalogInfo(fileRef, kFSCatInfoNodeID, &catalogInfo, NULL, NULL, NULL);
        if (noErr == err)
            hash = catalogInfo.nodeID;
    }
    return self;    
}

- (void)dealloc
{
    NSZoneFree([self zone], (void *)fileRef);
    [super dealloc];
}

- (BOOL)isEqual:(id)other
{
    BOOL isEqual = NO;
    const FSRef *otherFSRef;
    if(self == other){
        isEqual = YES;
    } else if(NULL != (otherFSRef = [other fsRef]) ){
        
        // only compare with a subclass that has an fsRef; URL variant always returns NULL
        isEqual = (noErr == FSCompareFSRefs(fileRef, otherFSRef));
    }
#if OMNI_FORCE_ASSERTIONS
    if(isEqual)
        NSAssert([self hash] == [other hash], @"inconsistent hash and isEqual:");
#endif
    return isEqual;
}

- (unsigned int)hash
{
    return hash;
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
    OSErr err = FSGetCatalogInfo(fsRef, kFSCatInfoNone, NULL, &fileName, NULL, NULL);
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

#pragma mark -
#pragma mark Alias- and FSRef-based concrete subclass

@implementation BDSKAliasFile

// guaranteed to be called with a non-nil alias
- (id)initWithAlias:(BDAlias *)anAlias;
{
    if (self = [super init]) {
        fileRef = NULL; // this is updated lazily, as we don't know the base path at this point
        alias = [anAlias retain];
    }
    return self;    
}

- (id)initWithData:(NSData *)data;
{
    NSParameterAssert(nil != data);
    BDAlias *anAlias = [[BDAlias alloc] initWithData:data];
    self = [self initWithAlias:anAlias];
    [anAlias release];
    return self;
}

- (id)initWithBase64String:(NSString *)base64String;
{
    NSParameterAssert(nil != base64String);
    NSData *data = [[NSData alloc] initWithBase64String:base64String];
    self = [self initWithData:data];
    [data release];
    return self;
}

- (id)initWithPath:(NSString *)aPath relativeToPath:(NSString *)basePath;
{
    BDAlias *anAlias = nil;
    // BDAlias has a different interpretation of aPath, which is inconsistent with the way it handles FSRef
    if (basePath)
        anAlias = [[BDAlias alloc] initWithPath:[basePath relativePathToFilename:aPath] relativeToPath:basePath];
    else
        anAlias = [[BDAlias alloc] initWithPath:aPath];
    if (anAlias) {
        if ((self = [self initWithAlias:anAlias]) && basePath) {
            // this initalizes the FSRef and update the alias
            [self fsRefRelativeToURL:[NSURL fileURLWithPath:basePath] update:YES];
        }
        [anAlias release];
    } else {
        self = nil;
    }
    return self;
}

- (id)initWithURL:(NSURL *)aURL relativeToURL:(NSURL *)baseURL;
{
    return [self initWithPath:[aURL path] relativeToPath:[baseURL path]];
}

- (id)initWithCoder:(NSCoder *)coder
{
    OBASSERT_NOT_REACHED("BDSKAliasFile needs a base path for encoding");
    return [self initWithData:[coder decodeObject]];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    OBASSERT_NOT_REACHED("BDSKAliasFile needs a base path for encoding");
    [coder encodeObject:[self aliasDataRelativeToPath:nil]];
}

- (void)dealloc
{
    NSZoneFree([self zone], (void *)fileRef);
    [alias release];
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)aZone
{
    // or should this be a real copy, as it is mutable?
    return [self retain];
}

// Should we implement -isEqual: and -hash?

- (const FSRef *)fsRefRelativeToURL:(NSURL *)baseURL update:(BOOL)update;
{
    if (fileRef == NULL && alias) {
        FSRef aRef;
        FSRef baseRef;
        short aliasCount = 1;
        Boolean requireUpdate;
        OSStatus anErr;
        
        if (baseURL)
            CFURLGetFSRef((CFURLRef)baseURL, &baseRef);
        
        if (update)
            anErr = FSResolveAliasWithMountFlags(&baseRef, [alias alias], &aRef, &requireUpdate, kResolveAliasFileNoUI);
        else // I think these options reproduce the behavior of FSResolveAliasWithMountFlags
            anErr = FSMatchAliasNoUI(&baseRef, kARMNoUI | kARMSearch | kARMSearchRelFirst, [alias alias], &aliasCount, &aRef, &requireUpdate, NULL, NULL);
        
        if (anErr == noErr) {
            FSRef *newRef = (FSRef *)NSZoneMalloc([self zone], sizeof(FSRef));
            if(newRef)
                bcopy(&aRef, newRef, sizeof(FSRef));
            fileRef = newRef;
        }
    }
    return fileRef;
}

- (const FSRef *)fsRefRelativeToURL:(NSURL *)baseURL;
{
    return [self fsRefRelativeToURL:baseURL update:YES];
}

- (const FSRef *)fsRef;
{
    return [self fsRefRelativeToURL:nil update:NO];
}

- (NSURL *)fileURLRelativeToURL:(NSURL *)baseURL;
{
    BOOL hadFileRef = fileRef != NULL;
    NSURL *aURL = [(id)CFURLCreateFromFSRef(CFAllocatorGetDefault(), [self fsRefRelativeToURL:baseURL]) autorelease];
    if (aURL == nil && hadFileRef) {
        NSZoneFree([self zone], (void *)fileRef);
        fileRef = NULL;
        aURL = [(id)CFURLCreateFromFSRef(CFAllocatorGetDefault(), [self fsRefRelativeToURL:baseURL]) autorelease];
    }
    return aURL;
}

- (NSURL *)fileURLRelativeToURLNoUpdate:(NSURL *)baseURL;
{
    BOOL hadFileRef = fileRef != NULL;
    NSURL *aURL = [(id)CFURLCreateFromFSRef(CFAllocatorGetDefault(), [self fsRefRelativeToURL:baseURL update:NO]) autorelease];
    if (aURL == nil && hadFileRef) {
        NSZoneFree([self zone], (void *)fileRef);
        fileRef = NULL;
        aURL = [(id)CFURLCreateFromFSRef(CFAllocatorGetDefault(), [self fsRefRelativeToURL:baseURL update:NO]) autorelease];
    }
    return aURL;
}

- (NSURL *)fileURL;
{
    return [self fileURLRelativeToURLNoUpdate:nil];
}

- (NSString *)fileName;
{
    return [(NSString *)copyFileNameFromFSRef([self fsRef]) autorelease];
}

- (NSString *)path;
{
    return [self pathRelativeToPath:nil];
}

- (NSString *)pathRelativeToPath:(NSString *)basePath;
{
    return [[self fileURLRelativeToURL:[NSURL fileURLWithPath:basePath]] path];
}

- (NSString *)pathRelativeToPathNoUpdate:(NSString *)basePath;
{
    return [[self fileURLRelativeToURLNoUpdate:[NSURL fileURLWithPath:basePath]] path];
}

- (BDAlias *)aliasRelativeToPath:(NSString *)basePath;
{
    NSParameterAssert(nil != basePath);
    // make sure the fileRef is valid
    [self fileURLRelativeToURLNoUpdate:[NSURL fileURLWithPath:basePath]];
    
    const FSRef *fsRef = [self fsRefRelativeToURL:[NSURL fileURLWithPath:basePath] update:NO];
    FSRef baseRef, tempRef = *fsRef;
    NSURL *baseURL;
    BDAlias *anAlias = nil;
    
    if (fsRef) {
        baseURL = [NSURL fileURLWithPath:basePath];
        if (baseURL && CFURLGetFSRef((CFURLRef)baseURL, &baseRef))
            anAlias = [[[BDAlias alloc] initWithFSRef:&tempRef relativeToFSRef:&baseRef] autorelease];
        else
            anAlias = [[[BDAlias alloc] initWithFSRef:&tempRef] autorelease];
    } else {
       anAlias = alias;
    }
    
    return anAlias;
}

- (NSData *)aliasDataRelativeToPath:(NSString *)basePath;
{
    return [[self aliasRelativeToPath:basePath] aliasData];
}

- (NSString *)base64StringRelativeToPath:(NSString *)basePath;
{
    return [[self aliasDataRelativeToPath:basePath] base64String];
}

@end

//
//  NSFileManager_BDSKExtensions.m
//  Bibdesk
//
//  Created by Adam Maxwell on 07/08/05.
//
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

#import "NSFileManager_BDSKExtensions.h"
#import "BDSKStringConstants.h"
#import <OmniFoundation/OFResourceFork.h>
#import "NSURL_BDSKExtensions.h"
#import "NSObject_BDSKExtensions.h"
#import "BDSKVersionNumber.h"
#import "NSError_BDSKExtensions.h"
#import <SkimNotes/SKNExtendedAttributeManager.h>

#define OPEN_META_TAGS_KEY @"com.apple.metadata:kOMUserTags"
#define OPEN_META_RATING_KEY @"com.apple.metadata:kOMStarRating"

/* 
The WLDragMapHeaderStruct stuff was borrowed from CocoaTech Foundation, http://www.cocoatech.com (BSD licensed).  This is used for creating WebLoc files, which are a resource-only Finder clipping.  Apple provides no API for creating them, so apparently everyone just reverse-engineers the resource file format and creates them.  Since I have no desire to mess with ResEdit anymore, we're borrowing this code directly and using Omni's resource fork methods to create the file.  Note that you can check the contents of a resource fork in Terminal with `cat somefile/rsrc`, not that it's incredibly helpful. 
*/

#pragma options align=mac68k

typedef struct WLDragMapHeaderStruct
{
    long mapVersion;  // always 1
    long unused1;     // always 0
    long unused2;     // always 0
    short unused;
    short numEntries;   // number of repeating WLDragMapEntries
} WLDragMapHeaderStruct;

typedef struct WLDragMapEntryStruct
{
    OSType type;
    short unused;  // always 0
    ResID resID;   // always 128 or 256?
    long unused1;   // always 0
    long unused2;   // always 0
} WLDragMapEntryStruct;

#pragma options align=reset

@interface WLDragMapEntry : NSObject
{
    OSType _type;
    ResID _resID;
}

+ (id)entryWithType:(OSType)type resID:(int)resID;
+ (NSData*)dragDataWithEntries:(NSArray*)entries;

- (OSType)type;
- (ResID)resID;
- (NSData*)entryData;

@end


@interface OFResourceFork (BDSKExtensions)

// the setData:forResourceType: method apparently sets the wrong resID, so we use this method to override that
- (void)setData:(NSData *)contentData forResourceType:(ResType)resType resID:(short)resID;

@end


@implementation NSFileManager (BDSKExtensions)

static NSString *temporaryBaseDirectory = nil;

// we can't use +initialize in a category, and +load is too dangerous
__attribute__((constructor))
static void createTemporaryDirectory()
{    
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    // Getting the chewable items folder failed for some users; use code from FVCacheFile.mm instead
    // docs say this returns nil in case of failure...so we'll check for it just in case
    NSString *tempDir = NSTemporaryDirectory();
    if (nil == tempDir) {
        fprintf(stderr, "NSTemporaryDirectory() returned nil in createTemporaryDirectory()\n");
        tempDir = @"/tmp";
    }

    // mkdtemp needs a writable string
    char *template = strdup([[tempDir stringByAppendingPathComponent:@"bibdesk.XXXXXX"] fileSystemRepresentation]);

    // use mkdtemp to avoid race conditions
    const char *tempPath = mkdtemp(template);
    
    if (NULL == tempPath) {
        // if this call fails the OS will probably crap out soon, so there's no point in dying gracefully
        perror("mkdtemp failed");
        exit(1);
    }
    
    temporaryBaseDirectory = (NSString *)CFStringCreateWithFileSystemRepresentation(NULL, tempPath);
    free(template);
        
    assert(NULL != temporaryBaseDirectory);
    [pool release];
}

__attribute__((destructor))
static void destroyTemporaryDirectory()
{
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    // clean up at exit; should never be used after this, but set to nil anyway
    if (NO == [[NSFileManager defaultManager] removeFileAtPath:temporaryBaseDirectory handler:nil]) {
        NSLog(@"Unable to remove temp directory %@", temporaryBaseDirectory);
        temporaryBaseDirectory = nil;
    }
    [pool release];
}

- (NSString *)currentApplicationSupportPathForCurrentUser{
    
    static NSString *path = nil;
    
    if(path == nil){
        FSRef foundRef;
        OSStatus err = noErr;
        
        err = FSFindFolder(kUserDomain,  kApplicationSupportFolderType, kCreateFolder, &foundRef);
        if(err != noErr){
            NSLog(@"Error %d:  the system was unable to find your Application Support folder.", err);
            return nil;
        }
        
        CFURLRef url = CFURLCreateFromFSRef(kCFAllocatorDefault, &foundRef);
        
        if(url != nil){
            path = [(NSURL *)url path];
            CFRelease(url);
        }
        
        NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleNameKey];
        
        if(appName == nil)
            [NSException raise:NSObjectNotAvailableException format:NSLocalizedString(@"Unable to find CFBundleIdentifier for %@", @"Exception message"), [NSApp description]];
        
        path = [[path stringByAppendingPathComponent:appName] copy];
        
        // the call to FSFindFolder creates the parent hierarchy, but not the directory we're looking for
        static BOOL dirExists = NO;
        if(dirExists == NO){
            BOOL pathIsDir;
            dirExists = [self fileExistsAtPath:path isDirectory:&pathIsDir];
            if(dirExists == NO || pathIsDir == NO)
                [self createDirectoryAtPath:path attributes:nil];
            // make sure it was created
            dirExists = [self fileExistsAtPath:path isDirectory:&pathIsDir];
            NSAssert1(dirExists && pathIsDir, @"Unable to create folder %@", path);
        }
    }
    
    return path;
}

- (NSString *)applicationSupportDirectory:(SInt16)domain{
    
    FSRef foundRef;
    OSStatus err = noErr;
    
    err = FSFindFolder(domain,
                       kApplicationSupportFolderType,
                       kCreateFolder,
                       &foundRef);
    NSAssert1( err == noErr, @"Error %d:  the system was unable to find your Application Support folder.", err);
    
    CFURLRef url = CFURLCreateFromFSRef(kCFAllocatorDefault, &foundRef);
    NSString *retStr = nil;
    
    if(url != nil){
        retStr = [(NSURL *)url path];
        CFRelease(url);
    }
    
    return retStr;
}

- (NSString *)applicationsDirectory{
    
    NSString *path = nil;
    FSRef foundRef;
    OSStatus err = noErr;
    CFURLRef url = NULL;
    BOOL isDir = YES;
    
    err = FSFindFolder(kLocalDomain,  kApplicationsFolderType, kDontCreateFolder, &foundRef);
    if(err == noErr){
        url = CFURLCreateFromFSRef(kCFAllocatorDefault, &foundRef);
    }
    
    if(url != NULL){
        path = [(NSURL *)url path];
        CFRelease(url);
    }
    
    if(path == nil){
        path = @"/Applications";
        if([self fileExistsAtPath:path isDirectory:&isDir] == NO || isDir == NO){
            NSLog(@"The system was unable to find your Applications folder.", @"");
            return nil;
        }
    }
    
    return path;
}

#pragma mark Temporary files and directories

- (NSString *)temporaryFileWithBasename:(NSString *)fileName;
{
	if(nil == fileName)
        fileName = [[NSProcessInfo processInfo] globallyUniqueString];
	return [self uniqueFilePathWithName:fileName atPath:temporaryBaseDirectory];
}

// This method is subject to a race condition in our temporary directory if we pass the same baseName to this method and temporaryFileWithBasename: simultaneously; hence the lock in uniqueFilePathWithName:atPath:, even though it and temporaryFileWithBasename: are not thread safe or secure.
- (NSString *)makeTemporaryDirectoryWithBasename:(NSString *)baseName {
    NSString *finalPath = nil;
    
    @synchronized(self) {
        if (baseName == nil) {
            CFUUIDRef uuid = CFUUIDCreate(NULL);
            baseName = [(NSString *)CFUUIDCreateString(NULL, uuid) autorelease];
            CFRelease(uuid);
        }
        
        unsigned i = 0;
        NSURL *fileURL = [NSURL fileURLWithPath:[temporaryBaseDirectory stringByAppendingPathComponent:baseName]];
        while ([self objectExistsAtFileURL:fileURL]) {
            fileURL = [NSURL fileURLWithPath:[temporaryBaseDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%i", baseName, ++i]]];
        }
        finalPath = [fileURL path];
        
        // raise if we can't create a file in the chewable folder?
        if (NO == [self createDirectoryAtPathWithNoAttributes:finalPath])
            finalPath = nil;
    }
    return finalPath;
}

- (NSString *)uniqueFilePathWithName:(NSString *)fileName atPath:(NSString *)directory {
    // could expand this path?
    NSParameterAssert([directory isAbsolutePath]);
    NSParameterAssert([fileName isAbsolutePath] == NO);
    NSString *baseName = [fileName stringByDeletingPathExtension];
    NSString *extension = [fileName pathExtension];
    
    // optimistically assume we can just return the sender's guess of /directory/filename
    NSString *fullPath = [directory stringByAppendingPathComponent:fileName];
    int i = 0;
    
    // this method is always invoked from the main thread, but we don't want multiple threads in temporaryBaseDirectory (which may be passed as directory here); could make the lock conditional, but performance isn't a concern here
    @synchronized(self) {
    // if the file exists, try /directory/filename-i.extension
    while([self fileExistsAtPath:fullPath])
        fullPath = [directory stringByAppendingPathComponent:[[NSString stringWithFormat:@"%@-%i", baseName, ++i] stringByAppendingPathExtension:extension]];
    }

	return fullPath;
}

// note: IC is not thread safe
- (NSURL *)downloadFolderURL;
{
    if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_4) {
        
        const OSType dlFolder = 'down'; // 10.5 Folders.h: kDownloadsFolderType = 'down' /* Refers to the ~/Downloads folder*/
        FSRef folderRef;
        OSStatus err = FSFindFolder(kUserDomain, dlFolder, TRUE, &folderRef);
        CFURLRef folderURL = NULL;
        if (noErr == err)
            folderURL = CFURLCreateFromFSRef(CFAllocatorGetDefault(), &folderRef);
        
        if (NULL != folderURL)
            return [(id)folderURL autorelease];
        
        // otherwise continue and try IC, which has been deprecated for years and leaks like a sieve
    }
    
    NSAssert([NSThread inMainThread], @"InternetConfig is not thread safe");
    OSStatus err;
	ICInstance inst;
	ICAttr junk = 0;
	ICFileSpec spec;
    
	static CFURLRef pathURL = NULL;
    static BOOL alreadyTried = NO;
    
    if (NO == alreadyTried) {
        
        alreadyTried = YES;
        
        long size = sizeof(ICFileSpec);
        FSRef pathRef;
        
        err = ICStart(&inst, 'BDSK');
        
        if (noErr == err)
            err = ICBegin(inst, icReadOnlyPerm);
        
        if (err == noErr)
        {
            //Get the downloads folder
            err = ICGetPref(inst, kICDownloadFolder, &junk, &spec, &size);
            
            if (noErr == err) {
                ICEnd(inst);
                ICStop(inst);
            }
            
            // convert FSSpec to FSRef
            err = FSpMakeFSRef(&(spec.fss), &pathRef);
            
            if(err == noErr)
                pathURL = CFURLCreateFromFSRef(CFAllocatorGetDefault(), &pathRef);
            

        }
    }
    return (NSURL *)pathURL;
}

- (NSString *)newestLyXPipePath {
    NSString *appSupportPath = [self applicationSupportDirectory:kUserDomain];
    NSDirectoryEnumerator *dirEnum = [self enumeratorAtPath:appSupportPath];
    NSString *file;
    NSString *lyxPipePath = nil;
    BDSKVersionNumber *version = nil;
    
    while (file = [dirEnum nextObject]) {
        NSString *fullPath = [appSupportPath stringByAppendingPathComponent:file];
        NSDictionary *fileAttributes = [self fileAttributesAtPath:fullPath traverseLink:YES];
        if ([[fileAttributes fileType] isEqualToString:NSFileTypeDirectory]) {
            [dirEnum skipDescendents];
            NSString *pipePath = [fullPath stringByAppendingPathComponent:@".lyxpipe.in"];
            if ([file hasPrefix:@"LyX"] && [self fileExistsAtPath:pipePath]) {
                if (version == nil) {
                    lyxPipePath = pipePath;
                } else {
                    BDSKVersionNumber *fileVersion = nil;
                    if ([file hasPrefix:@"LyX-"])
                        fileVersion = [[[BDSKVersionNumber alloc] initWithVersionString:[file substringFromIndex:4]] autorelease];
                    else
                        fileVersion = [[[BDSKVersionNumber alloc] initWithVersionString:@""] autorelease];
                    if ([fileVersion compareToVersionNumber:version] == NSOrderedDescending) {
                        lyxPipePath = pipePath;
                        version = fileVersion;
                    }
                }
            }
        }
    }
    if (lyxPipePath == nil) {
        NSString *pipePath = [[NSHomeDirectory() stringByAppendingPathComponent:@".lyx"] stringByAppendingPathComponent:@"lyxpipe.in"];
        if ([self fileExistsAtPath:pipePath])
            lyxPipePath = pipePath;
    }
    return lyxPipePath;
}

- (BOOL)copyFileFromSharedSupportToApplicationSupport:(NSString *)fileName overwrite:(BOOL)overwrite{
    NSString *targetPath = [[self currentApplicationSupportPathForCurrentUser] stringByAppendingPathComponent:fileName];
    NSString *sourcePath = [[[NSBundle mainBundle] sharedSupportPath] stringByAppendingPathComponent:fileName];
    if ([self fileExistsAtPath:targetPath]) {
        if (overwrite == NO)
            return NO;
        [self removeFileAtPath:targetPath handler:nil];
    }
    return [self copyPath:sourcePath toPath:targetPath handler:nil];
}

#pragma mark Thread safe methods

- (BOOL)createDirectoryAtPathWithNoAttributes:(NSString *)path
{
    NSParameterAssert(path != nil);
    
    NSURL *parent = [NSURL fileURLWithPath:[path stringByDeletingLastPathComponent]];
    NSString *fileName = [path lastPathComponent];
    unsigned length = [fileName length];
    UniChar *name = (UniChar *)NSZoneMalloc(NULL, length * sizeof(UniChar));
    [fileName getCharacters:name];
    
    FSRef parentFileRef;
    BOOL success = CFURLGetFSRef((CFURLRef)parent, &parentFileRef);
    OSErr err = noErr;
    if(success)    
        err = FSCreateDirectoryUnicode(&parentFileRef, length, name, kFSCatInfoNone, NULL, NULL, NULL, NULL);

    NSZoneFree(NULL, name);
    if(noErr != err)
        success = NO;
    
    return success;
}

- (BOOL)objectExistsAtFileURL:(NSURL *)fileURL{
    NSParameterAssert(fileURL != nil);
    NSParameterAssert([fileURL isFileURL]);
    
    // we can use CFURLGetFSRef to see if a file exists, but it fails if there is an alias in the path before the last path component; this method should return YES even if the file is pointed to by an alias
    CFURLRef resolvedURL = BDCopyFileURLResolvingAliases((CFURLRef)fileURL);
    BOOL exists;
    if(resolvedURL){
        exists = YES;
        CFRelease(resolvedURL);
    } else {
        exists = NO;
    }
    return exists;
}

- (BOOL)deleteObjectAtFileURL:(NSURL *)fileURL error:(NSError **)error{
    NSParameterAssert(fileURL != nil);
    NSParameterAssert([fileURL isFileURL]);

    FSRef fileRef;
    BOOL success = CFURLGetFSRef((CFURLRef)fileURL, &fileRef);
    
    // if we couldn't create the FSRef, try to resolve aliases
    if(NO == success){
        CFURLRef resolvedURL = BDCopyFileURLResolvingAliases((CFURLRef)fileURL);
        if(resolvedURL){
            success = CFURLGetFSRef(resolvedURL, &fileRef);
            CFRelease(resolvedURL);
        } else {
            success = NO;
        }
    }
    
    if(NO == success && error != nil)
        *error = [NSError errorWithDomain:NSCocoaErrorDomain code:0 userInfo:[NSDictionary dictionaryWithObject:NSLocalizedString(@"File does not exist.", @"Error description") forKey:NSLocalizedDescriptionKey]];
    
    if(YES == success){
        success = (noErr == FSDeleteObject(&fileRef));
        if(NO == success && error != nil)
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:0 userInfo:[NSDictionary dictionaryWithObject:NSLocalizedString(@"Unable to delete file.", @"Error description") forKey:NSLocalizedDescriptionKey]];
    }
    
    return success;
}

// Sets a file ref descriptor from a path, without following symlinks
// Based on OAAppKit's fillAEDescFromPath and an example in http://www.cocoadev.com/index.pl?FSMakeFSSpec
static OSErr BDSKFillAEDescFromPath(AEDesc *fileRefDescPtr, NSString *path, BOOL isSymLink)
{
    FSRef fileRef;
    AEDesc fileRefDesc;
    OSErr err;

    bzero(&fileRef, sizeof(fileRef));

    err = FSPathMakeRefWithOptions((UInt8 *)[path fileSystemRepresentation], kFSPathMakeRefDoNotFollowLeafSymlink, &fileRef, NULL);
    
    if (err != noErr) 
        return err;

    AEInitializeDesc(&fileRefDesc);
    err = AECreateDesc(typeFSRef, &fileRef, sizeof(fileRef), &fileRefDesc);

    // Omni says the Finder isn't very good at coercions, so we have to do this ourselves; however we don't want to lose symlinks
    if (err == noErr){
        if(isSymLink == NO)
            err = AECoerceDesc(&fileRefDesc, typeAlias, fileRefDescPtr);
        else
            err = AEDuplicateDesc(&fileRefDesc, fileRefDescPtr);
    }
    AEDisposeDesc(&fileRefDesc);
    
    return err;
}

static OSType finderSignatureBytes = 'MACS';

// Sets the Finder comment (Spotlight comment) field via the Finder; this method takes 0.01s to execute, vs. 0.5s for NSAppleScript
// Based on OAAppKit's setComment:forPath: and http://developer.apple.com/samplecode/MoreAppleEvents/MoreAppleEvents.html (which is dated)
- (BOOL)setComment:(NSString *)comment forURL:(NSURL *)fileURL;
{
    NSParameterAssert(comment != nil);
    NSParameterAssert([fileURL isFileURL]);
    NSString *path = [fileURL path];
    BOOL isSymLink = [[[self fileAttributesAtPath:path traverseLink:NO] objectForKey:NSFileType] isEqualToString:NSFileTypeSymbolicLink];
    BOOL success = YES;
    NSAppleEventDescriptor *commentTextDesc;
    OSErr err;
    AEDesc fileDesc, builtEvent;
    const char *eventFormat =
        "'----': 'obj '{ "         // Direct object is the file comment we want to modify
        "  form: enum(prop), "     //  ... the comment is an object's property...
        "  seld: type(comt), "     //  ... selected by the 'comt' 4CC ...
        "  want: type(prop), "     //  ... which we want to interpret as a property (not as e.g. text).
        "  from: 'obj '{ "         // It's the property of an object...
        "      form: enum(indx), "
        "      want: type(file), " //  ... of type 'file' ...
        "      seld: @,"           //  ... selected by an alias ...
        "      from: null() "      //  ... according to the receiving application.
        "              }"
        "             }, "
        "data: @";                 // The data is what we want to set the direct object to.

    commentTextDesc = [NSAppleEventDescriptor descriptorWithString:comment];
    
    
    AEInitializeDesc(&builtEvent);
    
    err = BDSKFillAEDescFromPath(&fileDesc, path, isSymLink);

    if (err == noErr)
        err = AEBuildAppleEvent(kAECoreSuite, kAESetData,
                                typeApplSignature, &finderSignatureBytes, sizeof(finderSignatureBytes),
                                kAutoGenerateReturnID, kAnyTransactionID,
                                &builtEvent, NULL,
                                eventFormat,
                                &fileDesc, [commentTextDesc aeDesc]);

    AEDisposeDesc(&fileDesc);

    if (err == noErr)
        err = AESendMessage(&builtEvent, NULL, kAENoReply, kAEDefaultTimeout);

    AEDisposeDesc(&builtEvent);
    
    if (err != noErr) {
        NSLog(@"Unable to set comment for file %@", fileURL);
        success = NO;
    }
    return success;
}

// using AESendMessage for this will cause problems when we use it during a drop from Finder
- (NSString *)commentForURL:(NSURL *)fileURL;
{
    NSParameterAssert([fileURL isFileURL]);
    
    MDItemRef mdItem = NULL;
    CFStringRef path = (CFStringRef)[fileURL path];
    NSString *theComment = nil;
    
    if (path && (mdItem = MDItemCreate(CFGetAllocator(path), path))) {
        theComment = (NSString *)MDItemCopyAttribute(mdItem, kMDItemFinderComment);
        CFRelease(mdItem);
        [theComment autorelease];
    }
    return theComment;
}

- (BOOL)copyObjectAtURL:(NSURL *)srcURL toDirectoryAtURL:(NSURL *)dstURL error:(NSError **)error;
{
    NSParameterAssert(srcURL != nil);
    NSParameterAssert(dstURL != nil);
    
    FSRef srcFileRef, dstDirRef;
    BOOL success;
    
    //@@ should we resolve aliases here?
    success = CFURLGetFSRef((CFURLRef)srcURL, &srcFileRef);
    if(success)
        success = CFURLGetFSRef((CFURLRef)dstURL, &dstDirRef);
    
    OSErr err = noErr;
    NSString *comment = [self commentForURL:srcURL];
    FSRef newObjectRef;
    

    // unfortunately, FSCopyObjectSync does not copy Spotlight comments (and neither does NSFileManager) rdar://problem/4531819
    err = FSCopyObjectSync(&srcFileRef, &dstDirRef, NULL, &newObjectRef, 0);
    
    // set the file comment if necessary
    if(noErr == err && nil != comment){
        CFURLRef newFileURL = CFURLCreateFromFSRef(CFAllocatorGetDefault(), &newObjectRef);
        if(newFileURL){
            [self setComment:comment forURL:(NSURL *)newFileURL];
            CFRelease(newFileURL);
        } else {
            err = coreFoundationUnknownErr;
        }
    }        

    if(NO == success && error != nil){
        NSString *errorMessage = nil;
        if(GetMacOSStatusCommentString != NULL && noErr != err)
            errorMessage = [NSString stringWithUTF8String:GetMacOSStatusCommentString(err)];
        if(nil == errorMessage)
            errorMessage = NSLocalizedString(@"Unable to copy file.", @"Error description");
        *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:[NSDictionary dictionaryWithObject:errorMessage forKey:NSLocalizedDescriptionKey]];
    }
    
    return success;
}

#pragma mark Spotlight support

// not application-specific; append the bundle identifier
- (NSString *)metadataFolderPath{
    return [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"Metadata"];
}
    
- (NSString *)spotlightCacheFolderPathByCreating:(NSError **)anError{

    NSString *cachePath = nil;
    
    NSString *basePath = [self metadataFolderPath];
    
    BOOL dirExists = YES;
    
    if(![self objectExistsAtFileURL:[NSURL fileURLWithPath:basePath]])
        dirExists = [self createDirectoryAtPathWithNoAttributes:basePath];
    
    if(dirExists){
        cachePath = [basePath stringByAppendingPathComponent:[[NSBundle mainBundle] bundleIdentifier]];
        if(![self fileExistsAtPath:cachePath])
            dirExists = [self createDirectoryAtPathWithNoAttributes:cachePath];
    }

    if(dirExists == NO && anError != nil){
        *anError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteUnknownError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:basePath, NSFilePathErrorKey, NSLocalizedString(@"Unable to create the cache directory.", @"Error description"), NSLocalizedDescriptionKey, nil]];
    }
        
    return cachePath;
}

- (BOOL)removeSpotlightCacheFolder{
    return [self deleteObjectAtFileURL:[NSURL fileURLWithPath:[self spotlightCacheFolderPathByCreating:NULL]] error:NULL];
}

- (BOOL)spotlightCacheFolderExists{
    NSString *path = [[self metadataFolderPath] stringByAppendingPathComponent:[[NSBundle mainBundle] bundleIdentifier]];
    return [self objectExistsAtFileURL:[NSURL fileURLWithPath:path]];
}

- (BOOL)removeSpotlightCacheFilesForCiteKeys:(NSArray *)itemNames;
{
	NSEnumerator *nameEnum = [itemNames objectEnumerator];
	NSString *name;
	BOOL removed = YES;
	
	while (name = [nameEnum nextObject])
		removed = removed && [self removeSpotlightCacheFileForCiteKey:name];
	return removed;
}

- (NSString *)spotlightCacheFilePathWithCiteKey:(NSString *)citeKey;
{
    // We use citeKey as the file's name, since it needs to be unique and static (relatively speaking), so we can overwrite the old cache content with newer content when saving the document.  We replace pathSeparator in paths, as we can't create subdirectories with -[NSDictionary writeToFile:] (currently this is the POSIX path separator).
    NSString *path = citeKey;
    NSString *pathSeparator = [NSString pathSeparator];
    if([path rangeOfString:pathSeparator].length){
        NSMutableString *mutablePath = [[path mutableCopy] autorelease];
        // replace with % as it can't occur in a cite key, so will still be unique
        [mutablePath replaceOccurrencesOfString:pathSeparator withString:@"%" options:0 range:NSMakeRange(0, [path length])];
        path = mutablePath;
    }
    
    // return nil in case of an empty/nil path
    path = [NSString isEmptyString:path] ? nil : [[self spotlightCacheFolderPathByCreating:NULL] stringByAppendingPathComponent:[path stringByAppendingPathExtension:@"bdskcache"]];
    return path;
}

- (BOOL)removeSpotlightCacheFileForCiteKey:(NSString *)citeKey;
{
    NSString *path = [self spotlightCacheFilePathWithCiteKey:citeKey];
    NSURL *theURL = nil;
    if(path)
        theURL = [NSURL fileURLWithPath:path];
    return theURL ? [self deleteObjectAtFileURL:theURL error:NULL] : NO;
}

#pragma mark Webloc files

- (BOOL)createWeblocFileAtPath:(NSString *)fullPath withURL:(NSURL *)destURL;
{
    BOOL success = YES;

    // create an empty file, since weblocs are just a resource
    NSURL *parent = [NSURL fileURLWithPath:[fullPath stringByDeletingLastPathComponent]];
    NSString *fileName = [fullPath lastPathComponent];
    unsigned length = [fileName length];
    UniChar *name = (UniChar *)NSZoneMalloc(NULL, length * sizeof(UniChar));
    [fileName getCharacters:name];
    
    FSRef parentFileRef, newFileRef;
    success = CFURLGetFSRef((CFURLRef)parent, &parentFileRef);
    OSErr err = noErr;
    if(success)    
        err = FSCreateFileUnicode(&parentFileRef, (UniCharCount)length, name, kFSCatInfoNone, NULL, &newFileRef, NULL);
    NSZoneFree(NULL, name);
    if(noErr != err)
        success = NO;
    
    if(success){
        NSURL *newFile = [(id)CFURLCreateFromFSRef(CFAllocatorGetDefault(), &newFileRef) autorelease];
        OBASSERT([[newFile path] isEqual:fullPath]);
        fullPath = [newFile path];
                
        OFResourceFork *resourceFork = [[OFResourceFork alloc] initWithContentsOfFile:fullPath forkType:OFResourceForkType createFork:YES];

        NSString *urlString = [destURL absoluteString];
        NSData *data = [NSData dataWithBytes:[urlString UTF8String] length:strlen([urlString UTF8String])];
        NSMutableArray *entries = [[NSMutableArray alloc] initWithCapacity:2];

        // write out the same data for text and url resources
        [resourceFork setData:data forResourceType:'TEXT' resID:256];
        [resourceFork setData:data forResourceType:'url ' resID:256];

        [entries addObject:[WLDragMapEntry entryWithType:'TEXT' resID:256]];
        [entries addObject:[WLDragMapEntry entryWithType:'url ' resID:256]];

        // add the drag map entry resources, since we get a corrupt file without them
        [resourceFork setData:[WLDragMapEntry dragDataWithEntries:entries] forResourceType:'drag' resID:128];
        [entries release];
        [resourceFork release];
    }
        
    return success;
}

- (void)createWeblocFiles:(NSDictionary *)fullPathDict{
        
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    @try {    
        NSString *path;
        NSEnumerator *pathEnum = [fullPathDict keyEnumerator];
        
        while(path = [pathEnum nextObject])
            [self createWeblocFileAtPath:path withURL:[fullPathDict objectForKey:path]];
    }
    @catch(id localException) {
        NSLog(@"%@: discarding %@", NSStringFromSelector(_cmd), localException);
    }
    
    @finally {
        [pool release];
    }
}

- (void)copyFilesInPathDictionary:(NSDictionary *)fullPathDict{
        
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    NSString *originalPath;
    NSEnumerator *pathEnum = [fullPathDict keyEnumerator];
    NSError *error;
    NSURL *dstDir;
    while(originalPath = [pathEnum nextObject]){
        dstDir = [NSURL fileURLWithPath:[[fullPathDict valueForKey:originalPath] stringByDeletingLastPathComponent]];
        if([self copyObjectAtURL:[NSURL fileURLWithPath:originalPath] toDirectoryAtURL:dstDir error:&error])
            NSLog(@"Unable to copy %@ to %@.  Error %@", originalPath, [fullPathDict valueForKey:originalPath], error);
    }
    [pool release];
}

- (void)copyFilesInBackgroundThread:(NSDictionary *)fullPathDict{
    [NSThread detachNewThreadSelector:@selector(copyFilesInPathDictionary:) toTarget:self withObject:fullPathDict];
}

- (void)createWeblocFilesInBackgroundThread:(NSDictionary *)fullPathDict{
    [NSThread detachNewThreadSelector:@selector(createWeblocFiles:) toTarget:self withObject:fullPathDict];
}

#pragma mark Apple String Encoding

- (BOOL)setAppleStringEncoding:(NSStringEncoding)nsEncoding atPath:(NSString *)path error:(NSError **)error;
{
    NSParameterAssert(0 != nsEncoding);
    CFStringEncoding cfEncoding = CFStringConvertNSStringEncodingToEncoding(nsEncoding);
    CFStringRef name = CFStringConvertEncodingToIANACharSetName(cfEncoding);
    NSString *encodingString = [NSString stringWithFormat:@"%@;%d", name, cfEncoding];
    return [[SKNExtendedAttributeManager sharedNoSplitManager] setExtendedAttributeNamed:@"com.apple.TextEncoding" toValue:[encodingString dataUsingEncoding:NSUTF8StringEncoding] atPath:path options:0 error:error];
}

- (NSStringEncoding)appleStringEncodingAtPath:(NSString *)path error:(NSError **)error;
{
    NSData *eaData = [[SKNExtendedAttributeManager sharedNoSplitManager] extendedAttributeNamed:@"com.apple.TextEncoding" atPath:path traverseLink:YES error:error];
    NSString *encodingString = nil;
    
    // IANA charset names should be ASCII, but utf-8 is compatible
    /*
     MACINTOSH;0
     UTF-8;134217984
     UTF-8;
     ;3071
     */
    
    if (nil != eaData)
        encodingString = [[[NSString alloc] initWithData:eaData encoding:NSUTF8StringEncoding] autorelease];
    
    // this is not a valid NSStringEncoding
    NSStringEncoding nsEncoding = 0;
    NSArray *array = nil;
    if (encodingString)
        array = [encodingString componentsSeparatedByString:@";"];
    
    // currently only two elements, but may become arbitrarily long in future
    if ([array count] >= 2) {
        CFStringEncoding cfEncoding = [[array objectAtIndex:1] unsignedIntValue];
        nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding);
    }
    else if ([array count] > 0) {
        CFStringRef name = (CFStringRef)[array objectAtIndex:0];
        CFStringEncoding cfEncoding = CFStringConvertIANACharSetNameToEncoding(name);
        nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding);
    }
    else if (NULL != error && nil != encodingString /* we read something from EA, but couldn't understand it */) {
        *error = [NSError mutableLocalErrorWithCode:kBDSKStringEncodingError localizedDescription:NSLocalizedString(@"Unable to interpret com.apple.TextEncoding", @"")];
    }
    
    return nsEncoding;
}

#pragma mark Open Meta tags

// Support for Open Meta tags and rating
// These are just definitions for special EA names and the format of their values
// They're saved as serialized property list values, which is the same as SKNExtendedAttributeManager does without splitting and compression
// See http://code.google.com/p/openmeta/ for some documentation and sample code

- (NSArray *)openMetaTagsAtPath:(NSString *)path error:(NSError **)error {
    return [[SKNExtendedAttributeManager sharedNoSplitManager] propertyListFromExtendedAttributeNamed:OPEN_META_TAGS_KEY atPath:path traverseLink:YES error:error];
}

- (BOOL)setOpenMetaTags:(NSArray *)tags atPath:(NSString *)path error:(NSError **)error {
   if (tags)
        return [[SKNExtendedAttributeManager sharedNoSplitManager] setExtendedAttributeNamed:OPEN_META_TAGS_KEY toPropertyListValue:tags atPath:path options:kSKNXattrNoCompress error:error];
    else
        return [[SKNExtendedAttributeManager sharedNoSplitManager] removeExtendedAttributeNamed:OPEN_META_TAGS_KEY atPath:path traverseLink:YES error:error];
}

- (NSNumber *)openMetaRatingAtPath:(NSString *)path error:(NSError **)error {
    return [[SKNExtendedAttributeManager sharedNoSplitManager] propertyListFromExtendedAttributeNamed:OPEN_META_RATING_KEY atPath:path traverseLink:YES error:error];
}

- (BOOL)setOpenMetaRating:(NSNumber *)rating atPath:(NSString *)path error:(NSError **)error {
    if (rating)
        return [[SKNExtendedAttributeManager sharedNoSplitManager] setExtendedAttributeNamed:OPEN_META_RATING_KEY toPropertyListValue:rating atPath:path options:kSKNXattrNoCompress error:error];
    else
        return [[SKNExtendedAttributeManager sharedNoSplitManager] removeExtendedAttributeNamed:OPEN_META_RATING_KEY atPath:path traverseLink:YES error:error];
}

@end

@implementation WLDragMapEntry

- (id)initWithType:(OSType)type resID:(int)resID;
{
    self = [super init];
    
    _type = type;
    _resID = resID;
    
    return self;
}

+ (id)entryWithType:(OSType)type resID:(int)resID;
{
    WLDragMapEntry* result = [[WLDragMapEntry alloc] initWithType:type resID:resID];
    
    return [result autorelease];
}

- (OSType)type;
{
    return _type;
}

- (ResID)resID;
{
    return _resID;
}

- (NSData*)entryData;
{
    WLDragMapEntryStruct result;
    
    // zero the structure
    memset(&result, 0, sizeof(result));
    
    result.type = _type;
    result.resID = _resID;
    
    return [NSData dataWithBytes:&result length:sizeof(result)];
}

+ (NSData*)dragDataWithEntries:(NSArray*)entries;
{
    NSMutableData *result;
    WLDragMapHeaderStruct header;
    
    // zero the structure
    memset(&header, 0, sizeof(WLDragMapHeaderStruct));
    
    header.mapVersion = 1;
    header.numEntries = [entries count];
    
    result = [NSMutableData dataWithBytes:&header length:sizeof(WLDragMapHeaderStruct)];
    
    [result performSelector:@selector(appendData:) withObjectsByMakingObjectsFromArray:entries performSelector:@selector(entryData)];
    
    return result;
}

@end

@implementation OFResourceFork (BDSKExtensions)

- (void)setData:(NSData *)contentData forResourceType:(ResType)resType resID:(short)resID;
{
    SInt16 oldCurRsrcMap;
    
    oldCurRsrcMap = CurResFile();
    UseResFile(refNum);
    
    const void *data = [contentData bytes];
    Handle dataHandle;
    PtrToHand(data, &dataHandle, [contentData length]);
    Str255 dst;
    CFStringGetPascalString(CFSTR("OFResourceForkData"), dst, 256, kCFStringEncodingASCII);
    AddResource(dataHandle, resType, resID, dst);
    
    UpdateResFile(refNum);
    UseResFile(oldCurRsrcMap);
}

@end

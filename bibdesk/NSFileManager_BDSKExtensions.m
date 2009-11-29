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
 
/*
 Some methods in this category are copied from OmniFoundation 
 and are subject to the following licence:
 
 Omni Source License 2007

 OPEN PERMISSION TO USE AND REPRODUCE OMNI SOURCE CODE SOFTWARE

 Omni Source Code software is available from The Omni Group on their 
 web site at http://www.omnigroup.com/www.omnigroup.com. 

 Permission is hereby granted, free of charge, to any person obtaining 
 a copy of this software and associated documentation files (the 
 "Software"), to deal in the Software without restriction, including 
 without limitation the rights to use, copy, modify, merge, publish, 
 distribute, sublicense, and/or sell copies of the Software, and to 
 permit persons to whom the Software is furnished to do so, subject to 
 the following conditions:

 Any original copyright notices and this permission notice shall be 
 included in all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, 
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF 
 MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. 
 IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY 
 CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, 
 TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE 
 SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "NSFileManager_BDSKExtensions.h"
#import "BDSKStringConstants.h"
#import "NSURL_BDSKExtensions.h"
#import "BDSKVersionNumber.h"
#import "NSError_BDSKExtensions.h"
#import "CFString_BDSKExtensions.h"
#import <SkimNotesBase/SkimNotesBase.h>
#import <CoreServices/CoreServices.h>

#define OPEN_META_TAGS_KEY @"com.apple.metadata:kOMUserTags"
#define OPEN_META_RATING_KEY @"com.apple.metadata:kOMStarRating"

/* 
The WLDragMapHeaderStruct stuff was borrowed from CocoaTech Foundation, http://www.cocoatech.com (BSD licensed).  This is used for creating WebLoc files, which are a resource-only Finder clipping.  Apple provides no API for creating them, so apparently everyone just reverse-engineers the resource file format and creates them.  Since I have no desire to mess with ResEdit anymore, we're borrowing this code directly and using Omni's resource fork methods to create the file.  Note that you can check the contents of a resource fork in Terminal with `cat somefile/rsrc`, not that it's incredibly helpful. 
*/

#if !__LP64__
#pragma options align=mac68k
#endif

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

#if !__LP64__
#pragma options align=reset
#endif

@interface WLDragMapEntry : NSObject
{
    OSType _type;
    ResID _resID;
}

+ (id)entryWithType:(OSType)type resID:(NSInteger)resID;
+ (NSData*)dragDataWithEntries:(NSArray*)entries;

- (OSType)type;
- (ResID)resID;
- (NSData*)entryData;

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
    if (NO == [[NSFileManager defaultManager] removeItemAtPath:temporaryBaseDirectory error:NULL]) {
        NSLog(@"Unable to remove temp directory %@", temporaryBaseDirectory);
        temporaryBaseDirectory = nil;
    }
    [pool release];
}

static NSString *findSpecialFolder(FSVolumeRefNum domain, OSType folderType, Boolean createFolder) {
    FSRef foundRef;
    OSStatus err = noErr;
    CFURLRef url = NULL;
    NSString *path = nil;
    
    err = FSFindFolder(domain, folderType, createFolder, &foundRef);
    if (err != noErr)
        NSLog(@"Error %d:  the system was unable to find your folder of type %i in domain %i.", err, folderType, domain);
    else
        url = CFURLCreateFromFSRef(kCFAllocatorDefault, &foundRef);
    
    if(url != NULL){
        path = [(NSURL *)url path];
        CFRelease(url);
    }
    
    return path;
}

- (NSString *)currentApplicationSupportPathForCurrentUser{
    
    static NSString *path = nil;
    
    if(path == nil){
        path = findSpecialFolder(kUserDomain, kApplicationSupportFolderType, kCreateFolder);
        
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
                [self createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:NULL];
            // make sure it was created
            dirExists = [self fileExistsAtPath:path isDirectory:&pathIsDir];
            NSAssert1(dirExists && pathIsDir, @"Unable to create folder %@", path);
        }
    }
    
    return path;
}

- (NSString *)applicationSupportDirectory:(SInt16)domain{
    return findSpecialFolder(domain, kApplicationSupportFolderType, kCreateFolder);
}

- (NSString *)applicationsDirectory{
    NSString *path = findSpecialFolder(kLocalDomain, kApplicationSupportFolderType, kDontCreateFolder);
    
    if(path == nil){
        path = @"/Applications";
        BOOL isDir;
        if([self fileExistsAtPath:path isDirectory:&isDir] == NO || isDir == NO){
            NSLog(@"The system was unable to find your Applications folder.", @"");
            return nil;
        }
    }
    
    return path;
}

- (NSString *)desktopDirectory {
    return findSpecialFolder(kUserDomain, kDesktopFolderType, kCreateFolder);
}

// note: IC is not thread safe
- (NSURL *)downloadFolderURL;
{
    FSRef pathRef;
    CFURLRef downloadsURL = NULL;
    
    if (noErr == FSFindFolder(kUserDomain, kDownloadsFolderType, TRUE, &pathRef))
        downloadsURL = CFURLCreateFromFSRef(CFAllocatorGetDefault(), &pathRef);
    
    return [(NSURL *)downloadsURL autorelease];
}

- (NSString *)newestLyXPipePath {
    NSString *appSupportPath = [self applicationSupportDirectory:kUserDomain];
    NSDirectoryEnumerator *dirEnum = [self enumeratorAtPath:appSupportPath];
    NSString *file;
    NSString *lyxPipePath = nil;
    BDSKVersionNumber *version = nil;
    
    while (file = [dirEnum nextObject]) {
        NSString *fullPath = [appSupportPath stringByAppendingPathComponent:file];
        NSDictionary *fileAttributes = [self attributesOfItemAtPath:fullPath error:NULL];
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
        [self removeItemAtPath:targetPath error:NULL];
    }
    return [self copyItemAtPath:sourcePath toPath:targetPath error:NULL];
}

- (void)copyAllExportTemplatesToApplicationSupportAndOverwrite:(BOOL)overwrite{
    NSString *applicationSupport = [self currentApplicationSupportPathForCurrentUser];
    NSString *templates = @"Templates";
    NSString *templatesPath = [applicationSupport stringByAppendingPathComponent:templates];
    BOOL success = NO;
    
    if ([self fileExistsAtPath:templatesPath isDirectory:&success] == NO)
        success = [self createDirectoryAtPath:templatesPath withIntermediateDirectories:NO attributes:nil error:NULL];
    if (success) {
        for (NSString *file in [self contentsOfDirectoryAtPath:templatesPath error:NULL]) {
            if ([file hasPrefix:@"."] == NO)
                [self copyFileFromSharedSupportToApplicationSupport:[templates stringByAppendingPathComponent:file] overwrite:overwrite];
        }
    }
}

#pragma mark Temporary files and directories

// This method is copied and modified from NSFileManager-OFExtensions.m
// Note that due to the permissions behavior of FSFindFolder, this shouldn't have the security problems that raw calls to -uniqueFilenameFromName: may have.
- (NSString *)temporaryPathForWritingToPath:(NSString *)path error:(NSError **)outError
/*" Returns a unique filename in the -temporaryDirectoryForFileSystemContainingPath: for the filesystem containing the given path.  The returned path is suitable for writing to and then replacing the input path using -replaceFileAtPath:withFileAtPath:handler:.  This means that the result should never be equal to the input path.  If no suitable temporary items folder is found and allowOriginalDirectory is NO, this will raise.  If allowOriginalDirectory is YES, on the other hand, this will return a file name in the same folder.  Note that passing YES for allowOriginalDirectory could potentially result in security implications of the form noted with -uniqueFilenameFromName:. "*/
{
    BDSKPRECONDITION(![NSString isEmptyString:path]);
    
    NSString *tempFileName = nil;
    
    // first find the Temporary Items folder for the volume containing path
    // The file in question might not exist yet.  This loop assumes that it will terminate due to '/' always being valid.
    OSErr err;
    FSRef ref;
    NSString *attempt = path;
    while (YES) {
        CFURLRef url = (CFURLRef)[NSURL fileURLWithPath:attempt];
        if (CFURLGetFSRef((CFURLRef)url, &ref))
            break;
        attempt = [attempt stringByDeletingLastPathComponent];
    }
    
    FSCatalogInfo catalogInfo;
    err = FSGetCatalogInfo(&ref, kFSCatInfoVolume, &catalogInfo, NULL, NULL, NULL);
    if (err != noErr) {
        NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil]; // underlying error
        if(outError)
            *outError = [NSError localErrorWithCode:kBDSKCannotFindTemporaryDirectoryError localizedDescription:[NSString stringWithFormat:@"Unable to get catalog info for '%@'", path] underlyingError:error];
        return nil;
    }
    
    NSString *tempItemsPath = findSpecialFolder(catalogInfo.volume, kTemporaryFolderType, kCreateFolder);
    if (tempItemsPath == nil) {
        NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil]; // underlying error
        if (outError)
            *outError = [NSError localErrorWithCode:kBDSKCannotFindTemporaryDirectoryError localizedDescription:[NSString stringWithFormat:@"Unable to find temporary items directory for '%@'", path] underlyingError:error];
    }
    
    if (tempItemsPath) {
        // Don't pass in paths that are already inside Temporary Items or you might get back the same path you passed in.
        if (tempFileName = [self uniqueFilePathWithName:[path lastPathComponent] atPath:tempItemsPath]) {
            NSInteger fd = open((const char *)[self fileSystemRepresentationWithPath:tempFileName], O_EXCL | O_WRONLY | O_CREAT | O_TRUNC, 0666);
            if (fd != -1)
                close(fd); // no unlink, were are on the 'create' branch
            else if (errno != EEXIST)
                tempFileName = nil;
        }
    }
    
    if (tempFileName == nil) {
        if (outError)
            *outError = nil; // Ignore any previous error
        // Try to use the same directory.  Can't just call -uniqueFilenameFromName:path since we want a NEW file name (-uniqueFilenameFromName: would just return the input path and the caller expecting a path where it can put something temporarily, i.e., different from the input path).
        if (tempFileName = [self uniqueFilePathWithName:[path lastPathComponent] atPath:[path stringByDeletingLastPathComponent]]) {
            NSInteger fd = open((const char *)[self fileSystemRepresentationWithPath:tempFileName], O_EXCL | O_WRONLY | O_CREAT | O_TRUNC, 0666);
            if (fd != -1)
                close(fd); // no unlink, were are on the 'create' branch
            else if (errno != EEXIST)
                tempFileName = nil;
        }
    }
    
    if (tempFileName == nil && outError)
        *outError = [NSError localErrorWithCode:kBDSKCannotCreateTemporaryFileError localizedDescription:[NSString stringWithFormat:@"Unable to create unique file for %@.", path]];
    
    BDSKPOSTCONDITION(!tempFileName || [self fileExistsAtPath:tempFileName] || ![path isEqualToString:tempFileName]);
    
    return tempFileName;
}

- (NSString *)temporaryFileWithBasename:(NSString *)fileName {
	return [self uniqueFilePathWithName:fileName atPath:temporaryBaseDirectory ?: [[NSProcessInfo processInfo] globallyUniqueString]];
}

// This method is subject to a race condition in our temporary directory if we pass the same baseName to this method and temporaryFileWithBasename: simultaneously; hence the lock in uniqueFilePathWithName:atPath:, even though it and temporaryFileWithBasename: are not thread safe or secure.
- (NSString *)makeTemporaryDirectoryWithBasename:(NSString *)baseName {
    NSString *finalPath = nil;
    
    @synchronized(self) {
        if (baseName == nil)
            baseName = [(NSString *)BDCreateUniqueString() autorelease];
        
        NSUInteger i = 0;
        NSURL *fileURL = [NSURL fileURLWithPath:[temporaryBaseDirectory stringByAppendingPathComponent:baseName]];
        while ([self objectExistsAtFileURL:fileURL]) {
            fileURL = [NSURL fileURLWithPath:[temporaryBaseDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%lu", baseName, (unsigned long)++i]]];
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
    NSInteger i = 0;
    
    // this method is always invoked from the main thread, but we don't want multiple threads in temporaryBaseDirectory (which may be passed as directory here); could make the lock conditional, but performance isn't a concern here
    @synchronized(self) {
        // if the file exists, try /directory/filename-i.extension
        while([self fileExistsAtPath:fullPath]) {
            fullPath = [directory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%lu", baseName, (unsigned long)++i]];
            if (extension)
                fullPath = [fullPath stringByAppendingPathExtension:extension];
        }
    }

	return fullPath;
}

#pragma mark Creating paths

- (BOOL)createPathToFile:(NSString *)path attributes:(NSDictionary *)attributes;
    // Creates any directories needed to be able to create a file at the specified path.  Returns NO on failure.
{
    NSString *directory = [path stringByDeletingLastPathComponent];
    BOOL isDir;
    BOOL success = NO;
    if ([directory length] == 0)
        success = YES;
    else if ([self fileExistsAtPath:directory isDirectory:&isDir] == NO)
        success = [self createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:attributes error:NULL];
    else if (isDir)
        success = YES;
    return success;
}

#pragma mark Resoving aliases

// This method is copied and modified from NSFileManager-OFExtensions.m
- (NSString *)resolveAliasesInPath:(NSString *)originalPath
{
    FSRef ref, originalRefOfPath;
    OSErr err;
    char *buffer;
    UInt32 bufferSize;
    Boolean isFolder, wasAliased;
    NSMutableArray *strippedComponents;
    NSString *path;

    if ([NSString isEmptyString:originalPath])
        return nil;
    
    path = [originalPath stringByStandardizingPath]; // maybe use stringByExpandingTildeInPath instead?
    strippedComponents = [[NSMutableArray alloc] init];
    [strippedComponents autorelease];

    /* First convert the path into an FSRef. If necessary, strip components from the end of the pathname until we reach a resolvable path. */
    for(;;) {
        bzero(&ref, sizeof(ref));
        err = FSPathMakeRef((const unsigned char *)[path fileSystemRepresentation], &ref, &isFolder);
        if (err == noErr)
            break;  // We've resolved the first portion of the path to an FSRef.
        else if (err == fnfErr || err == nsvErr || err == dirNFErr) {  // Not found --- try walking up the tree.
            NSString *stripped;

            stripped = [path lastPathComponent];
            if ([NSString isEmptyString:stripped])
                return nil;

            [strippedComponents addObject:stripped];
            path = [path stringByDeletingLastPathComponent];
        } else
            return nil;  // Some other error; return nil.
    }
    /* Stash a copy of the FSRef we got from 'path'. In the common case, we'll be converting this very same FSRef back into a path, in which case we can just re-use the original path. */
    bcopy(&ref, &originalRefOfPath, sizeof(FSRef));

    /* Repeatedly resolve aliases and add stripped path components until done. */
    for(;;) {
        
        /* Resolve any aliases. */
        /* TODO: Verify that we don't need to repeatedly call FSResolveAliasFile(). We're passing TRUE for resolveAliasChains, which suggests that the call will continue resolving aliases until it reaches a non-alias, but that parameter's meaning is not actually documented in the Apple File Manager API docs. However, I can't seem to get the finder to *create* an alias to an alias in the first place, so this probably isn't much of a problem.
        (Why not simply call FSResolveAliasFile() repeatedly since I don't know if it's necessary? Because it can be a fairly time-consuming call if the volume is e.g. a remote WebDAVFS volume.) */
        err = FSResolveAliasFile(&ref, TRUE, &isFolder, &wasAliased);
        /* if it's a regular file and not an alias, FSResolveAliasFile() will return noErr and set wasAliased to false */
        if (err != noErr)
            return nil;

        /* Append one stripped path component. */
        if ([strippedComponents count] > 0) {
            UniChar *componentName;
            UniCharCount componentNameLength;
            NSString *nextComponent;
            FSRef newRef;
            
            if (!isFolder) {
                // Whoa --- we've arrived at a non-folder. Can't continue.
                // (A volume root is considered a folder, as you'd expect.)
                return nil;
            }
            
            nextComponent = [strippedComponents lastObject];
            componentNameLength = [nextComponent length];
            componentName = malloc(componentNameLength * sizeof(UniChar));
            BDSKASSERT(sizeof(UniChar) == sizeof(unichar));
            [nextComponent getCharacters:componentName];
            bzero(&newRef, sizeof(newRef));
            err = FSMakeFSRefUnicode(&ref, componentNameLength, componentName, kTextEncodingUnknown, &newRef);
            free(componentName);

            if (err == fnfErr) {
                /* The current ref is a directory, but it doesn't contain anything with the name of the next component. Quit walking the filesystem and append the unresolved components to the name of the directory. */
                break;
            } else if (err != noErr) {
                /* Some other error. Give up. */
                return nil;
            }

            bcopy(&newRef, &ref, sizeof(ref));
            [strippedComponents removeLastObject];
        } else {
            /* If we don't have any path components to re-resolve, we're done. */
            break;
        }
    }

    if (FSCompareFSRefs(&originalRefOfPath, &ref) != noErr) {
        /* Convert our FSRef back into a path. */
        /* PATH_MAX*4 is a generous guess as to the largest path we can expect. CoreFoundation appears to just use PATH_MAX, so I'm pretty confident this is big enough. */
        buffer = malloc(bufferSize = (PATH_MAX * 4));
        err = FSRefMakePath(&ref, (unsigned char *)buffer, bufferSize);
        if (err == noErr) {
            path = [NSString stringWithUTF8String:buffer];
        } else {
            path = nil;
        }
        free(buffer);
    }

    /* Append any unresolvable path components to the resolved directory. */
    while ([strippedComponents count] > 0) {
        path = [path stringByAppendingPathComponent:[strippedComponents lastObject]];
        [strippedComponents removeLastObject];
    }

    return path;
}

#pragma mark Thread safe methods

- (BOOL)createDirectoryAtPathWithNoAttributes:(NSString *)path
{
    NSParameterAssert(path != nil);
    
    NSURL *parent = [NSURL fileURLWithPath:[path stringByDeletingLastPathComponent]];
    NSString *fileName = [path lastPathComponent];
    NSUInteger length = [fileName length];
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

// The following function is copied from Apple's MoreFilesX sample project

struct FSDeleteContainerGlobals
{
	OSErr							result;			/* result */
	ItemCount						actualObjects;	/* number of objects returned */
	FSCatalogInfo					catalogInfo;	/* FSCatalogInfo */
};
typedef struct FSDeleteContainerGlobals FSDeleteContainerGlobals;

static
void
FSDeleteContainerLevel(
	const FSRef *container,
	FSDeleteContainerGlobals *theGlobals)
{
	/* level locals */
	FSIterator					iterator;
	FSRef						itemToDelete;
	UInt16						nodeFlags;
	
	/* Open FSIterator for flat access and give delete optimization hint */
	theGlobals->result = FSOpenIterator(container, kFSIterateFlat + kFSIterateDelete, &iterator);
	require_noerr(theGlobals->result, FSOpenIterator);
	
	/* delete the contents of the directory */
	do
	{
		/* get 1 item to delete */
		theGlobals->result = FSGetCatalogInfoBulk(iterator, 1, &theGlobals->actualObjects,
								NULL, kFSCatInfoNodeFlags, &theGlobals->catalogInfo,
								&itemToDelete, NULL, NULL);
		if ( (noErr == theGlobals->result) && (1 == theGlobals->actualObjects) )
		{
			/* save node flags in local in case we have to recurse */
			nodeFlags = theGlobals->catalogInfo.nodeFlags;
			
			/* is it a file or directory? */
			if ( 0 != (nodeFlags & kFSNodeIsDirectoryMask) )
			{
				/* it's a directory -- delete its contents before attempting to delete it */
				FSDeleteContainerLevel(&itemToDelete, theGlobals);
			}
			/* are we still OK to delete? */
			if ( noErr == theGlobals->result )
			{
				/* is item locked? */
				if ( 0 != (nodeFlags & kFSNodeLockedMask) )
				{
					/* then attempt to unlock it (ignore result since FSDeleteObject will set it correctly) */
					theGlobals->catalogInfo.nodeFlags = nodeFlags & ~kFSNodeLockedMask;
					(void) FSSetCatalogInfo(&itemToDelete, kFSCatInfoNodeFlags, &theGlobals->catalogInfo);
				}
				/* delete the item */
				theGlobals->result = FSDeleteObject(&itemToDelete);
			}
		}
	} while ( noErr == theGlobals->result );
	
	/* we found the end of the items normally, so return noErr */
	if ( errFSNoMoreItems == theGlobals->result )
	{
		theGlobals->result = noErr;
	}
	
	/* close the FSIterator (closing an open iterator should never fail) */
	verify_noerr(FSCloseIterator(iterator));

FSOpenIterator:

	return;
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
    
    if(NO == success && error != NULL)
        *error = [NSError errorWithDomain:NSCocoaErrorDomain code:0 userInfo:[NSDictionary dictionaryWithObject:NSLocalizedString(@"File does not exist.", @"Error description") forKey:NSLocalizedDescriptionKey]];
    
    if(success){
        FSCatalogInfo catalogInfo;
        success = (noErr == FSGetCatalogInfo(&fileRef, kFSCatInfoNodeFlags, &catalogInfo, NULL, NULL, NULL));
        if(NO == success && error != NULL)
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:0 userInfo:[NSDictionary dictionaryWithObject:NSLocalizedString(@"Unable to delete file.", @"Error description") forKey:NSLocalizedDescriptionKey]];
        
        if(success && 0 != (catalogInfo.nodeFlags & kFSNodeIsDirectoryMask)){
            FSDeleteContainerGlobals theGlobals;
            FSDeleteContainerLevel(&fileRef, &theGlobals);
            success = (noErr == theGlobals.result);
            if(NO == success && error != NULL)
                *error = [NSError errorWithDomain:NSCocoaErrorDomain code:0 userInfo:[NSDictionary dictionaryWithObject:NSLocalizedString(@"Unable to delete directory contents.", @"Error description") forKey:NSLocalizedDescriptionKey]];
        }
        
        if(success){
            success = (noErr == FSDeleteObject(&fileRef));
            if(NO == success && error != NULL)
                *error = [NSError errorWithDomain:NSCocoaErrorDomain code:0 userInfo:[NSDictionary dictionaryWithObject:NSLocalizedString(@"Unable to delete file.", @"Error description") forKey:NSLocalizedDescriptionKey]];
        }
    }
    
    return success;
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
    FSRef newObjectRef;
    
    err = FSCopyObjectSync(&srcFileRef, &dstDirRef, NULL, &newObjectRef, 0);
    
    if(NO == success && error != nil){
        NSString *errorMessage = nil;
        if(noErr != err)
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
	BOOL removed = YES;
	
	for (NSString *name in itemNames)
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
    NSUInteger length = [fileName length];
    UniChar *name = (UniChar *)NSZoneMalloc(NULL, length * sizeof(UniChar));
    [fileName getCharacters:name];
    
    FSRef parentFileRef, newFileRef;
    success = CFURLGetFSRef((CFURLRef)parent, &parentFileRef);
    OSErr err = noErr;
    if (success)    
        err = FSCreateFileUnicode(&parentFileRef, (UniCharCount)length, name, kFSCatInfoNone, NULL, &newFileRef, NULL);
    NSZoneFree(NULL, name);
    if (noErr != err)
        success = NO;
    
    // open the resource fork
    HFSUniStr255 forkName;
    ResFileRefNum refNum;
    
    if (success)
        err = FSGetResourceForkName(&forkName);
    if (err != noErr)
        success = NO;
    
    if (success) {
        err = FSOpenResourceFile(&newFileRef, forkName.length, forkName.unicode, fsCurPerm, &refNum);
        if (err != noErr) {
            err = FSCreateResourceFork(&newFileRef, forkName.length, forkName.unicode, 0);
            if (err == noErr)
                err = FSOpenResourceFile(&newFileRef, forkName.length, forkName.unicode, fsCurPerm, &refNum);
        }
        if (err == noErr)
            success = NO;
    }
    
    if (success) {
        // at this point we have opened the resource fork, remember the current resource file
        SInt16 oldCurRsrcMap;
        oldCurRsrcMap = CurResFile();
        UseResFile(refNum);
        
        // get the data we should write to the resource fork
        NSString *urlString = [destURL absoluteString];
        NSData *data = [NSData dataWithBytes:[urlString UTF8String] length:strlen([urlString UTF8String])];
        NSMutableArray *entries = [[NSMutableArray alloc] initWithCapacity:2];
        NSData *entriesData;
        
        [entries addObject:[WLDragMapEntry entryWithType:'TEXT' resID:256]];
        [entries addObject:[WLDragMapEntry entryWithType:'url ' resID:256]];
        entriesData = [WLDragMapEntry dragDataWithEntries:entries];
        [entries release];
        
        Handle dataHandle;
        Str255 dst;
        
        CFStringGetPascalString(CFSTR("BDSKResourceForkData"), dst, 256, kCFStringEncodingASCII);
        
        // write out the same data for text and url resources
        PtrToHand((const void *)[data bytes], &dataHandle, [data length]);
        AddResource(dataHandle, 'TEXT', 256, dst);
        PtrToHand((const void *)[data bytes], &dataHandle, [data length]);
        AddResource(dataHandle, 'url ', 256, dst);
        PtrToHand((const void *)[entriesData bytes], &dataHandle, [entriesData length]);
        AddResource(dataHandle, 'drag', 128, dst);
        
        // reset the current resource file and close the resource fork
        UpdateResFile(refNum);
        UseResFile(oldCurRsrcMap);
        CloseResFile(refNum);
    }
        
    return success;
}

- (void)createWeblocFiles:(NSDictionary *)fullPathDict{
        
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    @try {    
        for (NSString *path in fullPathDict)
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
    
    NSError *error;
    NSURL *dstDir;
    for (NSString *originalPath in fullPathDict) {
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
    NSString *encodingString = [NSString stringWithFormat:@"%@;%lu", name, (unsigned long)cfEncoding];
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
        CFStringEncoding cfEncoding = [[array objectAtIndex:1] integerValue];
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
// Probably we should not write them, because really the com.apple.metadata domain is private to Apple, http://ironicsoftware.com/community/comments.php?DiscussionID=632&amp;page=1

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

- (id)initWithType:(OSType)type resID:(NSInteger)resID;
{
    self = [super init];
    
    _type = type;
    _resID = resID;
    
    return self;
}

+ (id)entryWithType:(OSType)type resID:(NSInteger)resID;
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
    
    for (WLDragMapEntry *entry in entries)
        [result appendData:[entry entryData]];
    
    return result;
}

@end

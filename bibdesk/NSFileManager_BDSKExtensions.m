//
//  NSFileManager_BDSKExtensions.m
//  Bibdesk
//
//  Created by Adam Maxwell on 07/08/05.
//
/*
 This software is Copyright (c) 2005-2016
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
#import "NSArray_BDSKExtensions.h"
#import <SkimNotesBase/SkimNotesBase.h>
#import <CoreServices/CoreServices.h>

#define OPEN_META_TAGS_KEY @"com.apple.metadata:kMDItemOMUserTags"
#define OPEN_META_TAG_TIME_KEY @"com.apple.metadata:kMDItemOMUserTagTime"
#define OPEN_META_RATING_KEY @"com.apple.metadata:kMDItemStarRating"

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

- (NSString *)applicationSupportDirectory{
    
    static NSString *path = nil;
    
    if(path == nil){
        path = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) firstObject];
        
        NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleNameKey];
        if(appName == nil)
            [NSException raise:NSObjectNotAvailableException format:NSLocalizedString(@"Unable to find CFBundleIdentifier for %@", @"Exception message"), [NSApp description]];
        
        path = [[path stringByAppendingPathComponent:appName] copy];
        
        // the call to NSSearchPathForDirectoriesInDomains does not create the directory we're looking for
        static BOOL dirExists = NO;
        if(dirExists == NO){
            BOOL pathIsDir;
            dirExists = [self fileExistsAtPath:path isDirectory:&pathIsDir];
            if(dirExists == NO || pathIsDir == NO)
                [self createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:NULL];
            // make sure it was created
            dirExists = [self fileExistsAtPath:path isDirectory:&pathIsDir];
            NSAssert1(dirExists && pathIsDir, @"Unable to create folder %@", path);
        }
    }
    
    return path;
}

- (NSURL *)applicationsDirectoryURL {
    NSURL *applicationsURL = [self URLForDirectory:NSApplicationDirectory inDomain:NSLocalDomainMask appropriateForURL:nil create:NO error:NULL];
    
    if (applicationsURL == nil) {
        applicationsURL = [NSURL fileURLWithPath:@"/Applications"];
        BOOL isDir;
        if ([self fileExistsAtPath:[applicationsURL path] isDirectory:&isDir] == NO || isDir == NO) {
            NSLog(@"The system was unable to find your Applications folder.");
            return nil;
        }
    }
    
    return applicationsURL;
}

- (NSURL *)downloadFolderURL;
{
    return [self URLForDirectory:NSDownloadsDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:NULL];
}

- (NSURL *)latestLyXPipeURL {
    NSURL *appSupportURL = [self URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:NULL];
    NSDirectoryEnumerator *dirEnum = [self enumeratorAtURL:appSupportURL includingPropertiesForKeys:[NSArray arrayWithObjects:NSURLNameKey, NSURLIsDirectoryKey, nil] options:NSDirectoryEnumerationSkipsSubdirectoryDescendants errorHandler:nil];
    NSURL *fileURL;
    NSURL *lyxPipeURL = nil;
    BDSKVersionNumber *version = nil;
    
    for (fileURL in dirEnum) {
        NSNumber *isDir = nil;
        [fileURL getResourceValue:&isDir forKey:NSURLIsDirectoryKey error:NULL];
        if ([isDir boolValue]) {
            NSString *fileName = nil;
            [fileURL getResourceValue:&fileName forKey:NSURLNameKey error:NULL];
            if ([fileName hasPrefix:@"LyX"]) {
                NSURL *pipeURL = [fileURL URLByAppendingPathComponent:@".lyxpipe.in"];
                if ([self objectExistsAtFileURL:pipeURL]) {
                    BDSKVersionNumber *fileVersion = [[[BDSKVersionNumber alloc] initWithVersionString:([fileName hasPrefix:@"LyX-"] ? [fileName substringFromIndex:4] : @"")] autorelease];
                    if (version == nil || [fileVersion compare:version] == NSOrderedDescending) {
                        lyxPipeURL = pipeURL;
                        version = fileVersion;
                    }
                }
            }
        }
    }
    if (lyxPipeURL == nil) {
        NSString *pipePath = [[NSHomeDirectory() stringByAppendingPathComponent:@".lyx"] stringByAppendingPathComponent:@"lyxpipe.in"];
        if ([self fileExistsAtPath:pipePath])
            lyxPipeURL = [NSURL fileURLWithPath:pipePath];
    }
    return lyxPipeURL;
}

- (void)copyFileFromSharedSupportToApplicationSupport:(NSString *)fileName overwrite:(BOOL)overwrite{
    NSString *sourcePath = [[[NSBundle mainBundle] sharedSupportPath] stringByAppendingPathComponent:fileName];
    BOOL isDir = NO;
    if ([self fileExistsAtPath:sourcePath isDirectory:&isDir]) {
        NSString *targetPath = [[self applicationSupportDirectory] stringByAppendingPathComponent:fileName];
        if (isDir) {
            if ([self fileExistsAtPath:targetPath isDirectory:&isDir] == NO)
                isDir = [self createDirectoryAtPath:targetPath withIntermediateDirectories:NO attributes:nil error:NULL];
            if (isDir) {
                for (NSString *file in [self contentsOfDirectoryAtPath:sourcePath error:NULL]) {
                    if ([file hasPrefix:@"."] == NO)
                        [self copyFileFromSharedSupportToApplicationSupport:[fileName stringByAppendingPathComponent:file] overwrite:overwrite];
                }
            }
        } else {
            if ([self fileExistsAtPath:targetPath]) {
                if (overwrite == NO)
                    return;
                [self removeItemAtPath:targetPath error:NULL];
            }
            [self copyItemAtPath:sourcePath toPath:targetPath error:NULL];
        }
    }
}

- (void)copyFileFromSharedSupportToApplicationSupportsInDirectory:(NSString *)folderName overwrite:(BOOL)overwrite{
    NSString *applicationSupport = [self applicationSupportDirectory];
    NSString *targetPath = [applicationSupport stringByAppendingPathComponent:folderName];
    BOOL success = YES;
    
    if ([self fileExistsAtPath:targetPath isDirectory:&success] == NO)
        success = [self createDirectoryAtPath:targetPath withIntermediateDirectories:NO attributes:nil error:NULL];
    if (success) {
        NSString *sourcePath = [[[NSBundle mainBundle] sharedSupportPath] stringByAppendingPathComponent:folderName];
        for (NSString *file in [self contentsOfDirectoryAtPath:sourcePath error:NULL]) {
            if ([file hasPrefix:@"."] == NO)
                [self copyFileFromSharedSupportToApplicationSupport:[folderName stringByAppendingPathComponent:file] overwrite:overwrite];
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
    
    NSString *tempItemsPath = nil;
    FSRef tempItemsRef;
    CFURLRef tempItemsURL = NULL;
    if (noErr == FSFindFolder(catalogInfo.volume, kTemporaryFolderType, kCreateFolder, &tempItemsRef)) {
        NSLog(@"Error %d:  the system was unable to find your temporary items folder on volume %i.", err, catalogInfo.volume);
    } else if ((tempItemsURL = CFURLCreateFromFSRef(kCFAllocatorDefault, &tempItemsRef))) {
        tempItemsPath = [(NSURL *)tempItemsURL path];
        CFRelease(tempItemsURL);
    }
    if (tempItemsPath == nil) {
        NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil]; // underlying error
        if (outError)
            *outError = [NSError localErrorWithCode:kBDSKCannotFindTemporaryDirectoryError localizedDescription:[NSString stringWithFormat:@"Unable to find temporary items directory for '%@'", path] underlyingError:error];
    }
    
    if (tempItemsPath) {
        // Don't pass in paths that are already inside Temporary Items or you might get back the same path you passed in.
        if ((tempFileName = [self uniqueFilePathWithName:[path lastPathComponent] atPath:tempItemsPath])) {
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
        if ((tempFileName = [self uniqueFilePathWithName:[path lastPathComponent] atPath:[path stringByDeletingLastPathComponent]])) {
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
    if (fileName == nil)
        fileName = [(NSString *)BDCreateUniqueString() autorelease];
	return [self uniqueFilePathWithName:fileName atPath:temporaryBaseDirectory];
}

- (NSString *)desktopFileWithBasename:(NSString *)fileName {
    NSString *desktopDirectory = [NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES) firstObject];
	return [self uniqueFilePathWithName:fileName atPath:desktopDirectory];
}

- (NSString *)makeTemporaryDirectoryWithBasename:(NSString *)baseName {
    NSString *finalPath = nil;
    
    if (baseName == nil)
        baseName = [(NSString *)BDCreateUniqueString() autorelease];
    
    NSUInteger i = 0;
    NSURL *fileURL = [NSURL fileURLWithPath:[temporaryBaseDirectory stringByAppendingPathComponent:baseName]];
    while ([self objectExistsAtFileURL:fileURL]) {
        fileURL = [NSURL fileURLWithPath:[temporaryBaseDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%lu", baseName, (unsigned long)++i]]];
    }
    finalPath = [fileURL path];
    
    if (NO == [self createDirectoryAtPath:finalPath withIntermediateDirectories:NO attributes:nil error:NULL])
        finalPath = nil;
    
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

- (BOOL)objectExistsAtFileURL:(NSURL *)fileURL{
    return [self fileExistsAtPath:[fileURL path]];
}

#pragma mark Spotlight support
    
- (NSURL *)spotlightCacheFolderURLByCreating:(NSError **)anError{
    
    NSURL *cacheURL = [self URLForDirectory:NSCachesDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:NULL];
    cacheURL = [[cacheURL URLByAppendingPathComponent:@"Metadata"] URLByAppendingPathComponent:[[NSBundle mainBundle] bundleIdentifier]];
    
    BOOL dirExists = YES;
    
    if (NO == [self objectExistsAtFileURL:cacheURL])
        dirExists = [self createDirectoryAtPath:[cacheURL path] withIntermediateDirectories:YES attributes:nil error:NULL];

    if(dirExists == NO && anError != nil){
        *anError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteUnknownError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[cacheURL path], NSFilePathErrorKey, NSLocalizedString(@"Unable to create the cache directory.", @"Error description"), NSLocalizedDescriptionKey, nil]];
    }
        
    return cacheURL;
}

- (NSURL *)spotlightCacheFileURLWithCiteKey:(NSString *)citeKey;
{
    // We use citeKey as the file's name, since it needs to be unique and static (relatively speaking), so we can overwrite the old cache content with newer content when saving the document.  We replace pathSeparator in paths, as we can't create subdirectories with -[NSDictionary writeToFile:] (currently this is the POSIX path separator).
    NSString *filename = citeKey;
    NSString *pathSeparator = [NSString pathSeparator];
    if([filename rangeOfString:pathSeparator].length){
        NSMutableString *mutableFilename = [[filename mutableCopy] autorelease];
        // replace with % as it can't occur in a cite key, so will still be unique
        [mutableFilename replaceOccurrencesOfString:pathSeparator withString:@"%" options:0 range:NSMakeRange(0, [filename length])];
        filename = mutableFilename;
    }
    
    // return nil in case of an empty/nil path
    return [NSString isEmptyString:filename] ? nil : [[self spotlightCacheFolderURLByCreating:NULL] URLByAppendingPathComponent:[filename stringByAppendingPathExtension:@"bdskcache"]];
}

- (BOOL)removeSpotlightCacheFileForCiteKey:(NSString *)citeKey;
{
    NSURL *theURL = [self spotlightCacheFileURLWithCiteKey:citeKey];
    return theURL ? [self removeItemAtURL:theURL error:NULL] : NO;
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
        *error = [NSError localErrorWithCode:kBDSKStringEncodingError localizedDescription:NSLocalizedString(@"Unable to interpret com.apple.TextEncoding", @"")];
    }
    
    return nsEncoding;
}

@end

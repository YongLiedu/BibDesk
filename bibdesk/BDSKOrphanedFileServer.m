//
//  BDSKOrphanedFileServer.m
//  Bibdesk
//
//  Created by Adam Maxwell on 08/13/06.
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

#import "BDSKOrphanedFileServer.h"
#import "UKDirectoryEnumerator.h"
#import "NSURL_BDSKExtensions.h"

@protocol BDSKOrphanedFileServerThread <BDSKAsyncDOServerThread>

- (oneway void)checkForOrphans;
- (oneway void)restartWithKnownFiles:(bycopy NSSet *)theFiles baseURL:(bycopy NSURL *)theURL;
- (bycopy NSSet *)orphanedFiles;

@end

@implementation BDSKOrphanedFileServer

- (id)initWithKnownFiles:(NSSet *)theFiles baseURL:(NSURL *)theURL;
{
    self = [super init];
    if(self){
        NSParameterAssert([theURL isFileURL]);
        orphanedFiles = [[NSMutableSet alloc] initWithCapacity:1024];
        [self setKnownFiles:theFiles];
        [self setBaseURL:theURL];
        keepEnumerating = 0;
        allFilesEnumerated = 0;
    }
    return self;
}

- (void)dealloc
{
    [orphanedFiles release];
    [knownFiles release];
    [baseURL release];
    [super dealloc];
}

// must not be oneway; we need to wait for this method to return and set a flag when enumeration is complete (or been stopped)
- (void)checkAllFilesInDirectoryRootedAtURL:(NSURL *)theURL
{
    UKDirectoryEnumerator *enumerator = [UKDirectoryEnumerator enumeratorWithURL:theURL];

    // default is 16, which is a bit small (don't set it too large, though, since we use -cacheExhausted to signal that it's time to run the runloop again)
    [enumerator setCacheSize:32];
    
    // get visibility and directory flags
    [enumerator setDesiredInfo:(kFSCatInfoFinderInfo | kFSCatInfoNodeFlags)];
    
    BOOL isDir, isHidden;
    CFURLRef fullPathURL;
    
    CFAllocatorRef alloc = CFAllocatorGetDefault();
    
    while ( (1 == keepEnumerating) && (fullPathURL = (CFURLRef)[enumerator nextObjectURL]) ){
        
        CFStringRef lastPathComponent = NULL;        
        lastPathComponent = CFURLCopyLastPathComponent(fullPathURL);
        
        // periodically run the runloop to service the DO requests, or else the main thread just spins
        if([enumerator cacheExhausted])
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
        
        isDir = [enumerator isDirectory];
        isHidden = NULL == lastPathComponent || [enumerator isInvisible] || CFStringHasPrefix(lastPathComponent, CFSTR("."));
        
        if (isDir && isHidden == NO){
            
            // recurse, then dispose of the lastPathComponent
            [self checkAllFilesInDirectoryRootedAtURL:(NSURL *)fullPathURL];
            
            // isHidden == NO guarantees the existence of this object
            CFRelease(lastPathComponent);
            
        } else if (isHidden == NO){
            
            // resolve aliases in the parent directory, since that's what BibItem does
            CFURLRef parentURL = CFURLCreateCopyDeletingLastPathComponent(alloc, fullPathURL);
            CFURLRef resolvedParent = NULL;
            if(parentURL){
                resolvedParent = BDCopyFileURLResolvingAliases(parentURL);
                CFRelease(parentURL);
                parentURL = NULL;
            }
            
            // we'll check for this later
            fullPathURL = NULL;
            
            // add the last path component back in
            if(resolvedParent){
                fullPathURL = CFURLCreateCopyAppendingPathComponent(alloc, resolvedParent, lastPathComponent, FALSE);
                CFRelease(resolvedParent);
                resolvedParent = NULL;
            }
            
            // lastPathComponent exists if isHidden == NO
            CFRelease(lastPathComponent);
            lastPathComponent = NULL;
            
            if(fullPathURL && [knownFiles containsObject:(NSURL *)fullPathURL] == NO){
                [orphanedFiles addObject:(NSURL *)fullPathURL];
                CFRelease(fullPathURL);
                fullPathURL = NULL;
            }
            
        } else {
            // couldn't get last path component, or started with a "."
            if(lastPathComponent) CFRelease(lastPathComponent);
        }
        
    }
    
}

- (BOOL)allFilesEnumerated { return (BOOL)(1 == allFilesEnumerated); }

- (void)stopEnumerating
{
    OSAtomicCompareAndSwap32Barrier(1, 0, &keepEnumerating);
}

- (oneway void)checkForOrphans;
{
    OSAtomicCompareAndSwap32Barrier(0, 1, &keepEnumerating);
    OSAtomicCompareAndSwap32Barrier(1, 0, &allFilesEnumerated);
    
    // increase file limit for enumerating a home directory http://developer.apple.com/qa/qa2001/qa1292.html
    struct rlimit limit;
    int err;
    
    err = getrlimit(RLIMIT_NOFILE, &limit);
    if (err == 0) {
        limit.rlim_cur = RLIM_INFINITY;
        (void) setrlimit(RLIMIT_NOFILE, &limit);
    }
        
    // run directory enumerator; if knownFiles doesn't contain object, add to orphanedFiles

    // not oneway, since we need to set the allFilesEnumerated flag here
    [self checkAllFilesInDirectoryRootedAtURL:baseURL];
    OSAtomicCompareAndSwap32Barrier(0, 1, &allFilesEnumerated);
}

- (void)setBaseURL:(NSURL *)theURL;
{
    NSParameterAssert([theURL isFileURL]);
    [baseURL autorelease];
    baseURL = [theURL copy];
}

- (void)setKnownFiles:(NSSet *)theFiles;
{
    [knownFiles autorelease];
    knownFiles = [theFiles copy];
}

- (void)clearFoundFiles;
{
    [orphanedFiles removeAllObjects];
}

- (oneway void)restartWithKnownFiles:(bycopy NSSet *)theFiles baseURL:(bycopy NSURL *)theURL;
{
    // set the stop flag so enumeration ceases
    OSAtomicCompareAndSwap32Barrier(1, 0, &keepEnumerating);
    
    // reset our local variables
    [self setKnownFiles:theFiles];
    [self clearFoundFiles];
    [self setBaseURL:theURL];
}

- (bycopy NSSet *)orphanedFiles;
{
    // only call using serverOnServerThread
    return [[orphanedFiles copy] autorelease];
}

- (Protocol *)protocolForServerThread { return @protocol(BDSKOrphanedFileServerThread); }

@end

#pragma mark -
#pragma mark fixes for encoding NSURL

@interface NSURL (BDSK_PortCoderFix) @end

@implementation NSURL (BDSK_PortCoderFix)

- (id)replacementObjectForPortCoder:(NSPortCoder *)encoder
{
    return [encoder isByref] ? (id)[NSDistantObject proxyWithLocal:self connection:[encoder connection]] : self;
}

- (NSComparisonResult)localizedCaseInsensitiveCompare:(NSURL *)other;
{
    return [[self path] localizedCaseInsensitiveCompare:[other path]];
}

@end


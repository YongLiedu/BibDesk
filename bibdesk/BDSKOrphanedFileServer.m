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

@end

@protocol BDSKOrphanedFileServerMainThread <BDSKAsyncDOServerMainThread>

- (oneway void)serverFoundFiles:(bycopy NSArray *)newFiles;
- (oneway void)serverDidFinish;

@end

@implementation BDSKOrphanedFileServer

- (id)initWithKnownFiles:(NSSet *)theFiles baseURL:(NSURL *)theURL;
{
    self = [super init];
    if(self){
        NSParameterAssert([theURL isFileURL]);
        orphanedFiles = [[NSMutableArray alloc] initWithCapacity:16];
        [self setKnownFiles:theFiles];
        [self setBaseURL:theURL];
        keepEnumerating = 0;
        allFilesEnumerated = 0;
        delegate = nil;
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

- (id)delegate {
    return delegate;
}

- (void)setDelegate:(id)newDelegate {
    delegate = newDelegate;
    
}

// must not be oneway; we need to wait for this method to return and set a flag when enumeration is complete (or been stopped)
- (void)checkAllFilesInDirectoryRootedAtURL:(NSURL *)theURL
{
    UKDirectoryEnumerator *enumerator = [UKDirectoryEnumerator enumeratorWithURL:theURL];

    // default is 16, which is a bit small (don't set it too large, though, since we use -cacheExhausted to signal that it's time to flush the found files)
    [enumerator setCacheSize:32];
    
    // get visibility and directory flags
    [enumerator setDesiredInfo:(kFSCatInfoFinderInfo | kFSCatInfoNodeFlags)];
    
    BOOL isDir, isHidden;
    CFURLRef fullPathURL;
    
    CFAllocatorRef alloc = CFAllocatorGetDefault();
    
    while ( (1 == keepEnumerating) && (fullPathURL = (CFURLRef)[enumerator nextObjectURL]) ){
        
        // periodically flush the cache        
        if([enumerator cacheExhausted] && [orphanedFiles count] >= 16){
            [self flushFoundFiles];
        }
        
        CFStringRef lastPathComponent = NULL;        
        lastPathComponent = CFURLCopyLastPathComponent(fullPathURL);
        
        isDir = [enumerator isDirectory];
        isHidden = NULL == lastPathComponent || [enumerator isInvisible] || CFStringHasPrefix(lastPathComponent, CFSTR("."));
        
        if(lastPathComponent) CFRelease(lastPathComponent);
        
        // ignore hidden files
        if (isHidden)
            continue;
            
        if (isDir){
            
            // resolve aliases in parent directories, since that's what BibItem does
            CFURLRef resolvedURL = BDCopyFileURLResolvingAliases(fullPathURL);
            if(resolvedURL){
                // recurse
                [self checkAllFilesInDirectoryRootedAtURL:(NSURL *)resolvedURL];
                CFRelease(resolvedURL);
            }
            
        } else if([knownFiles containsObject:[(NSURL *)fullPathURL precomposedPath]] == NO){
            
            [orphanedFiles addObject:(NSURL *)fullPathURL];
            
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
    // see if we have some left in the cache
    [self flushFoundFiles];
    if (keepEnumerating == 1)
        OSAtomicCompareAndSwap32Barrier(0, 1, &allFilesEnumerated);
    
    // notify the delegate
    [[self serverOnMainThread] serverDidFinish];
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

- (void)flushFoundFiles;
{
    if([orphanedFiles count]){
        [[self serverOnMainThread] serverFoundFiles:[[orphanedFiles copy] autorelease]];
        [self clearFoundFiles];
    }
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

- (oneway void)serverFoundFiles:(bycopy NSArray *)newFiles;
{
    if ([delegate respondsToSelector:@selector(orphanedFileServer:foundFiles:)])
        [delegate orphanedFileServer:self foundFiles:newFiles];
}

- (oneway void)serverDidFinish;
{
    if ([delegate respondsToSelector:@selector(orphanedFileServerDidFinish:)])
        [delegate orphanedFileServerDidFinish:self];
}

- (Protocol *)protocolForServerThread { return @protocol(BDSKOrphanedFileServerThread); }

- (Protocol *)protocolForMainThread { return @protocol(BDSKOrphanedFileServerMainThread); }

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


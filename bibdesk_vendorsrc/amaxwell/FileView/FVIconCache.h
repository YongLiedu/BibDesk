//
//  FVIconCache.h
//  FileView
//
//  Created by Adam Maxwell on 10/21/07.
/*
 This software is Copyright (c) 2007-2009
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

#import <Cocoa/Cocoa.h>

struct FVDataStorage;

@interface FVIconCache : NSObject
{
@private;
    struct FVDataStorage *_dataStorage;
    NSLock               *_dataFileLock;
    NSMutableDictionary  *_eventTable;
    NSString             *_cacheName;
}

+ (CGImageRef)newThumbnailNamed:(const char *)name;
+ (void)cacheThumbnail:(CGImageRef)image withName:(const char *)name;

+ (CGImageRef)newImageNamed:(const char *)name;
+ (void)cacheImage:(CGImageRef)image withName:(const char *)name;


// C-strings are used as names for compatibility with DTDataFile's use of std::string, and because it won't change.   Default is to use inode, and use the URL string as name for debug logging.  I was originally using -[[[NSURL path] lastPathComponent] fileSystemRepresentation] as the name when calling these methods, but it was creating a bunch of autoreleased objects and doing encoding conversions.

+ (char *)createDiskCacheNameWithURL:(NSURL *)aURL;

// This always returns a new instance with a retain count of one, based on the data stored on disk.  It will return NULL if an error occurred in deserializing the image data or if the image could not be found in the cache.
- (CGImageRef)newImageNamed:(const char *)name decompress:(BOOL)decompress;

// Note: it's likely best to use +cacheImage:withName: only with images created from our bitmap context factory, for colorspace compatibility.  I haven't tested that hypothesis.
- (void)cacheImage:(CGImageRef)image withName:(const char *)name compress:(BOOL)compress;

- (void)setName:(NSString *)name;

@end

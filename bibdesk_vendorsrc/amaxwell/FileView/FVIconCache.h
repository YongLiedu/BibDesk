//
//  FVIconCache.h
//  FileView
//
//  Created by Adam Maxwell on 10/21/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface FVIconCache : NSObject

// C-strings are used as names for compatibility with DTDataFile's use of std::string, and because it won't change.   Default is to use inode as name for release builds, and use the path as name for debug builds.  I was originally using -[[[NSURL path] lastPathComponent] fileSystemRepresentation] as the name when calling these methods, but it was creating a bunch of autoreleased objects and doing encoding conversions.

// This always returns a new instance with a retain count of one, based on the data stored on disk.  It will return NULL if an error occurred in deserializing the image data or if the image could not be found in the cache.
+ (CGImageRef)newImageNamed:(const char *)name;

// Note: it's likely best to use +cacheCGImage:withName: only with images created from our bitmap context factory, for colorspace compatibility.  I haven't tested that hypothesis.
+ (void)cacheCGImage:(CGImageRef)image withName:(const char *)name;

@end

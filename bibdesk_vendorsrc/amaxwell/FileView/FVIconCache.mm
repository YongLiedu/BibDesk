//
//  FVIconCache.m
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

#import "FVIconCache.h"
#import "DTDataFile.h"
#import "DTCharArray.h"
#import "FVUtilities.h"
#import "FVCGImageHeader.h"
#import <sys/stat.h>
#import <asl.h>

static CGImageRef FVCreateCGImageWithCharArray(DTCharArray array, BOOL decompress);
static DTCharArray FVCharArrayWithCGImage(CGImageRef image, BOOL compress);

@interface _FVIconCacheEventRecord : NSObject
{
@public
    double      _kbytes;
    NSUInteger  _count;
    CFStringRef _identifier;
}
@end

@implementation _FVIconCacheEventRecord

- (void)dealloc
{
    CFRelease(_identifier);
    [super dealloc];
}
- (NSString *)description { return [NSString stringWithFormat:@"%.2f kilobytes in %d files", _kbytes, _count]; }
- (NSUInteger)hash { return CFHash(_identifier); }
- (BOOL)isEqual:(id)other { return CFStringCompare(_identifier, ((_FVIconCacheEventRecord *)other)->_identifier, 0) == kCFCompareEqualTo; }
@end

struct FVDataStorage {
    FVDataStorage(string fn) { name = fn; dataFile = new DTDataFile(name); }
    ~FVDataStorage() { dataFile->Flush(); delete dataFile; }
    
    DTDataFile *dataFile;
    string name;
};

@implementation FVIconCache

static NSInteger FVCacheLogLevel = 0;
static FVIconCache *_bigImageCache = nil;
static FVIconCache *_smallImageCache = nil;

+ (void)initialize
{
    FVINITIALIZE(FVIconCache);

    // Pass in args on command line: -FVCacheLogLevel 0
    // 0 - disabled
    // 1 - only print final stats
    // 2 - print URL each as it's added
    FVCacheLogLevel = [[NSUserDefaults standardUserDefaults] integerForKey:@"FVCacheLogLevel"];
    _bigImageCache = [FVIconCache new];
    [_bigImageCache setName:@"full size images"];
    _smallImageCache = [FVIconCache new];
    [_smallImageCache setName:@"thumbnail images"];
}

- (id)init
{
    self = [super init];
    if (self) {
                    
        // docs say this returns nil in case of failure...so we'll check for it just in case
        NSString *tempDir = NSTemporaryDirectory();
        if (nil == tempDir)
            tempDir = @"/tmp";
        
        const char *tmpPath;
        tmpPath = [[tempDir stringByAppendingPathComponent:@"FileViewCache.XXXXXX"] fileSystemRepresentation];
        
        // mkstemp needs a writable string
        char *tempName = strdup(tmpPath);
        
        // use mkstemp to avoid race conditions; we can't share the cache for writing between processes anyway
        if ((mkstemp(tempName)) == -1) {
            // if this call fails the OS will probably crap out soon, so there's no point in dying gracefully
            string errMsg = string("mkstemp failed \"") + tempName + "\"";
            perror(errMsg.c_str());
            exit(1);
        }

        // opens the file we just created as read/write; use new and a pointer so we guarantee the life cycle
        _dataStorage = new FVDataStorage(tempName);
        free(tempName);
        tempName = NULL;

        // unlink the file immediately; since DTDataFile calls fopen() in its constructor, this is safe, and means we don't leave turds when the program crashes.  For debug builds, the file is unlinked when the app terminates, since otherwise the call to stat() fails with a file not found error (presumably since the link count is zero).
        
        if (FVCacheLogLevel > 0) {
            _dataFileLock = [NSLock new];
            _eventTable = [NSMutableDictionary new];
            [[NSNotificationCenter defaultCenter] addObserver:self 
                                                     selector:@selector(handleAppTerminate:) 
                                                         name:NSApplicationWillTerminateNotification 
                                                       object:nil];        
        }
        else {
            unlink(_dataStorage->name.c_str());
        }
    }
    return self;
}

- (void)dealloc
{
    NSLog(@"*** error *** attempt to deallocate FVIconCache");
    if (0) [super dealloc];
}

- (void)setName:(NSString *)name
{
    [_cacheName autorelease];
    _cacheName = [name copy];
}

- (void)handleAppTerminate:(NSNotification *)notification
{    
    // The only reason for this lock is to avoid a NULL pointer dereference in case a file is being cached while the app terminates.  DTDataFile itself is safe for reading/writing from multiple threads, but we get handleAppTerminate: on the main thread and are generally reading/writing from another thread.
    [_dataFileLock lock];
            
    if (FVCacheLogLevel > 0) {

        string name = _dataStorage->name;
        
        // deleting the _dataFile will cause DTDataFile to close the FILE* pointer
        _dataStorage->dataFile->Flush();
        delete _dataStorage;    
        _dataStorage = NULL;
        
        const char *path = name.c_str();
        
        // print the file size, just because I'm curious about it (before unlinking the file, though!)
        struct stat sb;
        if (0 == stat(path, &sb)) {
            off_t fsize = sb.st_size;
            double mbSize = double(fsize) / 1024 / 1024;
            
            aslclient client = asl_open("FileViewCache", NULL, ASL_OPT_NO_DELAY);
            aslmsg m = asl_new(ASL_TYPE_MSG);
            asl_set(m, ASL_KEY_SENDER, "FileViewCache");
            const char *cacheName = [_cacheName UTF8String];
            asl_log(client, m, ASL_LEVEL_ERR, "%s: removing %s with cache size = %.2f MB\n", cacheName, path, mbSize);
            asl_log(client, m, ASL_LEVEL_ERR, "%s: final cache content (compressed): %s\n", cacheName, [[_eventTable description] UTF8String]);
            asl_free(m);
            asl_close(client);        
        }
        else {
            string errMsg = string("stat failed \"") + path + "\"";
            perror(errMsg.c_str());
        }
        unlink(path);
    }
    
    // hold the lock for the event table as well
    [_dataFileLock unlock];
}

- (CGImageRef)newImageNamed:(const char *)name decompress:(BOOL)decompress;
{
    CGImageRef toReturn = NULL;
    [_dataFileLock lock];
    
    if (_dataStorage->dataFile) {
        // David suggested a periodic flush, though it doesn't seem to be needed
        _dataStorage->dataFile->Flush();
        
        if (_dataStorage->dataFile->Contains(name)) {
            DTCharArray array = _dataStorage->dataFile->ReadCharArray(name);
            toReturn = FVCreateCGImageWithCharArray(array, decompress);
            if (FVCacheLogLevel > 0 && NULL == toReturn)
                NSLog(@"failed reading %s from cache", name);
        }
    }
    else if (FVCacheLogLevel > 0) {
        NSLog(@"must be quitting; the cache file is already gone");
    }
    [_dataFileLock unlock];
    return toReturn;
}

- (void)_recordCacheEventWithName:(const char *)name size:(double)kbytes
{
    const UInt8 *url_bytes = (const UInt8 *)name;
    CFURLRef theURL = CFURLCreateWithBytes(NULL, url_bytes, strlen(name), kCFStringEncodingUTF8, NULL);
    CFStringRef scheme = CFURLCopyScheme(theURL);
    CFStringRef identifier = NULL;
    if (scheme && CFStringCompare(scheme, CFSTR("file"), 0) == kCFCompareEqualTo) {
        
        FSRef fileRef;
        if (CFURLGetFSRef(theURL, &fileRef)) {
            CFStringRef theUTI;
            LSCopyItemAttribute(&fileRef, kLSRolesAll, kLSItemContentType, (CFTypeRef *)&theUTI);
            if (theUTI) identifier = theUTI;
        }
    }
    else if (scheme) {
        identifier = (CFStringRef)CFRetain(scheme);
    }
    else {
        identifier = (CFStringRef)CFRetain(CFSTR("anonymous"));
    }
    
    _FVIconCacheEventRecord *rec = [_eventTable objectForKey:(id)identifier];
    if (nil != rec) {
        rec->_kbytes += kbytes;
        rec->_count += 1;
    }
    else {
        rec = [_FVIconCacheEventRecord new];
        rec->_kbytes = kbytes;
        rec->_count = 1;
        rec->_identifier = (CFStringRef)CFRetain(identifier);
        [_eventTable setObject:rec forKey:(id)identifier];
        [rec release];
    }
    
    if (identifier) CFRelease(identifier);
    if (scheme) CFRelease(scheme);
    if (theURL) CFRelease(theURL);
    
    if (FVCacheLogLevel > 1) {
        aslclient client = asl_open("FileViewCache", NULL, ASL_OPT_NO_DELAY);
        aslmsg m = asl_new(ASL_TYPE_MSG);
        asl_set(m, ASL_KEY_SENDER, "FileViewCache");
        asl_log(client, m, ASL_LEVEL_ERR, "caching image for %s, size = %.2f kBytes\n", name, kbytes);
        asl_free(m);
        asl_close(client);
    }
}

- (void)cacheImage:(CGImageRef)image withName:(const char *)name compress:(BOOL)compress;
{
    DTCharArray array = FVCharArrayWithCGImage(image, compress);
    [_dataFileLock lock];
    if (FVCacheLogLevel > 0)
        [self _recordCacheEventWithName:name size:double(array.Length()) / 1024];
    if (_dataStorage->dataFile) _dataStorage->dataFile->Save(array, name);
    [_dataFileLock unlock];
}

static inline char * FVCreateCStringWithInode(ino_t n)
{
    char *temp;
    asprintf(&temp,"%ld", (long)n);
    return temp;   
}

// tried avoiding the compression step for thumbnails, but file sizes quickly grow >100 MB and performance is worse
+ (CGImageRef)newThumbnailNamed:(const char *)name;
{
    return [_smallImageCache newImageNamed:name decompress:YES];
}

+ (void)cacheThumbnail:(CGImageRef)image withName:(const char *)name;
{
    [_smallImageCache cacheImage:image withName:name compress:YES];
}

+ (CGImageRef)newImageNamed:(const char *)name;
{
    return [_bigImageCache newImageNamed:name decompress:YES];
}

+ (void)cacheImage:(CGImageRef)image withName:(const char *)name;
{
    [_bigImageCache cacheImage:image withName:name compress:YES];
}

// changed from function to class method so +initialize gets called first and sets FVCacheLogLevel
+ (char *)createDiskCacheNameWithURL:(NSURL *)aURL
{
    NSParameterAssert(nil != aURL);
    
    char *name = NULL;
    if (NO == [aURL isFileURL] || FVCacheLogLevel > 0) {
        // this is a much more useful name for debugging, but it's slower and breaks if the name changes
        name = strdup([[aURL absoluteString] fileSystemRepresentation]);
    }
    else {
        struct stat sb;
        if (0 == stat([[aURL path] fileSystemRepresentation], &sb))
            name = FVCreateCStringWithInode(sb.st_ino);
    }
    return name;
}

@end

#pragma mark -

#ifdef USE_IMAGEIO
#undef USE_IMAGEIO
#endif

#define USE_IMAGEIO 0

// PNG and JPEG2000 are too slow when drawing, and TIFF is too big (although we could compress it)
#define IMAGEIO_TYPE kUTTypeTIFF
    
static CGImageRef FVCreateCGImageWithCharArray(DTCharArray array, BOOL decompress)
{
    CGImageRef toReturn = NULL;

#if USE_IMAGEIO
    // ImageIO doesn't copy its data, which is kind of scary...
    NSData *data = [[NSData alloc] initWithBytes:(void *)array.Pointer() length:array.Length()];
#else
    // this is a cheap way to create an NSData, and is safe since we decompress it and create a new instance
    NSData *data = [[NSData alloc] initWithBytesNoCopy:(void *)array.Pointer() length:array.Length() freeWhenDone:NO];
#endif
    
    if (0 == [data length]) {
        [data release];
        return toReturn;
    }
    
#if USE_IMAGEIO
    // C++ has thread-safe initialization of local statics http://googlemac.blogspot.com/2006/11/synchronized-swimming-part-2.html
    static NSDictionary *imageProperties = [[NSDictionary alloc] initWithObjectsAndKeys:[[NSNumber alloc] initWithInt:1.0], (id)kCGImageDestinationLossyCompressionQuality, nil];

    CGImageSourceRef imsrc = CGImageSourceCreateWithData((CFDataRef)data, (CFDictionaryRef)imageProperties);
    if (imsrc && CGImageSourceGetCount(imsrc))
        toReturn = CGImageSourceCreateImageAtIndex(imsrc, 0, NULL);
    if (imsrc) CFRelease(imsrc);
    [data release];
#else
    
    NSData *decompressedData = decompress ? [data _fv_zlibDecompress] : [[data retain] autorelease];
    [data release];
    
    FVCGImageHeaderInfo headerInfo;
    size_t hdrSize = sizeof(headerInfo);
    
    // this should never happen, but let's avoid a possible range exception anyway
    if (hdrSize > [decompressedData length]) {
        NSLog(@"*** ERROR *** Incomplete deserialization of image");
        return NULL;
    }
    
    [decompressedData getBytes:&headerInfo length:hdrSize];
    
    FVCGImageHeader header = FVCGImageHeader(headerInfo);
    
    // this is messy, but faster than using subdataWithRange: and avoids autorelease
    const UInt8 *basePtr = (const UInt8 *)[decompressedData bytes];
    const UInt8 *bitmapPtr = &basePtr[hdrSize];
    
    CFDataRef bitmapData = NULL;
    if (bitmapPtr)
        bitmapData = CFDataCreate(CFAllocatorGetDefault(), bitmapPtr, [decompressedData length] - hdrSize);    
    
    if (bitmapData) {
        toReturn = header.CreateCGImageWithData(bitmapData);
        CFRelease(bitmapData);
    }
#endif
    return toReturn;
}

// private on all versions of OS X
FV_EXTERN void * CGDataProviderGetBytePtr(CGDataProviderRef provider);
FV_EXTERN size_t CGDataProviderGetSize(CGDataProviderRef provider);

static DTCharArray FVCharArrayWithCGImage(CGImageRef image, BOOL compress)
{
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
#if USE_IMAGEIO
    CFMutableDataRef data = CFDataCreateMutable(CFAllocatorGetDefault(), 0);
    CGImageDestinationRef dest = CGImageDestinationCreateWithData(data, IMAGEIO_TYPE, 1, NULL);
    CGImageDestinationAddImage(dest, image, NULL);
    CGImageDestinationFinalize(dest);
    if (dest) CFRelease(dest);
#else
    CFDataRef data = nil;
    FVCGImageHeader header = FVCGImageHeader(image);
    const FVCGImageHeaderInfo *headerInfo = header.HeaderInfo();
    
    // CFMutableData craps out if you specify a length and then try to increase it afterwards
    CFMutableDataRef mdata = CFDataCreateMutable(CFAllocatorGetDefault(), 0);

    CFDataAppendBytes(mdata, (const UInt8 *)headerInfo, sizeof(FVCGImageHeaderInfo));
    CGDataProviderRef provider = CGImageGetDataProvider(image);
    void *bytePtr = NULL;
    
    if (NULL != CGDataProviderGetBytePtr && NULL != CGDataProviderGetSize && 
        NULL != (bytePtr = CGDataProviderGetBytePtr(provider)) ) {
        CFDataAppendBytes(mdata, (const UInt8 *)bytePtr, CGDataProviderGetSize(provider));
    }
    else {
        data = CGDataProviderCopyData(provider);
        // CGDataProviderCopyData returns NULL if a copy can't fit in memory, but we put it there originally
        if (NULL != data) {
            CFDataAppendBytes(mdata, CFDataGetBytePtr(data), CFDataGetLength(data));
            CFRelease(data);
        }
    }

    if (compress)
        data = (CFDataRef)[(id)mdata _fv_zlibCompress];
    else
        data = (CFDataRef)[[(id)mdata retain] autorelease];
    if (mdata) CFRelease(mdata);
#endif
    CFIndex len = CFDataGetLength(data);
    DTMutableCharArray array = DTMutableCharArray(len);
    memcpy(array.Pointer(), CFDataGetBytePtr(data), len);
    
#if USE_IMAGEIO
    if (data) CFRelease(data);
#endif
    [pool release];
    
    return array;
}


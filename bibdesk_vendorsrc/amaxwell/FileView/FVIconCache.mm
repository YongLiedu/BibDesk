//
//  FVIconCache.m
//  FileView
//
//  Created by Adam Maxwell on 10/21/07.
/*
 This software is Copyright (c) 2007-2008
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
#import <sys/stat.h>
#import <asl.h>

static CGImageRef FVCreateCGImageWithCharArray(DTCharArray array);
static DTCharArray FVCharArrayWithCGImage(CGImageRef image);

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

@implementation FVIconCache

static DTDataFile *__dataFile = NULL;
static char *__tempName = NULL;        /* only a file static for debugging */
static pthread_mutex_t __dataFileLock = PTHREAD_MUTEX_INITIALIZER;
static NSMutableDictionary *__eventTable = nil;
static NSInteger FVCacheLogLevel = 0;

+ (void)initialize
{
    static BOOL didInit = NO;
    if (NO == didInit) {
        
        // Pass in args on command line: -FVCacheLogLevel 0
        // 0 - disabled
        // 1 - only print final stats
        // 2 - print URL each as it's added
        FVCacheLogLevel = [[NSUserDefaults standardUserDefaults] integerForKey:@"FVCacheLogLevel"];
                
        // docs say this returns nil in case of failure...so we'll check for it just in case
        NSString *tempDir = NSTemporaryDirectory();
        if (nil == tempDir)
            tempDir = @"/tmp";
        
        const char *tmpPath;
        tmpPath = [[tempDir stringByAppendingPathComponent:@"FileViewCache.XXXXXX"] fileSystemRepresentation];
        
        // mkstemp needs a writable string
        __tempName = strdup(tmpPath);
        
        // use mkstemp to avoid race conditions; we can't share the cache for writing between processes anyway
        if ((mkstemp(__tempName)) == -1) {
            // if this call fails the OS will probably crap out soon, so there's no point in dying gracefully
            string errMsg = string("mkstemp failed \"") + __tempName + "\"";
            perror(errMsg.c_str());
            exit(1);
        }

        // opens the file we just created as read/write; use new and a pointer so we guarantee the life cycle
        __dataFile = new DTDataFile(__tempName);
        
        // unlink the file immediately; since DTDataFile calls fopen() in its constructor, this is safe, and means we don't leave turds when the program crashes.  For debug builds, the file is unlinked when the app terminates, since otherwise the call to stat() fails with a file not found error (presumably since the link count is zero).
        
        if (FVCacheLogLevel > 0)
            __eventTable = [NSMutableDictionary new];
        else
            unlink(__tempName);

        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(handleAppTerminate:) 
                                                     name:NSApplicationWillTerminateNotification 
                                                   object:nil];
        didInit = YES;
    }
}

+ (void)handleAppTerminate:(NSNotification *)notification
{    
    // The only reason for this lock is to avoid a NULL pointer dereference in case a file is being cached while the app terminates.  DTDataFile itself is safe for reading/writing from multiple threads, but we get handleAppTerminate: on the main thread and are generally reading/writing from another thread.
    pthread_mutex_lock(&__dataFileLock);
    
    // deleting the __dataFile will cause DTDataFile to close the FILE* pointer
    __dataFile->Flush();
    delete __dataFile;    
    __dataFile = NULL;
        
    if (FVCacheLogLevel > 0) {
        // print the file size, just because I'm curious about it (before unlinking the file, though!)
        struct stat sb;
        if (0 == stat(__tempName, &sb)) {
            off_t fsize = sb.st_size;
            double mbSize = double(fsize) / 1024 / 1024;
            
            aslclient client = asl_open("FileViewCache", NULL, ASL_OPT_NO_DELAY);
            aslmsg m = asl_new(ASL_TYPE_MSG);
            asl_set(m, ASL_KEY_SENDER, "FileViewCache");
            asl_log(client, m, ASL_LEVEL_ERR, "removing %s with cache size = %.2f MB\n", __tempName, mbSize);
            asl_log(client, m, ASL_LEVEL_ERR, "final cache content (compressed): %s\n", [[__eventTable description] UTF8String]);
            asl_free(m);
            asl_close(client);        
        }
        else {
            string errMsg = string("stat failed \"") + __tempName + "\"";
            perror(errMsg.c_str());
        }
        unlink(__tempName);
    }
    
    // hold the lock for the event table as well
    pthread_mutex_unlock(&__dataFileLock);
}

+ (CGImageRef)newImageNamed:(const char *)name;
{
    CGImageRef toReturn = NULL;
    
    pthread_mutex_lock(&__dataFileLock);
    
    if (__dataFile) {
        // David suggested a periodic flush, though it doesn't seem to be needed
        __dataFile->Flush();
        
        if (__dataFile->Contains(name)) {
            DTCharArray array = __dataFile->ReadCharArray(name);
            toReturn = FVCreateCGImageWithCharArray(array);
            if (FVCacheLogLevel > 0 && NULL == toReturn)
                NSLog(@"failed reading %s from cache", name);
        }
    }
    else if (FVCacheLogLevel > 0) {
        NSLog(@"must be quitting; the cache file is already gone");
    }
    pthread_mutex_unlock(&__dataFileLock);
    return toReturn;
}

+ (void)_recordCacheEventWithName:(const char *)name size:(double)kbytes
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
    
    _FVIconCacheEventRecord *rec = [__eventTable objectForKey:(id)identifier];
    if (nil != rec) {
        rec->_kbytes += kbytes;
        rec->_count += 1;
    }
    else {
        rec = [_FVIconCacheEventRecord new];
        rec->_kbytes = kbytes;
        rec->_count = 1;
        rec->_identifier = (CFStringRef)CFRetain(identifier);
        [__eventTable setObject:rec forKey:(id)identifier];
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

+ (void)cacheCGImage:(CGImageRef)image withName:(const char *)name;
{
    DTCharArray array = FVCharArrayWithCGImage(image);
    pthread_mutex_lock(&__dataFileLock);
    if (FVCacheLogLevel > 0)
        [self _recordCacheEventWithName:name size:double(array.Length()) / 1024];
    if (__dataFile) __dataFile->Save(array, name);
    pthread_mutex_unlock(&__dataFileLock);
}

static char * FVCreateCStringWithInode(ino_t n)
{
    // LONG_MAX on x86_64 is 9223372036854775807, so 40 chars should be sufficient
    char temp[40];
    sprintf(temp,"%ld", (long)n);
    return strdup(temp);   
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

typedef struct _FVCGImageHeaderInfo {
    size_t                 w;
    size_t                 h;
    size_t                 bpc;
    size_t                 bpp;
    size_t                 bpr;
    bool                   isGray;
    CGBitmapInfo           bitmapInfo;
    CGColorRenderingIntent renderingIntent;
    bool                   shouldInterpolate;
} FVCGImageHeaderInfo;

// This class isn't really necessary, but I found it amusing to write a C++ class for a change.  Serializing the class directly seems to work, but I'd rather serialize a struct instead, since I'm not sure what the compiler adds to C++ objects.
class FVCGImageHeader {
    
public:
    FVCGImageHeader() { info = new FVCGImageHeaderInfo; }
    FVCGImageHeader(CGImageRef image);
    FVCGImageHeader(FVCGImageHeaderInfo hInfo);
    
    FVCGImageHeader(const FVCGImageHeader &);
    ~FVCGImageHeader();
    
    size_t Width() const { return info->w; }
    size_t Height() const { return info->h; }
    size_t BitsPerComponent() const { return info->bpc; }
    size_t BitsPerPixel() const { return info->bpp; }
    size_t BytesPerRow() const { return info->bpr; }
    bool IsGray() const { return info->isGray; }
    CGBitmapInfo BitmapInfo() const { return info->bitmapInfo; }
    CGColorRenderingIntent ColorRenderingIntent() const { return info->renderingIntent; }
    bool ShouldInterpolate() const { return info->shouldInterpolate; }
    
    const FVCGImageHeaderInfo *HeaderInfo() const { return info; }
    
    // for debugging, as in DTSource
    void pinfo(void) const;
    
private:
    FVCGImageHeaderInfo *info;
};

FVCGImageHeader::FVCGImageHeader(const FVCGImageHeader &H)
{
    info = new FVCGImageHeaderInfo;
    memcpy(info, H.info, sizeof(FVCGImageHeaderInfo));
}

FVCGImageHeader::~FVCGImageHeader()
{
    delete info;
    info = NULL;
}

FVCGImageHeader::FVCGImageHeader(FVCGImageHeaderInfo hInfo)
{
    info = new FVCGImageHeaderInfo;
    memcpy(info, &hInfo, sizeof(FVCGImageHeaderInfo));
}

FVCGImageHeader::FVCGImageHeader(CGImageRef image)
{
    info = new FVCGImageHeaderInfo;
    info->w = CGImageGetWidth(image);
    info->h = CGImageGetHeight(image);
    info->bpc = CGImageGetBitsPerComponent(image);
    info->bpp = CGImageGetBitsPerPixel(image);
    info->bpr = CGImageGetBytesPerRow(image);
    
    // I only support device-specific RGB (3) and Gray (1) colorspaces in bitmap context caching, so just check the number of components since there's no way to get the colorspace name.  I think this is because Apple wants developers to use generic colorspaces, but I want to avoid the conversions for performance reasons.
    info->isGray = CGColorSpaceGetNumberOfComponents(CGImageGetColorSpace(image)) == 1;
    info->bitmapInfo = CGImageGetBitmapInfo(image);
    info->renderingIntent = CGImageGetRenderingIntent(image);
    info->shouldInterpolate = CGImageGetShouldInterpolate(image); 
}

void FVCGImageHeader::pinfo(void) const
{
    fprintf(stderr, "FVCGImageHeader <%p>: width=%d, height=%d, bitsPerComponent=%d, bitsPerPixel=%d, bytesPerRow=%d, %s, bitmapInfo=%d, renderingIntent=%d, %s\n", this, info->w, info->h, info->bpc, info->bpp, info->bpr, (info->isGray ? "grayscale" : "rgb"), info->bitmapInfo, info->renderingIntent, (info->shouldInterpolate ? "interpolates" : "does not interpolate"));
    fflush(stderr);
}

#ifdef USE_IMAGEIO
#undef USE_IMAGEIO
#endif

#define USE_IMAGEIO 0
#ifndef MAC_OS_X_VERSION_10_5
#warning Using private CG API
#endif

// PNG and JPEG2000 are too slow when drawing, and TIFF is too big (although we could compress it)
#define IMAGEIO_TYPE kUTTypeTIFF
    
static CGImageRef FVCreateCGImageWithCharArray(DTCharArray array)
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
    
    NSData *decompressedData = [data _fv_zlibDecompress];
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
    
    CGColorSpaceRef cspace = header.IsGray() ? CGColorSpaceCreateDeviceGray() : CGColorSpaceCreateDeviceRGB();
    CGDataProviderRef provider = NULL;
    
    if (bitmapData) {
        provider = CGDataProviderCreateWithCFData(bitmapData);
        CFRelease(bitmapData);
    }
    
    if (provider)
        toReturn = CGImageCreate(header.Width(), header.Height(), 
                                 header.BitsPerComponent(), header.BitsPerPixel(), header.BytesPerRow(), 
                                 cspace, header.BitmapInfo(), provider, NULL, 
                                 header.ShouldInterpolate(), header.ColorRenderingIntent());
    
    CGColorSpaceRelease(cspace);
    CGDataProviderRelease(provider);
#endif
    return toReturn;
}

#if !defined(MAC_OS_X_VERSION_10_5) || (MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_5)
// public on Leopard, private on 10.4
FV_EXTERN CFDataRef CGDataProviderCopyData(CGDataProviderRef provider);
#endif
// private on all versions of OS X
FV_EXTERN void * CGDataProviderGetBytePtr(CGDataProviderRef provider);
FV_EXTERN size_t CGDataProviderGetSize(CGDataProviderRef provider);

static DTCharArray FVCharArrayWithCGImage(CGImageRef image)
{
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
#if USE_IMAGEIO
    NSMutableData *data = [[NSMutableData alloc] init];
    CGImageDestinationRef dest = CGImageDestinationCreateWithData((CFMutableDataRef)data, IMAGEIO_TYPE, 1, NULL);
    CGImageDestinationAddImage(dest, image, NULL);
    CGImageDestinationFinalize(dest);
    if (dest) CFRelease(dest);
#else
    NSData *data = nil;
    FVCGImageHeader header = FVCGImageHeader(image);
    const FVCGImageHeaderInfo *headerInfo = header.HeaderInfo();
    
    NSMutableData *mdata = [[NSMutableData alloc] initWithCapacity:[data length]];
    [mdata appendBytes:headerInfo length:sizeof(FVCGImageHeaderInfo)];
    CGDataProviderRef provider = CGImageGetDataProvider(image);
    void *bytePtr = NULL;
    
    if (NULL != &CGDataProviderGetBytePtr && NULL != &CGDataProviderGetSize && 
        NULL != (bytePtr = CGDataProviderGetBytePtr(provider)) ) {
        [mdata appendBytes:bytePtr length:CGDataProviderGetSize(provider)];
    }
    else {
        data = (NSData *)CGDataProviderCopyData(provider);
        // CGDataProviderCopyData returns NULL if a copy can't fit in memory, but we put it there originally
        if (nil != data)
            [mdata appendData:data];
        [data release];
    }

    data = [mdata _fv_zlibCompress];
    [mdata release];
#endif
    DTMutableCharArray array = DTMutableCharArray([data length]);
    memcpy(array.Pointer(), [data bytes], [data length]);
    
#if USE_IMAGEIO
    [data release];
#endif
    [pool release];
    
    return array;
}

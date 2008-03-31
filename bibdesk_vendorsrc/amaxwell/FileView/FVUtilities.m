//
//  FVUtilities.m
//  FileView
//
//  Created by Adam Maxwell on 2/6/08.
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

#import "FVUtilities.h"
#import "zlib.h"

static Boolean __FVIntegerEquality(const void *v1, const void *v2) { return v1 == v2; }
static CFStringRef __FVIntegerCopyDescription(const void *value) { return (CFStringRef)[[NSString alloc] initWithFormat:@"%ld", (long)value]; }
static CFHashCode __FVIntegerHash(const void *value) { return (CFHashCode)value; }

static CFStringRef __FVObjectCopyDescription(const void *value) { return (CFStringRef)[[(id)value description] copy]; }
static CFHashCode __FVObjectHash(const void *value) { return [(id)value hash]; }
static Boolean __FVObjectEqual(const void *value1, const void *value2) { return (Boolean)[(id)value1 isEqual:(id)value2]; }
static const void * __FVObjectRetain(CFAllocatorRef alloc, const void *value) { return [(id)value retain]; }
static void __FVObjectRelease(CFAllocatorRef alloc, const void *value) { [(id)value release]; }

const CFDictionaryKeyCallBacks FVIntegerKeyDictionaryCallBacks = { 0, NULL, NULL, __FVIntegerCopyDescription, __FVIntegerEquality, __FVIntegerHash };
const CFDictionaryValueCallBacks FVIntegerValueDictionaryCallBacks = { 0, NULL, NULL, __FVIntegerCopyDescription, __FVIntegerEquality };
const CFSetCallBacks FVNSObjectSetCallBacks = { 0, __FVObjectRetain, __FVObjectRelease, __FVObjectCopyDescription, __FVObjectEqual, __FVObjectHash };
const CFSetCallBacks FVNSObjectPointerSetCallBacks = { 0, __FVObjectRetain, __FVObjectRelease, __FVObjectCopyDescription, NULL, NULL };

#pragma mark Timer

// Object that can be retained and released by the timer, but does not retain its ivars
@interface _FVNSObjectTimerInfo : NSObject
{
@public;
    id  target;
    SEL selector;
}
@end

@implementation _FVNSObjectTimerInfo
@end

static const void * __FVTimerInfoRetain(const void *info) { return [(id)info retain]; }
static void __FVTimerInfoRelease(const void *info) { [(id)info release]; }
static CFStringRef __FVTimerInfoCopyDescription(const void *info)
{
    _FVNSObjectTimerInfo *tmi = (void *)info;
    return (CFStringRef)[[NSString alloc] initWithFormat:@"_FVNSObjectTimerInfo = {\n\ttarget = %@,\n\tselector = %@\n}", tmi->target, NSStringFromSelector(tmi->selector)];    
}

static void __FVRunLoopTimerFired(CFRunLoopTimerRef timer, void *info)
{
    _FVNSObjectTimerInfo *tmi = info;
    [tmi->target performSelector:tmi->selector withObject:(id)timer];
}

CFRunLoopTimerRef FVCreateWeakTimerWithTimeInterval(NSTimeInterval interval, NSTimeInterval fireTime, id target, SEL selector)
{
    // This can't be a stack object, so timer creation invokes the context's retain callback.
    _FVNSObjectTimerInfo *tmi = [_FVNSObjectTimerInfo new];
    tmi->target = target;
    tmi->selector = selector;
    
    CFRunLoopTimerContext timerContext = {  0, tmi, __FVTimerInfoRetain, __FVTimerInfoRelease, __FVTimerInfoCopyDescription };
    CFRunLoopTimerRef timer = CFRunLoopTimerCreate(CFAllocatorGetDefault(), fireTime, interval, 0, 0, __FVRunLoopTimerFired, &timerContext);
    
    // now owned by the timer
    [tmi release];
    return timer;
}

#pragma mark Logging

void FVLogv(NSString *format, va_list argList)
{
    NSString *logString = [[NSString alloc] initWithFormat:format arguments:argList];
    
    char *buf = NULL;
    char stackBuf[1024];
    
    // add 1 for the NULL terminator (length arg to getCString:maxLength:encoding: needs to include space for this)
    NSUInteger requiredLength = ([logString maximumLengthOfBytesUsingEncoding:NSUTF8StringEncoding] + 1);
    
    if (requiredLength <= sizeof(stackBuf) && [logString getCString:stackBuf maxLength:sizeof(stackBuf) encoding:NSUTF8StringEncoding]) {
        buf = stackBuf;
    } else if (NULL != (buf = NSZoneMalloc(NULL, requiredLength * sizeof(char))) ){
        [logString getCString:buf maxLength:requiredLength encoding:NSUTF8StringEncoding];
    } else {
        fprintf(stderr, "unable to allocate log buffer\n");
    }
    [logString release];
    
    fprintf(stderr, "%s\n", buf);
    
    if (buf != stackBuf) NSZoneFree(NULL, buf);
}

void FVLog(NSString *format, ...)
{
    va_list list;
    va_start(list, format);
    FVLogv(format, list);
    va_end(list);
}

#pragma mark Pasteboard URL functions

// NSPasteboard only lets us read a single webloc or NSURL instance from the pasteboard, which isn't very considerate of it.  Fortunately, we can create a Carbon pasteboard that isn't as fundamentally crippled (except in its moderately annoying API).  
NSArray *FVURLsFromPasteboard(NSPasteboard *pboard)
{
    OSStatus err;
    
    PasteboardRef carbonPboard;
    err = PasteboardCreate((CFStringRef)[pboard name], &carbonPboard);
    
    PasteboardSyncFlags syncFlags;
#pragma unused(syncFlags)
    if (noErr == err)
        syncFlags = PasteboardSynchronize(carbonPboard);
    
    ItemCount itemCount, itemIndex;
    if (noErr == err)
        err = PasteboardGetItemCount(carbonPboard, &itemCount);
    else
        itemCount = 0;
    
    NSMutableArray *toReturn = [NSMutableArray arrayWithCapacity:itemCount];
    
    // this is to avoid duplication in the last call to NSPasteboard
    NSMutableSet *allURLsReadFromPasteboard = [NSMutableSet setWithCapacity:itemCount];
    
    // Pasteboard has 1-based indexing!
            
    for (itemIndex = 1; itemIndex <= itemCount; itemIndex++) {
        
        PasteboardItemID itemID;
        CFArrayRef flavors = NULL;
        CFIndex flavorIndex, flavorCount = 0;
        
        err = PasteboardGetItemIdentifier(carbonPboard, itemIndex, &itemID);
        if (noErr == err)
            err = PasteboardCopyItemFlavors(carbonPboard, itemID, &flavors);
        
        if (noErr == err)
            flavorCount = CFArrayGetCount(flavors);
                    
        // webloc has file and non-file URL, and we may only have a string type
        CFURLRef destURL = NULL;
        CFURLRef fileURL = NULL;
        CFURLRef textURL = NULL;
        
        // flavorCount will be zero in case of an error...
        for (flavorIndex = 0; flavorIndex < flavorCount; flavorIndex++) {
            
            CFStringRef flavor;
            CFDataRef data;
            
            flavor = CFArrayGetValueAtIndex(flavors, flavorIndex);
            
            // !!! I'm assuming that the URL bytes are UTF-8, but that should be checked...
            
            // UTIs determined with PasteboardPeeker
            
            if (UTTypeConformsTo(flavor, kUTTypeFileURL)) {
                
                err = PasteboardCopyItemFlavorData(carbonPboard, itemID, flavor, &data);
                if (noErr == err && NULL != data) {
                    fileURL = CFURLCreateWithBytes(NULL, CFDataGetBytePtr(data), CFDataGetLength(data), kCFStringEncodingUTF8, NULL);
                    CFRelease(data);
                }
                
            } else if (UTTypeConformsTo(flavor, kUTTypeURL)) {
                
                err = PasteboardCopyItemFlavorData(carbonPboard, itemID, flavor, &data);
                if (noErr == err && NULL != data) {
                    destURL = CFURLCreateWithBytes(NULL, CFDataGetBytePtr(data), CFDataGetLength(data), kCFStringEncodingUTF8, NULL);
                    CFRelease(data);
                }
                
            } else if (UTTypeConformsTo(flavor, kUTTypeUTF8PlainText)) {
                
                // this is a string that may be a URL; FireFox and other apps don't use any of the standard URL pasteboard types
                err = PasteboardCopyItemFlavorData(carbonPboard, itemID, kUTTypeUTF8PlainText, &data);
                if (noErr == err && NULL != data) {
                    textURL = CFURLCreateWithBytes(NULL, CFDataGetBytePtr(data), CFDataGetLength(data), kCFStringEncodingUTF8, NULL);
                    CFRelease(data);
                    
                    // CFURLCreateWithBytes will create a URL from any arbitrary string
                    if (NULL != textURL && nil == [(NSURL *)textURL scheme]) {
                        CFRelease(textURL);
                        textURL = NULL;
                    }
                }
                
            }
            
            // ignore any other type; we don't care
            
        }
        
        // only add the textURL if the destURL or fileURL were not found
        if (NULL != textURL) {
            if (NULL == destURL && NULL == fileURL)
                [toReturn addObject:(id)textURL];
            
            [allURLsReadFromPasteboard addObject:(id)textURL];
            CFRelease(textURL);
        }
        // only add the fileURL if the destURL (target of a remote URL or webloc) was not found
        if (NULL != fileURL) {
            if (NULL == destURL) 
                [toReturn addObject:(id)fileURL];
            
            [allURLsReadFromPasteboard addObject:(id)fileURL];
            CFRelease(fileURL);
        }
        // always add this if it exists
        if (NULL != destURL) {
            [toReturn addObject:(id)destURL];
            [allURLsReadFromPasteboard addObject:(id)destURL];
            CFRelease(destURL);
        }
    
        if (NULL != flavors)
            CFRelease(flavors);
    }
                                
    if (carbonPboard) CFRelease(carbonPboard);

    // NSPasteboard only allows a single NSURL for some idiotic reason, and NSURLPboardType isn't automagically coerced to a Carbon URL pboard type.  This step handles a program like BibDesk which presently adds a webloc promise + NSURLPboardType, where we want the NSURLPboardType data and ignore the HFS promise.  However, Finder puts all of these on the pboard, so don't add duplicate items to the array...since we may have already added the content (remote URL) if this is a webloc file.
    if ([[pboard types] containsObject:NSURLPboardType]) {
        NSURL *nsURL = [NSURL URLFromPasteboard:pboard];
        if (nsURL && [allURLsReadFromPasteboard containsObject:nsURL] == NO)
            [toReturn addObject:nsURL];
    }
    
    // ??? On 10.5, NSStringPboardType and kUTTypeUTF8PlainText point to the same data, according to pasteboard peeker; if that's the case on 10.4, we can remove this and the registration for NSStringPboardType.
    if ([[pboard types] containsObject:NSStringPboardType]) {
        NSURL *nsURL = [NSURL URLWithString:[pboard stringForType:NSStringPboardType]];
        if ([nsURL scheme] != nil && [allURLsReadFromPasteboard containsObject:nsURL] == NO)
            [toReturn addObject:nsURL];
    }

    return toReturn;
}

// Once we treat the NSPasteboard as a Carbon pboard, bad things seem to happen on Tiger (-types doesn't work), so return the PasteboardRef by reference to allow the caller to add more types to it or whatever.
BOOL FVWriteURLsToPasteboard(NSArray *URLs, NSPasteboard *pboard)
{
    OSStatus err;
    
    PasteboardRef carbonPboard;
    err = PasteboardCreate((CFStringRef)[pboard name], &carbonPboard);
    
    if (noErr == err)
        err = PasteboardClear(carbonPboard);
    
    PasteboardSyncFlags syncFlags;
#pragma unused(syncFlags)
    if (noErr == err)
        syncFlags = PasteboardSynchronize(carbonPboard);
    
    NSUInteger i, iMax = [URLs count];
    
    for (i = 0; i < iMax && noErr == err; i++) {
        
        NSURL *theURL = [URLs objectAtIndex:i];
        CFDataRef utf8Data = CFURLCreateData(nil, (CFURLRef)theURL, kCFStringEncodingUTF8, true);
        
        // any pointer type; private to the creating application
        PasteboardItemID itemID = (void *)theURL;
        
        // Finder adds a file URL and destination URL for weblocs, but only a file URL for regular files
        // could also put a string representation of the URL, but Finder doesn't do that
        
        if (NULL != utf8Data) {
            if ([theURL isFileURL]) {
                err = PasteboardPutItemFlavor(carbonPboard, itemID, kUTTypeFileURL, utf8Data, kPasteboardFlavorNoFlags);
            } else {
                err = PasteboardPutItemFlavor(carbonPboard, itemID, kUTTypeURL, utf8Data, kPasteboardFlavorNoFlags);
            }
            CFRelease(utf8Data);
        }
    }
    
    if (carbonPboard) 
        CFRelease(carbonPboard);
    
    return noErr == err;
}

@interface NSBezierPath (Leopard)
+ (NSBezierPath*)bezierPathWithRoundedRect:(NSRect)rect xRadius:(CGFloat)xRadius yRadius:(CGFloat)yRadius;
@end

@implementation NSBezierPath (RoundRect)

+ (NSBezierPath*)fv_bezierPathWithRoundRect:(NSRect)rect xRadius:(CGFloat)xRadius yRadius:(CGFloat)yRadius;
{    
    if ([self respondsToSelector:@selector(bezierPathWithRoundedRect:xRadius:yRadius:)])
        return [self bezierPathWithRoundedRect:rect xRadius:xRadius yRadius:yRadius];
    
    // Make sure radius doesn't exceed a maximum size to avoid artifacts:
    CGFloat mr = MIN(NSHeight(rect), NSWidth(rect));
    CGFloat radius = MIN(xRadius, 0.5f * mr);
    
    // Make sure silly values simply lead to un-rounded corners:
    if( radius <= 0 )
        return [self bezierPathWithRect:rect];
    
    NSRect innerRect = NSInsetRect(rect, radius, radius); // Make rect with corners being centers of the corner circles.
    NSBezierPath *path = [self bezierPath]; 
    
    // Now draw our rectangle:
    [path moveToPoint: NSMakePoint(NSMinX(innerRect) - radius, NSMinY(innerRect))];
    
    // Bottom left (origin):
    [path appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(innerRect), NSMinY(innerRect)) radius:radius startAngle:180.0 endAngle:270.0];
    // Bottom edge and bottom right:
    [path appendBezierPathWithArcWithCenter:NSMakePoint(NSMaxX(innerRect), NSMinY(innerRect)) radius:radius startAngle:270.0 endAngle:360.0];
    // Left edge and top right:
    [path appendBezierPathWithArcWithCenter:NSMakePoint(NSMaxX(innerRect), NSMaxY(innerRect)) radius:radius startAngle:0.0  endAngle:90.0 ];
    // Top edge and top left:
    [path appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(innerRect), NSMaxY(innerRect)) radius:radius startAngle:90.0  endAngle:180.0];
    // Left edge:
    [path closePath];
    
    return path;
}

@end

@implementation NSData (FVZip)

// 
// implementation modified after http://www.cocoadev.com/index.pl?NSDataCategory
//

- (NSData *)_fv_zlibDecompress
{
	if ([self length] == 0) return [[self retain] autorelease];
    
	unsigned full_length = [self length];
	unsigned half_length = [self length] / 2;
    
	NSMutableData *decompressed = [NSMutableData dataWithLength: full_length + half_length];
	BOOL done = NO;
	int status;
    
	z_stream strm;
	strm.next_in = (Bytef *)[self bytes];
	strm.avail_in = [self length];
	strm.total_out = 0;
	strm.zalloc = Z_NULL;
	strm.zfree = Z_NULL;
    
	if (inflateInit (&strm) != Z_OK) return nil;
    
	while (!done)
	{
		// Make sure we have enough room and reset the lengths.
		if (strm.total_out >= [decompressed length])
			[decompressed increaseLengthBy: half_length];
		strm.next_out = (Bytef *)[decompressed mutableBytes] + strm.total_out;
		strm.avail_out = [decompressed length] - strm.total_out;
        
		// Inflate another chunk.
		status = inflate (&strm, Z_SYNC_FLUSH);
		if (status == Z_STREAM_END) done = YES;
		else if (status != Z_OK) break;
	}
	if (inflateEnd (&strm) != Z_OK) return nil;
    
	// Set real length.
	if (done)
	{
		[decompressed setLength: strm.total_out];
		return decompressed;
	}
	else return nil;
}

- (NSData *)_fv_zlibCompress
{
	if ([self length] == 0) return [[self retain] autorelease];
	
	z_stream strm;
    
	strm.zalloc = Z_NULL;
	strm.zfree = Z_NULL;
	strm.opaque = Z_NULL;
	strm.total_out = 0;
	strm.next_in=(Bytef *)[self bytes];
	strm.avail_in = [self length];
    
	// Compresssion Levels:
	//   Z_NO_COMPRESSION
	//   Z_BEST_SPEED
	//   Z_BEST_COMPRESSION
	//   Z_DEFAULT_COMPRESSION
    
	if (deflateInit(&strm, Z_BEST_SPEED) != Z_OK) return nil;
    
	NSMutableData *compressed = [NSMutableData dataWithLength:16384];  // 16K chunks for expansion
    
	do {
        
		if (strm.total_out >= [compressed length])
			[compressed increaseLengthBy: 16384];
		
		strm.next_out = (Bytef *)[compressed mutableBytes] + strm.total_out;
		strm.avail_out = [compressed length] - strm.total_out;
		
		deflate(&strm, Z_FINISH);  
		
	} while (strm.avail_out == 0);
	
	deflateEnd(&strm);
	
	[compressed setLength: strm.total_out];
	return compressed;
}

@end


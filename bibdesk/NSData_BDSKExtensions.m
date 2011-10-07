//
//  NSData_BDSKExtensions.m
//  Bibdesk
//
//  Created by Adam Maxwell on 09/06/06.
/*
 This software is Copyright (c) 2006-2011
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

// For base 64 encoding/decoding:
//
//  Created by Matt Gallagher on 2009/06/03.
//  Copyright 2009 Matt Gallagher. All rights reserved.
//
//  Permission is given to use this source code file, free of charge, in any
//  project, commercial or otherwise, entirely at your risk, with the condition
//  that any redistribution (in part or whole) of source code must retain
//  this copyright and permission notice. Attribution in compiled projects is
//  appreciated but not required.
//

#import "NSData_BDSKExtensions.h"
#import "NSError_BDSKExtensions.h"
#import <CommonCrypto/CommonDigest.h>
#import <unistd.h>
#import <sys/mman.h>
#import <sys/stat.h>
#import <zlib.h>

NSString *BDSKEncodingConversionException = @"BDSKEncodingConversionException";

@implementation NSData (BDSKExtensions)

- (NSData *)sha1Signature {
    CC_SHA1_CTX sha1context;
    NSUInteger signatureLength = CC_SHA1_DIGEST_LENGTH;
    unsigned char signature[signatureLength];
    NSUInteger blockSize = 4096;
    char buffer[blockSize];
    unsigned int length = [self length];
    NSRange range = NSMakeRange(0, MIN(blockSize, length));
    
    // NB: status == 1 for success
    (void)CC_SHA1_Init(&sha1context);
    while (range.length > 0) {
        [self getBytes:buffer range:range];
        (void)CC_SHA1_Update(&sha1context, (const void *)buffer, (CC_LONG)range.length);
        range.location = NSMaxRange(range);
        range.length = MIN(blockSize, length - range.location);
    }
    
    (void)CC_SHA1_Final(signature, &sha1context);

    return [NSData dataWithBytes:signature length:signatureLength];
}

+ (NSData *)sha1SignatureForFile:(NSString *)absolutePath {
    const char *path = [absolutePath fileSystemRepresentation];
    
    // early out in case we can't open the file
    int fd = open(path, O_RDONLY);
    if (fd == -1)
        return nil;
    
    int status;
    struct stat sb;
    status = fstat(fd, &sb);
    if (status) {
        perror(path);
        close(fd);
        return nil;
    }
    
    (void) fcntl(fd, F_NOCACHE, 1);
    
    CC_SHA1_CTX sha1context;
    NSUInteger signatureLength = CC_SHA1_DIGEST_LENGTH;
    unsigned char signature[signatureLength];
    
    // I originally used read() with 4K blocks, but that actually made the system sluggish during intensive hashing.
    // Using 1 MB blocks gives reasonable performance, and avoids problems with really large files.
    const vm_size_t blockSize = vm_page_size * 1024;
    
    off_t offset = 0;
    size_t len = MIN((size_t)blockSize, (size_t)(sb.st_size - offset));
    char *buffer;
    
    (void)CC_SHA1_Init(&sha1context);
    while (len > 0 && (buffer = mmap(0, len, PROT_READ, MAP_SHARED | MAP_NOCACHE, fd, offset)) != (void *)-1) {
        (void)CC_SHA1_Update(&sha1context, (void *)buffer, (CC_LONG)len);
        munmap(buffer, len);
        offset += len;
        len = MIN((size_t)blockSize, (size_t)(sb.st_size - offset));
    }
    close(fd);    
    
    (void)CC_SHA1_Final(signature, &sha1context);

    return offset > 0 ? [NSData dataWithBytes:signature length:signatureLength] : nil;
}

// The following code is taken and modified from Matt Gallagher's code at http://cocoawithlove.com/2009/06/base64-encoding-options-on-mac-and.html

// Mapping from 6 bit pattern to ASCII character.
static unsigned char base64EncodeTable[65] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

// Definition for "masked-out" areas of the     base64DecodeTable mapping
#define xx 65

// Mapping from ASCII character to 6 bit pattern.
static unsigned char base64DecodeTable[256] =
{
    xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, 
    xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, 
    xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, 62, xx, xx, xx, 63, 
    52, 53, 54, 55, 56, 57, 58, 59, 60, 61, xx, xx, xx, xx, xx, xx, 
    xx,  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 
    15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, xx, xx, xx, xx, xx, 
    xx, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 
    41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, xx, xx, xx, xx, xx, 
    xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, 
    xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, 
    xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, 
    xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, 
    xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, 
    xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, 
    xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, 
    xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, 
};

// Fundamental sizes of the binary and base64 encode/decode units in bytes
#define BINARY_UNIT_SIZE 3
#define BASE64_UNIT_SIZE 4

- (id)initWithBase64String:(NSString *)base64String {
    NSData *data = [base64String dataUsingEncoding:NSASCIIStringEncoding];
    size_t length = [data length];
    const unsigned char *inputBuffer = (const unsigned char *)[data bytes];
    size_t outputBufferSize = (length / BASE64_UNIT_SIZE) * BINARY_UNIT_SIZE;
    unsigned char *outputBuffer = (unsigned char *)malloc(outputBufferSize);
    
    size_t i = 0, j = 0;
    while (i < length) {
		// Accumulate 4 valid characters (ignore everything else)
		unsigned char accumulated[BASE64_UNIT_SIZE];
		size_t accumulateIndex = 0;
		while (i < length) {
			unsigned char decode = base64DecodeTable[inputBuffer[i++]];
			if (decode != xx) {
				accumulated[accumulateIndex] = decode;
				accumulateIndex++;
				
				if (accumulateIndex == BASE64_UNIT_SIZE)
					break;
			}
		}
		
		// Store the 6 bits from each of the 4 characters as 3 bytes
		outputBuffer[j] = (accumulated[0] << 2) | (accumulated[1] >> 4);
		outputBuffer[j + 1] = (accumulated[1] << 4) | (accumulated[2] >> 2);
		outputBuffer[j + 2] = (accumulated[2] << 6) | accumulated[3];
		j += accumulateIndex - 1;
    }
    
    NSData *result = [self initWithBytes:outputBuffer length:j];
    
    free(outputBuffer);
    
    return result;
}

- (NSString *)base64String {
    size_t length = [self length];
    const unsigned char *inputBuffer = (const unsigned char *)[self bytes];
    
    #define MAX_NUM_PADDING_CHARS 2
    #define OUTPUT_LINE_LENGTH 64
    #define INPUT_LINE_LENGTH ((OUTPUT_LINE_LENGTH / BASE64_UNIT_SIZE) * BINARY_UNIT_SIZE)
    
    // Byte accurate calculation of final buffer size
    size_t outputBufferSize = ((length / BINARY_UNIT_SIZE) + ((length % BINARY_UNIT_SIZE) ? 1 : 0)) * BASE64_UNIT_SIZE;
    
    // Include space for a terminating zero
    outputBufferSize += 1;

    // Allocate the output buffer
    char *outputBuffer = (char *)malloc(outputBufferSize);
    if (outputBuffer == NULL)
		return NULL;

    size_t i = 0;
    size_t j = 0;
    size_t lineEnd = length;
    
    while (true) {
		if (lineEnd > length)
			lineEnd = length;

		for (; i + BINARY_UNIT_SIZE - 1 < lineEnd; i += BINARY_UNIT_SIZE) {
			// Inner loop: turn 48 bytes into 64 base64 characters
			outputBuffer[j++] = base64EncodeTable[(inputBuffer[i] & 0xFC) >> 2];
			outputBuffer[j++] = base64EncodeTable[((inputBuffer[i] & 0x03) << 4) | ((inputBuffer[i + 1] & 0xF0) >> 4)];
			outputBuffer[j++] = base64EncodeTable[((inputBuffer[i + 1] & 0x0F) << 2) | ((inputBuffer[i + 2] & 0xC0) >> 6)];
			outputBuffer[j++] = base64EncodeTable[inputBuffer[i + 2] & 0x3F];
		}
		
		if (lineEnd == length)
			break;
    }
    
    if (i + 1 < length) {
		// Handle the single '=' case
		outputBuffer[j++] = base64EncodeTable[(inputBuffer[i] & 0xFC) >> 2];
		outputBuffer[j++] = base64EncodeTable[((inputBuffer[i] & 0x03) << 4) | ((inputBuffer[i + 1] & 0xF0) >> 4)];
		outputBuffer[j++] = base64EncodeTable[(inputBuffer[i + 1] & 0x0F) << 2];
		outputBuffer[j++] = '=';
    } else if (i < length) {
		// Handle the double '=' case
		outputBuffer[j++] = base64EncodeTable[(inputBuffer[i] & 0xFC) >> 2];
		outputBuffer[j++] = base64EncodeTable[(inputBuffer[i] & 0x03) << 4];
		outputBuffer[j++] = '=';
		outputBuffer[j++] = '=';
    }
    outputBuffer[j] = 0;
    
    NSString *result = [[[NSString alloc] initWithBytes:outputBuffer length:j encoding:NSASCIIStringEncoding] autorelease];
    
    free(outputBuffer);
    
    return result;
}

// gzip compression/decompression from sample code on CocoaDev http://www.cocoadev.com/index.pl?NSDataCategory 

- (BOOL)mightBeCompressed
{
    if ([self length] < 10) return NO;
    unsigned char bytes[2] = {0, 0};
    [self getBytes:bytes length:2];
    return (bytes[0] == 0x1F && bytes[1] == 0x8B);
}

- (NSData *)decompressedData
{
	if ([self length] == 0) return self;
	
	unsigned int full_length = [self length];
	unsigned int half_length = [self length] / 2;
	
	NSMutableData *decompressed = [NSMutableData dataWithLength: full_length + half_length];
	BOOL done = NO;
	int status;
	
	z_stream strm;
	strm.next_in = (Bytef *)[self bytes];
	strm.avail_in = [self length];
	strm.total_out = 0;
	strm.zalloc = Z_NULL;
	strm.zfree = Z_NULL;
	
	if (inflateInit2(&strm, (15+32)) != Z_OK) return nil;
	while (!done)
	{
		// Make sure we have enough room and reset the lengths.
		if (strm.total_out >= [decompressed length])
			[decompressed increaseLengthBy: half_length];
		strm.next_out = [decompressed mutableBytes] + strm.total_out;
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
		return [NSData dataWithData: decompressed];
	}
	else return nil;
}

- (NSData *)compressedData
{
	if ([self length] == 0) return self;
	
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
	
	if (deflateInit2(&strm, Z_DEFAULT_COMPRESSION, Z_DEFLATED, (15+16), 8, Z_DEFAULT_STRATEGY) != Z_OK) return nil;
	
	NSMutableData *compressed = [NSMutableData dataWithLength:16384];  // 16K chunks for expansion
	
	do {
		
		if (strm.total_out >= [compressed length])
			[compressed increaseLengthBy: 16384];
		
		strm.next_out = [compressed mutableBytes] + strm.total_out;
		strm.avail_out = [compressed length] - strm.total_out;
		
		deflate(&strm, Z_FINISH);  
		
	} while (strm.avail_out == 0);
	
	deflateEnd(&strm);
	
	[compressed setLength: strm.total_out];
	return [NSData dataWithData:compressed];
}

- (void)_writeToPipeInBackground:(NSPipe *)aPipe
{
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    @try {
        [[aPipe fileHandleForWriting] writeData:self];
    }
    @catch (id exception) {
        NSLog(@"caught exception writing %ld bytes to pipe (%@)", (long)[self length], exception);
    }
    [[aPipe fileHandleForWriting] closeFile];
    [pool release];
}

- (FILE *)openReadStream
{    
    (void) signal(SIGPIPE, SIG_IGN);
    NSPipe *aPipe = [NSPipe pipe];
    [NSThread detachNewThreadSelector:@selector(_writeToPipeInBackground:) toTarget:self withObject:aPipe];
    int fd = [[aPipe fileHandleForReading] fileDescriptor];
    NSParameterAssert(-1 != fd);
    // caller will block on this until we write to it
    return (-1 == fd) ? NULL : fdopen(fd, "r");
}

+ (id)scriptingRtfWithDescriptor:(NSAppleEventDescriptor *)descriptor {
    return [descriptor data];
}

- (id)scriptingRtfDescriptor {
    return [NSAppleEventDescriptor descriptorWithDescriptorType:'RTF ' data:self];
}

@end


@implementation NSMutableData (BDSKExtensions)

- (void)appendUTF8DataFromString:(NSString *)string;
{
    [self appendDataFromString:string encoding:NSUTF8StringEncoding error:NULL];
}

// OmniFoundation implements an identical method (hence our different method signature); however, they raise an NSInvalidArgumentException, and I want something less generic.

- (BOOL)appendDataFromString:(NSString *)string encoding:(NSStringEncoding)encoding error:(NSError **)error;
{
    CFStringEncoding cfEncoding = CFStringConvertNSStringEncodingToEncoding(encoding);
    CFDataRef data = nil;
    
    // try this first; generally locale-specific, but it's really fast if it works
    const char *cstringPtr = CFStringGetCStringPtr((CFStringRef)string, cfEncoding);
    if (cstringPtr) {
        // Omni uses strlen, but it returns incorrect length for some strings with strange Unicode characters (bug #1558548)
        CFIndex length = CFStringGetLength((CFStringRef)string);
        CFIndex bufLen;
        CFIndex convertedLength = CFStringGetBytes((CFStringRef)string, CFRangeMake(0, length), cfEncoding, 0, FALSE, NULL, INT_MAX, &bufLen);
        if (convertedLength != length){
            if(error != NULL){
                *error = [NSError mutableLocalErrorWithCode:kBDSKStringEncodingError localizedDescription:[NSString stringWithFormat:NSLocalizedString(@"Unable to convert string to encoding %@", @"Error description"), [NSString localizedNameOfStringEncoding:encoding]]];
                [*error setValue:[NSNumber numberWithUnsignedInteger:encoding] forKey:NSStringEncodingErrorKey];
            }
            return NO;
        }
        [self appendBytes:cstringPtr length:bufLen];
    } else if(data = CFStringCreateExternalRepresentation(CFAllocatorGetDefault(), (CFStringRef)string, cfEncoding, 0)){
        [self appendData:(NSData *)data];
        CFRelease(data);
    }else if([string canBeConvertedToEncoding:encoding]){
        // sometimes CFStringCreateExternalRepresentationreturns NULL even though the string can be converted
        [self appendData:[string dataUsingEncoding:encoding]];
    }else{
        // raise if the conversion wasn't possible, since we're not using a loss byte
        if(error != NULL){
            *error = [NSError mutableLocalErrorWithCode:kBDSKStringEncodingError localizedDescription:[NSString stringWithFormat:NSLocalizedString(@"Unable to convert string to encoding %@", @"Error description"), [NSString localizedNameOfStringEncoding:encoding]]];
            [*error setValue:[NSNumber numberWithUnsignedInteger:encoding] forKey:NSStringEncodingErrorKey];
        }
        return NO;
    }
    return YES;
}

- (BOOL)appendStringData:(NSData *)data convertedFromUTF8ToEncoding:(NSStringEncoding)encoding error:(NSError **)error{
    return [self appendStringData:data convertedFromEncoding:NSUTF8StringEncoding toEncoding:encoding error:error];
}

- (BOOL)appendStringData:(NSData *)data convertedFromEncoding:(NSStringEncoding)fromEncoding toEncoding:(NSStringEncoding)toEncoding error:(NSError **)error{
    BOOL success = YES;
    if(fromEncoding == toEncoding){
        [self appendData:data];
    }else{
        NSString *string = [[NSString alloc] initWithData:data encoding:fromEncoding];
        if(nil == string){
            if(error != NULL){
                *error = [NSError mutableLocalErrorWithCode:kBDSKStringEncodingError localizedDescription:[NSString stringWithFormat:NSLocalizedString(@"Unable to convert data to string with encoding %@", @"Error description"), [NSString localizedNameOfStringEncoding:toEncoding]]];
                [*error setValue:[NSNumber numberWithUnsignedInteger:toEncoding] forKey:NSStringEncodingErrorKey];
            }
            return NO;
        }
        success = [self appendDataFromString:string encoding:toEncoding error:error];
        [string release];
    }
    return success;
}

@end

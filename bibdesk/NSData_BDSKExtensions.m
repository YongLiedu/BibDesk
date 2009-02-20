//
//  NSData_BDSKExtensions.m
//  Bibdesk
//
//  Created by Adam Maxwell on 09/06/06.
/*
 This software is Copyright (c) 2006-2009
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

#import "NSData_BDSKExtensions.h"
#import "NSError_BDSKExtensions.h"
#import <openssl/bio.h>
#import <openssl/evp.h>
#import <unistd.h>
#import <zlib.h>

NSString *BDSKEncodingConversionException = @"BDSKEncodingConversionException";

@implementation NSData (BDSKExtensions)

// avoids reading the entire file into memory at once
+ (NSData *)copySha1SignatureForFile:(NSString *)absolutePath;
{
    
    const char *path = [absolutePath fileSystemRepresentation];
    
    // early out in case we can't open the file
    int fd = open(path, O_RDONLY);
    if (fd == -1)
        return nil;
    
    EVP_MD_CTX mdctx;
    const EVP_MD *md = EVP_sha1();
    int status;
    EVP_MD_CTX_init(&mdctx);
    
    // NB: status == 1 for success
    status = EVP_DigestInit_ex(&mdctx, md, NULL);
    
    // page size
    char buffer[4096];

    ssize_t bytesRead;
    while ((bytesRead = read(fd, buffer, sizeof(buffer))) > 0)
        status = EVP_DigestUpdate(&mdctx, buffer, bytesRead);
    
    close(fd);    
    
    unsigned char md_value[EVP_MAX_MD_SIZE];
    unsigned int md_len;
    status = EVP_DigestFinal_ex(&mdctx, md_value, &md_len);
    status = EVP_MD_CTX_cleanup(&mdctx);

    // return nil instead of a random hash if read() fails (it returns -1 for a directory) 
    NSData *digest = -1 == bytesRead ? nil : [[NSData alloc] initWithBytes:md_value length:md_len];
#if 0
    NSData *omniDigest = [[NSData dataWithContentsOfFile:absolutePath] sha1Signature];
    NSAssert([omniDigest isEqual:digest], @"sha1 signature not equal to OmniFoundation's");
#endif
    return digest;
}

- (NSData *)sha1Signature {
    EVP_MD_CTX mdctx;
    const EVP_MD *md = EVP_sha1();
    int status;
    EVP_MD_CTX_init(&mdctx);
    
    // NB: status == 1 for success
    status = EVP_DigestInit_ex(&mdctx, md, NULL);
    
    const unsigned char *buffer = [self bytes];
    size_t currentBytes, bytesLeft = [self length];
    while (bytesLeft > 0) {
        currentBytes = MIN(bytesLeft, 4096u); 
        status = EVP_DigestUpdate(&mdctx, buffer, currentBytes);
        bytesLeft -= currentBytes;
        buffer += currentBytes;
    }
    
    unsigned char md_value[EVP_MAX_MD_SIZE];
    unsigned int md_len;
    status = EVP_DigestFinal_ex(&mdctx, md_value, &md_len);
    status = EVP_MD_CTX_cleanup(&mdctx);
    
    return [NSData dataWithBytes:md_value length:md_len];
}

// base 64 encoding/decoding methods modified from sample code on CocoaDev http://www.cocoadev.com/index.pl?BaseSixtyFour

- (id)initWithBase64String:(NSString *)base64String {
    return [self initWithBase64String:base64String withNewlines:YES];
}

- (id)initWithBase64String:(NSString *)base64String withNewlines:(BOOL)encodedWithNewlines {
    // Create a memory buffer containing Base64 encoded string data
    BIO *mem = BIO_new_mem_buf((void *)[base64String cStringUsingEncoding:NSASCIIStringEncoding], [base64String lengthOfBytesUsingEncoding:NSASCIIStringEncoding]);
    
    // Push a Base64 filter so that reading from the buffer decodes it
    BIO *b64 = BIO_new(BIO_f_base64());
    if (encodedWithNewlines == NO)
        BIO_set_flags(b64, BIO_FLAGS_BASE64_NO_NL);
    mem = BIO_push(b64, mem);
    
    // Decode into an NSMutableData
    NSMutableData *data = [[NSMutableData alloc] init];
    char inbuf[512];
    int inlen;
    while ((inlen = BIO_read(mem, inbuf, sizeof(inbuf))) > 0)
        [data appendBytes:inbuf length:inlen];
    
    // Clean up and go home
    BIO_free_all(mem);
    
    self = [self initWithData:data];
    [data release];
    
    return self;
}

- (NSString *)base64String {
    return [self base64StringWithNewlines:YES];
}

- (NSString *)base64StringWithNewlines:(BOOL)encodeWithNewlines {
    // Create a memory buffer which will contain the Base64 encoded string
    BIO *mem = BIO_new(BIO_s_mem());
    
    // Push on a Base64 filter so that writing to the buffer encodes the data
    BIO *b64 = BIO_new(BIO_f_base64());
    if (encodeWithNewlines == NO)
        BIO_set_flags(b64, BIO_FLAGS_BASE64_NO_NL);
    mem = BIO_push(b64, mem);
    
    // Encode all the data
    BIO_write(mem, [self bytes], [self length]);
    BIO_flush(mem);
    
    // Create a new string from the data in the memory buffer
    char *base64Pointer;
    long base64Length = BIO_get_mem_data(mem, &base64Pointer);
    NSString *base64String = [[[NSString alloc] initWithBytes:base64Pointer length:base64Length encoding:NSASCIIStringEncoding] autorelease];
    
    // Clean up and go home
    BIO_free_all(mem);
    return base64String;
}

// gzip compression/decompression from sample code on CocoaDev http://www.cocoadev.com/index.pl?NSDataCategory 

- (BOOL)mightBeCompressed
{
    const unsigned char *bytes = [self bytes];
    return ([self length] >= 10 && bytes[0] == 0x1F && bytes[1] == 0x8B);
}

- (NSData *)decompressedData
{
	if ([self length] == 0) return self;
	
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

/*" Creates a stdio FILE pointer for reading from the receiver via the funopen() BSD facility.  The receiver is automatically retained until the returned FILE is closed. "*/

// Same context used for read and write.
typedef struct _BDSKDataFileContext {
    NSData *data;
    void   *bytes;
    size_t  length;
    size_t  position;
} BDSKDataFileContext;

static int _BDSKData_readfn(void *_ctx, char *buf, int nbytes) {
    //fprintf(stderr, " read(ctx:%p buf:%p nbytes:%d)\n", _ctx, buf, nbytes);
    BDSKDataFileContext *ctx = (BDSKDataFileContext *)_ctx;

    nbytes = MIN((unsigned)nbytes, ctx->length - ctx->position);
    memcpy(buf, ctx->bytes + ctx->position, nbytes);
    ctx->position += nbytes;
    return nbytes;
}

static fpos_t _BDSKData_seekfn(void *_ctx, off_t offset, int whence) {
    //fprintf(stderr, " seek(ctx:%p off:%qd whence:%d)\n", _ctx, offset, whence);
    BDSKDataFileContext *ctx = (BDSKDataFileContext *)_ctx;

    size_t reference;
    if (whence == SEEK_SET)
        reference = 0;
    else if (whence == SEEK_CUR)
        reference = ctx->position;
    else if (whence == SEEK_END)
        reference = ctx->length;
    else
        return -1;

    if (reference + offset >= 0 && reference + offset <= ctx->length) {
        // position is a size_t (i.e., memory/vm sized) while the reference and offset are off_t (file system positioned).
        // since we are refering to an NSData, this must be OK (and we checked 'reference + offset' vs. our length above).
        ctx->position = (size_t)(reference + offset);
        return ctx->position;
    }
    return -1;
}

static int _BDSKData_closefn(void *_ctx) {
    //fprintf(stderr, "close(ctx:%p)\n", _ctx);
    BDSKDataFileContext *ctx = (BDSKDataFileContext *)_ctx;
    [ctx->data release];
    free(ctx);
    
    return 0;
}

- (FILE *)openReadOnlyStandardIOFile {
    BDSKDataFileContext *ctx = calloc(1, sizeof(BDSKDataFileContext));
    ctx->data = [self retain];
    ctx->bytes = (void *)[self bytes];
    ctx->length = [self length];
    //fprintf(stderr, "open read -> ctx:%p\n", ctx);

    FILE *f = funopen(ctx, _BDSKData_readfn, NULL/*writefn*/, _BDSKData_seekfn, _BDSKData_closefn);
    if (f == NULL)
        [self release]; // Don't leak ourselves if funopen fails
    return f;
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
        CFIndex convertedLength = CFStringGetBytes((CFStringRef)string, CFRangeMake(0, length), cfEncoding, 0, FALSE, NULL, UINT_MAX, &bufLen);
        if (convertedLength != length){
            if(error != NULL){
                *error = [NSError mutableLocalErrorWithCode:kBDSKStringEncodingError localizedDescription:[NSString stringWithFormat:NSLocalizedString(@"Unable to convert string to encoding %@", @"Error description"), [NSString localizedNameOfStringEncoding:encoding]]];
                [*error setValue:[NSNumber numberWithInt:encoding] forKey:NSStringEncodingErrorKey];
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
            [*error setValue:[NSNumber numberWithInt:encoding] forKey:NSStringEncodingErrorKey];
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
                [*error setValue:[NSNumber numberWithInt:toEncoding] forKey:NSStringEncodingErrorKey];
            }
            return NO;
        }
        success = [self appendDataFromString:string encoding:toEncoding error:error];
        [string release];
    }
    return success;
}

@end

// Copyright 1998-2004 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniFoundation/NSData-OFExtensions.h>

#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <OmniBase/OmniBase.h>

#import <OmniFoundation/NSFileManager-OFExtensions.h>
#import <OmniFoundation/NSMutableData-OFExtensions.h>
#import <OmniFoundation/NSObject-OFExtensions.h>
#import <OmniFoundation/NSString-OFExtensions.h>
#import <OmniFoundation/OFDataBuffer.h>
#import <OmniFoundation/OFRandom.h>

#import "sha1.h"
#import <OmniFoundation/md5.h>

RCS_ID("$Header: /Source/CVS/OmniGroup/Frameworks/OmniFoundation/OpenStepExtensions.subproj/NSData-OFExtensions.m,v 1.52.2.1 2004/07/15 17:13:08 kc Exp $")

@implementation NSData (OFExtensions)

+ (NSData *)randomDataOfLength:(unsigned int)length;
{
    OFByte *bytes;
    unsigned int byteIndex;

    bytes = (OFByte *)NSZoneMalloc(NULL, length);
    for (byteIndex = 0; byteIndex < length; byteIndex++)
        bytes[byteIndex] = OFRandomNext() & 0xff;

    // Send to self rather than NSData so that we'll get mutable instances when the caller sent the message to NSMutableData
    return [self dataWithBytesNoCopy:bytes length:length];
}

static inline unsigned char fromhex(unsigned char hexDigit)
{
     if (hexDigit >= '0' && hexDigit <= '9')
        return hexDigit - '0';
     if (hexDigit >= 'a' && hexDigit <= 'f')
        return hexDigit - 'a' + 10;
     if (hexDigit >= 'A' && hexDigit <= 'F')
        return hexDigit - 'A' + 10;
     [NSException raise:@"IllegalHexDigit" format:@"Attempt to interpret a string containing '%c' as a hexidecimal value", hexDigit];
     return 0; // Never reached
}

+ (id)dataWithHexString:(NSString *)hexString;
{
    return [[[self alloc] initWithHexString:hexString] autorelease];
}

- initWithHexString:(NSString *)hexString;
{
    unsigned int length;
    unsigned int destIndex;
    unichar *inputCharacters, *inputCharactersEnd;
    const unichar *inputPtr;
    OFByte *outputBytes;
    NSData *returnValue;

    length = [hexString length];
    inputCharacters = NSZoneMalloc(NULL, length * sizeof(unichar));

    [hexString getCharacters:inputCharacters];
    inputCharactersEnd = inputCharacters + length;

    inputPtr = inputCharacters;
    while (isspace(*inputPtr))
        inputPtr++;

    if (*inputPtr == '0' && (inputPtr[1] == 'x' || inputPtr[1] == 'X'))
        inputPtr += 2;

    outputBytes = NSZoneMalloc(NULL, (inputCharactersEnd - inputPtr) / 2 + 1);

    destIndex = 0;
    if ((inputCharactersEnd - inputPtr) & 0x01) {
        // 0xf08 must be interpreted as 0x0f08
        outputBytes[destIndex++] = fromhex(*inputPtr++);
    }

    while (inputPtr < inputCharactersEnd) {
        unsigned char outputByte;

        outputByte = fromhex(*inputPtr++) << 4;
        outputByte |= fromhex(*inputPtr++);
        outputBytes[destIndex++] = outputByte;
    }

    returnValue = [self initWithBytes:outputBytes length:destIndex];

    NSZoneFree(NULL, inputCharacters);
    NSZoneFree(NULL, outputBytes);

    return returnValue;
}

- (NSString *)_lowercaseHexStringWithPrefix:(const unichar *)prefix
                                     length:(unsigned int)prefixLength
{
    const OFByte *inputBytes, *inputBytesPtr;
    unsigned int inputBytesLength, outputBufferLength;
    unichar *outputBuffer, *outputBufferEnd;
    unichar *outputBufferPtr;
    const char _tohex[] = "0123456789abcdef";
    NSString *hexString;

    inputBytes = [self bytes];
    inputBytesLength = [self length];
    outputBufferLength = prefixLength + inputBytesLength * 2;
    outputBuffer = NSZoneMalloc(NULL, outputBufferLength * sizeof(unichar));
    outputBufferEnd = outputBuffer + outputBufferLength;

    inputBytesPtr = inputBytes;
    outputBufferPtr = outputBuffer;

    while(prefixLength--)
        *outputBufferPtr++ = *prefix++;
    while (outputBufferPtr < outputBufferEnd) {
        unsigned char inputByte;

        inputByte = *inputBytesPtr++;
        *outputBufferPtr++ = _tohex[(inputByte & 0xf0) >> 4];
        *outputBufferPtr++ = _tohex[inputByte & 0x0f];
    }

    hexString = [[NSString allocWithZone:[self zone]] initWithCharacters:outputBuffer length:outputBufferLength];

    NSZoneFree(NULL, outputBuffer);

    return [hexString autorelease];
}

- (NSString *)lowercaseHexString;
{
    /* For backwards compatibility, this method has a leading "0x" */
    static const unichar hexPrefix[2] = { '0', 'x' };

    return [self _lowercaseHexStringWithPrefix:hexPrefix length:2];
}

- (NSString *)unadornedLowercaseHexString;
{
    return [self _lowercaseHexStringWithPrefix:NULL length:0];
}

// This is based on decode85.c.  The only major difference is that this doesn't deal with newlines in the file and doesn't deal with the '<~' and '~>' beginning and end of stirng markers.

static inline void ascii85put(OFDataBuffer *buffer, unsigned long tuple, int bytes)
{
    switch (bytes) {
        case 4:
            OFDataBufferAppendByte(buffer, tuple >> 24);
            OFDataBufferAppendByte(buffer, tuple >> 16);
            OFDataBufferAppendByte(buffer, tuple >>  8);
            OFDataBufferAppendByte(buffer, tuple);
            break;
        case 3:
            OFDataBufferAppendByte(buffer, tuple >> 24);
            OFDataBufferAppendByte(buffer, tuple >> 16);
            OFDataBufferAppendByte(buffer, tuple >>  8);
            break;
        case 2:
            OFDataBufferAppendByte(buffer, tuple >> 24);
            OFDataBufferAppendByte(buffer, tuple >> 16);
            break;
        case 1:
            OFDataBufferAppendByte(buffer, tuple >> 24);
            break;
    }
}

- initWithASCII85String:(NSString *)ascii85String;
{
    static const unsigned long pow85[] = {
            85 * 85 * 85 * 85, 85 * 85 * 85, 85 * 85, 85, 1
    };
    OFDataBuffer buffer;
    const unsigned char *string;
    unsigned long tuple = 0, length;
    int c, count = 0;
    NSData *ascii85Data, *decodedData;
    NSData *returnValue;

    OBPRECONDITION([ascii85String canBeConvertedToEncoding:NSASCIIStringEncoding]);

    ascii85Data = [ascii85String dataUsingEncoding:NSASCIIStringEncoding];
    string = [ascii85Data bytes];
    length = [ascii85Data length];
    
    OFDataBufferInit(&buffer);
    while (length--) {
        c = (int)*string;
        string++;

        switch (c) {
            default:
                if (c < '!' || c > 'u')
                    [NSException raise:@"ASCII85Error" format:@"ASCII85: bad character in ascii85 string: %#o", c];

                tuple += (c - '!') * pow85[count++];
                if (count == 5) {
                    ascii85put(&buffer, tuple, 4);
                    count = 0;
                    tuple = 0;
                }
                break;
            case 'z':
                if (count != 0)
                    [NSException raise:@"ASCII85Error" format:@"ASCII85: z inside ascii85 5-tuple"];
                OFDataBufferAppendByte(&buffer, '\0');
                OFDataBufferAppendByte(&buffer, '\0');
                OFDataBufferAppendByte(&buffer, '\0');
                OFDataBufferAppendByte(&buffer, '\0');
                break;
        }
    }

    if (count > 0) {
        count--;
        tuple += pow85[count];
        ascii85put(&buffer, tuple, count);
    }

    decodedData = [OFDataBufferData(&buffer) retain];
    OFDataBufferRelease(&buffer);

    returnValue = [self initWithData:decodedData];
    [decodedData release];

    return returnValue;
}

static inline void encode85(OFDataBuffer *dataBuffer, unsigned long tuple, int count)
{
    int i;
    char buf[5], *s = buf;
    i = 5;
    do {
        *s++ = tuple % 85;
        tuple /= 85;
    } while (--i > 0);
    i = count;
    do {
        OFDataBufferAppendByte(dataBuffer, *--s + '!');
    } while (i-- > 0);
}

- (NSString *)ascii85String;
{
    OFDataBuffer dataBuffer;
    const unsigned char *byte;
    unsigned int length, count = 0, tuple = 0;
    NSData *data;
    NSString *string;
    
    OFDataBufferInit(&dataBuffer);
    
    byte = [self bytes];
    length = [self length];

    // This is based on encode85.c.  The only major difference is that this doesn't put newlines in the file to keep the output line(s) as some maximum width.  Also, this doesn't put the '<~' at the beginning and '

    while (length--) {
        unsigned int c;

        c = (unsigned int)*byte;
        byte++;

        switch (count++) {
            case 0:
                tuple |= (c << 24);
                break;
            case 1:
                tuple |= (c << 16);
                break;
            case 2:
                tuple |= (c <<  8);
                break;
            case 3:
                tuple |= c;
                if (tuple == 0)
                    OFDataBufferAppendByte(&dataBuffer, 'z');
                else
                    encode85(&dataBuffer, tuple, count);
                tuple = 0;
                count = 0;
                break;
        }
    }

    if (count > 0)
        encode85(&dataBuffer, tuple, count);
        
    data = OFDataBufferData(&dataBuffer);
    string = [NSString stringWithData:data encoding:NSASCIIStringEncoding];
    OFDataBufferRelease(&dataBuffer);

    return string;
}

//
// Base-64 (RFC-1521) support.  The following is based on mpack-1.5 (ftp://ftp.andrew.cmu.edu/pub/mpack/)
//

#define XX 127
static char index_64[256] = {
    XX,XX,XX,XX, XX,XX,XX,XX, XX,XX,XX,XX, XX,XX,XX,XX,
    XX,XX,XX,XX, XX,XX,XX,XX, XX,XX,XX,XX, XX,XX,XX,XX,
    XX,XX,XX,XX, XX,XX,XX,XX, XX,XX,XX,62, XX,XX,XX,63,
    52,53,54,55, 56,57,58,59, 60,61,XX,XX, XX,XX,XX,XX,
    XX, 0, 1, 2,  3, 4, 5, 6,  7, 8, 9,10, 11,12,13,14,
    15,16,17,18, 19,20,21,22, 23,24,25,XX, XX,XX,XX,XX,
    XX,26,27,28, 29,30,31,32, 33,34,35,36, 37,38,39,40,
    41,42,43,44, 45,46,47,48, 49,50,51,XX, XX,XX,XX,XX,
    XX,XX,XX,XX, XX,XX,XX,XX, XX,XX,XX,XX, XX,XX,XX,XX,
    XX,XX,XX,XX, XX,XX,XX,XX, XX,XX,XX,XX, XX,XX,XX,XX,
    XX,XX,XX,XX, XX,XX,XX,XX, XX,XX,XX,XX, XX,XX,XX,XX,
    XX,XX,XX,XX, XX,XX,XX,XX, XX,XX,XX,XX, XX,XX,XX,XX,
    XX,XX,XX,XX, XX,XX,XX,XX, XX,XX,XX,XX, XX,XX,XX,XX,
    XX,XX,XX,XX, XX,XX,XX,XX, XX,XX,XX,XX, XX,XX,XX,XX,
    XX,XX,XX,XX, XX,XX,XX,XX, XX,XX,XX,XX, XX,XX,XX,XX,
    XX,XX,XX,XX, XX,XX,XX,XX, XX,XX,XX,XX, XX,XX,XX,XX,
};
#define CHAR64(c) (index_64[(unsigned char)(c)])

#define BASE64_GETC (length > 0 ? (length--, bytes++, (unsigned int)(bytes[-1])) : (unsigned int)EOF)
#define BASE64_PUTC(c) OFDataBufferAppendByte(buffer, (c))

+ (id)dataWithBase64String:(NSString *)base64String;
{
    return [[[self alloc] initWithBase64String:base64String] autorelease];
}

- initWithBase64String:(NSString *)base64String;
{
    NSData *base64Data;
    const char *bytes;
    unsigned int length;
    OFDataBuffer dataBuffer, *buffer;
    NSData *decodedData;
    NSData *returnValue;
    BOOL suppressCR = NO;
    unsigned int c1, c2, c3, c4;
    int DataDone = 0;
    char buf[3];

    OBPRECONDITION([base64String canBeConvertedToEncoding:NSASCIIStringEncoding]);

    buffer = &dataBuffer;
    OFDataBufferInit(buffer);

    base64Data = [base64String dataUsingEncoding:NSASCIIStringEncoding];
    bytes = [base64Data bytes];
    length = [base64Data length];

    while ((c1 = BASE64_GETC) != (unsigned int)EOF) {
        if (c1 != '=' && CHAR64(c1) == XX)
            continue;
        if (DataDone)
            continue;
        
        do {
            c2 = BASE64_GETC;
        } while (c2 != (unsigned int)EOF && c2 != '=' && CHAR64(c2) == XX);
        do {
            c3 = BASE64_GETC;
        } while (c3 != (unsigned int)EOF && c3 != '=' && CHAR64(c3) == XX);
        do {
            c4 = BASE64_GETC;
        } while (c4 != (unsigned int)EOF && c4 != '=' && CHAR64(c4) == XX);
        if (c2 == (unsigned int)EOF || c3 == (unsigned int)EOF || c4 == (unsigned int)EOF) {
            [NSException raise:@"Base64Error" format:@"Premature end of Base64 string"];
            break;
        }
        if (c1 == '=' || c2 == '=') {
            DataDone=1;
            continue;
        }
        c1 = CHAR64(c1);
        c2 = CHAR64(c2);
        buf[0] = ((c1<<2) | ((c2&0x30)>>4));
        if (!suppressCR || buf[0] != '\r') BASE64_PUTC(buf[0]);
        if (c3 == '=') {
            DataDone = 1;
        } else {
            c3 = CHAR64(c3);
            buf[1] = (((c2&0x0F) << 4) | ((c3&0x3C) >> 2));
            if (!suppressCR || buf[1] != '\r') BASE64_PUTC(buf[1]);
            if (c4 == '=') {
                DataDone = 1;
            } else {
                c4 = CHAR64(c4);
                buf[2] = (((c3&0x03) << 6) | c4);
                if (!suppressCR || buf[2] != '\r') BASE64_PUTC(buf[2]);
            }
        }
    }

    decodedData = [OFDataBufferData(buffer) retain];
    OFDataBufferRelease(buffer);

    returnValue = [self initWithData:decodedData];
    [decodedData release];

    return returnValue;
}

static char basis_64[] =
   "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

static inline void output64chunk(int c1, int c2, int c3, int pads, OFDataBuffer *buffer)
{
    BASE64_PUTC(basis_64[c1>>2]);
    BASE64_PUTC(basis_64[((c1 & 0x3)<< 4) | ((c2 & 0xF0) >> 4)]);
    if (pads == 2) {
        BASE64_PUTC('=');
        BASE64_PUTC('=');
    } else if (pads) {
        BASE64_PUTC(basis_64[((c2 & 0xF) << 2) | ((c3 & 0xC0) >>6)]);
        BASE64_PUTC('=');
    } else {
        BASE64_PUTC(basis_64[((c2 & 0xF) << 2) | ((c3 & 0xC0) >>6)]);
        BASE64_PUTC(basis_64[c3 & 0x3F]);
    }
}

- (NSString *)base64String;
{
    NSString *string;
    NSData *data;
    const OFByte *bytes;
    unsigned int length;
    OFDataBuffer dataBuffer, *buffer;
    unsigned int c1, c2, c3;

    buffer = &dataBuffer;
    OFDataBufferInit(buffer);

    bytes = [self bytes];
    length = [self length];

    while ((c1 = BASE64_GETC) != (unsigned int)EOF) {
        c2 = BASE64_GETC;
        if (c2 == (unsigned int)EOF) {
            output64chunk(c1, 0, 0, 2, buffer);
        } else {
            c3 = BASE64_GETC;
            if (c3 == (unsigned int)EOF) {
                output64chunk(c1, c2, 0, 1, buffer);
            } else {
                output64chunk(c1, c2, c3, 0, buffer);
            }
        }
    }

    data = OFDataBufferData(&dataBuffer);
    string = [NSString stringWithData:data encoding:NSASCIIStringEncoding];
    OFDataBufferRelease(&dataBuffer);

    return string;
}

//
// Omni's custom base-26 support.  This is based on the ascii85 implementation above.
//
// Input strings are characters (either upper or lowercase).  Dashes are ignored.
// Anything else, including whitespace, is illegal.
//
// Output strings are four-character tuples separated by dashes.  The last
// tuple might have fewer than four characters.
//
// Unlike most encodings in this file, a partially-filled 4-octet group has the data
// packed into the less-significant bytes, instead of the more-significant bytes.
//

#define POW4_26_COUNT (7)   // Four base 256 digits take 7 base 26 digits
#define POW3_26_COUNT (6)   // Three base 256 digits take 6 base 26 digits
#define POW2_26_COUNT (4)   // Two base 256 digits take 4 base 26 digits
#define POW1_26_COUNT (2)   // One base 256 digit taks 2 base 26 digits

static unsigned int log256_26[] = {
    POW1_26_COUNT,
    POW2_26_COUNT,
    POW3_26_COUNT,
    POW4_26_COUNT
};

static unsigned int log26_256[] = {
    0, // invalid
    1, // two base 26 digits gives one base 256 digit
    0, // invalid
    2, // four base 26 digits gives two base 256 digits
    0, // invalid
    3, // six base 26 digits gives three base 256 digits
    4, // seven base 26 digits gives three base 256 digits
};

static inline void ascii26put(OFDataBuffer *buffer, unsigned long tuple, int count26)
{
    switch (log26_256[count26-1]) {
        case 4:
            OFDataBufferAppendByte(buffer, (tuple >> 24) & 0xff);
            OFDataBufferAppendByte(buffer, (tuple >> 16) & 0xff);
            OFDataBufferAppendByte(buffer, (tuple >>  8) & 0xff);
            OFDataBufferAppendByte(buffer, (tuple >>  0) & 0xff);
            break;
        case 3:
            OFDataBufferAppendByte(buffer, (tuple >> 16) & 0xff);
            OFDataBufferAppendByte(buffer, (tuple >>  8) & 0xff);
            OFDataBufferAppendByte(buffer, (tuple >>  0) & 0xff);
            break;
        case 2:
            OFDataBufferAppendByte(buffer, (tuple >>  8) & 0xff);
            OFDataBufferAppendByte(buffer, (tuple >>  0) & 0xff);
            break;
        case 1:
            OFDataBufferAppendByte(buffer, (tuple >>  0) & 0xff);
            break;
        default: // ie, zero
            [NSException raise:@"IllegalBase26String" format:@"Malformed base26 string -- last block is %d long", count26];
            break;
    }
}

- initWithASCII26String:(NSString *)ascii26String;
{
    OFDataBuffer buffer;
    const unsigned char *string;
    unsigned long tuple = 0, length;
    unsigned char c, count = 0;
    NSData *ascii26Data, *decodedData;
    NSData *returnValue;

    OBPRECONDITION([ascii26String canBeConvertedToEncoding:NSASCIIStringEncoding]);

    ascii26Data = [ascii26String dataUsingEncoding:NSASCIIStringEncoding];
    string = [ascii26Data bytes];
    length = [ascii26Data length];

    OFDataBufferInit(&buffer);
    while (length--) {
        c = *string;
        string++;

        if (c == '-') {
            // Dashes are ignored
            continue;
        }

        count++;
        
        // 'shift' up
        tuple *= 26;

        // 'or' in the new digit
        if (c >= 'a' && c <= 'z') {
            tuple += (c - 'a');
        } else if (c >= 'A' && c <= 'Z') {
            tuple += (c - 'A');
        } else {
            // Illegal character
            [NSException raise:@"ASCII26Error"
                        format:@"ASCII26: bad character in ascii26 string: %#o", c];
        }

        if (count == POW4_26_COUNT) {
            // If we've filled up a full tuple, output it
            ascii26put(&buffer, tuple, count);
            count = 0;
            tuple = 0;
        }
    }

    if (count)
        // flush remaining digits
        ascii26put(&buffer, tuple, count);

    decodedData = [OFDataBufferData(&buffer) retain];
    OFDataBufferRelease(&buffer);

    returnValue = [self initWithData:decodedData];
    [decodedData release];

    return returnValue;
}

static inline void encode26(OFDataBuffer *dataBuffer, unsigned long tuple, int count256)
{
    int  i, count26;
    char buf[POW4_26_COUNT], *s = buf;

    // Compute the number of base 26 digits necessary to represent
    // the number of base 256 digits we've been given.
    count26 = log256_26[count256-1];

    i = count26;
    while (i--) {
        *s = tuple % 26;
        tuple /= 26;
        s++;
    }
    i = count26;
    while (i--) {
        s--;
        OFDataBufferAppendByte(dataBuffer, *s + 'A');
    }
}

- (NSString *) ascii26String;
{
    OFDataBuffer dataBuffer;
    const unsigned char *byte;
    unsigned int length, count = 0, tuple = 0;
    NSData *data;
    NSString *string;

    OFDataBufferInit(&dataBuffer);

    byte   = [self bytes];
    length = [self length];

    while (length--) {
        unsigned int c;

        c = (unsigned int)*byte;
        tuple <<= 8;
        tuple += c;
        byte++;
        count++;
        
        if (count == 4) {
            encode26(&dataBuffer, tuple, count);
            tuple = 0;
            count = 0;
        }
    }

    if (count)
        encode26(&dataBuffer, tuple, count);

    data = OFDataBufferData(&dataBuffer);
    string = [NSString stringWithData:data encoding:NSASCIIStringEncoding];
    OFDataBufferRelease(&dataBuffer);

    return string;
}

+ dataWithDecodedURLString:(NSString *)urlString
{
    if (urlString == nil)
        return [NSData data];
    else
        return [urlString dataUsingCFEncoding:[NSString urlEncoding] allowLossyConversion:NO hexEscapes:@"%"];
}

static inline unichar hex(int i)
{
    static const char hexDigits[16] = {
        '0', '1', '2', '3', '4', '5', '6', '7',
        '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'
    };

    return (unichar)hexDigits[i];
}

- (unsigned)lengthOfQuotedPrintableStringWithMapping:(const OFQuotedPrintableMapping *)qpMap
{
    unsigned const char *sourceBuffer;
    unsigned sourceLength, sourceIndex, quotedPairs;

    sourceLength = [self length];
    if (sourceLength == 0)
        return 0;
    sourceBuffer = [self bytes];

    quotedPairs = 0;

    for (sourceIndex = 0; sourceIndex < sourceLength; sourceIndex++) {
        unsigned char ch = sourceBuffer[sourceIndex];
        if (qpMap->map[ch] == 1)
            quotedPairs ++;
    }

    return sourceLength + ( 2 * quotedPairs );
}

- (NSString *)quotedPrintableStringWithMapping:(const OFQuotedPrintableMapping *)qpMap lengthHint:(unsigned)outputLengthHint
{
    unsigned const char *sourceBuffer;
    int sourceLength;
    int sourceIndex;
    unichar *destinationBuffer;
    int destinationBufferSize;
    int destinationIndex;
    NSString *escapedString;

    sourceLength = [self length];
    if (sourceLength == 0)
        return [NSString string];
    sourceBuffer = [self bytes];

    if (outputLengthHint > 0)
        destinationBufferSize = outputLengthHint;
    else
        destinationBufferSize = sourceLength + (sourceLength >> 2) + 12;
    destinationBuffer = malloc((destinationBufferSize) * sizeof(*destinationBuffer));
    destinationIndex = 0;

    for (sourceIndex = 0; sourceIndex < sourceLength; sourceIndex++) {
        unsigned char ch;
        unsigned char chtype;

        ch = sourceBuffer[sourceIndex];

        if (destinationIndex >= destinationBufferSize - 3) {
            destinationBufferSize += destinationBufferSize >> 2;
            destinationBuffer = realloc(destinationBuffer, (destinationBufferSize) * sizeof(*destinationBuffer));
        }

        chtype = qpMap->map[ ch ];
        if (!chtype) {
            destinationBuffer[destinationIndex++] = ch;
        } else {
            destinationBuffer[destinationIndex++] = qpMap->translations[chtype-1];
            if (chtype == 1) {
                // "1" indicates a quoted-printable rather than a translation
                destinationBuffer[destinationIndex++] = hex((ch & 0xF0) >> 4);
                destinationBuffer[destinationIndex++] = hex(ch & 0x0F);
            }
        }
    }

    escapedString = [[[NSString alloc] initWithCharactersNoCopy:destinationBuffer length:destinationIndex freeWhenDone:YES] autorelease];

    return escapedString;
}

//
// Misc extensions
//

- (unsigned long)indexOfFirstNonZeroByte;
{
    const OFByte *bytes, *bytePtr;
    unsigned long int byteIndex, byteCount;

    byteCount = [self length];
    bytes = (const unsigned char *)[self bytes];

    for (byteIndex = 0, bytePtr = bytes; byteIndex < byteCount; byteIndex++, bytePtr++) {
	if (*bytePtr != 0)
	    return byteIndex;
    }

    return NSNotFound;
}

- (unsigned long)firstByteSet;
{
    return [self indexOfFirstNonZeroByte];
}

- (NSData *)sha1Signature;
{
    const char *bytesToProcess;
    unsigned int lengthToProcess, currentLengthToProcess;
    SHA1_CTX context;
    char signature[SHA1_SIGNATURE_LENGTH];

    bytesToProcess = [self bytes];
    lengthToProcess = [self length];

    SHA1Init(&context);

    while (lengthToProcess) {
        currentLengthToProcess = MIN(lengthToProcess, 16384u);
        SHA1Update(&context, bytesToProcess, currentLengthToProcess);
        lengthToProcess -= currentLengthToProcess;
        bytesToProcess += currentLengthToProcess;
    }

    SHA1Final(signature, &context);

    return [NSData dataWithBytes:signature length:SHA1_SIGNATURE_LENGTH];
}

/* An MD5 hash is 16 bytes long. There isn't a define for this in md5.h; but it can't ever change, anyway (unless we go to a non-8-bit byte) */
#define MD5_SIGNATURE_LENGTH 16

- (NSData *)md5Signature;
{
    MD5_CTX md5context;
    unsigned char signature[MD5_SIGNATURE_LENGTH];

    MD5Init(&md5context);
    MD5Update(&md5context, [self bytes], [self length]);
    MD5Final(signature, &md5context);

    return [NSData dataWithBytes:signature length:MD5_SIGNATURE_LENGTH];
}

- (BOOL)hasPrefix:(NSData *)data;
{
    unsigned const char *selfPtr, *ptr, *end;

    if ([self length] < [data length])
        return NO;

    ptr = [data bytes];
    end = ptr + [data length];
    selfPtr = [self bytes];
    
    while(ptr < end) {
        if (*ptr++ != *selfPtr++)
            return NO;
    }
    return YES;
}

- (BOOL)containsData:(NSData *)data;
{
    unsigned const char *selfPtr, *selfEnd, *selfRestart, *ptr, *ptrRestart, *end;
    unsigned myLength, otherLength;

    ptrRestart = [data bytes];
    otherLength = [data length];
    if (otherLength == 0)
        return YES;
    end = ptrRestart + otherLength;
    selfRestart = [self bytes];
    myLength = [self length];
    if (myLength < otherLength) // This test is a nice shortcut, but it's also necessary to avoid crashing: zero-length CFDatas will sometimes(?) return NULL for their bytes pointer, and the resulting pointer arithmetic can underflow.
        return NO;
    selfEnd = selfRestart + (myLength - otherLength);

    /* A note on the goto in the following code, for the structure-obsessed among us: it could be replaced with a flag and a 'break', yes, but since that code path is the most common one (and gcc3 doesn't optimize out control-flow flags) it seems worth the potential disapprobation from the use of reviled goto. */
    
    while(selfRestart <= selfEnd) {
        selfPtr = selfRestart;
        ptr = ptrRestart;
        while(ptr < end) {
            if (*ptr++ != *selfPtr++)
                goto notThisOffset;
        }

        return YES;

      notThisOffset:
        selfRestart++;
    }
    return NO;
}

- propertyList
{
    CFPropertyListRef propList;
    CFStringRef errorString;
    NSException *exception;
    
    propList = CFPropertyListCreateFromXMLData(kCFAllocatorDefault, (CFDataRef)self, kCFPropertyListImmutable, &errorString);
    
    if (propList != NULL)
        return [(id <NSObject>)propList autorelease];
    
    exception = [[NSException alloc] initWithName:NSParseErrorException reason:(NSString *)errorString userInfo:nil];
    
    [(NSString *)errorString release];
    
    [exception autorelease];
    [exception raise];
    /* NOT REACHED */
    return nil;
}


- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)useAuxiliaryFile createDirectories:(BOOL)shouldCreateDirectories;
    // Will raise an exception if it can't create the required directories.
{
    if (shouldCreateDirectories) {
        // TODO: We ought to make the attributes configurable
        [[NSFileManager defaultManager] createPathToFile:path attributes:nil];
    }

    return [self writeToFile:path atomically:useAuxiliaryFile];
}

- (NSData *)dataByAppendingData:(NSData *)anotherData;
{
    unsigned int myLength, otherLength;
    NSMutableData *buffer;
    NSData *result;
    
    if (!anotherData)
        return [[self copy] autorelease];

    myLength = [self length];
    otherLength = [anotherData length];

    if (!otherLength) return [[self copy] autorelease];
    if (!myLength) return [[anotherData copy] autorelease];

    buffer = [[NSMutableData alloc] initWithCapacity:myLength + otherLength];
    [buffer appendData:self];
    [buffer appendData:anotherData];
    result = [buffer copy];
    [buffer release];

    return [result autorelease];
}

/*" Creates a stdio FILE pointer for reading from the receiver via the funopen() BSD facility.  The receiver is automatically retained until the returned FILE is closed. "*/

// Same context used for read and write.
typedef struct _NSDataFileContext {
    NSData *data;
    void   *bytes;
    size_t  length;
    size_t  position;
} NSDataFileContext;

static int _NSData_readfn(void *_ctx, char *buf, int nbytes)
{
    //fprintf(stderr, " read(ctx:%p buf:%p nbytes:%d)\n", _ctx, buf, nbytes);
    NSDataFileContext *ctx = (NSDataFileContext *)_ctx;

    nbytes = MIN(nbytes, ctx->length - ctx->position);
    memcpy(buf, ctx->bytes + ctx->position, nbytes);
    ctx->position += nbytes;
    return nbytes;
}

static int _NSData_writefn(void *_ctx, const char *buf, int nbytes)
{
    //fprintf(stderr, "write(ctx:%p buf:%p nbytes:%d)\n", _ctx, buf, nbytes);
    NSDataFileContext *ctx = (NSDataFileContext *)_ctx;

    // Might be in the middle of a the file if a seek has been done so we can't just append naively!
    if (ctx->position + nbytes > ctx->length) {
        ctx->length = ctx->position + nbytes;
        [(NSMutableData *)ctx->data setLength:ctx->length];
        ctx->bytes = [(NSMutableData *)ctx->data mutableBytes]; // Might have moved after size change
    }

    memcpy(ctx->bytes + ctx->position, buf, nbytes);
    ctx->position += nbytes;
    return nbytes;
}

static fpos_t _NSData_seekfn(void *_ctx, off_t offset, int whence)
{
    //fprintf(stderr, " seek(ctx:%p off:%qd whence:%d)\n", _ctx, offset, whence);
    NSDataFileContext *ctx = (NSDataFileContext *)_ctx;

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
        ctx->position = reference + offset;
        return ctx->position;
    }
    return -1;
}

static int _NSData_closefn(void *_ctx)
{
    //fprintf(stderr, "close(ctx:%p)\n", _ctx);
    NSDataFileContext *ctx = (NSDataFileContext *)_ctx;
    [ctx->data release];
    free(ctx);
    
    return 0;
}


- (FILE *)openReadOnlyStandardIOFile;
{
    NSDataFileContext *ctx = calloc(1, sizeof(NSDataFileContext));
    ctx->data = [self retain];
    ctx->bytes = (void *)[self bytes];
    ctx->length = [self length];
    //fprintf(stderr, "open read -> ctx:%p\n", ctx);

    FILE *f = funopen(ctx, _NSData_readfn, NULL/*writefn*/, _NSData_seekfn, _NSData_closefn);
    if (f == NULL)
        [self release]; // Don't leak ourselves if funopen fails
    return f;
}


@end


@implementation NSMutableData (OFIOExtensions)

- (FILE *)openReadWriteStandardIOFile;
{
    NSDataFileContext *ctx = calloc(1, sizeof(NSDataFileContext));
    ctx->data   = [self retain];
    ctx->bytes  = [self mutableBytes];
    ctx->length = [self length];
    //fprintf(stderr, "open write -> ctx:%p\n", ctx);
    
    FILE *f = funopen(ctx, _NSData_readfn, _NSData_writefn, _NSData_seekfn, _NSData_closefn);
    if (f == NULL)
        [self release]; // Don't leak ourselves if funopen fails
    return f;
}

@end

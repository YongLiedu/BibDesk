// Copyright 1997-2005, 2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniFoundation/OFSignature.h>

#import "sha1.h"

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease_2007-10-25/OmniGroup/Frameworks/OmniFoundation/DataStructures.subproj/OFSignature.m 90130 2007-08-15 07:15:53Z bungi $")

#define CONTEXT  ((SHA1_CTX *)_private)

@implementation OFSignature

+ (void) initialize
{
    OBINITIALIZE;

    // Verify that the renaming of this define is valid
    OBASSERT(OF_SIGNATURE_LENGTH == SHA1_SIGNATURE_LENGTH);
}

- init;
{
    return [self initWithBytes:nil length:0];
}

- (void) dealloc;
{
    NSZoneFree(NULL, _private);
    [_signatureData release];
    [super dealloc];
}

- initWithData: (NSData *) data;
{
    return [self initWithBytes: [data bytes] length: [data length]];
}

- initWithBytes: (const void *) bytes length: (unsigned int) length;
{
    if ([super init] == nil)
        return nil;

    _private = NSZoneMalloc(NULL, sizeof(SHA1_CTX));
    SHA1Init(CONTEXT);

    [self addBytes: bytes length: length];
    return self;
}

- (void) addData: (NSData *) data;
{
    [self addBytes: [data bytes] length: [data length]];
}

- (void) addBytes: (const void *) bytes length: (unsigned int) length;
{
    unsigned int currentLengthToProcess;

    OBPRECONDITION(!_signatureData);
    
    while (length) {
        currentLengthToProcess = MIN(length, 16384u);
        SHA1Update(CONTEXT, bytes, currentLengthToProcess);
        length -= currentLengthToProcess;
        bytes += currentLengthToProcess;
    }
}

- (NSData *) signatureData;
{
    if (!_signatureData) {
        unsigned char signature[SHA1_SIGNATURE_LENGTH];

        SHA1Final(signature, CONTEXT);
        _signatureData = [[NSData alloc] initWithBytes: signature length: SHA1_SIGNATURE_LENGTH];
       
    }

    return _signatureData;
}


@end

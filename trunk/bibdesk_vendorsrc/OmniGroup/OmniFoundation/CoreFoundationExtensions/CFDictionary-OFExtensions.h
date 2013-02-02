// Copyright 1997-2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease_2007-10-25/OmniGroup/Frameworks/OmniFoundation/CoreFoundationExtensions/CFDictionary-OFExtensions.h 82735 2007-01-05 01:21:23Z kc $

#import <CoreFoundation/CFDictionary.h>

#import <OmniFoundation/FrameworkDefines.h>

OmniFoundation_EXTERN const CFDictionaryKeyCallBacks OFCaseInsensitiveStringKeyDictionaryCallbacks;


OmniFoundation_EXTERN const CFDictionaryKeyCallBacks    OFNonOwnedPointerDictionaryKeyCallbacks;
OmniFoundation_EXTERN const CFDictionaryValueCallBacks  OFNonOwnedPointerDictionaryValueCallbacks;

OmniFoundation_EXTERN const CFDictionaryKeyCallBacks    OFPointerEqualObjectDictionaryKeyCallbacks;

OmniFoundation_EXTERN const CFDictionaryKeyCallBacks    OFIntegerDictionaryKeyCallbacks;
OmniFoundation_EXTERN const CFDictionaryValueCallBacks  OFIntegerDictionaryValueCallbacks;

OmniFoundation_EXTERN const CFDictionaryKeyCallBacks    OFNSObjectDictionaryKeyCallbacks;
OmniFoundation_EXTERN const CFDictionaryKeyCallBacks    OFNSObjectCopyDictionaryKeyCallbacks;
OmniFoundation_EXTERN const CFDictionaryValueCallBacks  OFNSObjectDictionaryValueCallbacks;


// Convenience functions
@class NSMutableDictionary;
OmniFoundation_EXTERN NSMutableDictionary *OFCreateCaseInsensitiveKeyMutableDictionary(void);

// Applier functions
OmniFoundation_EXTERN void OFPerformSelectorOnKeyApplierFunction(const void *key, const void *value, void *context);   // context==SEL
OmniFoundation_EXTERN void OFPerformSelectorOnValueApplierFunction(const void *key, const void *value, void *context); // context==SEL

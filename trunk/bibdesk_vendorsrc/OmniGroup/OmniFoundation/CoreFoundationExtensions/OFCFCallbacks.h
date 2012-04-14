// Copyright 2002-2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease_2007-10-25/OmniGroup/Frameworks/OmniFoundation/CoreFoundationExtensions/OFCFCallbacks.h 89466 2007-08-01 23:35:13Z kc $

#import <CoreFoundation/CFString.h>


// Callbacks for NSObjects
OmniFoundation_EXTERN const void *OFNSObjectRetain(CFAllocatorRef allocator, const void *value);
OmniFoundation_EXTERN const void *OFNSObjectRetainCopy(CFAllocatorRef allocator, const void *value);
OmniFoundation_EXTERN void        OFNSObjectRelease(CFAllocatorRef allocator, const void *value);
OmniFoundation_EXTERN CFStringRef OFNSObjectCopyDescription(const void *value);
OmniFoundation_EXTERN CFStringRef OFNSObjectCopyShortDescription(const void *value);
OmniFoundation_EXTERN Boolean     OFNSObjectIsEqual(const void *value1, const void *value2);
OmniFoundation_EXTERN CFHashCode  OFNSObjectHash(const void *value1);

// Callbacks for CFTypeRefs (should usually be interoperable with NSObject, but not always)
OmniFoundation_EXTERN const void *OFCFTypeRetain(CFAllocatorRef allocator, const void *value);
OmniFoundation_EXTERN void        OFCFTypeRelease(CFAllocatorRef allocator, const void *value);
OmniFoundation_EXTERN CFStringRef OFCFTypeCopyDescription(const void *value);
OmniFoundation_EXTERN Boolean     OFCFTypeIsEqual(const void *value1, const void *value2);
OmniFoundation_EXTERN CFHashCode  OFCFTypeHash(const void *value);

// Callbacks for NSObjects responding to the OFWeakRetain protocol
OmniFoundation_EXTERN const void *OFNSObjectWeakRetain(CFAllocatorRef allocator, const void *value);
OmniFoundation_EXTERN void        OFNSObjectWeakRelease(CFAllocatorRef allocator, const void *value);

// Special purpose callbacks
OmniFoundation_EXTERN CFStringRef OFPointerCopyDescription(const void *ptr);
OmniFoundation_EXTERN CFStringRef OFIntegerCopyDescription(const void *ptr);
OmniFoundation_EXTERN CFStringRef OFUnsignedIntegerCopyDescription(const void *ptr);

OmniFoundation_EXTERN Boolean     OFCaseInsensitiveStringIsEqual(const void *value1, const void *value2);
OmniFoundation_EXTERN CFHashCode  OFCaseInsensitiveStringHash(const void *value);

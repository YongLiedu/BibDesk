// Copyright 2005-2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease_2007-10-25/OmniGroup/Frameworks/OmniFoundation/OpenStepExtensions.subproj/NSError-OFExtensions.h 93132 2007-10-20 21:45:55Z bungi $

#import <Foundation/NSError.h>

extern NSString *OFUserCancelledActionErrorKey;
extern NSString *OFFileNameAndNumberErrorKey;

@interface NSError (OFExtensions)
- (BOOL)causedByUserCancelling;
@end

extern void OFErrorv(NSError **error, NSString *domain, int code, const char *fileName, unsigned int line, NSString *firstKey, va_list args);
extern void _OFError(NSError **error, NSString *domain, int code, const char *fileName, unsigned int line, NSString *firstKey, ...);

// It is expected that -DOMNI_BUNDLE_IDENTIFIER=@"com.foo.bar" will be set when building your code.  Build configurations make this easy since you can set it in the target's configuration and then have your Other C Flags have -DOMNI_BUNDLE_IDENTIFIER=@\"$(OMNI_BUNDLE_IDENTIFIER)\" and also use $(OMNI_BUNDLE_IDENTIFIER) in your Info.plist instead of duplicating it.
#define OFError(error, code, description) _OFError(error, OMNI_BUNDLE_IDENTIFIER, code, __FILE__, __LINE__, NSLocalizedDescriptionKey, description, nil)
#define OFErrorWithInfo(error, code, ...) _OFError(error, OMNI_BUNDLE_IDENTIFIER, code, __FILE__, __LINE__, ## __VA_ARGS__)

// Unlike the other routines in this file, but like all the other Foundation routines, this takes its key-value pairs with each value followed by its key.  The disadvantage to this is that you can't easily have runtime-ignored values (the nil value is a terminator rather than being skipped).
void OFErrorWithErrnoObjectsAndKeys(NSError **error, int errno_value, const char *function, NSString *argument, NSString *localizedDescription, ...);
#define OFErrorWithErrno(error, errno_value, function, argument, localizedDescription) OFErrorWithErrnoObjectsAndKeys(error, errno_value, function, argument, localizedDescription, nil)

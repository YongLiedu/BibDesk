// Copyright 2005-2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "NSError-OFExtensions.h"

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease_2007-10-25/OmniGroup/Frameworks/OmniFoundation/OpenStepExtensions.subproj/NSError-OFExtensions.m 93132 2007-10-20 21:45:55Z bungi $");

NSString *OFUserCancelledActionErrorKey = OMNI_BUNDLE_IDENTIFIER @".ErrorDomain.ErrorDueToUserCancel";
NSString *OFFileNameAndNumberErrorKey = OMNI_BUNDLE_IDENTIFIER @".ErrorDomain.FileLineAndNumber";

static NSMutableDictionary *_createUserInfo(NSString *firstKey, va_list args)
{
    NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];

    NSString *key = firstKey;
    while (key) { // firstKey might be nil
	id value = va_arg(args, id);
	[userInfo setValue:value forKey:key];
	key = va_arg(args, id);
    }
    
    return userInfo;
}

@implementation NSError (OFExtensions)

/*" Returns YES if the receiver or any of its underlying errors has a user info key of OFUserCancelledActionErrorKey with a boolean value of YES.  Under 10.4 and higher, this also returns YES if the receiver or any of its underlying errors has the domain NSCocoaErrorDomain and code NSUserCancelledError (see NSResponder.h). "*/
- (BOOL)causedByUserCancelling;
{
    NSError *error = self;
    while (error) {
	NSDictionary *userInfo = [error userInfo];
	if ([[userInfo valueForKey:OFUserCancelledActionErrorKey] boolValue])
	    return YES;
	
#if defined(MAC_OS_X_VERSION_10_4) && MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_4
	// TJW: There is also NSUserCancelledError in 10.4.  See NSResponder.h -- it says NSApplication will bail on presenting the error if the domain is NSCocoaErrorDomain and code is NSUserCancelledError.  It's unclear if NSApplication checks the whole chain (question open on cocoa-dev as of 2005/09/29).
	if ([[error domain] isEqualToString:NSCocoaErrorDomain] && [error code] == NSUserCancelledError)
	    return YES;
#endif
	
	error = [userInfo valueForKey:NSUnderlyingErrorKey];
    }
    return NO;
}

@end

void OFErrorWithDomainv(NSError **error, NSString *domain, int code, const char *fileName, unsigned int line, NSString *firstKey, va_list args)
{
    OBPRECONDITION(error); // Must supply a error pointer or this is pointless (since it is in-out)
    
    NSMutableDictionary *userInfo = _createUserInfo(firstKey, args);
    
    // Add in the previous error, if there was one
    if (*error) {
	OBASSERT(![userInfo valueForKey:NSUnderlyingErrorKey]); // Don't pass NSUnderlyingErrorKey in the varargs to this macro, silly!
	[userInfo setValue:*error forKey:NSUnderlyingErrorKey];
    }
    
    // Add in file and line information if the file was supplied
    if (fileName) {
	NSString *fileString = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:fileName length:strlen(fileName)];
	[userInfo setValue:[fileString stringByAppendingFormat:@":%d", line] forKey:OFFileNameAndNumberErrorKey];
    }
    
    *error = [NSError errorWithDomain:domain code:code userInfo:userInfo];
    [userInfo release];
}

/*" Convenience function, invoked by the OFError macro, that allows for creating error objects with user info objects without creating a dictionary object.  The keys and values list must be terminated with a nil key. "*/
void _OFError(NSError **error, NSString *domain, int code, const char *fileName, unsigned int line, NSString *firstKey, ...)
{
    OBPRECONDITION(![NSString isEmptyString:domain]);
    
    va_list args;
    va_start(args, firstKey);
    OFErrorWithDomainv(error, domain, code, fileName, line, firstKey, args);
    va_end(args);
    [domain release];
}

void OFErrorWithErrnoObjectsAndKeys(NSError **error, int errno_value, const char *function, NSString *argument, NSString *localizedDescription, ...)
{
    if (!error)
        return;
    
    NSMutableString *description = [[NSMutableString alloc] init];
    if (function)
        [description appendFormat:@"%s: ", function];
    if (argument) {
        [description appendString:argument];
        [description appendString:@": "];
    }
    [description appendFormat:@"%s", strerror(errno_value)];
    
    NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
    [userInfo setObject:description forKey:NSLocalizedFailureReasonErrorKey];
    [description release];
    if (localizedDescription)
        [userInfo setObject:localizedDescription forKey:NSLocalizedDescriptionKey];
    
    va_list kvargs;
    va_start(kvargs, localizedDescription);
    for(;;) {
        NSObject *anObject = va_arg(kvargs, NSObject *);
        if (!anObject)
            break;
        NSString *aKey = va_arg(kvargs, NSString *);
        if (!aKey) {
            NSLog(@"*** OFErrorWithErrnoObjectsAndKeys(..., %s, %@, ...) called with an odd number of varargs!", function, localizedDescription);
            break;
        }
        [userInfo setObject:anObject forKey:aKey];
    }
    va_end(kvargs);
    
    *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno_value userInfo:userInfo];
    [userInfo release];
}


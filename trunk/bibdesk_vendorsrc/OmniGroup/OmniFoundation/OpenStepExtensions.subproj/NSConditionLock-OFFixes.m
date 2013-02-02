// Copyright 2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <Foundation/NSLock.h>
#import <OmniBase/OmniBase.h>

#import "NSDate-OFExtensions.h"

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease_2007-10-25/OmniGroup/Frameworks/OmniFoundation/OpenStepExtensions.subproj/NSConditionLock-OFFixes.m 91717 2007-09-22 00:26:44Z kc $")

@implementation NSConditionLock (OFFixes)

static BOOL (*originalLockWhenConditionBeforeDate)(id self, SEL _cmd, int condition, NSDate *limit);

+ (void)performPosing;
{
    originalLockWhenConditionBeforeDate = (typeof(originalLockWhenConditionBeforeDate))OBReplaceMethodImplementationWithSelector(self, @selector(lockWhenCondition:beforeDate:), @selector(replacement_lockWhenCondition:beforeDate:));
}

#define LIMIT_DATE_ACCURACY 0.1

- (BOOL)replacement_lockWhenCondition:(int)condition beforeDate:(NSDate *)limitDate;
{
    do {
        BOOL locked = originalLockWhenConditionBeforeDate(self, _cmd, condition, limitDate);
        if (locked)
            return YES; // We have the lock

        NSTimeInterval limitDateInterval = [limitDate timeIntervalSinceNow];
        if (limitDateInterval <= 0.0)
            return NO; // Timeout reached

        // We woke up too early (which is the whole reason we need this patch).  Let's try an alternate means of sleeping:  -[NSDate(OFExtensions) sleepUntilDate] (which calls +[NSThread sleepUntilDate:]).
#ifdef DEBUG_kc
        NSLog(@"%@: Woke up %5.3f (%g) seconds too early, sleeping until %@", [self shortDescription], limitDateInterval, limitDateInterval, limitDate);
#endif

        if (limitDateInterval < LIMIT_DATE_ACCURACY) {
            // We're close to the first event's date, let's only sleep until that precise date.
            [limitDate sleepUntilDate];
        } else {
            // We woke up much earlier than we'd like.  Let's sleep for a little while before we check our condition again
            [[NSDate dateWithTimeIntervalSinceNow:LIMIT_DATE_ACCURACY] sleepUntilDate];
        }
    } while (1);
}

@end

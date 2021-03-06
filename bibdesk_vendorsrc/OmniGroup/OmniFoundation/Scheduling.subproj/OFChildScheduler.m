// Copyright 1999-2005, 2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OFChildScheduler.h"

#import "OFScheduledEvent.h"

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease_2007-10-25/OmniGroup/Frameworks/OmniFoundation/Scheduling.subproj/OFChildScheduler.m 93428 2007-10-25 16:36:11Z kc $")

@implementation OFChildScheduler

// Init and dealloc

- initWithParentScheduler:(OFScheduler *)aParent;
{
    if ([super init] == nil)
        return nil;
    parent = [aParent retain];
    return self;
}


- (void)dealloc;
{
    [self cancelScheduledEvents];
    [parent release];
    [super dealloc];
}


// OFScheduler subclass

- (void)invokeScheduledEvents;
{
    [scheduleLock lock];
    [parentAlarmEvent release];
    parentAlarmEvent = nil;
    [scheduleLock unlock];
    [super invokeScheduledEvents];
}

- (void)scheduleEvents;
{
    NSDate *dateOfFirstEvent;

    [scheduleLock lock];
    // Reschedule with parent
    [self cancelScheduledEvents];
    dateOfFirstEvent = [self dateOfFirstEvent];
    if (dateOfFirstEvent != nil) {
        OBASSERT(parentAlarmEvent == nil);
        parentAlarmEvent = [[parent scheduleSelector:@selector(invokeScheduledEvents) onObject:self withObject:nil atDate:dateOfFirstEvent] retain];
    }
    [scheduleLock unlock];
}

- (void)cancelScheduledEvents;
{
    [scheduleLock lock];
    if (parentAlarmEvent != nil) {
        [parent abortEvent:parentAlarmEvent];
        [parentAlarmEvent release];
        parentAlarmEvent = nil;
    }
    [scheduleLock unlock];
}

// OBObject subclass

- (NSMutableDictionary *)debugDictionary;
{
    NSMutableDictionary *debugDictionary;

    debugDictionary = [super debugDictionary];
    if (parent != nil)
        [debugDictionary setObject:[parent shortDescription] forKey:@"parent"];
    if (parentAlarmEvent != nil)
        [debugDictionary setObject:parentAlarmEvent forKey:@"parentAlarmEvent"];

    return debugDictionary;
}

@end

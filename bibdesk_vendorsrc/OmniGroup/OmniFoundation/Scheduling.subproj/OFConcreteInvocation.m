// Copyright 1997-2003 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// http://www.omnigroup.com/DeveloperResources/OmniSourceLicense.html.

#import "OFConcreteInvocation.h"

#import <Foundation/Foundation.h>
#import <OmniBase/OmniBase.h>

RCS_ID("$Header: /Network/Source/CVS/OmniGroup/Frameworks/OmniFoundation/Scheduling.subproj/OFConcreteInvocation.m,v 1.15 2003/01/15 22:52:01 kc Exp $")

#import <OmniFoundation/OFMessageQueuePriorityProtocol.h>

@implementation OFConcreteInvocation

// Init and dealloc

+ alloc;
{
    // +[OFInvocation alloc] returns a temporary placeholder, so here we override +alloc to act normally again.

    return [self allocWithZone:NULL];
}

+ allocWithZone:(NSZone *)aZone;
{
    return NSAllocateObject(self, 0, aZone);
}

- initForObject:(id <NSObject>)targetObject;
{
    OBPRECONDITION(targetObject != nil); // since we are going to dereference it below

    [super init];
    object = [targetObject retain];

    // Note that it's perfectly legal to respond to just some and not all.
    flags.objectRespondsToPriority = [object respondsToSelector:@selector(priority)];
    flags.objectRespondsToGroup = [object respondsToSelector:@selector(group)];
    flags.objectRespondsToMaximumSimultaneousThreadsInGroup = [object respondsToSelector:@selector(maximumSimultaneousThreadsInGroup)];
    
    return self;
}

- (void)dealloc;
{
    [object release];
    [super dealloc];
}


// OFInvocation subclass

- (id <NSObject>)object;
{
    return object;
}

// OFMessageQueuePriority protocol

- (unsigned int)priority;
{
    if (flags.objectRespondsToPriority)
        return [(id <OFMessageQueuePriority>)object priority];
    else
        return OFMediumPriority;
}

- (unsigned int)group;
{
    if (flags.objectRespondsToGroup)
        return [(id <OFMessageQueuePriority>)object group];
    else
        return OFInvocationNoGroup;
}

- (unsigned int)maximumSimultaneousThreadsInGroup;
{
    if (flags.objectRespondsToMaximumSimultaneousThreadsInGroup)
        return [(id <OFMessageQueuePriority>)object maximumSimultaneousThreadsInGroup];
    else
        return INT_MAX;
}

@end


#import "OFIObjectNSInvocation.h"
#import "OFIObjectSelector.h"
#import "OFIObjectSelectorBool.h"
#import "OFIObjectSelectorInt.h"
#import "OFIObjectSelectorIntInt.h"
#import "OFIObjectSelectorObject.h"
#import "OFIObjectSelectorObjectObject.h"
#import "OFIObjectSelectorObjectObjectObject.h"

@implementation OFInvocation (Inits)

- initForObject:(id <NSObject>)targetObject nsInvocation:(NSInvocation *)anInvocation;
{
    return [[OFIObjectNSInvocation alloc] initForObject:targetObject nsInvocation:anInvocation];
}

- initForObject:(id <NSObject>)targetObject selector:(SEL)aSelector;
{
    return [[OFIObjectSelector alloc] initForObject:targetObject selector:aSelector];
}

- initForObject:(id <NSObject>)targetObject selector:(SEL)aSelector withBool:(BOOL)aBool;
{
    return [[OFIObjectSelectorBool alloc] initForObject:targetObject selector:aSelector withBool:aBool];
}

- initForObject:(id <NSObject>)targetObject selector:(SEL)aSelector withInt:(int)anInt;
{
    return [[OFIObjectSelectorInt alloc] initForObject:targetObject selector:aSelector withInt:anInt];
}

- initForObject:(id <NSObject>)targetObject selector:(SEL)aSelector withInt:(int)anInt withInt:(int)anotherInt;
{
    return [[OFIObjectSelectorIntInt alloc] initForObject:targetObject selector:aSelector withInt:anInt withInt:anotherInt];
}

- initForObject:(id <NSObject>)targetObject selector:(SEL)aSelector withObject:(id <NSObject>)aWithObject;
{
    return [[OFIObjectSelectorObject alloc] initForObject:targetObject selector:aSelector withObject:aWithObject];
}

- initForObject:(id <NSObject>)targetObject selector:(SEL)aSelector withObject:(id <NSObject>)object1 withObject:(id <NSObject>)object2;
{
    return [[OFIObjectSelectorObjectObject alloc] initForObject:targetObject selector:aSelector withObject:object1 withObject:object2];
}

- initForObject:(id <NSObject>)targetObject selector:(SEL)aSelector withObject:(id <NSObject>)object1 withObject:(id <NSObject>)object2 withObject:(id <NSObject>)object3;
{
    return [[OFIObjectSelectorObjectObjectObject alloc] initForObject:targetObject selector:aSelector withObject:object1 withObject:object2 withObject:object3];
}

@end

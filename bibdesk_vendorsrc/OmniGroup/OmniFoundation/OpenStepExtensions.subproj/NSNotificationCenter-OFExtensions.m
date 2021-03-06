// Copyright 1998-2005, 2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniFoundation/NSNotificationCenter-OFExtensions.h>

#import "OFObject-Queue.h"

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease_2007-10-25/OmniGroup/Frameworks/OmniFoundation/OpenStepExtensions.subproj/NSNotificationCenter-OFExtensions.m 93428 2007-10-25 16:36:11Z kc $")

@implementation NSNotificationCenter (OFExtensions)

- (void)addObserver:(id)observer selector:(SEL)aSelector name:(NSString *)aName objects:(NSArray *)objects;
{
    unsigned int objectIndex;

    objectIndex = [objects count];
    while (objectIndex--)
        [self addObserver:observer selector:aSelector name:aName object:[objects objectAtIndex:objectIndex]];
}

- (void)removeObserver:(id)observer name:(NSString *)aName objects:(NSArray *)objects;
{
    unsigned int objectIndex;

    objectIndex = [objects count];
    while (objectIndex--)
        [self removeObserver:observer name:aName object:[objects objectAtIndex:objectIndex]];
}

- (void)mainThreadPostNotificationName:(NSString *)aName object:(id)anObject;
    // Asynchronously post a notification in the main thread
{
    [self mainThreadPerformSelector:@selector(postNotificationName:object:) withObject:aName withObject:anObject];
}

- (void)mainThreadPostNotificationName:(NSString *)aName object:(id)anObject userInfo:(NSDictionary *)aUserInfo;
    // Asynchronously post a notification in the main thread
{
    [self mainThreadPerformSelector:@selector(postNotificationName:object:userInfo:) withObject:aName withObject:anObject withObject:aUserInfo];
}

@end

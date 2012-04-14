// Copyright 1997-2005, 2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OFIObjectSelectorBool.h"

#import <objc/objc-class.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease_2007-10-25/OmniGroup/Frameworks/OmniFoundation/Scheduling.subproj/OFIObjectSelectorBool.m 90130 2007-08-15 07:15:53Z bungi $")

@implementation OFIObjectSelectorBool;

static Class myClass;

+ (void)initialize;
{
    OBINITIALIZE;
    myClass = self;
}

- initForObject:(id)anObject selector:(SEL)aSelector withBool:(BOOL)aBool;
{
    OBPRECONDITION([anObject respondsToSelector:aSelector]);

    [super initForObject:anObject selector:aSelector];

    theBool = aBool;

    return self;
}

- (void)invoke;
{
    Class cls = OB_object_getClass(object);
    Method method = class_getInstanceMethod(cls, selector);
    if (!method)
        [NSException raise:NSInvalidArgumentException format:@"%s(0x%x) does not respond to the selector %@", OB_class_getName(cls), (unsigned)object, NSStringFromSelector(selector)];

    OB_method_getImplementation(method)(object, selector, theBool);
}

- (unsigned int)hash;
{
    return (unsigned int)object + (unsigned int)(void *)selector + (unsigned int)theBool;
}

- (BOOL)isEqual:(id)anObject;
{
    OFIObjectSelectorBool *otherObject;

    otherObject = anObject;
    if (OB_object_getClass(otherObject) != myClass)
	return NO;
    return object == otherObject->object && selector == otherObject->selector && theBool == otherObject->theBool;
}

- (NSMutableDictionary *)debugDictionary;
{
    NSMutableDictionary *debugDictionary;

    debugDictionary = [super debugDictionary];
    if (object)
	[debugDictionary setObject:object forKey:@"object"];
    [debugDictionary setObject:NSStringFromSelector(selector) forKey:@"selector"];
    [debugDictionary setObject:theBool ? @"YES" : @"NO" forKey:@"theBool"];

    return debugDictionary;
}

- (NSString *)shortDescription;
{
    return [NSString stringWithFormat:@"-[%@ %@%d]", OBShortObjectDescription(object), NSStringFromSelector(selector), theBool ? @"YES" : @"NO"];
}

@end

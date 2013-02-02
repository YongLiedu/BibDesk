// Copyright 1997-2005, 2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OFIObjectSelectorObjectObjectObject.h"

#import <objc/objc-class.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease_2007-10-25/OmniGroup/Frameworks/OmniFoundation/Scheduling.subproj/OFIObjectSelectorObjectObjectObject.m 90130 2007-08-15 07:15:53Z bungi $")

@implementation OFIObjectSelectorObjectObjectObject;

static Class myClass;

+ (void)initialize;
{
    OBINITIALIZE;
    myClass = self;
}

- initForObject:(id)targetObject selector:(SEL)aSelector withObject:(id)anObject1 withObject:(id)anObject2 withObject:(id)anObject3;
{
    OBPRECONDITION([targetObject respondsToSelector:aSelector]);

    [super initForObject:targetObject selector:aSelector];

    object1 = [anObject1 retain];
    object2 = [anObject2 retain];
    object3 = [anObject3 retain];

    return self;
}

- (void)dealloc;
{
    [object1 release];
    [object2 release];
    [object3 release];
    [super dealloc];
}

- (void)invoke;
{
    Class cls = OB_object_getClass(object);
    Method method = class_getInstanceMethod(cls, selector);
    if (!method)
        [NSException raise:NSInvalidArgumentException format:@"%s(0x%x) does not respond to the selector %@", OB_class_getName(cls), (unsigned)object, NSStringFromSelector(selector)];

    OB_method_getImplementation(method)(object, selector, object1, object2, object3);
}

- (unsigned int)hash;
{
    return (unsigned int)object + (unsigned int)(void *)selector + (unsigned int)object1 + (unsigned int)object2 + (unsigned int)object3;
}

- (BOOL)isEqual:(id)anObject;
{
    OFIObjectSelectorObjectObjectObject *otherObject;

    otherObject = anObject;
    if (OB_object_getClass(otherObject) != myClass)
        return NO;
    return object == otherObject->object && selector == otherObject->selector && object1 == otherObject->object1 && object2 == otherObject->object2 && object3 == otherObject->object3;
}

- (NSMutableDictionary *)debugDictionary;
{
    NSMutableDictionary *debugDictionary;

    debugDictionary = [super debugDictionary];
    if (object)
        [debugDictionary setObject:object forKey:@"object"];
    [debugDictionary setObject:NSStringFromSelector(selector) forKey:@"selector"];
    if (object1)
        [debugDictionary setObject:object1 forKey:@"object1"];
    if (object2)
        [debugDictionary setObject:object2 forKey:@"object2"];
    if (object3)
        [debugDictionary setObject:object3 forKey:@"object3"];

    return debugDictionary;
}

- (NSString *)shortDescription;
{
    return [NSString stringWithFormat:@"-[%@ %@(%@,%@,%@)]", OBShortObjectDescription(object), NSStringFromSelector(selector), OBShortObjectDescription(object1), OBShortObjectDescription(object2), OBShortObjectDescription(object3)];
}

@end

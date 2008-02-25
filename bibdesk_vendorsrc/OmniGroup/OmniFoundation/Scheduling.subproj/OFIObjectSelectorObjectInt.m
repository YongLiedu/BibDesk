// Copyright 2003-2005, 2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OFIObjectSelectorObjectInt.h"

#import <objc/objc-class.h>
#import <OmniFoundation/NSMutableDictionary-OFExtensions.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease_2007-10-25/OmniGroup/Frameworks/OmniFoundation/Scheduling.subproj/OFIObjectSelectorObjectInt.m 90130 2007-08-15 07:15:53Z bungi $")

@implementation OFIObjectSelectorObjectInt

- initForObject:(id)targetObject selector:(SEL)aSelector withObject:(id)anObject withInt:(int)anInt;
{
    OBPRECONDITION([targetObject respondsToSelector:aSelector]);

    [super initForObject:targetObject selector:aSelector];

    withObject = [anObject retain];
    theInt = anInt;

    return self;
}

- (void)dealloc;
{
    [withObject release];
    [super dealloc];
}

- (void)invoke;
{
    Class cls = OB_object_getClass(object);
    Method method = class_getInstanceMethod(cls, selector);
    if (!method)
        [NSException raise:NSInvalidArgumentException format:@"%s(0x%x) does not respond to the selector %@", OB_class_getName(cls), (unsigned)object, NSStringFromSelector(selector)];

    OB_method_getImplementation(method)(object, selector, withObject, theInt);
}

- (unsigned int)hash;
{
    return (unsigned int)object + (unsigned int)(void *)selector + (unsigned int)withObject + (unsigned int)theInt;
}

- (BOOL)isEqual:(id)anObject;
{
    OFIObjectSelectorObjectInt *otherObject;

    otherObject = anObject;
    if (OB_object_getClass(otherObject) != isa)
        return NO;
    return object == otherObject->object && selector == otherObject->selector && withObject == otherObject->withObject && theInt == otherObject->theInt;
}

- (NSMutableDictionary *)debugDictionary;
{
    NSMutableDictionary *debugDictionary;

    debugDictionary = [super debugDictionary];
    if (object)
        [debugDictionary setObject:object forKey:@"object"];
    [debugDictionary setObject:NSStringFromSelector(selector) forKey:@"selector"];
    if (withObject)
        [debugDictionary setObject:withObject forKey:@"withObject"];
    [debugDictionary setIntValue:theInt forKey:@"theInt"];

    return debugDictionary;
}

- (NSString *)shortDescription;
{
    return [NSString stringWithFormat:@"-[%@ %@(%@,%d)]", OBShortObjectDescription(object), NSStringFromSelector(selector), OBShortObjectDescription(withObject), theInt];
}

@end

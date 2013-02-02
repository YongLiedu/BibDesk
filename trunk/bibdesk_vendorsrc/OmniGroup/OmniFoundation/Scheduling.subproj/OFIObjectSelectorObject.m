// Copyright 1997-2005, 2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OFIObjectSelectorObject.h"

#import <objc/objc-class.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease_2007-10-25/OmniGroup/Frameworks/OmniFoundation/Scheduling.subproj/OFIObjectSelectorObject.m 90130 2007-08-15 07:15:53Z bungi $")

@implementation OFIObjectSelectorObject;

static Class myClass;

+ (void)initialize;
{
    OBINITIALIZE;
    myClass = self;
}

- initForObject:(id)anObject selector:(SEL)aSelector withObject:(id)aWithObject;
{
    OBPRECONDITION([anObject respondsToSelector:aSelector]);
    
    [super initForObject:anObject selector:aSelector];

    withObject = [aWithObject retain];

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
    
    OB_method_getImplementation(method)(object, selector, withObject);
}

- (unsigned int)hash;
{
    return (unsigned int)object + (unsigned int)(void *)selector + (unsigned int)withObject;
}

- (BOOL)isEqual:(id)anObject;
{
    OFIObjectSelectorObject *otherObject = anObject;
    if (otherObject == self)
	return YES;
    if (OB_object_getClass(otherObject) != myClass)
	return NO;
    return object == otherObject->object &&
	   selector == otherObject->selector &&
	   withObject == otherObject->withObject;
}

- (NSMutableDictionary *)debugDictionary;
{
    NSMutableDictionary *debugDictionary;

    debugDictionary = [super debugDictionary];
    if (object)
	[debugDictionary setObject:OBShortObjectDescription(object) forKey:@"object"];
    [debugDictionary setObject:NSStringFromSelector(selector) forKey:@"selector"];
    if (withObject)
	[debugDictionary setObject:OBShortObjectDescription(withObject) forKey:@"withObject"];

    return debugDictionary;
}

- (NSString *)shortDescription;
{
    return [NSString stringWithFormat:@"-[%@ %@%@]", OBShortObjectDescription(object), NSStringFromSelector(selector), OBShortObjectDescription(withObject)];
}

@end

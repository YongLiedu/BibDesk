// Copyright 2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Frameworks/OmniBase/OBPostLoader.m 81954 2006-12-01 18:40:08Z bungi $

#import <objc/objc.h>
#import <objc/objc-class.h>
#import <objc/objc-runtime.h>
#import <AvailabilityMacros.h>
#import <Foundation/NSObjCRuntime.h>

// Compatibility for new Objective-C 2 API that isn't present on 10.4.
#if !defined(MAC_OS_X_VERSION_10_5) || MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_5

// New types for Leopard; don't explode if they leak into the frameworks early
typedef int NSInteger;
typedef unsigned int NSUInteger;

#import <OmniBase/assertions.h>
#import <stdlib.h>

static inline Class object_getClass(id object) { return object->isa; }

static inline Class class_getSuperclass(Class cls) { return cls->super_class; }
static inline const char *class_getName(Class cls) { return cls->name; }
static inline BOOL class_isMetaClass(Class cls) { return (CLS_GETINFO(cls, CLS_META) != 0); }
static inline size_t class_getInstanceSize(Class cls) { return cls->instance_size; }

static inline SEL method_getName(Method m) { return m->method_name; }
static inline IMP method_getImplementation(Method m) { return m->method_imp; }
static inline const char *method_getTypeEncoding(Method m) { return m->method_types; }
static inline IMP method_setImplementation(Method m, IMP newImp) {
    IMP oldImp = m->method_imp;
    m->method_imp = newImp;
    return oldImp;
}
static inline Method *class_copyMethodList(Class cls, unsigned int *outCount)
{
    if (cls == Nil)
        return NULL; // so sayeth the documentation
    
    Method *list = NULL;
    unsigned int total = 0;
    
    void *iterator = NULL;
    struct objc_method_list *mlist;
    
    while ((mlist = class_nextMethodList(cls, &iterator))) {
        int methodIndex, methodCount = mlist->method_count;
        if (methodCount == 0)
            continue;
        
        struct objc_method *methods = &mlist->method_list[0];

        unsigned int newTotal = total + methodCount;
        list = (Method *)realloc(list, sizeof(*list)*newTotal);
        
        for (methodIndex = 0; methodIndex < methodCount; methodIndex++)
            list[total+methodIndex] = &methods[methodIndex];

        total = newTotal;
    }

    if (outCount)
        *outCount = total;
    
    OBPOSTCONDITION((total == 0) == (list == NULL)); // documentation says this function returns NULL if there are no instance methods on the class
    return list;
}

// Returns NO on failure; documentation says this can happen if there is a pre-existing method with this name.
static inline BOOL class_addMethod(Class cls, SEL name, IMP imp, const char *types)
{
    struct objc_method_list *newMethodList;
    
    newMethodList = (struct objc_method_list *) NSZoneMalloc(NSDefaultMallocZone(), sizeof(struct objc_method_list));
    
    newMethodList->method_count = 1;
    newMethodList->method_list[0].method_name = name;
    newMethodList->method_list[0].method_imp = imp;
    newMethodList->method_list[0].method_types = (char *)types;
    
    class_addMethods(cls, newMethodList);
    return YES;
}


static inline BOOL sel_isEqual(SEL a, SEL b) { return a == b; }

#endif

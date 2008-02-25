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
#if !defined(MAC_OS_X_VERSION_10_5) || MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_5

// New types for Leopard; don't explode if they leak into the frameworks early
// From NSObjCRuntime.h
#ifndef NSINTEGER_DEFINED
typedef int NSInteger;
typedef unsigned int NSUInteger;
#define NSIntegerMax    LONG_MAX
#define NSIntegerMin    LONG_MIN
#define NSUIntegerMax   ULONG_MAX
#define NSINTEGER_DEFINED 1
#endif /* NSINTEGER_DEFINED */


#import <OmniBase/assertions.h>
#import <stdlib.h>

static inline Class OB_object_getClass(id object) { return object->isa; }

static inline Class OB_class_getSuperclass(Class cls) { return cls->super_class; }
static inline const char *OB_class_getName(Class cls) { return cls->name; }
static inline BOOL OB_class_isMetaClass(Class cls) { return (CLS_GETINFO(cls, CLS_META) != 0); }
static inline size_t OB_class_getInstanceSize(Class cls) { return cls->instance_size; }

static inline SEL OB_method_getName(Method m) { return m->method_name; }
static inline IMP OB_method_getImplementation(Method m) { return m->method_imp; }
static inline const char *OB_method_getTypeEncoding(Method m) { return m->method_types; }
static inline IMP OB_method_setImplementation(Method m, IMP newImp) {
    IMP oldImp = m->method_imp;
    m->method_imp = newImp;
    return oldImp;
}
static inline Method *OB_class_copyMethodList(Class cls, unsigned int *outCount)
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
static inline BOOL OB_class_addMethod(Class cls, SEL name, IMP imp, const char *types)
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

static inline BOOL OB_sel_isEqual(SEL a, SEL b) { return a == b; }


#elif MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_5


#import <OmniBase/assertions.h>

static inline Class OB_object_getClass(id object) { return object_getClass != NULL ? object_getClass(object) : object->isa; }

static inline Class OB_class_getSuperclass(Class cls) { return class_getSuperclass != NULL ? class_getSuperclass(cls) : cls->super_class; }
static inline const char *OB_class_getName(Class cls) { return class_getName != NULL ? class_getName(cls) : cls->name; }
static inline BOOL OB_class_isMetaClass(Class cls) { return class_isMetaClass != NULL ? class_isMetaClass(cls) : (CLS_GETINFO(cls, CLS_META) != 0); }
static inline size_t OB_class_getInstanceSize(Class cls) { return class_getInstanceSize != NULL ? class_getInstanceSize(cls) : (size_t)cls->instance_size; }

static inline SEL OB_method_getName(Method m) { return method_getName != NULL ? method_getName(m) : m->method_name; }
static inline IMP OB_method_getImplementation(Method m) { return method_getImplementation != NULL ? method_getImplementation(m) : m->method_imp; }
static inline const char *OB_method_getTypeEncoding(Method m) { return method_getTypeEncoding != NULL ? method_getTypeEncoding(m) : m->method_types; }
static inline IMP OB_method_setImplementation(Method m, IMP newImp) {
    if (method_setImplementation != NULL) {
        return method_setImplementation (m, newImp);
    } else {
        IMP oldImp = m->method_imp;
        m->method_imp = newImp;
        return oldImp;
    }
}
static inline Method *OB_class_copyMethodList(Class cls, unsigned int *outCount)
{
    if (class_copyMethodList != NULL) {
        return class_copyMethodList(cls, outCount);
    } else {
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
}

// Returns NO on failure; documentation says this can happen if there is a pre-existing method with this name.
static inline BOOL OB_class_addMethod(Class cls, SEL name, IMP imp, const char *types)
{
    if (class_addMethod != NULL) {
        return class_addMethod(cls, name, imp, types);
    } else {
        struct objc_method_list *newMethodList;
        
        newMethodList = (struct objc_method_list *) NSZoneMalloc(NSDefaultMallocZone(), sizeof(struct objc_method_list));
        
        newMethodList->method_count = 1;
        newMethodList->method_list[0].method_name = name;
        newMethodList->method_list[0].method_imp = imp;
        newMethodList->method_list[0].method_types = (char *)types;
        
        class_addMethods(cls, newMethodList);
        return YES;
    }
}

static inline BOOL OB_sel_isEqual(SEL a, SEL b) { return sel_isEqual != NULL ? sel_isEqual(a, b) : a == b; }


#else


static inline Class OB_object_getClass(id object) { return object_getClass(object); }

static inline Class OB_class_getSuperclass(Class cls) { return class_getSuperclass(cls); }
static inline const char *OB_class_getName(Class cls) { return class_getName(cls); }
static inline BOOL OB_class_isMetaClass(Class cls) { return class_isMetaClass(cls); }
static inline size_t OB_class_getInstanceSize(Class cls) { return class_getInstanceSize(cls); }
static inline Method *OB_class_copyMethodList(Class cls, unsigned int *outCount) { return class_copyMethodList(cls, outCount); }
static inline BOOL OB_class_addMethod(Class cls, SEL name, IMP imp, const char *types) { return class_addMethod(cls, name, imp, types); }

static inline SEL OB_method_getName(Method m) { return method_getName(m); }
static inline IMP OB_method_getImplementation(Method m) { return method_getImplementation(m); }
static inline const char *OB_method_getTypeEncoding(Method m) { return method_getTypeEncoding(m); }
static inline IMP OB_method_setImplementation(Method m, IMP newImp) { return method_setImplementation(m, newImp); }

static inline BOOL OB_sel_isEqual(SEL a, SEL b) { return sel_isEqual(a, b); }


#endif

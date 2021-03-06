// Copyright 1997-2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniBase/OBUtilities.h>

#import <Foundation/Foundation.h>
#import <objc/objc-runtime.h>

#import <OmniBase/assertions.h>
#import <OmniBase/rcsid.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease_2007-10-25/OmniGroup/Frameworks/OmniBase/OBUtilities.m 89466 2007-08-01 23:35:13Z kc $")

static BOOL _OBRegisterMethod(IMP imp, Class cls, const char *types, SEL name)
{
    return OB_class_addMethod(cls, name, imp, types);
}

IMP OBRegisterInstanceMethodWithSelector(Class aClass, SEL oldSelector, SEL newSelector)
{
    Method thisMethod;
    IMP oldImp = NULL;

    if ((thisMethod = class_getInstanceMethod(aClass, oldSelector))) {
        oldImp = OB_method_getImplementation(thisMethod);
        _OBRegisterMethod(oldImp, aClass, OB_method_getTypeEncoding(thisMethod), newSelector);
    }

    return oldImp;
}

IMP OBReplaceMethodImplementation(Class aClass, SEL oldSelector, IMP newImp)
{
    Method localMethod, superMethod;
    IMP oldImp = NULL;
    extern void _objc_flush_caches(Class);

    if ((localMethod = class_getInstanceMethod(aClass, oldSelector))) {
	oldImp = OB_method_getImplementation(localMethod);
        Class superCls = OB_class_getSuperclass(aClass);
	superMethod = superCls ? class_getInstanceMethod(superCls, oldSelector) : NULL;

	if (superMethod == localMethod) {
	    // We are inheriting this method from the superclass.  We do *not* want to clobber the superclass's Method as that would replace the implementation on a greater scope than the caller wanted.  In this case, install a new method at this class and return the superclass's implementation as the old implementation (which it is).
	    _OBRegisterMethod(newImp, aClass, OB_method_getTypeEncoding(localMethod), oldSelector);
	} else {
	    // Replace the method in place
#ifdef OMNI_ASSERTIONS_ON
            IMP previous = 
#endif
            OB_method_setImplementation(localMethod, newImp);
            OBASSERT(oldImp == previous); // OB_method_setImplementation is supposed to return the old implementation, but we already grabbed it.
	}
	
#if !defined(MAC_OS_X_VERSION_10_5) || MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_5
	// Flush the method cache
	if (_objc_flush_caches != NULL)
        _objc_flush_caches(aClass);
#endif
    }

    return oldImp;
}

IMP OBReplaceMethodImplementationWithSelector(Class aClass, SEL oldSelector, SEL newSelector)
{
    Method newMethod = class_getInstanceMethod(aClass, newSelector);
    OBASSERT(newMethod);
    
    return OBReplaceMethodImplementation(aClass, oldSelector, OB_method_getImplementation(newMethod));
}

IMP OBReplaceMethodImplementationWithSelectorOnClass(Class destClass, SEL oldSelector, Class sourceClass, SEL newSelector)
{
    Method newMethod = class_getInstanceMethod(sourceClass, newSelector);
    OBASSERT(newMethod);

    return OBReplaceMethodImplementation(destClass, oldSelector, OB_method_getImplementation(newMethod));
}

// Returns the class in the inheritance chain of 'cls' that actually implements the given selector, or Nil if it isn't implemented
Class OBClassImplementingMethod(Class cls, SEL sel)
{
    Method method = class_getInstanceMethod(cls, sel);
    if (!method)
	return Nil;

    // *Some* class must implement it
    Class superClass;
    while ((superClass = OB_class_getSuperclass(cls))) {
	Method superMethod = class_getInstanceMethod(superClass, sel);
	if (superMethod != method)
	    return cls;
	cls = superClass;
    }
    
    return cls;
}


void OBRequestConcreteImplementation(id self, SEL _cmd)
{
    OBASSERT_NOT_REACHED("Concrete implementation needed");
    [NSException raise:OBAbstractImplementation format:@"%@ needs a concrete implementation of %c%s", [self class], OBPointerIsClass(self) ? '+' : '-', sel_getName(_cmd)];
    exit(1);  // notreached, but needed to pacify the compiler
}

void OBRejectUnusedImplementation(id self, SEL _cmd)
{
    OBASSERT_NOT_REACHED("Subclass rejects unused implementation");
    [NSException raise:OBUnusedImplementation format:@"%c[%@ %s] should not be invoked", OBPointerIsClass(self) ? '+' : '-', OBClassForPointer(self), sel_getName(_cmd)];
    exit(1);  // notreached, but needed to pacify the compiler
}

void _OBRejectInvalidCall(id self, SEL _cmd, const char *file, unsigned int line, NSString *format, ...)
{
    const char *className = OB_class_getName(OBClassForPointer(self));
    const char *methodName = sel_getName(_cmd);
    
    va_list argv;
    va_start(argv, format);
    NSString *complaint = [[NSString alloc] initWithFormat:format arguments:argv];
    va_end(argv);
    
#ifdef DEBUG
    fprintf(stderr, "Invalid call on:\n%s:%d\n", file, line);
#endif
    
    NSString *reasonString = [NSString stringWithFormat:@"%c[%s %s] (%s:%d) %@", OBPointerIsClass(self) ? '+' : '-', className, methodName, file, line, complaint];
    [complaint release];
    [[NSException exceptionWithName:NSInvalidArgumentException reason:reasonString userInfo:nil] raise];
    exit(1);  // notreached, but needed to pacify the compiler
}

DEFINE_NSSTRING(OBAbstractImplementation);
DEFINE_NSSTRING(OBUnusedImplementation);

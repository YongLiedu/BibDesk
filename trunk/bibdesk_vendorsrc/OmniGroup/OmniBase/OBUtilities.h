// Copyright 1997-2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease_2007-10-25/OmniGroup/Frameworks/OmniBase/OBUtilities.h 92219 2007-10-02 23:39:09Z wiml $

#import <Foundation/NSString.h>

#import <objc/objc.h>
#import <objc/objc-class.h>
#import <objc/objc-runtime.h>
#import <OmniBase/FrameworkDefines.h>
#import <OmniBase/assertions.h>
#import <OmniBase/objc.h>

#if defined(__GNUC__)
#define NORETURN __attribute__ ((noreturn))
#else
#define NORETURN
#endif

OmniBase_EXTERN void OBRequestConcreteImplementation(id self, SEL _cmd) NORETURN;
OmniBase_EXTERN void OBRejectUnusedImplementation(id self, SEL _cmd) NORETURN;
OmniBase_EXTERN void _OBRejectInvalidCall(id self, SEL _cmd, const char *file, unsigned int line, NSString *format, ...) NORETURN;
#define OBRejectInvalidCall(self, sel, format, ...) _OBRejectInvalidCall((self), (sel), __FILE__, __LINE__, (format), ## __VA_ARGS__)

OmniBase_EXTERN NSString *OBAbstractImplementation;
OmniBase_EXTERN NSString *OBUnusedImplementation;


#undef NORETURN

OmniBase_EXTERN IMP OBRegisterInstanceMethodWithSelector(Class aClass, SEL oldSelector, SEL newSelector);
/*.doc.
Provides the same functionality as +[NSObject registerInstanceMethod:withMethodTypes:forSelector: but does it without provoking +initialize on the target class.  Returns the original implementation.
*/

OmniBase_EXTERN IMP OBReplaceMethodImplementation(Class aClass, SEL oldSelector, IMP newImp);
/*.doc.
Replaces the given method implementation in place.  Returns the old implementation.
*/

OmniBase_EXTERN IMP OBReplaceMethodImplementationWithSelector(Class aClass, SEL oldSelector, SEL newSelector);
/*.doc.
Calls the above, but determines newImp by looking up the instance method for newSelector.  Returns the old implementation.
*/

OmniBase_EXTERN IMP OBReplaceMethodImplementationWithSelectorOnClass(Class destClass, SEL oldSelector, Class sourceClass, SEL newSelector);
/*.doc.
Calls OBReplaceMethodImplementation.  Derives newImp from newSelector on sourceClass and changes method implementation for oldSelector on destClass.
*/

OmniBase_EXTERN Class OBClassImplementingMethod(Class cls, SEL sel);

// This returns YES if the given pointer is a class object
static inline BOOL OBPointerIsClass(id object)
{
    if (object) {
        Class cls = OB_object_getClass(object);
        return OB_class_isMetaClass(cls);
    }
    return NO;
}

// This returns the class object for the given pointer.  For an instance, that means getting the class.  But for a class object, that means returning the pointer itself 

static inline Class OBClassForPointer(id object)
{
    if (!object)
	return object;

    if (OBPointerIsClass(object))
	return object;
    else
	return object->isa;
}

static inline BOOL OBClassIsSubclassOfClass(Class subClass, Class superClass)
{
    while (subClass) {
        if (subClass == superClass)
            return YES;
        else
            subClass = OB_class_getSuperclass(subClass);
    }
    return NO;
}

// This macro ensures that we call [super initialize] in our +initialize (since this behavior is necessary for some classes in Cocoa), but it keeps custom class initialization from executing more than once.
#define OBINITIALIZE \
    do { \
        static BOOL hasBeenInitialized = NO; \
        [super initialize]; \
        if (hasBeenInitialized) \
            return; \
        hasBeenInitialized = YES;\
    } while (0);

    
#ifdef USING_BUGGY_CPP_PRECOMP
// Versions of cpp-precomp released before April 2002 have a bug that makes us have to do this
#define NSSTRINGIFY(name) @ ## '"' ## name ## '"'
#elif defined(__GNUC__)
    #if __GNUC__ < 3 || (__GNUC__ == 3 && __GNUC_MINOR__ < 3)
        // GCC before 3.3 requires this format
        #define NSSTRINGIFY(name) @ ## #name
    #else
        // GCC 3.3 requires this format
        #define NSSTRINGIFY(name) @#name
    #endif
#endif

// An easy way to define string constants.  For example, "NSSTRINGIFY(foo)" produces @"foo" and "DEFINE_NSSTRING(foo);" produces: NSString *foo = @"foo";

#define DEFINE_NSSTRING(name) \
	NSString *name = NSSTRINGIFY(name)

// Emits a warning indicating that an obsolete method has been called.

#define OB_WARN_OBSOLETE_METHOD \
    do { \
        static BOOL warned = NO; \
            if (!warned) { \
                warned = YES; \
                    NSLog(@"Warning: obsolete method %c[%@ %s] invoked", OBPointerIsClass(self)?'+':'-', OBClassForPointer(self), _cmd); \
            } \
            OBASSERT_NOT_REACHED("obsolete method called"); \
    } while(0)

/*
 * only certain compilers support __attribute__((deprecated))
 * Apple has a similar definition but it's too inclusive
 */
#if defined(MAC_OS_X_VERSION_10_5) && defined(MAC_OS_X_VERSION_MIN_REQUIRED) && defined(__GNUC__) && ((__GNUC__ >= 4) || ((__GNUC__ == 3) && (__GNUC_MINOR__ >= 1))) && (MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_5)
#define OB_DEPRECATED_ATTRIBUTE __attribute__((deprecated))
#else
#define OB_DEPRECATED_ATTRIBUTE
#endif


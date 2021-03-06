// Copyright 1998-2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniFoundation/OFController.h>

#import <OmniBase/system.h>
#import <ExceptionHandling/NSExceptionHandler.h>

#import "OFObject-Queue.h"
#import "NSString-OFExtensions.h"
#import "NSThread-OFExtensions.h"
#import "NSData-OFExtensions.h"

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease_2007-10-25/OmniGroup/Frameworks/OmniFoundation/OFController.m 90706 2007-09-04 22:12:04Z bungi $")


// The following exception can be raised during an OFControllerRequestsTerminateNotification.

@interface OFController (PrivateAPI)
- (void)_makeObserversPerformSelector:(SEL)aSelector;
- (NSArray *)_observersSnapshot;
- (NSString *)_copyNumericBacktraceString;
@end

/*" OFController is used to represent the current state of the application and to receive notifications about changes in that state. "*/
@implementation OFController

static OFController *sharedController = nil;

#ifdef OMNI_ASSERTIONS_ON
static void _OFControllerCheckTerminated(void)
{
    // Make sure that applications that use OFController actually call its -willTerminate.
    OBASSERT(sharedController->status == OFControllerTerminatingStatus || sharedController->status == OFControllerNotInitializedStatus);
}
#endif

+ (void)initialize;
{
    OBPRECONDITION([NSThread inMainThread]);
    
    OBINITIALIZE;
    
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSDictionary *infoDictionary = [mainBundle infoDictionary];
    NSString *controllerClassName = [infoDictionary objectForKey:@"OFControllerClass"];
    Class controllerClass;
    if ([NSString isEmptyString:controllerClassName])
        controllerClass = self;
    else {
        controllerClass = NSClassFromString(controllerClassName);
        if (controllerClass == Nil) {
            NSLog(@"OFController: no such class \"%@\"", controllerClassName);
            controllerClass = self;
        }
    }
    
    OBASSERT(sharedController == nil);
    
    sharedController = [controllerClass alloc]; // Special case; make sure assignment happens before call to -init
    sharedController = [sharedController init];
#ifdef DEBUG_neo
    NSLog(@"sharedController=%@", sharedController);
#endif
}
    
+ (id)sharedController;
{
    return sharedController;
}

- (id)init;
{
    OBPRECONDITION([NSThread inMainThread]);
    
    // Ensure that +sharedController and nib loading produce a single instance
    OBPRECONDITION([self class] == [[OFController sharedController] class]); // Need to set OFControllerClass otherwise
    
    if (self == sharedController) {
	if ([super init] == nil)
	    return nil;
	
	NSExceptionHandler *handler = [NSExceptionHandler defaultExceptionHandler];
	[handler setDelegate:self];
#ifdef DEBUG
	[handler setExceptionHandlingMask:NSLogUncaughtExceptionMask|NSLogUncaughtSystemExceptionMask|NSLogUncaughtRuntimeErrorMask|NSLogTopLevelExceptionMask|NSLogOtherExceptionMask];
#else
        [handler setExceptionHandlingMask:NSLogUncaughtExceptionMask|NSLogUncaughtSystemExceptionMask|NSLogUncaughtRuntimeErrorMask|NSLogTopLevelExceptionMask];
#endif
        
	// NSAssertionHandler's documentation says this is the way to customize assertion handling
	[[[NSThread currentThread] threadDictionary] setObject:self forKey:@"NSAssertionHandler"];
	
	observerLock = [[NSLock alloc] init];
	status = OFControllerNotInitializedStatus;
	observers = [[NSMutableArray alloc] init];
	postponingObservers = [[NSMutableSet alloc] init];
        
#ifdef OMNI_ASSERTIONS_ON
        atexit(_OFControllerCheckTerminated);
#endif
        
	return self;
    } else {
	[self release];
	return [[OFController sharedController] retain];
    }
}

- (void)dealloc;
{
    OBPRECONDITION([NSThread inMainThread]);

    [observers release];
    [postponingObservers release];
    
    [super dealloc];
}

- (OFControllerStatus)status;
{
    OBPRECONDITION([NSThread inMainThread]);

    return status;
}

/*" Subscribes the observer to a set of notifications based on the methods that it implements in the OFControllerObserver informal protocol.  Classes can register for these notifications in their +didLoad methods (and those +didLoad methods probably shouldn't do much else, since defaults aren't yet registered during +didLoad). "*/
- (void)addObserver:(id <OFWeakRetain>)observer;
{
    OBPRECONDITION(observer != nil);
    
    [observerLock lock];
    
    [observers addObject:observer];
    [observer incrementWeakRetainCount];
    
    [observerLock unlock];
}


/*" Unsubscribes the observer to a set of notifications based on the methods that it implements in the OFControllerObserver informal protocol. "*/
- (void)removeObserver:(id <OFWeakRetain>)observer;
{
    [observerLock lock];
    
    [observers removeObject:observer];
    [observer decrementWeakRetainCount];
    
    [observerLock unlock];
}


/*" The application should call this once after it is initialized.  In AppKit applications, this should be called from -applicationWillFinishLaunching:. "*/
- (void)didInitialize;
{
    OBPRECONDITION([NSThread inMainThread]);
    OBPRECONDITION(status == OFControllerNotInitializedStatus);
    
    status = OFControllerInitializedStatus;
    [self _makeObserversPerformSelector:@selector(controllerDidInitialize:)];
}

/*" The application should call this once after calling -didInitialize.  In AppKit applications, this should be called from -applicationDidFinishLaunching:. "*/
- (void)startedRunning;
{
    OBPRECONDITION([NSThread inMainThread]);
    OBPRECONDITION(status == OFControllerInitializedStatus);
    
    status = OFControllerRunningStatus;
    [self _makeObserversPerformSelector:@selector(controllerStartedRunning:)];
}
    
/*" The application should call this when a termination request has been received.  If YES is returned, the termination can proceed (i.e., the caller should call -willTerminate) next. "*/
- (OFControllerTerminateReply)requestTermination;
{
    OBPRECONDITION([NSThread inMainThread]);
    OBPRECONDITION(status == OFControllerRunningStatus);
    
    status = OFControllerRequestingTerminateStatus;

    NSArray *observersSnapshot = [self _observersSnapshot];    
    unsigned int observerCount = [observersSnapshot count];
    unsigned int observerIndex;
    
    for (observerIndex = 0; observerIndex < observerCount; observerIndex++) {
        id anObserver = [observersSnapshot objectAtIndex:observerIndex];
        if ([anObserver respondsToSelector:@selector(controllerRequestsTerminate:)]) {
            NS_DURING {
                [anObserver controllerRequestsTerminate:self];
            } NS_HANDLER {
                NSLog(@"Ignoring exception raised during %s[%@ controllerRequestsTerminate:]: %@", OBPointerIsClass(anObserver) ? "+" : "-", OBShortObjectDescription(anObserver), [localException reason]);
            } NS_ENDHANDLER;
        }
        
        // Break if the termination was cancelled
        if (status == OFControllerRunningStatus)
            break;
    }

    if (status != OFControllerRunningStatus && [postponingObservers count] > 0)
        status = OFControllerPostponingTerminateStatus;

    switch (status) {
        case OFControllerRunningStatus:
            return OFControllerTerminateCancel;
        case OFControllerRequestingTerminateStatus:
            status = OFControllerTerminatingStatus;
            return OFControllerTerminateNow;
        case OFControllerPostponingTerminateStatus:
            return OFControllerTerminateLater;
        default:
            OBASSERT_NOT_REACHED("Can't return from OFControllerRunningStatus to an earlier state");
            return OFControllerTerminateNow;
    }
}

/*" This method can be called during a -controllerRequestsTerminate: method when an object wishes to cancel the termination (typically in response to a user pressing the "Cancel" button on a Save panel). "*/
- (void)cancelTermination;
{
    OBPRECONDITION([NSThread inMainThread]);
    
    switch (status) {
        case OFControllerRequestingTerminateStatus:
            status = OFControllerRunningStatus;
            break;
        case OFControllerPostponingTerminateStatus:
            [self gotPostponedTerminateResult:NO];
            status = OFControllerRunningStatus;
            break;
        default:
            break;
    }
}

- (void)postponeTermination:(id)observer;
{
    OBPRECONDITION([NSThread inMainThread]);

    [postponingObservers addObject:observer];
}

- (void)continuePostponedTermination:(id)observer;
{
    OBPRECONDITION([NSThread inMainThread]);
    OBPRECONDITION([postponingObservers containsObject:observer]);
    
    [postponingObservers removeObject:observer];
    if ([postponingObservers count] == 0) {
        [self gotPostponedTerminateResult:(status != OFControllerRunningStatus)];
    } else if ((status == OFControllerRequestingTerminateStatus || status == OFControllerPostponingTerminateStatus || status == OFControllerTerminatingStatus)) {
        [self _makeObserversPerformSelector:@selector(controllerRequestsTerminate:)];
    }
}

/*" The application should call this method when it is going to terminate and there is no chance of cancelling it (i.e., after it has called -requestTermination and a YES has been returned). "*/
- (void)willTerminate;
{
    OBPRECONDITION([NSThread inMainThread]);
    OBPRECONDITION(status == OFControllerTerminatingStatus); // We should have requested termination and not had it cancelled or postponed.
    
    [self _makeObserversPerformSelector:@selector(controllerWillTerminate:)];
}

- (void)gotPostponedTerminateResult:(BOOL)isReadyToTerminate;
{
    OBRequestConcreteImplementation(self, _cmd);
}

- (NSString *)copySymbolicBacktrace;
{
    NSString *numericTrace = [self _copyNumericBacktraceString];
    NSString *symbolicTrace = [self copySymbolicBacktraceForNumericBacktrace:numericTrace];
    [numericTrace release];
    return symbolicTrace;
}

- (NSString *)copySymbolicBacktraceForNumericBacktrace:(NSString *)numericTrace;
{
    // atos is in the developer tools package, so it might not be present
    NSString *atosPath = @"/usr/bin/atos";
    if (![[NSFileManager defaultManager] isExecutableFileAtPath:atosPath])
	return [numericTrace copy];
    
    NSString *outputString;
    @try {
        NSError *error = nil;
        NSData *inputData = [numericTrace dataUsingEncoding:NSUTF8StringEncoding];
        NSData *outputData = [inputData filterDataThroughCommandAtPath:atosPath
                                                         withArguments:[NSArray arrayWithObjects:@"-p", [NSString stringWithFormat:@"%u", getpid()], nil]
                                                 includeErrorsInOutput:YES
                                                           errorStream:nil
                                                                 error:&error];
        
        if (!outputData) {
            outputString = [[error description] copy]; // for now, just return something for the result
        } else {
            outputString = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];
            if (!outputString) {
                outputString = [[NSString alloc] initWithFormat:@"Unable to convert output data to UTF-8:\n%@", outputData];
            }
        }
    } @catch (NSException *exc) {
        // This method can get called for unhandled exceptions, so let's not have any.
        outputString = [[NSString alloc] initWithFormat:@"Exception raised while converting numeric backtrace: %@\n%@", numericTrace, exc];
    }
    
    return outputString;
}

#pragma mark -
#pragma mark NSAssertionHandler replacement

- (void)handleFailureInMethod:(SEL)selector object:(id)object file:(NSString *)fileName lineNumber:(int)line description:(NSString *)format,...;
{
    va_list args;
    va_start(args, format);
    [self handleFailureInMethod:selector object:object file:fileName lineNumber:line format:format arguments:args];
    va_end(args);
}

- (void)handleFailureInFunction:(NSString *)functionName file:(NSString *)fileName lineNumber:(int)line description:(NSString *)format,...;
{
    va_list args;
    va_start(args, format);
    [self handleFailureInFunction:functionName file:fileName lineNumber:line format:format arguments:args];
    va_end(args);
}

// The real stuff is here so that subclassers can override these points instead of the '...' versions (which make it impossible to call super w/o silly contortions).
- (void)handleFailureInMethod:(SEL)selector object:(id)object file:(NSString *)fileName lineNumber:(int)line format:(NSString *)format arguments:(va_list)args;
{
    static BOOL handlingAssertion = NO;
    if (handlingAssertion)
	return; // Skip since we apparently screwed up
    handlingAssertion = YES;
    {
	NSString *numericTrace = [self _copyNumericBacktraceString];
	NSString *symbolicTrace = [self copySymbolicBacktraceForNumericBacktrace:numericTrace];
	[numericTrace release];
        
	NSString *description = [[NSString alloc] initWithFormat:format arguments:args];
	
	NSLog(@"Assertion Failed:\n---------------------------\nObject: %@\nSelector: %@\nFile: %@\nLine: %d\nDescription: %@\nStack Trace:\n%@\n---------------------------",
	      OBShortObjectDescription(object), NSStringFromSelector(selector), fileName, line, description, symbolicTrace);
	[description release];
	[symbolicTrace release];
    }
    handlingAssertion = NO;
}

- (void)handleFailureInFunction:(NSString *)functionName file:(NSString *)fileName lineNumber:(int)line format:(NSString *)format arguments:(va_list)args;
{
    static BOOL handlingAssertion = NO;
    if (handlingAssertion)
	return; // Skip since we apparently screwed up
    handlingAssertion = YES;
    {
	NSString *symbolicTrace = [self copySymbolicBacktrace];
	
	NSString *description = [[NSString alloc] initWithFormat:format arguments:args];
	
	NSLog(@"Assertion Failed:\n---------------------------\nFunction: %@\nFile: %@\nLine: %d\nDescription: %@\nStack Trace:\n%@\n---------------------------",
	      functionName, fileName, line, description, symbolicTrace);
	[description release];
	[symbolicTrace release];
    }
    handlingAssertion = NO;
}

#pragma mark -
#pragma mark NSExceptionHandler delegate

static NSString *OFControllerAssertionHandlerException = @"OFControllerAssertionHandlerException";

- (BOOL)exceptionHandler:(NSExceptionHandler *)sender shouldLogException:(NSException *)exception mask:(unsigned int)aMask;
{
    if (([sender exceptionHandlingMask] & aMask) == 0)
	return NO;
    
    // We might invoke OmniCrashCatcher later, but in a mode where it just dumps the info and doesn't reap us.  If we did we would get a list of all the Mach-O files loaded, for example.  This can be important when the exception is due to some system hack installed.  But, for now we'll do something fairly simple.  For now, we don't present this to the user, but at least it gets in the log file.  Once we have that level of reporting working well, we can start presenting to the user.
    
    static BOOL handlingException = NO;
    if (handlingException) {
	NSLog(@"Exception handler delegate called recursively!");
	return YES; // Let the normal handler do it since we apparently screwed up
    }
    
    if ([[exception name] isEqualToString:OFControllerAssertionHandlerException])
	return NO; // We are collecting the backtrace for some random purpose
	    
    NSString *numericTrace = [[exception userInfo] objectForKey:NSStackTraceKey];
    if ([NSString isEmptyString:numericTrace])
	return YES; // huh?
    
    handlingException = YES;
    {
	NSString *symbolicTrace = [self copySymbolicBacktraceForNumericBacktrace:numericTrace];
	NSLog(@"Exception raised:\n---------------------------\nMask: 0x%08x\nName: %@\nReason: %@\nStack Trace:\n%@\n---------------------------",
	      aMask, [exception name], [exception reason], symbolicTrace);
	[symbolicTrace release];
    }
    handlingException = NO;
    return NO; // we already did
}

@end


@implementation OFController (PrivateAPI)

- (void)_makeObserversPerformSelector:(SEL)aSelector;
{
    OBPRECONDITION([NSThread inMainThread]);
    
    NSArray *observersSnapshot = [self _observersSnapshot];
    unsigned int observerCount = [observersSnapshot count];
    unsigned int observerIndex;
    
    for (observerIndex = 0; observerIndex < observerCount; observerIndex++) {
        id anObserver = [observersSnapshot objectAtIndex:observerIndex];
        if ([anObserver respondsToSelector:aSelector]) {
            // NSLog(@"Calling %s[%@ %s]", OBPointerIsClass(anObserver) ? "+" : "-", OBShortObjectDescription(anObserver), aSelector);
            NS_DURING {
                [anObserver performSelector:aSelector withObject:self];
            } NS_HANDLER {
                NSLog(@"Ignoring exception raised during %s[%@ %@]: %@", OBPointerIsClass(anObserver) ? "+" : "-", OBShortObjectDescription(anObserver), NSStringFromSelector(aSelector), [localException reason]);
            } NS_ENDHANDLER;
        }
    }
}

- (NSArray *)_observersSnapshot;
{
    OBPRECONDITION([NSThread inMainThread]);

    [observerLock lock];
    NSMutableArray *observersSnapshot = [[NSMutableArray alloc] initWithArray:observers];
    [observerLock unlock];

    return [observersSnapshot autorelease];
}

- (NSString *)_copyNumericBacktraceString;
{
    NSString *backtrace = nil;
    
    // This is a hack since there is no public API to get this.  Our exception logging code ignores this exception
    @try {
	[NSException raise:OFControllerAssertionHandlerException format:@"getting backtrace"];
    } @catch(NSException *exc) {
	backtrace = [[[exc userInfo] objectForKey:NSStackTraceKey] copy];
    }
    return backtrace;
}

@end


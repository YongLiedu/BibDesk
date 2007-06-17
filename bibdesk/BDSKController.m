//
//  BDSKController.m
//  Bibdesk
//
//  Created by Adam Maxwell on 11/12/06.
/*
 This software is Copyright (c) 2006,2007
 Adam Maxwell. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 - Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in
 the documentation and/or other materials provided with the
 distribution.
 
 - Neither the name of Adam Maxwell nor the names of any
 contributors may be used to endorse or promote products derived
 from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "BDSKController.h"
#import <ExceptionHandling/NSExceptionHandler.h>
#import "BDSKReadMeController.h"
#import "BDSKShellTask.h"
#import <unistd.h>

@interface NSException (BDSKExtensions)
- (NSString *)stackTrace;
@end

@interface BDSKStandardErrorLog : NSObject
{
    NSMutableData *stderrData;
    pthread_rwlock_t stderrLock;
}
+ (id)sharedLog;
- (void)startWatching;
- (NSString *)standardErrorString;
@end

@implementation BDSKController

- (id)init;
{
    log_method();
    self = [super init];
    // Omni adds NSLogOtherExceptionMask for debug builds, which logs complex string exceptions
    [[NSExceptionHandler defaultExceptionHandler] setExceptionHandlingMask:NSLogUncaughtExceptionMask|NSLogUncaughtSystemExceptionMask|NSLogUncaughtRuntimeErrorMask|NSLogTopLevelExceptionMask];
    // start copying standard error
    [BDSKStandardErrorLog sharedLog];
    return self;
}

// copied from superclass' implementation
static NSString *OFControllerAssertionHandlerException = @"OFControllerAssertionHandlerException";

// we override this OFController method in order to display a window with the stack trace

- (BOOL)exceptionHandler:(NSExceptionHandler *)sender shouldLogException:(NSException *)exception mask:(unsigned int)aMask;
{
    if (([sender exceptionHandlingMask] & aMask) == 0 || [[NSUserDefaults standardUserDefaults] boolForKey:@"BDSKDisableExceptionHandling"])
        return NO;
        
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
#if OMNI_FORCE_ASSERTIONS
    // log so it's easy to spot in the console, but don't display the exception viewer window
    NSLog(@"%@", [NSString stringWithFormat:@"**** Exception:\n%@\n\n **** Stack Trace:\n%@\n ****", exception, [exception stackTrace]]);
#else
    [[BDSKExceptionViewer sharedViewer] performSelectorOnMainThread:@selector(displayString:) withObject:[NSString stringWithFormat:@"Exception:\n%@\n\nStack Trace:\n%@\n\nStandard Error:\n%@", exception, [exception stackTrace], [[BDSKStandardErrorLog sharedLog] standardErrorString]] waitUntilDone:YES];
#endif
    handlingException = NO;
    
    return NO; // we already did
}


@end

@implementation NSException (BDSKExtensions)

- (NSString *)stackTrace;
{
    // copied from Apple's exception handling docs
    NSString *stack = [[self userInfo] objectForKey:NSStackTraceKey];
    
    // unfortunately, atos is part of the Developer tools, so we get a crash when executing it if it's not present; how does CrashReporter get symbolic traces, then?
    if (stack && [[NSFileManager defaultManager] isExecutableFileAtPath:@"/usr/bin/atos"]) {
        NSString *pid = [[NSNumber numberWithInt:getpid()] stringValue];
        NSMutableArray *args = [NSMutableArray arrayWithCapacity:20];
        
        [args addObject:@"-p"];
        [args addObject:pid];
        [args addObjectsFromArray:[stack componentsSeparatedByString:@"  "]];
        // Note: function addresses are separated by double spaces, not a single space.
        
        @try {
            stack = [BDSKShellTask executeBinary:@"/usr/bin/atos" inDirectory:nil withArguments:args environment:nil inputString:nil];
        }
        @catch (id exception) {
            NSLog(@"caught %@ while getting stack trace from %@", exception, self);
            stack = [NSString stringWithFormat:@"caught \"%@\" while running atos on stack trace\n%@", exception, [[self userInfo] objectForKey:NSStackTraceKey]];
        }
    } else if (stack == nil) {
        stack = [NSString stringWithFormat:@"No stack trace for exception %@", self];
    }
    return stack;
}
@end

@implementation BDSKStandardErrorLog

+ (id)sharedLog;
{
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"BDSKDisableStandardErrorCapture"])
        return nil;
    
    static id sharedInstance = nil;
    @synchronized(@"BDSKStandardErrorLog") {
        if (nil == sharedInstance)
            sharedInstance = [[self alloc] init];
    }
    return sharedInstance;
}

- (id)init
{
    self = [super init];
    if (self) {
        pthread_rwlock_init(&stderrLock, NULL);
        stderrData = [[NSMutableData alloc] initWithCapacity:8192];
        [NSThread detachNewThreadSelector:@selector(startWatching) toTarget:self withObject:nil];
    }
    return self;
}

- (oneway void)release {}

#define LOG_BUF_SIZE 1024

// see http://lists.apple.com/archives/cocoa-dev/2004/Jun/msg01395.html
- (void)startWatching;
{
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    int pipefds[2];
    char buf[LOG_BUF_SIZE];
    
    int error = pipe(pipefds);
    if (error < 0)
        perror("pipe() failed");
    
    error = dup2(pipefds[1], 2);
    if (error < 0)
        perror("dup2() failed");
        
    ssize_t bytesRead = error;

    while (bytesRead >= 0) {
        
        bytesRead = read(pipefds[0], buf, LOG_BUF_SIZE);

        if (bytesRead > 0) {
            pthread_rwlock_wrlock(&stderrLock);
            [stderrData appendBytes:buf length:bytesRead];
            pthread_rwlock_unlock(&stderrLock);
        }
    }
    [pool release];
}

- (NSString *)standardErrorString
{
    pthread_rwlock_rdlock(&stderrLock);
    NSString *str = [[NSString alloc] initWithData:stderrData encoding:NSUTF8StringEncoding];
    pthread_rwlock_unlock(&stderrLock);
    return [str autorelease];
}

@end
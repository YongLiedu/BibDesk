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
#import <asl.h>
#import <libkern/OSAtomic.h>

@interface NSException (BDSKExtensions)
- (NSString *)stackTrace;
@end

NSString *BDSKStandardErrorString(void);

@implementation BDSKController

- (id)init;
{
    self = [super init];
    // Omni adds NSLogOtherExceptionMask for debug builds, which logs complex string exceptions
    [[NSExceptionHandler defaultExceptionHandler] setExceptionHandlingMask:NSLogUncaughtExceptionMask|NSLogUncaughtSystemExceptionMask|NSLogUncaughtRuntimeErrorMask|NSLogTopLevelExceptionMask];
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
    [[BDSKExceptionViewer sharedViewer] performSelectorOnMainThread:@selector(displayString:) withObject:[NSString stringWithFormat:@"Exception:\n%@\n\nStack Trace:\n%@\n\nStandard Error:\n%@", exception, [exception stackTrace], BDSKStandardErrorString()] waitUntilDone:YES];
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

#define SENDER "BibDesk"
static BOOL isTiger = YES;

static NSString *tigerASLHackaround(void)
{
    static NSArray *args = nil;
    if (nil == args)
        args = [[NSArray alloc] initWithObjects:@"-k", @ASL_KEY_SENDER, @SENDER, @"-k", @ASL_KEY_UID, @"Neq", [NSString stringWithFormat:@"%d", getuid()], @"-k", @ASL_KEY_LEVEL, @"Nle", [NSString stringWithFormat:@"%d", ASL_LEVEL_DEBUG], nil];
    
    NSString *logString = nil;
    @try{
        logString = [BDSKShellTask executeBinary:@"/usr/bin/syslog" inDirectory:nil withArguments:args environment:nil inputString:nil];
    }
    @catch(id exception){
        logString = [NSString stringWithFormat:@"Caught exception \"%@\" when attempting to run /usr/bin/syslog.", exception];
    }
    return logString;
}

// formats an ASL message and appends it to the given mutable data
static void appendMessageToData(aslmsg msg, NSMutableData *stderrData)
{
    // constants for formatting the output as follows:
    // Mon Jun 18 18:14:31 2007	BibDesk[13255]	here's a log message from <BibDocument: 0x467e180>
    const char tab[1] = { '\t' };
    const char newline[1] = { '\n' };
    const char lb[1] = { '[' };
    const char rbTab[2] = { ']', '\t' };
    
    const char *val;
    
    val = asl_get(msg, ASL_KEY_TIME);
    if (NULL == val) val = "0";
        
    // Header definition of ASL_KEY_TIME says to see ctime(3), but the date string on Tiger is of the form "2007.06.18 16:31:42 UTC", which has nothing to do with ctime or any other time function I can find.  This is a crock.
    struct tm tm;
    memset(&tm, 0, sizeof(tm));
    time_t time;

    // %Z apparently requires "GMT" instead of "UTC", so omit it and force UTC with timegm().
    if (strptime(val, "%Y.%m.%d %H:%M:%S", &tm)) {
        time = timegm(&tm);
    } else {
        time = strtol(val, NULL, 0);
    }
    val = ctime(&time);
    if (NULL == val) val = "0";
    
    // ctime is documented as adding a newline, which is annoying to read
    [stderrData appendBytes:val length:(strlen(val) - 1)];
    [stderrData appendBytes:tab length:sizeof(tab)];
    
    val = asl_get(msg, ASL_KEY_SENDER);
    if (NULL == val) val = "Unknown";
    [stderrData appendBytes:val length:strlen(val)];
    [stderrData appendBytes:lb length:sizeof(lb)];
    
    val = asl_get(msg, ASL_KEY_PID);
    if (NULL == val) val = "-1";
    [stderrData appendBytes:val length:strlen(val)];
    [stderrData appendBytes:rbTab length:sizeof(rbTab)];
    
    val = asl_get(msg, ASL_KEY_MSG);
    if (NULL == val) val = "Empty log message";
    [stderrData appendBytes:val length:strlen(val)];
    [stderrData appendBytes:newline length:sizeof(newline)];
}

static Boolean disableASLLogging = TRUE;
    
NSString *BDSKStandardErrorString(void)
{
    // sadly, repeated calls to asl_search() seem to corrupt memory on 10.4.9 rdar://problem/5276522
    if (isTiger) return (disableASLLogging ? @"Re-enable ASL logging with `defaults write edu.ucsd.cs.mmccrack.bibdesk BDSKDisableASLLogging -bool FALSE`" : tigerASLHackaround());
    
    aslmsg query, msg;
    aslresponse response;
    
    query = asl_new(ASL_TYPE_QUERY);
    if (NULL == query)
        perror("asl_new");
    
    int err;
    
    err = asl_set_query(query, ASL_KEY_SENDER, SENDER, ASL_QUERY_OP_EQUAL);
    if (err != 0)
        perror("asl_set_query sender");
    
    const char *uid_string = [[NSString stringWithFormat:@"%d", getuid()] UTF8String];
    err = asl_set_query(query, ASL_KEY_UID, uid_string, ASL_QUERY_OP_EQUAL | ASL_QUERY_OP_NUMERIC);
    if (err != 0)
        perror("asl_set_query uid");
    
    const char *level_string = [[NSString stringWithFormat:@"%d", ASL_LEVEL_DEBUG] UTF8String];
    err = asl_set_query(query, ASL_KEY_LEVEL, level_string, ASL_QUERY_OP_LESS_EQUAL | ASL_QUERY_OP_NUMERIC);
    if (err != 0)
        perror("asl_set_query level");
    
    aslclient client = asl_open(SENDER, SENDER, ASL_OPT_NO_DELAY);
    asl_set_filter(client, ASL_FILTER_MASK_UPTO(ASL_LEVEL_DEBUG));
    
    response = asl_search(client, query);
    if (NULL == response)
        perror("asl_search");
    
    NSMutableData *stderrData = nil;
    NSString *stderrString = nil;
    
    @try {
        stderrData = [[NSMutableData alloc] initWithCapacity:1024];
                
        while (NULL != (msg = aslresponse_next(response))) {
            appendMessageToData(msg, stderrData);
        }
        
        if ([stderrData length])
            stderrString = [[[NSString alloc] initWithData:stderrData encoding:NSUTF8StringEncoding] autorelease];
        
    }
    @catch(id exception) {
        stderrString = [NSString stringWithFormat:@"Caught exception \"%@\" when attempting to read standard error log.", exception];
    }
    @finally {
        aslresponse_free(response);
        asl_free(query);
        asl_close(client);
        [stderrData release];
    }
    return stderrString;
}

// returns true if Gestalt() fails or if the major version is not 10
static BOOL isRunningTiger(void)
{
    long majorVersion;
    long minorVersion;
    OSStatus err;
    err = Gestalt(gestaltSystemVersionMajor, &majorVersion);
    if (noErr == err)
        Gestalt(gestaltSystemVersionMinor, &minorVersion);
    return (noErr != err || (10 == majorVersion && 4 == minorVersion));
}

static void *copyStandardErrorToASL(void *unused);
static int32_t continueLogging = 1;

__attribute__((constructor))
static void startASLThread(void)
{
    // avoid Cocoa in this function
    
    // make this check regardless, since it affects reading from the log
    isTiger = isRunningTiger();
    
// for debug builds, allow Xcode to display stderr, since we usually won't be calling for stderr logs from code anyway
#if(!OMNI_FORCE_ASSERTIONS)
    if (isTiger) {
        
        disableASLLogging = CFPreferencesGetAppBooleanValue(CFSTR("BDSKDisableASLLogging"), kCFPreferencesCurrentApplication, NULL);
        
        if (disableASLLogging) {
            asl_log(NULL, NULL, ASL_LEVEL_ERR, "%s", "*** Disabled ASL logging ***\n\nTo re-enable, use\n\t`defaults write edu.ucsd.cs.mmccrack.bibdesk BDSKDisableASLLogging -bool FALSE`\n");
        } else {
            
            // start copying standard error
            pthread_attr_t attr;
            pthread_attr_init(&attr);
            pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);
            pthread_t thread;
            
            pthread_create(&thread, &attr, &copyStandardErrorToASL, NULL);
            
            asl_log(NULL, NULL, ASL_LEVEL_ERR, "%s", "*** Enabled ASL logging ***\n\nTo disable, use\n\t`defaults write edu.ucsd.cs.mmccrack.bibdesk BDSKDisableASLLogging -bool TRUE`\n");
        }
    }
    
#endif
}

__attribute__((destructor))
static void stopASLThread(void)
{
    OSAtomicDecrement32Barrier(&continueLogging);
}

#define STACK_BUFFER_SIZE 2048

// This thread runs in order to catch relevant items written directly to stderr; NSLog & NSLogv are handled specially, so we can reformat their output to remove redundant information.
static void *copyStandardErrorToASL(void *unused)
{    
    int pipefds[2];
    
    if (pipe(pipefds) < 0) {
        perror("pipe");
        return NULL;
    }
    
    if (dup2(pipefds[1], STDERR_FILENO) < 0) {
        perror("dup2");
        return NULL;
    }
  
    // create a new client for this thread
    aslclient client = asl_open(SENDER, NULL, ASL_OPT_NO_DELAY);
    aslmsg m = asl_new(ASL_TYPE_MSG);
    asl_set(m, ASL_KEY_SENDER, SENDER);
    
    FILE *stream = fdopen(pipefds[0], "r");
    if (NULL == stream) {
        perror("fdopen");
        return NULL;
    }

    char *line, buf[STACK_BUFFER_SIZE];        
    
    // NSLogv() logs with priority LOG_ERR; note that if the level is too high, it won't show up in the console log
    while (continueLogging && NULL != (line = fgets(buf, sizeof(buf), stream)))
        asl_log(client, m, ASL_LEVEL_ERR, "%s", buf);
    
    fclose(stream);
    asl_free(m);
    asl_close(client);
    return NULL;
}

void BDSKLog(NSString *format, ...)
{
    va_list list;
    va_start(list, format);
    // this will be redefined as BDSKLogv
    NSLogv(format, list);
    va_end(list);
}

// override to avoid passing additional info in the message string, since ASL handles that for us
void BDSKLogv(NSString *format, va_list argList)
{

// we want to call the real NSLog if we're not on Tiger, or if ASL logging is disabled on Tiger
#ifdef NSLogv
#undef NSLogv
    if (NO == isTiger || TRUE == disableASLLogging) {
        NSLogv(format, argList);
        return;
    }
#endif
    
    NSString *logString = [[NSString alloc] initWithFormat:format arguments:argList];
    
    // create a new client since we may be calling this from an arbitrary thread
    aslclient client = asl_open(SENDER, NULL, ASL_OPT_NO_DELAY);
    
    aslmsg m = asl_new(ASL_TYPE_MSG);
    asl_set(m, ASL_KEY_SENDER, SENDER);
    
    char *buf;
    char stackBuf[STACK_BUFFER_SIZE];
    
    // nothing to prepend, since ASL takes care of that for us
    unsigned len = [logString maximumLengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    
    if (len < STACK_BUFFER_SIZE && [logString getCString:stackBuf maxLength:STACK_BUFFER_SIZE encoding:NSUTF8StringEncoding]) {
        buf = stackBuf;
    } else if (NULL != (buf = NSZoneMalloc(NULL, (len + 1) * sizeof(char))) ){
        [logString getCString:buf maxLength:(len + 1) encoding:NSUTF8StringEncoding];
    } else {
        asl_log(client, m, ASL_LEVEL_EMERG, "%s", "unable to allocate log buffer");
        abort();
    }
    [logString release];
    
    asl_log(client, m, ASL_LEVEL_ERR, "%s", buf);
    
    if (buf != stackBuf) NSZoneFree(NULL, buf);
    asl_free(m);
    asl_close(client);
}

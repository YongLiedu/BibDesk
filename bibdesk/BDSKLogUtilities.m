//
//  BDSKLogUtilities.m
//  Bibdesk
//
//  Created by Adam Maxwell on 06/19/07.
/*
 This software is Copyright (c) 2007-2009
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

#import "BDSKLogUtilities.h"
#import "NSTask_BDSKExtensions.h"
#import <unistd.h>
#import <asl.h>
#import <libkern/OSAtomic.h>
#import <pthread.h>

#define BDSK_ASL_SENDER "BibDesk"
#define BDSK_ASL_FACILITY NULL

static BOOL isTiger = YES;

@interface BDSKLogMessage : NSObject
{
    NSDate *date;
    NSString *message;
    NSString *sender;
    int pid;
    unsigned hash;
}
- (id)initWithASLMessage:(aslmsg)msg;
@end

static NSString *tigerASLHackaround(void)
{
    // find messages that we've logged
    NSArray *args  = [NSArray arrayWithObjects:@"-k", @ASL_KEY_SENDER, @BDSK_ASL_SENDER, @"-k", @ASL_KEY_UID, @"Neq", [NSString stringWithFormat:@"%d", getuid()], @"-k", @ASL_KEY_LEVEL, @"Nle", [NSString stringWithFormat:@"%d", ASL_LEVEL_DEBUG], @"-k", @ASL_KEY_TIME, @"ge", @"-24h", nil];
    
    NSString *logString = nil;
    @try{
        logString = [NSTask executeBinary:@"/usr/bin/syslog" inDirectory:nil withArguments:args environment:nil inputString:nil];
    }
    @catch(id exception){
        logString = [NSString stringWithFormat:@"Caught exception \"%@\" when attempting to run /usr/bin/syslog.", exception];
    }
    return logString;
}

static Boolean disableASLLogging = TRUE;

static int new_default_asl_query(aslmsg *newQuery)
{
    int err;
    aslmsg query;
    
    query = asl_new(ASL_TYPE_QUERY);
    if (NULL == query)
        perror("asl_new");
    
    const char *uid_string = [[NSString stringWithFormat:@"%d", getuid()] UTF8String];
    err = asl_set_query(query, ASL_KEY_UID, uid_string, ASL_QUERY_OP_EQUAL | ASL_QUERY_OP_NUMERIC);
    if (err != 0)
        perror("asl_set_query uid");
    
    const char *level_string = [[NSString stringWithFormat:@"%d", ASL_LEVEL_DEBUG] UTF8String];
    err = asl_set_query(query, ASL_KEY_LEVEL, level_string, ASL_QUERY_OP_LESS_EQUAL | ASL_QUERY_OP_NUMERIC);
    if (err != 0)
        perror("asl_set_query level");
    
    // limit to last 24 hours
    const char *time_string = [[NSString stringWithFormat:@"%fh", -24.0] UTF8String];
    err = asl_set_query(query, ASL_KEY_TIME, time_string, ASL_QUERY_OP_GREATER_EQUAL);
    if (err != 0)
        perror("asl_set_query time");
    
    *newQuery = query;
    
    return err;
}
    
NSString *BDSKStandardErrorString(void)
{
    // sadly, repeated calls to asl_search() seem to corrupt memory on 10.4.9 rdar://problem/5276522
    // this is fixed on 10.5, but will not be fixed on 10.4
#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_5
#warning Tiger ASL hack
#endif
    
    if (isTiger) return (disableASLLogging ? @"Re-enable ASL logging with `defaults write edu.ucsd.cs.mmccrack.bibdesk BDSKDisableASLLogging -bool FALSE`" : tigerASLHackaround());
    
    aslmsg query, msg;
    aslresponse response;
    
    int err;
        
    aslclient client = asl_open(BDSK_ASL_SENDER, BDSK_ASL_FACILITY, ASL_OPT_NO_DELAY);
    asl_set_filter(client, ASL_FILTER_MASK_UPTO(ASL_LEVEL_DEBUG));
    
    NSMutableSet *messages = [NSMutableSet set];
    NSString *stderrString = nil;
    
    @try {
        
        err = new_default_asl_query(&query);
        
        // search for anything with our sender name as substring; captures some system logging
        err = asl_set_query(query, ASL_KEY_MSG, BDSK_ASL_SENDER, ASL_QUERY_OP_CASEFOLD | ASL_QUERY_OP_SUBSTRING | ASL_QUERY_OP_EQUAL);
        if (err != 0)
            perror("asl_set_query message");
        
        response = asl_search(client, query);
        if (NULL == response)
            perror("asl_search");
        
        BDSKLogMessage *logMessage;
        
        while (NULL != (msg = aslresponse_next(response))) {
            logMessage = [[BDSKLogMessage alloc] initWithASLMessage:msg];
            if (logMessage)
                [messages addObject:logMessage];
            [logMessage release];
        }
        
        aslresponse_free(response);
        asl_free(query);
        
        err = new_default_asl_query(&query);
        
        // now search for messages that we've logged directly
        err = asl_set_query(query, ASL_KEY_SENDER, BDSK_ASL_SENDER, ASL_QUERY_OP_EQUAL);
        if (err != 0)
            perror("asl_set_query sender");
        
        response = asl_search(client, query);
        if (NULL == response)
            perror("asl_search");
        
        while (NULL != (msg = aslresponse_next(response))) {
            logMessage = [[BDSKLogMessage alloc] initWithASLMessage:msg];
            if (logMessage)
                [messages addObject:logMessage];
            [logMessage release];
        }
        
        // sort by date so we have a coherent list...
        NSArray *sortedMessages = [[messages allObjects] sortedArrayUsingSelector:@selector(compare:)];
        
        // sends -description to each object
        stderrString = [sortedMessages componentsJoinedByString:@"\n"];
    }
    @catch(id exception) {
        stderrString = [NSString stringWithFormat:@"Caught exception \"%@\" when attempting to read standard error log.", exception];
    }
    @finally {
        aslresponse_free(response);
        asl_free(query);
        asl_close(client);
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
        
        // log to the automatic client/message; we're thread safe here
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
    aslclient client = asl_open(BDSK_ASL_SENDER, BDSK_ASL_FACILITY, ASL_OPT_NO_DELAY);
    aslmsg m = asl_new(ASL_TYPE_MSG);
    asl_set(m, ASL_KEY_SENDER, BDSK_ASL_SENDER);
    
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

BDSK_PRIVATE_EXTERN void BDSKLog(NSString *format, ...)
{
    va_list list;
    va_start(list, format);
    // this will be redefined as BDSKLogv (see Bibdesk_Prefix.pch)
    NSLogv(format, list);
    va_end(list);
}

// override to avoid passing additional info in the message string, since ASL handles that for us
BDSK_PRIVATE_EXTERN void BDSKLogv(NSString *format, va_list argList)
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
    aslclient client = asl_open(BDSK_ASL_SENDER, BDSK_ASL_FACILITY, ASL_OPT_NO_DELAY);
    
    aslmsg m = asl_new(ASL_TYPE_MSG);
    asl_set(m, ASL_KEY_SENDER, BDSK_ASL_SENDER);
    
    char *buf;
    char stackBuf[STACK_BUFFER_SIZE];
    
    // nothing to prepend (pid, host, etc.) since ASL takes care of that for us; just convert the string to UTF-8
    
    // add 1 for the NULL terminator (length arg to getCString:maxLength:encoding: needs to include space for this)
    unsigned requiredLength = ([logString maximumLengthOfBytesUsingEncoding:NSUTF8StringEncoding] + 1);
    
    if (requiredLength <= STACK_BUFFER_SIZE && [logString getCString:stackBuf maxLength:STACK_BUFFER_SIZE encoding:NSUTF8StringEncoding]) {
        buf = stackBuf;
    } else if (NULL != (buf = NSZoneMalloc(NULL, requiredLength * sizeof(char))) ){
        [logString getCString:buf maxLength:requiredLength encoding:NSUTF8StringEncoding];
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

#pragma mark -

@implementation BDSKLogMessage

- (id)initWithASLMessage:(aslmsg)msg
{
    self = [super init];
    if (self) {
        const char *val;
        
        val = asl_get(msg, ASL_KEY_TIME);
        if (NULL == val) val = "0";
        time_t theTime = strtol(val, NULL, 0);
        date = [[NSDate dateWithTimeIntervalSince1970:theTime] copy];
        hash = [date hash];
        
        val = asl_get(msg, ASL_KEY_SENDER);
        if (NULL == val) val = "Unknown";
        sender = [[NSString alloc] initWithCString:val encoding:NSUTF8StringEncoding];
        
        val = asl_get(msg, ASL_KEY_PID);
        if (NULL == val) val = "-1";
        pid = strtol(val, NULL, 0);
        
        val = asl_get(msg, ASL_KEY_MSG);
        if (NULL == val) val = "Empty log message";
        message = [[NSString alloc] initWithCString:val encoding:NSUTF8StringEncoding];
    }
    return self;
}

- (void)dealloc
{
    [date release];
    [sender release];
    [message release];
    [super dealloc];
}

- (unsigned)hash { return hash; }
- (NSDate *)date { return date; }
- (NSString *)message { return message; }
- (NSString *)sender { return sender; }
- (int)pid { return pid; }

- (BOOL)isEqual:(id)other
{
    if ([other isKindOfClass:[self class]] == NO)
        return NO;
    if ([other pid] != pid)
        return NO;
    if ([[other message] isEqualToString:message] == NO)
        return NO;
    if ([(NSString *)[other sender] isEqualToString:sender] == NO)
        return NO;
    if ([[other date] compare:date] != NSOrderedSame)
        return NO;
    return YES;
}
- (NSString *)description { return [NSString stringWithFormat:@"%@ %@[%d]\t%@", date, sender, pid, message]; }
- (NSComparisonResult)compare:(BDSKLogMessage *)other { return [[self date] compare:[other date]]; }

@end

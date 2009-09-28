//
//  BDSKShellTask.m
//  BibDesk
//
//  Created by Michael McCracken on Sat Dec 14 2002.
/*
 This software is Copyright (c) 2002-2009
 Michael O. McCracken. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Michael O. McCracken nor the names of any
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

#import "NSTask_BDSKExtensions.h"
#import "BDSKAppController.h"
#import "NSFileManager_BDSKExtensions.h"
#import <sys/stat.h>

volatile int caughtSignal = 0;

@interface BDSKShellTask : NSObject {
    NSTask *task;
    // data used to store stdOut from the filter
    NSData *stdoutData;
}
- (id)initWithTask:(NSTask *)aTask;
// Note: the returned data is not autoreleased
- (NSData *)runShellCommand:(NSString *)cmd withInputString:(NSString *)input;
- (NSData *)executeBinary:(NSString *)executablePath inDirectory:(NSString *)currentDirPath withArguments:(NSArray *)args environment:(NSDictionary *)env inputString:(NSString *)input;
- (void)stdoutNowAvailable:(NSNotification *)notification;
@end


@implementation NSTask (BDSKExtensions)

+ (NSString *)runShellCommand:(NSString *)cmd withInputString:(NSString *)input{
    BDSKShellTask *shellTask = [[BDSKShellTask alloc] initWithTask:[[[self alloc] init] autorelease]];
    NSString *output = nil;
    NSData *outputData = [shellTask runShellCommand:cmd withInputString:input];
    if(outputData){
        output = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];
        if(!output)
            output = [[NSString alloc] initWithData:outputData encoding:NSASCIIStringEncoding];
        if(!output)
            output = [[NSString alloc] initWithData:outputData encoding:[NSString defaultCStringEncoding]];
    }
    [shellTask release];
    return [output autorelease];
}

+ (NSData *)runRawShellCommand:(NSString *)cmd withInputString:(NSString *)input{
    BDSKShellTask *shellTask = [[BDSKShellTask alloc] initWithTask:[[[self alloc] init] autorelease]];
    NSData *output = [[shellTask runShellCommand:cmd withInputString:input] retain];
    [shellTask release];
    return [output autorelease];
}

+ (NSString *)executeBinary:(NSString *)executablePath inDirectory:(NSString *)currentDirPath withArguments:(NSArray *)args environment:(NSDictionary *)env inputString:(NSString *)input{
    BDSKShellTask *shellTask = [[BDSKShellTask alloc] initWithTask:[[[self alloc] init] autorelease]];
    NSString *output = nil;
    NSData *outputData = [shellTask executeBinary:executablePath inDirectory:currentDirPath withArguments:args environment:env inputString:input];
    if(outputData){
        output = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];
        if(!output)
            output = [[NSString alloc] initWithData:outputData encoding:NSASCIIStringEncoding];
        if(!output)
            output = [[NSString alloc] initWithData:outputData encoding:[NSString defaultCStringEncoding]];
    }
    [shellTask release];
    return [output autorelease];
}

@end


@implementation BDSKShellTask

- (id)init{
    return [self initWithTask:nil];
}

- (id)initWithTask:(NSTask *)aTask{
    if (self = [super init]) {
        task = [aTask retain] ?: [[NSTask alloc] init];
    }
    return self;
}

- (void)dealloc{
    [task release];
    [stdoutData release];
    [super dealloc];
}

//
// The following three methods are borrowed from Mike Ferris' TextExtras.
// For the real versions of them, check out http://www.lorax.com/FreeStuff/TextExtras.html
// - mmcc

// was runWithInputString in TextExtras' TEPipeCommand class.
- (NSData *)runShellCommand:(NSString *)cmd withInputString:(NSString *)input{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *shellPath = @"/bin/sh";
    NSString *shellScriptPath = [[NSFileManager defaultManager] temporaryFileWithBasename:@"shellscript"];
    NSString *script;
    NSData *scriptData;
    NSMutableDictionary *currentAttributes;
    unsigned long currentMode;
    NSData *output = nil;

    // ---------- Check the shell and create the script ----------
    if (![fm isExecutableFileAtPath:shellPath]) {
        NSLog(@"Filter Pipes: Shell path for Pipe panel does not exist or is not executable. (%@)", shellPath);
        return nil;
    }
    if (!cmd){
        return nil;
    }
    script = [NSString stringWithFormat:@"#!%@\n\n%@\n", shellPath, cmd];
    // Use UTF8... and write out the shell script and make it exectuable
    scriptData = [script dataUsingEncoding:NSUTF8StringEncoding];
    if (![scriptData writeToFile:shellScriptPath atomically:YES]) {
        NSLog(@"Filter Pipes: Failed to write temporary script file. (%@)", shellScriptPath);
        return nil;
    }
    currentAttributes = [[[fm attributesOfItemAtPath:shellScriptPath error:NULL] mutableCopyWithZone:[self zone]] autorelease];
    if (!currentAttributes) {
        NSLog(@"Filter Pipes: Failed to get attributes of temporary script file. (%@)", shellScriptPath);
        return nil;
    }
    currentMode = [currentAttributes filePosixPermissions];
    currentMode |= S_IRWXU;
    [currentAttributes setObject:[NSNumber numberWithUnsignedLong:currentMode] forKey:NSFilePosixPermissions];
    if (![fm setAttributes:currentAttributes ofItemAtPath:shellScriptPath error:NULL]) {
        NSLog(@"Filter Pipes: Failed to get attributes of temporary script file. (%@)", shellScriptPath);
        return nil;
    }

    // ---------- Execute the script ----------

    // MF:!!! The current working dir isn't too appropriate
    output = [self executeBinary:shellScriptPath inDirectory:[shellScriptPath stringByDeletingLastPathComponent] withArguments:nil environment:nil inputString:input];

    // ---------- Remove the script file ----------
    if (![fm removeItemAtPath:shellScriptPath error:NULL]) {
        NSLog(@"Filter Pipes: Failed to delete temporary script file. (%@)", shellScriptPath);
    }

    return output;
}

// This method and the little notification method following implement synchronously running a task with input piped in from a string and output piped back out and returned as a string.   They require only a stdoutData instance variable to function.
- (NSData *)executeBinary:(NSString *)executablePath inDirectory:(NSString *)currentDirPath withArguments:(NSArray *)args environment:(NSDictionary *)env inputString:(NSString *)input {
    NSPipe *inputPipe;
    NSPipe *outputPipe;
    NSFileHandle *inputFileHandle;
    NSFileHandle *outputFileHandle;

    [task setLaunchPath:executablePath];
    if (currentDirPath) {
        [task setCurrentDirectoryPath:currentDirPath];
    }
    if (args) {
        [task setArguments:args];
    }
    if (env) {
        [task setEnvironment:env];
    }

    [task setStandardError:[NSFileHandle fileHandleWithStandardError]];
    inputPipe = [NSPipe pipe];
    inputFileHandle = [inputPipe fileHandleForWriting];
    [task setStandardInput:inputPipe];
    outputPipe = [NSPipe pipe];
    outputFileHandle = [outputPipe fileHandleForReading];
    [task setStandardOutput:outputPipe];
    
    // ignore SIGPIPE, as it causes a crash (seems to happen if the binaries don't exist and you try writing to the pipe)
    sig_t previousSignalMask = signal(SIGPIPE, SIG_IGN);

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(stdoutNowAvailable:) name:NSFileHandleReadToEndOfFileCompletionNotification object:outputFileHandle];
    [outputFileHandle readToEndOfFileInBackgroundAndNotifyForModes:[NSArray arrayWithObject:@"BDSKSpecialPipeServiceRunLoopMode"]];

    @try{

        [task launch];

        if ([task isRunning]) {
            
            if (input)
                [inputFileHandle writeData:[input dataUsingEncoding:NSUTF8StringEncoding]];
            [inputFileHandle closeFile];
            
            // run the runloop and pick up our notifications
            while (nil == stdoutData && ([task isRunning] || [task terminationStatus] == 0))
                [[NSRunLoop currentRunLoop] runMode:@"BDSKSpecialPipeServiceRunLoopMode" beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
            [task waitUntilExit];
            
            [nc removeObserver:self name:NSFileHandleReadToEndOfFileCompletionNotification object:outputFileHandle];
            
        } else {
            NSLog(@"Failed to launch task at \"%@\" or it exited without accepting input.  Termination status was %d", executablePath, [task terminationStatus]);
        }
    }
    @catch(id exception){
        // if the pipe failed, we catch an exception here and ignore it
        NSLog(@"exception %@ encountered while trying to run task %@", exception, executablePath);
        [nc removeObserver:self name:NSFileHandleReadToEndOfFileCompletionNotification object:outputFileHandle];
    }
    
    // reset signal handling to default behavior
    signal(SIGPIPE, previousSignalMask);

    return [task terminationStatus] == 0 && [stdoutData length] ? stdoutData : nil;
}

- (void)stdoutNowAvailable:(NSNotification *)notification {
    NSData *outputData = [[notification userInfo] objectForKey:NSFileHandleNotificationDataItem];
    if ([outputData length])
        stdoutData = [outputData retain];
}


@end

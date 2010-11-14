//
//  BDSKScriptGroup.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 10/19/06.
/*
 This software is Copyright (c) 2006-2010
 Christiaan Hofman. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Christiaan Hofman nor the names of any
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

#import "BDSKScriptGroup.h"
#import "KFAppleScriptHandlerAdditionsCore.h"
#import "KFASHandlerAdditions-TypeTranslation.h"
#import "BDSKBibTeXParser.h"
#import "BDSKStringParser.h"
#import "NSString_BDSKExtensions.h"
#import "NSImage_BDSKExtensions.h"
#import "BDSKAppController.h"
#import "NSError_BDSKExtensions.h"
#import "NSFileManager_BDSKExtensions.h"
#import "NSScanner_BDSKExtensions.h"
#import "BibItem.h"
#import "BDSKPublicationsArray.h"
#import "NSWorkspace_BDSKExtensions.h"
#import "BDSKTask.h"
#import "BDSKMacroResolver.h"

#define APPLESCRIPT_HANDLER_NAME @"main"

#define BDSKScriptGroupRunLoopMode @"BDSKScriptGroupRunLoopMode"

@interface BDSKScriptGroup (BDSKPrivate)

- (void)handleApplicationWillTerminate:(NSNotification *)aNotification;

- (void)runShellScript;
- (void)runAppleScript;

- (void)scriptDidFinishWithResult:(NSString *)outputString;
- (void)scriptDidFailWithError:(NSError *)error;

@end

#pragma mark -

@implementation BDSKScriptGroup

// old designated initializer
- (id)initWithName:(NSString *)aName;
{
    [self release];
    self = nil;
    return self;
}

- (id)initWithScriptPath:(NSString *)path scriptArguments:(NSString *)arguments scriptType:(NSInteger)type;
{
    self = [self initWithName:nil scriptPath:path scriptArguments:arguments scriptType:type];
    return self;
}

- (void)commonInit {
    argsArray = nil;
    isRetrieving = NO;
    failedDownload = NO;
    
    workingDirPath = [[[NSFileManager defaultManager] makeTemporaryDirectoryWithBasename:nil] retain];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleApplicationWillTerminate:) name:NSApplicationWillTerminateNotification object:nil];
}

// designated initialzer
- (id)initWithName:(NSString *)aName scriptPath:(NSString *)path scriptArguments:(NSString *)arguments scriptType:(NSInteger)type;
{
    NSParameterAssert(path != nil);
    if (aName == nil)
        aName = [[path lastPathComponent] stringByDeletingPathExtension];
    if(self = [super initWithName:aName]){
        scriptPath = [path retain];
        scriptArguments = [arguments retain];
        scriptType = type;
        [self commonInit];
    }
    return self;
}

- (id)initWithDictionary:(NSDictionary *)groupDict {
    NSString *aName = [[groupDict objectForKey:@"group name"] stringByUnescapingGroupPlistEntities];
    NSString *aPath = [[groupDict objectForKey:@"script path"] stringByUnescapingGroupPlistEntities];
    NSString *anArguments = [[groupDict objectForKey:@"script arguments"] stringByUnescapingGroupPlistEntities];
    NSInteger aType = [[groupDict objectForKey:@"script type"] integerValue];
    self = [self initWithName:aName scriptPath:aPath scriptArguments:anArguments scriptType:aType];
    return self;
}

- (NSDictionary *)dictionaryValue {
    NSString *aName = [[self stringValue] stringByEscapingGroupPlistEntities];
    NSString *aPath = [[self scriptPath] stringByEscapingGroupPlistEntities];
    NSString *anArgs = [[self scriptArguments] stringByEscapingGroupPlistEntities];
    NSNumber *aType = [NSNumber numberWithInteger:[self scriptType]];
    return [NSDictionary dictionaryWithObjectsAndKeys:aName, @"group name", aPath, @"script path", anArgs, @"script arguments", aType, @"script type", nil];
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super initWithCoder:decoder]) {
        scriptPath = [[decoder decodeObjectForKey:@"scriptPath"] retain];
        scriptArguments = [[decoder decodeObjectForKey:@"scriptArguments"] retain];
        scriptType = [decoder decodeIntegerForKey:@"scriptType"];
        [self commonInit];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    [coder encodeObject:scriptPath forKey:@"scriptPath"];
    [coder encodeObject:scriptArguments forKey:@"scriptArguments"];
    [coder encodeInteger:scriptType forKey:@"scriptType"];
}

- (id)copyWithZone:(NSZone *)aZone {
	return [[[self class] allocWithZone:aZone] initWithName:name scriptPath:scriptPath scriptArguments:scriptArguments scriptType:scriptType];
}

- (void)dealloc;
{
    // don't release currentTask; it's managed in the thread
    [[NSFileManager defaultManager] deleteObjectAtFileURL:[NSURL fileURLWithPath:workingDirPath] error:NULL];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopRetrieving];
    BDSKDESTROY(scriptPath);
    BDSKDESTROY(scriptArguments);
    BDSKDESTROY(argsArray);
    BDSKDESTROY(workingDirPath);
    BDSKDESTROY(stdoutData);
    [super dealloc];
}

- (NSString *)description;
{
    return [NSString stringWithFormat:@"<%@ %p>: {\n\t\tname: %@\n\tscript path: %@\n }", [self class], self, name, scriptPath];
}

- (void)handleApplicationWillTerminate:(NSNotification *)aNotification{
    [self stopRetrieving];
    [[NSFileManager defaultManager] deleteObjectAtFileURL:[NSURL fileURLWithPath:workingDirPath] error:NULL];
}

#pragma mark Accessors

- (BOOL)isRetrieving { return isRetrieving; }

- (BOOL)failedDownload { return failedDownload; }

- (NSString *)scriptPath;
{
    return scriptPath;
}

- (void)setScriptPath:(NSString *)newPath;
{
    if (newPath != scriptPath) {
		[(BDSKScriptGroup *)[[self undoManager] prepareWithInvocationTarget:self] setScriptPath:scriptPath];
        [scriptPath release];
        scriptPath = [newPath retain];
        
        [self setPublications:nil];
    }
}

- (NSString *)scriptArguments;
{
    return scriptArguments;
}

- (void)setScriptArguments:(NSString *)newArguments;
{
    if (newArguments != scriptArguments) {
		[(BDSKScriptGroup *)[[self undoManager] prepareWithInvocationTarget:self] setScriptArguments:scriptArguments];
        [scriptArguments release];
        scriptArguments = [newArguments retain];
        
        [argsArray release];
        argsArray = nil;
        
        [self setPublications:nil];
    }
}

- (NSInteger)scriptType;
{
    return scriptType;
}

- (void)setScriptType:(NSInteger)newType;
{
    if (newType != scriptType) {
		[(BDSKScriptGroup *)[[self undoManager] prepareWithInvocationTarget:self] setScriptType:scriptType];
        scriptType = newType;
        
        [argsArray release];
        argsArray = nil;
        
        [self setPublications:nil];
    }
}

// BDSKGroup overrides

- (NSImage *)icon {
    return [NSImage imageNamed:@"scriptGroup"];
}

- (BOOL)isScript { return YES; }

#pragma mark Running the script

- (void)retrievePublications;
{
    BOOL isDir = NO;
    NSString *standardizedPath = [scriptPath stringByStandardizingPath];
    
    isRetrieving = NO;
    failedDownload = NO;
    
    if([[NSFileManager defaultManager] fileExistsAtPath:standardizedPath isDirectory:&isDir] == NO || isDir){
        NSError *error = [NSError mutableLocalErrorWithCode:kBDSKFileNotFound localizedDescription:nil];
        if (isDir)
            [error setValue:NSLocalizedString(@"Script path points to a directory instead of a file", @"Error description") forKey:NSLocalizedDescriptionKey];
        else
            [error setValue:NSLocalizedString(@"The script path points to a file that does not exist", @"Error description") forKey:NSLocalizedDescriptionKey];
        [error setValue:standardizedPath forKey:NSFilePathErrorKey];
        [self scriptDidFailWithError:error];
    } else if (scriptType == BDSKShellScriptType) {
        [self runShellScript];
    } else if (scriptType == BDSKAppleScriptType) {
        [self runAppleScript];
    }
}

- (void)scriptDidFinishWithResult:(NSString *)outputString;
{
    NSParameterAssert([NSThread isMainThread]);
    NSParameterAssert(NO == failedDownload);
    isRetrieving = NO;
    NSError *error = nil;
    
    NSArray *pubs = nil;
    BDSKStringType type = [outputString contentStringType];
    if (type == BDSKNoKeyBibTeXStringType) {
        outputString = [outputString stringWithPhoneyCiteKeys:@"FixMe"];
        type = BDSKBibTeXStringType;
    }
    BOOL isPartialData = NO;
    NSDictionary *macros = nil;
    
    if (type == BDSKBibTeXStringType) {
        pubs = [BDSKBibTeXParser itemsFromData:[outputString dataUsingEncoding:NSUTF8StringEncoding] macros:&macros filePath:@"" owner:self encoding:NSUTF8StringEncoding isPartialData:&isPartialData error:&error];
        if (isPartialData && [error isLocalError] && [error code] == kBDSKParserIgnoredFrontMatter)
            isPartialData = NO;
    } else if (type != BDSKUnknownStringType){
        pubs = [BDSKStringParser itemsFromString:outputString ofType:type error:&error];
    } else {
        error = [NSError localErrorWithCode:kBDSKUnknownError localizedDescription:NSLocalizedString(@"Script did not return BibTeX", @"Error description")];
    }
    if (pubs == nil || isPartialData) {
        failedDownload = YES;
        [self setErrorMessage:[error localizedDescription]];
    }
    [[self macroResolver] setMacroDefinitions:macros];
    [self setPublications:pubs];
}

- (void)scriptDidFailWithError:(NSError *)error;
{
    NSParameterAssert([NSThread isMainThread]);
    isRetrieving = NO;
    failedDownload = YES;
    [self setErrorMessage:[error localizedDescription]];
    
    // redraw 
    [self setPublications:nil];
}

#pragma mark Shell task

// this method is called from the main thread
- (void)stopRetrieving{
    if([currentTask isRunning])
        [currentTask terminate];
    BDSKDESTROY(currentTask);
}

- (void)taskFinished:(NSNotification *)aNote
{
    NSParameterAssert([aNote object] == currentTask);
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:self name:NSTaskDidTerminateNotification object:[aNote object]];

    // now that the task is finished, run the special runloop mode (only one source in this mode)
    SInt32 ret;
    
    do {
        
        // handle the source in this mode immediately
        // any nonzero timeout should be sufficient, since the task has completed and flushed the pipe
        ret = CFRunLoopRunInMode((CFStringRef)BDSKScriptGroupRunLoopMode, 0.1, FALSE);
        
        // should get this immediately
        if (kCFRunLoopRunFinished == ret || kCFRunLoopRunStopped == ret) {
            break;
        }
        
        // hard timeout, since all I get when a task is terminated is kCFRunLoopRunTimedOut
        if (kCFRunLoopRunTimedOut == ret) {
            break;
        }
        
    } while (kCFRunLoopRunHandledSource == ret);

    NSFileHandle *outputFileHandle = [[currentTask standardOutput] fileHandleForReading];
    [nc removeObserver:self name:NSFileHandleReadToEndOfFileCompletionNotification object:outputFileHandle];
    
    NSString *outputString = [[NSString allocWithZone:[self zone]] initWithData:stdoutData encoding:NSUTF8StringEncoding];
    if(outputString == nil)
        outputString = [[NSString allocWithZone:[self zone]] initWithData:stdoutData encoding:[NSString defaultCStringEncoding]];
    [outputString autorelease];
    
    NSInteger terminationStatus = [currentTask terminationStatus];
    
    [currentTask release];
    currentTask = nil;

    if (terminationStatus != EXIT_SUCCESS || nil == outputString) {
        NSError *error = [NSError localErrorWithCode:kBDSKUnknownError localizedDescription:NSLocalizedString(@"The script did not return any output", @"Error description")];
        [self scriptDidFailWithError:error];
    } else {
        [self scriptDidFinishWithResult:outputString];
    }
}

- (void)stdoutNowAvailable:(NSNotification *)notification {
    NSData *outputData = [[notification userInfo] objectForKey:NSFileHandleNotificationDataItem];
    if ([outputData length])
        stdoutData = [outputData copy];
}

- (void)runShellScript;
{    
    if (stdoutData) {
        [stdoutData autorelease];
        stdoutData = nil;
    }
    
    @try{
        if (argsArray == nil)
            argsArray = [[scriptArguments shellScriptArgumentsArray] copy];
    }
    @catch (id exception) {
        NSError *error = [NSError mutableLocalErrorWithCode:kBDSKParserFailed localizedDescription:NSLocalizedString(@"Error parsing script arguments", @"Error description")];
        [error setValue:[exception reason] forKey:NSLocalizedRecoverySuggestionErrorKey];
        [self scriptDidFailWithError:error];
        
        // !!! early return here
        return;
    }
    
    NSPipe *outputPipe = [NSPipe pipe];

    // ignore SIGPIPE, as it causes a crash (seems to happen if the binaries don't exist and you try writing to the pipe)
    (void) signal(SIGPIPE, SIG_IGN);
        
    currentTask = [[BDSKTask allocWithZone:[self zone]] init];    
    [currentTask setStandardError:[NSFileHandle fileHandleWithStandardError]];
    [currentTask setLaunchPath:[scriptPath stringByStandardizingPath]];
    [currentTask setCurrentDirectoryPath:workingDirPath];
    [currentTask setStandardOutput:outputPipe];
    if ([argsArray count])
        [currentTask setArguments:argsArray];
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    NSFileHandle *outputFileHandle = [outputPipe fileHandleForReading];
    [nc addObserver:self selector:@selector(stdoutNowAvailable:) name:NSFileHandleReadToEndOfFileCompletionNotification object:outputFileHandle];
    [outputFileHandle readToEndOfFileInBackgroundAndNotifyForModes:[NSArray arrayWithObject:BDSKScriptGroupRunLoopMode]];

    [nc addObserver:self selector:@selector(taskFinished:) name:NSTaskDidTerminateNotification object:currentTask];
    
    [currentTask launch];
    isRetrieving = [currentTask isRunning];
    
    if (NO == isRetrieving) {
        NSError *error = [NSError localErrorWithCode:kBDSKUnknownError localizedDescription:NSLocalizedString(@"Failed to launch shell script", @"Error description")];
        [self scriptDidFailWithError:error];
    }
    
}

#pragma mark AppleScript

- (void)runAppleScript
{
    NSParameterAssert([NSThread isMainThread]);
    NSString *outputString = nil;
    NSError *error = nil;
    NSDictionary *errorInfo = nil;
    NSAppleScript *script = [[NSAppleScript alloc] initWithContentsOfURL:[NSURL fileURLWithPath:[scriptPath stringByStandardizingPath]] error:&errorInfo];
    if (errorInfo) {
        error = [NSError mutableLocalErrorWithCode:kBDSKAppleScriptError localizedDescription:NSLocalizedString(@"Unable to load AppleScript", @"Error description")];
        [error setValue:[errorInfo objectForKey:NSAppleScriptErrorMessage] forKey:NSLocalizedRecoverySuggestionErrorKey];
    } else {
        @try{
            if (argsArray == nil)
                argsArray = [[scriptArguments appleScriptArgumentsArray] retain];
            if ([argsArray count])
                outputString = [script executeHandler:APPLESCRIPT_HANDLER_NAME withParametersFromArray:argsArray];
            else 
                outputString = [script executeHandler:APPLESCRIPT_HANDLER_NAME];
        }
        @catch (id exception){
            // if there are no arguments we try to run the whole script
            if ([argsArray count] == 0) {
                errorInfo = nil;
                outputString = [[script executeAndReturnError:&errorInfo] objCObjectValue];
                if (errorInfo) {
                    error = [NSError mutableLocalErrorWithCode:kBDSKAppleScriptError localizedDescription:NSLocalizedString(@"Error executing AppleScript", @"Error description")];
                    [error setValue:[errorInfo objectForKey:NSAppleScriptErrorMessage] forKey:NSLocalizedRecoverySuggestionErrorKey];
                }
            } else {
                error = [NSError mutableLocalErrorWithCode:kBDSKAppleScriptError localizedDescription:NSLocalizedString(@"Error executing AppleScript", @"Error description")];
                [error setValue:[exception reason] forKey:NSLocalizedRecoverySuggestionErrorKey];
            }
        }
        [script release];
    }
    if (error || nil == outputString || NO == [outputString isKindOfClass:[NSString class]]) {
        if (error == nil)
            error = [NSError localErrorWithCode:kBDSKUnknownError localizedDescription:NSLocalizedString(@"The script did not return any output", @"Error description")];
        [self scriptDidFailWithError:error];
    } else {
        [self scriptDidFinishWithResult:outputString];
    }
}    

@end

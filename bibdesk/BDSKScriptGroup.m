//
//  BDSKScriptGroup.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 10/19/06.
/*
 This software is Copyright (c) 2006
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
#import "BDSKShellTask.h"
#import "KFAppleScriptHandlerAdditionsCore.h"
#import "KFASHandlerAdditions-TypeTranslation.h"
#import "BibTeXParser.h"
#import "PubMedParser.h"
#import "BDSKJSTORParser.h"
#import "BDSKWebOfScienceParser.h"
#import "BDSKParserProtocol.h"
#import "NSString_BDSKExtensions.h"
#import "NSImage+Toolbox.h"
#import "BibAppController.h"
#import "NSError_BDSKExtensions.h"
#import "NSFileManager_BDSKExtensions.h"
#import "NSScanner_BDSKExtensions.h"

#define APPLESCRIPT_HANDLER_NAME @"main"
#import <OmniFoundation/OFMessageQueue.h>

@implementation BDSKScriptGroup

- (id)initWithScriptPath:(NSString *)path scriptArguments:(NSString *)arguments scriptType:(int)type;
{
    self = [self initWithName:nil scriptPath:path scriptArguments:arguments scriptType:type];
    return self;
}

- (id)initWithName:(NSString *)aName scriptPath:(NSString *)path scriptArguments:(NSString *)arguments scriptType:(int)type;
{
    NSParameterAssert(path != nil);
    if (aName == nil)
        aName = [[path lastPathComponent] stringByDeletingPathExtension];
    if(self = [super initWithName:aName count:0]){
        publications = nil;
        scriptPath = [path retain];
        scriptArguments = [arguments retain];
        argsArray = nil;
        scriptType = type;
        failedDownload = NO;
        
        messageQueue = [[OFMessageQueue alloc] init];
        [messageQueue startBackgroundProcessors:1];
        [messageQueue setSchedulesBasedOnPriority:NO];
        
        workingDirPath = [[[NSApp delegate] temporaryFilePath:nil createDirectory:YES] retain];
        
        OFSimpleLockInit(&processingLock);
        OFSimpleLockInit(&currentTaskLock);
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:) name:NSApplicationWillTerminateNotification object:nil];
    }
    return self;
}

- (void)dealloc;
{
    [[NSFileManager defaultManager] deleteObjectAtFileURL:[NSURL fileURLWithPath:workingDirPath] error:NULL];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self terminate];
    OFSimpleLockFree(&processingLock);
    OFSimpleLockFree(&currentTaskLock);
    [scriptPath release];
    [scriptArguments release];
    [argsArray release];
    [publications release];
    [workingDirPath release];
    [stdoutData release];
    [super dealloc];
}

- (NSString *)description;
{
    return [NSString stringWithFormat:@"<%@ %p>: {\n\t\tname: %@\n\tscript path: %@\n }", [self class], self, name, scriptPath];
}

#pragma mark Running the script

- (void)startRunningScript;
{
    BOOL isDir = NO;
    
    if([[NSFileManager defaultManager] fileExistsAtPath:scriptPath isDirectory:&isDir] == NO || isDir){
        NSError *error = [NSError mutableLocalErrorWithCode:kBDSKFileNotFound localizedDescription:nil];
        if (isDir)
            [error setValue:NSLocalizedString(@"Script path points to a directory instead of a file", @"") forKey:NSLocalizedDescriptionKey];
        else
            [error setValue:NSLocalizedString(@"The script path points to a file that does not exist", @"") forKey:NSLocalizedDescriptionKey];
        [error setValue:scriptPath forKey:NSFilePathErrorKey];
        [self scriptDidFailWithError:error];
    } else if (scriptType == BDSKShellScriptType) {
        NSError *error = nil;
        @try{
            if (argsArray == nil)
                argsArray = [[scriptArguments shellScriptArgumentsArray] retain];
        }
        @catch (id exception) {
            error = [NSError mutableLocalErrorWithCode:kBDSKAppleScriptError localizedDescription:NSLocalizedString(@"Error Parsing Arguments", @"")];
            [error setValue:[exception reason] forKey:NSLocalizedRecoverySuggestionErrorKey];
        }
        if (error) {
            [self scriptDidFailWithError:error];
        } else {
            [messageQueue queueSelector:@selector(runShellScriptAtPath:withArguments:) forObject:self withObject:scriptPath withObject:argsArray];
            isRetrieving = YES;
        }
    } else if (scriptType == BDSKAppleScriptType) {
        // NSAppleScript can only run on the main thread
        NSString *outputString = nil;
        NSError *error = nil;
        NSDictionary *errorInfo = nil;
        NSAppleScript *script = [[NSAppleScript alloc] initWithContentsOfURL:[NSURL fileURLWithPath:scriptPath] error:&errorInfo];
        if (errorInfo) {
            error = [NSError mutableLocalErrorWithCode:kBDSKAppleScriptError localizedDescription:NSLocalizedString(@"Unable to Create AppleScript", @"")];
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
                        error = [NSError mutableLocalErrorWithCode:kBDSKAppleScriptError localizedDescription:NSLocalizedString(@"Error Executing AppleScript", @"")];
                        [error setValue:[errorInfo objectForKey:NSAppleScriptErrorMessage] forKey:NSLocalizedRecoverySuggestionErrorKey];
                    }
                } else {
                    error = [NSError mutableLocalErrorWithCode:kBDSKAppleScriptError localizedDescription:NSLocalizedString(@"Error Executing AppleScript", @"")];
                    [error setValue:[exception reason] forKey:NSLocalizedRecoverySuggestionErrorKey];
                }
            }
            [script release];
        }
        if (error || nil == outputString || NO == [outputString isKindOfClass:[NSString class]]) {
            if (error == nil)
                error = [NSError mutableLocalErrorWithCode:kBDSKUnknownError localizedDescription:NSLocalizedString(@"Script Did Not Return Anything", @"")];
            [self scriptDidFailWithError:error];
        } else {
            [self scriptDidFinishWithResult:outputString];
        }
    }
}

- (void)scriptDidFinishWithResult:(NSString *)outputString;
{
    isRetrieving = NO;
    failedDownload = NO;
    NSError *error = nil;

    NSArray *pubs = nil;
    int type = [outputString contentStringType];
    if (type == BDSKBibTeXStringType) {
        outputString = [outputString stringWithPhoneyCiteKeys:@"FixMe"];
        type = BDSKBibTeXStringType;
    }
    if (type == BDSKBibTeXStringType) {
        pubs = [BibTeXParser itemsFromData:[outputString dataUsingEncoding:NSUTF8StringEncoding] error:&error document:nil];
    } else if (type != BDSKUnknownStringType){
        pubs = [BDSKParserForStringType(type) itemsFromString:outputString error:&error];
    } else {
        error = [NSError mutableLocalErrorWithCode:kBDSKUnknownError localizedDescription:NSLocalizedString(@"Script Did Not Return BibTeX", @"")];
    }
    if (pubs == nil || error) {
        failedDownload = YES;
        [NSApp presentError:error];
    }
    [self setPublications:pubs];
}

- (void)scriptDidFailWithError:(NSError *)error;
{
    isRetrieving = NO;
    failedDownload = YES;
    
    // redraw 
    [self setPublications:nil];
    [NSApp presentError:error];
}

#pragma mark Accessors

- (NSArray *)publications;
{
    if([self isRetrieving] == NO && publications == nil){
        // get the publications asynchronously
        [self startRunningScript]; 
        
        // use this to notify the tableview to start the progress indicators
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:@"succeeded"];
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKScriptGroupUpdatedNotification object:self userInfo:userInfo];
    }
    // this posts a notification that the publications of the group changed, forcing a redisplay of the table cell
    return publications;
}

- (void)setPublications:(NSArray *)newPublications;
{
    if ([self isRetrieving])
        [self terminate];
    
    if(newPublications != publications){
        [publications release];
        publications = [newPublications retain];
    }
    
    [self setCount:[publications count]];
    
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:(publications != nil)] forKey:@"succeeded"];
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKScriptGroupUpdatedNotification object:self userInfo:userInfo];
}

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

- (int)scriptType;
{
    return scriptType;
}

- (void)setScriptType:(int)newType;
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
    return [NSImage smallImageNamed:@"scriptFolderIcon"];
}

- (BOOL)containsItem:(BibItem *)item {
    // calling [self publications] will repeatedly reschedule a retrieval, which is undesirable if the the URL download is busy; containsItem is called very frequently
    NSArray *pubs = [publications retain];
    BOOL rv = [pubs containsObject:item];
    [pubs release];
    return rv;
}

- (BOOL)isRetrieving { return isRetrieving; }

- (BOOL)failedDownload { return failedDownload; }

- (BOOL)isScript { return YES; }

- (BOOL)isExternal { return YES; }

- (BOOL)isEditable { return YES; }

- (BOOL)isValidDropTarget { return NO; }

#pragma mark Shell task thread

- (void)terminate{
    
    NSDate *referenceDate = [NSDate date];
    
    while ([self isProcessing] && currentTask){
        // if the task is still running after 2 seconds, kill it; we can't sleep here, because the main thread (usually this one) may be updating the UI for a task
        if([referenceDate timeIntervalSinceNow] > -2 && OFSimpleLockTry(&currentTaskLock)){
            if([currentTask isRunning])
                [currentTask terminate];
            currentTask = nil;
            OFSimpleUnlock(&currentTaskLock);
            break;
        } else if([referenceDate timeIntervalSinceNow] > -2.1){ // just in case this ever happens
            NSLog(@"%@ failed to lock for task %@", self, currentTask);
            [currentTask terminate];
            currentTask = nil;
            break;
        }
    }    
}

- (BOOL)isProcessing{
	// just see if we can get the lock, otherwise we are processing
    if(OFSimpleLockTry(&processingLock)){
		OFSimpleUnlock(&processingLock);
		return NO;
	}
	return YES;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification{
    [self terminate];
    [[NSFileManager defaultManager] deleteObjectAtFileURL:[NSURL fileURLWithPath:workingDirPath] error:NULL];
}

// this runs in the background thread
// we pass arguments because our ivars might change on the main thread
// @@ is this safe now?
- (void)runShellScriptAtPath:(NSString *)path withArguments:(NSArray *)args;
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    OFSimpleLock(&processingLock);
    
    NSString *outputString = nil;
    NSError *error = nil;
    NSTask *task;
    NSPipe *outputPipe = [NSPipe pipe];
    NSFileHandle *outputFileHandle = [outputPipe fileHandleForReading];
    BOOL isRunning;

    task = [[NSTask allocWithZone:[self zone]] init];    
    [task setStandardError:[NSFileHandle fileHandleWithNullDevice]];
    [task setLaunchPath:path];
    [task setCurrentDirectoryPath:workingDirPath];
    [task setStandardOutput:outputPipe];
    if ([args count])
        [task setArguments:args];
    
    // ignore SIGPIPE, as it causes a crash (seems to happen if the binaries don't exist and you try writing to the pipe)
    signal(SIGPIPE, SIG_IGN);
    
    OFSimpleLock(&currentTaskLock);
    currentTask = task;
    // we keep the lock, as the task is now the currentTask
    
    @try{ [task launch]; }
    @catch(id exception){
        if([task isRunning])
            [task terminate];
    }
    
    isRunning = [task isRunning];
    OFSimpleUnlock(&currentTaskLock);
    
    @try{
        if (isRunning) {
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stdoutNowAvailable:) name:NSFileHandleReadToEndOfFileCompletionNotification object:outputFileHandle];
            [outputFileHandle readToEndOfFileInBackgroundAndNotifyForModes:[NSArray arrayWithObject:@"BDSKSpecialPipeServiceRunLoopMode"]];
            
            // Now loop the runloop in the special mode until we've processed the notification.
            stdoutData = nil;
            while (stdoutData == nil && isRunning) {
                // Run the run loop, briefly, until we get the notification...
                [[NSRunLoop currentRunLoop] runMode:@"BDSKSpecialPipeServiceRunLoopMode" beforeDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
                OFSimpleLock(&currentTaskLock);
                isRunning = [task isRunning];
                OFSimpleUnlock(&currentTaskLock);
            }
            [[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleReadToEndOfFileCompletionNotification object:outputFileHandle];

            OFSimpleLock(&currentTaskLock);
            [task waitUntilExit];
            OFSimpleUnlock(&currentTaskLock);        

            outputString = [[NSString allocWithZone:[self zone]] initWithData:stdoutData encoding:NSUTF8StringEncoding];
            if(outputString == nil)
                outputString = [[NSString allocWithZone:[self zone]] initWithData:stdoutData encoding:NSASCIIStringEncoding];
            
            [stdoutData release];
            stdoutData = nil;
        } else {
            error = [NSError mutableLocalErrorWithCode:kBDSKUnknownError localizedDescription:NSLocalizedString(@"Failed to Run Script", @"")];
            [error setValue:[NSString stringWithFormat:NSLocalizedString(@"Failed to launch shell script %@", @""), path] forKey:NSLocalizedRecoverySuggestionErrorKey];
        }
    }
    @catch(id exception){
        // if the pipe failed, we catch an exception here and ignore it
        error = [NSError mutableLocalErrorWithCode:kBDSKUnknownError localizedDescription:NSLocalizedString(@"Failed to Run Script", @"")];
        [error setValue:[NSString stringWithFormat:NSLocalizedString(@"Exception %@ encountered while trying to run shell script %@", @""), [exception name], path] forKey:NSLocalizedRecoverySuggestionErrorKey];
    }
    
    // reset signal handling to default behavior
    signal(SIGPIPE, SIG_DFL);
    
    OFSimpleLock(&currentTaskLock);
    currentTask = nil;
    OFSimpleUnlock(&currentTaskLock);        
    
    [task release];
    
    if (error || nil == outputString) {
        if(error == nil)
            error = [NSError mutableLocalErrorWithCode:kBDSKUnknownError localizedDescription:NSLocalizedString(@"Script Did Not Return Anything", @"")];
        [[OFMessageQueue mainQueue] queueSelector:@selector(scriptDidFailWithError:) forObject:self withObject:error];
    } else {
        [[OFMessageQueue mainQueue] queueSelector:@selector(scriptDidFinishWithResult:) forObject:self withObject:outputString];
    }
    
    [outputString release];
    
    OFSimpleUnlock(&processingLock);
	[pool release];
}

- (void)stdoutNowAvailable:(NSNotification *)notification {
    // This is the notification method that executeBinary:inDirectory:withArguments:environment:inputString: registers to get called when all the data has been read. It just grabs the data and stuffs it in an ivar.  The setting of this ivar signals the main method that the output is complete and available.
    NSData *outputData = [[notification userInfo] objectForKey:NSFileHandleNotificationDataItem];
    stdoutData = (outputData ? [outputData retain] : [[NSData allocWithZone:[self zone]] init]);
}

@end


@implementation NSString (BDSKScriptGroupExtensions)

- (NSArray *)shellScriptArgumentsArray {
    static NSCharacterSet *specialChars;
    static NSCharacterSet *quoteChars;
    
    if (specialChars == nil) {
        NSMutableCharacterSet *tmpSet = [[NSCharacterSet whitespaceAndNewlineCharacterSet] mutableCopy];
        [tmpSet addCharactersInString:@"\\\"'`"];
        specialChars = [tmpSet copy];
        [tmpSet release];
        quoteChars = [[NSCharacterSet characterSetWithCharactersInString:@"\"'`"] retain];
    }
    
    NSScanner *scanner = [NSScanner scannerWithString:self];
    NSString *s = nil;
    unichar ch;
    NSMutableString *currArg = [scanner isAtEnd] ? nil : [NSMutableString string];
    NSMutableArray *arguments = [NSMutableArray array];
    
    [scanner setCharactersToBeSkipped:nil];
    
    while ([scanner isAtEnd] == NO) {
        if ([scanner scanUpToCharactersFromSet:specialChars intoString:&s])
            [currArg appendString:s];
        if ([scanner scanCharacter:&ch] == NO)
            break;
        if ([[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:ch]) {
            [scanner scanCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:NULL];
            [arguments addObject:currArg];
            currArg = [scanner isAtEnd] ? nil : [NSMutableString string];
        } else if (ch == '\\') {
            if ([scanner scanCharacter:&ch] == NO)
                [NSException raise:NSInternalInconsistencyException format:@"Missing character"];
            if ([currArg length] == 0 && [[NSCharacterSet newlineCharacterSet] characterIsMember:ch])
                [scanner scanCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:NULL];
            else 
                [currArg appendFormat:@"%C", ch];
        } else if ([quoteChars characterIsMember:ch]) {
            if ([scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithRange:NSMakeRange(ch, 1)] intoString:&s])
                [currArg appendString:s];
            if ([scanner scanCharacter:NULL] == NO)
                [NSException raise:NSInternalInconsistencyException format:@"Unmatched %C", ch];
        }
    }
    if (currArg)
        [arguments addObject:currArg];
    return arguments;
}

- (NSArray *)appleScriptArgumentsArray {
    static NSCharacterSet *numberChars = nil;
    static NSCharacterSet *specialStringChars = nil;
    static NSCharacterSet *listSeparatorChars = nil;
    static NSCharacterSet *specialListChars = nil;
    
    if (numberChars == nil) {
        numberChars = [[NSCharacterSet characterSetWithCharactersInString:@"-.0123456789"] retain];
        specialStringChars = [[NSCharacterSet characterSetWithCharactersInString:@"\\\""] retain];
        listSeparatorChars = [[NSCharacterSet characterSetWithCharactersInString:@"},:"] retain];
        specialListChars = [[NSCharacterSet characterSetWithCharactersInString:@"{}\""] retain];
    }
    
    NSScanner *scanner = [NSScanner scannerWithString:self];
    NSString *s = nil;
    unichar ch;
    NSMutableArray *arguments = [NSMutableArray array];
    
    [scanner setCharactersToBeSkipped:nil];
    
    while ([scanner isAtEnd] == NO) {
        [scanner scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:NULL];
        if ([scanner peekCharacter:&ch] == NO)
            break;
        if (ch == '"') {
            [scanner setScanLocation:[scanner scanLocation] + 1];
            NSMutableString *tmpString = [NSMutableString string];
            while ([scanner isAtEnd] == NO) {
                if ([scanner scanUpToCharactersFromSet:specialStringChars intoString:&s])
                    [tmpString appendString:s];
                if ([scanner scanCharacter:&ch] == NO)
                    [NSException raise:NSInternalInconsistencyException format:@"Missing \""];
                if (ch == '"') {
                    [tmpString removeSurroundingWhitespace];
                    [arguments addObject:tmpString];
                    break;
                } else if (ch == '\\') {
                    if ([scanner scanCharacter:&ch] == NO)
                        [NSException raise:NSInternalInconsistencyException format:@"Missing character"];
                    if (ch == 'n')
                        [tmpString appendString:@"\n"];
                    else if (ch == 'r')
                        [tmpString appendString:@"\r"];
                    else if (ch == 't')
                        [tmpString appendString:@"\t"];
                    else if (ch == '"')
                        [tmpString appendString:@"\""];
                    else if (ch == '\\')
                        [tmpString appendString:@"\\"];
                    else // or should we raise an execption?
                        [tmpString appendFormat:@"%C", ch];
                }
            }
        } else if ([numberChars characterIsMember:ch]) {
            float tmpNumber = 0;
            if ([scanner scanFloat:&tmpNumber])
                [arguments addObject:[NSNumber numberWithFloat:tmpNumber]];
        } else if (ch == '{') {
            [scanner setScanLocation:[scanner scanLocation] + 1];
            NSMutableArray *tmpArray = [NSMutableArray array];
            NSMutableDictionary *tmpDict = [NSMutableDictionary dictionary];
            BOOL isDict = NO;
            id tmpValue = nil;
            NSString *tmpKey = nil;
            while ([scanner isAtEnd] == NO) {
                [scanner scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:NULL];
                if ([scanner scanCharacter:&ch] == NO)
                    [NSException raise:NSInternalInconsistencyException format:@"Missing }"];
                tmpValue = nil;
                if (ch == '"') {
                    NSMutableString *tmpString = [NSMutableString stringWithString:@"\""];
                    while ([scanner isAtEnd] == NO) {
                        if ([scanner scanUpToString:@"\"" intoString:&s])
                            [tmpString appendString:s];
                        if ([scanner isAtEnd])
                            [NSException raise:NSInternalInconsistencyException format:@"Missing \""];
                        [scanner setScanLocation:[scanner scanLocation] + 1];
                        [tmpString appendString:@"\""];
                        if ([self characterAtIndex:[scanner scanLocation] - 2] != '\\')
                            break;
                    }
                    tmpValue = [[tmpString appleScriptArgumentsArray] objectAtIndex:0];
                    [scanner scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:NULL];
                    if ([scanner peekCharacter:&ch] == NO)
                        [NSException raise:NSInternalInconsistencyException format:@"Missing }"];
                    if (ch != '}' && ch != ',')
                        [NSException raise:NSInternalInconsistencyException format:@"Missing }"];
                } else if (ch == '{') {
                    NSMutableString *tmpString = [NSMutableString stringWithString:@"{"];
                    int nesting = 1;
                    while ([scanner isAtEnd] == NO) {
                        [scanner scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:NULL];
                        if ([scanner scanUpToCharactersFromSet:specialListChars intoString:&s])
                            [tmpString appendString:s];
                        if ([scanner scanCharacter:&ch] == NO)
                            [NSException raise:NSInternalInconsistencyException format:@"Missing }"];
                        [tmpString appendFormat:@"%C", ch];
                        if (ch == '"') {
                            while ([scanner isAtEnd] == NO) {
                                if ([scanner scanUpToString:@"\"" intoString:&s])
                                    [tmpString appendString:s];
                                if ([scanner scanString:@"\"" intoString:NULL] == NO)
                                    [NSException raise:NSInternalInconsistencyException format:@"Missing \""];
                                [tmpString appendString:@"\""];
                                if ([self characterAtIndex:[scanner scanLocation] - 2] != '\\')
                                    break;
                            }
                        } else if (ch == '{') {
                            nesting++;
                        } else {
                            nesting--;
                            if(nesting == 0){
                                break;
                            }
                        }
                    }
                    tmpValue = [[tmpString appleScriptArgumentsArray] objectAtIndex:0];
                } else {
                    [scanner setScanLocation:[scanner scanLocation] - 1];
                    if ([scanner scanUpToCharactersFromSet:listSeparatorChars intoString:&s])
                        tmpValue = [[s appleScriptArgumentsArray] objectAtIndex:0];
                }
                if ([scanner scanCharacter:&ch] == NO)
                    [NSException raise:NSInternalInconsistencyException format:@"Missing }"];
                if (ch == '}') {
                    if (isDict) {
                        if (tmpValue)
                            [tmpDict setObject:tmpValue forKey:tmpKey];
                        [arguments addObject:tmpDict];
                    } else {
                        if (tmpValue)
                            [tmpArray addObject:tmpValue];
                        [arguments addObject:tmpArray];
                    }
                    break;
                } else if (ch == ',') {
                    if (isDict)
                        [tmpDict setObject:tmpValue forKey:tmpKey];
                    else
                        [tmpArray addObject:tmpValue];
                } else if (ch == ':') {
                    isDict = YES;
                    tmpKey = tmpValue;
                    tmpValue = nil;
                } else
                    [NSException raise:NSInternalInconsistencyException format:@"Missing }"];
            }
        } else if ([scanner scanString:@"true" intoString:NULL] || [scanner scanString:@"yes" intoString:NULL]) {
            [arguments addObject:[NSNumber numberWithBool:YES]];
        } else if ([scanner scanString:@"false" intoString:NULL] || [scanner scanString:@"no" intoString:NULL]) {
            [arguments addObject:[NSNumber numberWithBool:NO]];
        } else { // or should we raise an exception?
            NSString *s = nil;
            if ([scanner scanUpToString:@"," intoString:&s])
                [arguments addObject:[s stringByRemovingSurroundingWhitespace]];
        }
        [scanner scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:NULL];
        if ([scanner scanCharacter:&ch] == NO)
            break;
        if (ch != ',')
            [NSException raise:NSInternalInconsistencyException format:@"Missing ,"];
    }
    return arguments;
}

@end

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
#import <OmniFoundation/OFMessageQueue.h>
#import "BibItem.h"
#import "BDSKPublicationsArray.h"
#import "BDSKMacroResolver.h"

#define APPLESCRIPT_HANDLER_NAME @"main"

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
        macroResolver = [[BDSKMacroResolver alloc] initWithOwner:self];
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
    [macroResolver release];
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
        NSMutableString *frontMatter = [NSMutableString string];
        pubs = [BibTeXParser itemsFromData:[outputString dataUsingEncoding:NSUTF8StringEncoding] frontMatter:frontMatter filePath:BDSKParserPasteDragString document:self error:&error];
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

- (BDSKPublicationsArray *)publications;
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
        [publications makeObjectsPerformSelector:@selector(setOwner:) withObject:nil];
        [publications release];
        publications = newPublications == nil ? nil : [[BDSKPublicationsArray alloc] initWithArray:newPublications];
        [publications makeObjectsPerformSelector:@selector(setOwner:) withObject:self];
        
        if (publications == nil)
            [macroResolver removeAllMacros];
    }
    
    [self setCount:[publications count]];
    
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:(publications != nil)] forKey:@"succeeded"];
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKScriptGroupUpdatedNotification object:self userInfo:userInfo];
}

- (BDSKMacroResolver *)macroResolver;
{
    return macroResolver;
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

// parses a space separated list of shell script argments
// allows quoting parts of an argument and escaped characters outside quotes, according to shell rules
- (NSArray *)shellScriptArgumentsArray {
    static NSCharacterSet *specialChars = nil;
    static NSCharacterSet *quoteChars = nil;
    
    if (specialChars == nil) {
        NSMutableCharacterSet *tmpSet = [[NSCharacterSet whitespaceAndNewlineCharacterSet] mutableCopy];
        [tmpSet addCharactersInString:@"\\\"'`"];
        specialChars = [tmpSet copy];
        [tmpSet release];
        quoteChars = [[NSCharacterSet characterSetWithCharactersInString:@"\"'`"] retain];
    }
    
    NSScanner *scanner = [NSScanner scannerWithString:self];
    NSString *s = nil;
    unichar ch = 0;
    NSMutableString *currArg = [scanner isAtEnd] ? nil : [NSMutableString string];
    NSMutableArray *arguments = [NSMutableArray array];
    
    [scanner setCharactersToBeSkipped:nil];
    [scanner scanCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:NULL];
    
    while ([scanner isAtEnd] == NO) {
        if ([scanner scanUpToCharactersFromSet:specialChars intoString:&s])
            [currArg appendString:s];
        if ([scanner scanCharacter:&ch] == NO)
            break;
        if ([[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:ch]) {
            // argument separator, add the last one we found and ignore more whitespaces
            [scanner scanCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:NULL];
            [arguments addObject:currArg];
            currArg = [scanner isAtEnd] ? nil : [NSMutableString string];
        } else if (ch == '\\') {
            // escaped character
            if ([scanner scanCharacter:&ch] == NO)
                [NSException raise:NSInternalInconsistencyException format:@"Missing character"];
            if ([currArg length] == 0 && [[NSCharacterSet newlineCharacterSet] characterIsMember:ch])
                // ignore escaped newlines between arguments, as they should be considered whitespace
                [scanner scanCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:NULL];
            else // real escaped character, just add the character, so we can ignore it if it is a special character
                [currArg appendFormat:@"%C", ch];
        } else if ([quoteChars characterIsMember:ch]) {
            // quoted part of an argument, scan up to the matching quote
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

// parses a comma separated list of AppleScript type arguments
- (NSArray *)appleScriptArgumentsArray {
    static NSCharacterSet *commaChars = nil;
    if (commaChars == nil)
        commaChars = [[NSCharacterSet characterSetWithCharactersInString:@","] retain];
    
    NSMutableArray *arguments = [NSMutableArray array];
    NSScanner *scanner = [NSScanner scannerWithString:self];
    unichar ch = 0;
    id object;
    
    [scanner setCharactersToBeSkipped:nil];
    
    while ([scanner isAtEnd] == NO) {
        if ([scanner scanAppleScriptValueUpToCharactersInSet:commaChars intoObject:&object])
            [arguments addObject:object];
        if ([scanner scanCharacter:&ch] == NO)
            break;
        if (ch != ',')
            [NSException raise:NSInternalInconsistencyException format:@"Missing ,"];
    }
    return arguments;
}

@end


@implementation NSScanner (BDSKScriptGroupExtensions)

// parses an AppleScript type value, including surrounding whitespace. A value can be:
// "-quoted string (with escapes),  explicit number, list of the form {item,...}, record of the form {key:value,...}, boolean constant, unquoted string (no escapes)
- (BOOL)scanAppleScriptValueUpToCharactersInSet:stopSet intoObject:(id *)object {
    static NSCharacterSet *numberChars = nil;
    static NSCharacterSet *specialStringChars = nil;
    static NSCharacterSet *listSeparatorChars = nil;
    
    if (numberChars == nil) {
        numberChars = [[NSCharacterSet characterSetWithCharactersInString:@"-.0123456789"] retain];
        specialStringChars = [[NSCharacterSet characterSetWithCharactersInString:@"\\\""] retain];
        listSeparatorChars = [[NSCharacterSet characterSetWithCharactersInString:@"},:"] retain];
    }
    
    unichar ch = 0;
    id tmpObject = nil;
    
    [self scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:NULL];
    
    if ([self peekCharacter:&ch] == NO)
        return NO;
    if (ch == '"') {
        // quoted string, look for escaped characters or closing double-quote
        [self setScanLocation:[self scanLocation] + 1];
        NSMutableString *tmpString = [NSMutableString string];
        NSString *s = nil;
        while ([self isAtEnd] == NO) {
            if ([self scanUpToCharactersFromSet:specialStringChars intoString:&s])
                [tmpString appendString:s];
            if ([self scanCharacter:&ch] == NO)
                [NSException raise:NSInternalInconsistencyException format:@"Missing \""];
            if (ch == '\\') {
                if ([self scanCharacter:&ch] == NO)
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
                else // or should we raise an exception?
                    [tmpString appendFormat:@"%C", ch];
            } else if (ch == '"') {
                [tmpString removeSurroundingWhitespace];
                tmpObject = tmpString;
                break;
            }
        }
    } else if ([numberChars characterIsMember:ch]) {
        // explicit number, should we check for integers?
        float tmpFloat = 0;
        if ([self scanFloat:&tmpFloat])
            tmpObject = [NSNumber numberWithFloat:tmpFloat];
    } else if (ch == '{') {
        // list or record, comma-separated items, possibly with keys
        // look for item and then a separator or closing brace
        [self setScanLocation:[self scanLocation] + 1];
        NSMutableArray *tmpArray = [NSMutableArray array];
        NSMutableDictionary *tmpDict = [NSMutableDictionary dictionary];
        BOOL isDict = NO;
        id tmpValue = nil;
        NSString *tmpKey = nil;
        while ([self isAtEnd] == NO) {
            // look for a key or value
            [self scanAppleScriptValueUpToCharactersInSet:listSeparatorChars intoObject:&tmpValue];
            if ([self scanCharacter:&ch] == NO)
                [NSException raise:NSInternalInconsistencyException format:@"Missing }"];
            if (ch == ':') {
                // we just found a key, so we have a record
                isDict = YES;
                tmpKey = tmpValue;
                tmpValue = nil;
            } else if (ch == ',') {
                // item separator, add it to the array or dictionary
                if (isDict)
                    [tmpDict setObject:tmpValue forKey:tmpKey];
                else
                    [tmpArray addObject:tmpValue];
                tmpValue = nil;
                tmpKey = nil;
            } else if (ch == '}') {
                // matching closing brace of the list or record argument, we can add the array or dictionary
                if (isDict) {
                    if (tmpValue)
                        [tmpDict setObject:tmpValue forKey:tmpKey];
                    tmpObject = tmpDict;
                } else {
                    if (tmpValue)
                        [tmpArray addObject:tmpValue];
                    tmpObject = tmpArray;
                }
                break;
            }
        }
    } else if ([self scanString:@"true" intoString:NULL] || [self scanString:@"yes" intoString:NULL]) {
        // boolean
        tmpObject = [NSNumber numberWithBool:YES];
    } else if ([self scanString:@"false" intoString:NULL] || [self scanString:@"no" intoString:NULL]) {
        // boolean
        tmpObject = [NSNumber numberWithBool:NO];
    } else { // or should we raise an exception?
        // unquoted string, just scan up to the next character in the stopset
        NSString *s = nil;
        if ([self scanUpToCharactersFromSet:stopSet intoString:&s])
            tmpObject = [s stringByRemovingSurroundingWhitespace];
    }
    [self scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:NULL];
    if (object != NULL)
        *object = tmpObject;
    return nil != tmpObject;
}

@end

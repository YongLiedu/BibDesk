//
//  NSWorkspace_BDSKExtensions.m
//  Bibdesk
//
//  Created by Adam Maxwell on 10/27/05.
/*
 This software is Copyright (c) 2005-2012
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

#import "NSWorkspace_BDSKExtensions.h"
#import <Carbon/Carbon.h>
#import "NSURL_BDSKExtensions.h"
#import "NSString_BDSKExtensions.h"

#define BDSKDefaultBrowserKey @"BDSKDefaultBrowserKey"

@implementation NSWorkspace (BDSKExtensions)

- (BOOL)openURL:(NSURL *)fileURL withSearchString:(NSString *)searchString
{
    
    // Passing a nil argument is a misuse of this method, so don't do it.
    NSParameterAssert(fileURL != nil);
    NSParameterAssert(searchString != nil);
    NSParameterAssert([fileURL isFileURL]);
    
    if ([NSString isEmptyString:searchString])
        return [self openLinkedURL:fileURL];
    
    // Find the application that should open this file
    BOOL success = NO;
    NSURL *appURL = NULL;
    NSString *bundleID = nil;
    NSString *extension = [[fileURL pathExtension] lowercaseString];
    NSDictionary *defaultViewers = [[NSUserDefaults standardUserDefaults] dictionaryForKey:BDSKDefaultViewersKey];
    NSWorkspace *ws = [NSWorkspace sharedWorkspace];
    bundleID = [defaultViewers objectForKey:extension];
    if (bundleID)
        appURL = [ws URLForApplicationWithBundleIdentifier:bundleID];
    if (appURL == nil) {
        appURL = [ws URLForApplicationToOpenURL:fileURL];
        if (appURL)
            bundleID = [[NSBundle bundleWithURL:appURL] bundleIdentifier];
    }
    
    if (bundleID) {
        // Create the odoc Apple event
        NSAppleEventDescriptor *openEvent = nil;
        NSAppleEventDescriptor *fileListDesc = [NSAppleEventDescriptor listDescriptor];
        NSAppleEventDescriptor *searchStringDesc = [NSAppleEventDescriptor descriptorWithString:searchString];
        [fileListDesc insertDescriptor:[fileURL aeDescriptorValue] atIndex:1];
        
        NSArray *runningApps = [NSRunningApplication runningApplicationsWithBundleIdentifier:bundleID];
        if ([runningApps count] > 0) {
            NSRunningApplication *runningApp = [runningApps objectAtIndex:0];
            pid_t pid = [runningApp processIdentifier];
            NSAppleEventDescriptor *appDesc = [NSAppleEventDescriptor descriptorWithDescriptorType:typeKernelProcessID bytes:&pid length:sizeof(pid)];
            openEvent = [NSAppleEventDescriptor appleEventWithEventClass:kCoreEventClass eventID:kAEOpenDocuments targetDescriptor:appDesc returnID:kAutoGenerateReturnID transactionID:kAnyTransactionID];
            [openEvent setParamDescriptor:fileListDesc forKeyword:keyDirectObject];
            [openEvent setParamDescriptor:searchStringDesc forKeyword:keyAESearchText];
            [runningApp activateWithOptions:0];
            if (noErr == AESendMessage([openEvent aeDesc], NULL, kAENoReply, kAEDefaultTimeout))
                success = YES;
        } else if (appURL) {
            // If the app wasn't running, we need to use LaunchApplication...which doesn't seem to work if the app (at least Skim) is already running, hence the initial call to AESendMessage.  Possibly this can be done with LaunchServices, but the documentation for this stuff isn't sufficient to say and I'm not in the mood for any more trial-and-error AppleEvent coding.
            FSRef appRef;
            if (CFURLGetFSRef((CFURLRef)appURL, &appRef)) {
                openEvent = [NSAppleEventDescriptor appleEventWithEventClass:kCoreEventClass eventID:kAEOpenDocuments targetDescriptor:nil returnID:kAutoGenerateReturnID transactionID:kAnyTransactionID];
                [openEvent setParamDescriptor:fileListDesc forKeyword:keyDirectObject];
                [openEvent setParamDescriptor:searchStringDesc forKeyword:keyAESearchText];
                LSApplicationParameters appParams;
                memset(&appParams, 0, sizeof(LSApplicationParameters));
                appParams.flags = kLSLaunchDefaults;
                appParams.application = &appRef;
                appParams.initialEvent = (AppleEvent *)[openEvent aeDesc];
                if (noErr == LSOpenApplication(&appParams, NULL))
                    success = YES;
            }
        }
    }
    
    // handle the case where somehow we are still not able to open
    if (success == NO)
        success = [self openURL:fileURL];
    
    return success;
}

- (BOOL)openLinkedURL:(NSURL *)aURL {
    BOOL rv = NO;
    NSString *appID = nil;
    if ([aURL isFileURL]) {
        NSString *extension = [[aURL pathExtension] lowercaseString];
        NSDictionary *defaultViewers = [[NSUserDefaults standardUserDefaults] dictionaryForKey:BDSKDefaultViewersKey];
        appID = [defaultViewers objectForKey:extension];
    } else {
        appID = [[NSUserDefaults standardUserDefaults] stringForKey:BDSKDefaultBrowserKey];
    }
    if (appID)
        rv = [self openURLs:[NSArray arrayWithObjects:aURL, nil] withAppBundleIdentifier:appID options:NSWorkspaceLaunchDefault additionalEventParamDescriptor:nil launchIdentifiers:NULL];
    if (rv == NO)
        rv = [self openURL:aURL];
    return rv;
}

- (BOOL)openURL:(NSURL *)aURL withApplicationURL:(NSURL *)applicationURL;
{
    OSStatus err = kLSUnknownErr;
    if(nil != aURL){
        LSLaunchURLSpec launchSpec;
        memset(&launchSpec, 0, sizeof(LSLaunchURLSpec));
        launchSpec.appURL = (CFURLRef)applicationURL;
        launchSpec.itemURLs = (CFArrayRef)[NSArray arrayWithObject:aURL];
        launchSpec.passThruParams = NULL;
        launchSpec.launchFlags = kLSLaunchDefaults;
        launchSpec.asyncRefCon = NULL;
        
        err = LSOpenFromURLSpec(&launchSpec, NULL);
    }
    return noErr == err ? YES : NO;
}

- (NSArray *)editorAndViewerURLsForURL:(NSURL *)aURL;
{
    NSParameterAssert(aURL);
    
    NSArray *applications = (NSArray *)LSCopyApplicationURLsForURL((CFURLRef)aURL, kLSRolesEditor | kLSRolesViewer);
    
    if(nil != applications){
        // LS seems to return duplicates (same full path), so we'll remove those to avoid confusion
        NSSet *uniqueApplications = [[NSSet alloc] initWithArray:applications];
        [applications release];
            
        // sort by application name
        NSSortDescriptor *sort = [[NSSortDescriptor alloc] initWithKey:@"path.lastPathComponent.stringByDeletingPathExtension" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)];
        applications = [[uniqueApplications allObjects] sortedArrayUsingDescriptors:[NSArray arrayWithObject:sort]];
        [sort release];
        [uniqueApplications release];
    }
    
    return applications;
}

- (NSURL *)defaultEditorOrViewerURLForURL:(NSURL *)aURL;
{
    NSParameterAssert(aURL);
    CFURLRef defaultEditorURL = NULL;
    OSStatus err = LSGetApplicationForURL((CFURLRef)aURL, kLSRolesEditor | kLSRolesViewer, NULL, &defaultEditorURL);
    
    // make sure we return nil if there's no application for this URL
    if(noErr != err && NULL != defaultEditorURL){
        CFRelease(defaultEditorURL);
        defaultEditorURL = NULL;
    }
    
    return [(id)defaultEditorURL autorelease];
}

- (NSArray *)editorAndViewerNamesAndBundleIDsForPathExtension:(NSString *)extension;
{
    NSParameterAssert(extension);
    
    CFStringRef theUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (CFStringRef)extension, NULL);
    NSArray *bundleIDs = (NSArray *)LSCopyAllRoleHandlersForContentType(theUTI, kLSRolesEditor | kLSRolesViewer);
    
    NSMutableSet *set = [[NSMutableSet alloc] init];
    NSMutableArray *applications = [NSMutableArray array];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    for (NSString *bundleID in bundleIDs) {
        if ([set containsObject:bundleID]) continue;
        NSString *appPath = [self absolutePathForAppBundleWithIdentifier:bundleID];
        if (appPath == nil || [fm fileExistsAtPath:appPath] == NO) continue;
        NSString *name = [[fm displayNameAtPath:appPath] stringByDeletingPathExtension];
        if (name == nil) continue;
        NSImage *icon = [self iconForFile:appPath];
        NSDictionary *dict = [[NSDictionary alloc] initWithObjectsAndKeys:bundleID, @"bundleID", name, @"name", icon, @"icon", nil];
        [applications addObject:dict];
        [dict release];
        [set addObject:bundleID];
    }
    [set release];
    BDSKCFDESTROY(bundleIDs);
    BDSKCFDESTROY(theUTI);
    
    // sort by application name
    NSSortDescriptor *sort = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)];
    [applications sortUsingDescriptors:[NSArray arrayWithObject:sort]];
    [sort release];
    
    return applications;
}

- (BOOL)isAppleScriptFileAtPath:(NSString *)path {
    NSString *theUTI = [self typeOfFile:[[path stringByStandardizingPath] stringByResolvingSymlinksInPath] error:NULL];
    return theUTI ? ([self type:theUTI conformsToType:@"com.apple.applescript.script"] ||
                     [self type:theUTI conformsToType:@"com.apple.applescript.text"] ||
                     [self type:theUTI conformsToType:@"com.apple.applescript.script-bundle"] ) : NO;
}

- (BOOL)isApplicationAtPath:(NSString *)path {
    NSString *theUTI = [self typeOfFile:[[path stringByStandardizingPath] stringByResolvingSymlinksInPath] error:NULL];
    return theUTI ? [self type:theUTI conformsToType:(id)kUTTypeApplication] : NO;
}

- (BOOL)isAutomatorWorkflowAtPath:(NSString *)path {
    NSString *theUTI = [self typeOfFile:[[path stringByStandardizingPath] stringByResolvingSymlinksInPath] error:NULL];
    return theUTI ? [self type:theUTI conformsToType:@"com.apple.automator-workflow"] : NO;
}

- (BOOL)isFolderAtPath:(NSString *)path {
    NSString *theUTI = [self typeOfFile:[[path stringByStandardizingPath] stringByResolvingSymlinksInPath] error:NULL];
    return theUTI ? [self type:theUTI conformsToType:(id)kUTTypeFolder] : NO;
}

#pragma mark Email support

- (BOOL)emailTo:(NSString *)receiver subject:(NSString *)subject body:(NSString *)body attachments:(NSArray *)files {
    NSMutableString *scriptString = nil;
    NSString *mailAppID = [(NSString *)LSCopyDefaultHandlerForURLScheme(CFSTR("mailto")) autorelease];
    
    if ([@"com.microsoft.entourage" isCaseInsensitiveEqual:mailAppID]) {
        scriptString = [NSMutableString stringWithString:@"tell application \"Microsoft Entourage\"\n"];
        [scriptString appendString:@"activate\n"];
        [scriptString appendFormat:@"set m to make new draft window with properties {subject: \"%@\", visible: true}\n", subject ?: @""];
        [scriptString appendString:@"tell m\n"];
        if (receiver)
            [scriptString appendFormat:@"set recipient to {address: {address: \"%@\", display name: \"%@\"}, recipient type: to recipient}}\n", receiver, receiver];
        if (body)
            [scriptString appendFormat:@"set content to \"%@\"\n", body];
        for (NSString *fileName in files)
            [scriptString appendFormat:@"make new attachment with properties {file: POSIX file \"%@\"}\n", fileName];
        [scriptString appendString:@"end tell\n"];
        [scriptString appendString:@"end tell\n"];
    } else if ([@"com.microsoft.outlook" isCaseInsensitiveEqual:mailAppID]) {
        scriptString = [NSMutableString stringWithString:@"tell application \"Microsoft Outlook\"\n"];
        [scriptString appendString:@"activate\n"];
        [scriptString appendFormat:@"set m to make new draft window with properties {subject: \"%@\", visible: true}\n", subject ?: @""];
        [scriptString appendString:@"tell m\n"];
        if (receiver)
            [scriptString appendFormat:@"set recipient to {address: {address: \"%@\", display name: \"%@\"}, recipient type: to recipient}}\n", receiver, receiver];
        if (body)
            [scriptString appendFormat:@"set content to \"%@\"\n", body];
        for (NSString *fileName in files)
            [scriptString appendFormat:@"make new attachment with properties {file: POSIX file \"%@\"}\n", fileName];
        [scriptString appendString:@"end tell\n"];
        [scriptString appendString:@"end tell\n"];
    } else if ([@"com.barebones.mailsmith" isCaseInsensitiveEqual:mailAppID]) {
        scriptString = [NSMutableString stringWithString:@"tell application \"Mailsmith\"\n"];
        [scriptString appendString:@"activate\n"];
        [scriptString appendFormat:@"set m to make new message window with properties {subject: \"%@\", visible: true}\n", subject ?: @""];
        [scriptString appendString:@"tell m\n"];
        if (receiver)
            [scriptString appendFormat:@"make new to_recipient at end with properties {address: \"%@\"}\n", receiver];
        if (body)
            [scriptString appendFormat:@"set contents to \"%@\"\n", body];
        for (NSString *fileName in files)
            [scriptString appendFormat:@"make new enclosure with properties {file: POSIX file \"%@\"}\n", fileName];
        [scriptString appendString:@"end tell\n"];
        [scriptString appendString:@"end tell\n"];
    } else if ([@"com.mailplaneapp.Mailplane" isCaseInsensitiveEqual:mailAppID]) {
        scriptString = [NSMutableString stringWithString:@"tell application \"Mailplane\"\n"];
        [scriptString appendString:@"activate\n"];
        [scriptString appendFormat:@"set m to make new outgoing message with properties {subject: \"%@\", visible: true}\n", subject ?: @""];
        [scriptString appendString:@"tell m\n"];
        if (receiver)
            [scriptString appendFormat:@"make new to recipient at end with properties {address: \"%@\"}\n", receiver];
        if (body)
            [scriptString appendFormat:@"set content to \"%@\"\n", body];
        for (NSString *fileName in files)
            [scriptString appendFormat:@"make new mail attachment with properties {path: \"%@\"}\n", fileName];
        [scriptString appendString:@"end tell\n"];
        [scriptString appendString:@"end tell\n"];
    } else if ([@"com.postbox-inc.postboxexpress" isCaseInsensitiveEqual:mailAppID]) {
        scriptString = [NSMutableString stringWithString:@"tell application \"PostboxExpress\"\n"];
        [scriptString appendString:@"activate\n"];
        [scriptString appendFormat:@"send message subject \"%@\"", subject ?: @""];
        if (receiver)
            [scriptString appendFormat:@" recipient \"%@\"", receiver];
        if (body)
            [scriptString appendFormat:@" body \"%@\"", body];
        if ([files count])
            [scriptString appendFormat:@" attachment \"%@\"", [files objectAtIndex:0]];
        [scriptString appendString:@"\n"];
        [scriptString appendString:@"end tell\n"];
    } else if ([@"com.postbox-inc.postbox" isCaseInsensitiveEqual:mailAppID]) {
        scriptString = [NSMutableString stringWithString:@"tell application \"Postbox\"\n"];
        [scriptString appendString:@"activate\n"];
        [scriptString appendFormat:@"send message subject \"%@\"", subject ?: @""];
        if (receiver)
            [scriptString appendFormat:@" recipient \"%@\"", receiver];
        if (body)
            [scriptString appendFormat:@" body \"%@\"", body];
        if ([files count])
            [scriptString appendFormat:@" attachment \"%@\"", [files objectAtIndex:0]];
        [scriptString appendString:@"\n"];
        [scriptString appendString:@"end tell\n"];
    } else {
        scriptString = [NSMutableString stringWithString:@"tell application \"Mail\"\n"];
        [scriptString appendString:@"activate\n"];
        [scriptString appendFormat:@"set m to make new outgoing message with properties {subject: \"%@\", visible: true}\n", subject ?: @""];
        [scriptString appendString:@"tell m\n"];
        if (receiver)
            [scriptString appendFormat:@"make new to recipient at end of to recipients with properties {address: \"%@\"}\n", receiver];
        if (body)
            [scriptString appendFormat:@"set content to \"%@\"\n", body];
        [scriptString appendString:@"tell its content\n"];
        for (NSString *fileName in files)
            [scriptString appendFormat:@"make new attachment at after last character with properties {file name: \"%@\"}\n", fileName];
        [scriptString appendString:@"end tell\n"];
        [scriptString appendString:@"end tell\n"];
        [scriptString appendString:@"end tell\n"];
    }
    
    if (scriptString) {
        NSAppleScript *script = [[[NSAppleScript alloc] initWithSource:scriptString] autorelease];
        NSDictionary *errorDict = nil;
        if ([script compileAndReturnError:&errorDict] == NO) {
            NSLog(@"Error compiling mail to script: %@", errorDict);
            return NO;
        }
        if ([script executeAndReturnError:&errorDict] == NO) {
            NSLog(@"Error running mail to script: %@", errorDict);
            return NO;
        }
        return YES;
    }
    return NO;
}

@end

@implementation NSString (UTIExtensions)

- (BOOL)isEqualToUTI:(NSString *)UTIString;
{
    return (UTIString == nil || UTTypeEqual((CFStringRef)self, (CFStringRef)UTIString) == FALSE) ? NO : YES;
}

@end

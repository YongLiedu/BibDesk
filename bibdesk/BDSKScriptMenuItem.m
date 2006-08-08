//
//  BDSKScriptMenuItem.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 30/10/05.
/*
 This software is Copyright (c) 2005,2006
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

#import "BDSKScriptMenuItem.h"
#import <OmniFoundation/OmniFoundation.h>
#import <OmniAppKit/NSMenu-OAExtensions.h>
#import <OmniBase/OmniBase.h>
#import <OmniAppKit/OAApplication.h>

@interface BDSKScriptMenu (Private)
- (NSArray *)scripts;
- (NSArray *)scriptPaths;
- (NSArray *)directoryContentsAtPath:(NSString *)path;
- (void)updateSubmenu:(NSMenu *)menu withScripts:(NSArray *)scripts;
- (void)executeScript:(id)sender;
- (void)openScript:(id)sender;
@end

@implementation BDSKScriptMenu

+ (BOOL)disabled;
{
    // Omni disables their script menu on 10.4, saying the system one is better...
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"OAScriptMenuDisabled"];
}

static Boolean scriptsArraysAreEqual(NSArray *array1, NSArray *array2)
{
    CFIndex count = CFArrayGetCount((CFArrayRef)array1);
    Boolean arraysAreEqual = FALSE;
    if(count == CFArrayGetCount((CFArrayRef)array2)){
        CFIndex idx;
        NSDictionary *dict1, *dict2;
        for(idx = 0; idx < count; idx++){
            dict1 = (id)CFArrayGetValueAtIndex((CFArrayRef)array1, idx);
            dict2 = (id)CFArrayGetValueAtIndex((CFArrayRef)array2, idx);
            if([dict1 isEqualToDictionary:dict2] == NO){
                arraysAreEqual = FALSE;
                break;
            }
        }
        arraysAreEqual = TRUE;
    }
    return arraysAreEqual;
}

- (void)reloadScriptMenu;
{
    NSArray *scripts = [self scripts];
    
    // don't recreate the menu unless the directory on disk has actually changed
    if(nil == cachedScripts || scriptsArraysAreEqual(cachedScripts, scripts) == FALSE){
        [self updateSubmenu:self withScripts:scripts];
        [cachedScripts release];
        cachedScripts = [scripts copy];
    }   
}

@end

@implementation BDSKScriptMenu (Private)

- (void)dealloc
{
    [cachedScripts release];
    [super dealloc];
}

static NSComparisonResult
scriptSort(id script1, id script2, void *context)
{
	NSString *key = (NSString *)context;
    return [[[script1 objectForKey:key] lastPathComponent] caseInsensitiveCompare:[[script2 objectForKey:key] lastPathComponent]];
}

- (NSArray *)scripts;
{
    NSMutableArray *scripts;
    NSArray *scriptFolders;
    unsigned int scriptFolderIndex, scriptFolderCount;
    
    scripts = [[NSMutableArray alloc] init];
    scriptFolders = [self scriptPaths];
    scriptFolderCount = [scriptFolders count];
	
    for (scriptFolderIndex = 0; scriptFolderIndex < scriptFolderCount; scriptFolderIndex++) {
        NSString *scriptFolder = [scriptFolders objectAtIndex:scriptFolderIndex];
		[scripts addObjectsFromArray:[self directoryContentsAtPath:scriptFolder]];
    }
	
	[scripts sortUsingFunction:scriptSort context:@"filename"];
    
	return [scripts autorelease];
}

- (NSArray *)directoryContentsAtPath:(NSString *)path 
{
	NSDirectoryEnumerator *dirEnum = [[NSFileManager defaultManager] enumeratorAtPath:path];
	NSString *file, *fileType, *filePath;
	NSNumber *fileCode;
	NSArray *content;
	NSDictionary *dict;
	NSMutableArray *fileArray = [NSMutableArray array];
	
	while (file = [dirEnum nextObject]) {
		fileType = [[dirEnum fileAttributes] valueForKey:NSFileType];
		fileCode = [[dirEnum fileAttributes] valueForKey:NSFileHFSTypeCode];
		filePath = [path stringByAppendingPathComponent:file];
		
		if ([file hasPrefix:@"."]) {
			[dirEnum skipDescendents];
		} else if ([fileType isEqualToString:NSFileTypeDirectory]) {
			[dirEnum skipDescendents];
			content = [self directoryContentsAtPath:filePath];
			if ([content count] > 0) {
				dict = [[NSDictionary alloc] initWithObjectsAndKeys:filePath, @"filename", content, @"content", nil];
				[fileArray addObject:dict];
				[dict release];
			}
		} else if ([file hasSuffix:@".scpt"] || [file hasSuffix:@".scptd"] || [fileCode longValue] == 'osas') {
			dict = [[NSDictionary alloc] initWithObjectsAndKeys:filePath, @"filename", nil];
			[fileArray addObject:dict];
			[dict release];
		}
	}
	[fileArray sortUsingFunction:scriptSort context:@"filename"];
	
	return fileArray;
}

- (void)updateSubmenu:(NSMenu *)menu withScripts:(NSArray *)scripts;
{        
    // we call this method recursively; if the menu is nil, the stuff we add won't be retained
    NSParameterAssert(menu != nil);
    
    NSEnumerator *scriptEnum = [scripts objectEnumerator];
	NSDictionary *scriptInfo;
    
    [menu setAutoenablesItems:NO];
    [menu removeAllItems];
    
    while (scriptInfo = [scriptEnum nextObject]) {
        NSString *scriptFilename = [scriptInfo objectForKey:@"filename"];
		NSArray *folderContent = [scriptInfo objectForKey:@"content"];
        NSString *scriptName = [scriptFilename lastPathComponent];
		NSMenuItem *item;
		
		if (folderContent) {
			NSMenu *submenu = [[NSMenu allocWithZone:[NSMenu menuZone]] initWithTitle:scriptName];
			
			item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:scriptName action:NULL keyEquivalent:@""];
			[item setSubmenu:submenu];
			[submenu release];
			[menu addItem:item];
			[item release];
			
			[self updateSubmenu:submenu withScripts:folderContent];
		} else {
			// why not use displayNameAtPath: or stringByDeletingPathExtension?
			// we want to remove the standard script filetype extension even if they're displayed in Finder
			// but we don't want to truncate a non-extension from a script without a filetype extension.
			// e.g. "Foo.scpt" -> "Foo" but not "Foo 2.5" -> "Foo 2"
			scriptName = [scriptName stringByRemovingSuffix:@".scpt"];
			scriptName = [scriptName stringByRemovingSuffix:@".scptd"];
			scriptName = [scriptName stringByRemovingSuffix:@".applescript"];
			
			item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:scriptName action:@selector(executeScript:) keyEquivalent:@""];
			[item setTarget:self];
			[item setEnabled:YES];
			[item setRepresentedObject:scriptFilename];
			[menu addItem:item];
			[item release];
			item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:scriptName action:@selector(openScript:) keyEquivalent:@""];
			[item setKeyEquivalentModifierMask:NSAlternateKeyMask];
			[item setTarget:self];
			[item setEnabled:YES];
			[item setRepresentedObject:scriptFilename];
			[item setAlternate:YES];
			[menu addItem:item];
			[item release];
		}
    }
}

- (NSArray *)scriptPaths;
{
    NSString *appSupportDirectory = nil;
    
    id appDelegate = [NSApp delegate];
    if (appDelegate != nil && [appDelegate respondsToSelector:@selector(applicationSupportDirectoryName)])
        appSupportDirectory = [appDelegate applicationSupportDirectoryName];
    
    if (appSupportDirectory == nil)
        appSupportDirectory = [[NSProcessInfo processInfo] processName];
    
    NSArray *libraries = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSAllDomainsMask, YES);
    unsigned int libraryIndex, libraryCount;
    libraryCount = [libraries count];
    NSMutableArray *result = [[NSMutableArray alloc] initWithCapacity:libraryCount + 1];
    for (libraryIndex = 0; libraryIndex < libraryCount; libraryIndex++) {
        NSString *library = [libraries objectAtIndex:libraryIndex];        
        
        [result addObject:[[[library stringByAppendingPathComponent:@"Application Support"] stringByAppendingPathComponent:appSupportDirectory] stringByAppendingPathComponent:@"Scripts"]];
    }
    
    [result addObject:[[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Contents"] stringByAppendingPathComponent:@"Scripts"]];
    
    return [result autorelease];
}

- (void)executeScript:(id)sender;
{
    NSString *scriptFilename, *scriptName;
    NSAppleScript *script;
    NSDictionary *errorDictionary;
    NSAppleEventDescriptor *result;
    
    scriptFilename = [sender representedObject];
    scriptName = [[NSFileManager defaultManager] displayNameAtPath:scriptFilename];
    script = [[[NSAppleScript alloc] initWithContentsOfURL:[NSURL fileURLWithPath:scriptFilename] error:&errorDictionary] autorelease];
    if (script == nil) {
        NSString *errorText, *messageText, *okButton;
        
        errorText = [NSString stringWithFormat:NSLocalizedString(@"The script file '%@' could not be opened.", @"script loading error"), scriptName];
        messageText = [NSString stringWithFormat:NSLocalizedString(@"AppleScript reported the following error:\n%@", @"script error message"), [errorDictionary objectForKey:NSAppleScriptErrorMessage]];
        okButton = NSLocalizedString(@"OK", @"OK");
        NSRunAlertPanel(errorText, messageText, okButton, nil, nil);
        return;
    }
    result = [script executeAndReturnError:&errorDictionary];
    if (result == nil) {
        NSString *errorText, *messageText, *okButton, *editButton;
        
        errorText = [NSString stringWithFormat:NSLocalizedString(@"The script '%@' could not complete.", @"script execute error"), scriptName];
        messageText = [NSString stringWithFormat:NSLocalizedString(@"AppleScript reported the following error:\n%@", @"script error message"), [errorDictionary objectForKey:NSAppleScriptErrorMessage]];
        okButton = NSLocalizedString(@"OK", "OK");
        editButton = NSLocalizedString(@"Edit Script", @"Edit Script");
        if (NSRunAlertPanel(errorText, messageText, okButton, editButton, nil) == NSAlertAlternateReturn) {
            [[NSWorkspace sharedWorkspace] openFile:scriptFilename];
        }
        return;
    }
}

- (void)openScript:(id)sender;
{
    NSString *scriptFilename = [sender representedObject];
	
	[[NSWorkspace sharedWorkspace] openFile:scriptFilename];
}

@end
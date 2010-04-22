//
//  BDSKScriptMenu.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 30/10/05.
/*
 This software is Copyright (c) 2005-2010
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

#import "BDSKScriptMenu.h"
#import "NSWorkspace_BDSKExtensions.h"
#import "NSMenu_BDSKExtensions.h"
#import "BDSKTask.h"

@interface BDSKScriptMenu (Private) <NSMenuDelegate>
- (NSArray *)scriptPaths;
- (NSArray *)directoryContentsAtPath:(NSString *)path lastModified:(NSDate **)lastModifiedDate;
- (void)updateSubmenu:(NSMenu *)menu withScripts:(NSArray *)scripts;
- (void)executeScript:(id)sender;
- (void)openScript:(id)sender;
@end

@implementation BDSKScriptMenu

static NSArray *sortDescriptors = nil;
static NSInteger recursionDepth = 0;

+ (void)initialize
{
    BDSKINITIALIZE;
    sortDescriptors = [[NSArray alloc] initWithObjects:[[[NSSortDescriptor alloc] initWithKey:@"filename" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)] autorelease], nil];
}

+ (void)addScriptsToMainMenu;
{
    // title is currently unused
    NSString *scriptMenuTitle = @"Scripts";
    BDSKScriptMenu *newMenu = [[self allocWithZone:[self menuZone]] initWithTitle:scriptMenuTitle];
    NSMenuItem *scriptItem = [[NSMenuItem allocWithZone:[self menuZone]] initWithTitle:scriptMenuTitle action:NULL keyEquivalent:@""];
    [scriptItem setImage:[NSImage imageNamed:@"ScriptMenu"]];
    [scriptItem setSubmenu:newMenu];
    [newMenu setDelegate:newMenu];
    [newMenu release];
    NSInteger itemIndex = [[NSApp mainMenu] numberOfItems] - 1;
    if (itemIndex > 0)
        [[NSApp mainMenu] insertItem:scriptItem atIndex:itemIndex];
    [scriptItem release];
}    

- (void)dealloc
{
    BDSKDESTROY(cachedDate);
    [super dealloc];
}

@end

@implementation BDSKScriptMenu (Private)

static NSDate *earliestDateFromBaseScriptsFolders(NSArray *folders)
{
    NSDate *date = [NSDate distantPast];
    for (NSString *folder in folders) {
        NSDate *modDate = [[[NSFileManager defaultManager] attributesOfItemAtPath:folder error:NULL] objectForKey:NSFileModificationDate];
        
        // typically these don't even exist for the other domains
        if (modDate)
            date = [modDate laterDate:date];
    }
    return date;
}
        

- (void)menuNeedsUpdate:(BDSKScriptMenu *)menu
{
    NSMutableArray *scripts;
    NSMutableArray *defaultScripts;
    NSArray *scriptFolders;
    NSUInteger i, count;
    
    scripts = [[NSMutableArray alloc] init];
    scriptFolders = [self scriptPaths];
    count = [scriptFolders count];
    
    // must initialize this date before passing it by reference
    NSDate *modDate = earliestDateFromBaseScriptsFolders(scriptFolders);
    
    // walk the subdirectories for each domain
    for (i = 0; i < count; i++) {
        NSString *scriptFolder = [scriptFolders objectAtIndex:i];
        recursionDepth = 0;
		[scripts addObjectsFromArray:[self directoryContentsAtPath:scriptFolder lastModified:&modDate]];
    }
    
    // don't recreate the menu unless the content on disk has actually changed
    if(nil == cachedDate || [modDate compare:cachedDate] == NSOrderedDescending){
        [cachedDate release];
        cachedDate = [modDate retain];
        
        [scripts sortUsingDescriptors:sortDescriptors];
        
        defaultScripts = [[self directoryContentsAtPath:[[[NSBundle mainBundle] sharedSupportPath] stringByAppendingPathComponent:@"Scripts"] lastModified:&modDate] mutableCopy];
        [defaultScripts sortUsingDescriptors:sortDescriptors];
        
        if (count = [defaultScripts count]) {
            if ([scripts count])
                [scripts insertObject:[NSDictionary dictionary] atIndex:0];
            [scripts insertObjects:defaultScripts atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, count)]];
        }
        [defaultScripts release];
        [self updateSubmenu:menu withScripts:scripts];        
    }   
    [scripts release];
}

- (BOOL)menuHasKeyEquivalent:(NSMenu *)menu forEvent:(NSEvent *)event target:(id *)target action:(SEL *)action
{
    // implemented so the menu isn't populated on every key event
    return NO;
}

- (NSArray *)directoryContentsAtPath:(NSString *)path lastModified:(NSDate **)lastModifiedDate
{
	NSMutableArray *fileArray = [NSMutableArray array];
	
    if (recursionDepth < 3) {
        recursionDepth++;
        
        NSFileManager *fm = [NSFileManager defaultManager];
        NSWorkspace *wm = [NSWorkspace sharedWorkspace];
        
        // avoid recursing too many times (and creating an excessive number of submenus)
        for (NSString *file in [fm contentsOfDirectoryAtPath:path error:NULL]) {
            NSString *filePath = [path stringByAppendingPathComponent:file];
            NSDictionary *fileAttributes = [fm attributesOfItemAtPath:filePath error:NULL];
            NSString *fileType = [fileAttributes valueForKey:NSFileType];
            BOOL isDir = [fileType isEqualToString:NSFileTypeDirectory];
            
            // get the latest modification date
            NSDate *modDate = [fileAttributes valueForKey:NSFileModificationDate];
            *lastModifiedDate = [*lastModifiedDate laterDate:modDate];
            
            NSDictionary *dict;
            
            if ([file hasPrefix:@"."]) {
            } else if ([wm isAppleScriptFileAtPath:filePath] || [wm isApplicationAtPath:filePath] || ([fm isExecutableFileAtPath:filePath] && isDir == NO)) {
                dict = [[NSDictionary alloc] initWithObjectsAndKeys:filePath, @"filename", nil];
                [fileArray addObject:dict];
                [dict release];
            } else if (isDir && [wm isFolderAtPath:filePath]) {
                NSArray *content = [self directoryContentsAtPath:filePath lastModified:lastModifiedDate];
                if ([content count] > 0) {
                    dict = [[NSDictionary alloc] initWithObjectsAndKeys:filePath, @"filename", content, @"content", nil];
                    [fileArray addObject:dict];
                    [dict release];
                }
            }
        }
        [fileArray sortUsingDescriptors:sortDescriptors];
        recursionDepth--;
	}
    return fileArray;
}

- (void)updateSubmenu:(NSMenu *)menu withScripts:(NSArray *)scripts;
{        
    static NSSet *scriptExtensions = nil;
    if (scriptExtensions == nil)
        scriptExtensions = [[NSSet alloc] initWithObjects:@"scpt", @"scptd", @"applescript", @"sh", @"csh", @"command", @"py", @"rb", @"pl", @"pm", @"app", @"workflow", nil];
    
    // we call this method recursively; if the menu is nil, the stuff we add won't be retained
    NSParameterAssert(menu != nil);
    
    [menu setAutoenablesItems:NO];
    [menu removeAllItems];
    
    for (NSDictionary *scriptInfo in scripts) {
        NSString *scriptFilename = [scriptInfo objectForKey:@"filename"];
		NSArray *folderContent = [scriptInfo objectForKey:@"content"];
        NSString *scriptName = [scriptFilename lastPathComponent];
		NSMenuItem *item;
		
		if (scriptName == nil) {
			[menu addItem:[NSMenuItem separatorItem]];
		} else if (folderContent) {
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
            if ([scriptExtensions containsObject:[[scriptName pathExtension] lowercaseString]])
                scriptName = [scriptName stringByDeletingPathExtension];
			NSString *showScriptName = [NSString stringWithFormat:NSLocalizedString(@"Show %@", @"menu item title"), scriptName];
            
			item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:scriptName action:@selector(executeScript:) keyEquivalent:@""];
			[item setTarget:self];
			[item setEnabled:YES];
			[item setRepresentedObject:scriptFilename];
			[menu addItem:item];
			[item release];
			item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:showScriptName action:@selector(openScript:) keyEquivalent:@""];
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
    static NSArray *scriptPaths = nil;
    
    if(nil == scriptPaths){
        NSString *appSupportDirectory = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleNameKey];
        
        NSArray *libraries = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSAllDomainsMask, YES);
        NSUInteger libraryIndex, libraryCount;
        libraryCount = [libraries count];
        NSMutableArray *result = [[NSMutableArray alloc] initWithCapacity:libraryCount + 1];
        for (libraryIndex = 0; libraryIndex < libraryCount; libraryIndex++) {
            NSString *library = [libraries objectAtIndex:libraryIndex];        
            
            [result addObject:[[library stringByAppendingPathComponent:appSupportDirectory] stringByAppendingPathComponent:@"Scripts"]];
        }
        
        scriptPaths = [result copy];
        [result release];
    }
    
    return scriptPaths;
}

- (void)executeScript:(id)sender;
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSWorkspace *wm = [NSWorkspace sharedWorkspace];
    NSString *scriptFilename, *scriptName;
    NSDictionary *errorDictionary;
    
    scriptFilename = [sender representedObject];
    scriptName = [fm displayNameAtPath:scriptFilename];
    
    if ([wm isAppleScriptFileAtPath:scriptFilename]) {
        NSAppleScript *script;
        NSAppleEventDescriptor *result;
        script = [[[NSAppleScript alloc] initWithContentsOfURL:[NSURL fileURLWithPath:scriptFilename] error:&errorDictionary] autorelease];
        if (script == nil) {
            NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"The script file '%@' could not be opened.", @"Message in alert dialog when failing to load script"), scriptName]
                                             defaultButton:NSLocalizedString(@"OK", @"Button title")
                                           alternateButton:nil
                                               otherButton:nil
                                 informativeTextWithFormat:NSLocalizedString(@"AppleScript reported the following error:\n%@", @"Informative text in alert dialog"), [errorDictionary objectForKey:NSAppleScriptErrorMessage]];
            [alert runModal];
        }
        result = [script executeAndReturnError:&errorDictionary];
        if (result == nil) {
            NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"The script '%@' could not complete.", @"Message in alert dialog when failing to execute script"), scriptName]
                                             defaultButton:NSLocalizedString(@"OK", @"Button title")
                                           alternateButton:NSLocalizedString(@"Edit Script", @"Button title")
                                               otherButton:nil
                                 informativeTextWithFormat:NSLocalizedString(@"AppleScript reported the following error:\n%@", @"Informative text in alert dialog"), [errorDictionary objectForKey:NSAppleScriptErrorMessage]];
            if ([alert runModal] == NSAlertAlternateReturn) {
                [wm openFile:scriptFilename];
            }
        }
    } else if ([wm isApplicationAtPath:scriptFilename]) {
        BOOL result = [wm launchApplication:scriptFilename];
        if (result == NO) {
            NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"The application '%@' could not be launched.", @"Message in alert dialog when failing to launch an app"), scriptName]
                                             defaultButton:NSLocalizedString(@"OK", @"Button title")
                                           alternateButton:NSLocalizedString(@"Show", @"Button title")
                                               otherButton:nil
                                 informativeTextWithFormat:nil];
            if ([alert runModal] == NSAlertAlternateReturn) {
                [wm selectFile:scriptFilename inFileViewerRootedAtPath:@""];
            }
        }
    } else if ([wm isAutomatorWorkflowAtPath:scriptFilename]) {
        [BDSKTask launchedTaskWithLaunchPath:@"/usr/bin/automator" arguments:[NSArray arrayWithObjects:scriptFilename, nil]];
    } else if ([fm isExecutableFileAtPath:scriptFilename]) {
        [BDSKTask launchedTaskWithLaunchPath:scriptFilename arguments:[NSArray array]];
    }
}

- (void)openScript:(id)sender;
{
    NSString *scriptFilename = [sender representedObject];
	NSWorkspace *wm = [NSWorkspace sharedWorkspace];
    
    if ([wm isApplicationAtPath:scriptFilename])
        [wm selectFile:scriptFilename inFileViewerRootedAtPath:@""];
    else
        [wm openFile:scriptFilename];
}

@end

// Copyright 2002-2004 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OAScriptMenuItem.h"

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "NSImage-OAExtensions.h"
#import "OAApplication.h"
#import "OAOSAScript.h"

RCS_ID("$Header: /Source/CVS/OmniGroup/Frameworks/OmniAppKit/OAScriptMenuItem.m,v 1.16.2.1 2004/05/06 23:06:12 neo Exp $")

@interface OAScriptMenuItem (Private)
- (NSArray *)_scripts;
- (NSArray *)_scriptPaths;
@end

#define SCRIPT_REFRESH_TIMEOUT (5.0)

@implementation OAScriptMenuItem

static NSImage *scriptImage;

+ (void)initialize;
{
    OBINITIALIZE;
    scriptImage = [[NSImage imageNamed:@"OAScriptMenu" inBundleForClass:self] retain];
}

- (void)_setup;
{
    [self setImage:scriptImage]; // does nothing on 10.2 and earlier, replaces title with icon on 10.3+
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"OAScriptMenuDisabled"])
        [[self menu] performSelector:@selector(removeItem:) withObject:self afterDelay:0.1];
        
    [self queueSelectorOnce:@selector(updateScripts)];
}

- initWithTitle:(NSString *)aTitle action:(SEL)anAction keyEquivalent:(NSString *)charCode;
{
    [super initWithTitle:aTitle action:anAction keyEquivalent:charCode];
    [self _setup];
    return self;
}

- initWithCoder:(NSCoder *)coder;
{
    // Init from nib
    [super initWithCoder:coder];
    [self _setup];
    return self;
}

- (void)dealloc;
{
    [cachedScripts release];
    [cachedScriptsDate release];
    [super dealloc];
}

- (IBAction)executeScript:(id)sender;
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
        
        errorText = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"The script file '%@' could not be opened.", @"OmniAppKit", [OAScriptMenuItem bundle], "script loading error"), scriptName];
        messageText = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"AppleScript reported the following error:\n%@", @"OmniAppKit", [OAScriptMenuItem bundle], "script loading error message"), [errorDictionary objectForKey:NSAppleScriptErrorMessage]];
        okButton = NSLocalizedStringFromTableInBundle(@"OK", @"OmniAppKit", [OAScriptMenuItem bundle], "script error panel button");
        NSRunAlertPanel(errorText, messageText, okButton, nil, nil);                                     
        return;
    }
    result = [script executeAndReturnError:&errorDictionary];
    if (result == nil) {
        NSString *errorText, *messageText, *okButton, *editButton;
        
        errorText = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"The script '%@' could not complete.", @"OmniAppKit", [OAScriptMenuItem bundle], "script execute error"), scriptName];
        messageText = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"AppleScript reported the following error:\n%@", @"OmniAppKit", [OAScriptMenuItem bundle], "script execute error message"), [errorDictionary objectForKey:NSAppleScriptErrorMessage]];
        okButton = NSLocalizedStringFromTableInBundle(@"OK", @"OmniAppKit", [OAScriptMenuItem bundle], "script error panel button");
        editButton = NSLocalizedStringFromTableInBundle(@"Edit Script", @"OmniAppKit", [OAScriptMenuItem bundle], "script error panel button");
        if (NSRunAlertPanel(errorText, messageText, okButton, editButton, nil) == NSAlertAlternateReturn) {
            [[NSWorkspace sharedWorkspace] openFile:scriptFilename];
        }
        return;
    }
}

- (NSMenu *)submenu;
{    
    if ((cachedScriptsDate != nil && [cachedScriptsDate timeIntervalSinceNow] > -SCRIPT_REFRESH_TIMEOUT))
        [self queueSelectorOnce:@selector(updateScripts)];
    return [super submenu];
}

- (void)updateScripts;
{
    NSMenu *menu;
    unsigned int oldMenuItemCount;
    NSArray *scripts;
    unsigned int scriptIndex, scriptCount;
    
    menu = [super submenu];
    [menu setAutoenablesItems:NO];
    oldMenuItemCount = [menu numberOfItems];
    while (oldMenuItemCount-- != 0)
        [menu removeItemAtIndex:oldMenuItemCount];

    scripts = [self _scripts];
    scriptCount = [scripts count];
    for (scriptIndex = 0; scriptIndex < scriptCount; scriptIndex++) {
        NSString *scriptFilename;
        NSString *scriptName;
        NSMenuItem *item;
        
        scriptFilename = [scripts objectAtIndex:scriptIndex];
        scriptName = [scriptFilename lastPathComponent];
        // why not use displayNameAtPath: or stringByDeletingPathExtension?
        // we want to remove the standard script filetype extension even if they're displayed in Finder
        // but we don't want to truncate a non-extension from a script without a filetype extension.
        // e.g. "Foo.scpt" -> "Foo" but not "Foo 2.5" -> "Foo 2"
        scriptName = [scriptName stringByRemovingSuffix:@".scpt"];
        scriptName = [scriptName stringByRemovingSuffix:@".scptd"];
        scriptName = [scriptName stringByRemovingSuffix:@".applescript"];
        item = [[NSMenuItem alloc] initWithTitle:scriptName action:@selector(executeScript:) keyEquivalent:@""];
        [item setTarget:self];
        [item setEnabled:YES];
        [item setRepresentedObject:scriptFilename];
        [menu addItem:item];
        [item release];
    }
}

@end

@implementation OAScriptMenuItem (Private)

int scriptSort(id script1, id script2, void *context)
{
    return [[script1 lastPathComponent] compare:[script2 lastPathComponent]];
}

- (NSArray *)_scripts;
{
    NSMutableArray *scripts;
    NSFileManager *fileManager;
    NSArray *scriptFolders;
    unsigned int scriptFolderIndex, scriptFolderCount;

    scripts = [[NSMutableArray alloc] init];
    fileManager = [NSFileManager defaultManager];
    scriptFolders = [self _scriptPaths];
    scriptFolderCount = [scriptFolders count];
    for (scriptFolderIndex = 0; scriptFolderIndex < scriptFolderCount; scriptFolderIndex++) {
        NSString *scriptFolder;
        NSArray *filenames;
        unsigned int filenameIndex, filenameCount;

        scriptFolder = [scriptFolders objectAtIndex:scriptFolderIndex];
        filenames = [fileManager directoryContentsAtPath:scriptFolder];
        filenameCount = [filenames count];
        for (filenameIndex = 0; filenameIndex < filenameCount; filenameIndex++) {
            NSString *filename;
            NSString *path;

            filename = [filenames objectAtIndex:filenameIndex];
            path = [scriptFolder stringByAppendingPathComponent:filename];
            if ([filename hasSuffix:@".scpt"] || [filename hasSuffix:@".scptd"] || [[[fileManager fileAttributesAtPath:path traverseLink:YES] objectForKey:NSFileHFSTypeCode] longValue] == 'osas')
                [scripts addObject:path];
        }
    }

    [cachedScripts release];
    cachedScripts = [[scripts sortedArrayUsingFunction:scriptSort context:NULL] retain];
    [scripts release];

    [cachedScriptsDate release];
    cachedScriptsDate = [[NSDate alloc] init];
    return cachedScripts;
}

- (NSArray *)_scriptPaths;
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

@end

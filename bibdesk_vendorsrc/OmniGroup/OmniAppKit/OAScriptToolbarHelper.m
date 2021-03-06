// Copyright 2002-2005, 2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OAScriptToolbarHelper.h"

#import <AppKit/AppKit.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "NSImage-OAExtensions.h"
#import "NSToolbar-OAExtensions.h"
#import "OAApplication.h"
#import "OAWorkflow.h"

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease_2007-10-25/OmniGroup/Frameworks/OmniAppKit/OAScriptToolbarHelper.m 90593 2007-08-31 16:58:02Z bungi $")

static BOOL OSVersionIs_10_4_Plus = NO;

@interface OAScriptToolbarHelper (Private)
- (void)_scanItems;
@end

@implementation OAScriptToolbarHelper

+ (void)initialize;
{
    OBINITIALIZE;
    
    OFVersionNumber *_10_4_version = [[OFVersionNumber alloc] initWithVersionString:@"10.4"];
    OSVersionIs_10_4_Plus = [_10_4_version compareToVersionNumber:[OFVersionNumber userVisibleOperatingSystemVersionNumber]] != NSOrderedDescending;
    [_10_4_version release];
}

- (id)init;
{
    if ([super init] == nil)
        return nil;

    _pathForItemDictionary = [[NSMutableDictionary alloc] init];

    return self;
}

- (void)dealloc;
{
    [_pathForItemDictionary release];
    [super dealloc];
}

- (NSString *)itemIdentifierExtension;
{
    return @"osascript";
}

- (NSString *)templateItemIdentifier;
{
    return @"OSAScriptTemplate";
}

static NSString *scriptPathForRootPath_10_4(NSString *rootPath)
{
    static NSString *appSupportDirectory = nil;

    if (appSupportDirectory == nil)
        appSupportDirectory = [[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"] retain];

    OBASSERT(appSupportDirectory != nil);

    return [[[[rootPath stringByAppendingPathComponent:@"Library"] stringByAppendingPathComponent:@"Scripts"] stringByAppendingPathComponent:@"Applications"] stringByAppendingPathComponent:appSupportDirectory];
}

static NSString *scriptPathForRootPath_10_3(NSString *rootPath)
{
    static NSString *appSupportDirectory = nil;
    
    if (appSupportDirectory == nil) {
        id appDelegate = [NSApp delegate];
        if (appDelegate != nil && [appDelegate respondsToSelector:@selector(applicationSupportDirectoryName)])
            appSupportDirectory = [appDelegate applicationSupportDirectoryName];
        
        if (appSupportDirectory == nil)
            appSupportDirectory = [[NSProcessInfo processInfo] processName];
        
        [appSupportDirectory retain];
    }

    OBASSERT(appSupportDirectory != nil);

    return [[[[rootPath stringByAppendingPathComponent:@"Library"] stringByAppendingPathComponent:@"Application Support"] stringByAppendingPathComponent:appSupportDirectory] stringByAppendingPathComponent:@"Scripts"];
}

static NSString *scriptPathForRootPath(NSString *rootPath)
{
    if (OSVersionIs_10_4_Plus) {
        return scriptPathForRootPath_10_4(rootPath);
    } else {
        return scriptPathForRootPath_10_3(rootPath);
    }
}

- (NSArray *)scriptPaths;
{
    NSMutableArray *result = [NSMutableArray array];

    [result addObject:scriptPathForRootPath(NSHomeDirectory())];
    [result addObject:scriptPathForRootPath(@"/")];
    [result addObject:scriptPathForRootPath(@"/Network")];
    [result addObject:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Scripts"]];
    
    if (!OSVersionIs_10_4_Plus) {
        // The only script we currently embed in the app wrapper is About The Scripts Menu, which we only use on 10.3
        [result addObject:[[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Contents"] stringByAppendingPathComponent:@"Scripts"]];
    }

    return result;
}

static NSString *removeScriptSuffix(NSString *string)
{
    if ([string hasSuffix:@".scpt"])
        return [string stringByRemovingSuffix:@".scpt"];
    if ([string hasSuffix:@".scptd"])
        return [string stringByRemovingSuffix:@".scptd"];
    if ([string hasSuffix:@".applescript"])
        return [string stringByRemovingSuffix:@".applescript"];
    if ([string hasSuffix:@".workflow"])
        return [string stringByRemovingSuffix:@".workflow"];
    return string;
}

- (NSArray *)allowedItems;
{
    [self _scanItems];
    return [_pathForItemDictionary allKeys];
}

- (NSString *)pathForItem:(NSToolbarItem *)anItem;
{
    [self _scanItems];
    return [_pathForItemDictionary objectForKey:[anItem itemIdentifier]];
}

- (void)finishSetupForItem:(NSToolbarItem *)item;
{
    NSString *path = [self pathForItem:item];
    if (path == nil)
        return;
    
    [item setTarget:self];
    [item setAction:@selector(executeScriptItem:)];
    [item setLabel:removeScriptSuffix([item label])];
    [item setPaletteLabel:removeScriptSuffix([item paletteLabel])];

    path = [path stringByExpandingTildeInPath];
    [item setImage:[[NSWorkspace sharedWorkspace] iconForFile:path]];

    CFURLRef url = CFURLCreateWithFileSystemPath(NULL, (CFStringRef)path, kCFURLPOSIXPathStyle, false);
    
    FSRef myFSRef;
    if (CFURLGetFSRef(url, &myFSRef)) {
        FSCatalogInfo catalogInfo;
        if (FSGetCatalogInfo(&myFSRef, kFSCatInfoFinderInfo, &catalogInfo, NULL, NULL, NULL) == noErr) {
            if ((((FileInfo *)(&catalogInfo.finderInfo))->finderFlags & kHasCustomIcon) == 0)
                [item setImage:[NSImage imageNamed:@"OAScriptIcon" inBundleForClass:[OAScriptToolbarHelper class]]];
        }
    }
    
    CFRelease(url);
}

- (void)executeScriptItem:sender;
{
    OAToolbarWindowController *controller = [[sender toolbar] delegate];
    
    if ([controller respondsToSelector:@selector(scriptToolbarItemShouldExecute:)] &&
	![controller scriptToolbarItemShouldExecute:sender])
	return;
    
    @try {
	NSString *scriptFilename = [[self pathForItem:sender] stringByExpandingTildeInPath];

	if (OSVersionIs_10_4_Plus && [@"workflow" isEqualToString:[scriptFilename pathExtension]]) {
	    OAWorkflow *workflow = [OAWorkflow workflowWithContentsOfFile:scriptFilename];
	    if (!workflow) {
		NSBundle *frameworkBundle = [OAScriptToolbarHelper bundle];
		NSString *errorText = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"Unable to run workflow.", @"OmniAppKit", frameworkBundle, "workflow execution error")];
		NSString *messageText = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"workflow not found at %@", @"OmniAppKit", frameworkBundle, "script loading error message"), scriptFilename];
		NSString *okButton = NSLocalizedStringFromTableInBundle(@"OK", @"OmniAppKit", frameworkBundle, "script error panel button");
		NSBeginAlertSheet(errorText, okButton, nil, nil, [[sender toolbar] window], self, NULL, NULL, NULL, messageText);                                     
		return;
	    }
	    NSException   *raisedException = nil;
	    NS_DURING {
		[workflow executeWithFiles:nil];
	    } NS_HANDLER {
		raisedException = localException;
	    } NS_ENDHANDLER;
	    if (raisedException) {
		NSBundle *frameworkBundle = [OAScriptToolbarHelper bundle];
		NSString *errorText = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"Unable to run workflow.", @"OmniAppKit", frameworkBundle, "workflow execution error")];
		NSString *messageText = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"The following error was reported:\n%@", @"OmniAppKit", frameworkBundle, "script loading error message"), [raisedException reason]];
		NSString *okButton = NSLocalizedStringFromTableInBundle(@"OK", @"OmniAppKit", frameworkBundle, "script error panel button");
		NSBeginAlertSheet(errorText, okButton, nil, nil, [[sender toolbar] window], self, NULL, NULL, NULL, messageText);                                     
	    }
	} else {
	    NSDictionary *errorDictionary;
	    NSString *scriptName = [[NSFileManager defaultManager] displayNameAtPath:scriptFilename];
	    NSAppleScript *script = [[[NSAppleScript alloc] initWithContentsOfURL:[NSURL fileURLWithPath:scriptFilename] error:&errorDictionary] autorelease];
	    NSAppleEventDescriptor *result;
	    if (script == nil) {
		NSString *errorText, *messageText, *okButton;
		
		errorText = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"The script file '%@' could not be opened.", @"OmniAppKit", [OAScriptToolbarHelper bundle], "script loading error"), scriptName];
		messageText = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"AppleScript reported the following error:\n%@", @"OmniAppKit", [OAScriptToolbarHelper bundle], "script loading error message"), [errorDictionary objectForKey:NSAppleScriptErrorMessage]];
		okButton = NSLocalizedStringFromTableInBundle(@"OK", @"OmniAppKit", [OAScriptToolbarHelper bundle], "script error panel button");
		NSBeginAlertSheet(errorText, okButton, nil, nil, [[sender toolbar] window], self, NULL, NULL, NULL, messageText);                                     
		return;
	    }
	    result = [script executeAndReturnError:&errorDictionary];
	    if (result == nil) {
		NSString *errorText, *messageText, *okButton, *editButton;
		
		errorText = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"The script '%@' could not complete.", @"OmniAppKit", [OAScriptToolbarHelper bundle], "script execute error"), scriptName];
		messageText = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"AppleScript reported the following error:\n%@", @"OmniAppKit", [OAScriptToolbarHelper bundle], "script execute error message"), [errorDictionary objectForKey:NSAppleScriptErrorMessage]];
		okButton = NSLocalizedStringFromTableInBundle(@"OK", @"OmniAppKit", [OAScriptToolbarHelper bundle], "script error panel button");
		editButton = NSLocalizedStringFromTableInBundle(@"Edit Script", @"OmniAppKit", [OAScriptToolbarHelper bundle], "script error panel button");
		NSBeginAlertSheet(errorText, okButton, editButton, nil, [[sender toolbar] window], self, @selector(errorSheetDidEnd:returnCode:contextInfo:), NULL, [scriptFilename retain], messageText);                                     
		
		return;
	    }
	}
    } @finally {
	if ([controller respondsToSelector:@selector(scriptToolbarItemFinishedExecuting:)])
	    [controller scriptToolbarItemFinishedExecuting:sender];
    }
}

- (void)errorSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
{
    if (returnCode == NSAlertAlternateReturn)
        [[NSWorkspace sharedWorkspace] openFile:[(NSString *)contextInfo autorelease]];
}

@end

@implementation OAScriptToolbarHelper (Private)

- (void)_scanItems;
{
    [_pathForItemDictionary removeAllObjects];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSEnumerator *folderEnumerator = [[self scriptPaths] objectEnumerator];
    NSString *scriptFolder;
    while ((scriptFolder = [folderEnumerator nextObject])) {
        NSEnumerator *fileEnumerator = [fileManager enumeratorAtPath:scriptFolder];
        NSString *filename;
        while ((filename = [fileEnumerator nextObject])) {
            // Sadly, there is no UTI for AppleScripts.  Radar 5032374.
            NSString *path = [scriptFolder stringByAppendingPathComponent:filename];
            
            NSDictionary *attributes = [fileManager fileAttributesAtPath:path traverseLink:YES];
            if (([[attributes objectForKey:NSFileHFSTypeCode] longValue] != 'osas') && ![filename hasSuffix:@".scpt"] && ![filename hasSuffix:@".scptd"] && ![filename hasSuffix:@".applescript"] && ![filename hasSuffix:@".workflow"])
                continue;
	    
	    NSString *itemIdentifier = [removeScriptSuffix(filename) stringByAppendingPathExtension:@"osascript"];
            if ([_pathForItemDictionary objectForKey:itemIdentifier] != nil)
                continue; // Don't register more than one script with the same name

	    path = [path stringByAbbreviatingWithTildeInPath];
            [_pathForItemDictionary setObject:path forKey:itemIdentifier];
        } 
    }
}

@end

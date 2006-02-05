//
//  BDSKInspectorWindowController.m
//  bd2xtest
//
//  Created by Christiaan Hofman on 2/5/06.
//  Copyright 2006. All rights reserved.
//

#import "BDSKInspectorWindowController.h"
#import "BDSKSecondaryWindowController.h"


@implementation BDSKInspectorWindowController

+ (id)sharedController {
    static NSMutableDictionary *sharedControllers = nil;
    if (sharedControllers == nil) {
        sharedControllers = [[NSMutableDictionary alloc] initWithCapacity:2];
    }
    NSString *className = NSStringFromClass([self class]);
    id sharedController = [sharedControllers objectForKey:className];
    if (sharedController == nil) {
        sharedController = [[[self class] alloc] init];
        [sharedControllers setObject:sharedController forKey:className];
        [sharedController release];
    }
    return sharedController;
}

- (id)init {
    self = [self initWithWindowNibName:[self windowNibName]];
    if (self) {
        observedWindowController = nil;
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self setMainWindow:nil];
    [super dealloc];
}

- (NSString *)windowNibName {
    // should be implemented by concrete subclass
    return [super windowNibName];
}

- (NSString *)windowTitle {
    // should be implemented by concrete subclass
    return nil;
}

- (NSString *)keyPathForBinding {
    // should be implemented by concrete subclass
    return nil;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    [[self window] setTitle:[self windowTitle]];
    [self setMainWindow:[NSApp mainWindow]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mainWindowChanged:) name:NSWindowDidBecomeMainNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mainWindowResigned:) name:NSWindowDidResignMainNotification object:nil];
}

- (void)mainWindowChanged:(NSNotification *)notification {
    [self setMainWindow:[notification object]];
}

- (void)mainWindowResigned:(NSNotification *)notification {
    [self setMainWindow:nil];
}

- (void)setMainWindow:(NSWindow *)mainWindow {
    NSWindowController *controller = [mainWindow windowController];

    if (controller && [controller isKindOfClass:[BDSKSecondaryWindowController class]]) {
        if (controller != observedWindowController) {
            if (observedWindowController != nil)
                [self unbindWindowController:observedWindowController];
            [observedWindowController release];
            observedWindowController = [controller retain];
            [self bindWindowController:observedWindowController];
        }
    } else if (controller == nil && observedWindowController != nil) {
        [self unbindWindowController:observedWindowController];
        [observedWindowController release];
        observedWindowController = nil;
    }
}

- (void)bindWindowController:(NSWindowController *)controller{
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO], NSRaisesForNotApplicableKeysBindingOption, [NSNumber numberWithBool:YES], NSConditionallySetsEnabledBindingOption, nil];
    NSString *keyPath = [NSString stringWithFormat:@"displayController.itemsArrayController.selection.%@", [self keyPathForBinding]];
    [itemsArrayController bind:@"managedObjectContext" toObject:controller withKeyPath:@"document.managedObjectContext" options:0];
    [itemsArrayController bind:@"contentSet" toObject:controller withKeyPath:keyPath options:options];
    [itemsArrayController rearrangeObjects];
}

- (void)unbindWindowController:(NSWindowController *)controller{
	[itemsArrayController unbind:@"contentSet"];
	[itemsArrayController unbind:@"managedObjectContext"];
}

@end


@implementation BDSKNoteWindowController

- (NSString *)windowNibName { return @"BDSKNoteWindow"; }

- (NSString *)windowTitle { return @"Notes"; }

- (NSString *)keyPathForBinding { return @"notes"; }

@end


@implementation BDSKTagWindowController

- (NSString *)windowNibName { return @"BDSKTagWindow"; }

- (NSString *)windowTitle { return @"Tags"; }

- (NSString *)keyPathForBinding { return @"tags"; }

@end

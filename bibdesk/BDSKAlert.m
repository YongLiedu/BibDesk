//
//  BDSKAlert.m
//  BibDesk
//
//  Created by Christiaan Hofman on 24/11/05.
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

#import "BDSKAlert.h"
#import "NSImage+Toolbox.h"


@interface BDSKAlert (Private)

- (void)prepare;
- (void)buttonPressed:(id)sender;
- (void)didEndAlert:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)endSheetWithReturnCode:(int)returnCode;

@end

@implementation BDSKAlert

+ (BDSKAlert *)alertWithMessageText:(NSString *)messageTitle defaultButton:(NSString *)defaultButtonTitle alternateButton:(NSString *)alternateButtonTitle otherButton:(NSString *)otherButtonTitle informativeTextWithFormat:(NSString *)format, ... {
	BDSKAlert *alert = [[[self class] alloc] init];
	NSString *informativeText;
	va_list args;
	
	[alert setMessageText:messageTitle];
	va_start(args, format);
	informativeText = [[NSString alloc] initWithFormat:format arguments:args];
	va_end(args);
	[alert setInformativeText:informativeText];
	[informativeText release];
	
	if (defaultButtonTitle == nil) 
		defaultButtonTitle = NSLocalizedString(@"OK", @"OK");
	[[alert addButtonWithTitle:defaultButtonTitle] setTag:NSAlertDefaultReturn];
	if (otherButtonTitle != nil) 
		[[alert addButtonWithTitle:otherButtonTitle] setTag:NSAlertOtherReturn];
	if (alternateButtonTitle != nil) 
		[[alert addButtonWithTitle:alternateButtonTitle] setTag:NSAlertAlternateReturn];
	
	return [alert autorelease];
}

- (id)init {
    if (self = [super init]) {
		BOOL success = [NSBundle loadNibNamed:@"BDSKAlert" owner:self];
		if (!success) {
			[self release];
			return (self = nil);
		}
		alertStyle = NSWarningAlertStyle;
		hasCheckButton = NO;
		minButtonSize = NSMakeSize(90.0, 32.0);
        buttons = [[NSMutableArray alloc] initWithCapacity:3];
        unbadgedImage = [[NSImage imageNamed:@"NSApplicationIcon"] retain];
        theModalDelegate = nil;
        theDidEndSelector = NULL;
        theDidDismissSelector = NULL;
    }
    return self;
}

- (void)dealloc {
    [buttons release];
    [unbadgedImage release];
    [panel release];
    [super dealloc];
}

- (int)runModal {
	[self prepare];
	
	runAppModal = YES;
	
	[panel makeKeyAndOrderFront:self];
	int returnCode = [NSApp runModalForWindow:panel];
	[panel orderOut:self];
	
	return returnCode;
}

- (void)beginSheetModalForWindow:(NSWindow *)window {
	[self beginSheetModalForWindow:window modalDelegate:nil didEndSelector:NULL didDismissSelector:NULL contextInfo:NULL];
}

- (void)beginSheetModalForWindow:(NSWindow *)window modalDelegate:(id)delegate didEndSelector:(SEL)didEndSelector contextInfo:(void *)contextInfo {
	[self beginSheetModalForWindow:window modalDelegate:delegate didEndSelector:didEndSelector didDismissSelector:NULL contextInfo:contextInfo];
}

- (void)beginSheetModalForWindow:(NSWindow *)window modalDelegate:(id)delegate didEndSelector:(SEL)didEndSelector didDismissSelector:(SEL)didDismissSelector contextInfo:(void *)contextInfo {
	[self prepare];
	
	runAppModal = NO;
    theModalDelegate = delegate;
	theDidEndSelector = didEndSelector;
	theDidDismissSelector = didDismissSelector;
    theContextInfo = contextInfo;
	
	[self retain]; // make sure we stay around long enough
	
	[NSApp beginSheet:panel
	   modalForWindow:window
		modalDelegate:self
	   didEndSelector:@selector(didEndAlert:returnCode:contextInfo:)
		  contextInfo:NULL];
}

- (int)runSheetModalForWindow:(NSWindow *)window {
	return [self runSheetModalForWindow:window modalDelegate:nil didEndSelector:NULL didDismissSelector:NULL contextInfo:NULL];
}

- (int)runSheetModalForWindow:(NSWindow *)window modalDelegate:(id)delegate didEndSelector:(SEL)didEndSelector didDismissSelector:(SEL)didDismissSelector contextInfo:(void *)contextInfo {
	[self prepare];
	
	runAppModal = YES;
    theModalDelegate = delegate;
	theDidEndSelector = didEndSelector;
	theDidDismissSelector = didDismissSelector;
    theContextInfo = contextInfo;
	
	[NSApp beginSheet:panel
	   modalForWindow:window
		modalDelegate:self
	   didEndSelector:@selector(didEndAlert:returnCode:contextInfo:)
		  contextInfo:NULL];
	int returnCode = [NSApp runModalForWindow:panel];
    [self endSheetWithReturnCode:returnCode];
	return returnCode;
}

- (void)setMessageText:(NSString *)messageText {
	[messageField setStringValue:messageText];
}

- (NSString *)messageText {
	return [messageField stringValue];
}

- (void)setInformativeText:(NSString *)informativeText {
	[informationField setStringValue:informativeText];
}

- (NSString *)informativeText {
	return [informationField stringValue];
}

- (void)setCheckText:(NSString *)checkText {
	[checkButton setTitle:checkText];
}

- (NSString *)checkText {
	return [checkButton title];
}

- (void)setIcon:(NSImage *)icon {
	if (unbadgedImage != icon) {
		[unbadgedImage release];
		unbadgedImage = [icon retain];
	}
}

- (BOOL)hasCheckButton {
    return hasCheckButton;
}

- (void)setHasCheckButton:(BOOL)flag {
    if (hasCheckButton != flag) {
        hasCheckButton = flag;
    }
}

- (void)setCheckValue:(BOOL)flag {
	[checkButton setState:flag ? NSOnState : NSOffState];
}

- (BOOL)checkValue {
	return ([checkButton state] == NSOnState);
}

- (NSImage *)icon {
	return unbadgedImage;
}

- (NSWindow *)window {
	return panel;
}

- (void)setAlertStyle:(NSAlertStyle)style {
	alertStyle = style;
}

- (NSAlertStyle)alertStyle {
	return alertStyle;
}

- (NSButton *)addButtonWithTitle:(NSString *)aTitle {
	int numButtons = [buttons count];
	NSRect buttonRect = NSMakeRect(318.0, 12.0, 90.0, 32.0);
	NSButton *button = [[NSButton alloc] initWithFrame:buttonRect];
	[button setBezelStyle:NSRoundedBezelStyle];
	[button setButtonType:NSMomentaryPushInButton];
	[button setTitle:aTitle];
	[button setTag:NSAlertFirstButtonReturn + numButtons];
	[button setTarget:self];
	[button setAction:@selector(buttonPressed:)];
    
    // buttons created in code use the wrong font
    id cell = [button cell];
    [cell setFont:[NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:[cell controlSize]]]];
    
	if (numButtons == 0) {
		[button setKeyEquivalent:@"\r"];
	} else if ([aTitle isEqualToString:NSLocalizedString(@"Cancel", @"Cancel")]) {
		[button setKeyEquivalent:@"\e"];
	} else if ([aTitle isEqualToString:NSLocalizedString(@"Don't Save", @"Don't Save")]) {
		[button setKeyEquivalent:@"d"];
		[button setKeyEquivalentModifierMask:NSCommandKeyMask];
	}
	[button sizeToFit];
	buttonRect = [button frame];
	if (NSWidth(buttonRect) < minButtonSize.width) 
		buttonRect.size.width = minButtonSize.width;
	if (numButtons == 0)
		buttonRect.origin.x = NSMaxX([[panel contentView] bounds]) - NSWidth(buttonRect) - 14.0;
	else
		buttonRect.origin.x = NSMinX([[buttons lastObject] frame]) - NSWidth(buttonRect);
	[button setFrame:buttonRect];
	[button setAutoresizingMask:NSViewMinXMargin | NSViewMaxXMargin];
	[[panel contentView] addSubview:button];
	[buttons addObject:button];
	[button release];
	return button;
}

- (NSArray *)buttons {
	return buttons;
}

- (NSButton *)checkButton {
	return checkButton;
}

@end

@implementation BDSKAlert (Private)

- (void)prepare {
	NSString *title;
	int numButtons = [buttons count];
	NSRect buttonRect;
	int i;
	NSButton *button = nil;
	float x;
	
	switch (alertStyle) {
		case NSCriticalAlertStyle: 
			title = NSLocalizedString(@"Critical", @"Critical");
			break;
		case NSInformationalAlertStyle: 
			title = NSLocalizedString(@"Information", @"Information");
			break;
		case NSWarningAlertStyle:
		default:
			title = NSLocalizedString(@"Alert", @"Alert");
	}
	[panel setTitle: title];
	
    // see if we should resize the message text
    NSRect frame = [panel frame];
    NSRect infoRect = [informationField frame];
    
    NSTextStorage *textStorage = [[[NSTextStorage alloc] initWithAttributedString:[informationField attributedStringValue]] autorelease];
    NSTextContainer *textContainer = [[[NSTextContainer alloc] initWithContainerSize:NSMakeSize(NSWidth(infoRect), 100.0)] autorelease];
    NSLayoutManager *layoutManager = [[[NSLayoutManager alloc] init] autorelease];
    
    [layoutManager addTextContainer:textContainer];
    [textStorage addLayoutManager:layoutManager];
    
    // drawing in views uses a different typesetting behavior from the current one which leads to a mismatch in line height
    // see http://www.cocoabuilder.com/archive/message/cocoa/2006/1/3/153669
    [layoutManager setTypesetterBehavior:NSTypesetterBehavior_10_2_WithCompatibility];
    [layoutManager glyphRangeForTextContainer:textContainer];
    
    float extraHeight = NSHeight([layoutManager usedRectForTextContainer:textContainer]) - NSHeight(infoRect);

    if (extraHeight > 0) {
        frame.size.height += extraHeight;
        infoRect.size.height += extraHeight;
        infoRect.origin.y -= extraHeight;
        [informationField setFrame:infoRect];
		[panel setFrame:frame display:NO];
    }
    
	if (hasCheckButton == NO) {
		frame.size.height -= 22.0;
		[checkButton removeFromSuperview];
		[panel setFrame:frame display:NO];
	}
	
	if (numButtons == 0)
		[self addButtonWithTitle:NSLocalizedString(@"OK", @"OK")];
	x = NSMinX([[buttons lastObject] frame]);
	if (numButtons > 2 && x > 98.0) {
		x = 98.0;
		i = numButtons;
		while (--i > 1) {
			button = [buttons objectAtIndex:i];
			buttonRect = [button frame];
			buttonRect.origin.x = x;
			[button setFrame:buttonRect];
			x += NSWidth(buttonRect) + 12.0;
		}
	}
	
	NSImage *image = unbadgedImage;
	
	if (alertStyle == NSCriticalAlertStyle) {
		NSRect imageRect = NSZeroRect;
		NSRect badgeRect;
		
		imageRect.size = [unbadgedImage size];
        badgeRect = NSMakeRect(floorf(NSMidX(imageRect)), 1.0, ceilf(0.5 * NSWidth(imageRect)), ceilf(0.5 * NSHeight(imageRect)));
        
		NSImage *image = [NSImage iconWithSize:imageRect.size forToolboxCode:kAlertCautionIcon];
		
		[image lockFocus]; 
		[unbadgedImage drawInRect:badgeRect fromRect:imageRect operation:NSCompositeSourceOver fraction:1.0];
		[image unlockFocus]; 
	}
	
	[imageView setImage:image];
}

- (void)buttonPressed:(id)sender {
	int returnCode = [sender tag];
	if (runAppModal) {
		[NSApp stopModalWithCode:returnCode];
	} else {
        [self endSheetWithReturnCode:returnCode];
        [self release];
	}
}

- (void)didEndAlert:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	if(theModalDelegate != nil && theDidEndSelector != NULL){
		NSMethodSignature *signature = [theModalDelegate methodSignatureForSelector:theDidEndSelector];
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
		[invocation setSelector:theDidEndSelector];
		[invocation setArgument:&self atIndex:2];
		[invocation setArgument:&returnCode atIndex:3];
		[invocation setArgument:&theContextInfo atIndex:4];
		[invocation invokeWithTarget:theModalDelegate];
	}
}

- (void)endSheetWithReturnCode:(int)returnCode {
    [NSApp endSheet:panel returnCode:returnCode];
    [panel orderOut:self];
    
	if(theModalDelegate != nil && theDidDismissSelector != NULL){
		NSMethodSignature *signature = [theModalDelegate methodSignatureForSelector:theDidDismissSelector];
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
		[invocation setSelector:theDidDismissSelector];
		[invocation setArgument:&self atIndex:2];
		[invocation setArgument:&returnCode atIndex:3];
		[invocation setArgument:&theContextInfo atIndex:4];
		[invocation invokeWithTarget:theModalDelegate];
	}
    
    theModalDelegate = nil;
    theDidEndSelector = NULL;
    theDidDismissSelector = NULL;
    theContextInfo = NULL;
}

@end

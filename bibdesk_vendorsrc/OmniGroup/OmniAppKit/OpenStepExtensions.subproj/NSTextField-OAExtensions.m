// Copyright 1997-2005, 2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniAppKit/NSTextField-OAExtensions.h>

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import <OmniAppKit/NSControl-OAExtensions.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease_2007-10-25/OmniGroup/Frameworks/OmniAppKit/OpenStepExtensions.subproj/NSTextField-OAExtensions.m 93428 2007-10-25 16:36:11Z kc $")

@implementation NSTextField (OAExtensions)

- (void) setStringValueAllowingNil: (NSString *) aString;
{
    if (!aString)
        aString = @"";
    [self setStringValue: aString];
}

- (void)appendString:(NSString *)aString;
{
    [self setStringValue:[NSString stringWithFormat:@"%@%@",
	    [self stringValue], aString]];
}


- (void)changeColorAsIfEnabledStateWas:(BOOL)newEnabled;
{
    [self setTextColor:newEnabled ? [NSColor controlTextColor] : [NSColor disabledControlTextColor]];
}

- (void)sizeToFitVertically;
{
    NSRect bounds = [self bounds];
    
    NSRect tallBounds = bounds;
    tallBounds.size.height = FLT_MAX;
    
    NSSize size = [[self cell] cellSizeForBounds:tallBounds];
    
    NSSize frameSize = [self convertSize:size toView:[self superview]];
    [self setFrameSize:frameSize];
}

// Subclassed from NSControl-OAExtensions

- (NSMutableDictionary *)attributedStringDictionaryWithCharacterWrapping;
{
    NSMutableDictionary *attributes;

    attributes = [super attributedStringDictionaryWithCharacterWrapping];
    [attributes setObject:[self textColor] forKey:NSForegroundColorAttributeName];

    return attributes;
}

@end

/*
#warning Hacking around Titan 1T4 (and before) bug.
// There's a bug where _setEditingTextView: gets called with nil, and raises an exception which horks a lot of stuff up.

@interface NSActionCell (PrivateAPI)
- (void)_setEditingTextView:(NSTextView *)textView;
@end

@interface NSActionCellOMNIBugFixes : NSActionCell
@end

@implementation NSActionCellOMNIBugFixes

+ (void)performPosing;
{
    // don't use -poseAs: method as it messes up OBPostLoader
    class_poseAs((Class)self, ((Class)self)->super_class);
}

- (void)_setEditingTextView:(NSTextView *)textView;
{
    if (!textView)
        return;
    [super _setEditingTextView:textView];
}

@end

*/



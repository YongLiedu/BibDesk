//
//  BDSKEditorTextView.m
//  Bibdesk
//
//  Created by Adam Maxwell on 02/28/06.
/*
 This software is Copyright (c) 2005-2009
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

#import "BDSKEditorTextView.h"
#import "NSURL_BDSKExtensions.h"
#import "BDSKStringConstants.h"

static char BDSKEditorTextViewDefaultsObservationContext;

@interface BDSKEditorTextView (Private)

- (void)updateFontFromPreferences;

@end

@implementation BDSKEditorTextView

- (void)doCommonSetup;
{
    BDSKPRECONDITION([self textStorage]);
    // use Apple's link detection on 10.5 and later
    [self setAutomaticLinkDetectionEnabled:YES];
    [self updateFontFromPreferences];
    [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self
        forKeyPath:[@"values." stringByAppendingString:BDSKEditorFontNameKey]
           options:0
           context:&BDSKEditorTextViewDefaultsObservationContext];
}    

- (id)initWithCoder:(NSCoder *)coder
{
    if (self = [super initWithCoder:coder]) {
        [self doCommonSetup];
    }
    return self;
}

- (id)initWithFrame:(NSRect)frameRect textContainer:(NSTextContainer *)container;
{
    if (self = [super initWithFrame:frameRect textContainer:container]) {
        [self doCommonSetup];
    }
    return self;    
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    @try { [[NSUserDefaultsController sharedUserDefaultsController] removeObserver:self forKeyPath:[@"values." stringByAppendingString:BDSKEditorFontNameKey]]; }
    @catch (id e) {}
    [super dealloc];
}

- (void)changeFont:(id)sender
{
    // convert the current font to the new font from the font panel
    // returns current font in case of a conversion failure
    NSFont *font = [[NSFontManager sharedFontManager] convertFont:[self font]];
    
    // save it to prefs for next time
    [[NSUserDefaults standardUserDefaults] setFloat:[font pointSize] forKey:BDSKEditorFontSizeKey];
    [[NSUserDefaults standardUserDefaults] setObject:[font fontName] forKey:BDSKEditorFontNameKey];
}

// make sure the font and other attributes get fixed when pasting text
- (void)paste:(id)sender {  [self pasteAsPlainText:sender]; }

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &BDSKEditorTextViewDefaultsObservationContext) {
        NSString *key = [keyPath substringFromIndex:7];
        if ([key isEqualToString:BDSKEditorFontNameKey]) {
            [self updateFontFromPreferences];
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark Private

// used only for reading the default font from prefs and then changing the font of the text storage
- (void)updateFontFromPreferences;
{
    NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:BDSKEditorFontNameKey];
    CGFloat fontSize = [[NSUserDefaults standardUserDefaults] floatForKey:BDSKEditorFontSizeKey];
    NSFont *font = nil;
    
    if(fontName != nil)
        font = [NSFont fontWithName:fontName size:fontSize];
    
    // NSFont itself could be nil
    if(font == nil)
        font = [NSFont systemFontOfSize:[NSFont systemFontSize]];
    
    // this changes the font of the entire text storage without undo
    [self setFont:font];
}

@end

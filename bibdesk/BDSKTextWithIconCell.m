//
//  BDSKTextWithIconCell.m
//  Bibdesk
//
//  Created by Adam Maxwell on 12/10/05.
/*
 This software is Copyright (c) 2005-2011
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

#import "BDSKTextWithIconCell.h"

NSString *BDSKTextWithIconCellStringKey = @"string";
NSString *BDSKTextWithIconCellImageKey = @"image";

static id nonNullObjectValueForKey(id object, NSString *key) {
    id value = [object valueForKey:key];
    return [value isEqual:[NSNull null]] ? nil : value;
}

@implementation BDSKTextWithIconCell

static BDSKTextWithIconFormatter *textWithIconFormatter = nil;

+ (void)initialize {
    BDSKINITIALIZE;
    textWithIconFormatter = [[BDSKTextWithIconFormatter alloc] init];
}

- (id)initTextCell:(NSString *)aString {
    if (self = [super initTextCell:aString]) {
        [self setFormatter:textWithIconFormatter];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    if (self = [super initWithCoder:coder]) {
        if ([self formatter] == nil)
            [self setFormatter:textWithIconFormatter];
    }
    return self;
}

- (NSColor *)highlightColorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    return nil;
}

- (void)setObjectValue:(id <NSCopying>)obj {
    // the objectValue should be an object that's KVC compliant for the "string" and "image" keys
    
    // this can happen initially from the init, as there's no initializer passing an objectValue
    if ([(id)obj isKindOfClass:[NSString class]])
        obj = [NSDictionary dictionaryWithObjectsAndKeys:obj, BDSKTextWithIconCellStringKey, nil];
    
    // we should not set a derived value such as the string here, otherwise NSTableView will call tableView:setObjectValue:forTableColumn:row: whenever a cell is selected
    [super setObjectValue:obj];
    
    [self setIcon:nonNullObjectValueForKey(obj, BDSKTextWithIconCellImageKey)];
}

@end

#pragma mark -

@implementation BDSKTextWithIconFormatter

- (NSString *)stringForObjectValue:(id)obj {
    return [obj isKindOfClass:[NSString class]] ? obj : nonNullObjectValueForKey(obj, BDSKTextWithIconCellStringKey);
}

- (BOOL)getObjectValue:(id *)obj forString:(NSString *)string errorDescription:(NSString **)error {
    // even though 'string' is reported as immutable, it's actually changed after this method returns and before it's returned by the control!
    string = [[string copy] autorelease];
    *obj = [NSDictionary dictionaryWithObjectsAndKeys:string, BDSKTextWithIconCellStringKey, nil];
    return YES;
}

@end

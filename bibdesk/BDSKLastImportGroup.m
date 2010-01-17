//
//  BDSKLastImportGroup.m
//  Bibdesk
//
//  Created by Christiaan on 11/30/09.
/*
 This software is Copyright (c) 2009-2010
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

#import "BDSKLastImportGroup.h"
#import "BDSKGroup.h"
#import "BDSKStaticGroup.h"


@implementation BDSKLastImportGroup

static NSString *BDSKLastImportLocalizedString = nil;

+ (void)initialize{
    BDSKINITIALIZE;
    BDSKLastImportLocalizedString = [NSLocalizedString(@"Last Import", @"Group name for last import") copy];
}

- (id)initWithLastImport:(NSArray *)array {
	self = [self initWithName:BDSKLastImportLocalizedString publications:array];
	return self;
}

- (NSImage *)icon {
	static NSImage *importGroupImage = nil;
    if (importGroupImage == nil) {
        importGroupImage = [[NSImage alloc] initWithSize:NSMakeSize(32.0, 32.0)];
        [importGroupImage lockFocus];
        [[NSImage imageNamed:NSImageNameFolderSmart] drawInRect:NSMakeRect(0.0, 0.0, 32.0, 32.0) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
        [[NSImage imageNamed:@"importBadge"] drawInRect:NSMakeRect(0.0, 0.0, 32.0, 32.0) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
        [importGroupImage unlockFocus];
        NSImage *tinyImage = [[NSImage alloc] initWithSize:NSMakeSize(16.0, 16.0)];
        [tinyImage lockFocus];
        [[NSImage imageNamed:NSImageNameFolderSmart] drawInRect:NSMakeRect(0.0, 0.0, 16.0, 16.0) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
        [[NSImage imageNamed:@"importBadge"] drawInRect:NSMakeRect(0.0, 0.0, 16.0, 16.0) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
        [tinyImage unlockFocus];
        [importGroupImage addRepresentation:[[tinyImage representations] lastObject]];
        [tinyImage release];
    }
    return importGroupImage;
}

- (void)setName:(NSString *)newName {}

- (BOOL)isNameEditable { return NO; }

- (BOOL)isEditable { return NO; }

- (BOOL)isStatic { return NO; }

- (BOOL)isValidDropTarget { return NO; }

- (BOOL)isEqual:(id)other { return other == self; }

- (NSUInteger)hash { return BDSKHash(self); }

@end

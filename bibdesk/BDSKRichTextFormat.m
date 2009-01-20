//
//  BDSKRichTextFormat.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 1/19/09.
/*
 This software is Copyright (c) 2009
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

#import "BDSKRichTextFormat.h"
#import <OmniFoundation/OmniFoundation.h>


@implementation BDSKRichTextFormat

- (id)initWithData:(NSData *)aData {
    if (self = [super init]) {
        if (aData) {
            data = [aData retain];
            name = nil;
        } else {
            [self release];
            self = nil;
        }
    }
    return self;
}

- (id)initWithName:(NSString *)aName {
    if (self = [super init]) {
        if (aName) {
            name = [aName retain];
            data = nil;
        } else {
            [self release];
            self = nil;
        }
    }
    return self;
}

- (void)dealloc {
    [data release];
    [name release];
    [super dealloc];
}

- (NSScriptObjectSpecifier *)objectSpecifier {
    NSScriptClassDescription *containerClassDescription = (NSScriptClassDescription *)[NSClassDescription classDescriptionForClass:[NSApp class]];
    return [[[NSNameSpecifier allocWithZone:[self zone]] initWithContainerClassDescription:containerClassDescription containerSpecifier:nil key:@"richText" name:[self name]] autorelease];
}

- (NSString *)name {
    if (name == nil)
        name = [[data base64String] retain];
    return name;
}

- (NSTextStorage *)richText {
    if (data == nil)
        data = [[NSData alloc] initWithBase64String:name];
    return data ? [[[NSTextStorage alloc] initWithRTF:data documentAttributes:nil] autorelease] : nil;
}

@end


@implementation NSApplication (BDSKRichTextFormat)

- (BDSKRichTextFormat *)valueInRichTextWithName:(NSString *)name {
    return [[[BDSKRichTextFormat alloc] initWithName:name] autorelease];
}

@end


@implementation BDSKRichTextForCommand

- (id)performDefaultImplementation {
    id descriptor = [self directParameter];
    
    if ([descriptor isKindOfClass:[NSAppleEventDescriptor class]] == NO) {
		[self setScriptErrorNumber:NSArgumentsWrongScriptError];
    } else {
        NSScriptObjectSpecifier *containerRef = [[[[BDSKRichTextFormat alloc] initWithData:[descriptor data]] autorelease] objectSpecifier];
        if (containerRef)
            return [[[NSPropertySpecifier alloc] initWithContainerClassDescription:[containerRef keyClassDescription] containerSpecifier:containerRef key:@"richText"] autorelease];
    }
    return nil;
}

@end

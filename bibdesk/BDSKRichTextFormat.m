//
//  BDSKRichTextFormat.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 1/19/09.
/*
 This software is Copyright (c) 2009-2011
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
#import "NSData_BDSKExtensions.h"
#import "NSObject_BDSKExtensions.h"


@implementation BDSKRichTextFormat

+ (id)richTextSpecifierWithData:(NSData *)aData {
    BDSKRichTextFormat *rtf = [[BDSKRichTextFormat alloc] initWithData:aData];
    NSScriptObjectSpecifier *rtfSpecifier = [rtf objectSpecifier];
    NSPropertySpecifier *richTextSpecifier = rtfSpecifier ? [[[NSPropertySpecifier alloc] initWithContainerClassDescription:[rtfSpecifier keyClassDescription] containerSpecifier:rtfSpecifier key:@"richText"] autorelease] : nil;
    [rtf release];
    return richTextSpecifier;
}

- (id)initWithData:(NSData *)aData {
    self = [super init];
    if (self) {
        if (aData) {
            data = [aData retain];
        } else {
            [self release];
            self = nil;
        }
    }
    return self;
}

- (id)initWithName:(NSString *)aName {
    NSData *aData = [[NSData alloc] initWithBase64String:aName];
    self = [self initWithData:aData];
    [aData release];
    return self;
}

- (void)dealloc {
    BDSKDESTROY(data);
    [super dealloc];
}

- (NSScriptObjectSpecifier *)objectSpecifier {
    NSScriptClassDescription *containerClassDescription = [NSApp scriptClassDescription];
    return [[[NSNameSpecifier allocWithZone:[self zone]] initWithContainerClassDescription:containerClassDescription containerSpecifier:nil key:@"richTextFormat" name:[self name]] autorelease];
}

- (NSString *)name {
    return [data base64String];
}

- (NSTextStorage *)richText {
    NSError *error;
    return [[[NSTextStorage alloc] initWithData:data options:[NSDictionary dictionary] documentAttributes:NULL error:&error] autorelease];
}

@end


@implementation NSApplication (BDSKRichTextFormat)

- (BDSKRichTextFormat *)valueInRichTextFormatWithName:(NSString *)name {
    return [[[BDSKRichTextFormat alloc] initWithName:name] autorelease];
}

@end


@implementation BDSKRichTextForCommand

- (id)performDefaultImplementation {
    id attrString = [self directParameter];
    
    if ([attrString isKindOfClass:[NSAttributedString class]] == NO) {
		[self setScriptErrorNumber:NSArgumentsWrongScriptError];
        return nil;
    } else {
        return [BDSKRichTextFormat richTextSpecifierWithData:[attrString RTFFromRange:NSMakeRange(0, [attrString length]) documentAttributes:nil]];
    }
}

@end

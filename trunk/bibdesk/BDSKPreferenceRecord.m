//
//  BDSKPreferenceRecord.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 2/18/09.
/*
 This software is Copyright (c) 2009-2012
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

#import "BDSKPreferenceRecord.h"

#define IDENTIFIER_KEY @"identifier"
#define CLASS_KEY @"class"
#define NIB_NAME_KEY @"nibName"
#define TITLE_KEY @"title"
#define LABEL_KEY @"label"
#define TOOL_TIP_KEY @"toolTip"
#define ICON_KEY @"icon"
#define HELP_ANCHOR_KEY @"helpAnchor"
#define HELP_URL_KEY @"helpURL"
#define INITIAL_VALUES_KEY @"initialValues"
#define SEARCH_TERMS_KEY @"searchTerms"

@implementation BDSKPreferenceRecord

- (id)initWithDictionary:(NSDictionary *)aDictionary {
    self = [super init];
    if (self) {
        BDSKPRECONDITION(aDictionary != nil);
        icon = [aDictionary valueForKey:ICON_KEY] ? [[NSImage imageNamed:[aDictionary valueForKey:ICON_KEY]] retain] : nil;
        helpURL = [aDictionary valueForKey:HELP_URL_KEY] ? [[NSURL alloc] initWithString:[aDictionary valueForKey:HELP_URL_KEY]] : nil;
        dictionary = [aDictionary copy];
        BDSKPOSTCONDITION([self identifier] != nil);
        BDSKPOSTCONDITION([self paneClass] != Nil);
    }
    return self;
}

- (void)dealloc {
    BDSKDESTROY(icon);
    BDSKDESTROY(helpURL);
    BDSKDESTROY(dictionary);
    [super dealloc];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %@>", [self class], dictionary];
}

- (NSString *)identifier { return [dictionary objectForKey:IDENTIFIER_KEY]; }

- (Class)paneClass { return NSClassFromString([dictionary valueForKey:CLASS_KEY]); }

- (NSString *)nibName { return [dictionary objectForKey:NIB_NAME_KEY]; }

- (NSString *)title { return [dictionary objectForKey:TITLE_KEY]; }

- (NSString *)label { return [dictionary objectForKey:LABEL_KEY]; }

- (NSString *)toolTip { return [dictionary objectForKey:TOOL_TIP_KEY]; }

- (NSImage *)icon { return icon; }

- (NSString *)helpAnchor { return [dictionary objectForKey:HELP_ANCHOR_KEY]; }

- (NSURL *)helpURL { return helpURL; }

- (NSDictionary *)initialValues { return [dictionary objectForKey:INITIAL_VALUES_KEY]; }

- (NSArray *)searchTerms { return [dictionary objectForKey:SEARCH_TERMS_KEY]; }

- (NSDictionary *)dictionary { return dictionary; }

- (id)valueForUndefinedKey:(NSString *)key { return [dictionary valueForKey:key]; }

@end

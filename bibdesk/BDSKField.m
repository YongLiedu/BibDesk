//
//  BDSKField.m
//  BibDesk
//
//  Created by Christiaan Hofman on 27/11/04.
/*
 This software is Copyright (c) 2004-2010
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

#import "BDSKField.h"
#import "BDSKOwnerProtocol.h"
#import "BDSKTypeManager.h"

/* cmh
A wrapper object around the fields to access them in AppleScript. 
*/
@implementation BDSKField

+ (BOOL)accessInstanceVariablesDirectly {
	return NO;
}

- (id)initWithName:(NSString *)newName bibItem:(BibItem *)newBibItem {
    self = [super init];
    if (self) {
        name = [newName copy];
        bibItem = newBibItem;
    }
    return self;
}

- (void)dealloc {
    BDSKDESTROY(name);
    [super dealloc];
}

- (NSScriptObjectSpecifier *) objectSpecifier {
    if ([self name] && bibItem) {
        NSScriptObjectSpecifier *containerRef = [bibItem objectSpecifier];
        return [[[NSNameSpecifier allocWithZone: [self zone]] 
			  initWithContainerClassDescription: [containerRef keyClassDescription] 
							 containerSpecifier: containerRef 
											key: @"bibFields" 
										   name: [self name]] autorelease];
    } else {
        return nil;
    }
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@: {%@ = %@}",[self class], [self name], [self value]];
}

- (NSString *)name {
    return [[name retain] autorelease];
}

- (NSString *)value {
    return [bibItem valueOfField:name inherit:[name isIntegerField] == NO && [name isNoteField] == NO] ?: @"";
}

- (void)setValue:(NSString *)newValue {
    if ([[bibItem owner] isDocument]) {
        [bibItem setField:name toValue:newValue];
        [[bibItem undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    } else {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot set property of external publication.",@"Error description")];
    }
}

- (BibItem *)publication {
	return bibItem;
}

- (NSString *)bibTeXString {
    return [([bibItem valueOfField:name inherit:[name isIntegerField] == NO && [name isNoteField] == NO] ?: @"") stringAsBibTeXString];
}

- (void)setBibTeXString:(NSString *)newValue {
    if ([[bibItem owner] isDocument]) {
        NSString *value = [NSString stringWithBibTeXString:newValue macroResolver:[bibItem macroResolver] error:NULL];
        if (value) {
            [bibItem setField:name toValue:value];
            [[bibItem undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
        } else {
            NSBeep();
        }
    } else {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot set property of external publication.",@"Error description")];
    }
}

- (BOOL)isInherited {
	return [[bibItem valueOfField:name] isInherited];
}

@end

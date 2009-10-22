//
//  BDSKMacro.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 2/1/07.
/*
 This software is Copyright (c) 2004-2009
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

#import "BDSKMacro.h"
#import "BDSKMacroResolver.h"
#import "BDSKOwnerProtocol.h"
#import "BDSKApplication.h"


@implementation BDSKMacro

+ (BOOL)accessInstanceVariablesDirectly {
	return NO;
}

- (id)initWithName:(NSString *)aName macroResolver:(BDSKMacroResolver *)aMacroResolver {
    self = [super init];
    if (self) {
        name = [aName copy];
        macroResolver = aMacroResolver;
    }
    return self;
}

- (void)dealloc {
    [name release];
    [super dealloc];
}

- (NSScriptObjectSpecifier *) objectSpecifier {
    if ([self name] && macroResolver) {
        id owner = [macroResolver owner];
        NSScriptObjectSpecifier *containerRef = nil;
		NSScriptClassDescription *containerClassDescription = nil;
        if (owner) {
            containerRef = [owner objectSpecifier];
            containerClassDescription = [containerRef keyClassDescription];
        } else {
            containerClassDescription = [NSScriptClassDescription classDescriptionForClass:[BDSKApplication class]];
        }
        return [[[NSNameSpecifier allocWithZone: [self zone]] 
			  initWithContainerClassDescription: containerClassDescription 
							 containerSpecifier: containerRef 
											key: @"macros" 
										   name: [self name]] autorelease];
    } else {
        return nil;
    }
}

- (BOOL)isEqual:(id)other {
    if ([other isMemberOfClass:[self class]] == NO)
        return NO;
    return [[self name] caseInsensitiveCompare:[other name]] == NSOrderedSame && 
           [[self macroResolver] isEqual:[other macroResolver]];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@: {%@ = %@}, resolver = %@",[super description], [self name], [self value], [self macroResolver]];
}

- (NSString *)name {
    return [[name retain] autorelease];
}

- (void)setName:(NSString *)newName {
    if ([macroResolver owner] && [[macroResolver owner] isDocument]) {
        if (name != newName) {
            if ([macroResolver valueOfMacro:name] != nil)
                [macroResolver changeMacroKey:name to:newName];
            [[macroResolver undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
            [name release];
            name = [newName copy];
        }
    } else {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot set property of external macro.",@"Error description")];
    }
}

- (id)value {
	return (id)[macroResolver valueOfMacro:name] ?: (id)[NSNull null];
}

- (void)setValue:(NSString *)newValue {
    if ([macroResolver owner] && [[macroResolver owner] isDocument]) {
        [macroResolver setMacroDefinition:newValue forMacro:name];
        [[macroResolver undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    } else {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot set property of external macro.",@"Error description")];
    }
}

- (id)bibTeXString {
	return (id)[[macroResolver valueOfMacro:name] stringAsBibTeXString] ?: (id)[NSNull null];
}

- (void)setBibTeXString:(NSString *)newValue {
    if ([macroResolver owner] && [[macroResolver owner] isDocument]) {
        NSString *value = [NSString stringWithBibTeXString:newValue macroResolver:macroResolver error:NULL];
        if (value) {
            [macroResolver setMacroDefinition:value forMacro:name];
            [[macroResolver undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
        } else {
            NSBeep();
        }
    } else {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot set property of external macro.",@"Error description")];
    }
}

- (BDSKMacroResolver *)macroResolver {
    return macroResolver;
}

- (BOOL)isExternal {
    return [[macroResolver owner] isDocument] == NO;
}

@end

//
//  BDSKAppController+Scripting.m
//  BibDesk
//
//  Created by Sven-S. Porst on Sat Jul 10 2004.
/*
 This software is Copyright (c) 2004-2012
 Sven-S. Porst. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 - Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in
 the documentation and/or other materials provided with the
 distribution.
 
 - Neither the name of Sven-S. Porst nor the names of any
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

#import "BDSKAppController+Scripting.h"
#import "BDSKScriptHookManager.h"
#import "BDSKTypeManager.h"
#import "BDSKMacroResolver.h"
#import "BDSKMacroResolver+Scripting.h"
#import "BDSKMacro.h"
#import "BDSKTemplate.h"
#import "NSObject_BDSKExtensions.h"


/* ssp
Category on BDSKAppController making the papers folder readable for scripting
*/
@implementation BDSKAppController (Scripting)

+ (BOOL)accessInstanceVariablesDirectly {
	return NO;
}

- (NSString *)papersFolder {
	return [[[NSUserDefaults standardUserDefaults] stringForKey:BDSKPapersFolderPathKey] stringByStandardizingPath];
}

- (NSString *)citeKeyFormat {
	return [[NSUserDefaults standardUserDefaults] stringForKey:BDSKCiteKeyFormatKey];
}

- (NSString *)localFileFormat {
	return [[NSUserDefaults standardUserDefaults] stringForKey:BDSKLocalFileFormatKey];
}

- (NSArray *)allTypes {
	return [[BDSKTypeManager sharedManager] types];
}

- (NSArray *)allFieldNames {
	return [[BDSKTypeManager sharedManager] allFieldNamesIncluding:nil excluding:nil];
}

- (id)clipboard {
    NSScriptClassDescription *containerClassDescription = [NSApp scriptClassDescription];
    return [[[NSPropertySpecifier allocWithZone: [self zone]] 
          initWithContainerClassDescription: containerClassDescription 
                         containerSpecifier: nil // the application is the null container
                                        key: @"clipboard"] autorelease];
}

- (BDSKScriptHook *)valueInScriptHooksWithUniqueID:(NSString *)uniqueID {
	return [[BDSKScriptHookManager sharedManager] scriptHookWithUniqueID:uniqueID];
}

- (BDSKMacro *)valueInMacrosWithName:(NSString *)aName {
    return [[BDSKMacroResolver defaultMacroResolver] valueInMacrosWithName:aName];
}

- (NSArray *)macros {
    return [[BDSKMacroResolver defaultMacroResolver] macros];
}

- (NSArray *)templateNames {
    return [BDSKTemplate allStyleNames];
}

- (NSArray *)plainTextTemplateNames {
    return [BDSKTemplate allStyleNamesForFormat:BDSKPlainTextTemplateFormat];
}

- (NSArray *)richTextTemplateNames {
    return [BDSKTemplate allStyleNamesForFormat:BDSKRichTextTemplateFormat];
}

- (BOOL)application:(NSApplication *)sender delegateHandlesKey:(NSString *)key {
	if ([key isEqualToString:@"papersFolder"] ||
        [key isEqualToString:@"localFileFormat"] ||
        [key isEqualToString:@"citeKeyFormat"] ||
		[key isEqualToString:@"allTypes"] ||
		[key isEqualToString:@"allFieldNames"] ||
		[key isEqualToString:@"macros"] ||
		[key isEqualToString:@"scriptHooks"] ||
		[key isEqualToString:@"templateNames"] ||
		[key isEqualToString:@"plainTextTemplateNames"] ||
		[key isEqualToString:@"richTextTemplateNames"] ||
		[key isEqualToString:@"clipboard"]) 
		return YES;
	return NO;
}

@end

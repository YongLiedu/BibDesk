//
//  NSAlert_BDSKExtensions.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 4/15/09.
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

#import "NSAlert_BDSKExtensions.h"
#import "BDSKRuntime.h"


@interface NSAlert (BDSKApplePrivate)
- (BOOL)_showsDontWarnAgain;
- (void)_setDontWarnMessage:(NSString *)message;
- (BOOL)_dontWarnAgain;
@end

@implementation NSAlert (BDSKExtensions)

#if MAC_OS_X_VERSION_MIN_REQUIRED <= MAC_OS_X_VERSION_10_4
- (void)Tiger_setShowsSuppressionButton:(BOOL)showButton {
    if ([self respondsToSelector:@selector(_setDontWarnMessage:)] == NO)
        return;
    if (showButton)
        [self _setDontWarnMessage:NSLocalizedString(@"Don't ask me again", @"Alert message")];
    else
        [self _setDontWarnMessage:nil];
}

- (BOOL)Tiger_showsSuppressionButton {
    if ([self respondsToSelector:@selector(_showsDontWarnAgain)] == NO)
        return NO;
    return [self _showsDontWarnAgain];
}

- (NSInteger)suppressionButtonState {
    if ([self respondsToSelector:@selector(suppressionButton)])
        return [[self suppressionButton] state];
    if ([self respondsToSelector:@selector(_dontWarnAgain)])
        return [self _dontWarnAgain] ? NSOnState : NSOffState;
    return NSOffState;
}

+ (void)load {
    BDSKAddInstanceMethodImplementationFromSelector(self, @selector(setShowsSuppressionButton:), @selector(Tiger_setShowsSuppressionButton:));
    BDSKAddInstanceMethodImplementationFromSelector(self, @selector(showsSuppressionButton), @selector(Tiger_showsSuppressionButton));
}
#else
#warning fixme: remove NSAlert category
#endif

@end

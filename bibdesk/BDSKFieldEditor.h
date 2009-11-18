//
//  BDSKFieldEditor.h
//  Bibdesk
//
//  Created by Christiaan Hofman on 19/12/05.
/*
 This software is Copyright (c) 2005-2009
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

#import <Cocoa/Cocoa.h>


@protocol BDSKFieldEditorDelegate <NSTextViewDelegate>
@optional

- (NSRange)textView:(NSTextView *)textView rangeForUserCompletion:(NSRange)charRange;
- (BOOL)textViewShouldAutoComplete:(NSTextView *)textView;
- (BOOL)textViewShouldLinkKeys:(NSTextView *)textView;
- (BOOL)textView:(NSTextView *)textView isValidKey:(NSString *)key;
@end


@interface BDSKFieldEditor : NSTextView {
	NSMutableArray *delegatedDraggedTypes;
    BOOL isEditing;
}
- (void)registerForDelegatedDraggedTypes:(NSArray *)pboardTypes;
#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5
- (id <BDSKFieldEditorDelegate>)delegate;
- (void)setDelegate:(id <BDSKFieldEditorDelegate>)newDelegate;
#endif
@end

// the above delegate methods could be implemented by calling these delegate methods for NSControl subclasses that actually have a delegate
// currently implemented for NSTextField and NSTableView
@protocol BDSKControlFieldEditorDelegate <NSControlTextEditingDelegate>
@optional
- (NSRange)control:(NSControl *)control textView:(NSTextView *)textView rangeForUserCompletion:(NSRange)charRange;
- (BOOL)control:(NSControl *)control textViewShouldAutoComplete:(NSTextView *)textView;
- (BOOL)control:(NSControl *)control textViewShouldLinkKeys:(NSTextView *)textView;
- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView isValidKey:(NSString *)key;
- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView clickedOnLink:(id)aLink atIndex:(NSUInteger)charIndex;
@end


@interface NSTextField (BDSKFieldEditorDelegate) <BDSKFieldEditorDelegate>
@end

@interface NSTableView (BDSKFieldEditorDelegate) <BDSKFieldEditorDelegate>
@end

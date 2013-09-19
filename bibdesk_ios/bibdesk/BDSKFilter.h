//
//  BDSKFilter.h
//  Bibdesk
//
//  Created by Christiaan Hofman on 17/3/05.
/*
 This software is Copyright (c) 2005-2013
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

#import <Foundation/Foundation.h>

enum {
	BDSKAnd = 0,
	BDSKOr = 1
};
typedef NSUInteger BDSKConjunction;

@protocol BDSKSmartGroup;
@class BDSKCondition, BibItem;

@interface BDSKFilter : NSObject <NSCopying, NSCoding> {
	NSMutableArray *conditions;
	BDSKConjunction conjunction;
    id<BDSKSmartGroup> group;
	NSUndoManager *undoManager;
}

- (id)initWithConditions:(NSArray *)aConditions conjunction:(BDSKConjunction)aConjunction;
- (id)initWithDictionary:(NSDictionary *)dictionary;

- (NSDictionary *)dictionaryValue;

- (NSArray *)filterItems:(NSArray *)items;
- (BOOL)testItem:(BibItem *)item;

- (NSArray *)conditions;
- (void)setConditions:(NSArray *)newConditions;
- (BDSKConjunction)conjunction;
- (void)setConjunction:(BDSKConjunction)newConjunction;

- (id<BDSKSmartGroup>)group;
- (void)setGroup:(id<BDSKSmartGroup>)newGroup;

- (NSUndoManager *)undoManager;

@end

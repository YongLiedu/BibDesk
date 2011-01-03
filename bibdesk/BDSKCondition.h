//
//  BDSKCondition.h
//  Bibdesk
//
//  Created by Christiaan Hofman on 17/3/05.
/*
 This software is Copyright (c) 2005-2011
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

// this should correspond to the tags of the items in the popup
enum {
	BDSKGroupContain = 0,
	BDSKGroupNotContain,
	BDSKContain,
	BDSKNotContain,
	BDSKEqual,
	BDSKNotEqual,
	BDSKStartWith,
	BDSKEndWith,
	BDSKSmaller,
	BDSKLarger
};
typedef NSUInteger BDSKStringComparison;

// this should correspond to the tags of the items in the popup
enum {
	BDSKCountEqual = 0,
	BDSKCountNotEqual,
	BDSKCountLarger,
	BDSKCountSmaller,
	BDSKAttachmentContain,
	BDSKAttachmentNotContain,
	BDSKAttachmentStartWith,
	BDSKAttachmentEndWith
};
typedef NSUInteger BDSKAttachmentComparison;

// this should correspond to the tags of the items in the popup
enum {
    BDSKToday = 0, 
    BDSKYesterday, 
    BDSKThisWeek, 
    BDSKLastWeek, 
    BDSKExactly, 
    BDSKInLast, 
    BDSKNotInLast, 
    BDSKBetween, 
    BDSKDate, 
    BDSKAfterDate, 
    BDSKBeforeDate, 
    BDSKInDateRange
};
typedef NSUInteger BDSKDateComparison;

enum {
    BDSKDateField,
    BDSKLinkedField,
    BDSKStringField,
    BDSKBooleanField,
    BDSKTriStateField,
    BDSKRatingField
};

@protocol BDSKSmartGroup;
@class BibItem;

@interface BDSKCondition : NSObject <NSCopying, NSCoding> {
	NSString *key;
	BDSKStringComparison stringComparison;
	BDSKAttachmentComparison attachmentComparison;
	BDSKDateComparison dateComparison;
	NSString *stringValue;
    NSInteger countValue;
    NSInteger numberValue;
    NSInteger andNumberValue;
    NSInteger periodValue;
    NSDate *dateValue;
    NSDate *toDateValue;
    id<BDSKSmartGroup> group;
	NSDate *cachedStartDate;
	NSDate *cachedEndDate;
	NSTimer *cacheTimer;
}

+ (NSString *)dictionaryVersion;

- (id)initWithDictionary:(NSDictionary *)dictionary;

- (NSDictionary *)dictionaryValue;

- (BOOL)isSatisfiedByItem:(BibItem *)item;

// Generic accessors
- (NSString *)key;
- (void)setKey:(NSString *)newKey;
- (NSString *)value;
- (void)setValue:(NSString *)newValue;
- (NSInteger)comparison;
- (void)setComparison:(NSInteger)newComparison;

// String accessors
- (BDSKStringComparison)stringComparison;
- (void)setStringComparison:(BDSKStringComparison)newComparison;
- (NSString *)stringValue;
- (void)setStringValue:(NSString *)newValue;

// Count accessors
- (BDSKAttachmentComparison)attachmentComparison;
- (void)setAttachmentComparison:(BDSKAttachmentComparison)newComparison;
- (NSInteger)countValue;
- (void)setCountValue:(NSInteger)newValue;

// Date accessors
- (BDSKDateComparison)dateComparison;
- (void)setDateComparison:(BDSKDateComparison)newComparison;
- (NSInteger)numberValue;
- (void)setNumberValue:(NSInteger)value;
- (NSInteger)andNumberValue;
- (void)setAndNumberValue:(NSInteger)value;
- (NSInteger)periodValue;
- (void)setPeriodValue:(NSInteger)value;
- (NSDate *)dateValue;
- (void)setDateValue:(NSDate *)value;
- (NSDate *)toDateValue;
- (void)setToDateValue:(NSDate *)value;

- (void)setDefaultComparison;
- (void)setDefaultValue;

- (BOOL)isDateCondition;
- (BOOL)isAttachmentCondition;

- (id<BDSKSmartGroup>)group;
- (void)setGroup:(id<BDSKSmartGroup>)newGroup;

@end


@interface NSString (BDSKConditionExtensions)
- (NSInteger)fieldType;
@end

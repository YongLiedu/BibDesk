//
//  BDSKCondition+Scripting.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 2/18/08.
/*
 This software is Copyright (c) 2008-2012
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

#import "BDSKCondition+Scripting.h"
#import "NSDate_BDSKExtensions.h"
#import "BDSKSmartGroup.h"
#import "BDSKFilter.h"

enum {
	BDSKScriptingGroupContain = 'CGCt',
	BDSKScriptingGroupNotContain = 'CGNC',
	BDSKScriptingContain = 'CCnt',
	BDSKScriptingNotContain = 'CNCt',
	BDSKScriptingEqual = 'CEqu',
	BDSKScriptingNotEqual = 'CNEq',
	BDSKScriptingStartWith = 'CStt',
	BDSKScriptingEndWith = 'CEnd',
	BDSKScriptingSmaller = 'CBef',
	BDSKScriptingLarger = 'CAft'
};

enum {
	BDSKScriptingCountEqual = 'CCEq',
	BDSKScriptingCountNotEqual = 'CCNE',
	BDSKScriptingCountLarger = 'CCLa',
	BDSKScriptingCountSmaller = 'CCSm'
};

enum {
    BDSKScriptingToday = 'CTdy', 
    BDSKScriptingYesterday = 'CYst', 
    BDSKScriptingThisWeek = 'CTWk', 
    BDSKScriptingLastWeek = 'CLWk', 
    BDSKScriptingExactly = 'CAgo', 
    BDSKScriptingInLast = 'CLPe', 
    BDSKScriptingNotInLast = 'CNLP', 
    BDSKScriptingBetween = 'CPeR', 
    BDSKScriptingDate = 'CDat', 
    BDSKScriptingAfterDate = 'CADt', 
    BDSKScriptingBeforeDate = 'CBDt', 
    BDSKScriptingInDateRange = 'CDtR'
};

@interface BDSKCondition (BDSKPrivate)
- (void)startObserving;
@end

@implementation BDSKCondition (Scripting)

- (id)initWithScriptingProperties:(NSDictionary *)properties {
    self = [self init];
    if (self) {
        
        [self setKey:[properties objectForKey:@"scriptingKey"]];
        
        NSNumber *comparisonNumber = [properties objectForKey:@"scriptingComparison"];
        if (comparisonNumber == nil) {
        } else if ([self isDateCondition]) {
            switch ([comparisonNumber unsignedIntValue]) {
                case BDSKScriptingToday:       [self setDateComparison:BDSKToday];         break; 
                case BDSKScriptingYesterday:   [self setDateComparison:BDSKYesterday];     break; 
                case BDSKScriptingThisWeek:    [self setDateComparison:BDSKThisWeek];      break; 
                case BDSKScriptingLastWeek:    [self setDateComparison:BDSKLastWeek];      break; 
                case BDSKScriptingExactly:     [self setDateComparison:BDSKExactly];       break; 
                case BDSKScriptingInLast:      [self setDateComparison:BDSKInLast];        break; 
                case BDSKScriptingNotInLast:   [self setDateComparison:BDSKNotInLast];     break; 
                case BDSKScriptingBetween:     [self setDateComparison:BDSKBetween];       break; 
                case BDSKScriptingDate:        [self setDateComparison:BDSKDate];          break; 
                case BDSKScriptingAfterDate:   [self setDateComparison:BDSKAfterDate];     break; 
                case BDSKScriptingBeforeDate:  [self setDateComparison:BDSKBeforeDate];    break; 
                case BDSKScriptingInDateRange: [self setDateComparison:BDSKInDateRange];   break;
                default:
                {
                    NSScriptCommand *cmd = [NSScriptCommand currentCommand];
                    [cmd setScriptErrorNumber:NSArgumentsWrongScriptError];
                    [cmd setScriptErrorString:NSLocalizedString(@"Invalid condition for smart condition.",@"Error description")];
                    break;
                }
            }
        } else if ([self isAttachmentCondition]) {
            switch ([comparisonNumber unsignedIntValue]) {
                case BDSKScriptingCountEqual:      [self setAttachmentComparison:BDSKCountEqual];           break;
                case BDSKScriptingCountNotEqual:   [self setAttachmentComparison:BDSKCountNotEqual];        break;
                case BDSKScriptingCountLarger:     [self setAttachmentComparison:BDSKCountLarger];          break;
                case BDSKScriptingCountSmaller:    [self setAttachmentComparison:BDSKCountSmaller];         break;
                case BDSKScriptingContain:         [self setAttachmentComparison:BDSKAttachmentContain];    break;
                case BDSKScriptingNotContain:      [self setAttachmentComparison:BDSKAttachmentNotContain]; break;
                case BDSKScriptingStartWith:       [self setAttachmentComparison:BDSKAttachmentStartWith];  break;
                case BDSKScriptingEndWith:         [self setAttachmentComparison:BDSKAttachmentEndWith];    break;
                default:
                {
                    NSScriptCommand *cmd = [NSScriptCommand currentCommand];
                    [cmd setScriptErrorNumber:NSArgumentsWrongScriptError];
                    [cmd setScriptErrorString:NSLocalizedString(@"Invalid condition for smart condition.",@"Error description")];
                    break;
                }
            }
        } else {
            switch ([comparisonNumber unsignedIntValue]) {
                case BDSKScriptingGroupContain:    [self setStringComparison:BDSKGroupContain];    break;
                case BDSKScriptingGroupNotContain: [self setStringComparison:BDSKGroupNotContain]; break;
                case BDSKScriptingContain:         [self setStringComparison:BDSKContain];         break;
                case BDSKScriptingNotContain:      [self setStringComparison:BDSKNotContain];      break;
                case BDSKScriptingEqual:           [self setStringComparison:BDSKEqual];           break;
                case BDSKScriptingNotEqual:        [self setStringComparison:BDSKNotEqual];        break;
                case BDSKScriptingStartWith:       [self setStringComparison:BDSKStartWith];       break;
                case BDSKScriptingEndWith:         [self setStringComparison:BDSKEndWith];         break;
                case BDSKScriptingSmaller:         [self setStringComparison:BDSKSmaller];         break;
                case BDSKScriptingLarger:          [self setStringComparison:BDSKLarger];          break;
                default:
                {
                    NSScriptCommand *cmd = [NSScriptCommand currentCommand];
                    [cmd setScriptErrorNumber:NSArgumentsWrongScriptError];
                    [cmd setScriptErrorString:NSLocalizedString(@"Invalid condition for smart condition.",@"Error description")];
                    break;
                }
            }
        }
        
        id newValue = [properties objectForKey:@"scriptingValue"];
        if (newValue == nil) {
        } else if ([self isDateCondition]) {
            if ([newValue isKindOfClass:[NSDictionary class]]) {
                id value;
                if ((value = [newValue objectForKey:@"numberValue"])) {
                    [self setNumberValue:[value integerValue]];
                    if ((value = [newValue objectForKey:@"periodValue"]))
                        [self setPeriodValue:[value integerValue]];
                    if ((value = [newValue objectForKey:@"andNumberValue"]))
                        [self setAndNumberValue:[value integerValue]];
                } else if ((value = [newValue objectForKey:@"dateValue"])) {
                    [self setDateValue:value];
                    if ((value = [newValue objectForKey:@"toDateValue"]))
                        [self setToDateValue:value];
                }
            } else if ([newValue isKindOfClass:[NSDate class]]) {
                [self setDateValue:newValue];
            } else if (newValue && [newValue isEqual:[NSNull null]] == NO) {
                NSScriptCommand *cmd = [NSScriptCommand currentCommand];
                [cmd setScriptErrorNumber:NSArgumentsWrongScriptError];
                [cmd setScriptErrorString:NSLocalizedString(@"Invalid value for smart condition.",@"Error description")];
            }
        } else if ([self isAttachmentCondition]) {
            if ([newValue isKindOfClass:[NSNumber class]] || [newValue isKindOfClass:[NSString class]]) {
                switch ([self attachmentComparison]) {
                    case BDSKCountEqual:
                    case BDSKCountNotEqual:
                    case BDSKCountLarger:
                    case BDSKCountSmaller:
                        [self setCountValue:[newValue integerValue]];
                        break;
                    case BDSKAttachmentContain:
                    case BDSKAttachmentNotContain:
                    case BDSKAttachmentStartWith:
                    case BDSKAttachmentEndWith:
                    default:
                        [self setStringValue:newValue];
                        break;
                }
            } else {
                NSScriptCommand *cmd = [NSScriptCommand currentCommand];
                [cmd setScriptErrorNumber:NSArgumentsWrongScriptError];
                [cmd setScriptErrorString:NSLocalizedString(@"Invalid value for smart condition.",@"Error description")];
            }
        } else {
            if ([newValue isKindOfClass:[NSString class]]) {
                [self setStringValue:newValue];
            } else {
                NSScriptCommand *cmd = [NSScriptCommand currentCommand];
                [cmd setScriptErrorNumber:NSArgumentsWrongScriptError];
                [cmd setScriptErrorString:NSLocalizedString(@"Invalid value for smart condition.",@"Error description")];
            }
        }
    }
    return self;
}

- (NSScriptObjectSpecifier *)objectSpecifier {
	NSArray *conditions = [[[self group] filter] conditions];
	NSUInteger idx = [conditions indexOfObjectIdenticalTo:self];
    if ([self group] && idx != NSNotFound) {
        NSScriptObjectSpecifier *containerRef = [(id)[self group] objectSpecifier];
        return [[[NSIndexSpecifier allocWithZone:[self zone]] initWithContainerClassDescription:[containerRef keyClassDescription] containerSpecifier:containerRef key:@"conditions" index:idx] autorelease];
    } else {
        return nil;
    }
}

- (NSString *)scriptingKey {
    return [self key];
}

- (NSInteger)scriptingComparison {
    if ([self isDateCondition]) {
        switch ([self dateComparison]) {
            case BDSKToday:         return BDSKScriptingToday;
            case BDSKYesterday:     return BDSKScriptingYesterday;
            case BDSKThisWeek:      return BDSKScriptingThisWeek;
            case BDSKLastWeek:      return BDSKScriptingLastWeek;
            case BDSKExactly:       return BDSKScriptingExactly;
            case BDSKInLast:        return BDSKScriptingInLast;
            case BDSKNotInLast:     return BDSKScriptingNotInLast;
            case BDSKBetween:       return BDSKScriptingBetween;
            case BDSKDate:          return BDSKScriptingDate;
            case BDSKAfterDate:     return BDSKScriptingAfterDate;
            case BDSKBeforeDate:    return BDSKScriptingBeforeDate;
            case BDSKInDateRange:   return BDSKInDateRange;
            default:                return BDSKScriptingToday;
        }
    } else if ([self isAttachmentCondition]) {
        switch ([self attachmentComparison]) {
            case BDSKCountEqual:            return BDSKScriptingCountEqual;
            case BDSKCountNotEqual:         return BDSKScriptingCountNotEqual;
            case BDSKCountLarger:           return BDSKScriptingCountLarger;
            case BDSKCountSmaller:          return BDSKScriptingCountSmaller;
            case BDSKAttachmentContain:     return BDSKScriptingContain;
            case BDSKAttachmentNotContain:  return BDSKScriptingNotContain;
            case BDSKAttachmentStartWith:   return BDSKScriptingStartWith;
            case BDSKAttachmentEndWith:     return BDSKScriptingEndWith;
            default:                        return BDSKScriptingCountEqual;
        }
    } else {
        switch ([self stringComparison]) {
            case BDSKGroupContain:      return BDSKScriptingGroupContain;
            case BDSKGroupNotContain:   return BDSKScriptingGroupNotContain;
            case BDSKContain:           return BDSKScriptingContain;
            case BDSKNotContain:        return BDSKScriptingNotContain;
            case BDSKEqual:             return BDSKScriptingEqual;
            case BDSKNotEqual:          return BDSKScriptingNotEqual;
            case BDSKStartWith:         return BDSKScriptingStartWith;
            case BDSKEndWith:           return BDSKScriptingEndWith;
            case BDSKSmaller:           return BDSKScriptingSmaller;
            case BDSKLarger:            return BDSKScriptingLarger;
            default:                    return BDSKScriptingContain;
        }
    }
}

- (id)scriptingValue {
    if ([self isDateCondition]) {
        switch ([self dateComparison]) {
            case BDSKExactly: 
            case BDSKInLast: 
            case BDSKNotInLast: 
                return [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:numberValue], @"numberValue", [NSNumber numberWithInteger:periodValue], @"periodValue", nil];
            case BDSKBetween:
                return [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:numberValue], @"numberValue", [NSNumber numberWithInteger:andNumberValue], @"andNumberValue", [NSNumber numberWithInteger:periodValue], @"periodValue", nil];
            case BDSKDate: 
            case BDSKAfterDate: 
            case BDSKBeforeDate: 
                return [NSDictionary dictionaryWithObjectsAndKeys:dateValue, @"dateValue", nil];
            case BDSKInDateRange:
                return [NSDictionary dictionaryWithObjectsAndKeys:dateValue, @"dateValue", toDateValue, @"dateValue", nil];
            default:
                return nil;
        }
    } else if ([self isAttachmentCondition]) {
        switch ([self attachmentComparison]) {
            case BDSKCountEqual:
            case BDSKCountNotEqual:
            case BDSKCountLarger:
            case BDSKCountSmaller:
                return [NSNumber numberWithInteger:countValue];
            case BDSKAttachmentContain:
            case BDSKAttachmentNotContain:
            case BDSKAttachmentStartWith:
            case BDSKAttachmentEndWith:
            default:
                return [self stringValue];
        }
    } else {
        return [self stringValue];
    }
}

@end

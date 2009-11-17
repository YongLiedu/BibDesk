//
//  BDSKCondition+Scripting.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 2/18/08.
/*
 This software is Copyright (c) 2008-2009
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
	BDSKASGroupContain = 'CGCt',
	BDSKASGroupNotContain = 'CGNC',
	BDSKASContain = 'CCnt',
	BDSKASNotContain = 'CNCt',
	BDSKASEqual = 'CEqu',
	BDSKASNotEqual = 'CNEq',
	BDSKASStartWith = 'CStt',
	BDSKASEndWith = 'CEnd',
	BDSKASSmaller = 'CBef',
	BDSKASLarger = 'CAft'
};

enum {
	BDSKASCountEqual = 'CCEq',
	BDSKASCountNotEqual = 'CCNE',
	BDSKASCountLarger = 'CCLa',
	BDSKASCountSmaller = 'CCSm'
};

enum {
    BDSKASToday = 'CTdy', 
    BDSKASYesterday = 'CYst', 
    BDSKASThisWeek = 'CTWk', 
    BDSKASLastWeek = 'CLWk', 
    BDSKASExactly = 'CAgo', 
    BDSKASInLast = 'CLPe', 
    BDSKASNotInLast = 'CNLP', 
    BDSKASBetween = 'CPeR', 
    BDSKASDate = 'CDat', 
    BDSKASAfterDate = 'CADt', 
    BDSKASBeforeDate = 'CBDt', 
    BDSKASInDateRange = 'CDtR'
};

enum {
    BDSKASPeriodDay = 'PDay',
    BDSKASPeriodWeek = 'PWek',
    BDSKASPeriodMonth = 'PMnt',
    BDSKASPeriodYear = 'PYer'
};

@interface BDSKCondition (BDSKPrivate)
- (void)startObserving;
@end

@implementation BDSKCondition (Scripting)

- (id)initWithScriptingProperties:(NSDictionary *)properties {
    if (self = [self init]) {
        
        [self setKey:[properties objectForKey:@"scriptingKey"]];
        
        NSNumber *comparisonNumber = [properties objectForKey:@"scriptingComparison"];
        if (comparisonNumber == nil) {
        } else if ([self isDateCondition]) {
            switch ([comparisonNumber unsignedIntValue]) {
                case BDSKASToday:       [self setDateComparison:BDSKToday];         break; 
                case BDSKASYesterday:   [self setDateComparison:BDSKYesterday];     break; 
                case BDSKASThisWeek:    [self setDateComparison:BDSKThisWeek];      break; 
                case BDSKASLastWeek:    [self setDateComparison:BDSKLastWeek];      break; 
                case BDSKASExactly:     [self setDateComparison:BDSKExactly];       break; 
                case BDSKASInLast:      [self setDateComparison:BDSKInLast];        break; 
                case BDSKASNotInLast:   [self setDateComparison:BDSKNotInLast];     break; 
                case BDSKASBetween:     [self setDateComparison:BDSKBetween];       break; 
                case BDSKASDate:        [self setDateComparison:BDSKDate];          break; 
                case BDSKASAfterDate:   [self setDateComparison:BDSKAfterDate];     break; 
                case BDSKASBeforeDate:  [self setDateComparison:BDSKBeforeDate];    break; 
                case BDSKASInDateRange: [self setDateComparison:BDSKInDateRange];   break;
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
                case BDSKASCountEqual:      [self setAttachmentComparison:BDSKCountEqual];           break;
                case BDSKASCountNotEqual:   [self setAttachmentComparison:BDSKCountNotEqual];        break;
                case BDSKASCountLarger:     [self setAttachmentComparison:BDSKCountLarger];          break;
                case BDSKASCountSmaller:    [self setAttachmentComparison:BDSKCountSmaller];         break;
                case BDSKASContain:         [self setAttachmentComparison:BDSKAttachmentContain];    break;
                case BDSKASNotContain:      [self setAttachmentComparison:BDSKAttachmentNotContain]; break;
                case BDSKASStartWith:       [self setAttachmentComparison:BDSKAttachmentStartWith];  break;
                case BDSKASEndWith:         [self setAttachmentComparison:BDSKAttachmentEndWith];    break;
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
                case BDSKASGroupContain:    [self setStringComparison:BDSKGroupContain];    break;
                case BDSKASGroupNotContain: [self setStringComparison:BDSKGroupNotContain]; break;
                case BDSKASContain:         [self setStringComparison:BDSKContain];         break;
                case BDSKASNotContain:      [self setStringComparison:BDSKNotContain];      break;
                case BDSKASEqual:           [self setStringComparison:BDSKEqual];           break;
                case BDSKASNotEqual:        [self setStringComparison:BDSKNotEqual];        break;
                case BDSKASStartWith:       [self setStringComparison:BDSKStartWith];       break;
                case BDSKASEndWith:         [self setStringComparison:BDSKEndWith];         break;
                case BDSKASSmaller:         [self setStringComparison:BDSKSmaller];         break;
                case BDSKASLarger:          [self setStringComparison:BDSKLarger];          break;
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
                if (value = [newValue objectForKey:@"numberValue"]) {
                    [self setNumberValue:[value integerValue]];
                    if (value = [newValue objectForKey:@"periodValue"]) {
                        switch ([value unsignedIntValue]) {
                            case BDSKASPeriodDay:   [self setPeriodValue:BDSKPeriodDay];    break;
                            case BDSKASPeriodWeek:  [self setPeriodValue:BDSKPeriodWeek];   break;
                            case BDSKASPeriodMonth: [self setPeriodValue:BDSKPeriodMonth];  break;
                            case BDSKASPeriodYear:  [self setPeriodValue:BDSKPeriodYear];   break;
                        }
                    }
                    if (value = [newValue objectForKey:@"andNumberValue"])
                        [self setAndNumberValue:[value integerValue]];
                } else if (value = [newValue objectForKey:@"dateValue"]) {
                    [self setDateValue:[[[NSCalendarDate alloc] initWithTimeInterval:0.0 sinceDate:value] autorelease]];
                    if (value = [newValue objectForKey:@"toDateValue"])
                        [self setToDateValue:[[[NSCalendarDate alloc] initWithTimeInterval:0.0 sinceDate:value] autorelease]];
                }
            } else if ([newValue isKindOfClass:[NSDate class]]) {
                [self setDateValue:[[[NSCalendarDate alloc] initWithTimeInterval:0.0 sinceDate:newValue] autorelease]];
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
            case BDSKToday:         return BDSKASToday;
            case BDSKYesterday:     return BDSKASYesterday;
            case BDSKThisWeek:      return BDSKASThisWeek;
            case BDSKLastWeek:      return BDSKASLastWeek;
            case BDSKExactly:       return BDSKASExactly;
            case BDSKInLast:        return BDSKASInLast;
            case BDSKNotInLast:     return BDSKASNotInLast;
            case BDSKBetween:       return BDSKASBetween;
            case BDSKDate:          return BDSKASDate;
            case BDSKAfterDate:     return BDSKASAfterDate;
            case BDSKBeforeDate:    return BDSKASBeforeDate;
            case BDSKInDateRange:   return BDSKInDateRange;
            default:                return BDSKASToday;
        }
    } else if ([self isAttachmentCondition]) {
        switch ([self attachmentComparison]) {
            case BDSKCountEqual:            return BDSKASCountEqual;
            case BDSKCountNotEqual:         return BDSKASCountNotEqual;
            case BDSKCountLarger:           return BDSKASCountLarger;
            case BDSKCountSmaller:          return BDSKASCountSmaller;
            case BDSKAttachmentContain:     return BDSKASContain;
            case BDSKAttachmentNotContain:  return BDSKASNotContain;
            case BDSKAttachmentStartWith:   return BDSKASStartWith;
            case BDSKAttachmentEndWith:     return BDSKASEndWith;
            default:                        return BDSKASCountEqual;
        }
    } else {
        switch ([self stringComparison]) {
            case BDSKGroupContain:      return BDSKASGroupContain;
            case BDSKGroupNotContain:   return BDSKASGroupNotContain;
            case BDSKContain:           return BDSKASContain;
            case BDSKNotContain:        return BDSKASNotContain;
            case BDSKEqual:             return BDSKASEqual;
            case BDSKNotEqual:          return BDSKASNotEqual;
            case BDSKStartWith:         return BDSKASStartWith;
            case BDSKEndWith:           return BDSKASEndWith;
            case BDSKSmaller:           return BDSKASSmaller;
            case BDSKLarger:            return BDSKASLarger;
            default:                    return BDSKASContain;
        }
    }
}

- (id)scriptingValue {
    if ([self isDateCondition]) {
        NSInteger scriptingPeriodValue = BDSKASPeriodDay;
        switch ([self periodValue]) {
            case BDSKPeriodDay:     scriptingPeriodValue = BDSKASPeriodDay;     break;
            case BDSKPeriodWeek:    scriptingPeriodValue = BDSKASPeriodWeek;    break;
            case BDSKPeriodMonth:   scriptingPeriodValue = BDSKASPeriodMonth;   break;
            case BDSKPeriodYear:    scriptingPeriodValue = BDSKASPeriodYear;    break;
        }
        switch ([self dateComparison]) {
            case BDSKExactly: 
            case BDSKInLast: 
            case BDSKNotInLast: 
                return [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:numberValue], @"numberValue", [NSNumber numberWithInteger:scriptingPeriodValue], @"periodValue", nil];
            case BDSKBetween:
                return [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:numberValue], @"numberValue", [NSNumber numberWithInteger:andNumberValue], @"andNumberValue", [NSNumber numberWithInteger:scriptingPeriodValue], @"periodValue", nil];
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

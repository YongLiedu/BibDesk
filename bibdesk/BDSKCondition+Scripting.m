//
//  BDSKCondition+Scripting.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 2/18/08.
/*
 This software is Copyright (c) 2008
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
    BDSKASBeforeDate = 'CCDt', 
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

- (NSScriptObjectSpecifier *)objectSpecifier {
	NSArray *conditions = [[[self group] filter] conditions];
	unsigned idx = [conditions indexOfObjectIdenticalTo:self];
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

- (void)setScriptingKey:(NSString *)newKey {
    NSScriptCommand *cmd = [NSScriptCommand currentCommand];
    if ([cmd isKindOfClass:[NSCreateCommand class]] == NO) {
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot edit smart condition.",@"Error description")];
    }
}

- (int)scriptingComparison {
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
    } else if ([self isCountCondition]) {
        switch ([self countComparison]) {
            case BDSKCountEqual:    return BDSKASCountEqual;
            case BDSKCountNotEqual: return BDSKASCountNotEqual;
            case BDSKCountLarger:   return BDSKASCountLarger;
            case BDSKCountSmaller:  return BDSKASCountSmaller;
            default:                return BDSKASCountEqual;
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

- (void)setScriptingComparison:(int)newComparison {
    NSScriptCommand *cmd = [NSScriptCommand currentCommand];
    if ([cmd isKindOfClass:[NSCreateCommand class]] == NO) {
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot edit smart condition.",@"Error description")];
    } else {
        if ([self isDateCondition]) {
            switch (newComparison) {
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
                    [cmd setScriptErrorNumber:NSArgumentsWrongScriptError];
                    [cmd setScriptErrorString:NSLocalizedString(@"Invalid condition for smart condition.",@"Error description")];
                    break;
            }
        } else if ([self isCountCondition]) {
            switch (newComparison) {
                case BDSKASCountEqual:      [self setCountComparison:BDSKCountEqual];       break;
                case BDSKASCountNotEqual:   [self setCountComparison:BDSKCountNotEqual];    break;
                case BDSKASCountLarger:     [self setCountComparison:BDSKCountLarger];      break;
                case BDSKASCountSmaller:    [self setCountComparison:BDSKCountSmaller];     break;
                default:
                    [cmd setScriptErrorNumber:NSArgumentsWrongScriptError];
                    [cmd setScriptErrorString:NSLocalizedString(@"Invalid condition for smart condition.",@"Error description")];
                    break;
            }
        } else {
            switch (newComparison) {
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
                    [cmd setScriptErrorNumber:NSArgumentsWrongScriptError];
                    [cmd setScriptErrorString:NSLocalizedString(@"Invalid condition for smart condition.",@"Error description")];
                    break;
            }
        }
    }
}

- (id)scriptingValue {
    if ([self isDateCondition]) {
        int scriptingPeriodValue = BDSKASPeriodDay;
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
                return [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:numberValue], @"numberValue", [NSNumber numberWithInt:scriptingPeriodValue], @"periodValue", nil];
            case BDSKBetween:
                return [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:numberValue], @"numberValue", [NSNumber numberWithInt:andNumberValue], @"andNumberValue", [NSNumber numberWithInt:scriptingPeriodValue], @"periodValue", nil];
            case BDSKDate: 
            case BDSKAfterDate: 
            case BDSKBeforeDate: 
                return [NSDictionary dictionaryWithObjectsAndKeys:dateValue, @"dateValue", nil];
            case BDSKInDateRange:
                return [NSDictionary dictionaryWithObjectsAndKeys:dateValue, @"dateValue", toDateValue, @"dateValue", nil];
            default:
                return [NSNull null];
        }
    } else if ([self isCountCondition]) {
        return [NSNumber numberWithInt:countValue];
    } else {
        return [self stringValue];
    }
}

- (void)setScriptingValue:(id)newValue {
    NSScriptCommand *cmd = [NSScriptCommand currentCommand];
    if ([cmd isKindOfClass:[NSCreateCommand class]] == NO) {
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot edit smart condition.",@"Error description")];
    } else if ([self isDateCondition]) {
        if ([newValue isKindOfClass:[NSDictionary class]]) {
            id value;
            if (value = [newValue objectForKey:@"numberValue"]) {
                [self setNumberValue:[value intValue]];
                if (value = [newValue objectForKey:@"periodValue"]) {
                    switch ([value intValue]) {
                        case BDSKASPeriodDay:   [self setPeriodValue:BDSKPeriodDay];    break;
                        case BDSKASPeriodWeek:  [self setPeriodValue:BDSKPeriodWeek];   break;
                        case BDSKASPeriodMonth: [self setPeriodValue:BDSKPeriodMonth];  break;
                        case BDSKASPeriodYear:  [self setPeriodValue:BDSKPeriodYear];   break;
                    }
                }
                if (value = [newValue objectForKey:@"andNumberValue"])
                    [self setAndNumberValue:[value intValue]];
            } else if (value = [newValue objectForKey:@"dateValue"]) {
                [self setDateValue:value];
                if (value = [newValue objectForKey:@"toDateValue"])
                    [self setToDateValue:value];
            }
        } else if ([newValue isKindOfClass:[NSDate class]]) {
            [self setDateValue:newValue];
        } else if (newValue && [newValue isEqual:[NSNull null]] == NO) {
            [cmd setScriptErrorNumber:NSArgumentsWrongScriptError];
            [cmd setScriptErrorString:NSLocalizedString(@"Invalid value for smart condition.",@"Error description")];
        }
    } else if ([self isCountCondition]) {
        if ([newValue isKindOfClass:[NSNumber class]] || [newValue isKindOfClass:[NSString class]]) {
            [self setCountValue:[newValue intValue]];
        } else {
            [cmd setScriptErrorNumber:NSArgumentsWrongScriptError];
            [cmd setScriptErrorString:NSLocalizedString(@"Invalid value for smart condition.",@"Error description")];
        }
    } else {
        if ([newValue isKindOfClass:[NSString class]]) {
            [self setStringValue:newValue];
        } else {
            [cmd setScriptErrorNumber:NSArgumentsWrongScriptError];
            [cmd setScriptErrorString:NSLocalizedString(@"Invalid value for smart condition.",@"Error description")];
        }
    }
}

@end

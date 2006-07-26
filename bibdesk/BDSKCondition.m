//
//  BDSKCondition.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 17/3/05.
/*
 This software is Copyright (c) 2005,2006
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

#import "BDSKCondition.h"
#import "BibItem.h"
#import "NSString_BDSKExtensions.h"
#import "NSDate_BDSKExtensions.h"
#import <OmniBase/assertions.h>
#import "BDSKDateStringFormatter.h"

@interface BDSKCondition (Private)
- (NSDate *)cachedEndDate;
- (void)setCachedEndDate:(NSDate *)newCachedDate;
- (NSDate *)cachedStartDate;
- (void)setCachedStartDate:(NSDate *)newCachedDate;
- (void)updateCachedDates;
- (void)getStartDate:(NSCalendarDate **)startDate endDate:(NSCalendarDate **)endDate;
- (void)refreshCachedDate:(NSTimer *)timer;

- (void)startObserving;
- (void)endObserving;
@end

@implementation BDSKCondition

+ (void)initialize {
    [self setKeys:[NSArray arrayWithObjects:@"valueComparison", @"dateComparison", nil] triggerChangeNotificationsForDependentKey:@"comparison"];
    [self setKeys:[NSArray arrayWithObjects:@"numberValue", @"andNumberValue", @"periodValue", @"dateValue", @"toDateValue", nil] triggerChangeNotificationsForDependentKey:@"value"];
}

- (id)init {
    self = [super init];
    if (self) {
        key = [@"" retain];
        value = [@"" retain];
        valueComparison = BDSKContain;
        dateComparison = BDSKToday;
        numberValue = 0;
        andNumberValue = 0;
        periodValue = BDSKPeriodDay;
        dateValue = nil;
        toDateValue = nil;
        cachedStartDate = nil;
        cachedEndDate = nil;
		cacheTimer = nil;
        [self startObserving];
    }
    return self;
}

- (id)initWithDictionary:(NSDictionary *)dictionary {
	if (self = [self init]) {
		NSString *aKey = [dictionary objectForKey:@"key"];
		NSMutableString *escapedValue = [[dictionary objectForKey:@"value"] mutableCopy];
		NSNumber *comparisonNumber = [dictionary objectForKey:@"comparison"];
		
		if (aKey != nil) 
			[self setKey:aKey];
		
		if (comparisonNumber != nil) 
			[self setComparison:[comparisonNumber intValue]];
		
		if (escapedValue != nil) {
			// we escape braces as they can give problems with btparse
			[escapedValue replaceAllOccurrencesOfString:@"%7B" withString:@"{"];
			[escapedValue replaceAllOccurrencesOfString:@"%7D" withString:@"}"];
			[escapedValue replaceAllOccurrencesOfString:@"%25" withString:@"%"];
			[self setValue:escapedValue];
			[escapedValue release];
        }
        
        [self startObserving];
	}
	return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
	if (self = [super init]) {
		[self setKey:[decoder decodeObjectForKey:@"key"]];
		[self setComparison:[decoder decodeIntForKey:@"comparison"]];
		[self setValue:[decoder decodeObjectForKey:@"value"]];
		OBASSERT(key != nil);
		OBASSERT(value != nil);
		cachedStartDate = nil;
		cachedEndDate = nil;
		cacheTimer = nil;
        [self startObserving];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
	[coder encodeObject:key forKey:@"key"];
	[coder encodeObject:value forKey:@"value"];
	[coder encodeInt:[self comparison] forKey:@"comparison"];
}

- (void)dealloc {
	//NSLog(@"dealloc condition");
    [self endObserving];
    [key release], key  = nil;
    [value release], value  = nil;
    [cachedStartDate release], cachedStartDate  = nil;
    [cachedEndDate release], cachedEndDate  = nil;
    [cacheTimer invalidate], cacheTimer  = nil;
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)aZone {
	BDSKCondition *copy = [[BDSKCondition allocWithZone:aZone] init];
	[copy setKey:[self key]];
	[copy setValue:[self value]];
	[copy setComparison:[self comparison]];
	return copy;
}

- (NSDictionary *)dictionaryValue {
	NSNumber *comparisonNumber = [NSNumber numberWithInt:[self comparison]];
	NSMutableString *escapedValue = [value mutableCopy];
	// escape braces as they can give problems with btparse
	[escapedValue replaceAllOccurrencesOfString:@"%" withString:@"%25"];
	[escapedValue replaceAllOccurrencesOfString:@"{" withString:@"%7B"];
	[escapedValue replaceAllOccurrencesOfString:@"}" withString:@"%7D"];
	NSDictionary *dict = [[NSDictionary alloc] initWithObjectsAndKeys:key, @"key", escapedValue, @"value", comparisonNumber, @"comparison", nil];
	[escapedValue release];
	return [dict autorelease];
}

- (BOOL)isEqual:(id)other {
	if (self == other)
		return YES;
	if (![other isKindOfClass:[BDSKCondition class]]) 
		return NO;
	return [[self key] isEqualToString:[(BDSKCondition *)other key]] &&
		   [[self value] isEqualToString:[(BDSKCondition *)other value]] &&
		   [self comparison] == [(BDSKCondition *)other comparison];
}

- (BOOL)isSatisfiedByItem:(BibItem *)item {
	if ([NSString isEmptyString:key] == YES) 
		return YES; // empty condition matches anything
	
	OBASSERT(value != nil);
	
    if ([self isDateCondition]) {
        
        NSDate *date = nil;
        if ([key isEqualToString:BDSKDateAddedString])
            date = [item dateAdded];
        else if ([key isEqualToString:BDSKDateModifiedString])
            date = [item dateModified];
        return ((cachedStartDate == nil || [date compare:cachedStartDate] == NSOrderedDescending) &&
                (cachedEndDate == nil || [date compare:cachedEndDate] == NSOrderedAscending));
        
    } else {
        
        if (valueComparison == BDSKGroupContain) 
            return ([item isContainedInGroupNamed:value forField:key] == YES);
        if (valueComparison == BDSKGroupNotContain) 
            return ([item isContainedInGroupNamed:value forField:key] == NO);
        
        NSString *itemValue = [item valueOfGenericField:key];
        // unset values are considered empty strings
        if (itemValue == nil)
            itemValue = @"";
        // to speed up comparisons
        if ([itemValue isComplex] || [itemValue isInherited])
            itemValue = [NSString stringWithString:itemValue];
        
        if (valueComparison == BDSKEqual) 
            return ([value caseInsensitiveCompare:itemValue] == NSOrderedSame);
        if (valueComparison == BDSKNotEqual) 
            return ([value caseInsensitiveCompare:itemValue] != NSOrderedSame);
        
        // minor optimization: Shark showed -[NSString rangeOfString:options:] as a bottleneck, calling through to CFStringFindWithOptions
        CFOptionFlags options = kCFCompareCaseInsensitive;
        if (valueComparison == BDSKEndWith)
            options = options | kCFCompareBackwards;
        CFRange range;
        CFIndex itemLength = CFStringGetLength((CFStringRef)itemValue);
        Boolean foundString = CFStringFindWithOptions((CFStringRef)itemValue, (CFStringRef)value, CFRangeMake(0, itemLength), options, &range);
        switch (valueComparison) {
            case BDSKContain:
                return foundString;
            case BDSKNotContain:
                return foundString == FALSE;
            case BDSKStartWith:
                return foundString && range.location == 0;
            case BDSKEndWith:
                return foundString && (range.location + range.length) == itemLength;
            default:
                break; // other enum types are handled before the switch, but the compiler doesn't know that
        }
        
        NSComparisonResult result = [value localizedCaseInsensitiveNumericCompare:itemValue];
        if (valueComparison == BDSKSmaller) 
            return (result == NSOrderedDescending);
        if (valueComparison == BDSKLarger) 
            return (result == NSOrderedAscending);
        
    }
    
    OBASSERT_NOT_REACHED("undefined comparison");
    return NO;
}

#pragma mark Accessors

- (NSString *)key {
    return [[key retain] autorelease];
}

- (void)setKey:(NSString *)newKey {
	// we never want the key to be nil. It is set to nil sometimes by the binding mechanism
	if (newKey == nil) newKey = @"";
    if (![key isEqualToString:newKey]) {
        [key release];
        key = [newKey copy];
    }
}

- (NSString *)value {
    return [[value retain] autorelease];
}

- (void)setValue:(NSString *)newValue {
	// we never want the value to be nil. It is set to nil sometimes by the binding mechanism
	if (newValue == nil) newValue = @"";
    if ([self isDateCondition]) {
        NSArray *values = nil;
        switch (dateComparison) {
            case BDSKExactly: 
            case BDSKInLast: 
            case BDSKNotInLast: 
                values = [newValue componentsSeparatedByString:@" "];
                OBASSERT([values count] == 2);
                [self setNumberValue:[[values objectAtIndex:0] intValue]];
                [self setPeriodValue:[[values objectAtIndex:1] intValue]];
                break;
            case BDSKBetween: 
                values = [newValue componentsSeparatedByString:@" "];
                OBASSERT([values count] == 3);
                [self setNumberValue:[[values objectAtIndex:0] intValue]];
                [self setAndNumberValue:[[values objectAtIndex:1] intValue]];
                [self setPeriodValue:[[values objectAtIndex:2] intValue]];
                break;
            case BDSKDate: 
            case BDSKAfterDate: 
            case BDSKBeforeDate: 
                [self setDateValue:[NSCalendarDate dateWithNaturalLanguageString:newValue]];
                break;
            case BDSKInDateRange:
                values = [newValue componentsSeparatedByString:@" to "];
                OBASSERT([values count] == 2);
                [self setDateValue:[NSCalendarDate dateWithNaturalLanguageString:[values objectAtIndex:0]]];
                [self setToDateValue:[NSCalendarDate dateWithNaturalLanguageString:[values objectAtIndex:1]]];
                break;
            default:
                break;
        }
    } else if (![value isEqualToString:newValue]) {
        [value release];
        value = [newValue retain];
    }
}

- (int)comparison {
    return ([self isDateCondition]) ? dateComparison : valueComparison;
}

- (void)setComparison:(int)newComparison {
    if ([self isDateCondition])
        [self setDateComparison:(BDSKDateComparison)newComparison];
    else
        [self setValueComparison:(BDSKComparison)newComparison];
}

- (BDSKComparison)valueComparison {
    return valueComparison;
}

- (void)setValueComparison:(BDSKComparison)newComparison {
    valueComparison = newComparison;
}

- (BDSKDateComparison)dateComparison {
    return dateComparison;
}

- (void)setDateComparison:(BDSKDateComparison)newComparison {
    dateComparison = newComparison;
}

- (int)numberValue {
    return numberValue;
}

- (void)setNumberValue:(int)newNumber {
    numberValue = newNumber;
}

- (int)andNumberValue {
    return andNumberValue;
}

- (void)setAndNumberValue:(int)newNumber {
    andNumberValue = newNumber;
}

- (int)periodValue {
    return periodValue;
}

- (void)setPeriodValue:(int)newPeriod {
    periodValue = newPeriod;
}

- (NSCalendarDate *)dateValue {
    return [[dateValue retain] autorelease];
}

- (void)setDateValue:(NSCalendarDate *)newDate {
    if (dateValue != newDate) {
        [dateValue release];
        dateValue = [newDate retain];
    }
}

- (NSCalendarDate *)toDateValue {
    return [[toDateValue retain] autorelease];
}

- (void)setToDateValue:(NSCalendarDate *)newDate {
    if (toDateValue != newDate) {
        [toDateValue release];
        toDateValue = [newDate retain];
    }
}

- (BOOL)isDateCondition {
    return ([key isEqualToString:BDSKDateAddedString] || [key isEqualToString:BDSKDateModifiedString]);
}

- (void)updateValue {
    [value release];
    switch (dateComparison) {
        case BDSKExactly: 
        case BDSKInLast: 
        case BDSKNotInLast: 
            value = [[NSString stringWithFormat:@"%i %i", numberValue, periodValue] retain];
            break;
        case BDSKBetween: 
            value = [[NSString stringWithFormat:@"%i %i %i", numberValue, andNumberValue, periodValue] retain];
            break;
        case BDSKDate: 
        case BDSKAfterDate: 
        case BDSKBeforeDate: 
            value = [[NSString stringWithFormat:@"%@", dateValue] retain];
            break;
        case BDSKInDateRange:
            value = [[NSString stringWithFormat:@"%@ to %@", dateValue, toDateValue] retain];
            break;
        default:
            value = [@"" retain];
            break;
    }
}

- (void)setDefaultValue {
    if ([self isDateCondition]) {
        switch (dateComparison) {
            case BDSKExactly: 
            case BDSKInLast: 
            case BDSKNotInLast: 
                [self setValue:@"7 0"];
                break;
            case BDSKBetween: 
                [self setValue:@"7 9 0"];
                break;
            case BDSKDate: 
            case BDSKAfterDate: 
            case BDSKBeforeDate: 
                [self setValue:@"01/01/06"];
                break;
            case BDSKInDateRange:
                [self setValue:@"01/01/06 to 01/01/06"];
                break;
            default:
                [self setValue:@""];
        }
    } else {
        [self setValue:@""];
    }
}

@end

@implementation BDSKCondition (Private)

#pragma mark Cached dates

- (NSDate *)cachedEndDate {
    return cachedEndDate;
}

- (void)setCachedEndDate:(NSDate *)newCachedDate {
    if (cachedEndDate != newCachedDate) {
        [cachedEndDate release];
        cachedEndDate = [newCachedDate retain];
	}
}

- (NSDate *)cachedStartDate {
    return cachedStartDate;
}

- (void)setCachedStartDate:(NSDate *)newCachedDate {
    if (cachedStartDate != newCachedDate) {
        [cachedStartDate release];
        cachedStartDate = [newCachedDate retain];
	}
}

- (void)updateCachedDates {
    NSCalendarDate *startDate = nil;
    NSCalendarDate *endDate = nil;
    
    [cacheTimer invalidate];
    cacheTimer = nil;
    
    if ([self isDateCondition]) {
        [self getStartDate:&startDate endDate:&endDate];
        if (dateComparison < BDSKDate) {
            NSTimeInterval refreshInterval = (periodValue == BDSKPeriodDay) ? 21600 : 86400;
            cacheTimer = [NSTimer scheduledTimerWithTimeInterval:refreshInterval target:self selector:@selector(refreshCachedDate:) userInfo:NULL repeats:YES];
        }
    }
    
    [self setCachedStartDate:startDate];
    [self setCachedEndDate:endDate];
}

- (void)refreshCachedDate:(NSTimer *)timer {
    NSCalendarDate *startDate = nil;
    NSCalendarDate *endDate = nil;
    BOOL changed = NO;
    
	[self getStartDate:&startDate endDate:&endDate];
    if (startDate != nil && [cachedStartDate compare:startDate] != NSOrderedSame) {
        [self setCachedStartDate:startDate];
        changed = YES;
    }
    if (endDate != nil && [cachedEndDate compare:endDate] != NSOrderedSame) {
        [self setCachedEndDate:endDate];
        changed = YES;
    }
    
    if (changed) {
		[[NSNotificationCenter defaultCenter] postNotificationName:BDSKFilterChangedNotification object:self];
    }
}

- (void)getStartDate:(NSCalendarDate **)startDate endDate:(NSCalendarDate **)endDate {
    NSCalendarDate *today = [[NSCalendarDate date] startOfDay];
    
    switch (dateComparison) {
        case BDSKToday:
            periodValue = BDSKPeriodDay;
            *startDate = today;
            *endDate = nil;
            break;
        case BDSKYesterday: 
            periodValue = BDSKPeriodDay;
            *startDate = [today dateByAddingYears:0 months:0 days:-1 hours:0 minutes:0 seconds:0];
            *endDate = today;
            break;
        case BDSKThisWeek: 
            periodValue = BDSKPeriodWeek;
            *startDate = today;
            *endDate = nil;
            break;
        case BDSKLastWeek: 
            periodValue = BDSKPeriodWeek;
            *endDate = [today startOfWeek];
            *startDate = [*endDate dateByAddingYears:0 months:0 days:-7 hours:0 minutes:0 seconds:0];
            break;
        case BDSKExactly: 
            *startDate = [today dateByAddingNumber:-numberValue ofPeriod:periodValue];
            *endDate = [*startDate dateByAddingNumber:1 ofPeriod:periodValue];
            break;
        case BDSKInLast: 
            *startDate = [today dateByAddingNumber:-numberValue ofPeriod:periodValue];
            *endDate = nil;
            break;
        case BDSKNotInLast: 
            *startDate = nil;
            *endDate = [today dateByAddingNumber:-numberValue ofPeriod:periodValue];
            break;
        case BDSKBetween: 
            *startDate = [today dateByAddingNumber:-numberValue ofPeriod:periodValue];
            *endDate = [today dateByAddingNumber:1-andNumberValue ofPeriod:periodValue];
            break;
        case BDSKDate: 
            *startDate = (dateValue == nil) ? nil : [dateValue startOfDay];
            *endDate = [*startDate dateByAddingYears:0 months:0 days:1 hours:0 minutes:0 seconds:0];
            break;
        case BDSKAfterDate: 
            *startDate = (dateValue == nil) ? nil : [dateValue endOfDay];
            *endDate = nil;
            break;
        case BDSKBeforeDate: 
            *startDate = nil;
            *endDate = (dateValue == nil) ? nil : [dateValue startOfDay];
            break;
        case BDSKInDateRange:
            *startDate = (dateValue == nil) ? nil : [dateValue startOfDay];
            *endDate = (toDateValue == nil) ? nil : [toDateValue endOfDay];
            break;
    }
}

#pragma mark KVO

- (void)startObserving {
    [self addObserver:self forKeyPath:@"key" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"dateComparison" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"value" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"numberValue" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"andNumberValue" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"periodValue" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"dateValue" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"toDateValue" options:0 context:NULL];
}

- (void)endObserving {
    [self removeObserver:self forKeyPath:@"key"];
    [self removeObserver:self forKeyPath:@"dateComparison"];
    [self removeObserver:self forKeyPath:@"value"];
    [self removeObserver:self forKeyPath:@"numberValue"];
    [self removeObserver:self forKeyPath:@"andNumberValue"];
    [self removeObserver:self forKeyPath:@"periodValue"];
    [self removeObserver:self forKeyPath:@"dateValue"];
    [self removeObserver:self forKeyPath:@"toDateValue"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"key"]) {
        if ([self isDateCondition]) {
            [self setDateComparison:BDSKToday];
        } else {
            [self updateCachedDates]; // remove the cached date and stop the timer
            [self setValueComparison:BDSKContain];
            [self setDefaultValue];
        }
    } else if ([keyPath isEqualToString:@"dateComparison"]) {
        [self setDefaultValue];
    } else if ([keyPath isEqualToString:@"value"]) {
        [self updateCachedDates];
    } else if ([keyPath isEqualToString:@"numberValue"] || 
               [keyPath isEqualToString:@"andNumberValue"] || 
               [keyPath isEqualToString:@"periodValue"] || 
               [keyPath isEqualToString:@"dateValue"] || 
               [keyPath isEqualToString:@"toDateValue"]) {
        [self updateValue];
    }
}

@end

//
//  NSDate_BDSKExtensions.m
//  Bibdesk
//
//  Created by Adam Maxwell on 07/29/05.
/*
 This software is Copyright (c) 2005-2010
 Adam Maxwell. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 - Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in
 the documentation and/or other materials provided with the
 distribution.
 
 - Neither the name of Adam Maxwell nor the names of any
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

#import "NSDate_BDSKExtensions.h"
#import "BDSKStringConstants.h"
#import "NSCharacterSet_BDSKExtensions.h"
#import "BDSKComplexString.h"
#import "BDSKStringNode.h"


@implementation NSDate (BDSKExtensions)
    
- (id)initWithMonthDayYearString:(NSString *)dateString;
{    
    [[self init] release];
    self = nil;
    
    CFAllocatorRef alloc = CFAllocatorGetDefault();
    
    static id locale = nil;
    if (nil == locale) {
        locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en"];
    }
    static CFDateFormatterRef dateFormatter = nil;
    if (NULL == dateFormatter) {
        // use the en locale, since dates use en short names as keys in BibTeX
        CFLocaleRef enLocale = CFLocaleCreate(alloc, CFSTR("en"));
    
        // the formatter styles aren't used here, since we set an explicit format
        dateFormatter = CFDateFormatterCreate(alloc, enLocale, kCFDateFormatterLongStyle, kCFDateFormatterLongStyle);

        if(NULL != dateFormatter){
            // CFDateFormatter uses ICU formats: http://icu.sourceforge.net/userguide/formatDateTime.html
            CFDateFormatterSetFormat(dateFormatter, CFSTR("MMM-dd-yy"));
            CFDateFormatterSetProperty(dateFormatter, kCFDateFormatterIsLenient, kCFBooleanTrue);    
        }
        
        if(enLocale) CFRelease(enLocale);
    }
    static CFDateFormatterRef numericDateFormatter = nil;
    if (NULL == numericDateFormatter) {
        // use the en locale, since dates use en short names as keys in BibTeX
        CFLocaleRef enLocale = CFLocaleCreate(alloc, CFSTR("en"));
        
        // the formatter styles aren't used here, since we set an explicit format
        numericDateFormatter = CFDateFormatterCreate(alloc, enLocale, kCFDateFormatterLongStyle, kCFDateFormatterLongStyle);
        
        // CFDateFormatter uses ICU formats: http://icu.sourceforge.net/userguide/formatDateTime.html
        CFDateFormatterSetFormat(numericDateFormatter, CFSTR("MM-dd-yy"));
        CFDateFormatterSetProperty(numericDateFormatter, kCFDateFormatterIsLenient, kCFBooleanTrue);            
        
        if(enLocale) CFRelease(enLocale);
    }
    
    CFDateRef date = CFDateFormatterCreateDateFromString(alloc, dateFormatter, (CFStringRef)dateString, NULL);
    
    if(date != nil)
        return (NSDate *)date;
    
    // If we didn't get a valid date on the first attempt, let's try a purely numeric formatter    
    date = CFDateFormatterCreateDateFromString(alloc, numericDateFormatter, (CFStringRef)dateString, NULL);
    
    if(date != nil)
        return (NSDate *)date;
    
    // Now fall back to natural language parsing, which is fairly memory-intensive.
    // We should be able to use NSDateFormatter with the natural language option, but it doesn't seem to work as well as +dateWithNaturalLanguageString
    return [[NSDate dateWithNaturalLanguageString:dateString locale:locale] retain];
}

- (id)initWithMonthString:(NSString *)monthString yearString:(NSString *)yearString {
    if([yearString isComplex])
        yearString = [(BDSKStringNode *)[[yearString nodes] objectAtIndex:0] value];
    if ([NSString isEmptyString:yearString]) {
        [[super init] release];
        return nil;
    } else {
        if([monthString isComplex]) {
            BDSKStringNode *node = nil;
            NSArray *nodes = [monthString nodes];
            for (node in nodes) {
                if ([node type] == BDSKStringNodeMacro) {
                    monthString = [node value];
                    break;
                }
            }
            if (node == nil)
                monthString = [(BDSKStringNode *)[nodes objectAtIndex:0] value];
        } else if (monthString) {
            NSRange r = [monthString rangeOfCharacterFromSet:[NSCharacterSet letterCharacterSet]];
            NSUInteger start = 0, end = [monthString length];
            if (r.location != NSNotFound) {
                start = r.location;
                r = [monthString rangeOfCharacterFromSet:[NSCharacterSet nonLetterCharacterSet] options:0 range:NSMakeRange(start, end - start)];
                if (r.location != NSNotFound)
                    end = r.location;
            } else {
                r = [monthString rangeOfCharacterFromSet:[NSCharacterSet decimalDigitCharacterSet]];
                if (r.location != NSNotFound) {
                    start = r.location;
                    r = [monthString rangeOfCharacterFromSet:[NSCharacterSet nonDecimalDigitCharacterSet] options:0 range:NSMakeRange(start, end - start)];
                    if (r.location != NSNotFound)
                        end = r.location;
                }
            }
            if (start > 0 || end < [monthString length])
                monthString = [monthString substringWithRange:NSMakeRange(start, end - start)];
        } else {
            monthString = @"";
        }
        return [self initWithMonthDayYearString:[NSString stringWithFormat:@"%@-15-%@", monthString, yearString]];
    }
}

- (NSString *)dateDescription{
    // Saturday, March 24, 2001 (NSDateFormatString)
    NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
    [formatter setFormatterBehavior:NSDateFormatterBehavior10_4];
    [formatter setDateStyle:NSDateFormatterFullStyle];
    [formatter setTimeStyle:NSDateFormatterNoStyle];
    return [formatter stringFromDate:self];
}

- (NSString *)shortDateDescription{
    // 31/10/01 (NSShortDateFormatString)
    NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
    [formatter setFormatterBehavior:NSDateFormatterBehavior10_4];
    [formatter setDateStyle:NSDateFormatterShortStyle];
    [formatter setTimeStyle:NSDateFormatterNoStyle];
    return [formatter stringFromDate:self];
}

- (NSString *)rssDescription{
    // see RFC 822, %a, %d %b %Y %H:%M:%S %z
    NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
    [formatter setFormatterBehavior:NSDateFormatterBehavior10_4];
    [formatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss ZZZ"];
    return [formatter stringFromDate:self];
}

- (NSString *)standardDescription{
    // %Y-%m-%d %H:%M:%S %z
    NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
    [formatter setFormatterBehavior:NSDateFormatterBehavior10_4];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss ZZZ"];
    return [formatter stringFromDate:self];
}

- (NSDate *)startOfDay;
{
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSUInteger unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit | NSWeekCalendarUnit | NSWeekdayOrdinalCalendarUnit | NSWeekdayCalendarUnit | NSDayCalendarUnit;
    NSDateComponents *components = [calendar components:unitFlags fromDate:self];
    [components setHour:0];
    [components setMinute:0];
    [components setSecond:0];
    NSDate *date = [calendar dateFromComponents:components];
    [calendar release];
    return date;
}

- (NSDate *)endOfDay;
{
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSUInteger unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit | NSWeekCalendarUnit | NSWeekdayOrdinalCalendarUnit | NSWeekdayCalendarUnit | NSDayCalendarUnit;
    NSDateComponents *components = [calendar components:unitFlags fromDate:self];
    [components setHour:23];
    [components setMinute:59];
    [components setSecond:59];
    NSDate *date = [calendar dateFromComponents:components];
    [calendar release];
    return date;
}

- (NSDate *)startOfWeek;
{
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSUInteger unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit | NSWeekCalendarUnit;
    NSDateComponents *components = [calendar components:unitFlags fromDate:self];
    // the week jumps at firstWeekday, not at weekday=1
    [components setWeekday:[calendar firstWeekday]];
    [components setHour:0];
    [components setMinute:0];
    [components setSecond:0];
    NSDate *date = [calendar dateFromComponents:components];
    [calendar release];
    return date;
}

- (NSDate *)endOfWeek;
{
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSDateComponents *components = [NSDateComponents dateComponentsWithYear:0 month:NSUndefinedDateComponent day:0 hour:0 minute:0 second:-1];
    // the week jumps at firstWeekday, not at weekday=1
    [components setWeekday:[calendar firstWeekday] - 1 ?: 7];
    NSDate *date = [calendar dateByAddingComponents:components toDate:[self startOfWeek] options:0];
    [calendar release];
    return date;
}

- (NSDate *)dateByAddingNumber:(NSInteger)number ofPeriod:(NSInteger)period {
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSDateComponents *components = [[NSDateComponents alloc] init];
    [components setYear:0];
    [components setMonth:0];
    [components setDay:0];
    [components setHour:0];
    [components setMinute:0];
    [components setSecond:0];
    switch (period) {
        case BDSKPeriodHour:
            [components setHour:number];
            break;
        case BDSKPeriodDay:
            [components setDay:number];
            break;
        case BDSKPeriodWeek:
            [components setWeek:number];
            [components setWeekday:0];
            [components setDay:NSUndefinedDateComponent];
            [components setMonth:NSUndefinedDateComponent];
            break;
        case BDSKPeriodMonth:
            [components setMonth:number];
            break;
        case BDSKPeriodYear:
            [components setYear:number];
            break;
        default:
            NSLog(@"Unknown period %ld", (long)period);
            break;
    }
    NSDate *date = [calendar dateByAddingComponents:components toDate:self options:0];
    [calendar release];
    [components release];
    return date;
}

@end

@implementation NSCalendarDate (BDSKExtensions)

- (NSCalendarDate *)initWithNaturalLanguageString:(NSString *)dateString;
{
    // initWithString should release self when it returns nil
    self = [self initWithString:dateString];
    if (self == nil)
        self = [[NSCalendarDate dateWithNaturalLanguageString:dateString] retain];
    return self;
}

// override this NSDate method so we can return an NSCalendarDate efficiently
- (NSCalendarDate *)initWithMonthDayYearString:(NSString *)dateString;
{        
    NSDate *date = [[NSDate alloc] initWithMonthDayYearString:dateString];
    NSTimeInterval t = [date timeIntervalSinceReferenceDate];
    self = [self initWithTimeIntervalSinceReferenceDate:t];
    [date release];
    
    return self;
}

@end

@implementation NSDateComponents (BDSKExtensions)

+ (NSDateComponents *)dateComponentsWithYear:(NSInteger)year month:(NSInteger)month day:(NSInteger)day hour:(NSInteger)hour minute:(NSInteger)minute second:(NSInteger)second
{
    NSDateComponents *components = [[[NSDateComponents alloc] init] autorelease];
    [components setYear:year];
    [components setMonth:month];
    [components setDay:day];
    [components setHour:hour];
    [components setMinute:minute];
    [components setSecond:second];
    return components;
}

@end

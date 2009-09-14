//
//  NSDate_BDSKExtensions.m
//  Bibdesk
//
//  Created by Adam Maxwell on 07/29/05.
/*
 This software is Copyright (c) 2005-2009
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

static NSDictionary *locale = nil;
static CFDateFormatterRef dateFormatter = NULL;
static CFDateFormatterRef numericDateFormatter = NULL;

@implementation NSDate (BDSKExtensions)

+ (void)didLoad
{
    if(nil == locale){
        NSArray *monthNames = [NSArray arrayWithObjects:@"January", @"February", @"March", @"April", @"May", @"June", @"July", @"August", @"September", @"October", @"November", @"December", nil];
        NSArray *shortMonthNames = [NSArray arrayWithObjects:@"Jan", @"Feb", @"Mar", @"Apr", @"May", @"Jun", @"Jul", @"Aug", @"Sep", @"Oct", @"Nov", @"Dec", nil];
        
        locale = [[NSDictionary alloc] initWithObjectsAndKeys:@"MDYH", NSDateTimeOrdering, monthNames, NSMonthNameArray, shortMonthNames, NSShortMonthNameArray, nil];
    }
    

    // NB: CFDateFormatters are fairly expensive beasts to create, so we cache them here
    
    CFAllocatorRef alloc = CFAllocatorGetDefault();
    
    // use the en locale, since dates use en short names as keys in BibTeX
    CFLocaleRef enLocale = CFLocaleCreate(alloc, CFSTR("en"));
   
    // Create a date formatter that accepts "text month-numeric day-numeric year", which is arguably the most common format in BibTeX
    if(NULL == dateFormatter){
    
        // the formatter styles aren't used here, since we set an explicit format
        dateFormatter = CFDateFormatterCreate(alloc, enLocale, kCFDateFormatterLongStyle, kCFDateFormatterLongStyle);

        if(NULL != dateFormatter){
            // CFDateFormatter uses ICU formats: http://icu.sourceforge.net/userguide/formatDateTime.html
            CFDateFormatterSetFormat(dateFormatter, CFSTR("MMM-dd-yy"));
            CFDateFormatterSetProperty(dateFormatter, kCFDateFormatterIsLenient, kCFBooleanTrue);    
        }
    }
    
    if(NULL == numericDateFormatter){
        
        // the formatter styles aren't used here, since we set an explicit format
        numericDateFormatter = CFDateFormatterCreate(alloc, enLocale, kCFDateFormatterLongStyle, kCFDateFormatterLongStyle);
        
        // CFDateFormatter uses ICU formats: http://icu.sourceforge.net/userguide/formatDateTime.html
        CFDateFormatterSetFormat(numericDateFormatter, CFSTR("MM-dd-yy"));
        CFDateFormatterSetProperty(dateFormatter, kCFDateFormatterIsLenient, kCFBooleanTrue);            
    }
    if(enLocale) CFRelease(enLocale);
}
    
#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_5
#warning fixme: uses deprecated API, use NSDateFormatter instead
#endif
- (id)initWithMonthDayYearString:(NSString *)dateString;
{    
    [[self init] release];
    self = nil;

    CFAllocatorRef alloc = CFAllocatorGetDefault();
    
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

- (NSDate *)startOfHour;
{
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    unsigned unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit | NSWeekCalendarUnit | NSWeekdayOrdinalCalendarUnit | NSWeekdayCalendarUnit | NSDayCalendarUnit | NSHourCalendarUnit;
    NSDateComponents *components = [calendar components:unitFlags fromDate:self];
    [components setMinute:0];
    [components setSecond:0];
    NSDate *date = [calendar dateFromComponents:components];
    [calendar release];
    return date;
}

- (NSDate *)endOfHour;
{
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    unsigned unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit | NSWeekCalendarUnit | NSWeekdayOrdinalCalendarUnit | NSWeekdayCalendarUnit | NSDayCalendarUnit | NSHourCalendarUnit;
    NSDateComponents *components = [calendar components:unitFlags fromDate:self];
    [components setMinute:59];
    [components setSecond:59];
    NSDate *date = [calendar dateFromComponents:components];
    [calendar release];
    return date;
}

- (NSDate *)startOfDay;
{
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    unsigned unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit | NSWeekCalendarUnit | NSWeekdayOrdinalCalendarUnit | NSWeekdayCalendarUnit | NSDayCalendarUnit;
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
    unsigned unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit | NSWeekCalendarUnit | NSWeekdayOrdinalCalendarUnit | NSWeekdayCalendarUnit | NSDayCalendarUnit;
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
    unsigned unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit | NSWeekCalendarUnit;
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

- (NSDate *)startOfMonth;
{
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    unsigned unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit;
    NSDateComponents *components = [calendar components:unitFlags fromDate:self];
    [components setDay:1];
    [components setHour:0];
    [components setMinute:0];
    [components setSecond:0];
    NSDate *date = [calendar dateFromComponents:components];
    [calendar release];
    return date;
}

- (NSDate *)endOfMonth;
{
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSDateComponents *components = [NSDateComponents dateComponentsWithYear:0 month:1 day:0 hour:0 minute:0 second:-1];
    NSDate *date = [calendar dateByAddingComponents:components toDate:[self startOfMonth] options:0];
    [calendar release];
    [components release];
    return date;
}

- (NSDate *)startOfYear;
{
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    unsigned unitFlags = NSYearCalendarUnit;
    NSDateComponents *components = [calendar components:unitFlags fromDate:self];
    [components setMonth:1];
    [components setDay:1];
    [components setHour:0];
    [components setMinute:0];
    [components setSecond:0];
    NSDate *date = [calendar dateFromComponents:components];
    [calendar release];
    return date;
}

- (NSDate *)endOfYear;
{
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSDateComponents *components = [NSDateComponents dateComponentsWithYear:1 month:0 day:0 hour:0 minute:0 second:-1];
    NSDate *date = [calendar dateByAddingComponents:components toDate:[self startOfYear] options:0];
    [calendar release];
    return date;
}

- (NSDate *)startOfPeriod:(int)period;
{
    switch (period) {
        case BDSKPeriodHour:
            return [self startOfHour];
        case BDSKPeriodDay:
            return [self startOfDay];
        case BDSKPeriodWeek:
            return [self startOfWeek];
        case BDSKPeriodMonth:
            return [self startOfMonth];
        case BDSKPeriodYear:
            return [self startOfYear];
        default:
            NSLog(@"Unknown period %d",period);
            return self;
    }
}

- (NSDate *)endOfPeriod:(int)period;
{
    switch (period) {
        case BDSKPeriodHour:
            return [self endOfHour];
        case BDSKPeriodDay:
            return [self endOfDay];
        case BDSKPeriodWeek:
            return [self endOfWeek];
        case BDSKPeriodMonth:
            return [self endOfMonth];
        case BDSKPeriodYear:
            return [self endOfYear];
        default:
            NSLog(@"Unknown period %d",period);
            return self;
    }
}

- (NSDate *)dateByAddingNumber:(int)number ofPeriod:(int)period {
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
            NSLog(@"Unknown period %d",period);
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
    NSCalendarDate *date = [self initWithString:dateString];

    return (date != nil ? date : [[NSCalendarDate dateWithNaturalLanguageString:dateString] retain]);
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

+ (NSDateComponents *)dateComponentsWithYear:(int)year month:(int)month day:(int)day hour:(int)hour minute:(int)minute second:(int)second
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

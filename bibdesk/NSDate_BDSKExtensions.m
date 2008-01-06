//
//  NSDate_BDSKExtensions.m
//  Bibdesk
//
//  Created by Adam Maxwell on 07/29/05.
/*
 This software is Copyright (c) 2005,2006,2007,2008
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
    return [self descriptionWithCalendarFormat:@"%a, %d %b %Y %H:%M:%S %z"];
}

- (NSString *)standardDescription{
    return [self descriptionWithCalendarFormat:@"%Y-%m-%d %H:%M:%S %z"];
}

- (NSCalendarDate *)startOfHour;
{
    NSCalendarDate *startHour = [[NSCalendarDate alloc] initWithYear:[self yearOfCommonEra] month:[self monthOfYear] day:[self dayOfMonth] hour:[self hourOfDay] minute:0 second:0 timeZone:[self timeZone]];
    return [startHour autorelease];
}

- (NSCalendarDate *)endOfHour;
{
    return [[self startOfHour] dateByAddingYears:0 months:0 days:0 hours:1 minutes:0 seconds:-1];
}

- (NSCalendarDate *)startOfDay;
{
    NSCalendarDate *startDay = [[NSCalendarDate alloc] initWithYear:[self yearOfCommonEra] month:[self monthOfYear] day:[self dayOfMonth] hour:0 minute:0 second:0 timeZone:[self timeZone]];
    return [startDay autorelease];
}

- (NSCalendarDate *)endOfDay;
{
    return [[self startOfDay] dateByAddingYears:0 months:0 days:1 hours:0 minutes:0 seconds:-1];
}

- (NSCalendarDate *)startOfWeek;
{
    NSCalendarDate *startDay = [self startOfDay];
    return [startDay dateByAddingYears:0 months:0 days:-[startDay dayOfWeek] hours:0 minutes:0 seconds:0];
}

- (NSCalendarDate *)endOfWeek;
{
    return [[self startOfWeek] dateByAddingYears:0 months:0 days:7 hours:0 minutes:0 seconds:-1];
}

- (NSCalendarDate *)startOfMonth;
{
    NSCalendarDate *startDay = [[NSCalendarDate alloc] initWithYear:[self yearOfCommonEra] month:[self monthOfYear] day:1 hour:0 minute:0 second:0 timeZone:[self timeZone]];
    return [startDay autorelease];
}

- (NSCalendarDate *)endOfMonth;
{
    return [[self startOfMonth] dateByAddingYears:0 months:1 days:0 hours:0 minutes:0 seconds:-1];
}

- (NSCalendarDate *)startOfYear;
{
    NSCalendarDate *startDay = [[NSCalendarDate alloc] initWithYear:[self yearOfCommonEra] month:1 day:1 hour:0 minute:0 second:0 timeZone:[self timeZone]];
    return [startDay autorelease];
}

- (NSCalendarDate *)endOfYear;
{
    return [[self startOfYear] dateByAddingYears:1 months:0 days:0 hours:0 minutes:0 seconds:-1];
}

- (NSCalendarDate *)startOfPeriod:(int)period;
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

- (NSCalendarDate *)endOfPeriod:(int)period;
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

- (NSCalendarDate *)dateByAddingNumber:(int)number ofPeriod:(int)period {
    switch (period) {
        case BDSKPeriodHour:
            return [self dateByAddingYears:0 months:0 days:0 hours:number minutes:0 seconds:0];
        case BDSKPeriodDay:
            return [self dateByAddingYears:0 months:0 days:number hours:0 minutes:0 seconds:0];
        case BDSKPeriodWeek:
            return [self dateByAddingYears:0 months:0 days:7 * number hours:0 minutes:0 seconds:0];
        case BDSKPeriodMonth:
            return [self dateByAddingYears:0 months:number days:0 hours:0 minutes:0 seconds:0];
        case BDSKPeriodYear:
            return [self dateByAddingYears:number months:0 days:0 hours:0 minutes:0 seconds:0];
        default:
            NSLog(@"Unknown period %d",period);
            return self;
    }
}

@end

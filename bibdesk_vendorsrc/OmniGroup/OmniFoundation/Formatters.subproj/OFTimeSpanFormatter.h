// Copyright 2000-2004 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: /Network/Source/CVS/OmniGroup/Frameworks/OmniFoundation/Formatters.subproj/OFTimeSpanFormatter.h,v 1.9 2004/02/10 04:07:45 kc Exp $

#import <Foundation/NSFormatter.h>

@interface OFTimeSpanFormatter : NSFormatter
{
    BOOL shouldUseVerboseFormat;
    int hoursPerDay, hoursPerWeek, hoursPerMonth;
}

- (void)setUseVerboseFormat:(BOOL)shouldUseVerbose;
- (BOOL)shouldUseVerboseFormat;

- (int)hoursPerDay;
- (int)hoursPerWeek;
- (int)hoursPerMonth;

- (void)setHoursPerDay:(int)hours;
- (void)setHoursPerWeek:(int)hours;
- (void)setHoursPerMonth:(int)hours;

- (BOOL)isStandardWorkTime;
- (BOOL)isStandardCalendarTime;

- (void)setStandardWorkTime; // 8h = 1d, 40h = 1w, 160h = 1m
- (void)setStandardCalendarTime; // 24h = 1d, 168h = 1w, 5040h = 1m (30d = 1m)

@end

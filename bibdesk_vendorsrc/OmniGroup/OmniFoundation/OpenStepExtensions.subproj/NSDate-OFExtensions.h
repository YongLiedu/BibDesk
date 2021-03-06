// Copyright 1997-2005, 2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease_2007-10-25/OmniGroup/Frameworks/OmniFoundation/OpenStepExtensions.subproj/NSDate-OFExtensions.h 92224 2007-10-03 00:08:05Z wiml $

#import <Foundation/NSDate.h>

@class NSCalendar, NSString, NSTimeZone;

@interface NSDate (OFExtensions)

- (NSString *)descriptionWithHTTPFormat; // rfc1123 format with TZ forced to GMT

- (void)sleepUntilDate;

- (BOOL)isAfterDate: (NSDate *) otherDate;
- (BOOL)isBeforeDate: (NSDate *) otherDate;

// XML Schema / ISO 8601 support
+ (NSTimeZone *)UTCTimeZone;
+ (NSCalendar *)gregorianUTCCalendar;
- initWithXMLString:(NSString *)xmlString;
- (NSString *)xmlString;

@end

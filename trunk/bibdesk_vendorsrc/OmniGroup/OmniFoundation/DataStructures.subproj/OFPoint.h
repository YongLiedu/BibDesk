// Copyright 2003-2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease_2007-10-25/OmniGroup/Frameworks/OmniFoundation/DataStructures.subproj/OFPoint.h 93428 2007-10-25 16:36:11Z kc $

#import <Foundation/NSObject.h>
#import <Foundation/NSGeometry.h>

@interface OFPoint : NSObject <NSCopying, NSCoding>
{
    NSPoint _value;
}

+ (OFPoint *)pointWithPoint:(NSPoint)point;

- initWithPoint:(NSPoint)point;
- initWithString:(NSString *)string;

- (NSPoint)point;

- (NSMutableDictionary *)propertyListRepresentation;
+ (OFPoint *)pointFromPropertyListRepresentation:(NSDictionary *)dict;

@end

// Value transformer
#if MAC_OS_X_VERSION_10_3 <= MAC_OS_X_VERSION_MAX_ALLOWED
extern NSString *OFPointToPropertyListTransformerName;
#endif

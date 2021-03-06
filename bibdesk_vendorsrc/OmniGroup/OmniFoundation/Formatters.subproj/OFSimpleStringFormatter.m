// Copyright 1997-2005, 2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniFoundation/OFSimpleStringFormatter.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease_2007-10-25/OmniGroup/Frameworks/OmniFoundation/Formatters.subproj/OFSimpleStringFormatter.m 90130 2007-08-15 07:15:53Z bungi $")

@implementation OFSimpleStringFormatter

+ (void)initialize;
{
    OBINITIALIZE;
    [self setVersion:0];
}

- init;
{
    return [self initWithMaxLength:0];
}

- initWithMaxLength:(unsigned int)value;
{
    if ([super init] == nil)
        return nil;
    maxLength = value;
    return self;
}

- (void)setMaxLength:(unsigned int)value; { maxLength = value; }
- (unsigned int)maxLength; { return maxLength; }

- (NSString *)stringForObjectValue:anObject;
{
    if (![anObject isKindOfClass:[NSString class]])
        return nil;

    return anObject;
}

- (BOOL)isPartialStringValid:(NSString *)partialString newEditingString:(NSString **)newString errorDescription:(NSString **)error;
{
    if (maxLength == 0)
        return YES;

    return ([partialString length] <= maxLength);
}

- (BOOL)getObjectValue:(id *)obj forString:(NSString *)string errorDescription:(NSString **)error;
{
    if (maxLength != 0 && [string length] > maxLength)
        return NO;
    if (obj)
        *obj = string;
    return YES;
}

- (NSString *)inspectorClassName;
{
    return @"OASimpleStringFormatterInspector";
}

- (void)encodeWithCoder:(NSCoder *)coder;
{
    [super encodeWithCoder:coder];
    [coder encodeValueOfObjCType:@encode(unsigned int) at:&maxLength];
}

- initWithCoder:(NSCoder *)coder;
{
    unsigned int version;
    
    self = [super initWithCoder:coder];
    version = [coder versionForClassName:NSStringFromClass([self class])];
    switch (version) {
        case 0:
            [coder decodeValueOfObjCType:@encode(unsigned int) at:&maxLength];
            break;

        default:
            OBASSERT(NO);
            break;
    }
    
    return self;
}

@end

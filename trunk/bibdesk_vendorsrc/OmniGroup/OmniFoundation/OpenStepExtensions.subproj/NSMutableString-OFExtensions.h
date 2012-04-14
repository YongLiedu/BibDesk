// Copyright 1997-2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease_2007-10-25/OmniGroup/Frameworks/OmniFoundation/OpenStepExtensions.subproj/NSMutableString-OFExtensions.h 93428 2007-10-25 16:36:11Z kc $

#import <Foundation/NSString.h>
#import <OmniBase/OBUtilities.h> // for OB_DEPRECATED_ATTRIBUTE

@interface NSMutableString (OFExtensions)
- (void)replaceAllOccurrencesOfCharactersInSet:(NSCharacterSet *)set withString:(NSString *)replaceString;
- (void)collapseAllOccurrencesOfCharactersInSet:(NSCharacterSet *)set toString:(NSString *)replaceString;

- (BOOL)replaceAllOccurrencesOfString:(NSString *)matchString withString:(NSString *)newString;
- (BOOL)replaceAllOccurrencesOfRegularExpressionString:(NSString *)matchString withString:(NSString *)newString;
- (void)replaceAllLineEndingsWithString:(NSString *)newString;

- (void)appendCharacter:(unsigned int)aCharacter;
- (void)appendStrings: (NSString *)first, ...;

- (void)removeSurroundingWhitespace OB_DEPRECATED_ATTRIBUTE;

@end

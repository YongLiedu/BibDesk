/*

NSString+XMLUtils.m
by Buzz Andersen

More information at: http://www.scifihifi.com/weblog/mac/NSString-Entities.html

This work is licensed under the Creative Commons Attribution License. To view a copy of this license, visit

http://creativecommons.org/licenses/by/1.0/

or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford,
California 94305, USA.

*/

#import "NSString+XMLUtils.h"


@implementation NSString (XMLUtils)

- (NSString *) stringByUnescapingEntities: (NSDictionary *) entitiesDictionary {
    NSString *unescapedString = (NSString *) CFXMLCreateStringByUnescapingEntities(NULL, (CFStringRef) self, (CFDictionaryRef) entitiesDictionary);
    return [unescapedString autorelease];
}

@end

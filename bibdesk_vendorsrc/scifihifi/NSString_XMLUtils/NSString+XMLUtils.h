/*

NSString+XMLUtils.m
TemplateTest
by Buzz Andersen

More information at: http://www.scifihifi.com/weblog/mac/NSString-Entities.html

This work is licensed under the Creative Commons Attribution License. To view a copy of this license, visit

http://creativecommons.org/licenses/by/1.0/

or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford,
California 94305, USA.

*/

#import <Foundation/Foundation.h>


@interface NSString (XMLUtils) 

/* Pass in a custom dictionary mapping entities to their literal values, or pass nil and only the standard XML entities (&lt; = <, &gt; = >, &amp; = &, &apos = ';, &quot = ";) will be handled. */
- (NSString *) stringByUnescapingEntities: (NSDictionary *) entitiesDictionary;

@end

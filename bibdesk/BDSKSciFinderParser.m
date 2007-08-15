//
//  BDSKSciFinderParser.m
//  Bibdesk
//
//  Created by Adam Maxwell on 08/15/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "BDSKSciFinderParser.h"
#import "BibItem.h"
#import "NSError_BDSKExtensions.h"

@implementation BDSKSciFinderParser

+ (BOOL)canParseString:(NSString *)string;
{
    // remove leading newlines in case this originates from copy/paste
    return [[string stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]] hasPrefix:@"START_RECORD"];
}

+ (BOOL)copyKey:(NSString **)key value:(NSString **)value fromLine:(NSString *)line;
{
    NSRange r = [line rangeOfString:@":"];
    unsigned len = [line length];
    if (r.location != NSNotFound && (r.location + 1) < len) {
        CFAllocatorRef alloc = CFGetAllocator((CFStringRef)line);
        *key = (id)CFStringCreateWithSubstring(alloc, (CFStringRef)line, CFRangeMake(0, r.location));
        // advance range past the ":"
        r.location += 1;
        *value = (id)CFStringCreateWithSubstring(alloc, (CFStringRef)line, CFRangeMake(r.location, len - r.location));
        return YES;
    }
    return NO;
}

static void fixAndAddKeyValueToDictionary(NSString *key, NSString *value, NSMutableDictionary *pubFields)
{
    // @@ most of this needs to be replaced by TypeInfo.plist dictionaries
    static NSCharacterSet *replaceChars = nil;
    if (nil == replaceChars) {
        replaceChars = [[NSCharacterSet characterSetWithCharactersInString:@" ."] copy];
    }    
    if ([key isEqualToString:@"Author"])
        value = [value stringByReplacingAllOccurrencesOfString:@"; " withString:@" and "];
    else if ([key isEqualToString:@"Journal Title"])
        key = BDSKJournalString;
    else if ([key isEqualToString:@"Document Type"])
        return;
    else if ([key isEqualToString:@"Publication Year"])
        key = BDSKYearString;
    else if ([key isEqualToString:@"Page"]) {
        key = BDSKPagesString;
        if ([value rangeOfString:@"--"].location == NSNotFound)
            value = [value stringByReplacingAllOccurrencesOfString:@"-" withString:@"--"];
    }
    else if ([key isEqualToString:@"Issue"])
        key = BDSKNumberString;
    else if ([key rangeOfCharacterFromSet:replaceChars].length)
        key = [key stringByReplacingCharactersInSet:replaceChars withString:@"-"];

    // @@ worth it to remove newlines from the value?  probably depends on the source...
    
    [pubFields setObject:value forKey:[key fieldName]];    
}

+ (NSArray *)itemsFromString:(NSString *)itemString error:(NSError **)outError;
{        
    // initial sanity check to make sure we have start/end tags
    NSRange r = [itemString rangeOfString:@"START_RECORD"];
    unsigned nStart = 0, nStop = 0;
    while (r.length) {
        nStart++;
        r = [itemString rangeOfString:@"START_RECORD" options:0 range:NSMakeRange(NSMaxRange(r), [itemString length] - NSMaxRange(r))];
    }
    r = [itemString rangeOfString:@"END_RECORD"];
    while (r.length) {
        nStop++;
        r = [itemString rangeOfString:@"END_RECORD" options:0 range:NSMakeRange(NSMaxRange(r), [itemString length] - NSMaxRange(r))];
    }
    if (nStart != nStop) {
        if (outError) *outError = [NSError mutableLocalErrorWithCode:kBDSKUnknownError localizedDescription:NSLocalizedString(@"Unable to parse SciFinder data", @"error message for SciFinder")];
        [*outError setValue:NSLocalizedString(@"Unbalanced START_RECORD and END_RECORD tags", @"error message for SciFinder; do not translate START_RECORD or END_RECORD") forKey:NSLocalizedRecoverySuggestionErrorKey];
        return nil;
    }
    
    // make sure we only deal with ASCII space and \n characters
    itemString = [itemString stringByNormalizingSpacesAndLineBreaks];
    
    // split into an array of strings, with one for each record
    NSArray *scfItems = [itemString componentsSeparatedByString:@"\nEND_RECORD"];

    NSMutableArray *toReturn = [NSMutableArray arrayWithCapacity:[scfItems count]];

    NSEnumerator *scfItemEnum = [scfItems objectEnumerator];
    NSString *str;
    NSMutableDictionary *pubFields = [NSMutableDictionary new];
    
    while (str = [scfItemEnum nextObject]) {

        // split each record up into field/value lines
        NSArray *lines = [str componentsSeparatedByString:@"\nFIELD "];
        
        unsigned i, iMax = [lines count];
        for (i = 0; i < iMax; i++) {
            
            NSString *line = [lines objectAtIndex:i];
            
            NSString *key;
            NSString *value;
            
            // lots of keys have empty values, so check the return value of this method
            // some fields also seem to be continued, as "Index Terms" and "Index Terms(2)"; not clear how to handle those yet
            if ([self copyKey:&key value:&value fromLine:line]) {
                fixAndAddKeyValueToDictionary(key, value, pubFields);
                [key release];
                [value release];
            }            
        }
        
        if ([pubFields count]) {
            BibItem *pub = [[BibItem alloc] initWithType:BDSKArticleString fileType:BDSKBibtexString citeKey:nil pubFields:pubFields isNew:YES];
            [toReturn addObject:pub];
            [pub release];
            [pubFields removeAllObjects];
        }
    }
    [pubFields release];
    return toReturn;
}

@end

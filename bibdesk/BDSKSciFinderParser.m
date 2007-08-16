//
//  BDSKSciFinderParser.m
//  Bibdesk
//
//  Created by Adam Maxwell on 08/15/07.
/*
 This software is Copyright (c) 2007
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

// some more-or-less unique string that meets our field name criteria (leading cap, no space)
static NSString *__documentTypeString = @"Document-Type";

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
    else if ([key isEqualToString:@"Document Type"]) {
        // parse this here and add to the dictionary, to be removed later when we match it up with a BibTeX type
        NSRange r = [value rangeOfString:@";"];
        if (r.length)
            value = [value substringWithRange:NSMakeRange(0, r.location)];
        key = __documentTypeString;
    }
    else if ([key isEqualToString:@"Publication Year"])
        key = BDSKYearString;
    else if ([key isEqualToString:@"Page"]) {
        key = BDSKPagesString;
        if ([value rangeOfString:@"--"].location == NSNotFound)
            value = [value stringByReplacingAllOccurrencesOfString:@"-" withString:@"--"];
    }
    else if ([key isEqualToString:@"Issue"])
        key = BDSKNumberString;
    else if ([key isEqualToString:@"Title"] && [value hasSuffix:@"."]) // many entries seem to have a trailing "." on the title
        value = [value stringByRemovingSuffix:@"."];
    else if ([key rangeOfCharacterFromSet:replaceChars].length)
        key = [key stringByReplacingCharactersInSet:replaceChars withString:@"-"];
    
    [pubFields setObject:[value stringByBackslashEscapingTeXSpecials] forKey:[key fieldName]];    
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
            NSString *type = [pubFields objectForKey:__documentTypeString];
            
            // leave Document-Type as a field if we don't have a precise mapping
            if ([type isEqualToString:@"Journal"]) {
                type = BDSKArticleString;
                [pubFields removeObjectForKey:__documentTypeString];
            }else if ([type isEqualToString:@"Preprint"]) {
                // preprint is most likely an article type...but unpublished is probably better
                type = BDSKUnpublishedString;
            }else if ([type isEqualToString:@"Report"]) {
                // this should be more accurate than "Journal", but unfortunately all types are described with the same keys
                if ([pubFields objectForKey:BDSKJournalString]) {
                    [pubFields setObject:[pubFields objectForKey:BDSKJournalString] forKey:BDSKInstitutionString];
                    [pubFields removeObjectForKey:BDSKJournalString];
                }
                type = BDSKTechreportString;
                [pubFields removeObjectForKey:__documentTypeString];
            }else {
                // the only other type I've seen so far is patent, which BibTeX doesn't have
                type = BDSKMiscString;
            }
            
            BibItem *pub = [[BibItem alloc] initWithType:type fileType:BDSKBibtexString citeKey:nil pubFields:pubFields isNew:YES];
            [toReturn addObject:pub];
            [pub release];
            [pubFields removeAllObjects];
        }
    }
    [pubFields release];
    return toReturn;
}

@end

/*
 Google turns up some sample documents at
 
 http://chemistry.library.wisc.edu/instruction/scifinder_taggedsample.txt
 http://wiki.refbase.net/index.php/Import_Example:_SciFinder
 
 From those, we have the following unique doc types:
 
 FIELD Document Type:Journal; Online Computer File
 FIELD Document Type:Patent
 FIELD Document Type:Journal; Article; (JOURNAL ARTICLE)
 FIELD Document Type:Journal; Article; (JOURNAL ARTICLE)
 FIELD Document Type:Journal; Article; (JOURNAL ARTICLE)
 FIELD Document Type:Preprint
 FIELD Document Type:Journal; General Review
 FIELD Document Type:Report
 
 so it looks like we want to grab the first word/phrase before the semicolon, or to the end of the line, whichever is shorter.  Entries appear to have a maximum of 49 lines.
 
 START_RECORD
 Copyright
 Database
 Title
 Accession Number
 Abstract
 Author
 Chemical Abstracts Number(CAN)
 Section Code
 Section Title
 CA Section Cross-references
 Corporate Source
 URL
 Document Type
 CODEN
 Internat.Standard Doc. Number
 Journal Title
 Language
 Volume
 Issue
 Page
 Publication Year
 Publication Date
 Index Terms
 Index Terms(2)
 CAS Registry Numbers
 Supplementary Terms
 PCT Designated States
 PCT Reg. Des. States
 Reg.Pat.Tr.Des.States
 Main IPC
 IPC
 Secondary IPC
 Additional IPC
 Index IPC
 Inventor Name
 National Patent Classification
 Patent Application Country
 Patent Application Date
 Patent Application Number
 Patent Assignee
 Patent Country
 Patent Kind Code
 Patent Number
 Priority Application Country
 Priority Application Number
 Priority Application Date
 Citations
 END_RECORD
 
 */ 

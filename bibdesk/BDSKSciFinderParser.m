//
//  BDSKSciFinderParser.m
//  Bibdesk
//
//  Created by Adam Maxwell on 08/15/07.
/*
 This software is Copyright (c) 2007-2009
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
    NSUInteger len = [line length];
    if (r.location != NSNotFound && (r.location + 1) < len) {
        CFAllocatorRef alloc = CFGetAllocator((CFStringRef)line);
        *key = (id)CFStringCreateWithSubstring(alloc, (CFStringRef)line, CFRangeMake(0, r.location));
        // advance range past the ":"
        r.location += 1;
        *value = (id)CFStringCreateWithSubstring(alloc, (CFStringRef)line, CFRangeMake(r.location, len - r.location));
        
        // just checking length may not be sufficient; some entries have a single space past the colon
        if ([*value rangeOfCharacterFromSet:[NSCharacterSet alphanumericCharacterSet]].length)
            return YES;
        // no meaningful characters, so release and return NO
        [*key release];
        [*value release];
    }
    return NO;
}

// this is a set of fields that don't need any massaging; the key/value match BibTeX definitions
static NSSet *correctFields = nil;
static NSString *shortJournalNameString = nil;
// some more-or-less unique string that meets our field name criteria (leading cap, no space)
static NSString *__documentTypeString = @"Doc-Type";

+ (void)initialize
{
    BDSKINITIALIZE;
    correctFields = [[NSSet alloc] initWithObjects:BDSKVolumeString, @"Language", BDSKAbstractString, nil];
    shortJournalNameString = [[[[NSUserDefaults standardUserDefaults] objectForKey:@"BDSKShortJournalNameField"] fieldName] copy];
}

static void addKeyValueToAnnote(NSString *key, NSString *value, NSMutableDictionary *pubFields)
{
    NSMutableString *mutString = [pubFields objectForKey:BDSKAnnoteString];
    if (nil == mutString) {
        mutString = [NSMutableString string];
        [pubFields setObject:mutString forKey:BDSKAnnoteString];
    }
    [mutString appendFormat:@"%@:\t%@\n\n", key, value];    
}

static void fixAndAddKeyValueToDictionary(NSString *key, NSString *value, NSMutableDictionary *pubFields)
{    
    // We could move some of this into TypeInfo.plist, but we only have three fields that don't need special handling, so it's not really worthwhile.  This function has multiple early returns, so be careful when debugging.
    
    if ([key isEqualToString:BDSKAuthorString]) {
        value = [value stringByReplacingOccurrencesOfString:@"; " withString:@" and "];
        // this sucks; some entries have "Last, Middle, First.", and some have "Last, M. F."
        if ([value hasSuffix:@"."] && [value length] > 2 && 
            [[NSCharacterSet lowercaseLetterCharacterSet] characterIsMember:[value characterAtIndex:([value length] - 2)]])
            value = [value stringByRemovingSuffix:@"."];
    }
    else if ([key isEqualToString:@"Full Journal Title"]) {
        key = BDSKJournalString;
        // apparently one of the databases returns journal names in all caps
        if ([value rangeOfCharacterFromSet:[NSCharacterSet lowercaseLetterCharacterSet]].location == NSNotFound)
            value = [value titlecaseString];
        
        // if we previously used the short title for Journal, save it off in Annote
        if ([pubFields objectForKey:key] != nil) {
            if (nil == shortJournalNameString)
                addKeyValueToAnnote(@"Journal Title", [pubFields objectForKey:key], pubFields);
            else
                [pubFields setObject:[pubFields objectForKey:key] forKey:shortJournalNameString];
        }
    }
    else if ([key isEqualToString:@"Journal Title"]) {
        key = BDSKJournalString;
        
        // if we already have a Journal definition, it's from the full title, so keep it
        if ([pubFields objectForKey:key] != nil) {
            // add it to annote and bail out, unless the user wants to put it in a special field
            if (nil == shortJournalNameString) {
                addKeyValueToAnnote(@"Journal Title", value, pubFields);
                return;
            }
            else key = shortJournalNameString;
        }
        // apparently one of the databases returns journal names in all caps
        if ([value rangeOfCharacterFromSet:[NSCharacterSet lowercaseLetterCharacterSet]].location == NSNotFound)
            value = [value titlecaseString];
    }
    else if ([key isEqualToString:@"Document Type"]) {
        // parse this here and add to the dictionary, to be removed later when we match it up with a BibTeX type
        NSRange r = [value rangeOfString:@";"];
        if (r.length)
            value = [value substringWithRange:NSMakeRange(0, r.location)];
        key = __documentTypeString;
    }
    else if ([key isEqualToString:@"Publication Year"]) {
        key = BDSKYearString;
    }
    else if ([key isEqualToString:@"Publication Date"]) {
        // user says that one database uses Publication Year, and the other uses Publication Date, and recommends we prefer year
        key = BDSKYearString;
        if ([pubFields objectForKey:key] == nil)
            return;
    }
    else if ([key isEqualToString:@"Corporate Source"]) {
        key = BDSKAddressString;
    }
    else if ([key isEqualToString:@"Page"]) {
        key = BDSKPagesString;
        if ([value rangeOfString:@"--"].location == NSNotFound)
            value = [value stringByReplacingOccurrencesOfString:@"-" withString:@"--"];
    }
    else if ([key isEqualToString:@"Issue"]) {
        key = BDSKNumberString;
    }
    else if ([key isEqualToString:BDSKTitleString]) {
        // many entries seem to have a trailing "." on the title
        if ([value hasSuffix:@"."]) 
            value = [value stringByRemovingSuffix:@"."];
    }
    else if ([correctFields containsObject:key] == NO) {
        // this is a field that isn't meaningful, so dump it into Annote
        addKeyValueToAnnote(key, value, pubFields);
        
        // bail out instead of adding to the dictionary
        return;
    }
    
    [pubFields setObject:[value stringByBackslashEscapingTeXSpecials] forKey:[key fieldName]];    
}

+ (NSArray *)itemsFromString:(NSString *)itemString error:(NSError **)outError;
{        
    // initial sanity check to make sure we have start/end tags
    NSRange r = [itemString rangeOfString:@"START_RECORD"];
    NSUInteger nStart = 0, nStop = 0;
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
        if (outError) {
            *outError = [NSError mutableLocalErrorWithCode:kBDSKUnknownError localizedDescription:NSLocalizedString(@"Unable to parse SciFinder data", @"error message for SciFinder")];
            [*outError setValue:NSLocalizedString(@"Unbalanced START_RECORD and END_RECORD tags", @"error message for SciFinder; do not translate START_RECORD or END_RECORD") forKey:NSLocalizedRecoverySuggestionErrorKey];
        }
        return nil;
    }
    
    // make sure we only deal with ASCII space and \n characters
    itemString = [itemString stringByNormalizingSpacesAndLineBreaks];
    
    // split into an array of strings, with one for each record
    NSArray *scfItems = [itemString componentsSeparatedByString:@"\nEND_RECORD"];

    NSMutableArray *toReturn = [NSMutableArray arrayWithCapacity:[scfItems count]];

    NSMutableDictionary *pubFields = [NSMutableDictionary new];
    
    for (NSString *str in scfItems) {

        // split each record up into field/value lines
        NSArray *lines = [str componentsSeparatedByString:@"\nFIELD "];
        
        for (NSString *line in lines) {
            
            NSString *key;
            NSString *value;
            
            // lots of keys have empty values, so check the return value of this method
            // some fields also seem to be continued, but those end up getting dumped into Annote
            if ([self copyKey:&key value:&value fromLine:line]) {
                fixAndAddKeyValueToDictionary(key, value, pubFields);
                [key release];
                [value release];
            }            
        }
        
        if ([pubFields count]) {
            NSString *type = [pubFields objectForKey:__documentTypeString];
            
            // leave Doc-Type as a field if we don't have a precise mapping
            if ([type isEqualToString:@"Journal"]) {
                type = BDSKArticleString;
                [pubFields removeObjectForKey:__documentTypeString];
            }else if ([type isEqualToString:@"Preprint"]) {
                // preprint is most likely an article type...but unpublished is probably more correct
                type = BDSKUnpublishedString;
            }else if ([type isEqualToString:@"Report"]) {
                // techreport should be more correct than journal, but unfortunately all types are described with the same keys
                if ([pubFields objectForKey:BDSKJournalString]) {
                    [pubFields setObject:[pubFields objectForKey:BDSKJournalString] forKey:BDSKInstitutionString];
                    [pubFields removeObjectForKey:BDSKJournalString];
                }
                type = BDSKTechreportString;
                [pubFields removeObjectForKey:__documentTypeString];
            }else {
                // SciFinder fields basically force everything to be an @article
                type = BDSKArticleString;
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
 
 http://www.google.com/search?q=cache:3Cg15n4kCGwJ:chemistry.library.wisc.edu/instruction/scifinder_taggedsample.txt+scifinder+START_RECORD&hl=en&ct=clnk&cd=4&gl=us
 http://wiki.refbase.net/index.php/Import_Example:_SciFinder
 
 From those and user-suppled info, we have the following doc types:
 
 FIELD Document Type:Journal; Online Computer File
 FIELD Document Type:Patent
 FIELD Document Type:Journal; Article; (JOURNAL ARTICLE)
 FIELD Document Type:Journal; Article; (JOURNAL ARTICLE)
 FIELD Document Type:Journal; Article; (JOURNAL ARTICLE)
 FIELD Document Type:Preprint
 FIELD Document Type:Journal; General Review
 FIELD Document Type:Report
 FIELD Document Type:Conference; General Review
 FIELD Document Type:Conference; Meeting Abstract; Computer Optical Disk
 FIELD Document Type:Conference
 FIELD Document Type:Journal; Article; (JOURNAL ARTICLE); (RESEARCH SUPPORT, NON-U.S. GOV'T)
 
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

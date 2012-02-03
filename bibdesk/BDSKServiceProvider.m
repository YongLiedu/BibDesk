//
//  BDSKServiceProvider.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 1/31/10.
/*
 This software is Copyright (c) 2010-2012
 Christiaan Hofman. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Christiaan Hofman nor the names of any
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

#import "BDSKServiceProvider.h"
#import "BibItem.h"
#import "BibDocument.h"
#import "BibDocument_Search.h"
#import "BibDocument_Actions.h"
#import "BibDocument_Groups.h"
#import "BDSKTemplate.h"
#import "BDSKTemplateObjectProxy.h"
#import "BDSKDocumentController.h"
#import "NSSet_BDSKExtensions.h"
#import "NSURL_BDSKExtensions.h"


@implementation BDSKServiceProvider

static id sharedServiceProvider = nil;

+ (id)sharedServiceProvider {
    if (sharedServiceProvider == nil)
        sharedServiceProvider = [[self alloc] init];
    return sharedServiceProvider;
}

- (id)init {
    BDSKPRECONDITION(sharedServiceProvider == nil);
    return [super init];
}

- (NSDictionary *)constraintsFromString:(NSString *)string{
    NSScanner *scanner;
    NSMutableDictionary *searchConstraints = [NSMutableDictionary dictionary];
    NSString *queryString = nil;
    NSString *queryKey = nil;
    NSCharacterSet *delimiterSet = [NSCharacterSet characterSetWithCharactersInString:@":="];
    NSCharacterSet *ampersandSet =  [NSCharacterSet characterSetWithCharactersInString:@"&"];

    if([string rangeOfCharacterFromSet:delimiterSet].location == NSNotFound){
        [searchConstraints setObject:[string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] forKey:BDSKTitleString];
        return searchConstraints;
    }
    
    
    scanner = [NSScanner scannerWithString:string];
    
    // Now split the string into a key and value pair by looking for a delimiter
    // (we'll use a bunch of handy delimiters, including the first space, so it's flexible.)
    // alternatively we can just type the title, like we used to.
    [scanner setCharactersToBeSkipped:nil];
    NSSet *citeKeyStrings = [NSSet setForCaseInsensitiveStringsWithObjects:@"cite key", @"citekey", @"cite-key", @"key", nil];
    
    while(![scanner isAtEnd]){
        // set these to nil explicitly, since we check for that later
        queryKey = nil;
        queryString = nil;
        [scanner scanUpToCharactersFromSet:delimiterSet intoString:&queryKey];
        [scanner scanCharactersFromSet:delimiterSet intoString:nil]; // scan the delimiters away
        [scanner scanUpToCharactersFromSet:ampersandSet intoString:&queryString]; // scan to either the end, or the next query key.
        [scanner scanCharactersFromSet:ampersandSet intoString:nil]; // scan the ampersands away.
        
        // lose the whitespace, if any
        queryString = [queryString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        queryKey = [queryKey stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        
        // allow some additional leeway with citekey
        if([citeKeyStrings containsObject:queryKey])
            queryKey = BDSKCiteKeyString;
        
        if(queryKey && queryString) // make sure we have both a key and a value
            [searchConstraints setObject:queryString forKey:[queryKey fieldName]]; // BibItem field names are capitalized
    }
    
    return searchConstraints;
}

// this only should return items that belong to a document, not items from external groups
// if this is ever changed, we should also change showPubWithKey:userData:error:
- (NSSet *)itemsMatchingSearchConstraints:(NSDictionary *)constraints{
    NSArray *docs = [[NSDocumentController sharedDocumentController] documents];
    if ([docs count] == 0)
        return nil;

    NSMutableSet *itemsFound = [NSMutableSet set];
    NSMutableArray *arrayOfSets = [NSMutableArray array];
    
    for (NSString *constraintKey in constraints) {
        for (BibDocument *aDoc in docs) { 
	    // this is an array of objects matching this particular set of search constraints; add them to the set
            [itemsFound addObjectsFromArray:[aDoc publicationsMatchingSubstring:[constraints objectForKey:constraintKey] 
                                                                        inField:constraintKey]];
        }
        // we have one set per search term, so copy it to an array and we'll get the next set of matches
        [arrayOfSets addObject:[[itemsFound copy] autorelease]];
        [itemsFound removeAllObjects];
    }
    
    // sort the sets in order of increasing length indexed 0-->[arrayOfSets length]
    NSSortDescriptor *setLengthSort = [[[NSSortDescriptor alloc] initWithKey:@"self.@count" ascending:YES selector:@selector(compare:)] autorelease];
    [arrayOfSets sortUsingDescriptors:[NSArray arrayWithObject:setLengthSort]];
    
    if ([arrayOfSets count]) {
        [itemsFound setSet:[arrayOfSets objectAtIndex:0]]; // smallest set
        for (NSSet *set in arrayOfSets)
            [itemsFound intersectSet:set];
    }
    
    return itemsFound;
}

- (NSSet *)itemsMatchingCiteKey:(NSString *)citeKeyString{
    NSDictionary *constraints = [NSDictionary dictionaryWithObject:citeKeyString forKey:BDSKCiteKeyString];
    return [self itemsMatchingSearchConstraints:constraints];
}

- (void)completeCitationFromSelection:(NSPasteboard *)pboard
                             userData:(NSString *)userData
                                error:(NSString **)error{
    NSString *pboardString;
    NSArray *types;
    NSSet *items;
    BDSKTemplate *template = [BDSKTemplate templateForCiteService];
    BDSKPRECONDITION(nil != template && ([template templateFormat] & BDSKPlainTextTemplateFormat));
    
    types = [pboard types];
    if (![types containsObject:NSStringPboardType]) {
        *error = NSLocalizedString(@"Error: couldn't complete text.",
                                   @"Error description for Service");
        return;
    }
    pboardString = [pboard stringForType:NSStringPboardType];
    if (!pboardString) {
        *error = NSLocalizedString(@"Error: couldn't complete text.",
                                   @"Error description for Service");
        return;
    }

    NSDictionary *searchConstraints = [self constraintsFromString:pboardString];
    
    if(searchConstraints == nil){
        *error = NSLocalizedString(@"Error: invalid search constraints.",
                                   @"Error description for Service");
        return;
    }        

    items = [self itemsMatchingSearchConstraints:searchConstraints];
    
    if([items count] > 0){
        NSString *fileTemplate = [BDSKTemplateObjectProxy stringByParsingTemplate:template withObject:self publications:[items allObjects]];
        
        types = [NSArray arrayWithObject:NSStringPboardType];
        [pboard declareTypes:types owner:nil];

        [pboard setString:fileTemplate forType:NSStringPboardType];
    }
    return;
}

- (void)completeTextBibliographyFromSelection:(NSPasteboard *)pboard
                                     userData:(NSString *)userData
                                        error:(NSString **)error{
    NSString *pboardString;
    NSArray *types;
    NSSet *items;
    BDSKTemplate *template = [BDSKTemplate templateForTextService];
    BDSKPRECONDITION(nil != template && ([template templateFormat] & BDSKPlainTextTemplateFormat));
    
    types = [pboard types];
    if (![types containsObject:NSStringPboardType]) {
        *error = NSLocalizedString(@"Error: couldn't complete text.",
                                   @"Error description for Service");
        return;
    }
    pboardString = [pboard stringForType:NSStringPboardType];
    if (!pboardString) {
        *error = NSLocalizedString(@"Error: couldn't complete text.",
                                   @"Error description for Service");
        return;
    }

    NSDictionary *searchConstraints = [self constraintsFromString:pboardString];
    
    if(searchConstraints == nil){
        *error = NSLocalizedString(@"Error: invalid search constraints.",
                                   @"Error description for Service");
        return;
    }        

    items = [self itemsMatchingSearchConstraints:searchConstraints];
    
    if([items count] > 0){
        NSString *fileTemplate = [BDSKTemplateObjectProxy stringByParsingTemplate:template withObject:self publications:[items allObjects]];
        
        types = [NSArray arrayWithObject:NSStringPboardType];
        [pboard declareTypes:types owner:nil];

        [pboard setString:fileTemplate forType:NSStringPboardType];
    }
    return;
}

- (void)completeRichBibliographyFromSelection:(NSPasteboard *)pboard
                                     userData:(NSString *)userData
                                        error:(NSString **)error{
    NSString *pboardString;
    NSArray *types;
    NSSet *items;
    BDSKTemplate *template = [BDSKTemplate templateForRTFService];
    BDSKPRECONDITION(nil != template && [template templateFormat] == BDSKRTFTemplateFormat);
    
    types = [pboard types];
    if (![types containsObject:NSStringPboardType]) {
        *error = NSLocalizedString(@"Error: couldn't complete text.",
                                   @"Error description for Service");
        return;
    }
    pboardString = [pboard stringForType:NSStringPboardType];
    if (!pboardString) {
        *error = NSLocalizedString(@"Error: couldn't complete text.",
                                   @"Error description for Service");
        return;
    }

    NSDictionary *searchConstraints = [self constraintsFromString:pboardString];
    
    if(searchConstraints == nil){
        *error = NSLocalizedString(@"Error: invalid search constraints.",
                                   @"Error description for Service");
        return;
    }        

    items = [self itemsMatchingSearchConstraints:searchConstraints];
    
    if([items count] > 0){
        NSDictionary *docAttributes = nil;
        NSAttributedString *fileTemplate = [BDSKTemplateObjectProxy attributedStringByParsingTemplate:template withObject:self publications:[items allObjects] documentAttributes:&docAttributes];
        NSData *pboardData = [fileTemplate RTFFromRange:NSMakeRange(0, [fileTemplate length]) documentAttributes:docAttributes];
        
        types = [NSArray arrayWithObject:NSRTFPboardType];
        [pboard declareTypes:types owner:nil];

        [pboard setData:pboardData forType:NSRTFPboardType];
    }
    return;
}

- (void)completeCiteKeyFromSelection:(NSPasteboard *)pboard
                             userData:(NSString *)userData
                                error:(NSString **)error{

    NSArray *types = [pboard types];
    if (![types containsObject:NSStringPboardType]) {
        *error = NSLocalizedString(@"Error: couldn't complete text.",
                                   @"Error description for Service");
        return;
    }
    NSString *pboardString = [pboard stringForType:NSStringPboardType];
    NSSet *items = [self itemsMatchingCiteKey:pboardString];
    
    // if no matches, we'll return the original string unchanged
    if ([items count]) {
        pboardString = [[[[items allObjects] valueForKey:@"citeKey"] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)] componentsJoinedByString:@", "];
    }
    
    types = [NSArray arrayWithObject:NSStringPboardType];
    [pboard declareTypes:types owner:nil];
    [pboard setString:pboardString forType:NSStringPboardType];
}

- (void)showPubWithKey:(NSPasteboard *)pboard
			  userData:(NSString *)userData
				 error:(NSString **)error{	
    NSArray *types = [pboard types];
    if (![types containsObject:NSStringPboardType]) {
        *error = NSLocalizedString(@"Error: couldn't complete text.",
                                   @"Error description for Service");
        return;
    }
    NSString *pboardString = [pboard stringForType:NSStringPboardType];

    NSSet *items = [self itemsMatchingCiteKey:pboardString];
	
    for (BibItem *item in items) {   
        // these should all be items belonging to a BibDocument, see remark before itemsMatchingSearchConstraints:
		[(BibDocument *)[item owner] editPub:item];
    }

}

- (void)openDocumentFromSelection:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error{	

    id doc = [[NSDocumentController sharedDocumentController] openUntitledDocumentAndDisplay:YES error:NULL];
    NSError *nsError = nil;
    
    if([doc addPublicationsFromPasteboard:pboard selectLibrary:YES verbose:NO error:&nsError] == nil){
        if(error)
            *error = [nsError localizedDescription];
    }
}

- (void)addPublicationsFromSelection:(NSPasteboard *)pboard
						   userData:(NSString *)userData
							  error:(NSString **)error{	
	
	// add to the frontmost bibliography
	BibDocument * doc = [[NSDocumentController sharedDocumentController] mainDocument];
    if ([doc isKindOfClass:[BibDocument class]] == NO) {
        for (doc in [NSApp orderedDocuments])
            if ([doc isKindOfClass:[BibDocument class]]) break;
    }
    if (doc == nil) {
        // create a new document if we don't have one, or else this method appears to fail mysteriosly (since the error isn't displayed)
        [self openDocumentFromSelection:pboard userData:userData error:error];
	} else {
        NSError *addError = nil;
        if([doc addPublicationsFromPasteboard:pboard selectLibrary:YES verbose:NO error:&addError] == nil || addError != nil)
        if(error) *error = [addError localizedDescription];
    }
}

- (void)openURLInWebGroup:(NSPasteboard *)pboard 
                 userData:(NSString *)userData 
                    error:(NSString **)error {
	// open in the frontmost bibliography
	BibDocument * doc = [[NSDocumentController sharedDocumentController] mainDocument];
    if ([doc isKindOfClass:[BibDocument class]] == NO) {
        for (doc in [NSApp orderedDocuments])
            if ([doc isKindOfClass:[BibDocument class]]) break;
    }
    if (doc == nil) {
        // create a new document if we don't have one, or else this method appears to fail mysteriosly (since the error isn't displayed)
        doc = [[NSDocumentController sharedDocumentController] openUntitledDocumentAndDisplay:YES error:NULL];
    }
    NSURL *theURL = [NSURL URLFromPasteboardAnyType:pboard];
    if (theURL) {
        [doc openURL:theURL];
    }
}

@end

//
//  BDSKMARCParser.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 12/4/06.
/*
 This software is Copyright (c) 2006
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

#import "BDSKMARCParser.h"
#import "NSString_BDSKExtensions.h"
#import "BibTypeManager.h"
#import "BibItem.h"
#import "BibAppController.h"
#import <OmniFoundation/NSScanner-OFExtensions.h>


@interface BDSKMARCParser (Private)
static void addStringToDictionary(NSMutableString *value, NSMutableDictionary *dict, NSString *tag);
@end


@implementation BDSKMARCParser

+ (BOOL)canParseString:(NSString *)string{
	return [string hasPrefix:@"LDR "];
}

+ (NSArray *)itemsFromString:(NSString *)itemString error:(NSError **)outError{
    // make sure that we only have one type of space and line break to deal with, since HTML copy/paste can have odd whitespace characters
    itemString = [itemString stringByNormalizingSpacesAndLineBreaks];
	
    BibItem *newBI = nil;
    NSMutableArray *returnArray = [NSMutableArray arrayWithCapacity:10];
	NSArray *keyArray = nil;
    NSError *error = nil;
	
    NSArray *sourceLines = [itemString sourceLinesBySplittingString];
    
    NSEnumerator *sourceLineE = [sourceLines objectEnumerator];
    NSString *sourceLine = nil;
    
    //dictionary is the publication entry
    NSMutableDictionary *pubDict = [[NSMutableDictionary alloc] init];
    
    NSString *tag = nil;
    NSString *tmpTag = nil;
    NSString *value = nil;
    NSMutableString *mutableValue = [NSMutableString string];
    BibTypeManager *typeManager = [BibTypeManager sharedManager];
    NSCharacterSet *whitespaceAndNewlineCharacterSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    
    while(sourceLine = [sourceLineE nextObject]){
        
        if([sourceLine length] < 3)
            continue;
        
        tmpTag = [sourceLine substringToIndex:3];
        
        if([tmpTag hasPrefix:@" "]){
            // continuation of a value
            
			value = [sourceLine stringByTrimmingCharactersInSet:whitespaceAndNewlineCharacterSet];
            [mutableValue appendString:@" "];
            [mutableValue appendString:value];
            
        }else if([tmpTag isEqualToString:@"LDR"]){
            // start of a new item, first safe the last one
            
            if([pubDict count] > 0){
                newBI = [[BibItem alloc] initWithType:BDSKBookString
                                             fileType:BDSKBibtexString
                                              citeKey:nil
                                            pubFields:pubDict
                                                isNew:YES];
                [returnArray addObject:newBI];
                [newBI release];
            }
            
            // we don't care about the rest of the leader
            continue;
            
        }else if([sourceLine length] > 6){
			// first save the last key/value pair if necessary
            
            if(tag && [mutableValue length])
                addStringToDictionary(mutableValue, pubDict, tag);
            
            tag = tmpTag;
            value = [[sourceLine substringFromIndex:6] stringByTrimmingCharactersInSet:whitespaceAndNewlineCharacterSet];
            [mutableValue setString:value];
            
        }
        
    }
    
    // add the last key/value pair
    if(tag && [mutableValue length])
        addStringToDictionary(mutableValue, pubDict, tag);
	
	// add the last item
	if([pubDict count] > 0){
		
		newBI = [[BibItem alloc] initWithType:BDSKBookString
									 fileType:BDSKBibtexString
									  citeKey:nil
									pubFields:pubDict
                                        isNew:YES];
		[returnArray addObject:newBI];
		[newBI release];
	}
    
    [pubDict release];
    return returnArray;
}

@end


@implementation BDSKMARCParser (Private)

static void addStringToDictionary(NSMutableString *value, NSMutableDictionary *pubDict, NSString *tag){
	NSString *subTag = nil;
    NSString *key = nil;
    NSDictionary *fieldsForSubTags = [[BibTypeManager sharedManager] fieldNamesForMARCTag:tag];
    NSString *subValue = nil;
	
    NSScanner *scanner = [[NSScanner alloc] initWithString:value];
    
    [scanner setCharactersToBeSkipped:nil];
    
    while([scanner isAtEnd] == NO){
        if(NO == [scanner scanString:@"$" intoString:NULL] || NO == [scanner scanStringOfLength:1 intoString:&subTag])
            break;
        
        if([scanner scanUpToString:@"$" intoString:&subValue] &&
           (key = [fieldsForSubTags objectForKey:subTag])){
            
            if([pubDict objectForKey:key] == nil)
                [pubDict setObject:[subValue stringByConvertingHTMLToTeX] forKey:key];
        }
    }
}

@end

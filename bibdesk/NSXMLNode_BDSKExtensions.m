//
//  NSXMLNode_BDSKExtensions.m
//  Bibdesk
//
//  Created by Michael McCracken on 9/26/07.
/*
 This software is Copyright (c) 2007-2011
 Michael O. McCracken. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 - Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in
 the documentation and/or other materials provided with the
 distribution.
 
 - Neither the name of Michael O. McCracken nor the names of any
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

#import "NSXMLNode_BDSKExtensions.h"


@implementation NSXMLNode (BDSKExtensions)

- (NSString *)stringValueOfAttribute:(NSString *)attrName{
    NSError *err = nil;
    NSString *path = [NSString stringWithFormat:@"./@%@", attrName];
    NSArray *atts = [self nodesForXPath:path error:&err];
    if ([atts count] == 0) return nil;
    return [[atts objectAtIndex:0] stringValue];
}

- (NSArray *)descendantOrSelfNodesWithClassName:(NSString *)className error:(NSError **)err{
    NSString *path = [NSString stringWithFormat:@".//*[contains(concat(' ', normalize-space(@class), ' '), ' %@ ')]", className];
     NSArray *ar = [self nodesForXPath:path error:err];
     return ar;
}

- (BOOL)hasParentWithClassName:(NSString *)class{
    
    NSXMLNode *parent = [self parent];
    
    do{
        if([parent kind] != NSXMLElementKind) return NO; // handles root node
        
        NSArray *parentClassNames = [parent classNames];
        
        if ([parentClassNames containsObject:class]){ 
            return YES;
        }
        
    }while(parent = [parent parent]);
    
    return NO;
}


- (NSArray *)classNames{
    
    if([self kind] != NSXMLElementKind) [NSException raise:NSInvalidArgumentException format:@"wrong node kind"];
    
    NSMutableArray *a = [NSMutableArray arrayWithCapacity:0];
    
    NSError *err = nil;
    
    NSArray *classNodes = [self nodesForXPath:@"@class"
                                        error:&err];
    if([classNodes count] == 0) 
        return a;
    
    NSAssert ([classNodes count] == 1, @"too many nodes in classNodes");
    
    NSXMLNode *classNode = [classNodes objectAtIndex:0];
    
    [a addObjectsFromArray:[[classNode stringValue] componentsSeparatedByString:@" "]];
    
    return a;
}


- (NSString *)fullStringValueIfABBR{
    NSError *err;
    if([self kind] != NSXMLElementKind) [NSException raise:NSInvalidArgumentException format:@"wrong node kind"];
    
    if([[self name] isEqualToString:@"abbr"]){
        //todo: will need more robust comparison for namespaced node titles.
        
        // return value of title attribute instead
        NSArray *titleNodes = [self nodesForXPath:@"@title"
                                            error:&err];
        if([titleNodes count] > 0){
            return [[titleNodes objectAtIndex:0] stringValue];
        }            
    }
    
    return [self stringValue];
}

- (NSString *)searchXPath:(NSString *)searchPath addTo:(NSMutableDictionary *)dict forKey:(NSString *)key {
	return [self searchXPath:searchPath
					   addTo:dict
					  forKey:key
						last:NO];
}

- (NSString *)searchXPath:(NSString *)searchPath addTo:(NSMutableDictionary *)dict forKey:(NSString *)key last:(BOOL)last {
	NSError *error = nil;
	NSArray *nodes = [self nodesForXPath:searchPath error:&error];
	NSString *string = nil;
	if (nil != nodes && 0 < [nodes count]) {
		if (last) {
			string = [[nodes objectAtIndex:([nodes count] - 1)] stringValue];
		} else {
			string = [[nodes objectAtIndex:0] stringValue];
		}
		if (string) {
			string = [string stringByRemovingSurroundingWhitespaceAndNewlines];
			if (dict != nil) {
				[dict setValue:string forKey:key];
			}
		}
	}
	return string;
}

@end
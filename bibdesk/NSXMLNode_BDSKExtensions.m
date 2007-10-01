//
//  NSXMLNode_BDSKExtensions.m
//  Bibdesk
//
//  Created by Michael McCracken on 9/26/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

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

@end
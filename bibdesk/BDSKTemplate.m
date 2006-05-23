//
//  BDSKTemplate.m
//  Bibdesk
//
//  Created by Adam Maxwell on 05/23/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "BDSKTemplate.h"
#import "BDAlias.h"
#import "NSFileManager_BDSKExtensions.h"

NSString *BDSKTemplateRoleString = @"role";
NSString *BDSKTemplateNameString = @"name";
NSString *BDSKExportTemplateTree = @"BDSKExportTemplateTree";

NSString *BDSKTemplateAccessoryString = @"Accessory File";
NSString *BDSKTemplateMainPageString = @"Main Page";
NSString *BDSKTemplateDefaultItemString = @"Default Item";

@implementation BDSKTemplate

#pragma mark API for templates

+ (NSArray *)allStyleNames;
{
    NSMutableArray *names = [NSMutableArray array];
    NSEnumerator *nodeE = [[NSKeyedUnarchiver unarchiveObjectWithData:[[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKExportTemplateTree]] objectEnumerator];
    id aNode;
    while(aNode = [nodeE nextObject]){
        if(NO == [aNode isLeaf])
            [names addObject:[aNode valueForKey:BDSKTemplateNameString]];
    }
    return names;
}

+ (NSArray *)allStyleNamesForFormat:(BDSKTemplateFormat)formatType;
{
    NSMutableArray *names = [NSMutableArray array];
    NSEnumerator *nodeE = [[NSKeyedUnarchiver unarchiveObjectWithData:[[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKExportTemplateTree]] objectEnumerator];
    id aNode;
    while(aNode = [nodeE nextObject]){
        if(NO == [aNode isLeaf] && [aNode templateFormat] == formatType)
            [names addObject:[aNode valueForKey:BDSKTemplateNameString]];
    }
    return names;
}

// accesses the node array in prefs
+ (BDSKTemplate *)templateForStyle:(NSString *)styleName;
{
    NSEnumerator *nodeE = [[NSKeyedUnarchiver unarchiveObjectWithData:[[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKExportTemplateTree]] objectEnumerator];
    id aNode = nil;
    
    while(aNode = [nodeE nextObject]){
        if(NO == [aNode isLeaf] && [[aNode valueForKey:BDSKTemplateNameString] isEqualToString:styleName])
            break;
    }
    return aNode;
}

- (BDSKTemplateFormat)templateFormat;
{
    OBASSERT([self isLeaf] == NO);
    NSString *extension = [[self valueForKey:BDSKTemplateRoleString] lowercaseString];
    if ([extension caseInsensitiveCompare:@"rtf"] == NSOrderedSame)
        return BDSKRTFTemplateFormat;
    else if ([extension caseInsensitiveCompare:@"doc"] == NSOrderedSame)
        return BDSKDocTemplateFormat;
    else    
        return BDSKTextTemplateFormat;
}

- (NSString *)fileExtension;
{
    OBASSERT([self isLeaf] == NO);
    return [self valueForKey:BDSKTemplateRoleString];
}

- (NSURL *)mainPageTemplateURL;
{
    return [self templateURLForType:BDSKTemplateMainPageString];
}

- (NSURL *)defaultItemTemplateURL;
{
    return [self templateURLForType:BDSKTemplateDefaultItemString];
}

- (NSURL *)templateURLForType:(NSString *)pubType;
{
    OBASSERT([self isLeaf] == NO);
    NSParameterAssert(nil != pubType);
    return [[self childForRole:pubType] representedFileURL];
}

- (NSArray *)accessoryFileURLs;
{
    OBASSERT([self isLeaf] == NO);
    NSMutableArray *fileURLs = [NSMutableArray array];
    NSEnumerator *childE = [[self children] objectEnumerator];
    BDSKTemplate *aChild;
    NSURL *fileURL;
    while(aChild = [childE nextObject]){
        if([[aChild valueForKey:BDSKTemplateRoleString] isEqualToString:BDSKTemplateAccessoryString]){
            fileURL = [aChild representedFileURL];
            if(fileURL)
                [fileURLs addObject:fileURL];
        }
    }
    return fileURLs;
}

- (BOOL)addChildWithURL:(NSURL *)fileURL role:(NSString *)role;
{
    BOOL retVal;
    retVal = [[NSFileManager defaultManager] objectExistsAtFileURL:fileURL];
    if(retVal){
        BDSKTemplate *newChild = [[BDSKTemplate alloc] init];
        
        [newChild setValue:[[fileURL path] lastPathComponent] forKey:BDSKTemplateNameString];
        [newChild setValue:role forKey:BDSKTemplateRoleString];
        // don't add it if the alias fails
        if([newChild setAliasFromURL:fileURL])
            [self addChild:newChild];
        else
            retVal = NO;
        [newChild release];
    }        
    return retVal;
}

- (id)childForRole:(NSString *)role;
{
    NSParameterAssert(nil != role);
    NSEnumerator *nodeE = [[self children] objectEnumerator];
    id aNode = nil;
    
    // assume roles are unique by grabbing the first one; this works for any case except the accessory files
    while(aNode = [nodeE nextObject]){
        if([[aNode valueForKey:BDSKTemplateRoleString] isEqualToString:role])
            break;
    }
    return aNode;
}

- (BOOL)setAliasFromURL:(NSURL *)aURL;
{
    BDAlias *alias = nil;
    alias = [[BDAlias alloc] initWithURL:aURL];
    
    BOOL rv = (nil != alias);
    
    if(alias)
        [self setValue:[alias aliasData] forKey:@"_BDAlias"];
    [alias release];
    
    return rv;
}

- (NSURL *)representedFileURL;
{
    return [[BDAlias aliasWithData:[self valueForKey:@"_BDAlias"]] fileURLNoUI];
}

- (NSColor *)representedColorForKey:(NSString *)key;
{
    NSColor *color = [NSColor controlTextColor];
    if([key isEqualToString:BDSKTemplateNameString] && [self isLeaf]){
        NSURL *fileURL = [self representedFileURL];
        if(nil == fileURL)
            color = [NSColor redColor];
    }
    return color;
}

- (BOOL)hasChildWithRole:(NSString *)aRole;
{
    NSEnumerator *roleEnum = [[self children] objectEnumerator];
    id aChild;
    while(aChild = [roleEnum nextObject]){
        if([[aChild valueForKey:BDSKTemplateRoleString] isEqualToString:aRole])
            return YES;
    }
    return NO;
}

@end

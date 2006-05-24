//
//  BDSKTemplate.m
//  Bibdesk
//
//  Created by Adam Maxwell on 05/23/06.
/*
 This software is Copyright (c) 2006
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
    NSString *name;
    while(aNode = [nodeE nextObject]){
        if(NO == [aNode isLeaf]){
            name = [aNode valueForKey:BDSKTemplateNameString];
            if(name != nil)
                [names addObject:name];
        }
    }
    return names;
}

+ (NSArray *)allStyleNamesForFormat:(BDSKTemplateFormat)formatType;
{
    NSMutableArray *names = [NSMutableArray array];
    NSEnumerator *nodeE = [[NSKeyedUnarchiver unarchiveObjectWithData:[[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKExportTemplateTree]] objectEnumerator];
    id aNode;
    NSString *name;
    while(aNode = [nodeE nextObject]){
        if(NO == [aNode isLeaf] && [aNode templateFormat] == formatType){
            name = [aNode valueForKey:BDSKTemplateNameString];
            if(name != nil)
                [names addObject:name];
        }
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
    if (extension == nil)
        return BDSKUnknownTemplateFormat;
    else if ([extension caseInsensitiveCompare:@"rtf"] == NSOrderedSame)
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
        if(nil == [self representedFileURL])
            color = [NSColor redColor];
    }else if(nil == [self valueForKey:key]){
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

// 
//  BDSKGroup.m
//  bd2xtest
//
//  Created by Christiaan Hofman on 2/4/06.
//  Copyright 2006. All rights reserved.
//

#import "BDSKGroup.h"


@implementation BDSKGroup 

+ (void)initialize {
    [self setKeys:[NSArray arrayWithObjects:@"items", @"children", nil] 
        triggerChangeNotificationsForDependentKey:@"itemsInSelfOrChildren"];
    [self setKeys:[NSArray arrayWithObjects:@"name", @"groupImageName", nil] 
        triggerChangeNotificationsForDependentKey:@"nameAndIcon"];
    [self setKeys:[NSArray arrayWithObjects:@"groupImageName", nil] 
        triggerChangeNotificationsForDependentKey:@"icon"];
}

- (NSString *)itemEntityName {
    NSString *entityName = nil;
    [self willAccessValueForKey:@"itemEntityName"];
    entityName = [self primitiveValueForKey:@"itemEntityName"];
    [self didAccessValueForKey:@"itemEntityName"];
    return entityName;
}

- (void)setItemEntityName:(NSString *)entityName {
    [self willChangeValueForKey: @"itemEntityName"];
    [self setPrimitiveValue:entityName forKey:@"itemEntityName"];
    [self didChangeValueForKey:@"itemEntityName"];
}

- (NSString *)groupImageName {
    return @"GroupIcon";
}

- (NSImage *)icon{
    if (cachedIcon == nil && [self groupImageName] != nil) {
        cachedIcon = [[NSImage imageNamed:[self groupImageName]] copy];
        [cachedIcon setScalesWhenResized:YES];
        [cachedIcon setSize:NSMakeSize(16, 16)];
    }
    return cachedIcon;
}

- (NSDictionary *)nameAndIcon{
    return [NSDictionary dictionaryWithObjectsAndKeys:[self valueForKey:@"name"], @"name", [self valueForKey:@"icon"], @"icon", nil];
}

- (void)setNameAndIcon:(NSString *)name{
    [self setValue:name forKey:@"name"];
}

- (BOOL)isSmart {
    return NO;
}

- (BOOL)isAuto {
    return NO;
}

- (BOOL)canEdit {
    return NO;
}

- (BOOL)canEditName {
    return YES;
}

- (NSSet *)itemsInSelfOrChildren {
    return [self valueForKey:@"items"];
}

@end

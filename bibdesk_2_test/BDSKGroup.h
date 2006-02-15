//
//  BDSKGroup.h
//  bd2xtest
//
//  Created by Christiaan Hofman on 2/4/06.
//  Copyright 2006. All rights reserved.
//

#import <CoreData/CoreData.h>


@interface BDSKGroup :  NSManagedObject {
    NSImage *cachedIcon;
}

- (NSString *)groupImageName;
- (NSImage *)icon;

- (NSDictionary *)nameAndIcon;
- (void)setNameAndIcon:(NSString *)name;

- (BOOL)isSmart;

- (BOOL)canEdit;
- (BOOL)canEditName;

@end

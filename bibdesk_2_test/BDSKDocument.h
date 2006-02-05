//  BDSKDocument.h
//  bd2
//
//  Created by Michael McCracken on 5/14/05.
//  Copyright Michael McCracken 2005 . All rights reserved.

#import <Cocoa/Cocoa.h>
#import "BDSKDataModelNames.h"
#import "BDSKMainWindowController.h"

#define BDSKPublicationPboardType @"BDSKPublicationPboardType"
#define BDSKPersonPboardType @"BDSKPersonPboardType"
#define BDSKNotePboardType @"BDSKNotePboardType"

@interface BDSKDocument : NSPersistentDocument {
}

- (NSManagedObject *)rootPublicationGroup;
- (NSManagedObject *)rootPersonGroup;
- (NSManagedObject *)rootNoteGroup;
- (NSManagedObject *)rootGroupForEntityName:(NSString *)entityName;

@end

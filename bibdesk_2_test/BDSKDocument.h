//  BDSKDocument.h
//  bd2
//
//  Created by Michael McCracken on 5/14/05.
//  Copyright Michael McCracken 2005 . All rights reserved.

#import <Cocoa/Cocoa.h>
#import "BDSKDataModelNames.h"
#import "BDSKMainWindowController.h"

extern NSString *BDSKPublicationPboardType;
extern NSString *BDSKPersonPboardType;
extern NSString *BDSKNotePboardType;
extern NSString *BDSKInstitutionPboardType;
extern NSString *BDSKVenuePboardType;
extern NSString *BDSKTagPboardType;

@interface BDSKDocument : NSPersistentDocument {
}

- (NSManagedObject *)rootPublicationGroup;
- (NSManagedObject *)rootPersonGroup;
- (NSManagedObject *)rootNoteGroup;
- (NSManagedObject *)rootInstitutionGroup;
- (NSManagedObject *)rootVenueGroup;
- (NSManagedObject *)rootGroupForEntityName:(NSString *)entityName;
- (NSManagedObject *)rootTagGroup;

- (NSSet *)newPublicationsFromDictionaries:(NSSet *)dictionarySet;

@end

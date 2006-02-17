//
//  BDSKSmartGroupEditor.h
//  bd2
//
//  Created by Christiaan Hofman on 2/15/06.
//  Copyright 2006. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "BDSKComparisonPredicateController.h"

@class BDSKPredicateView;


@interface BDSKSmartGroupEditor : NSWindowController {
    IBOutlet BDSKPredicateView *mainView;
    NSManagedObjectContext *managedObjectContext;
    NSString *entityName;
    NSString *propertyName;
    int conjunction;
    NSDictionary *predicateRules;
    NSMutableArray *controllers;
    CFArrayRef editors;
}

- (IBAction)add:(id)sender;
- (IBAction)remove:(BDSKComparisonPredicateController *)controller;

- (NSManagedObjectContext *)managedObjectContext;
- (void)setManagedObjectContext:(NSManagedObjectContext *)context;

- (NSString *)entityName;
- (void)setEntityName:(NSString *)newEntityName;

- (NSString *)propertyName;
- (void)setPropertyName:(NSString *)newPropertyName;

- (int)conjunction;
- (void)setConjunction:(int)value;

- (NSPredicate *)predicate;
- (void)setPredicate:(NSPredicate *)newPredicate;

- (NSArray *)entityNames;
- (NSArray *)propertyNames;

- (NSArray *)operatorNamesForTypeName:(NSString *)attributeTypeName;
- (NSPredicateOperatorType)operatorTypeForOperatorName:(NSString *)operatorName;
- (NSString *)operatorNameForOperatorType:(NSPredicateOperatorType)operatorType;

- (BOOL)isCompound;

- (void)reset;

- (IBAction)closeEditor:(id)sender;
 
@end


@interface BDSKPredicateView : NSView {
}

- (void)addView:(NSView *)view;
- (void)removeView:(NSView *)view;
- (void)removeAllSubviews;
- (void)updateSize;

@end

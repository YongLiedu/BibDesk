//
//  BDSKComparisonPredicateController.m
//  bd2
//
//  Created by Christiaan Hofman on 2/15/06.
//  Copyright 2006. All rights reserved.
//

#import "BDSKComparisonPredicateController.h"
#import "BDSKSmartGroupEditor.h"


@implementation BDSKComparisonPredicateController

+ (void)initialize {
    [self setKeys:[NSArray arrayWithObjects:@"smartGroupEditor", nil]
        triggerChangeNotificationsForDependentKey:@"propertyNames"];
    [self setKeys:[NSArray arrayWithObjects:@"smartGroupEditor", @"propertyName", nil]
        triggerChangeNotificationsForDependentKey:@"operatorNames"];
}

- (id)init {
    self = [self initWithEditor:nil];
    return self;

}

- (id)initWithEditor:(BDSKSmartGroupEditor *)anEditor {
    if (self = [super init]) {
        smartGroupEditor = anEditor;
        predicateRules = [[NSDictionary alloc] initWithContentsOfFile:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"PredicateRules.plist"]];
		propertyName = nil;
		operatorName = nil;
		searchValue = nil;
        
        BOOL success = [NSBundle loadNibNamed:@"BDSKComparisonPredicateView" owner:self];
		if (success == NO) {
			NSLog(@"Could not load PredicateComparisonView.");
		}
    }
    return self;
}

- (void)dealloc {
    smartGroupEditor = nil;
    [propertyName release], propertyName = nil;
    [operatorName release], operatorName = nil;
    [searchValue release], searchValue = nil;
    [predicateRules release], predicateRules = nil;
    [view release], view = nil;
	[ownerController release], ownerController = nil;
    [super dealloc];
}

- (void)awakeFromNib {
	[ownerController setContent:self]; // fix for binding-to-nib-owner bug
}

- (void)cleanup {
	[ownerController setContent:nil]; // fix for binding-to-nib-owner bug
}

- (NSView *)view {
    return view;
}

- (void)remove:(id)sender {
    [self cleanup];
    [[self smartGroupEditor] remove:self];
}

#pragma mark Accessors

- (BDSKSmartGroupEditor *)smartGroupEditor {
    return smartGroupEditor;
}

- (void)setSmartGroupEditor:(BDSKSmartGroupEditor *)newEditor {
    smartGroupEditor = newEditor;
}

// TODO: we might want to allow negated predicates, so we can support "does not contain" etc., maybe also custom operator types
// TODO: adding arbitrary keys (keyValuePairs)
- (NSPredicate *)predicate {
    id value = [self searchValue];
    NSString *typeName = [self attributeTypeName];
    
    if ([typeName isEqualToString:@"string"]) {
    } else if ([typeName isEqualToString:@"number"]) {
        value = [NSNumber numberWithInt:[value intValue]];
    } else if ([typeName isEqualToString:@"date"]) {
        value = [NSDate dateWithNaturalLanguageString:value];
    } else if ([typeName isEqualToString:@"boolean"]) {
        value = [NSNumber numberWithBool:[value boolValue]];
    }
    
    NSExpression *propertyExpression = [NSExpression expressionForKeyPath:[self propertyName]];
    NSExpression *valueExpression = [NSExpression expressionForConstantValue:value];
    NSExpression *leftExpression;
    NSExpression *rightExpression;
    NSPredicateOperatorType operatorType = [self operatorType];
    NSComparisonPredicateModifier modifier = [self prependAnyString] ? NSDirectPredicateModifier : NSAnyPredicateModifier;
    
    if (operatorType == NSInPredicateOperatorType) {
        leftExpression = valueExpression;
        rightExpression = propertyExpression;
    } else {
        leftExpression = propertyExpression;
        rightExpression = valueExpression;
    }
    
    return [NSComparisonPredicate predicateWithLeftExpression:leftExpression
                                              rightExpression:rightExpression
                                                     modifier:modifier
                                                         type:operatorType
                                                      options:0];
}

- (void)setPredicate:(NSPredicate *)newPredicate {
    if ([newPredicate isKindOfClass:[NSComparisonPredicate class]] == NO) {
        [self setPropertyName:nil];
        [self setOperatorName:nil];
        [self setSearchValue:nil];
        return;
    }
    
    NSComparisonPredicate *predicate = (NSComparisonPredicate *)newPredicate;
    int operatorType = [predicate predicateOperatorType];
    
    // The IN operator type corresonds to "foo contains'f'", but the expressions are reversed to look like "'f' IN foo" so we need to special case
    if (operatorType == NSInPredicateOperatorType) {
        [self setPropertyName:[[predicate rightExpression] keyPath]];
        [self setSearchValue:[[predicate leftExpression] constantValue]];
    } else {
        [self setPropertyName:[[predicate leftExpression] keyPath]];
        [self setSearchValue:[[predicate rightExpression] constantValue]];
    }
    [self setOperatorType:operatorType];
}

- (NSString *)propertyName {
    return propertyName;
}

- (void)setPropertyName:(NSString *)value {
    if (propertyName != value) {
        [propertyName release];
        propertyName = [value retain];
        
        if (operatorName != nil && [[[self operatorNames] valueForKey:@"operatorName"] containsObject:operatorName] == NO)
            [self setOperatorName:nil];
    }
}

- (NSString *)operatorName {
    return operatorName;
}

- (void)setOperatorName:(NSString *)value {
    if (operatorName != value) {
        [operatorName release];
        operatorName = [value retain];
    }
}

- (NSString *)searchValue {
    return searchValue;
}

- (void)setSearchValue:(NSString *)value {
    if (searchValue != value) {
        [searchValue release];
        searchValue = [value retain];
    }
}

- (BOOL)prependAnyString {
    NSManagedObjectContext *context = [[self smartGroupEditor] managedObjectContext];
    NSString *entityName = [smartGroupEditor entityName]; 
    NSEntityDescription *entity = [NSEntityDescription entityForName:entityName inManagedObjectContext:context];
    
    if (propertyName != nil && entity != nil) {
        NSArray *components = [propertyName componentsSeparatedByString:@"."];
        int i, count = [components count];
        NSRelationshipDescription *relationship;
        NSString *key;
        
        if (count > 1) {
            count --;
            for (i = 0; i < count; i++) {
                key = [components objectAtIndex:i];
                relationship = [[entity relationshipsByName] objectForKey:key];
                if ([relationship isToMany])
                    return YES;
                entity = [relationship destinationEntity];
            }
        }        
    }
    
    return NO;
}

- (NSAttributeDescription *)attribute {
    NSManagedObjectContext *context = [[self smartGroupEditor] managedObjectContext];
    NSString *entityName = [smartGroupEditor entityName]; 
    NSEntityDescription *entity = [NSEntityDescription entityForName:entityName inManagedObjectContext:context];
    NSAttributeDescription *attribute = nil;
    
    if (propertyName != nil && entity != nil) {
        NSArray *components = [propertyName componentsSeparatedByString:@"."];
        int i, count = [components count];
        NSString *key;
        NSRelationshipDescription *relationship;
        
        if (count > 1) {
            count --;
            for (i = 0; i < count; i++) {
                key = [components objectAtIndex:i];
                relationship = [[entity relationshipsByName] objectForKey:key];
                entity = [relationship destinationEntity];
            }
        }        
        attribute = [[entity attributesByName] objectForKey:[components lastObject]];
    }
    
    return attribute;
}

- (int)attributeType {
    NSAttributeDescription *attribute = [self attribute];    
    
    if (attribute != nil)
        return [attribute attributeType];
    
    return NSStringAttributeType;
}

- (NSString *)attributeTypeName {
    NSArray *propertyNames = [self propertyNames];
    NSEnumerator *propertyEnum = [propertyNames objectEnumerator];
    id property;
    
    if (propertyName == nil) 
        return @"";
    
    while (property = [propertyEnum nextObject]) {
        if ([[property valueForKey:@"propertyName"] isEqualToString:propertyName]) {
            return [property valueForKey:@"type"];
        }
    }
    return @"string";
}

- (NSPredicateOperatorType)operatorType {
    return [[predicateRules objectForKey:@"operatorTypes"] indexOfObject:[self operatorName]];
}

- (void)setOperatorType:(NSPredicateOperatorType)type {
    [self setOperatorName:[[predicateRules objectForKey:@"operatorTypes"] objectAtIndex:type]];
}

- (NSArray *)operatorNames {
    NSString *typeName = [self attributeTypeName];
    NSArray *operatorNames = [[predicateRules objectForKey:@"operatorNames"] objectForKey:typeName];
    
    return (operatorNames != nil) ? operatorNames : [NSArray array];
}

- (NSArray *)propertyNames {
    NSString *entityName = [smartGroupEditor entityName];
    NSArray *propertyNames = nil;
    
    if (entityName != nil)
        propertyNames = [[predicateRules objectForKey:@"propertyNames"] objectForKey:entityName];
    
    return (propertyNames != nil) ? propertyNames : [NSArray array];
}

#pragma mark NSEditorRegistration

- (void)objectDidBeginEditing:(id)editor {
	[[self smartGroupEditor] objectDidBeginEditing:editor];
}

- (void)objectDidEndEditing:(id)editor {
	[[self smartGroupEditor] objectDidEndEditing:editor];
}

@end


@implementation NSString (BDSKBoolExtensions) 

- (BOOL)boolValue {
    static NSString *oneString = nil;
    static NSString *yesString = nil;
    static NSString *localizedYesString = nil;
    if (oneString == nil) 
        oneString = [@"1" retain];
    if (yesString == nil) 
        yesString = [@"YES" retain];
    if (localizedYesString == nil) 
        localizedYesString = [NSLocalizedString(@"YES", @"YES") retain];
    
    if ([self isEqualToString:oneString] || [self caseInsensitiveCompare:yesString] || [self caseInsensitiveCompare:localizedYesString])
        return YES;
    return NO;
}

@end


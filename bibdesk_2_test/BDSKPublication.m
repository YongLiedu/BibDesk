//
//  BDSKPublication.m
//  bd2xtest
//
//  Created by Michael McCracken on 7/17/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "BDSKPublication.h"


@implementation BDSKPublication

- (id)initWithEntity:(NSEntityDescription*)entity insertIntoManagedObjectContext:(NSManagedObjectContext*)context{
	if (self = [super initWithEntity:entity insertIntoManagedObjectContext:context]) {
		[self addObserver:self forKeyPath:@"contributorRelationships" options:0 context:NULL];
	}
	return self;
}

- (void)dealloc{
	[self removeObserver:self forKeyPath:@"contributorRelationships"];
	[super dealloc];
}

- (id)valueForUndefinedKey:(NSString *)key {
    NSEnumerator *pairEnum = [[self valueForKey:@"keyValuePairs"] objectEnumerator];
    id pair;
    
    while (pair = [pairEnum nextObject]) {
        if ([[pair valueForKey:@"key"] caseInsensitiveCompare:key] == NSOrderedSame)
            return [pair valueForKey:@"value"];
    }
    return nil;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqual:@"contributorRelationships"]) {
		switch ([[change objectForKey:NSKeyValueChangeKindKey] intValue]) {
			case NSKeyValueChangeSetting:
				// This should be handled when the value is set
				break;
			case NSKeyValueChangeInsertion:
				// this should be handled when the insertion is done
                /*
				do {
					NSSet *relationships = [self valueForKey:@"contributorRelationships"];
					unsigned i = [[[relationships allObjects] valueForKeyPath:@"@distinctUnionOfObjects.index"] count];
					if (i < [relationships count]) {
						NSEnumerator *relationshipE = [relationships objectEnumerator];
						NSManagedObject *relationship;
						NSNumber *number;
						while (relationship = [relationshipE nextObject]) {
							if ([relationship valueForKeyPath:@"index"] == nil) {
								number = [[NSNumber alloc] initWithInt:i++];
								[relationship setValue:number forKey:@"index"];
								[number release];
							}
						}
					}
				} while (0);
				*/
				break;
			case NSKeyValueChangeRemoval:
				do {
					NSMutableArray *relationships = [[[self valueForKey:@"contributorRelationships"] allObjects] mutableCopy];
					NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"index" ascending:YES];
					[relationships sortUsingDescriptors:[NSArray arrayWithObject:sortDescriptor]];
					[sortDescriptor release];
					unsigned i, count = [relationships count];
					NSNumber *number;
					for (i = 0; i < count; i++) {
						number = [[NSNumber alloc] initWithInt:i];
						[[relationships objectAtIndex:i] setValue:number forKey:@"index"];
						[number release];
					}
					[relationships release];
				} while (0);
				break;
			case NSKeyValueChangeReplacement:
				// This should be handled when the items are replaced
				break;
		}
    }
}

@end

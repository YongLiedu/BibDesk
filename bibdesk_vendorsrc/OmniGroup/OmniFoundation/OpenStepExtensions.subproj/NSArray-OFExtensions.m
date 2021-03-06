// Copyright 1997-2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniFoundation/NSArray-OFExtensions.h>

#import <OmniFoundation/OFMultiValueDictionary.h>
#import <OmniFoundation/OFRandom.h>
#import <OmniFoundation/NSString-OFExtensions.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease_2007-10-25/OmniGroup/Frameworks/OmniFoundation/OpenStepExtensions.subproj/NSArray-OFExtensions.m 92224 2007-10-03 00:08:05Z wiml $")

@implementation NSArray (OFExtensions)

- (id)anyObject;
{
    return [self count] > 0 ? [self objectAtIndex:0] : nil;
}

- (NSArray *)elementsAsInstancesOfClass:(Class)aClass withContext:context;
{
    NSMutableArray *array;
    NSAutoreleasePool *pool;
    NSEnumerator *elementEnum;
    NSDictionary *element;

    // keep this out of the pool since we're returning it
    array = [NSMutableArray array];

    pool = [[NSAutoreleasePool alloc] init];
    elementEnum = [self objectEnumerator];
    while ((element = [elementEnum nextObject])) {
	id instance;

	instance = [[aClass alloc] initWithDictionary:element context:context];
	[array addObject:instance];

    }
    [pool release];

    return array;
}

- (id)randomObject;
{
    unsigned int count;

    count = [self count];
    if (!count)
	return nil;
    return [self objectAtIndex:OFRandomNext() % count];
}

- (NSIndexSet *)copyIndexesOfObjectsInSet:(NSSet *)objects;
{
    NSMutableIndexSet *indexes = nil;
    
    unsigned int objectIndex = [self count];
    while (objectIndex--) {
        if ([objects member:[self objectAtIndex:objectIndex]]) {
            if (!indexes)
                indexes = [[NSMutableIndexSet alloc] init];
            [indexes addIndex:objectIndex];
        }
    }
    
    return indexes;
}

- (int)indexOfString:(NSString *)aString;
{
    return [self indexOfString:aString options:0 range:NSMakeRange(0, [aString length])];
}

- (int)indexOfString:(NSString *)aString options:(unsigned)someOptions;
{
    return [self indexOfString:aString options:someOptions range:NSMakeRange(0, [aString length])];
}

- (int)indexOfString:(NSString *)aString options:(unsigned)someOptions range:(NSRange)aRange;
{
    NSObject *anObject;
    Class stringClass;
    unsigned int objectIndex;
    unsigned int objectCount;
    
    stringClass = [NSString class];
    objectCount = [self count];
    for (objectIndex = 0; objectIndex < objectCount; objectIndex++) {
	anObject = [self objectAtIndex:objectIndex];
	if ([anObject isKindOfClass:stringClass] && [aString compare:(NSString *)anObject options:someOptions range:aRange] == NSOrderedSame)
	    return objectIndex;
    }
    
    return NSNotFound;
}

- (NSString *)componentsJoinedByComma;
{
    return [self componentsJoinedByString:@", "];
}

- (NSString *)componentsJoinedByCommaAndAnd;
{
    unsigned int count;
    
    count = [self count];
    if (count == 0)
        return @"";
    else if (count == 1)
        return [self objectAtIndex:0];
    else if (count == 2)
        return [NSString stringWithFormat:@"%@ and %@", [self objectAtIndex:0], [self objectAtIndex:1]];
    else {
        NSArray *headObjects;
        id lastObject;
        
        headObjects = [self subarrayWithRange:NSMakeRange(0, count - 1)];
        lastObject = [self lastObject];
        return [[[headObjects componentsJoinedByComma] stringByAppendingString:@", and "] stringByAppendingString:lastObject];
    }
}

- (unsigned)indexWhereObjectWouldBelong:(id)anObject inArraySortedUsingFunction:(NSComparisonResult (*)(id, id, void *))comparator context:(void *)context;
{
    unsigned int low = 0;
    unsigned int range = 1;
    unsigned int test = 0;
    unsigned int count = [self count];
    NSComparisonResult result;
    id compareWith;
    IMP objectAtIndexImp = [self methodForSelector:@selector(objectAtIndex:)];
    
    while (count >= range) /* range is the lowest power of 2 > count */
        range <<= 1;

    while (range) {
        test = low + (range >>= 1);
        if (test >= count)
            continue;
	compareWith = objectAtIndexImp(self, @selector(objectAtIndex:), test);
	if (compareWith == anObject) 
            return test;
	result = (NSComparisonResult)comparator(anObject, compareWith, context);
	if (result > 0) /* NSOrderedDescending */
            low = test+1;
	else if (result == NSOrderedSame) 
            return test;
    }
    return low;
}

typedef NSComparisonResult (*comparisonMethodIMPType)(id rcvr, SEL _cmd, id other);
struct selectorAndIMP {
    SEL selector;
    comparisonMethodIMPType implementation;
};

static NSComparisonResult compareWithSelectorAndIMP(id obj1, id obj2, void *context)
{
    return (((struct selectorAndIMP *)context) -> implementation)(obj1, (((struct selectorAndIMP *)context) -> selector), obj2);
}

- (unsigned)indexWhereObjectWouldBelong:(id)anObject inArraySortedUsingSelector:(SEL)selector;
{
    struct selectorAndIMP selAndImp;
    
    OBASSERT([anObject respondsToSelector:selector]);
    
    selAndImp.selector = selector;
    selAndImp.implementation = (comparisonMethodIMPType)[anObject methodForSelector:selector];
    
    return [self indexWhereObjectWouldBelong:anObject inArraySortedUsingFunction:compareWithSelectorAndIMP context:&selAndImp];
}

static NSComparisonResult compareWithSortDescriptors(id obj1, id obj2, void *context)
{
    NSArray *sortDescriptors = (NSArray *)context;

    unsigned int sortDescriptorIndex, sortDescriptorCount = [sortDescriptors count];
    for (sortDescriptorIndex = 0; sortDescriptorIndex < sortDescriptorCount; sortDescriptorIndex++) {
	NSSortDescriptor *sortDescriptor = [sortDescriptors objectAtIndex:sortDescriptorIndex];
	NSComparisonResult result = [sortDescriptor compareObject:obj1 toObject:obj2];
	if (result != NSOrderedSame)
	    return result;
    }
    
    return NSOrderedSame;
}

- (unsigned)indexWhereObjectWouldBelong:(id)anObject inArraySortedUsingSortDescriptors:(NSArray *)sortDescriptors;
{
    // optimization: check for count == 1 here and have a different callback for a single descriptor vs. multiple.
    return [self indexWhereObjectWouldBelong:anObject inArraySortedUsingFunction:compareWithSortDescriptors context:sortDescriptors];
}

- (unsigned)indexOfObject:(id)anObject identical:(BOOL)requireIdentity inArraySortedUsingFunction:(NSComparisonResult (*)(id, id, void *))comparator context:(void *)context;
{
    IMP objectAtIndexImp = [self methodForSelector:@selector(objectAtIndex:)];
    int objectIndex = [self indexWhereObjectWouldBelong:anObject inArraySortedUsingFunction:comparator context:context];
    int count = [self count];
    id compareWith;
    
    if (objectIndex == count)
        return NSNotFound;

    if (requireIdentity) {            
        int startingAtIndex = objectIndex;
        do {
            compareWith = objectAtIndexImp(self, @selector(objectAtIndex:), objectIndex);
            if (compareWith == anObject) 
                return objectIndex;
            if ((NSComparisonResult)comparator(anObject, compareWith, context) != NSOrderedSame)
                break;
        } while (objectIndex--);
        
        objectIndex = startingAtIndex;
        while (++objectIndex < count) {
            compareWith = objectAtIndexImp(self, @selector(objectAtIndex:), objectIndex);
            if (compareWith == anObject)
                return objectIndex;
            if ((NSComparisonResult)comparator(anObject, compareWith, context) != NSOrderedSame)
                break;
        }
    } else {
        compareWith = objectAtIndexImp(self, @selector(objectAtIndex:), objectIndex);
        if ((NSComparisonResult)comparator(anObject, compareWith, context) == NSOrderedSame)
            return objectIndex;
    }
    return NSNotFound;
}

static NSComparisonResult compareWithSelector(id obj1, id obj2, void *context)
{
    return (NSComparisonResult)objc_msgSend(obj1, (SEL)context, obj2);
}

- (unsigned)indexOfObject:(id)anObject inArraySortedUsingSelector:(SEL)selector;
{
    struct selectorAndIMP selAndImp;
    
    selAndImp.selector = selector;
    selAndImp.implementation = (comparisonMethodIMPType)[anObject methodForSelector:selector];
    
    return [self indexOfObject:anObject identical:NO inArraySortedUsingFunction:compareWithSelectorAndIMP context:&selAndImp];
}

- (unsigned)indexOfObjectIdenticalTo:(id)anObject inArraySortedUsingSelector:(SEL)selector;
{
    struct selectorAndIMP selAndImp;
    
    selAndImp.selector = selector;
    selAndImp.implementation = (comparisonMethodIMPType)[anObject methodForSelector:selector];
    
    return [self indexOfObject:anObject identical:YES inArraySortedUsingFunction:compareWithSelectorAndIMP context:&selAndImp];
}

- (BOOL)isSortedUsingFunction:(NSComparisonResult (*)(id, id, void *))comparator context:(void *)context;
{
    unsigned int objectIndex, count;

    count = [self count];
    if (count < 2)
        return YES;

    id obj1, obj2;
    obj2 = [self objectAtIndex: 0];
    for (objectIndex = 1; objectIndex < count; objectIndex++) {
        obj1 = obj2;
        obj2 = [self objectAtIndex: objectIndex];
        if (comparator(obj1, obj2, context) > 0)
            return NO;
    }
    return YES;
}

- (BOOL)isSortedUsingSelector:(SEL)selector;
{
    return [self isSortedUsingFunction:compareWithSelector context:selector];
}

- (void)makeObjectsPerformSelector:(SEL)selector withObject:(id)arg1 withObject:(id)arg2;
{
    unsigned int objectIndex, objectCount;
    objectCount = CFArrayGetCount((CFArrayRef)self);
    for (objectIndex = 0; objectIndex < objectCount; objectIndex++) {
        id object = (id)CFArrayGetValueAtIndex((CFArrayRef)self, objectIndex);
        objc_msgSend(object, selector, arg1, arg2);
    }
}

- (void)makeObjectsPerformSelector:(SEL)aSelector withBool:(BOOL)aBool;
{
    unsigned int count = [self count];
    unsigned int objectIndex;

    for (objectIndex = 0; objectIndex < count; objectIndex++) {
        id anObject = [self objectAtIndex:objectIndex];
        objc_msgSend(anObject, aSelector, aBool);
    }
}

- (NSDecimalNumber *)decimalNumberSumForSelector:(SEL)aSelector;
{
    NSDecimalNumber *result;
    int objectIndex;

    result = [NSDecimalNumber zero];
    objectIndex = [self count];

    while (objectIndex--) {
        NSDecimalNumber *value;

        value = objc_msgSend([self objectAtIndex:objectIndex], aSelector);
        if (value)
            result = [result decimalNumberByAdding:value];
    }
    return result;
}

- (NSArray *)numberedArrayDescribedBySelector:(SEL)aSelector;
{
    NSArray *result;
    unsigned int arrayIndex, arrayCount;

    result = [NSArray array];
    for (arrayIndex = 0, arrayCount = [self count]; arrayIndex < arrayCount; arrayIndex++) {
        NSString *valueDescription;
        id value;

        value = [self objectAtIndex:arrayIndex];
        valueDescription = objc_msgSend(value, aSelector);
        result = [result arrayByAddingObject:[NSString stringWithFormat:@"%d. %@", arrayIndex, valueDescription]];
    }

    return result;
}

- (NSArray *)objectsDescribedByIndexesString:(NSString *)indexesString;
{
    NSArray *indexes;
    NSArray *results;
    unsigned int objectIndex, objectCount;

    indexes = [indexesString componentsSeparatedByString:@" "];
    results = [NSArray array];
    for (objectIndex = 0, objectCount = [indexes count]; objectIndex < objectCount; objectIndex++) {
        NSString *indexString;

        indexString = [indexes objectAtIndex:objectIndex];
        results = [results arrayByAddingObject:[self objectAtIndex:[indexString unsignedIntValue]]];
    }

    return results;
}

- (NSArray *)arrayByRemovingObject:(id)anObject;
{
    NSMutableArray *filteredArray;
    
    if (![self containsObject:anObject])
        return [NSArray arrayWithArray:self];

    filteredArray = [NSMutableArray arrayWithArray:self];
    [filteredArray removeObject:anObject];

    return [NSArray arrayWithArray:filteredArray];
}

- (NSArray *)arrayByRemovingObjectIdenticalTo:(id)anObject;
{
    NSMutableArray *filteredArray;
    
    if (![self containsObject:anObject])
        return [NSArray arrayWithArray:self];

    filteredArray = [NSMutableArray arrayWithArray:self];
    [filteredArray removeObjectIdenticalTo:anObject];

    return [NSArray arrayWithArray:filteredArray];
}

- (OFMultiValueDictionary *)groupBySelector:(SEL)aSelector;
{
    int objectIndex, count;
    id currentObject;
    OFMultiValueDictionary *dictionary;

    dictionary = [[[OFMultiValueDictionary alloc] init] autorelease];
    count = [self count];

    for (objectIndex = 0; objectIndex < count; objectIndex++) {
        currentObject = [self objectAtIndex:objectIndex];
        [dictionary addObject:currentObject forKey:[currentObject performSelector:aSelector]];
    }
    return dictionary;
}

- (OFMultiValueDictionary *)groupBySelector:(SEL)aSelector withObject:(id)anObject;
{
    int objectIndex, count;
    id currentObject;
    OFMultiValueDictionary *dictionary;

    dictionary = [[[OFMultiValueDictionary alloc] init] autorelease];
    count = [self count];

    for (objectIndex = 0; objectIndex < count; objectIndex++) {
        currentObject = [self objectAtIndex:objectIndex];
        [dictionary addObject:currentObject forKey:[currentObject performSelector:aSelector withObject:anObject]];
    }
    return dictionary;
}

- (NSDictionary *)indexBySelector:(SEL)aSelector;
{
    return [self indexBySelector:aSelector withObject:nil];
}

- (NSDictionary *)indexBySelector:(SEL)aSelector withObject:(id)argument;
{
    unsigned int objetIndex, objectCount = [self count];
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];

    for (objetIndex = 0; objetIndex < objectCount; objetIndex++) {
        id key, object = [self objectAtIndex:objetIndex];
        if ((key = [object performSelector:aSelector withObject:argument]))
            [dict setObject:object forKey:key];
    }

    NSDictionary *result = [NSDictionary dictionaryWithDictionary:dict];
    [dict release];
    return result;
}

- (NSArray *)arrayByPerformingSelector:(SEL)aSelector;
{
    // objc_msgSend won't bother passing the nil argument to the method implementation because of the selector signature.
    return [self arrayByPerformingSelector:aSelector withObject:nil];
}

- (NSArray *)arrayByPerformingSelector:(SEL)aSelector withObject:(id)anObject;
{
    NSMutableArray *result;
    unsigned int objectIndex, count;

    result = [NSMutableArray array];
    for (objectIndex = 0, count = [self count]; objectIndex < count; objectIndex++) {
        id singleObject;
        id selectorResult;

        singleObject = [self objectAtIndex:objectIndex];
        selectorResult = [singleObject performSelector:aSelector withObject:anObject];

        if (selectorResult)
            [result addObject:selectorResult];
    }

    return result;
}

- (NSSet *)setByPerformingSelector:(SEL)aSelector;
{
    NSMutableSet *result;
    id singleResult;
    unsigned int objectIndex, count;
    
    singleResult = nil;
    result = nil;
    for (objectIndex = 0, count = [self count]; objectIndex < count; objectIndex++) {
        id singleObject;
        id selectorResult;
        
        singleObject = [self objectAtIndex:objectIndex];
        selectorResult = [singleObject performSelector:aSelector /* withObject:anObject */ ];
        
        if (selectorResult) {
            if (singleResult == selectorResult) {
                /* ok */
            } else if (result != nil) {
                [result addObject:selectorResult];
            } else if (singleResult == nil) {
                singleResult = selectorResult;
            } else {
                result = [NSMutableSet set];
                [result addObject:singleResult];
                [result addObject:selectorResult];
                singleResult = nil;
            }
        }
    }
    
    if (result)
        return result;
    else if (singleResult)
        return [NSSet setWithObject:singleResult];
    else
        return [NSSet set];
}

- (NSArray *)objectsSatisfyingCondition:(SEL)aSelector;
{
    // objc_msgSend won't bother passing the nil argument to the method implementation because of the selector signature.
    return [self objectsSatisfyingCondition:aSelector withObject:nil];
}

- (NSArray *)objectsSatisfyingCondition:(SEL)aSelector withObject:(id)anObject;
{
    NSMutableArray *result = [NSMutableArray array];
    unsigned int objectIndex, objectCount = [self count];
    
    for (objectIndex = 0; objectIndex < objectCount; objectIndex++) {
        id singleObject = [self objectAtIndex:objectIndex];
        if ([singleObject satisfiesCondition:aSelector withObject:anObject])
            [result addObject:singleObject];
    }

    return result;
}

- (BOOL)anyObjectSatisfiesCondition:(SEL)sel;
{
    return [self anyObjectSatisfiesCondition:sel withObject:nil];
}

- (BOOL)anyObjectSatisfiesCondition:(SEL)sel withObject:(id)anObject;
{
    unsigned int objectIndex = [self count];
    while (objectIndex--) {
        NSObject *object = [self objectAtIndex:objectIndex];
        if ([object satisfiesCondition:sel withObject:anObject])
            return YES;
    }
    
    return NO;
}

- (NSMutableArray *)deepMutableCopy;
{
    NSMutableArray *newArray;
    unsigned int objectIndex, count;

    count = [self count];
    newArray = [[NSMutableArray allocWithZone:[self zone]] initWithCapacity:count];
    for (objectIndex = 0; objectIndex < count; objectIndex++) {
        id anObject;

        anObject = [self objectAtIndex:objectIndex];
        if ([anObject respondsToSelector:@selector(deepMutableCopy)]) {
            anObject = [anObject deepMutableCopy];
            [newArray addObject:anObject];
            [anObject release];
        } else if ([anObject respondsToSelector:@selector(mutableCopy)]) {
            anObject = [anObject mutableCopy];
            [newArray addObject:anObject];
            [anObject release];
        } else {
            [newArray addObject:anObject];
        }
    }

    return newArray;
}

- (NSArray *)reversedArray;
{
    NSMutableArray *newArray;
    unsigned int count;
    
    count = [self count];
    newArray = [[[NSMutableArray allocWithZone:[self zone]] initWithCapacity:count] autorelease];
    while (count--) {
        [newArray addObject:[self objectAtIndex:count]];
    }

    return newArray;
}

- (NSArray *)deepCopyWithReplacementFunction:(id (*)(id, void *))funct context:(void *)context;
{
    id *replacementItems = NULL;
    int itemCount, itemIndex;
    
    itemCount = [self count];
    for(itemIndex = 0; itemIndex < itemCount; itemIndex ++) {
        id item, copyItem;
        
        item = [self objectAtIndex:itemIndex];
        copyItem = (*funct)(item, context);
        if (!copyItem) {
            if ([item respondsToSelector:_cmd])
                copyItem = [item deepCopyWithReplacementFunction:funct context:context];
            else
                copyItem = [[item copy] autorelease];
        }
        if(copyItem != item && replacementItems == NULL) {
            replacementItems = NSZoneMalloc(NULL, sizeof(*replacementItems) * itemCount);
            if (itemIndex > 0)
                [self getObjects:replacementItems range:(NSRange){location:0, length:itemIndex}];
        }
        if (replacementItems != NULL)
            replacementItems[itemIndex] = copyItem;
    }
    
    if (replacementItems == NULL) {
        // TODO: If we're immutable, just return ourselves
        return [NSArray arrayWithArray:self];
    } else {
        NSArray *theCopy = [NSArray arrayWithObjects:replacementItems count:itemCount];
        NSZoneFree(NULL, replacementItems);
        return theCopy;
    }
}

// Returns YES if the two arrays contain exactly the same pointers in the same order.  That is, this doesn't use -isEqual: on the components
- (BOOL)isIdenticalToArray:(NSArray *)otherArray;
{
    unsigned int objectIndex = [self count];

    if (objectIndex != [otherArray count])
        return NO;
    while (objectIndex--)
        if ([self objectAtIndex:objectIndex] != [otherArray objectAtIndex:objectIndex])
            return NO;
    return YES;
}

// -containsObjectsInOrder: moved from TPTrending 6Dec2001 wiml
- (BOOL)containsObjectsInOrder:(NSArray *)orderedObjects
{
    unsigned myCount, objCount, myIndex, objIndex;
    id testItem = nil;
    
    myCount = [self count];
    objCount = [orderedObjects count];
    
    myIndex = objIndex = 0;
    while (objIndex < objCount) {
        id item;
        
        // Not enough objects left in self to correspond to objects left in orderedObjects
        if ((objCount - objIndex) > (myCount - myIndex))
            return NO;
        
        item = [self objectAtIndex:myIndex];
        if (!testItem)
            testItem = [orderedObjects objectAtIndex:objIndex];
        if (item == testItem) {
            testItem = nil;
            objIndex ++;
        }
        myIndex ++;
    }
    
    return YES;
}

- (BOOL)containsObjectIdenticalTo:anObject;
{
    return [self indexOfObjectIdenticalTo:anObject] != NSNotFound;
}

- (unsigned)indexOfFirstObjectWithValueForKey:(NSString *)key equalTo:(id)searchValue;
{
    unsigned int objectIndex, objectCount = [self count];
    
    for (objectIndex = 0; objectIndex < objectCount; objectIndex++) {
        id object = [self objectAtIndex:objectIndex];
        id objectValue = [object valueForKey:key];
        if (OFISEQUAL(objectValue, searchValue))
            return objectIndex;
    }
    
    return NSNotFound;
}

- (id)firstObjectWithValueForKey:(NSString *)key equalTo:(id)searchValue;
{
    unsigned int objectIndex = [self indexOfFirstObjectWithValueForKey:key equalTo:searchValue];
    return (objectIndex == NSNotFound) ? nil : [self objectAtIndex:objectIndex];
}

@end

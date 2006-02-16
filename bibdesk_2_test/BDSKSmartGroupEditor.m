//
//  BDSKSmartGroupEditor.m
//  bd2
//
//  Created by Christiaan Hofman on 2/15/06.
//  Copyright 2006. All rights reserved.
//

#import "BDSKSmartGroupEditor.h"
#import "BDSKDataModelNames.h"


@implementation BDSKSmartGroupEditor

- (id)init {
    if (self = [super initWithWindowNibName:[self windowNibName]]) {
        managedObjectContext = nil;
        entityName = nil;
        conjunction = 0;
        controllers = [[NSMutableArray alloc] init];
        editors = CFArrayCreateMutable(kCFAllocatorMallocZone, 0, NULL);
    }
    return self;
}

- (void)dealloc {
    [self reset];
    CFRelease(editors), editors = nil;
    [controllers release], controllers = nil;
    [entityName release], entityName = nil;
    [managedObjectContext release], managedObjectContext = nil;
    [super dealloc];
}

- (NSString *)windowNibName {
    return @"BDSKSmartGroupEditor";
}

- (void)reset {
    [mainView removeAllSubviews];
    
    [controllers makeObjectsPerformSelector:@selector(cleanup)];
    
    [self willChangeValueForKey:@"isCompound"];
    [controllers removeAllObjects];
    [self didChangeValueForKey:@"isCompound"];
}

#pragma mark Actions

- (IBAction)add:(id)sender {
    BDSKComparisonPredicateController *controller = [[BDSKComparisonPredicateController alloc] initWithEditor:self];
    NSView *view = [controller view];
    
    if (view) {
        [mainView addView:view];
        
        [self willChangeValueForKey:@"isCompound"];
		[controllers addObject:controller]; 
        [self didChangeValueForKey:@"isCompound"];
    }
    [controller release];
}

- (IBAction)remove:(BDSKComparisonPredicateController *)controller {
    int index = [controllers indexOfObjectIdenticalTo:controller];
    
    if (index != NSNotFound) {  
        [mainView removeView:[controller view]];
        
        [self willChangeValueForKey:@"isCompound"];
        [controllers removeObjectAtIndex:index];
        [self didChangeValueForKey:@"isCompound"];
    }
}

- (IBAction)closeEditor:(id)sender {
    if ([[self window] isSheet]) {
		[[self window] orderOut:sender];
		[NSApp endSheet:[self window] returnCode:[sender tag]];
	} else {
        // how do we notify the caller?
		[[self window] performClose:sender];
	}
}

#pragma mark Accessors

- (NSManagedObjectContext *)managedObjectContext {
    return managedObjectContext;
}

- (void)setManagedObjectContext:(NSManagedObjectContext *)context {
    if (context != managedObjectContext) {
        [managedObjectContext release];
        managedObjectContext = [context retain];
    }
}

- (NSString *)entityName {
	return entityName;
}

- (void)setEntityName:(NSString *)newEntityName {
	if ([newEntityName isEqualToString:entityName] == NO) {
        [entityName release]; 
        entityName = [newEntityName retain];
        [self reset];
    }
}

- (int)conjunction {
    return conjunction;
}

- (void)setConjunction:(int)value {
    conjunction = value;
}

- (NSPredicate *)predicate {
    int count = [controllers count];
    
    if (count == 0)
        return [NSPredicate predicateWithValue:YES];
    else if (count == 1)
        return [[controllers lastObject] predicate];
    
    NSMutableArray *subpredicates = [[NSMutableArray alloc] initWithCapacity:count];
    NSPredicate *predicate;
    int i;
    
    for (i = 0; i < count; i++) {
        id controller = [controller objectAtIndex:i];
        [subpredicates addObject:[controller predicate]];
    }
    
    if ([self conjunction] == 1)
        predicate = [NSCompoundPredicate orPredicateWithSubpredicates:subpredicates];
    else
        predicate = [NSCompoundPredicate andPredicateWithSubpredicates:subpredicates];
    
    [subpredicates release];
    
    return predicate;
}

- (void)setPredicate:(NSPredicate *)newPredicate {
	NSArray *subpredicates;
    
    [self setConjunction:0];

	// The predicate may be nil, compound or comparison
	if (newPredicate == nil || [newPredicate isEqualTo:[NSPredicate predicateWithValue:YES]] || [newPredicate isEqualTo:[NSPredicate predicateWithValue:NO]]) {
		subpredicates = [NSArray array];
	} else if ([newPredicate isKindOfClass:[NSCompoundPredicate self]]) {
		subpredicates = [(NSCompoundPredicate *)newPredicate subpredicates];
        if ([(NSCompoundPredicate *)newPredicate compoundPredicateType] == NSOrPredicateType)
            [self setConjunction:1];
	} else {
	    subpredicates = [NSArray arrayWithObject:newPredicate];
	}

    NSEnumerator *predicateEnum = [subpredicates objectEnumerator];
	NSPredicate *predicate;
    
    if ([controllers count] > 0)
        [self reset];
	while (predicate = [predicateEnum nextObject]) {
        [self add:nil];
        [[controllers lastObject] setPredicate:predicate];
    }    
}

- (NSArray *)entityNames {
    return [NSArray arrayWithObjects:PublicationEntityName, PersonEntityName, InstitutionEntityName, VenueEntityName, NoteEntityName, TagEntityName, nil];
}

- (BOOL)isCompound {
    return ([controllers count] > 1);
}

#pragma mark NSEditorRegistration

- (void)objectDidBeginEditing:(id)editor {
    if (CFArrayGetFirstIndexOfValue(editors, CFRangeMake(0, CFArrayGetCount(editors)), editor) == -1) {
		CFArrayAppendValue((CFMutableArrayRef)editors, editor);		
    }
}

- (void)objectDidEndEditing:(id)editor {
    CFIndex index = CFArrayGetFirstIndexOfValue(editors, CFRangeMake(0, CFArrayGetCount(editors)), editor);
    if (index != -1) {
		CFArrayRemoveValueAtIndex((CFMutableArrayRef)editors, index);		
    }
}

- (BOOL)commitEditing {
    CFIndex i, index, count = CFArrayGetCount(editors);
    NSObject *editor;
    
	for (i = 0; i < count; i++) {
		index = count - i - 1;
		editor = (NSObject *)(CFArrayGetValueAtIndex(editors, index));
		if (![editor commitEditing]) 
			return NO;
	}
    
    // ensure the predicate is valid
    @try { [self predicate]; }
    
    @catch ( NSException *e ) {  
        // present an alert about the problem
        NSAlert *alert = [[[NSAlert alloc] init] autorelease];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Invalid Conditions"];
        [alert setInformativeText: [NSString stringWithFormat: @"The conditions you have specified for the SmartGroup are invalid:  please examine the values entered to ensure they have the proper formatting.\n\n(Error: %@)", [e description]]];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert runModal];

        return NO;  
    }
    
    return YES;
}

@end


#define SEPARATION 0.0l

@implementation BDSKPredicateView

// this makes it easier to place the subviews
- (BOOL)isFlipped {
    return YES;
}

- (NSSize)minimumSize { 
    NSArray *subviews = [self subviews];
    float height = ([subviews count] > 0) ? NSMaxY([[subviews lastObject] frame]) : 32.0f;
    return NSMakeSize(NSWidth([self frame]), height);
}

- (void)setFrameSize:(NSSize)newSize {
    if (newSize.height >= [self minimumSize].height) {        
        [super setFrameSize:newSize];
    }
}

- (void)updateSize {
    float oldHeight = NSHeight([self frame]);
    
    [self setFrameSize:[self minimumSize]];
    
    float dh = NSHeight([self frame]) - oldHeight;
    if (dh != 0.0f) {
        NSRect winFrame = [[self window] frame];
        winFrame.size.height += dh;
        winFrame.origin.y -= dh;
        [[self window] setFrame:winFrame display:YES animate:YES];
    }
}

- (void)addView:(NSView *)view {
    NSArray *subviews = [self subviews];
    
    NSView *lastView = [subviews lastObject]; // use the lastView to compute location of next view
    
    [self addSubview:view];
    if (lastView != nil) {
        float yPosition = NSMaxY([lastView frame]) + SEPARATION;
        [view setFrameOrigin:NSMakePoint(0.0l, yPosition)];
    }
    
    NSSize size = [view frame].size;
    [view setFrameSize:NSMakeSize(NSWidth([self frame]), size.height)];
    
    [self updateSize];
    [self setNeedsDisplay:YES];
}

- (void)removeView:(NSView *)view {
    NSArray *subviews = [[[self subviews] copy] autorelease];
    int index = [subviews indexOfObjectIdenticalTo:view];
    
    if (index != NSNotFound) {
        NSView *view = [subviews objectAtIndex:index];
        NSPoint newPoint = [view frame].origin;
        float dy = NSHeight([view frame]) + SEPARATION;
        
        [view removeFromSuperview];
        
        int count = [subviews count];
        
        for (index++; index < count; index++) {
            view = [subviews objectAtIndex:index];
            [view setFrameOrigin:newPoint];
            newPoint.y += dy;
        }
        
        [self updateSize];
    }
    [self setNeedsDisplay:YES];
}

- (void)removeAllSubviews {
    NSArray *subviews = [[[self subviews] copy] autorelease];
    NSEnumerator *viewEnum = [subviews objectEnumerator];
    NSView *view;
    
    while (view = [viewEnum nextObject]) {
        [view removeFromSuperviewWithoutNeedingDisplay];
    }
    [self updateSize];
    [self setNeedsDisplay:YES];
}

@end

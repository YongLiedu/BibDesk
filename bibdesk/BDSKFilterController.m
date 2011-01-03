//
//  BDSKFilterController.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 17/3/05.
/*
 This software is Copyright (c) 2005-2011
 Christiaan Hofman. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Christiaan Hofman nor the names of any
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

#import "BDSKFilterController.h"
#import "BDSKConditionController.h"
#import "BDSKConditionsView.h"
#import "NSWindowController_BDSKExtensions.h"


@implementation BDSKFilterController

- (id)init
{
	BDSKFilter *aFilter = [[BDSKFilter alloc] init];
	self = [self initWithFilter:aFilter];
	[aFilter release];
	return self;
}

- (id)initWithFilter:(BDSKFilter *)aFilter
{
    self = [super init];
    if (self) {
		filter = [aFilter retain];
		conditionControllers = [[NSMutableArray alloc] initWithCapacity:[[filter conditions] count]];
		conjunction = [filter conjunction];
        undoManager = nil;
    }
    return self;
}

- (void)dealloc
{
	//NSLog(@"dealloc filterController");
    BDSKDESTROY(filter);
    BDSKDESTROY(conditionControllers);
    BDSKDESTROY(undoManager);
    [super dealloc];
}

- (NSString *)windowNibName {
	return @"BDSKFilter";
}

- (void)awakeFromNib {
	BDSKConditionController *controller = nil;
    BOOL canRemove = ([[filter conditions] count] > 1);
	
	[conditionControllers removeAllObjects];
    if ([[filter conditions] count]) {
        for (BDSKCondition *condition in [filter conditions]) {
            controller = [[BDSKConditionController alloc] initWithFilterController:self condition:[[condition copy] autorelease]];
            [controller setCanRemove:canRemove];
            [conditionControllers addObject:[controller autorelease]];
            [conditionsView addView:[controller view]];
        }
	} else {
        // add a dummy controller when there's no condition, so we have an add button
        controller = [[BDSKConditionController alloc] initWithFilterController:self condition:nil];
        [controller setCanRemove:NO];
        [conditionControllers addObject:[controller autorelease]];
        [conditionsView addView:[controller view]];
    }
    
	[self updateUI];
}

- (void)updateUI {
	if ([conditionControllers count] < 2) {
		[messageStartTextField setStringValue:NSLocalizedString(@"Match the following condition:", @"Label for smart group editor")];
		[conjunctionPopUp setHidden:YES];
		[messageEndTextField setHidden:YES];
	} else {
		[messageStartTextField setStringValue:NSLocalizedString(@"Match", @"Beginning of label for smart group editor")];
		[conjunctionPopUp setHidden:NO];
		[messageEndTextField setHidden:NO];
        [[messageStartTextField superview] setNeedsDisplayInRect:[messageStartTextField frame]];
	}
	[messageStartTextField sizeToFit];
}

- (IBAction)dismiss:(id)sender {
    if ([sender tag] == NSOKButton && [self commitEditing]) {
        
        NSMutableArray *conditions = [NSMutableArray arrayWithCapacity:[conditionControllers count]];
        
        for (BDSKConditionController *controller in conditionControllers)
            [conditions addObject:[controller condition]];
        // remove the dummy condition
        [conditions removeObject:[NSNull null]];
        [filter setConditions:conditions];
        [filter setConjunction:[self conjunction]];
        
        [[filter undoManager] setActionName:NSLocalizedString(@"Edit Smart Group", @"Undo action name")];
	}
    
    [super dismiss:sender];
}

- (BDSKFilter *)filter {
	return [[filter retain] autorelease];
}

- (void)insertNewConditionAfter:(BDSKConditionController *)aConditionController {
	// remove this one if it's a dummy controller
    if ([aConditionController condition] == nil)
        [self removeConditionController:[[aConditionController retain] autorelease]];
	
    NSUInteger idx = [conditionControllers indexOfObject:aConditionController];
	if (idx == NSNotFound) 
		idx = [conditionControllers count];
    else
        ++idx;
    BDSKConditionController *newController = [[[BDSKConditionController alloc] initWithFilterController:self] autorelease];
    [self insertConditionController:newController atIndex:idx];
}

- (void)insertConditionController:(BDSKConditionController *)newController atIndex:(NSUInteger)idx {
    [[[self undoManager] prepareWithInvocationTarget:self] removeConditionControllerAtIndex:idx];
	
    NSUInteger count = [conditionControllers count];
    [conditionControllers insertObject:newController atIndex:idx];
    [conditionsView insertView:[newController view] atIndex:idx];
    [newController setCanRemove:(count > 0)];
	if (count == 1) {
        [[conditionControllers objectAtIndex:0] setCanRemove:YES];
        [self updateUI];
    }
    [conditionsView scrollRectToVisible:[[newController view] frame]];
    [newController selectKeyText:self];
}

- (void)removeConditionController:(BDSKConditionController *)aConditionController {
	NSUInteger idx = [conditionControllers indexOfObject:aConditionController];
    [self removeConditionControllerAtIndex:idx];
}

- (void)removeConditionControllerAtIndex:(NSUInteger)idx {
    BDSKConditionController *aConditionController = [conditionControllers objectAtIndex:idx];
    
    [[[self undoManager] prepareWithInvocationTarget:self] insertConditionController:aConditionController atIndex:idx];
    
    [conditionsView removeView:[aConditionController view]];
	[conditionControllers removeObject:aConditionController]; 
	if ([conditionControllers count] == 1) {
        [[conditionControllers objectAtIndex:0] setCanRemove:NO];
        [self updateUI];
    }
}

- (BOOL)canRemoveCondition {
	return ([conditionControllers count] > 1);
}

- (NSArray *)conditionControllers {
    return [[conditionControllers copy] autorelease];
}

- (BDSKConjunction)conjunction {
    return conjunction;
}

- (void)setConjunction:(BDSKConjunction)newConjunction {
    [[[self undoManager] prepareWithInvocationTarget:self] setConjunction:conjunction];
	conjunction = newConjunction;
}

#pragma mark NSEditor

- (void)discardEditing {
	[conditionControllers makeObjectsPerformSelector:@selector(discardEditing)];
}

- (BOOL)commitEditing {
	for (BDSKConditionController *controller in conditionControllers) {
        if (NO == [controller commitEditing])
            return NO;
    }
    return YES;
}

- (void)commitEditingWithDelegate:(id)delegate didCommitSelector:(SEL)didCommitSelector contextInfo:(void *)contextInfo {
    BOOL didCommit = [self commitEditing];
    if (delegate && didCommitSelector) {
        // - (void)editor:(id)editor didCommit:(BOOL)didCommit contextInfo:(void *)contextInfo
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[delegate methodSignatureForSelector:didCommitSelector]];
        [invocation setTarget:delegate];
        [invocation setSelector:didCommitSelector];
        [invocation setArgument:&self atIndex:2];
        [invocation setArgument:&didCommit atIndex:3];
        [invocation setArgument:&contextInfo atIndex:4];
        [invocation invoke];
    }
}

#pragma mark Undo support

- (NSUndoManager *)undoManager{
    if(undoManager == nil)
        undoManager = [[NSUndoManager alloc] init];
    return undoManager;
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)sender{
    return [self undoManager];
}

@end

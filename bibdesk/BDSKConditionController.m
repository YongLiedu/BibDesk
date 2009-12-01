//
//  BDSKConditionController.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 17/3/05.
/*
 This software is Copyright (c) 2005-2009
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

#import "BDSKConditionController.h"
#import "BDSKFilterController.h"
#import "BibItem.h"
#import "BDSKBooleanValueTransformer.h"
#import "BDSKRatingButton.h"

static char BDSKConditionControllerObservationContext;

@interface BDSKConditionController (BDSKPrivate)
- (void)startObserving;
- (void)stopObserving;
- (void)layoutValueControls;
- (void)layoutComparisonControls;
@end

@implementation BDSKConditionController

+ (void)initialize
{
    BDSKINITIALIZE;
    [NSValueTransformer setValueTransformer:[[[BDSKBooleanValueTransformer alloc] init] autorelease] forName:@"BDSKBooleanValueTransformer"];
    [NSValueTransformer setValueTransformer:[[[BDSKTriStateValueTransformer alloc] init] autorelease] forName:@"BDSKTriStateValueTransformer"];
}

- (id)initWithFilterController:(BDSKFilterController *)aFilterController
{
	BDSKCondition *aCondition = [[[BDSKCondition alloc] init] autorelease];
    self = [self initWithFilterController:aFilterController condition:aCondition];
    return self;
}

- (id)initWithFilterController:(BDSKFilterController *)aFilterController condition:(BDSKCondition *)aCondition
{
    self = [super init];
    if (self) {
        filterController = aFilterController;
        condition = [aCondition retain];
		canRemove = [filterController canRemoveCondition];
		
        BDSKTypeManager *typeMan = [BDSKTypeManager sharedManager];
        keys = [[typeMan allFieldNamesIncluding:[NSArray arrayWithObjects:BDSKDateAddedString, BDSKDateModifiedString, BDSKAllFieldsString, BDSKPubTypeString, BDSKAbstractString, BDSKAnnoteString, BDSKRssDescriptionString, BDSKLocalFileString, BDSKRemoteURLString, nil]
                                      excluding:nil] mutableCopy];
    }
    return self;
}

- (void)dealloc
{
	//NSLog(@"dealloc conditionController");
    [self stopObserving];
    filterController = nil;
	BDSKDESTROY(condition);
    BDSKDESTROY(keys);
    BDSKDESTROY(view);
    [[dateComparisonPopUp superview] release];
    [[attachmentComparisonPopUp superview] release];
    [[comparisonPopUp superview] release];
    [[valueTextField superview] release];
    [[countTextField superview] release];
    [[numberTextField superview] release];
    [[andNumberTextField superview] release];
    [[periodPopUp superview] release];
    [[agoText superview] release];
    [[dateTextField superview] release];
    [[toDateTextField superview] release];
    [[booleanButton superview] release];
    [[triStateButton superview] release];
    [[ratingButton superview] release];
    [super dealloc];
}

- (NSString *)windowNibName {
    return @"BDSKCondition";
}

- (void)awakeFromNib {
    // we add/remove these controls, so we need to retain them
    [view retain];
    [[dateComparisonPopUp superview] retain];
    [[attachmentComparisonPopUp superview] retain];
    [[comparisonPopUp superview] retain];
    [[valueTextField superview] retain];
    [[countTextField superview] retain];
    [[numberTextField superview] retain];
    [[andNumberTextField superview] retain];
    [[periodPopUp superview] retain];
    [[agoText superview] retain];
    [[dateTextField superview] retain];
    [[toDateTextField superview] retain];
    [[booleanButton superview] retain];
    [[triStateButton superview] retain];
    [[ratingButton superview] retain];
    
    [ratingButton setRating:[[condition stringValue] integerValue]];
    
    NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
    [formatter setDateStyle:NSDateFormatterShortStyle];
    [formatter setTimeStyle:NSDateFormatterNoStyle];
    [dateTextField setFormatter:formatter];
    [toDateTextField setFormatter:formatter];
	
    BDSKFieldNameFormatter *fieldFormatter = [[[BDSKFieldNameFormatter alloc] init] autorelease];
	[keyComboBox setFormatter:fieldFormatter];
	[fieldFormatter setDelegate:self];
    
    [self layoutComparisonControls];
    [self layoutValueControls];
    
    if (condition == nil) {
        // hide everything except for the Add button when this is a dummy condition controller
        [keyComboBox setHidden:YES];
        [comparisonBox setHidden:YES];
        [valueBox setHidden:YES];
        [removeButton setHidden:YES];
    } else {
        [self startObserving];
    }
}

- (NSArray *)fieldNameFormatterKnownFieldNames:(BDSKFieldNameFormatter *)formatter {
    if (formatter == [keyComboBox formatter])
        return keys;
    else
        return nil;
}

- (NSView *)view {
    [self window]; // this makes sure the nib is loaded
	return view;
}

- (IBAction)addNewCondition:(id)sender {
	[filterController insertNewConditionAfter:self];
}

- (IBAction)removeThisCondition:(id)sender {
	if ([self canRemove]) {
        [self stopObserving];
        [filterController removeConditionController:self];
    }
}

- (IBAction)selectKeyText:(id)sender {
    [keyComboBox selectText:sender];
}

// we could implement binding in BDSKRatingButton, but that's a lot of hassle and exposes us to the binding-to-owner bug
- (IBAction)changeRating:(id)sender {
    [condition setStringValue:[NSString stringWithFormat:@"%ld", (long)[sender rating]]];
}

- (BDSKCondition *)condition {
    return [[condition retain] autorelease];
}

- (BOOL)canRemove {
	return canRemove;
}

- (void)setCanRemove:(BOOL)flag {
	canRemove = flag;
}

- (NSArray *)keys {
    return [[keys copy] autorelease];
}

- (void)setKeys:(NSArray *)newKeys {
    if (keys != newKeys) {
        [keys release];
        keys = [newKeys mutableCopy];
    }
}

- (void)layoutValueControls {
    NSArray *controls = nil;
    switch ([[condition key] fieldType]) {
        case BDSKDateField:
            switch ([condition dateComparison]) {
                case BDSKExactly: 
                    controls = [NSArray arrayWithObjects:numberTextField, periodPopUp, agoText, nil];
                    break;
                case BDSKInLast: 
                case BDSKNotInLast: 
                    controls = [NSArray arrayWithObjects:numberTextField, periodPopUp, nil];
                    break;
                case BDSKBetween: 
                    controls = [NSArray arrayWithObjects:numberTextField, andNumberTextField, periodPopUp, agoText, nil];
                    break;
                case BDSKDate: 
                case BDSKAfterDate: 
                case BDSKBeforeDate: 
                    controls = [NSArray arrayWithObjects:dateTextField, nil];
                    break;
                case BDSKInDateRange:
                    controls = [NSArray arrayWithObjects:dateTextField, toDateTextField, nil];
                    break;
                default:
                    break;
            }
        break;
        case BDSKLinkedField:
            switch ([condition attachmentComparison]) {
                case BDSKCountEqual: 
                case BDSKCountNotEqual: 
                case BDSKCountLarger: 
                case BDSKCountSmaller: 
                    controls = [NSArray arrayWithObjects:countTextField, nil];
                    break;
                case BDSKAttachmentContain: 
                case BDSKAttachmentNotContain: 
                case BDSKAttachmentStartWith: 
                case BDSKAttachmentEndWith: 
                    controls = [NSArray arrayWithObjects:valueTextField, nil];
                    break;
                default:
                    break;
            }
        break;
        case BDSKBooleanField:
            controls = [NSArray arrayWithObjects:booleanButton, nil];
        break;
        case BDSKTriStateField:
            controls = [NSArray arrayWithObjects:triStateButton, nil];
        break;
        case BDSKRatingField:
            controls = [NSArray arrayWithObjects:ratingButton, nil];
        break;
        default:
            controls = [NSArray arrayWithObjects:valueTextField, nil];
    }
    
    NSRect rect = NSZeroRect;
    NSArray *views = [[[valueBox contentView] subviews] copy];
    [views makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [views release];
    
    for (NSView *aView in controls) {
        aView = [aView superview];
        rect.size = [aView frame].size;
        [aView setFrameOrigin:rect.origin];
        [valueBox addSubview:aView];
        rect.origin.x += NSWidth(rect);
    }
}

- (void)layoutComparisonControls {
    [[[[comparisonBox contentView] subviews] lastObject] removeFromSuperview];
    if ([condition isDateCondition]) {
        [[dateComparisonPopUp superview] setFrameOrigin:NSZeroPoint];
        [comparisonBox addSubview:[dateComparisonPopUp superview]];
    } else if ([condition isAttachmentCondition]) {
        [[attachmentComparisonPopUp superview] setFrameOrigin:NSZeroPoint];
        [comparisonBox addSubview:[attachmentComparisonPopUp superview]];
    } else {
        [[comparisonPopUp superview] setFrameOrigin:NSZeroPoint];
        [comparisonBox addSubview:[comparisonPopUp superview]];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &BDSKConditionControllerObservationContext) {
        BDSKASSERT(object == condition);
        if(object == condition) {
            NSUndoManager *undoManager = [filterController undoManager];
            id oldValue = [change objectForKey:NSKeyValueChangeOldKey];
            if (oldValue == [NSNull null])
                oldValue = nil;
            if ([keyPath isEqualToString:@"key"]){
                NSString *newValue = [change objectForKey:NSKeyValueChangeNewKey];
                NSInteger oldFieldType = [oldValue fieldType];
                NSInteger newFieldType = [newValue fieldType];
                if(MIN(oldFieldType, BDSKStringField) != MIN(newFieldType, BDSKStringField))
                    [self layoutComparisonControls];
                if(oldFieldType != newFieldType)
                    [self layoutValueControls];
                [[undoManager prepareWithInvocationTarget:condition] setKey:oldValue];
            } else if ([keyPath isEqualToString:@"dateComparison"]) {
                [self layoutValueControls];
                [[undoManager prepareWithInvocationTarget:condition] setDateComparison:[oldValue integerValue]];
            } else if ([keyPath isEqualToString:@"attachmentComparison"]) {
                [self layoutValueControls];
                [[undoManager prepareWithInvocationTarget:condition] setAttachmentComparison:[oldValue integerValue]];
            } else if ([keyPath isEqualToString:@"stringComparison"]) {
                [[undoManager prepareWithInvocationTarget:condition] setStringComparison:[oldValue integerValue]];
            } else if ([keyPath isEqualToString:@"stringValue"]) {
                [[undoManager prepareWithInvocationTarget:condition] setStringValue:oldValue];
                [ratingButton setRating:[[condition stringValue] integerValue]];
            } else if ([keyPath isEqualToString:@"countValue"]) {
                [[undoManager prepareWithInvocationTarget:condition] setCountValue:[oldValue integerValue]];
            } else if ([keyPath isEqualToString:@"numberValue"]) {
                [[undoManager prepareWithInvocationTarget:condition] setNumberValue:[oldValue integerValue]];
            } else if ([keyPath isEqualToString:@"andNumberValue"]) {
                [[undoManager prepareWithInvocationTarget:condition] setAndNumberValue:[oldValue integerValue]];
            } else if ([keyPath isEqualToString:@"periodValue"]) {
                [[undoManager prepareWithInvocationTarget:condition] setPeriodValue:[oldValue integerValue]];
            } else if ([keyPath isEqualToString:@"dateValue"]) {
                [[undoManager prepareWithInvocationTarget:condition] setDateValue:oldValue];
            } else if ([keyPath isEqualToString:@"toDateValue"]) {
                [[undoManager prepareWithInvocationTarget:condition] setToDateValue:oldValue];
            }
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)startObserving {
    [condition addObserver:self forKeyPath:@"key" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld  context:&BDSKConditionControllerObservationContext];
    [condition addObserver:self forKeyPath:@"dateComparison" options: NSKeyValueObservingOptionOld  context:&BDSKConditionControllerObservationContext];
    [condition addObserver:self forKeyPath:@"attachmentComparison" options:NSKeyValueObservingOptionOld  context:&BDSKConditionControllerObservationContext];
    [condition addObserver:self forKeyPath:@"stringComparison" options:NSKeyValueObservingOptionOld  context:&BDSKConditionControllerObservationContext];
    [condition addObserver:self forKeyPath:@"stringValue" options:NSKeyValueObservingOptionOld  context:&BDSKConditionControllerObservationContext];
    [condition addObserver:self forKeyPath:@"countValue" options:NSKeyValueObservingOptionOld  context:&BDSKConditionControllerObservationContext];
    [condition addObserver:self forKeyPath:@"numberValue" options:NSKeyValueObservingOptionOld  context:&BDSKConditionControllerObservationContext];
    [condition addObserver:self forKeyPath:@"andNumberValue" options:NSKeyValueObservingOptionOld  context:&BDSKConditionControllerObservationContext];
    [condition addObserver:self forKeyPath:@"periodValue" options:NSKeyValueObservingOptionOld  context:&BDSKConditionControllerObservationContext];
    [condition addObserver:self forKeyPath:@"dateValue" options:NSKeyValueObservingOptionOld  context:&BDSKConditionControllerObservationContext];
    [condition addObserver:self forKeyPath:@"toDateValue" options:NSKeyValueObservingOptionOld  context:&BDSKConditionControllerObservationContext];
    isObserving = YES;
}

- (void)stopObserving {
    if (isObserving) {
        [condition removeObserver:self forKeyPath:@"key"];
        [condition removeObserver:self forKeyPath:@"dateComparison"];
        [condition removeObserver:self forKeyPath:@"attachmentComparison"];
        [condition removeObserver:self forKeyPath:@"stringComparison"];
        [condition removeObserver:self forKeyPath:@"stringValue"];
        [condition removeObserver:self forKeyPath:@"countValue"];
        [condition removeObserver:self forKeyPath:@"numberValue"];
        [condition removeObserver:self forKeyPath:@"andNumberValue"];
        [condition removeObserver:self forKeyPath:@"periodValue"];
        [condition removeObserver:self forKeyPath:@"dateValue"];
        [condition removeObserver:self forKeyPath:@"toDateValue"];
        isObserving = NO;
    }
}

- (void)discardEditing {
    [objectController discardEditing];
}

- (BOOL)commitEditing {
    return [objectController commitEditing];
}

- (void)commitEditingWithDelegate:(id)delegate didCommitSelector:(SEL)didCommitSelector contextInfo:(void *)contextInfo {
    return [objectController commitEditingWithDelegate:delegate didCommitSelector:didCommitSelector contextInfo:contextInfo];
}

@end

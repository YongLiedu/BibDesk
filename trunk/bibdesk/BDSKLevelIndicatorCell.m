//
//  BDSKLevelIndicatorCell.m
//  Bibdesk
//
//  Created by Adam Maxwell on 04/05/07.
/*
 This software is Copyright (c) 2007
 Adam Maxwell. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 - Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in
 the documentation and/or other materials provided with the
 distribution.
 
 - Neither the name of Adam Maxwell nor the names of any
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

#import "BDSKLevelIndicatorCell.h"
#import "NSGeometry_BDSKExtensions.h"

/* Subclass of NSLevelIndicatorCell.  The default relevancy cell draws bars the entire vertical height of the table row, which looks bad.  Using setControlSize: seems to have no effect.
*/
@interface NSLevelIndicatorCell (BDSKPrivateOverrideBecauseApplesSubclassingIsBroken)
- (void)_drawRelevancyWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;
@end

@implementation BDSKLevelIndicatorCell

- (id)initWithLevelIndicatorStyle:(NSLevelIndicatorStyle)levelIndicatorStyle;
{
    self = [super initWithLevelIndicatorStyle:levelIndicatorStyle];
    maxHeight = 0.8 * [self cellSize].height;
    return self;
}

- (id)copyWithZone:(NSZone *)aZone
{
    id obj = [super copyWithZone:aZone];
    [obj setMaxHeight:maxHeight];
    return obj;
}

- (void)setMaxHeight:(float)h;
{
    maxHeight = h;
}

- (float)indicatorHeight { return maxHeight; }

    /*
     This method and -drawingRectForBounds: are never called as of 10.4.8 rdar://problem/4998206
     
     - (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;
     {
         log_method();
         NSRect r = BDSKCenterRectVertically(cellFrame, [self indicatorHeight], [controlView isFlipped]);
         [super drawInteriorWithFrame:r inView:controlView];
     }
     */

- (void)_drawRelevancyWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;
{
    NSRect r = BDSKCenterRectVertically(cellFrame, [self indicatorHeight], [controlView isFlipped]);
    [super _drawRelevancyWithFrame:r inView:controlView];
}

@end

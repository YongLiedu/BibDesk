//
//  NSGeometry_BDSKExtensions.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 14/5/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "NSGeometry_BDSKExtensions.h"

NSRect BDSKCenterRect(NSRect rect, NSSize size, BOOL flipped)
{
    rect.origin.x += 0.5f * (NSWidth(rect) - size.width);
    rect.origin.y += 0.5f * (NSHeight(rect) - size.height);
    rect.origin.y = flipped ? ceilf(rect.origin.y)  : floorf(rect.origin.y);
    rect.size = size;
    return rect;
}

NSRect BDSKCenterRectVertically(NSRect rect, float height, BOOL flipped)
{
    rect.origin.y += 0.5f * (NSHeight(rect) - height);
    rect.origin.y = flipped ? ceilf(rect.origin.y)  : floorf(rect.origin.y);
    rect.size.height = height;
    return rect;
}

NSRect BDSKCenterRectHorizontally(NSRect rect, float width)
{
    rect.origin.x += floorf(0.5f * (NSWidth(rect) - width));
    rect.size.width = width;
    return rect;
}

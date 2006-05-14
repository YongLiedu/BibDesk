//
//  NSGeometry_BDSKExtensions.h
//  Bibdesk
//
//  Created by Christiaan Hofman on 14/5/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSRect BDSKCenterRect(NSRect rect, NSSize size, BOOL flipped);
extern NSRect BDSKCenterRectVertically(NSRect rect, float height, BOOL flipped);
extern NSRect BDSKCenterRectHorizontally(NSRect rect, float width);

// Copyright 2002-2004 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: /Network/Source/CVS/OmniGroup/Frameworks/OmniFoundation/OFGeometry.h,v 1.8 2004/02/10 04:07:40 kc Exp $

#import <OmniFoundation/FrameworkDefines.h>
#import <Foundation/NSGeometry.h>

OmniFoundation_EXTERN NSPoint OFCenterOfCircleFromThreePoints(NSPoint point1, NSPoint point2, NSPoint point3);
OmniFoundation_EXTERN NSRect OFRectFromPoints(NSPoint point1, NSPoint point2);

/*" Returns a rect constrained to lie within boundary. This differs from NSIntersectionRect() in that it will adjust the rectangle's origin in order to place it within the boundary rectangle, and will only reduce the rectangle's size if necessary to make it fit. "*/
OmniFoundation_EXTERN NSRect OFConstrainRect(NSRect rect, NSRect boundary);

/*" Returns a rectangle centered on the specified point, and with the specified size. "*/
static inline NSRect OFRectFromCenterAndSize(NSPoint center, NSSize size) {
    return (NSRect){
              origin: { center.x - (size.width/2), center.y - (size.height/2) },
              size: size
    };
}

OmniFoundation_EXTERN NSRect OFLargestRectAvoidingRectAndFitSize(NSRect parentRect, NSRect childRect, NSSize fitSize);
#define OFLargestRectAvoidingRect(parentRect, childRect) \
OFLargestRectAvoidingRectAndFitSize(parentRect, childRect, NSZeroSize)


// Copyright 2002-2005, 2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease_2007-10-25/OmniGroup/Frameworks/OmniFoundation/OFGeometry.h 89466 2007-08-01 23:35:13Z kc $

#import <OmniFoundation/FrameworkDefines.h>
#import <Foundation/NSGeometry.h>

@class NSArray, NSMutableArray;

/*" Returns the centerpoint of the circle passing through the three specified points. "*/
OmniFoundation_EXTERN NSPoint OFCenterOfCircleFromThreePoints(NSPoint point1, NSPoint point2, NSPoint point3);

/*" Returns a rect constrained to lie within boundary. This differs from NSIntersectionRect() in that it will adjust the rectangle's origin in order to place it within the boundary rectangle, and will only reduce the rectangle's size if necessary to make it fit. "*/
OmniFoundation_EXTERN NSRect OFConstrainRect(NSRect rect, NSRect boundary);

/*" Returns a minimum rectangle containing the specified points. "*/
static inline NSRect OFRectFromPoints(NSPoint point1, NSPoint point2)
{
    return NSMakeRect(MIN(point1.x, point2.x), MIN(point1.y, point2.y),
                      fabsf(point1.x - point2.x), fabsf(point1.y - point2.y));
}

/*" Returns a rectangle centered on the specified point, large enough to contain the other point. "*/
static inline NSRect OFRectFromCenterAndPoint(NSPoint center, NSPoint corner)
{
    return (NSRect){
        origin: {
            center.x - fabsf( corner.x - center.x ),
            center.y - fabsf( corner.y - center.y )
        },
        size: {
            2 * fabsf( corner.x - center.x ),
            2 * fabsf( corner.y - center.y )
        }
    };
}

/*" Returns a rectangle centered on the specified point, and with the specified size. "*/
static inline NSRect OFRectFromCenterAndSize(NSPoint center, NSSize size) {
    return (NSRect){
              origin: { center.x - (size.width/2), center.y - (size.height/2) },
              size: size
    };
}

OmniFoundation_EXTERN float OFSquaredDistanceToFitRectInRect(NSRect sourceRect, NSRect destinationRect);
OmniFoundation_EXTERN NSRect OFClosestRectToRect(NSRect sourceRect, NSArray *candidateRects);
OmniFoundation_EXTERN void OFUpdateRectsToAvoidRectGivenMinimumSize(NSMutableArray *rects, NSRect rectToAvoid, NSSize minimumSize);
/*" Returns YES if sourceSize is at least as tall and as wide as minimumSize, and that neither the height nor the width of minimumSize is 0. "*/
static inline BOOL OFSizeIsOfMinimumSize(NSSize sourceSize, NSSize minimumSize)
{
    return (sourceSize.width >= minimumSize.width) && (sourceSize.height >= minimumSize.height) && (sourceSize.width > 0.0) && (sourceSize.height > 0.0);
}

OmniFoundation_EXTERN NSRect OFLargestRectAvoidingRectAndFitSize(NSRect parentRect, NSRect childRect, NSSize fitSize);
#define OFLargestRectAvoidingRect(parentRect, childRect) OFLargestRectAvoidingRectAndFitSize(parentRect, childRect, NSZeroSize)

/*" Returns the rectangle containing both inRect and the point p. "*/
OmniFoundation_EXTERN NSRect OFRectIncludingPoint(NSRect inRect, NSPoint p);


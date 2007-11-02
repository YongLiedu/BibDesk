/*
 *  FVIcon_Private.h
 *  FileView
 *
 *  Created by Adam Maxwell on 10/21/07.
 *  Copyright 2007 __MyCompanyName__. All rights reserved.
 *
 */

#import "FVBitmapContextCache.h"
#import "FVIconCache.h"
#import <pthread.h>

#ifndef FV_DUMMY_ICON_ALPHA
#define FV_DUMMY_ICON_ALPHA 0.8f
#endif

@class FVIcon;

enum {
    FVFinderIconType,
    FVImageFileType,
    FVQTMovieType,
    FVPDFType,
    FVPostscriptType
};
typedef NSUInteger FVIconType;

@interface FVIcon (Private)
- (CGRect)_drawingRectWithRect:(NSRect)iconRect;
@end

FV_PRIVATE_EXTERN char * FVCreateDiskCacheNameWithURL(NSURL *fileURL);

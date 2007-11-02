//
//  FVFinderIcon.m
//  FileView
//
//  Created by Adam Maxwell on 10/21/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "FVFinderIcon.h"

@implementation FVFinderIcon

static IconRef __genericDocIcon;
static IconRef __questionIcon;
static IconRef __httpIcon;
static IconRef __ftpIcon;
static IconRef __genericURLIcon;

+ (void)initialize
{
    static BOOL didInit = NO;
    if (NO == didInit) {
        OSStatus err;
        err = GetIconRef(kOnSystemDisk, kSystemIconsCreator, kGenericDocumentIcon, &__genericDocIcon);
        if (err) __genericDocIcon = NULL;
        err = GetIconRef(kOnSystemDisk, kSystemIconsCreator, kQuestionMarkIcon, &__questionIcon);
        if (err) __questionIcon = NULL;
        err = GetIconRef(kOnSystemDisk, kSystemIconsCreator, kInternetLocationHTTPIcon, &__httpIcon);
        if (err) __httpIcon = NULL;
        err = GetIconRef(kOnSystemDisk, kSystemIconsCreator, kInternetLocationFTPIcon, &__ftpIcon);
        if (err) __ftpIcon = NULL;
        err = GetIconRef(kOnSystemDisk, kSystemIconsCreator, kGenericURLIcon, &__genericURLIcon);
        if (err) __genericURLIcon = NULL;
        didInit = YES;
    }
}

static inline NSSize bestIntegralSizeForIconSize(NSSize aSize)
{
    if (aSize.width <= 20)
        return NSMakeSize(16, 16);
    if (aSize.width <= 40)
        return NSMakeSize(32, 32);
    if (aSize.width <= 80)
        return NSMakeSize(64, 64);
    if (aSize.width <= 160)
        return NSMakeSize(128, 128);
    if (aSize.width <= 320)
        return NSMakeSize(256, 256);
    
    return NSMakeSize(512, 512);
}

- (BOOL)needsRenderForSize:(NSSize)size
{
    // this is a Finder icon, which may need to be redrawn for a given size
    BOOL needsRender = NO;
    size = bestIntegralSizeForIconSize(size);
    
    pthread_mutex_lock(&_mutex);
    if (NULL == _imageRef || NSEqualSizes(_iconSize, size) == NO) {
        _desiredSize = size;
        needsRender = YES;
    }
    pthread_mutex_unlock(&_mutex);
    return needsRender;
}

- (void)renderOffscreen
{  
    NSSize newSize;
    pthread_mutex_lock(&_mutex);
    newSize = _desiredSize;
    pthread_mutex_unlock(&_mutex);
    
    CGContextRef ctxt = [FVBitmapContextCache newBitmapContextOfWidth:newSize.width height:newSize.height];
    OSStatus err;
    CGRect rect;
    
    rect = CGRectMake(0, 0, newSize.width, newSize.height);
    // clear since the bitmap buffer could have garbage in it
    CGContextClearRect(ctxt, rect);
    
    // missing file has NULL _iconRef
    if (NULL == _iconRef) {
        
        if (__genericDocIcon)
            err = PlotIconRefInContext(ctxt, &rect, kAlignAbsoluteCenter, kTransformNone, NULL, kPlotIconRefNormalFlags, __genericDocIcon);
        rect = CGRectInset(rect, newSize.width/4, newSize.height/4);
        if (__questionIcon)
            err = PlotIconRefInContext(ctxt, &rect, kAlignCenterBottom, kTransformNone, NULL, kPlotIconRefNormalFlags, __questionIcon);          
    }
    else {
        PlotIconRefInContext(ctxt, &rect, kAlignAbsoluteCenter, kTransformNone, NULL, kPlotIconRefNormalFlags, _iconRef);
    }
    
    pthread_mutex_lock(&_mutex);
    _iconSize = newSize;
    CGImageRelease(_imageRef);
    _imageRef = CGBitmapContextCreateImage(ctxt);
    pthread_mutex_unlock(&_mutex);
    
    [FVBitmapContextCache disposeOfBitmapContext:ctxt];
}

- (id)initWithURLScheme:(NSString *)scheme ofSize:(NSSize)iconSize;
{
    NSParameterAssert(nil != scheme);
    self = [super init];
    if (self) {
        _iconType = FVFinderIconType;
        _iconSize = bestIntegralSizeForIconSize(iconSize);
        _desiredSize = _iconSize;
        _imageRef = NULL;
        
        if ([scheme isEqualToString:@"http"])
            _iconRef = __httpIcon;
        else if ([scheme isEqualToString:@"ftp"])
            _iconRef = __ftpIcon;
        else
            _iconRef = __genericURLIcon;
        // increment retain count of the shared instance
        if (_iconRef) AcquireIconRef(_iconRef);
        
        int rc = pthread_mutex_init(&_mutex, NULL);
        if (rc)
            perror("pthread_mutex_init");
    }
    return self;
}

- (id)initWithFinderIconOfURL:(NSURL *)theURL ofSize:(NSSize)iconSize;
{
    self = [super init];
    if (self) {
        _iconType = FVFinderIconType;
        _iconSize = bestIntegralSizeForIconSize(iconSize);
        _desiredSize = _iconSize;
        _imageRef = NULL;
        _iconRef = NULL;
        
        if (theURL) {
            OSStatus err;
            FSRef fileRef;
            if (FALSE == CFURLGetFSRef((CFURLRef)theURL, &fileRef))
                err = fnfErr;
            else
                err = noErr;
            err = GetIconRefFromFileInfo(&fileRef, 0, NULL, kFSCatInfoNone, NULL, kIconServicesNormalUsageFlag, &_iconRef, NULL);
            if (noErr != err) {
                // this will indicate that we should plot the question mark icon
                _iconRef = NULL;
            }
            
            // !!! docs don't say we own the reference from GetIconRefFromFileInfo
            
        }
        else {
            _iconRef = NULL;
        }
        
        int rc = pthread_mutex_init(&_mutex, NULL);
        if (rc)
            perror("pthread_mutex_init");
    }
    return self;   
}

- (void)releaseResources
{
    // do nothing since we only have a single representation; scrolling is pretty weird otherwise
}

- (void)dealloc
{
    pthread_mutex_destroy(&_mutex);
    if (_iconRef) ReleaseIconRef(_iconRef);
    CGImageRelease(_imageRef);
    [super dealloc];
}

- (NSSize)size { return _iconSize; }

- (void)drawInRect:(NSRect)dstRect inCGContext:(CGContextRef)context;
{
    pthread_mutex_lock(&_mutex);
    if (_imageRef)
        CGContextDrawImage(context, [self _drawingRectWithRect:dstRect], _imageRef);
    pthread_mutex_unlock(&_mutex);
}

@end

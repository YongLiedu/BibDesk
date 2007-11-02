//
//  FVTextIcon.m
//  FileView
//
//  Created by Adam Maxwell on 10/21/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "FVTextIcon.h"

@implementation FVTextIcon

// cache these so we avoid hitting NSPrintInfo; we only care to have something that approximates a page size, anyway
static NSSize __paperSize;
static NSSize __containerSize;
static CGAffineTransform __paperTransform;

+ (void)initialize
{
    static BOOL didInit = NO;
    if (NO == didInit) {
        NSPrintInfo *pInfo = [NSPrintInfo sharedPrintInfo];
        __paperSize = [pInfo paperSize];
        CGAffineTransform t1 = CGAffineTransformMakeTranslation([pInfo leftMargin], __paperSize.height - [pInfo topMargin]);
        CGAffineTransform t2 = CGAffineTransformMakeScale(1, -1);
        __paperTransform = CGAffineTransformConcat(t2, t1);
        // could add in NSTextContainer's default lineFragmentPadding
        __containerSize = __paperSize;
        __containerSize.width -= 2 * [pInfo leftMargin];
        __containerSize.height -= 2* [pInfo topMargin];
        didInit = YES;
    }
}

// A particular layout manager/text storage combination is not thread safe, so the AppKit string drawing routines must only be used from the main thread.  We're using the thread dictionary to cache our string drawing machinery on a per-thread basis.
+ (NSTextStorage *)textStorageForCurrentThread;
{
    NSMutableDictionary *threadDictionary = [[NSThread currentThread] threadDictionary];
    NSString *key = @"FVTextIconTextStorage";
    NSTextStorage *textStorage = [threadDictionary objectForKey:key];
    if (nil == textStorage) {
        textStorage = [[NSTextStorage alloc] init];
        NSLayoutManager *lm = [[NSLayoutManager alloc] init];
        NSTextContainer *tc = [[NSTextContainer alloc] init];
        [tc setContainerSize:__containerSize];
        [lm addTextContainer:tc];
        // don't let the layout manager use its threaded layout (see header)
        [lm setBackgroundLayoutEnabled:NO];
        [textStorage addLayoutManager:lm];
        // retained by layout manager
        [tc release];
        // retained by text storage
        [lm release];
        // see header; the CircleView example sets it to NO
        [lm setUsesScreenFonts:YES];
        [threadDictionary setObject:textStorage forKey:key];
        [textStorage release];
    }
    return textStorage;
}

// allows a crude sniffing, so initWithTextAtURL: doesn't have to immediately instantiate an attributed string ivar and return nil if that fails
+ (BOOL)canInitWithURL:(NSURL *)aURL;
{
    NSAttributedString *attributedString = [[NSAttributedString alloc] initWithURL:aURL documentAttributes:NULL];
    BOOL canInit = (nil != attributedString);
    [attributedString release];
    return canInit;
}

- (id)initWithTextAtURL:(NSURL *)aURL;
{
    self = [super init];
    if (self) {
        _fileURL = [aURL copy];
        _fullSize = __paperSize;
        _thumbnailSize = NSMakeSize(_fullSize.width / 2, _fullSize.height / 2);
        _fullImageRef = NULL;
        _thumbnailRef = NULL;
        _inDiskCache = NO;
        _diskCacheName = FVCreateDiskCacheNameWithURL(_fileURL);
        
        int rc = pthread_mutex_init(&_mutex, NULL);
        if (rc)
            perror("pthread_mutex_init");
    }
    return self;
}

- (void)dealloc
{
    pthread_mutex_destroy(&_mutex);
    [_fileURL release];
    CGImageRelease(_fullImageRef);
    CGImageRelease(_thumbnailRef);
    free(_diskCacheName);
    [super dealloc];
}

- (NSSize)size { return _fullSize; }

- (BOOL)needsRenderForSize:(NSSize)size { 
    BOOL needsRender = NO;
    // if we can't lock we're already rendering, which will give us both icons (so no render required)
    if (pthread_mutex_trylock(&_mutex) == 0) {
        if (size.height < _thumbnailSize.height * 1.2)
            needsRender = (NULL == _thumbnailRef);
        else 
            needsRender = (NULL == _fullImageRef);
        pthread_mutex_unlock(&_mutex);
    }
    return needsRender;
}

// It turns out to be fairly important to draw small text icons if possible, since the bitmaps have a pretty huge memory footprint (if we draw _fullImageRef all the time, dragging in the view is unbearably slow if there are more than a couple of text icons).
- (void)fastDrawInRect:(NSRect)dstRect inCGContext:(CGContextRef)context;
{
    pthread_mutex_lock(&_mutex);
    if (_thumbnailRef) {
        CGContextDrawImage(context, [self _drawingRectWithRect:dstRect], _thumbnailRef);
        pthread_mutex_unlock(&_mutex);
    }
    else {
        pthread_mutex_unlock(&_mutex);
        [self drawInRect:dstRect inCGContext:context];
    }
}

- (void)drawInRect:(NSRect)dstRect inCGContext:(CGContextRef)context;
{
    pthread_mutex_lock(&_mutex);
    CGRect drawRect = [self _drawingRectWithRect:dstRect];
    CGImageRef toDraw = _thumbnailRef;
    if (drawRect.size.height > _thumbnailSize.height * 1.2)
        toDraw = _fullImageRef;
    
    // draw the image if it's been created, or just draw a dummy icon
    if (toDraw) {
        CGContextDrawImage(context, drawRect, toDraw);
        pthread_mutex_unlock(&_mutex);
    }
    else {
        pthread_mutex_unlock(&_mutex);
        CGContextSaveGState(context);
        CGContextSetRGBFillColor(context, 1.0, 1.0, 1.0, FV_DUMMY_ICON_ALPHA);
        CGContextFillRect(context, drawRect);
        CGContextRestoreGState(context);
    }
}

- (void)releaseResources
{
    pthread_mutex_lock(&_mutex);
    CGImageRelease(_fullImageRef);
    _fullImageRef = NULL;
    pthread_mutex_unlock(&_mutex);
}

- (void)renderOffscreen
{
    // !!! early return here after a cache check
    pthread_mutex_lock(&_mutex);
    if (_inDiskCache) {
        CGImageRelease(_fullImageRef);
        _fullImageRef = [FVIconCache newImageNamed:_diskCacheName];
        BOOL success = (NULL != _fullImageRef);
        if (success) {
            pthread_mutex_unlock(&_mutex);
            return;
        }
    }
    pthread_mutex_unlock(&_mutex);
    
    // definitely use the context cache for this, since these bitmaps are pretty huge
    CGContextRef ctxt = [FVBitmapContextCache newBitmapContextOfWidth:__paperSize.width height:__paperSize.height];
    
    NSTextStorage *textStorage = [FVTextIcon textStorageForCurrentThread];
    
    // originally kept the attributed string as an ivar, but it's not worth it in most cases
    
    // no need to lock for -fileURL since it's invariant
    NSDictionary *documentAttributes;
    NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] initWithURL:_fileURL documentAttributes:&documentAttributes];
    
    CGAffineTransform pageTransform = __paperTransform;
    NSSize containerSize = __containerSize;
    NSSize paperSize = __paperSize;
    
    // use a monospaced font for plain text
    if (nil != attrString) {
        if (nil == documentAttributes || [[documentAttributes objectForKey:NSDocumentTypeDocumentAttribute] isEqualToString:NSPlainTextDocumentType]) {
            NSFont *plainFont = [NSFont userFixedPitchFontOfSize:10.0f];
            [attrString addAttribute:NSFontAttributeName value:plainFont range:NSMakeRange(0, [attrString length])];
        }
        else if (nil != documentAttributes) {
            
            CGFloat left, right, top, bottom;
            
            left = [[documentAttributes objectForKey:NSLeftMarginDocumentAttribute] floatValue];
            right = [[documentAttributes objectForKey:NSRightMarginDocumentAttribute] floatValue];
            top = [[documentAttributes objectForKey:NSTopMarginDocumentAttribute] floatValue];
            bottom = [[documentAttributes objectForKey:NSBottomMarginDocumentAttribute] floatValue];
            paperSize = [[documentAttributes objectForKey:NSPaperSizeDocumentAttribute] sizeValue];
            
            CGAffineTransform t1 = CGAffineTransformMakeTranslation(0, paperSize.height);
            CGAffineTransform t2 = CGAffineTransformMakeScale(1, -1);
            pageTransform = CGAffineTransformConcat(t2, t1);
            t1 = CGAffineTransformMakeTranslation(left, -bottom);
            pageTransform = CGAffineTransformConcat(pageTransform, t1);
            containerSize.width = paperSize.width - left - right;
            containerSize.height = paperSize.height - top - bottom;
        }
    }
    
    [textStorage beginEditing];
    if (attrString) {
        [textStorage setAttributedString:attrString];
        [attrString release];
        
        // these will be garbage from here on, so set to nil in case I forget and try using them
        attrString = nil;
        documentAttributes = nil;
    }
    else {
        // avoid setting the text storage to nil, and display a mildly unhelpful error message
        NSString *err = [NSLocalizedString(@"Unable to read text file ", @"single trailing space") stringByAppendingString:[_fileURL path]];
        [[textStorage mutableString] setString:err];
    }  
    [textStorage endEditing];
    
    NSRect stringRect = NSZeroRect;
    stringRect.size = paperSize;
    
    // assume a white page background; could maybe read from the attributed string's background color?
    CGContextSetRGBFillColor(ctxt, 1.0, 1.0, 1.0, 1.0);
    CGContextFillRect(ctxt, *(CGRect *)&stringRect);
    
    CGContextSaveGState(ctxt);
    CGContextConcatCTM(ctxt, pageTransform);
    
    // we flipped the CTM in our bitmap context since NSLayoutManager expects a flipped context
    NSGraphicsContext *nsCtxt = [NSGraphicsContext graphicsContextWithGraphicsPort:ctxt flipped:YES];
    
    // save whatever is current on this thread, since we're going to use setCurrentContext:
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:nsCtxt];
    
    // objectAtIndex:0 is safe, since we added these to the text storage (so there's at least one)
    NSLayoutManager *lm = [[textStorage layoutManagers] objectAtIndex:0];
    NSTextContainer *tc = [[lm textContainers] objectAtIndex:0];
    [tc setContainerSize:containerSize];
    
    NSRange glyphRange;
    
    // we now have a properly flipped graphics context, so force layout and then draw the text
    glyphRange = [lm glyphRangeForBoundingRect:stringRect inTextContainer:tc];
    NSRect usedRect = [lm usedRectForTextContainer:tc];
    
    // NSRunStorage raises if we try drawing a zero length range (happens if you have an empty text file)
    if (glyphRange.length > 0) {
        [lm drawBackgroundForGlyphRange:glyphRange atPoint:usedRect.origin];
        [lm drawGlyphsForGlyphRange:glyphRange atPoint:usedRect.origin];
    }
    
    // no point in keeping this around in memory
    [textStorage deleteCharactersInRange:NSMakeRange(0, [textStorage length])];
    
    // restore the previous context
    [NSGraphicsContext restoreGraphicsState];
    
    pthread_mutex_lock(&_mutex);
    CGImageRelease(_fullImageRef);
    _fullImageRef = CGBitmapContextCreateImage(ctxt);
    [FVIconCache cacheCGImage:_fullImageRef withName:_diskCacheName];
    _inDiskCache = YES;
    
    // reset size while we have the lock, since it may be different now that we've read the string
    _fullSize = paperSize;
    _thumbnailSize = NSMakeSize(_fullSize.width / 2, _fullSize.height / 2);
    
    pthread_mutex_unlock(&_mutex);
    
    // now restore our cached bitmap context and push it back into the cache
    CGContextRestoreGState(ctxt);
    [FVBitmapContextCache disposeOfBitmapContext:ctxt];
    
    // repeat for the thumbnail image as needed, but this time just draw our bitmap again
    if (NULL == _thumbnailRef) {
        
        ctxt = [FVBitmapContextCache new8BitGrayBitmapContextOfWidth:_thumbnailSize.width height:_thumbnailSize.height];
        CGContextSaveGState(ctxt);
        
        // take a small hit here for good interpolation so we can draw smaller icons at larger sizes
        CGContextSetInterpolationQuality(ctxt, kCGInterpolationHigh);
        stringRect.origin = NSZeroPoint;
        stringRect.size = _thumbnailSize;
        
        pthread_mutex_lock(&_mutex);
        if (_fullImageRef) {
            CGContextDrawImage(ctxt, *(CGRect *)&stringRect, _fullImageRef);
            CGImageRelease(_thumbnailRef);
            _thumbnailRef = CGBitmapContextCreateImage(ctxt);
        }
        pthread_mutex_unlock(&_mutex);
        
        CGContextRestoreGState(ctxt);
        [FVBitmapContextCache disposeOf8BitGrayBitmapContext:ctxt];
    }
    
    
}    

@end

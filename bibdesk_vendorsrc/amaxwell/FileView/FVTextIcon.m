//
//  FVTextIcon.m
//  FileView
//
//  Created by Adam Maxwell on 10/21/07.
/*
 This software is Copyright (c) 2007-2009
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

#import "FVTextIcon.h"
#import "FVIcon_Private.h"

@implementation FVTextIcon

// cache these so we avoid hitting NSPrintInfo; we only care to have something that approximates a page size, anyway
static NSSize _paperSize;
static NSSize _containerSize;
static CGAffineTransform _paperTransform;
static NSMutableSet *_cachedTextSystems = nil;
static OSSpinLock _cacheLock = OS_SPINLOCK_INIT;

#define MAX_CACHED_TEXT_SYSTEMS 10

+ (void)initialize
{
    FVINITIALIZE(FVTextIcon);

    NSPrintInfo *pInfo = [NSPrintInfo sharedPrintInfo];
    _paperSize = [pInfo paperSize];
    CGAffineTransform t1 = CGAffineTransformMakeTranslation([pInfo leftMargin], _paperSize.height - [pInfo topMargin]);
    CGAffineTransform t2 = CGAffineTransformMakeScale(1, -1);
    _paperTransform = CGAffineTransformConcat(t2, t1);
    // could add in NSTextContainer's default lineFragmentPadding
    _containerSize = _paperSize;
    _containerSize.width -= 2 * [pInfo leftMargin];
    _containerSize.height -= 2* [pInfo topMargin];
    
    // make sure we compare with pointer equality; all I really want is a bag
    _cachedTextSystems = (NSMutableSet *)CFSetCreateMutable(NULL, MAX_CACHED_TEXT_SYSTEMS, &FVNSObjectPointerSetCallBacks);
}

// A particular layout manager/text storage combination is not thread safe, so the AppKit string drawing routines must only be used from the main thread.  We're using the thread dictionary to cache our string drawing machinery on a per-thread basis.  Update:  for the record, Aki Inoue says that NSStringDrawing is supposed to be thread safe, so the crash I experienced may be something else.
+ (NSTextStorage *)_newTextStorage;
{
    NSTextStorage *textStorage = [[NSTextStorage alloc] init];
    NSLayoutManager *lm = [[NSLayoutManager alloc] init];
    NSTextContainer *tc = [[NSTextContainer alloc] init];
    [tc setContainerSize:_containerSize];
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
    return textStorage;
}

// caller will own the returned object
+ (NSTextStorage *)newTextStorage
{
    OSSpinLockLock(&_cacheLock);
    NSTextStorage *textStorage = [_cachedTextSystems anyObject];
    if (textStorage) {
        [textStorage retain];
        [_cachedTextSystems removeObject:textStorage];
    }
    OSSpinLockUnlock(&_cacheLock);
    if (nil == textStorage)
        textStorage = [self _newTextStorage];
    return textStorage;
}

// assumes the object was retrieved from +newTextStorage and /not/ (auto)released
+ (void)pushTextStorage:(NSTextStorage *)textStorage
{
    OSSpinLockLock(&_cacheLock);
    if ([_cachedTextSystems count] < MAX_CACHED_TEXT_SYSTEMS)
        [_cachedTextSystems addObject:textStorage];
    OSSpinLockUnlock(&_cacheLock);
    
    // either retained by the set, or we'll just let it go away
    [textStorage release];
}

// allows a crude sniffing, so initWithTextAtURL: doesn't have to immediately instantiate an attributed string ivar and return nil if that fails

+ (NSArray *)_supportedUTIs
{
    // new in 10.5
    if ([NSAttributedString respondsToSelector:@selector(textUnfilteredTypes)])
        return [NSAttributedString performSelector:@selector(textUnfilteredTypes)];
    
    NSMutableSet *UTIs = [NSMutableSet set];
    NSEnumerator *typeEnum = [[NSAttributedString textUnfilteredFileTypes] objectEnumerator];
    NSString *aType;
    CFStringRef aUTI;
    
    // checking OSType and extension gives lots of duplicates, but the set filters them out
    while ((aType = [typeEnum nextObject])) {
        OSType osType = NSHFSTypeCodeFromFileType(aType);
        if (0 != osType) {
            aUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassOSType, (CFStringRef)aType, NULL);
        }
        else {
            aUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (CFStringRef)aType, NULL);
        }
        if (NULL != aUTI) {
            [UTIs addObject:(id)aUTI];
            CFRelease(aUTI);
        }
    }
    return [UTIs allObjects];
}

// This should be very reliable, but in practice it's only as reliable as the UTI declaration.  For instance, OmniGraffle declares .graffle files as public.composite-content and public.xml in its Info.plist.  Since we see that it's public.xml (which is in this list), we open it as text, and it will actually open with NSAttributedString...and display as binary garbage.
+ (BOOL)canInitWithUTI:(NSString *)aUTI
{
    static NSArray *types = nil;
    if (nil == types) {
        NSMutableArray *a = [NSMutableArray arrayWithArray:[self _supportedUTIs]];
        // avoid threading issues on 10.4; this class should never be asked to render HTML anyway, since that's now handled by FVWebViewIcon
        if (floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_4)
            [a removeObject:(id)kUTTypeHTML];
        types = [a copyWithZone:[self zone]];
    }

    NSUInteger cnt = [types count];
    while (cnt--)
        if (UTTypeConformsTo((CFStringRef)aUTI, (CFStringRef)[types objectAtIndex:cnt]))
            return YES;
    return NO;
}

// This is mainly useful to prove that the file cannot be opened; as in the case of OmniGraffle files (see comment above), it returns YES.
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
        
        _drawsLinkBadge = [[self class] _shouldDrawBadgeForURL:aURL copyTargetURL:&_fileURL];                
        _fullSize = _paperSize;
        _thumbnailSize = _paperSize;
        // first approximation
        FVIconLimitThumbnailSize(&_thumbnailSize);
        _desiredSize = NSZeroSize;
        _fullImage = NULL;
        _thumbnail = NULL;
        _diskCacheName = [FVIconCache createDiskCacheNameWithURL:_fileURL];
        _isHTML = NO;
                
        NSInteger rc = pthread_mutex_init(&_mutex, NULL);
        if (rc)
            perror("pthread_mutex_init");
    }
    return self;
}

// return the same thing as text; just a container for the URL, until actually asked to render the text file
- (id)initWithHTMLAtURL:(NSURL *)aURL;
{
    if (self = [self initWithTextAtURL:aURL]) {
        _isHTML = YES;
    }
    return self;
}

- (void)dealloc
{
    pthread_mutex_destroy(&_mutex);
    [_fileURL release];
    CGImageRelease(_fullImage);
    CGImageRelease(_thumbnail);
    free(_diskCacheName);
    [super dealloc];
}

- (BOOL)tryLock { return pthread_mutex_trylock(&_mutex) == 0; }
- (void)lock { pthread_mutex_lock(&_mutex); }
- (void)unlock { pthread_mutex_unlock(&_mutex); }

- (NSSize)size { return _fullSize; }

- (BOOL)needsRenderForSize:(NSSize)size { 
    BOOL needsRender = NO;
    // if we can't lock we're already rendering, which will give us both icons (so no render required)
    if ([self tryLock]) {
        _desiredSize = size;
        if (FVShouldDrawFullImageWithThumbnailSize(size, _thumbnailSize))
            needsRender = (NULL == _fullImage);
        else
            needsRender = (NULL == _thumbnail);
        [self unlock];
    }
    return needsRender;
}

// It turns out to be fairly important to draw small text icons if possible, since the bitmaps have a pretty huge memory footprint (if we draw _fullImage all the time, dragging in the view is unbearably slow if there are more than a couple of text icons).  Using trylock for drawing to avoid stalling the main thread while rendering; there are some degenerate cases where rendering is really slow (e.g. a huge ASCII grid file).
- (void)fastDrawInRect:(NSRect)dstRect ofContext:(CGContextRef)context;
{
    // draw thumbnail if present, regardless of the size requested
    if (NO == [self tryLock]) {
        // no lock, so just draw the blank page and bail out
        [self _drawPlaceholderInRect:dstRect ofContext:context];
    }
    else if (NULL == _thumbnail) {
        [self unlock];
        [self _drawPlaceholderInRect:dstRect ofContext:context];
    }
    else if (_thumbnail) {
        CGContextDrawImage(context, [self _drawingRectWithRect:dstRect], _thumbnail);
        [self unlock];
        if (_drawsLinkBadge)
            [self _badgeIconInRect:dstRect ofContext:context];
    }
    else {
        [self unlock];
        // let drawInRect: handle the rect conversion
        [self drawInRect:dstRect ofContext:context];
    }
}

- (void)drawInRect:(NSRect)dstRect ofContext:(CGContextRef)context;
{
    if (NO == [self tryLock]) {
        [self _drawPlaceholderInRect:dstRect ofContext:context];
    }
    else {
        CGRect drawRect = [self _drawingRectWithRect:dstRect];
        CGImageRef toDraw = _thumbnail;
        
        if (FVShouldDrawFullImageWithThumbnailSize(dstRect.size, _thumbnailSize))
            toDraw = _fullImage;
        
        // draw the image if it's been created, or just draw a dummy icon
        if (toDraw) {
            CGContextDrawImage(context, drawRect, toDraw);
            [self unlock];
            if (_drawsLinkBadge)
                [self _badgeIconInRect:dstRect ofContext:context];
        }
        else {
            [self unlock];
            [self _drawPlaceholderInRect:dstRect ofContext:context];
        }
    }
}

- (BOOL)canReleaseResources;
{
    return (NULL != _fullImage || NULL != _thumbnail);
}

- (void)releaseResources
{
    [self lock];
    CGImageRelease(_fullImage);
    _fullImage = NULL;
    CGImageRelease(_thumbnail);
    _thumbnail = NULL;
    [self unlock];
}

- (void)_loadHTML:(NSMutableDictionary *)HTMLDict {
    NSDictionary *documentAttributes = nil;
    NSAttributedString *attrString = [[NSAttributedString alloc] initWithURL:_fileURL documentAttributes:&documentAttributes];
    if (attrString)
        [HTMLDict setObject:attrString forKey:@"attributedString"];
    if (documentAttributes)
        [HTMLDict setObject:documentAttributes forKey:@"documentAttributes"];
    [attrString release];
}

- (void)renderOffscreen
{
    // hold the lock to let needsRenderForSize: know that this icon doesn't need rendering
    [self lock];
    
    // !!! two early returns here after a cache check

    if (NULL != _fullImage) {
        // note that _fullImage may be non-NULL if we were added to the FVOperationQueue multiple times before renderOffscreen was called
        [self unlock];
        return;
    } 
    else {
        
        if (NULL == _thumbnail) {
            _thumbnail = [FVIconCache newThumbnailNamed:_diskCacheName];
            _thumbnailSize = FVCGImageSize(_thumbnail);
        }
        
        if (_thumbnail && FVShouldDrawFullImageWithThumbnailSize(_desiredSize, _thumbnailSize)) {
            _fullImage = [FVIconCache newImageNamed:_diskCacheName];
            if (NULL != _fullImage) {
                [self unlock];
                return;
            }
        }
        
        if (NULL != _thumbnail) {
            [self unlock];
            return;
        }
    }

    NSParameterAssert(NULL == _fullImage);
    NSParameterAssert(NULL == _thumbnail);
    
    // definitely use the context cache for this, since these bitmaps are pretty huge
    CGContextRef ctxt = [FVBitmapContextCache newBitmapContextOfWidth:_paperSize.width height:_paperSize.height];
    
    NSTextStorage *textStorage = [FVTextIcon newTextStorage];
    
    // originally kept the attributed string as an ivar, but it's not worth it in most cases
    
    // no need to lock for -fileURL since it's invariant
    NSDictionary *documentAttributes = nil;
    NSMutableAttributedString *attrString = nil;
    
    if (floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_4 && _isHTML) {
        NSMutableDictionary *HTMLDict = [NSMutableDictionary dictionary];
        [self performSelectorOnMainThread:@selector(_loadHTML:) withObject:HTMLDict waitUntilDone:YES];
        attrString = [[HTMLDict objectForKey:@"attributedString"] mutableCopy];
        documentAttributes = [HTMLDict objectForKey:@"documentAttributes"];
    } else {
        attrString = [[NSMutableAttributedString alloc] initWithURL:_fileURL documentAttributes:&documentAttributes];
    }
    
    CGAffineTransform pageTransform = _paperTransform;
    NSSize containerSize = _containerSize;
    NSSize paperSize = _paperSize;
    
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
        NSBundle *bundle = [NSBundle bundleForClass:[FVTextIcon class]];
        
        NSString *err = [NSLocalizedStringFromTableInBundle(@"Unable to read text file ", @"FileView", bundle, @"error message with single trailing space") stringByAppendingString:[_fileURL path]];
        [[textStorage mutableString] setString:err];
    }  
    [textStorage endEditing];
    
    NSRect stringRect = NSZeroRect;
    stringRect.size = paperSize;
    
    CGContextSaveGState(ctxt);

    // assume a white page background; could maybe read from the attributed string's background color?
    CGContextSetRGBFillColor(ctxt, 1.0, 1.0, 1.0, 1.0);
    CGContextFillRect(ctxt, *(CGRect *)&stringRect);
    
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
    [FVTextIcon pushTextStorage:textStorage];
    textStorage = nil;
    
    // restore the previous context
    [NSGraphicsContext restoreGraphicsState];
    
    CGImageRelease(_fullImage);
    _fullImage = CGBitmapContextCreateImage(ctxt);
    if (NULL != _fullImage)
        [FVIconCache cacheImage:_fullImage withName:_diskCacheName];
    
    // now restore our cached bitmap context and push it back into the cache
    CGContextRestoreGState(ctxt);
    [FVBitmapContextCache disposeOfBitmapContext:ctxt];
    
    // repeat for the thumbnail image as needed, but this time just draw our bitmap again
    if (NULL == _thumbnail)
        _thumbnail = FVCreateResampledThumbnail(_fullImage, true);

    // reset size while we have the lock, since it may be different now that we've read the string
    _fullSize = paperSize;
    
    if (NULL != _thumbnail) {
        _thumbnailSize = FVCGImageSize(_thumbnail);
        [FVIconCache cacheThumbnail:_thumbnail withName:_diskCacheName];
    }
    
    // get rid of this to save memory if we aren't drawing it right away
    if (FVShouldDrawFullImageWithThumbnailSize(_desiredSize, _thumbnailSize) == NO) {
        CGImageRelease(_fullImage);
        _fullImage = NULL;
    }

    [self unlock];
}    

@end

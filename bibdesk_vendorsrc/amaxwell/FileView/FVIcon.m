//
//  FVIcon.m
//  FileViewTest
//
//  Created by Adam Maxwell on 08/31/07.
/*
 This software is Copyright (c) 2007-2008
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

#import "FVIcon.h"
#import "FVCGImageIcon.h"
#import "FVFinderIcon.h"
#import "FVPDFIcon.h"
#import "FVTextIcon.h"
#import "FVQLIcon.h"
#import "FVWebViewIcon.h"
#import <sys/stat.h>

#pragma mark -
#pragma mark FVIcon abstract class

// FVIcon abstract class stuff
static FVIcon *defaultPlaceholderIcon = nil;
static Class FVIconClass = Nil;
static Class FVQLIconClass = Nil;
static NSURL *missingFileURL = nil;

@implementation FVIcon

+ (void)initialize
{
    if ([FVIcon class] == self) {
        FVIconClass = self;
        if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_4) {
            NSBundle *frameworkBundle = [NSBundle bundleForClass:FVIconClass];
            [[NSBundle bundleWithPath:[frameworkBundle pathForResource:@"FileView-Leopard" ofType:@"bundle"]] load];
            FVQLIconClass = NSClassFromString(@"FVQLIcon");
        }
        defaultPlaceholderIcon = (FVIcon *)NSAllocateObject(FVIconClass, 0, [self zone]);
        missingFileURL = [[NSURL alloc] initWithScheme:@"x-fileview" host:@"localhost" path:@"/missing"];
    }
}

+ (id)allocWithZone:(NSZone *)aZone
{
    return FVIconClass == self ? defaultPlaceholderIcon : NSAllocateObject(self, 0, aZone);
}

- (void)dealloc
{
    if ([self class] != FVIconClass)
        [super dealloc];
}

+ (NSImage *)imageWithURL:(NSURL *)representedURL size:(NSSize)iconSize
{
    FVIcon *anIcon = [FVIcon iconWithURL:representedURL size:iconSize];
    if ([anIcon needsRenderForSize:iconSize])
        [anIcon renderOffscreen];
    NSImage *nsImage = [[[NSImage alloc] initWithSize:iconSize] autorelease];
    [nsImage lockFocus];
    CGContextRef ctxt = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
    CGContextSetShouldAntialias(ctxt, true);
    CGContextSetInterpolationQuality(ctxt, kCGInterpolationHigh);
    [anIcon drawInRect:NSMakeRect(0, 0, iconSize.width, iconSize.height) inCGContext:ctxt];
    [nsImage unlockFocus];
    return nsImage;
}

+ (NSURL *)missingFileURL;
{
    return missingFileURL;
}

+ (id)iconWithPath:(NSString *)absolutePath size:(NSSize)iconSize;
{
    // guaranteed to be a filesystem path or NSNull, so we can use fileURLWithPath:
    NSURL *representedURL = nil;
    if (absolutePath && NO == [absolutePath isEqual:(id)[NSNull null]])
        representedURL = [NSURL fileURLWithPath:absolutePath];
    return [self iconWithURL:representedURL size:iconSize];
}

+ (BOOL)_shouldDrawBadgeForURL:(NSURL **)aURL
{
    NSParameterAssert([*aURL isFileURL]);
    
    const UInt8 *fsPath = (void *)[[*aURL path] UTF8String];
    OSStatus err;
    FSRef fileRef;
    err = FSPathMakeRefWithOptions(fsPath, kFSPathMakeRefDoNotFollowLeafSymlink, &fileRef, NULL);   
    
    // kLSItemContentType returns a CFStringRef, according to the header
    CFStringRef theUTI = NULL;
    if (noErr == err)
        err = LSCopyItemAttribute(&fileRef, kLSRolesAll, kLSItemContentType, (CFTypeRef *)&theUTI);
    
    BOOL drawBadge = (NULL != theUTI && UTTypeConformsTo(theUTI, kUTTypeResolvable));
    
    if (theUTI) CFRelease(theUTI);
    
    if (drawBadge) {
        // replace the URL with the resolved URL in case it was an alias
        Boolean isFolder, wasAliased;
        err = FSResolveAliasFileWithMountFlags(&fileRef, TRUE, &isFolder, &wasAliased, kARMNoUI);
        
        // wasAliased is false for symlinks, but use the resolved alias anyway
        if (noErr == err)
            *aURL = [(id)CFURLCreateFromFSRef(NULL, &fileRef) autorelease];
    }
    
    return drawBadge;
}
    
+ (id)iconWithURL:(NSURL *)representedURL size:(NSSize)iconSize;
{
    // CFURLGetFSRef won't like a nil URL
    NSParameterAssert(nil != representedURL);
    
    NSString *scheme = [representedURL scheme];
    
    // initWithURLScheme requires a scheme, so there's not much we can do without it
    if ([representedURL isEqual:missingFileURL] || nil == scheme) {
        return [[[FVFinderIcon allocWithZone:[self zone]] initWithFinderIconOfURL:nil] autorelease];
    }
    else if (NO == [representedURL isFileURL]) {
        return [[[FVWebViewIcon allocWithZone:[self zone]] initWithURL:representedURL] autorelease];
    }
    
    OSStatus err = noErr;
    
    FSRef fileRef;
    
    // convert to an FSRef without resolving symlinks, to get the UTI of the actual URL
    const UInt8 *fsPath = (void *)[[representedURL path] UTF8String];
    err = FSPathMakeRefWithOptions(fsPath, kFSPathMakeRefDoNotFollowLeafSymlink, &fileRef, NULL);
    
    // return missing file icon if we can't convert the path to an FSRef
    if (noErr != err)
        return [[[FVFinderIcon allocWithZone:[self zone]] initWithFinderIconOfURL:nil] autorelease];    
    
    // kLSItemContentType returns a CFStringRef, according to the header
    CFStringRef theUTI = NULL;
    if (noErr == err)
        err = LSCopyItemAttribute(&fileRef, kLSRolesAll, kLSItemContentType, (CFTypeRef *)&theUTI);
            
    // For a link/alias, get the target's UTI in order to determine which concrete subclass to create.  Subclasses that are file-based need to check the URL to see if it should be badged using _shouldDrawBadgeForURL, and then call _resolvedURLWithURL in order to actually load the file's content.
    
    // aliases and symlinks are kUTTypeResolvable, so the alias manager should handle either of them
    if (NULL != theUTI && UTTypeConformsTo(theUTI, kUTTypeResolvable)) {
        Boolean isFolder, wasAliased;
        err = FSResolveAliasFileWithMountFlags(&fileRef, TRUE, &isFolder, &wasAliased, kARMNoUI);
        // don't change the UTI if it couldn't be resolved; in that case, we should just show a finder icon
        if (noErr == err) {
            CFRelease(theUTI);
            theUTI = NULL;
            err = LSCopyItemAttribute(&fileRef, kLSRolesAll, kLSItemContentType, (CFTypeRef *)&theUTI);
        }
    }
    
    FVIcon *anIcon = nil;
        
    // Problems here.  TextMate claims a lot of plain text types but doesn't declare a UTI for any of them, so I end up with a dynamic UTI, and Spotlight ignores the files.  That's broken behavior on TextMate's part, and it sucks for my purposes.
    if ((NULL == theUTI) && [FVTextIcon canInitWithURL:representedURL]) {
        anIcon = [[FVTextIcon allocWithZone:[self zone]] initWithTextAtURL:representedURL];
    }
    else if (UTTypeConformsTo(theUTI, kUTTypePDF)) {
        anIcon = [[FVPDFIcon allocWithZone:[self zone]] initWithPDFAtURL:representedURL];
    }
    else if (UTTypeConformsTo(theUTI, CFSTR("com.adobe.postscript"))) {
        anIcon = [[FVPDFIcon allocWithZone:[self zone]] initWithPostscriptAtURL:representedURL];
    }
    else if (UTTypeConformsTo(theUTI, CFSTR("net.sourceforge.skim-app.pdfd"))) {
        anIcon = [[FVPDFIcon allocWithZone:[self zone]] initWithPDFDAtURL:representedURL];
    }
    else if (UTTypeConformsTo(theUTI, kUTTypeImage)) {
        anIcon = [[FVCGImageIcon allocWithZone:[self zone]] initWithImageAtURL:representedURL];
    }
    else if (UTTypeConformsTo(theUTI, kUTTypeMovie)) {
        anIcon = [[FVCGImageIcon allocWithZone:[self zone]] initWithQTMovieAtURL:representedURL];
    }
    else if (UTTypeConformsTo(theUTI, kUTTypeHTML)) {
        anIcon = [[FVWebViewIcon allocWithZone:[self zone]] initWithURL:representedURL];
    }
    else if ([FVTextIcon canInitWithUTI:(NSString *)theUTI]) {
        anIcon = [[FVTextIcon allocWithZone:[self zone]] initWithTextAtURL:representedURL];
    }
    else if (Nil != FVQLIconClass) {
        anIcon = [[FVQLIconClass allocWithZone:[self zone]] initWithURL:representedURL];
    }
    
    // In case some subclass returns nil, fall back to Quick Look.  If disabled, it returns nil.
    if (nil == anIcon && Nil != FVQLIconClass)
        anIcon = [[FVQLIconClass allocWithZone:[self zone]] initWithURL:representedURL];
    
    // In case all subclasses failed, fall back to a Finder icon.
    if (nil == anIcon)
        anIcon = [[FVFinderIcon allocWithZone:[self zone]] initWithFinderIconOfURL:representedURL];
        
    [(id)theUTI release];
    
    return [anIcon autorelease];    
}

// we only want to encode the public superclass
- (Class)classForCoder { return FVIconClass; }

// we want NSPortCoder to default to bycopy
- (id)replacementObjectForPortCoder:(NSPortCoder *)encoder
{
    return [encoder isByref] ? (id)[NSDistantObject proxyWithLocal:self connection:[encoder connection]] : self;
}

- (void)subclassResponsibility:(SEL)selector
{
    [NSException raise:@"FVAbstractClassException" format:[NSString stringWithFormat:@"Abstract class %@ does not implement %@", [self class], NSStringFromSelector(selector)]];
}

// these methods are all required
- (void)drawInRect:(NSRect)dstRect inCGContext:(CGContextRef)context { [self subclassResponsibility:_cmd]; }
// size should only be used for computing an aspect ratio; don't rely on it as a pixel size
- (NSSize)size { [self subclassResponsibility:_cmd]; return NSZeroSize; }
- (void)renderOffscreen { [self subclassResponsibility:_cmd]; }

// trivial description
- (NSString *)description
{
    NSMutableString *desc = [[super description] mutableCopy];
    [desc appendFormat:@" \"%@\"", NSStringFromSize([self size])];
    return [desc autorelease];
}

// implement trivially so these are safe to call on the abstract class
- (void)releaseResources { /* do nothing */ }
- (BOOL)needsRenderForSize:(NSSize)size { return NO; }

// this method is optional; some subclasses may not have a fast path
- (void)fastDrawInRect:(NSRect)dstRect inCGContext:(CGContextRef)context { [self drawInRect:dstRect inCGContext:context]; }

- (void)_drawBadgeInContext:(CGContextRef)context forIconInRect:(NSRect)dstRect
{
    IconRef linkBadge;
    OSStatus err;
    err = GetIconRef(kOnSystemDisk, kSystemIconsCreator, kAliasBadgeIcon, &linkBadge);
    
    // rect needs to be a square, or else the aspect ratio of the arrow is wrong
    // rect needs to be the same size as the full icon, or the scale of the arrow is wrong
    
    // We don't know the size of the actual link arrow (and it changes with the size of dstRect), so fine-tuning the drawing isn't really possible as far as I can see.
    if (noErr == err) {
        PlotIconRefInContext(context, (CGRect *)&dstRect, kAlignBottomLeft, kTransformNone, NULL, kPlotIconRefNormalFlags, linkBadge);
        ReleaseIconRef(linkBadge);
    }
}

// handles centering and aspect ratio, since most of our icons have weird sizes, but they'll be drawn in a square box
- (CGRect)_drawingRectWithRect:(NSRect)iconRect;
{
    NSSize s = [self size];
    
    CGFloat ratio = MIN(NSWidth(iconRect) / s.width, NSHeight(iconRect) / s.height);
    CGRect dstRect = *(CGRect *)&iconRect;
    dstRect.size.width = ratio * s.width;
    dstRect.size.height = ratio * s.height;
    
    CGFloat dx = (iconRect.size.width - dstRect.size.width) / 2;
    CGFloat dy = (iconRect.size.height - dstRect.size.height) / 2;
    dstRect.origin.x += dx;
    dstRect.origin.y += dy;
    
    // don't make the rect integral; the view uses centerScanRect: which handles scaling correctly for resolution independence
    return dstRect;
}

- (void)_drawPlaceholderInRect:(NSRect)dstRect inCGContext:(CGContextRef)context
{
    NSGraphicsContext *nsContext = [NSGraphicsContext graphicsContextWithGraphicsPort:context flipped:YES];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:nsContext];
    [nsContext saveGraphicsState];
    
    // get rid of any existing shadow, since the dashed line looks goofy with a shadow
    NSShadow *aShadow = [[NSShadow alloc] init];
    [aShadow set];
    
    CGFloat radius = MIN(NSWidth(dstRect) / 4.0, 10.0);
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundRect:dstRect xRadius:radius yRadius:radius];
    [path setLineWidth:2.0];
    CGFloat pattern[2] = { 12.0, 6.0 };
    
    [path setLineDash:pattern count:2 phase:0.0];
    [[NSColor lightGrayColor] setStroke];
    [path stroke];
    [nsContext restoreGraphicsState];
    [aShadow release];
    
    [NSGraphicsContext restoreGraphicsState];
}

- (NSUInteger)pageCount { return 1; }
- (NSUInteger)currentPageIndex { return 1; }
- (void)showNextPage { /* do nothing */ }
- (void)showPreviousPage { /* do nothing */ }

@end

static char * FVCreateCStringWithInode(ino_t n)
{
    // LONG_MAX on x86_64 is 9223372036854775807, so 40 chars should be sufficient
    char temp[40];
    sprintf(temp,"%ld", (long)n);
    return strdup(temp);   
}

FV_PRIVATE_EXTERN char * FVCreateDiskCacheNameWithURL(NSURL *aURL)
{
    NSCParameterAssert(nil != aURL);
#if DEBUG
    // this is a much more useful name for debugging, but it's slower and breaks if the name changes
    return strdup([[aURL absoluteString] fileSystemRepresentation]);
#endif
    char *name = NULL;
    if ([aURL isFileURL]) {
        struct stat sb;
        if (0 == stat([[aURL path] fileSystemRepresentation], &sb))
            name = FVCreateCStringWithInode(sb.st_ino);
    }
    else {
        name = strdup([[aURL absoluteString] fileSystemRepresentation]);
    }
    return name;
}


@interface NSBezierPath (Leopard)
+ (NSBezierPath*)bezierPathWithRoundedRect:(NSRect)rect xRadius:(CGFloat)xRadius yRadius:(CGFloat)yRadius;
@end

@implementation NSBezierPath (RoundRect)

+ (NSBezierPath*)bezierPathWithRoundRect:(NSRect)rect xRadius:(CGFloat)xRadius yRadius:(CGFloat)yRadius;
{    
    if ([self respondsToSelector:@selector(bezierPathWithRoundedRect:xRadius:yRadius:)])
        return [self bezierPathWithRoundedRect:rect xRadius:xRadius yRadius:yRadius];
    
    // Make sure radius doesn't exceed a maximum size to avoid artifacts:
    CGFloat mr = MIN(NSHeight(rect), NSWidth(rect));
    CGFloat radius = MIN(xRadius, 0.5f * mr);
    
    // Make sure silly values simply lead to un-rounded corners:
    if( radius <= 0 )
        return [self bezierPathWithRect:rect];
    
    NSRect innerRect = NSInsetRect(rect, radius, radius); // Make rect with corners being centers of the corner circles.
	static NSBezierPath *path = nil;
    if(path == nil)
        path = [[self bezierPath] retain];
    
    [path removeAllPoints];    
    
    // Now draw our rectangle:
    [path moveToPoint: NSMakePoint(NSMinX(innerRect) - radius, NSMinY(innerRect))];
    
    // Bottom left (origin):
    [path appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(innerRect), NSMinY(innerRect)) radius:radius startAngle:180.0 endAngle:270.0];
    // Bottom edge and bottom right:
    [path appendBezierPathWithArcWithCenter:NSMakePoint(NSMaxX(innerRect), NSMinY(innerRect)) radius:radius startAngle:270.0 endAngle:360.0];
    // Left edge and top right:
    [path appendBezierPathWithArcWithCenter:NSMakePoint(NSMaxX(innerRect), NSMaxY(innerRect)) radius:radius startAngle:0.0  endAngle:90.0 ];
    // Top edge and top left:
    [path appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(innerRect), NSMaxY(innerRect)) radius:radius startAngle:90.0  endAngle:180.0];
    // Left edge:
    [path closePath];
    
    return path;
}
@end


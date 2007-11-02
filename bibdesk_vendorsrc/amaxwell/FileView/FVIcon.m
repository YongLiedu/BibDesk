//
//  FVIcon.m
//  FileViewTest
//
//  Created by Adam Maxwell on 08/31/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "FVIcon.h"
#import "FVCGImageIcon.h"
#import "FVFinderIcon.h"
#import "FVPDFIcon.h"
#import "FVTextIcon.h"
#import "FVQLIcon.h"
#import <sys/stat.h>

#pragma mark -
#pragma mark FVIcon abstract class

// FVIcon abstract class stuff
static FVIcon *defaultPlaceholderIcon = nil;
static Class FVIconClass = Nil;
static Class FVQLIconClass = Nil;

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

+ (id)iconWithPath:(NSString *)absolutePath size:(NSSize)iconSize;
{
    // guaranteed to be a filesystem path or NSNull, so we can use fileURLWithPath:
    NSURL *representedURL = nil;
    if (absolutePath && NO == [absolutePath isEqual:(id)[NSNull null]])
        representedURL = [NSURL fileURLWithPath:absolutePath];
    return [self iconWithURL:representedURL size:iconSize];
}

+ (id)iconWithURL:(NSURL *)representedURL size:(NSSize)iconSize;
{
    // special case for nil URL, since CFURLGetFSRef won't like it
    if (nil == representedURL || [representedURL isEqual:[NSNull null]]) {
        return [[[FVFinderIcon allocWithZone:[self zone]] initWithFinderIconOfURL:nil ofSize:iconSize] autorelease];
    }
    else if (NO == [representedURL isFileURL]) {
        return [[[FVFinderIcon allocWithZone:[self zone]] initWithURLScheme:[representedURL scheme] ofSize:iconSize] autorelease];
    }
    
    OSStatus err = noErr;
    
    FSRef fileRef;
    
    // return missing file icon if we can't resolve the path
    if (FALSE == CFURLGetFSRef((CFURLRef)representedURL, &fileRef))
        return [[[FVFinderIcon allocWithZone:[self zone]] initWithFinderIconOfURL:nil ofSize:iconSize] autorelease];
    
    // kLSItemContentType returns a CFStringRef, according to the header
    CFStringRef theUTI = NULL;
    if (noErr == err)
        err = LSCopyItemAttribute(&fileRef, kLSRolesAll, kLSItemContentType, (CFTypeRef *)&theUTI);
    
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
    else if (UTTypeConformsTo(theUTI, kUTTypeImage)) {
        anIcon = [[FVCGImageIcon allocWithZone:[self zone]] initWithImageAtURL:representedURL];
    }
    else if (UTTypeConformsTo(theUTI, kUTTypeMovie)) {
        anIcon = [[FVCGImageIcon allocWithZone:[self zone]] initWithQTMovieAtURL:representedURL];
    }
    else if (UTTypeConformsTo(theUTI, kUTTypeText)) {
        anIcon = [[FVTextIcon allocWithZone:[self zone]] initWithTextAtURL:representedURL];
    }
    else if (UTTypeConformsTo(theUTI, CFSTR("public.composite-content")) && [FVTextIcon canInitWithURL:representedURL]) {
        // note that public.composite-content has to come after kUTTypePDF, which also conforms to it
        anIcon = [[FVTextIcon allocWithZone:[self zone]] initWithTextAtURL:representedURL];
    }
    else if (Nil != FVQLIconClass) {
        anIcon = [[FVQLIconClass allocWithZone:[self zone]] initWithURL:representedURL];
    }
    
    if (nil == anIcon)
        anIcon = [[FVFinderIcon allocWithZone:[self zone]] initWithFinderIconOfURL:representedURL ofSize:iconSize];
    
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

- (NSUInteger)pageCount { return 1; }
- (NSUInteger)currentPageIndex { return 1; }
- (void)showNextPage { /* do nothing */ }
- (void)showPreviousPage { /* do nothing */ }

@end

static char * FVCreateCStringWithInode(ino_t n)
{
    char temp[40];
    sprintf(temp,"%d",n);
    return strdup(temp);   
}

FV_PRIVATE_EXTERN char * FVCreateDiskCacheNameWithURL(NSURL *fileURL)
{
#if DEBUG
    // this is a much more useful name for debugging, but it's slower and not unique
    NSCParameterAssert([fileURL isFileURL]);
    return strdup([[fileURL path] fileSystemRepresentation]);
#endif
    struct stat sb;
    char *name = NULL;
    if (0 == stat([[fileURL path] fileSystemRepresentation], &sb)) { 
        name = FVCreateCStringWithInode(sb.st_ino);
    }
    return name;
}


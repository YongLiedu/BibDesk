//
//  FVScaledImageView.m
//  FileView
//
//  Created by Adam Maxwell on 09/22/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "FVScaledImageView.h"
#import "FVIcon.h"

@implementation FVScaledImageView

static NSDictionary *__textAttributes = nil;

+ (void)initialize {
    NSMutableDictionary *ta = [NSMutableDictionary dictionary];
    [ta setObject:[NSFont systemFontOfSize:[NSFont systemFontSize]] forKey:NSFontAttributeName];
    [ta setObject:[NSColor darkGrayColor] forKey:NSForegroundColorAttributeName];
    NSMutableParagraphStyle *ps = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    [ps setAlignment:NSCenterTextAlignment];
    [ta setObject:ps forKey:NSParagraphStyleAttributeName];
    [ps release];
    __textAttributes = [ta copy];
}

- (void)addBox
{
    if (nil == _box) {
        _box = [[NSBox alloc] initWithFrame:NSInsetRect([self frame], 17.0f, 17.0f)];
        [_box setTitlePosition:NSNoTitle];
        [_box setBoxType:NSBoxPrimary];
        [self addSubview:_box];
        [_box setAutoresizingMask:(NSViewWidthSizable|NSViewHeightSizable)];
    }
}

- (void)makeText
{
    NSMutableAttributedString *fileDescription = [[NSMutableAttributedString alloc] initWithString:[[NSFileManager defaultManager] displayNameAtPath:[_fileURL path]]];
    [fileDescription addAttributes:__textAttributes range:NSMakeRange(0, [fileDescription length])];
    [fileDescription addAttribute:NSFontAttributeName value:[NSFont boldSystemFontOfSize:[NSFont systemFontSize]] range:NSMakeRange(0, [fileDescription length])];
    
    MDItemRef mdItem = MDItemCreate(NULL, (CFStringRef)[_fileURL path]);
    NSDictionary *mdAttributes = nil;
    if (NULL != mdItem) {
        mdAttributes = [(id)MDItemCopyAttributeList(mdItem, kMDItemKind, kMDItemPixelHeight, kMDItemPixelWidth) autorelease];
        CFRelease(mdItem);
    }
    
    if (nil != mdAttributes) {
        NSMutableAttributedString *kindString = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"\n\n%@", [mdAttributes objectForKey:(id)kMDItemKind]] attributes:__textAttributes];
        if ([mdAttributes objectForKey:(id)kMDItemPixelHeight] && [mdAttributes objectForKey:(id)kMDItemPixelWidth])
            [[kindString mutableString] appendFormat:NSLocalizedString(@"\n%@ by %@ pixels", @"two string format specifiers"), [mdAttributes objectForKey:(id)kMDItemPixelWidth], [mdAttributes objectForKey:(id)kMDItemPixelHeight]];
        [fileDescription appendAttributedString:kindString];
        [kindString release];
    }
    
    NSDictionary *fattrs = [[NSFileManager defaultManager] fileAttributesAtPath:[_fileURL path] traverseLink:NO];
    if (fattrs) {
        NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
        [formatter setFormatterBehavior:NSDateFormatterBehavior10_4];
        [formatter setDateStyle:NSDateFormatterLongStyle];
        [formatter setTimeStyle:NSDateFormatterMediumStyle];
        
        unsigned long long fsize = [[fattrs objectForKey:NSFileSize] longLongValue];
        CGFloat mbsize = fsize / 1024.0f;
        NSString *label = @"KB";
        if (mbsize > 1024.0f) {
            mbsize /= 1024.0f;
            label = @"MB";
        }
        if (mbsize > 1024.0f) {
            mbsize /= 1024.0f;
            label = @"GB";
        }
        NSMutableAttributedString *details = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:NSLocalizedString(@"\n\nSize: %.1f %@\nCreated: %@\nModified: %@", @""), mbsize, label, [formatter stringFromDate:[fattrs objectForKey:NSFileCreationDate]], [formatter stringFromDate:[fattrs objectForKey:NSFileModificationDate]]] attributes:__textAttributes];
        [details addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]] range:NSMakeRange(0, [details length])];
        [fileDescription appendAttributedString:details];
        [details release];
    }
    [_text autorelease];
    _text = fileDescription;
}

- (void)dealloc
{
    [_icon release];
    [_box release];
    [_text release];
    [super dealloc];
}

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    [self addBox];
    return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    [self addBox];
    return self;
}

- (void)setIcon:(FVIcon *)anIcon
{
    [_icon autorelease];
    _icon = [anIcon retain];
}

- (void)setFileURL:(NSURL *)aURL
{
    [_fileURL autorelease];
    _fileURL = [aURL copy];
}

- (void)displayIconForURL:(NSURL *)aURL
{
    [self setFileURL:aURL];
    [self setIcon:[FVIcon iconWithURL:aURL size:[self bounds].size]];
    [self makeText];
}

- (void)displayImageAtURL:(NSURL *)aURL;
{
    [self setFileURL:aURL];
    [self setIcon:[FVIcon iconWithURL:aURL size:[self bounds].size]];
    [_text autorelease];
    _text = nil;
}

- (void)viewDidEndLiveResize;
{
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)aRect
{
    [super drawRect:aRect];
    
    CGContextRef ctxt = [[NSGraphicsContext currentContext] graphicsPort];
    if ([_icon needsRenderForSize:aRect.size])
        [_icon renderOffscreen];
    
    aRect = NSInsetRect([self bounds], 25, 25);
    NSRect iconRect = aRect;
    
    // originally was drawing text for all types, but QL just displays the image
    if (nil != _text) {
        NSRect textRect;
        NSDivideRect(aRect, &iconRect, &textRect, NSWidth(aRect) / 2, NSMinXEdge);
        
        // draw text before messing with the graphics state
        NSRect boundRect = [_text boundingRectWithSize:textRect.size options:NSStringDrawingUsesLineFragmentOrigin];
        if (NSWidth(boundRect) < NSWidth(textRect)) {
            CGFloat delta = NSWidth(textRect) - NSWidth(boundRect);
            textRect.origin.x += delta;
            textRect.size.width -= delta;
            iconRect.size.width += delta;
        }
        textRect.origin.y = textRect.origin.y - (NSHeight(textRect) - NSHeight(boundRect)) / 2;
        [_text drawWithRect:textRect options:NSStringDrawingUsesLineFragmentOrigin];
    }
    
    // always antialias the text
    if ([self inLiveResize]) {
        CGContextSetShouldAntialias(ctxt, false);
        CGContextSetInterpolationQuality(ctxt, kCGInterpolationNone);
    }
    else {
        CGContextSetShouldAntialias(ctxt, true);
        CGContextSetInterpolationQuality(ctxt, kCGInterpolationHigh);
    }     
    [_icon drawInRect:NSInsetRect(iconRect, 5.0f, 5.0f) inCGContext:ctxt];
    
}

@end

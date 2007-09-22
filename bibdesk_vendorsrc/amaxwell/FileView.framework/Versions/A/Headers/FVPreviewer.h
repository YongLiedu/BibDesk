//
//  FVPreviewer.h
//  FileViewTest
//
//  Created by Adam Maxwell on 09/01/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>
#import <QTKit/QTKit.h>
#import <WebKit/WebKit.h>

@class FVScaledImageView;

@interface FVPreviewer : NSWindowController {
    IBOutlet QTMovieView       *movieView;
    IBOutlet PDFView           *pdfView;
    IBOutlet NSImageView       *imageView;
    IBOutlet NSScrollView      *textView;
    IBOutlet WebView           *webView;
    IBOutlet FVScaledImageView *fvImageView;
    NSProgressIndicator        *spinner;
    
    NSTask                     *qlTask;
}
+ (void)previewURL:(NSURL *)absoluteURL;
+ (BOOL)isPreviewing;
@end

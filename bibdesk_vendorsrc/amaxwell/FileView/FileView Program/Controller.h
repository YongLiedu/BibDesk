//
//  Controller.h
//  FileViewTest
//
//  Created by Adam Maxwell on 06/23/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <FileView/FileView.h>

@interface Controller : NSObject {
    IBOutlet NSWindow *_window;
    IBOutlet FileView *_fileView;
    NSMutableArray *_filePaths;
    IBOutlet NSSlider *_slider;
    IBOutlet NSArrayController *arrayController;
}

@end

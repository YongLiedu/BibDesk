//
//  BDSKBibTeXImporter.h
//  bd2xtest
//
//  Created by Michael McCracken on 1/18/06.
//  Copyright 2006 Michael McCracken. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class BDSKDocument;
#import "BDSKBibTeXParser.h"
#import "BDSKDataModelNames.h"

@interface BDSKBibTeXImporter : NSObject {
    IBOutlet NSView *view;    
    NSString *fileName;
}

+ (BDSKBibTeXImporter *)sharedImporter;

+ (NSDictionary *)defaultSettings;


- (NSDictionary *)settings;

- (NSView *)view;

#pragma mark import action

- (NSError *)importIntoDocument:(BDSKDocument *)document
                       userInfo:(NSDictionary *)userInfo;

#pragma mark UI actions
- (IBAction)chooseFileName:(id)sender;

#pragma mark UI KVO stuff

- (NSImage *)fileIcon;

@end

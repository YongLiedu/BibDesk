//
//  BDSKBibTeXImporter.m
//  bd2xtest
//
//  Created by Michael McCracken on 1/18/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "BDSKBibTeXImporter.h"
#import "BDSKDocument.h"

static BDSKBibTeXImporter *sharedImporter = nil;

@implementation BDSKBibTeXImporter

+ (void)initialize{
    [self setKeys:[NSArray arrayWithObjects:@"fileName", nil] triggerChangeNotificationsForDependentKey:@"fileIcon"];
}


+ (BDSKBibTeXImporter *)sharedImporter{
    if(sharedImporter == nil)
        sharedImporter = [[BDSKBibTeXImporter alloc] init];
    return sharedImporter;
}


- (id)init{
    return [self initWithSettings:[BDSKBibTeXImporter defaultSettings]];
}


- (id)initWithSettings:(NSDictionary *)newSettings{
    self = [super init];
    if(self){
        fileName = [[newSettings objectForKey:@"fileName"] retain];
    }
    return self;
}


- (void)dealloc{
    [fileName release];
    [super dealloc];
}

#pragma mark settings UI and configuration

+ (NSDictionary *)defaultSettings{
    return [NSDictionary dictionary]; //probably want to load this from a plist.
    // candidates for default settings are text encodings, etc.
}

- (NSDictionary *)settings{
    NSDictionary *settings = [NSDictionary dictionaryWithObjectsAndKeys:fileName, @"fileName", nil];
    return settings; 
}

- (NSView *)view{
    if(!view){
        [NSBundle loadNibNamed:@"BDSKBibTeXImporter" owner:self];
    }
    return view;
}


#pragma mark import action

- (NSError *)importIntoDocument:(BDSKDocument *)doc
                       userInfo:(NSDictionary *)userInfo{
    
    NSLog(@"importIntoDocument %@ with fileName %@", doc, fileName);

    NSData *data = [NSData dataWithContentsOfFile:fileName];
    NSError *error = nil;
    [BDSKBibTeXParser itemsFromData:data error:&error document:doc];

    return nil;
}


#pragma mark UI actions

- (IBAction)chooseFileName:(id)sender{
    // open file chooser
    
    NSOpenPanel *op = [NSOpenPanel openPanel];
    [op runModalForDirectory:nil
                        file:@""];
    
    [self setValue:[[[op filenames] objectAtIndex:0] retain] forKey:@"fileName"];
}


#pragma mark UI KVO stuff

- (NSImage *)fileIcon{
    
    if(fileName){
        return [[NSWorkspace sharedWorkspace] iconForFile:fileName];
    }else{
        return nil;
    }
}

@end

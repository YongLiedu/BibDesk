//
//  BDSKSkimReader.h
//  Bibdesk
//
//  Created by Adam Maxwell on 04/09/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface BDSKSkimReader : NSObject {
    NSConnection *connection;
}

+ (id)sharedReader;
- (NSData *)RTFNotesAtURL:(NSURL *)fileURL;
- (NSString *)textNotesAtURL:(NSURL *)fileURL;

@end

//
//  BDSKFilePathCell.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 3/10/09.
/*
 This software is Copyright (c) 2009-2011
 Christiaan Hofman. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Christiaan Hofman nor the names of any
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

#import "BDSKFilePathCell.h"
#import "NSImage_BDSKExtensions.h"
#import "NSFileManager_BDSKExtensions.h"


@implementation BDSKFilePathCell

+ (Class)formatterClass {
    return [BDSKFilePathFormatter class];
}

@end

#pragma mark -

@implementation BDSKFilePathFormatter

- (NSImage *)imageForObjectValue:(id)obj {
    NSImage *image = nil;
    if ([(id)obj isKindOfClass:[NSString class]]) {
        NSString *path = [(NSString *)obj stringByStandardizingPath];
        if(path && [[NSFileManager defaultManager] fileExistsAtPath:path])
            image = [[NSWorkspace sharedWorkspace] iconForFile:path];
    } else if ([(id)obj isKindOfClass:[NSURL class]]) {
        NSURL *fileURL = (NSURL *)obj;
        if([[NSFileManager defaultManager] objectExistsAtFileURL:fileURL])
            image = [NSImage imageForURL:fileURL];
    }
    return image;
}

- (NSString *)stringForObjectValue:(id)obj {
    NSString *path = [obj isKindOfClass:[NSURL class]] ? [obj path] : [obj description];
    return [path stringByAbbreviatingWithTildeInPath];
}

// this won't be used because we never edit in this cell type
- (NSString *)editingStringForObjectValue:(id)obj {
    return [obj isKindOfClass:[NSURL class]] ? [obj path] : [obj description];
}

// this won't be used because we never edit in this cell type
- (BOOL)getObjectValue:(id *)obj forString:(NSString *)string errorDescription:(NSString **)error {
    *obj = [string stringByExpandingTildeInPath];
    return YES;
}

@end

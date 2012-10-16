//
//  NSPasteboard_BDSKExtensions.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 10/13/12.
/*
 This software is Copyright (c) 2012
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

#import "NSPasteboard_BDSKExtensions.h"
#import "NSSet_BDSKExtensions.h"
#import "BDSKStringParser.h"
#import "WebURLsWithTitles.h"
#import "NSURL_BDSKExtensions.h"

#define WebURLsWithTitlesPboardType @"WebURLsWithTitlesPboardType"
#define BDSKPasteboardTypeURLName @"public.url-name"

// Dummy subclass for reading from pasteboard
// Reads public.url before public.file-url, unlike NSURL, so it gets the target URL for webloc/fileloc files rather than its file location
// Don't use for anything else
@interface BDSKURL : NSURL
@end

@implementation BDSKURL

+ (id)allocWithZone:(NSZone *)zone {
    return [NSURL allocWithZone:zone];
}

+ (NSArray *)readableTypesForPasteboard:(NSPasteboard *)pasteboard {
    return [NSArray arrayWithObjects:(NSString *)kUTTypeURL, (NSString *)kUTTypeFileURL, nil];
}

@end

#pragma mark -

@implementation NSPasteboard (BDSKExtensions)

- (BOOL)writeURLs:(NSArray *)URLs names:(NSArray *)names {
    NSMutableArray *items = [NSMutableArray array];
    NSUInteger i, urlCount = [URLs count], namesCount = [names count];
    
    for (i = 0; i < urlCount; i++) {
        
        NSURL *theURL = [URLs objectAtIndex:i];
        CFDataRef utf8Data = (CFDataRef)[[theURL absoluteString] dataUsingEncoding:NSUTF8StringEncoding];
        NSString *name = i < namesCount ? [names objectAtIndex:i] : nil;
        NSPasteboardItem *item = [[[NSPasteboardItem alloc] init] autorelease];
        
        [item setString:[theURL absoluteString] forType:(NSString *)([theURL isFileURL] ? kUTTypeFileURL : kUTTypeURL)];
        [item setString:[theURL absoluteString] forType:NSPasteboardTypeString];
        if (i < namesCount)
            [item setString:[names objectAtIndex:i] forType:BDSKPasteboardTypeURLName];
        
        [items addObject:item];
    }
    
    if ([items count] > 0)
        if ([self writeObjects:items]) {
            Class WebURLsWithTitlesClass = NSClassFromString(@"WebURLsWithTitles");
            if (urlCount == namesCount && [[self pasteboardItems] count] == urlCount &&
                WebURLsWithTitlesClass != Nil && [WebURLsWithTitlesClass respondsToSelector:@selector(writeURLs:andTitles:toPasteboard:)]) {
                // This uses the old NSPasteboard API, which writes to the first pasteboard item
                // writeURLs:andTitles:toPasteboard: checks explicitly for WebURLsWithTitlesPboardType, so we need to add it first
                [self addTypes:[NSArray arrayWithObjects:WebURLsWithTitlesPboardType, nil] owner:nil];
                [WebURLsWithTitlesClass writeURLs:URLs andTitles:names toPasteboard:self];
            }
            return YES;
        }
    return NO;
}

- (NSArray *)readURLNames {
    Class WebURLsWithTitlesClass = NSClassFromString(@"WebURLsWithTitles");
    if ([self canReadItemWithDataConformingToTypes:[NSArray arrayWithObjects:WebURLsWithTitlesPboardType, nil]] &&
        WebURLsWithTitlesClass != Nil && [WebURLsWithTitlesClass respondsToSelector:@selector(titlesFromPasteboard:)]) {
        return [WebURLsWithTitlesClass titlesFromPasteboard:self];
    } else if ([self canReadItemWithDataConformingToTypes:[NSArray arrayWithObject:BDSKPasteboardTypeURLName]]) {
        NSMutableArray *names = [NSMutableArray array];
        for (NSPasteboardItem *item in [self pasteboardItems]) {
            NSString *name = [item stringForType:BDSKPasteboardTypeURLName];
            if (name)
                [names addObject:name];
        }
        if ([names count] > 0)
            return names;
    }
    return nil;
}

static inline BOOL fileConformsToTypes(NSString *filename, NSArray *types) {
    NSWorkspace *ws = [NSWorkspace sharedWorkspace];
    NSString *fileType = [ws typeOfFile:filename error:NULL];
    for (NSString *type in types) {
        if ([ws type:fileType conformsToType:type])
            return YES;
    }
    return NO;
}

- (BOOL)canReadFileURLOfTypes:(NSArray *)types {
    if ([self canReadObjectForClasses:[NSArray arrayWithObject:[NSURL class]] options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSPasteboardURLReadingFileURLsOnlyKey, types, NSPasteboardURLReadingContentsConformToTypesKey, nil]])
        return YES;
    if ([[self types] containsObject:NSFilenamesPboardType]) {
        if (types == nil)
            return YES;
        for (NSString *filename in [self propertyListForType:NSFilenamesPboardType]) {
            if (fileConformsToTypes([filename stringByExpandingTildeInPath], types))
                return YES;
        }
    }
    return NO;
}

- (NSArray *)readFileURLsOfTypes:(NSArray *)types {
    NSArray *fileURLs = [self readObjectsForClasses:[NSArray arrayWithObject:[NSURL class]] options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSPasteboardURLReadingFileURLsOnlyKey, types, NSPasteboardURLReadingContentsConformToTypesKey, nil]];
    if ([fileURLs count] == 0 && [[self types] containsObject:NSFilenamesPboardType]) {
        NSArray *filenames = [self propertyListForType:NSFilenamesPboardType];
        if ([filenames count]  > 0) {
            NSMutableArray *files = [NSMutableArray array];
            for (NSString *filename in filenames) {
                filename = [filename stringByExpandingTildeInPath];
                if (types == nil || fileConformsToTypes(filename, types))
                    [files addObject:[NSURL fileURLWithPath:filename]];
            }
            if ([files count] > 0)
                fileURLs = files;
        }
    }
    return fileURLs;
}

- (BOOL)canReadURL {
    return [self canReadObjectForClasses:[NSArray arrayWithObject:[BDSKURL class]] options:[NSDictionary dictionary]] ||
           [self canReadItemWithDataConformingToTypes:[NSArray arrayWithObjects:NSURLPboardType, NSFilenamesPboardType, nil]];
}

- (NSArray *)readURLs {
    NSArray *URLs = [self readObjectsForClasses:[NSArray arrayWithObject:[BDSKURL class]] options:[NSDictionary dictionary]];
    if ([URLs count] == 0) {
        NSString *type = [self availableTypeFromArray:[NSArray arrayWithObjects:NSURLPboardType, NSFilenamesPboardType, nil]];
        if ([type isEqualToString:NSURLPboardType]) {
            URLs = [NSArray arrayWithObjects:[NSURL URLFromPasteboard:self], nil];
        } else if ([type isEqualToString:NSFilenamesPboardType]) {
            NSArray *filenames = [self propertyListForType:NSFilenamesPboardType];
            if ([filenames count]  > 0) {
                NSMutableArray *files = [NSMutableArray array];
                for (NSString *filename in filenames)
                    [files addObject:[NSURL fileURLWithPath:[filename stringByExpandingTildeInPath]]];
                URLs = files;
            }
        }
    }
    return URLs;
}

@end

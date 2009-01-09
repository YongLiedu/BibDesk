/*
 This software is Copyright (c) 2007-2009
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

#import <Foundation/Foundation.h>
#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>
#import "BDSKSyntaxHighlighter.h"

/* -----------------------------------------------------------------------------
   Generate a preview for file

   This function's job is to create preview for designated file
   ----------------------------------------------------------------------------- */

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options)
{
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    
    OSStatus err = noErr;
    
    if (UTTypeEqual(CFSTR("net.sourceforge.bibdesk.bdskcache"), contentTypeUTI)) {
        
        CFBundleRef bundle = QLPreviewRequestGetGeneratorBundle(preview);
        CFURLRef templateURL = CFBundleCopyResourceURL(bundle, CFSTR("BibDeskQuickLook"), CFSTR("html"), NULL);
        NSString *path = templateURL ? (NSString *)CFURLCopyFileSystemPath(templateURL, kCFURLPOSIXPathStyle) : nil;

        if (templateURL) CFRelease(templateURL);
        
        if (nil == path) {
            [pool release];
            return fnfErr;
        }
        
        NSMutableString *string = [[NSMutableString alloc] initWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
        [path release];
        
        NSMutableDictionary *mdItem = [[NSMutableDictionary alloc] initWithContentsOfURL:(NSURL *)url];
        
        // if we don't have a URL, show something useful (this is multivalued, but it uses the fallback case)
        NSArray *whereFrom = [mdItem objectForKey:(NSString *)kMDItemWhereFroms];
        if ([whereFrom count] == 0)
            [mdItem setObject:@"No URL" forKey:(NSString *)kMDItemWhereFroms];
        
        NSDate *date = [mdItem objectForKey:@"net_sourceforge_bibdesk_publicationdate"];
        if (date) {
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            [formatter setDateStyle:NSDateFormatterLongStyle];
            NSString *dateString = [formatter stringFromDate:date];
            if (dateString)
                [mdItem setObject:dateString forKey:@"net_sourceforge_bibdesk_publicationdate"];
            [formatter release];
        }
        
        NSArray *keys = [mdItem allKeys];
        for (NSString *key in keys) {
            NSRange r = [string rangeOfString:key options:NSLiteralSearch|NSCaseInsensitiveSearch];
            if (r.length) {
                id obj = [mdItem objectForKey:key];
                NSString *value = nil;
                
                if ([key isEqualToString:(NSString *)kMDItemAuthors] && [obj respondsToSelector:@selector(componentsJoinedByString:)])
                    value = [obj componentsJoinedByString:@" and "];
                else if ([key isEqualToString:(NSString *)kMDItemWhereFroms] && [obj respondsToSelector:@selector(lastObject)])
                    value = [obj lastObject];
                else if ([key isEqualToString:@"net_sourceforge_bibdesk_owningfilepath"])
                    value = [[NSURL fileURLWithPath:obj] absoluteString];
                
                // fallback
                if (nil == value)
                    value = [obj description];
                
                // now replace this and future occurrences of the string
                [string replaceOccurrencesOfString:key withString:value options:NSCaseInsensitiveSearch|NSLiteralSearch range:NSMakeRange(r.location, [string length] - r.location)];
            }
        }
            
        NSDictionary *properties = [[NSDictionary alloc] initWithObjectsAndKeys:@"text/html", kQLPreviewPropertyMIMETypeKey, @"utf-8", kQLPreviewPropertyTextEncodingNameKey, nil];
        CFDataRef data = (CFDataRef)[string dataUsingEncoding:NSUTF8StringEncoding];
        if (nil != data) {
            QLPreviewRequestSetDataRepresentation(preview, data, kUTTypeHTML, (CFDictionaryRef)properties);
        } else{
            err = 1;
        }

        [string release];
        [mdItem release];
        [properties release];
        
    } else if (UTTypeConformsTo(contentTypeUTI, kUTTypePlainText)) {
        
        NSStringEncoding usedEncoding;
        NSString *btString = [[NSString alloc] initWithContentsOfURL:(NSURL *)url usedEncoding:&usedEncoding error:NULL];
        if (nil == btString)
            btString = [[NSString alloc] initWithContentsOfURL:(NSURL *)url encoding:[NSString defaultCStringEncoding] error:NULL];
        if (nil == btString)
            btString = [[NSString alloc] initWithContentsOfURL:(NSURL *)url encoding:NSISOLatin1StringEncoding error:NULL];
        
        if (btString) {
            if (UTTypeEqual(CFSTR("org.tug.tex.bibtex"), contentTypeUTI)) {
                CFDataRef data = (CFDataRef)[BDSKSyntaxHighlighter RTFDataWithBibTeXString:btString];
                if (data) {
                    QLPreviewRequestSetDataRepresentation(preview, data, kUTTypeRTF, NULL);
                } else {
                    err = 2;
                }
            }
            else {
                // some other plain text type...
                CFDataRef data = (CFDataRef)[btString dataUsingEncoding:NSUnicodeStringEncoding];
                // encoding must be a CF encoding
                NSNumber *encoding = [NSNumber numberWithUnsignedInteger:CFStringConvertNSStringEncodingToEncoding(NSUnicodeStringEncoding)];
                NSDictionary *properties = [[NSDictionary alloc] initWithObjectsAndKeys:encoding, kQLPreviewPropertyStringEncodingKey, nil];
                if (data) {
                    QLPreviewRequestSetDataRepresentation(preview, data, kUTTypePlainText, (CFDictionaryRef)properties);
                } else {
                    err = 2;
                }
                [properties release]; 
            }
                
            [btString release];
        } else {
            err = 3;
        }
    }

    
    [pool release];
    
    return err;
}

void CancelPreviewGeneration(void* thisInterface, QLPreviewRequestRef preview)
{
    // implement only if supported
}

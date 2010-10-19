//
//  BDSKBibDeskProtocol.m
//  Bibdesk
//
//  Created by Sven-S. Porst on 12.04.09.
/*
 This software is Copyright (c) 2009-2010
 Sven-S. Porst. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 - Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in
 the documentation and/or other materials provided with the
 distribution.
 
 - Neither the name of Sven-S. Porst nor the names of any
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

/* 
	Mostly nicked from Apple's PictureBrowser example project.
*/

#import "BDSKBibDeskProtocol.h"
#import "BDSKWebParser.h"
#import "NSString_BDSKExtensions.h"
#import "NSURL_BDSKExtensions.h"
#import "NSArray_BDSKExtensions.h"
#import "NSImage_BDSKExtensions.h"
#import <WebKit/WebView.h>
#import "BDSKTemplateParser.h"
#import "BDSKDownloadManager.h"

#define WEBGROUP_SPECIFIER  @"webgroup"
#define DOWNLOADS_SPECIFIER @"downloads"
#define FILEICON_SPECIFIER  @"fileicon:"
#define HELP_SPECIFIER      @"help"
#define HELP_DIRECTORY      @"BibDeskHelp"
#define HELP_START_FILE     @"BibDeskHelp.html"

NSString *BDSKBibDeskScheme = @"bibdesk";
NSURL *BDSKBibDeskWebGroupURL = nil;

@implementation BDSKBibDeskProtocol

+ (void)initialize {
    BDSKINITIALIZE;
    BDSKBibDeskWebGroupURL = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"%@:%@", BDSKBibDeskScheme, WEBGROUP_SPECIFIER]];
}

/*
 Only accept the bibdesk:webgroup URL.
*/
+ (BOOL)canInitWithRequest:(NSURLRequest *)theRequest {
	return [[[theRequest URL] scheme] caseInsensitiveCompare:BDSKBibDeskScheme] == NSOrderedSame;
}



+(NSURLRequest *) canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}



/*
 Immediately provide the requested data.
*/ 
- (void)startLoading {
    id<NSURLProtocolClient> client = [self client];
    NSURLRequest *request = [self request];
    NSURL *theURL = [request URL];
    NSString *resourceSpecifier = [theURL resourceSpecifier];
	
    if ([WEBGROUP_SPECIFIER caseInsensitiveCompare:resourceSpecifier] == NSOrderedSame) {
        NSData *data = [self welcomeHTMLData];
        NSURLResponse *response = [[NSURLResponse alloc] initWithURL:[request URL] MIMEType:@"text/html" expectedContentLength:[data length] textEncodingName:@"utf-8"];
        [client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
        [client URLProtocol:self didLoadData:data];
        [client URLProtocolDidFinishLoading:self];
        [response release];
    } else if ([DOWNLOADS_SPECIFIER caseInsensitiveCompare:resourceSpecifier] == NSOrderedSame) {
        NSData *data = [self downloadsHTMLData];
        NSURLResponse *response = [[NSURLResponse alloc] initWithURL:[request URL] MIMEType:@"text/html" expectedContentLength:[data length] textEncodingName:@"utf-8"];
        [client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
        [client URLProtocol:self didLoadData:data];
        [client URLProtocolDidFinishLoading:self];
        [response release];
    } else if ([resourceSpecifier hasCaseInsensitivePrefix:FILEICON_SPECIFIER]) {
        NSString *extension = [resourceSpecifier substringFromIndex:[FILEICON_SPECIFIER length]];
        NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFileType:extension];
        NSSize size = NSMakeSize(32.0, 32.0);
        if (NSEqualSizes([icon size], size) == NO) {
            NSImage *tmp = [[[NSImage alloc] initWithSize:size] autorelease];
            [tmp lockFocus];
            [icon drawInRect:NSMakeRect(0.0, 0.0, 32.0, 32.0) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0]; 
            [tmp unlockFocus];
            icon = tmp;
        }
        NSData *data = [icon TIFFRepresentation];
        NSURLResponse *response = [[NSURLResponse alloc] initWithURL:[request URL] MIMEType:@"image/tiff" expectedContentLength:[data length] textEncodingName:@"utf-8"];
        [client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
        [client URLProtocol:self didLoadData:data];
        [client URLProtocolDidFinishLoading:self];
        [response release];
    } else if ([HELP_SPECIFIER caseInsensitiveCompare:[[resourceSpecifier pathComponents] firstObject]] == NSOrderedSame) {
        // when there's no "//" the URL we get has percent escapes including in particular the # character, which would we don't want
        NSString *URLString = [NSString stringWithFormat:@"%@://%@", BDSKBibDeskScheme, [resourceSpecifier stringByReplacingPercentEscapes]];
        NSURLResponse *response = [[NSURLResponse alloc] initWithURL:theURL MIMEType:@"text/html" expectedContentLength:-1 textEncodingName:nil];
        NSURLRequest *redirectRequest = [[NSURLRequest alloc] initWithURL:[NSURL URLWithStringByNormalizingPercentEscapes:URLString]];
        [client URLProtocol:self wasRedirectedToRequest:redirectRequest redirectResponse:response];
        [client URLProtocolDidFinishLoading:self];
        [response release];
        [redirectRequest release];
    } else if ([HELP_SPECIFIER caseInsensitiveCompare:[theURL host]] == NSOrderedSame) {
        NSString *path = [theURL path];
        if ([path hasPrefix:@"/"])
            path = [path substringFromIndex:1];
        if ([path length] == 0)
            path = HELP_START_FILE;
        path = [[NSBundle mainBundle] pathForResource:[[path lastPathComponent] stringByDeletingPathExtension] ofType:[path pathExtension] inDirectory:[HELP_DIRECTORY stringByAppendingPathComponent:[path stringByDeletingLastPathComponent]]];
        if (path) {
            NSData *data = [NSData dataWithContentsOfFile:path];
            NSString *theUTI = [[NSWorkspace sharedWorkspace] typeOfFile:path error:NULL];
            NSString *MIMEType = (NSString *)UTTypeCopyPreferredTagWithClass((CFStringRef)theUTI, kUTTagClassMIMEType);
            NSURLResponse *response = [[NSURLResponse alloc] initWithURL:theURL MIMEType:MIMEType expectedContentLength:[data length] textEncodingName:nil];
            [client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
            [client URLProtocol:self didLoadData:data];
            [client URLProtocolDidFinishLoading:self];
            [response release];
            [MIMEType release];
        } else {
            [client URLProtocol:self didFailWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorFileDoesNotExist userInfo:nil]];
        }
    } else {
        [client URLProtocol:self didFailWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorUnsupportedURL userInfo:nil]];
    }
}



- (void)stopLoading {}



#pragma mark Create Information Web page

/*
 Loads web page template from resource file, inserts links to the web sites known by the available parser classes and returns the resulting HTML code as UTF-8 encoded data.
*/
- (NSData *) welcomeHTMLData {
	static NSData *data = nil;
    if (data == nil) {
        NSString *templateStringPath = [[NSBundle mainBundle] pathForResource:@"WebGroupStartPage" ofType:@"html"];
        NSString *templateString = [NSString stringWithContentsOfFile:templateStringPath encoding:NSUTF8StringEncoding error:NULL];
        NSMutableArray *publicParsers = [NSMutableArray array];
        NSMutableArray *subscriptionParsers = [NSMutableArray array];
        NSMutableArray *genericParsers = [NSMutableArray array];
        
        for (NSDictionary *info in [BDSKWebParser parserInfos]) {
            switch ([[info objectForKey:@"feature"] unsignedIntegerValue]) {
                case BDSKParserFeaturePublic:
                    [publicParsers addObject:info];
                    break;
                case BDSKParserFeatureSubscription:
                    [subscriptionParsers addObject:info];
                    break;
                case BDSKParserFeatureGeneric:
                    [genericParsers addObject:info];
                    break;
                default:
                    break;
            }
        }
        
        NSDictionary *parsers = [NSDictionary dictionaryWithObjectsAndKeys:publicParsers, @"publicParsers", subscriptionParsers, @"subscriptionParsers", genericParsers, @"genericParsers", nil];
        NSString *string = [BDSKTemplateParser stringByParsingTemplateString:templateString usingObject:parsers];
        
        data = [[string dataUsingEncoding:NSUTF8StringEncoding] copy];
    }
    return data;
}

- (NSData *) downloadsHTMLData {
    NSString *templateStringPath = [[NSBundle mainBundle] pathForResource:@"WebGroupDownloads" ofType:@"html"];
    NSString *templateString = [NSString stringWithContentsOfFile:templateStringPath encoding:NSUTF8StringEncoding error:NULL];
    NSString *string = [BDSKTemplateParser stringByParsingTemplateString:templateString usingObject:[BDSKDownloadManager sharedManager]];
    return [[string dataUsingEncoding:NSUTF8StringEncoding] copy];
}

@end

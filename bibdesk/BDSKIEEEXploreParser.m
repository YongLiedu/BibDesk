//
//  BDSKIEEEXploreParser.m
//
//  Created by Michael O. McCracken on 9/26/07.
/*
 This software is Copyright (c) 2007-2009
 Michael O. McCracken. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Michael O. McCracken nor the names of any
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

#import "BDSKIEEEXploreParser.h"
#import <WebKit/WebKit.h>
#import "BibItem.h"
#import "BDSKBibTeXParser.h"
#import "NSError_BDSKExtensions.h"
#import "NSArray_BDSKExtensions.h"
#import <AGRegex/AGRegex.h>

// sometimes the link says AbstractPlus, sometimes it only says Abstract. This should catch both:
static NSString *containsAbstractPlusLinkNode = @"//a[contains(lower-case(text()),'abstract')]";
static NSString *abstractPageURLPath = @"/xpls/abs_all.jsp";
static NSString *searchResultPageURLPath = @"/search/srchabstract.jsp";

@interface _BDSKIEEEDownload : NSObject <NSCopying>
{
@private
    NSURLConnection *_connection;
    NSURLRequest    *_request;
    NSURL           *_pdfLinkURL;
    BOOL             _failed;
    NSError         *_error;
    NSMutableData   *_result;
    id               _delegate;
}

// private runloop mode to avoid other callouts on the main thread (will also cause beachball if needed)
+ (NSString *)runloopMode;
- (id)initWithRequest:(NSURLRequest *)request delegate:(id)delegate;
- (void)start;

@property (nonatomic, copy) NSURL *pdfLinkURL;

// not KVO compliant, but that doesn't matter here
@property (nonatomic, readonly) BOOL failed;
@property (nonatomic, readonly) NSURL *URL;
@property (nonatomic, readonly) NSError *error;
@property (nonatomic, readonly) NSData *result;

@end


static NSMutableArray *_activeDownloads = nil;
static NSMutableArray *_finishedDownloads = nil;

@implementation BDSKIEEEXploreParser

+ (void)initialize
{
    if ([BDSKIEEEXploreParser class] == self) {
        _activeDownloads = [NSMutableArray new];
        _finishedDownloads = [NSMutableArray new];
    }
}

+ (BOOL)canParseDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url{
    
    if (! [[url host] isEqualToString:@"ieeexplore.ieee.org"]){
        return NO;
    }
        
	bool isOnAbstractPage     = [[url path] isEqualToString:abstractPageURLPath];
	bool isOnSearchResultPage = [[url path] isEqualToString:searchResultPageURLPath];
    
    NSError *error = nil;    

    bool nodecountisok =  [[[xmlDocument rootElement] nodesForXPath:containsAbstractPlusLinkNode error:&error] count] > 0;

    return nodecountisok || isOnAbstractPage || isOnSearchResultPage;
}


+ (NSString *)ARNumberFromURLSubstring:(NSString *)urlPath error:(NSError **)outError{
	
	AGRegex * ARNumberRegex = [AGRegex regexWithPattern:@"arnumber=([0-9]+)" options:AGRegexMultiline];
	AGRegexMatch *match = [ARNumberRegex findInString:urlPath];
	if([match count] == 0 && outError){
		*outError = [NSError localErrorWithCode:0 localizedDescription:NSLocalizedString(@"missingARNumberKey", @"Can't get an ARNumber from the URL")];

		return NULL;
	}
	return [match groupAtIndex:1];
}

+ (NSString *)ISNumberFromURLSubstring:(NSString *)urlPath error:(NSError **)outError{
	
	AGRegex * ISNumberRegex = [AGRegex regexWithPattern:@"isnumber=([0-9]+)" options:AGRegexMultiline];
	AGRegexMatch *match = [ISNumberRegex findInString:urlPath];
	if([match count] == 0 && outError){
		*outError = [NSError localErrorWithCode:0 localizedDescription:NSLocalizedString(@"missingISNumberKey", @"Can't get an ISNumber from the URL")];
		
		return NULL;
	}
	return [match groupAtIndex:1];
}

+ (void)downloadFinishedOrFailed:(_BDSKIEEEDownload *)download;
{
    if ([download failed] == NO)
        [_finishedDownloads addObject:download];
    [_activeDownloads removeObject:download];
}

+ (void)enqueueAbstractPageDownloadForURL:(NSURL *)url
{
    NSError *error;

    NSString *arnumberString = [self ARNumberFromURLSubstring:[url query] error:&error];
    NSString *isnumberString = [self ISNumberFromURLSubstring:[url query] error:&error];
    
    
    // Query IEEEXplore with a POST request	
    
    NSString * serverName = [[url host] lowercaseString];
    
    NSString * URLString = [NSString stringWithFormat:@"http://%@/xpls/citationAct", serverName];
    
    NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:URLString]];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-type"];
    
    // note, do not actually url-encode this. they are expecting their angle brackets raw.
    NSString * queryString = [NSString stringWithFormat:@"dlSelect=cite_abs&fileFormate=BibTex&arnumber=<arnumber>%@</arnumber>", arnumberString];
    
    [request setHTTPBody:[queryString dataUsingEncoding:NSUTF8StringEncoding]];
    
    _BDSKIEEEDownload *download = [[_BDSKIEEEDownload alloc] initWithRequest:request delegate:self];
    
    NSString * arnumberURLString = [NSString stringWithFormat:@"http://ieeexplore.ieee.org/xpls/abs_all.jsp?tp=&arnumber=%@&isnumber=%@", arnumberString, isnumberString];
    
    // stash this away since we have arnumber and isnumber here, and the download won't have the correct URL
    [download setPdfLinkURL:[NSURL URLWithString:arnumberURLString]];
    
    [_activeDownloads addObject:download];
    [download release];
    [download start];
}

+ (NSArray *)itemsFromDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url error:(NSError **)outError{
	
    /*
    
     http://ieeexplore.ieee.org/search/srchabstract.jsp?arnumber=4723961&isnumber=4723954&punumber=4711036&k2dockey=4723961@ieeecnfs&query=%28%28pegasus+on+the+virtual+grid%29%3Cin%3Emetadata%29&pos=0&access=no
		
     http://ieeexplore.ieee.org/xpls/abs_all.jsp?isnumber=4723954&arnumber=4723958&count=9&index=3
     
	 http://ieeexplore.ieee.org/search/srchabstract.jsp?arnumber=928956&isnumber=20064&punumber=7385&k2dockey=928956@ieeecnfs&query=%28%28planning+deformable+objects%29%3Cin%3Emetadata%29&pos=0&access=no
     
     http://ieeexplore.ieee.org/search/searchresult.jsp?history=yes&queryText=%28%28sediment+transport%29%3Cin%3Emetadata%29
     
     */
        
		 NSError *error = nil;    
    NSMutableArray *items = [NSMutableArray arrayWithCapacity:0];
		
    if ([[url path] isEqualToString:abstractPageURLPath] == NO && [[url path] isEqualToString:searchResultPageURLPath] == NO) {
    
        // parse all links on a TOC page

		 NSArray *AbstractPlusLinkNodes = [[xmlDocument rootElement] nodesForXPath:containsAbstractPlusLinkNode
																			error:&error];  
		
		if ([AbstractPlusLinkNodes count] < 1) {
			if (outError) *outError = error;
			return nil;
		}
		
		NSUInteger i, count = [AbstractPlusLinkNodes count];
		 for (i = 0; i < count; i++) {
		 NSXMLNode *aplinknode = [AbstractPlusLinkNodes objectAtIndex:i];
		 NSString *hrefValue = [aplinknode stringValueOfAttribute:@"href"];
			NSURL *abstractPageURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@%@", [url host], hrefValue]];
			
            [self enqueueAbstractPageDownloadForURL:abstractPageURL];
		}
		
	}
    else {

        // already on the abstract page
        [self enqueueAbstractPageDownloadForURL:url];
}

    // wait for all those downloads to finish
    while ([_activeDownloads count])
        CFRunLoopRunInMode((CFStringRef)[_BDSKIEEEDownload runloopMode], 0.3, FALSE);

    // copy and clear _finishedDownloads, since we'll be enqueuing more right away
    NSArray *finishedDownloads = [[_finishedDownloads copy] autorelease];
    [_finishedDownloads removeAllObjects];

    // need to associate subsequent PDF link downloads with their BibItem
    NSMutableDictionary *downloadItemTable = [NSMutableDictionary dictionary];
	_BDSKIEEEDownload *download;
    
    for (download in finishedDownloads) {
	
        // download failure
        if ([download failed]) {
            NSString *errMsg = [[download error] localizedDescription];
            if (nil == errMsg)
                errMsg = NSLocalizedString(@"Download from IEEEXplore failed.", @"error message");
            NSDictionary *pubFields = [NSDictionary dictionaryWithObject:errMsg forKey:BDSKTitleString];
            BibItem *errorItem = [[BibItem alloc] initWithType:BDSKMiscString fileType:BDSKBibtexString citeKey:nil pubFields:pubFields isNew:YES];
            [items addObject:errorItem];
            [errorItem release];

            continue;
	}
	
    /*
     Use NSAttributedString to unescape XML entities
	 For example: http://ieeexplore.ieee.org/xpls/abs_all.jsp?isnumber=4977283&arnumber=4977305&count=206&index=11
	 has a (tm) as an entity.

     http://ieeexplore.ieee.org/search/srchabstract.jsp?arnumber=259629&isnumber=6559&punumber=16&k2dockey=259629@ieeejrns&query=%28%28moll%29%3Cin%3Emetadata%29&pos=1&access=no
     has smart quotes and a Greek letter (converted) and <sub> and <sup> (which are lost).
     Using stringByConvertingHTMLToTeX will screw up too much stuff here, so that's not really an option.
     */
	
        NSAttributedString * attrString = [[[NSAttributedString alloc] initWithHTML:[download result] options:nil documentAttributes:NULL] autorelease];
        NSString * bibTeXString = [[attrString string] stringByCollapsingAndTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

	BOOL isPartialData;
        NSArray * newPubs = [BDSKBibTeXParser itemsFromString:bibTeXString document:nil isPartialData:&isPartialData error: &error];
	
        BibItem *newPub = [newPubs firstObject];
	
        // parse failure
        if (nil == newPub) {
            NSDictionary *pubFields = [NSDictionary dictionaryWithObject:[error localizedDescription] forKey:BDSKTitleString];
            BibItem *errorItem = [[BibItem alloc] initWithType:BDSKMiscString fileType:BDSKBibtexString citeKey:nil pubFields:pubFields isNew:YES];
            [items addObject:errorItem];
            [errorItem release];
            
            continue;
	}
	
        // enqueue a download to get the PDF URL, if possible:
        NSURLRequest *request = [NSURLRequest requestWithURL:[download pdfLinkURL]];
        download = [[_BDSKIEEEDownload alloc] initWithRequest:request delegate:self];
        [_activeDownloads addObject:download];
        [download release];
        [download start];
        [downloadItemTable setObject:newPub forKey:download];

        [items addObject:newPub];

	}
    
    // download all the PDF link documents
    while ([_activeDownloads count])
        CFRunLoopRunInMode((CFStringRef)[_BDSKIEEEDownload runloopMode], 0.3, FALSE);
    
    for (_BDSKIEEEDownload *download in _finishedDownloads) {
                            
        if ([download failed])
            continue;
        
        NSXMLDocument *linkDocument = nil;
        linkDocument = [[NSXMLDocument alloc] initWithData:[download result] options:NSXMLDocumentTidyHTML error:NULL];
        NSArray *pdfLinkNodes = [[linkDocument rootElement] nodesForXPath:@"//a[contains(text(), 'PDF')]" error:NULL];
    if ([pdfLinkNodes count] > 0){
        NSXMLNode *pdfLinkNode = [pdfLinkNodes objectAtIndex:0];
        NSString *hrefValue = [pdfLinkNode stringValueOfAttribute:@"href"];
        
            NSString *pdfURLString = [NSString stringWithFormat:@"http://%@%@", [[download URL] host], hrefValue];
        
            [[downloadItemTable objectForKey:download] setField:BDSKUrlString toValue:pdfURLString];
    }
        [linkDocument release];
    }
    [_finishedDownloads removeAllObjects];
	
	return items;
	
}

@end
	
#pragma mark Download delegate

@implementation _BDSKIEEEDownload

@synthesize pdfLinkURL = _pdfLinkURL;
@synthesize failed = _failed;
@synthesize error = _error;
@synthesize result = _result;

+ (NSString *)runloopMode { return @"_BDSKRunLoopModeIEEEDownload"; }

- (id)initWithRequest:(NSURLRequest *)request delegate:(id)delegate
{
    self = [super init];
    if (self) {
        _request = [request copy];
        _delegate = delegate;
}
    return self;
}

- (void)dealloc
{
    [_connection release];
    [_request release];
    [_error release];
    [_result release];
    [_pdfLinkURL release];
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)aZone { return [self retain]; }

- (NSURL *)URL { return [_request URL]; }

- (void)start
{
    NSParameterAssert(nil == _connection);
    NSParameterAssert(nil == _result);
    _result = [NSMutableData new];
    _connection = [[NSURLConnection alloc] initWithRequest:_request delegate:self startImmediately:NO];
    [_connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:[[self class] runloopMode]];
    [_connection start];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    _error = [error retain];
    _failed = YES;
    [_delegate performSelector:@selector(downloadFinishedOrFailed:) withObject:self];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection;
{
    [_delegate performSelector:@selector(downloadFinishedOrFailed:) withObject:self];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data;
{
    [_result appendData:data];
}

@end 

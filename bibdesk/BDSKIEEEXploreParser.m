//
//  BDSKIEEEXploreParser.m
//
//  Created by Michael O. McCracken on 9/26/07.
/*
 This software is Copyright (c) 2007-2011
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
    BDSKINITIALIZE;
    _activeDownloads = [NSMutableArray new];
    _finishedDownloads = [NSMutableArray new];
}

+ (BOOL)canParseDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url{
    
    if (nil == [url host] || NSOrderedSame != [[url host] caseInsensitiveCompare:@"ieeexplore.ieee.org"])
        return NO;
        
	if (NSOrderedSame == [[url path] caseInsensitiveCompare:abstractPageURLPath] || NSOrderedSame == [[url path] caseInsensitiveCompare:searchResultPageURLPath])
        return YES;
    
    return [[[xmlDocument rootElement] nodesForXPath:containsAbstractPlusLinkNode error:NULL] count] > 0;
}


+ (NSString *)ARNumberFromURLSubstring:(NSString *)urlPath error:(NSError **)outError{
	
	AGRegex * ARNumberRegex = [AGRegex regexWithPattern:@"arnumber=([0-9]+)" options:AGRegexMultiline];
	AGRegexMatch *match = [ARNumberRegex findInString:urlPath];
	if([match count] == 0 && outError){
		*outError = [NSError localErrorWithCode:kBDSKWebParserFailed localizedDescription:NSLocalizedString(@"missingARNumberKey", @"Can't get an ARNumber from the URL")];

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
    
    // Query IEEEXplore with a POST request	
    
    NSString * serverName = [[url host] lowercaseString];
    
    NSString * URLString = [NSString stringWithFormat:@"http://%@/xpl/downloadCitations", serverName];
    
    NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:URLString]];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-type"];
    
    // note, do not actually url-encode this. they are expecting their angle brackets raw.
    NSString * queryString = [NSString stringWithFormat:@"recordIds=%@&fromPageName=searchabstract&citations-format=citation-abstract&download-format=download-bibtex", arnumberString];
    
    [request setHTTPBody:[queryString dataUsingEncoding:NSUTF8StringEncoding]];
    
    _BDSKIEEEDownload *download = [[_BDSKIEEEDownload alloc] initWithRequest:request delegate:self];
    
    NSString * arnumberURLString = [NSString stringWithFormat:@"http://ieeexplore.ieee.org/stamp/stamp.jsp?tp=&arnumber=%@", arnumberString];
    
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
    
    if ([[url path] caseInsensitiveCompare:abstractPageURLPath] != NSOrderedSame && [[url path] caseInsensitiveCompare:searchResultPageURLPath] != NSOrderedSame) {
        
        // parse all links on a TOC page
        
        NSArray *abstractPlusLinkNodes = [[xmlDocument rootElement] nodesForXPath:containsAbstractPlusLinkNode error:&error];  
		
		if ([abstractPlusLinkNodes count] < 1) {
			if (nil == abstractPlusLinkNodes && outError) *outError = error;
            else if (outError) *outError = [NSError localErrorWithCode:kBDSKUnknownError localizedDescription:NSLocalizedString(@"Unable to find links", @"")];
			return nil;
		}
		
        for (NSXMLNode *aplinknode in abstractPlusLinkNodes) {
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
    
    for (_BDSKIEEEDownload *download in _finishedDownloads) {
        
        // download failure
        if ([download failed]) {
            NSString *errMsg = [[download error] localizedDescription];
            if (nil == errMsg)
                errMsg = NSLocalizedString(@"Download from IEEEXplore failed.", @"error message");
            NSDictionary *pubFields = [NSDictionary dictionaryWithObject:errMsg forKey:BDSKTitleString];
            BibItem *errorItem = [[BibItem alloc] initWithType:BDSKMiscString citeKey:nil pubFields:pubFields isNew:YES];
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
        NSString * bibTeXString = [[attrString string] stringByCollapsingAndTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        
        /*
         You'd think the IEEE would be able to produce valid BibTeX, but lots of entries have
         crap like "month=jun 1--aug 1" (unquoted).  They can also end a line with a double 
         comma (visible in the downloaded BibTeX, so not my fault).  Either of these causes
         btparse to choke.
         
         Unfortunately, BibTeX itself processes these without warnings, so there's not much
         point in complaining to IEEE.  BibTeX just uses the first simple value and ignores
         the rest.
         */
        NSScanner *scanner = [[NSScanner alloc] initWithString:bibTeXString];
        [scanner setCaseSensitive:NO];
        NSString *scanResult;
        if ([scanner scanUpToString:@"month=" intoString:&scanResult]) {
            [scanner scanString:@"month=" intoString:NULL];
            NSMutableString *fixed = [[scanResult mutableCopy] autorelease];
            if ([scanner scanUpToString:@"," intoString:&scanResult]) {
                [fixed appendFormat:@"month={%@},", scanResult];
                [scanner scanString:@"," intoString:NULL];
                
                // basically want to look for spaces and dashes between fragments; this is a heuristic, not a strict macro charset
                static NSCharacterSet *badSet = nil;
                if (nil == badSet) {
                    NSMutableCharacterSet *cset = [NSMutableCharacterSet characterSetWithRange:NSMakeRange('a', 26)];
                    [cset addCharactersInRange:NSMakeRange('A', 26)];
                    [cset addCharactersInString:@"0123456789"];
                    badSet = [[cset invertedSet] copy];
                }
                // unbraced non-letter
                if ([scanResult rangeOfCharacterFromSet:badSet].length) {
                    [fixed appendString:[[scanner string] substringFromIndex:[scanner scanLocation]]];
                    bibTeXString = fixed;
                }
            }
            else if ([scanner scanString:@"," intoString:NULL]) {
                // empty month, unbraced, which also causes btparse to complain
                [fixed appendString:[[scanner string] substringFromIndex:[scanner scanLocation]]];
                bibTeXString = fixed;
            }
            
            // find and remove ",,\n"
            NSRange doubleCommaRange = [fixed rangeOfString:@",," options:NSLiteralSearch];
            while (doubleCommaRange.length) {
                NSUInteger newlineIndex = NSMaxRange(doubleCommaRange) + 1;
                if (doubleCommaRange.length && newlineIndex < [fixed length] && [[NSCharacterSet newlineCharacterSet] characterIsMember:[fixed characterAtIndex:newlineIndex]]) {
                    [fixed replaceCharactersInRange:doubleCommaRange withString:@","];
                    newlineIndex -= 1;
                }
                doubleCommaRange = [fixed rangeOfString:@",," options:NSLiteralSearch range:NSMakeRange(newlineIndex, [fixed length] - newlineIndex)];
            }
        }
        [scanner release];
        
        BOOL isPartialData;
        NSArray *newPubs = nil;
        if ([NSString isEmptyString:bibTeXString] == NO)
            newPubs = [BDSKBibTeXParser itemsFromString:bibTeXString owner:nil isPartialData:&isPartialData error: &error];
        else
            error = [NSError mutableLocalErrorWithCode:kBDSKUnknownError localizedDescription:NSLocalizedString(@"No data returned from server", @"")];
        
        BibItem *newPub = [newPubs firstObject];
        
        [newPub addFileForURL:[download pdfLinkURL] autoFile:NO runScriptHook:NO];
        
        // parse failure
        if (nil == newPub) {
            NSMutableDictionary *pubFields = [NSMutableDictionary dictionaryWithObject:[error localizedDescription] forKey:BDSKTitleString];
            if ([[download URL] absoluteString])
                [pubFields setObject:[[download URL] absoluteString] forKey:BDSKUrlString];
            if (bibTeXString)
                [pubFields setObject:bibTeXString forKey:BDSKAnnoteString];
            BibItem *errorItem = [[BibItem alloc] initWithType:BDSKMiscString citeKey:nil pubFields:pubFields isNew:YES];
            [items addObject:errorItem];
            [errorItem release];
        } else {
            [items addObject:newPub];
        }
        
	}
    
    [_finishedDownloads removeAllObjects];
	
	return items;
	
}

+ (NSDictionary *)parserInfo {
	NSString * parserDescription = NSLocalizedString(@"IEEE Xplore Library Portal. Searching and browsing are free, but subscription is required for citation importing and full text access",
													 @"Description for IEEE Xplore site.");
	return [BDSKWebParser parserInfoWithName:@"IEEE Xplore"
                                     address:@"http://ieeexplore.ieee.org/" 
                                 description:parserDescription 
                                       feature:BDSKParserFeatureSubscription];
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
    BDSKDESTROY(_connection);
    BDSKDESTROY(_request);
    BDSKDESTROY(_error);
    BDSKDESTROY(_result);
    BDSKDESTROY(_pdfLinkURL);
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
    [_connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
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

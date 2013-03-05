//
//  BDSKDetailViewController.m
//  BibDesk
//
//  Created by Colin A. Smith on 3/3/12.
/*
 This software is Copyright (c) 2012-2012
 Colin A. Smith. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Colin A. Smith nor the names of any
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

#import "BDSKDetailViewController.h"

#import "BibItem.h"
#import "BDSKAppDelegate.h"
#import "BDSKBibDeskURLHandler.h"
#import "BDSKFileStore.h"
#import "BDSKStringConstants_iOS.h"
#import "BDSKTemplate.h"
#import "BDSKTemplateObjectProxy.h"

@interface BDSKDetailViewController () <UIWebViewDelegate, BDSKBibDeskURLHandlerDelegate> {

    NSString *_htmlText;
    NSMutableArray *_linkedFileLocalPaths;
    NSMutableArray *_linkedFileURLs;
    NSMutableDictionary *_linkedFileDisplayedRects;
    NSMutableArray *_webViews;
    UISegmentedControl *_segmentedControl;
    BOOL _loadingHTTP;
}

@property (strong, nonatomic) UIPopoverController *masterPopoverController;
@property (strong, nonatomic) BDSKBibDeskURLHandler *urlHandler;

- (void)configureView;

@end

@implementation BDSKDetailViewController

@synthesize displayedURL = _displayedURL;
@synthesize displayedFile = _displayedFile;
@synthesize masterPopoverController = _masterPopoverController;
@synthesize webView = _webView;

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (_loadingHTTP) [(BDSKAppDelegate *)[UIApplication sharedApplication].delegate hideNetworkActivityIndicator];
    [_htmlText release];
    [_linkedFileLocalPaths release];
    [_linkedFileURLs release];
    [_linkedFileDisplayedRects release];
    for (UIWebView *webView in _webViews) {
        [webView removeObserver:self forKeyPath:@"scrollView.contentSize"];
    }
    [_webViews release];
    [_segmentedControl release];
    [_urlHandler release];
    [_displayedURL release];
    [_displayedFile release];
    [_masterPopoverController release];
    [super dealloc];
}

- (void)awakeFromNib {

    [super awakeFromNib];
    _htmlText = nil;
    _linkedFileLocalPaths = [[NSMutableArray alloc] init];
    _linkedFileURLs = [[NSMutableArray alloc] init];
    _linkedFileDisplayedRects = [[NSMutableDictionary alloc] init];
    _webViews = [[NSMutableArray alloc] init];
    _loadingHTTP = NO;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(storeLinkedFileDisplayedRects) name:UIApplicationDidEnterBackgroundNotification object:nil];
}

#pragma mark - Managing the detail item

- (void)setDisplayedURL:(NSURL *)displayedURL {

    [_displayedFile release];
    _displayedFile = nil;
    self.urlHandler = [BDSKBibDeskURLHandler urlHandlerWithURL:displayedURL delegate:self];
    [self.urlHandler startLoad];
}

- (void)setDisplayedFile:(NSString *)newDisplayedFile
{
    [self resetDisplayedData];
    [newDisplayedFile retain];
    [_displayedFile release];
    _displayedFile = newDisplayedFile;

    // Update the view.
    [self configureView];

    if (self.masterPopoverController != nil) {
        [self.masterPopoverController dismissPopoverAnimated:YES];
    }
}

- (void)configureView
{
    // Update the user interface for the detail item.

    if (self.webView) {
        
        if (_webViews.count < 1) {
            [_webViews addObject:self.webView];
            [self.webView addObserver:self forKeyPath:@"scrollView.contentSize" options:NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew context:NULL];
        }
        
        if (self.displayedFile) {
        
            NSURL *url = [NSURL fileURLWithPath:self.displayedFile];
            NSURLRequest *urlRequest = [NSURLRequest requestWithURL:url];
            [self.webView loadRequest:urlRequest];
            self.title = [[self.displayedFile lastPathComponent] stringByDeletingPathExtension];
        
        } else if (_htmlText) {
        
            self.title = nil;
            [self.webView loadHTMLString:_htmlText baseURL:nil];
        }
        
        UIBarButtonItem *barButtonItem = nil;
        [_segmentedControl release];
        _segmentedControl = nil;
            
        if (_linkedFileLocalPaths.count) {
            
            _segmentedControl = [[UISegmentedControl alloc] initWithItems:@[ @"Citation" ]];
            _segmentedControl.segmentedControlStyle = UISegmentedControlStyleBar;
            _segmentedControl.selectedSegmentIndex = 0;
            [_segmentedControl addTarget:self action:@selector(segmentedControlChanged:) forControlEvents:UIControlEventValueChanged];
            
            for (NSUInteger i = 0; i < _linkedFileLocalPaths.count; ++i) {
            
                if (_webViews.count < i+2) {
                    UIWebView *webView = [[UIWebView alloc] initWithFrame:self.webView.frame];
                    webView.autoresizingMask = self.webView.autoresizingMask;
                    webView.delegate = self;
                    webView.scalesPageToFit = YES;
                    [webView addObserver:self forKeyPath:@"scrollView.contentSize" options:NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew context:NULL];
                    [self.view addSubview:webView];
                    [_webViews addObject:webView];
                    [webView release];
                }
                NSURL *url = [NSURL fileURLWithPath:[_linkedFileLocalPaths objectAtIndex:i]];
                NSURLRequest *urlRequest = [NSURLRequest requestWithURL:url];
                UIWebView *webView = [_webViews objectAtIndex:i+1];
                [webView loadRequest:urlRequest];
            
                if (_linkedFileLocalPaths.count == 1) {
                    [_segmentedControl insertSegmentWithTitle:@"File" atIndex:i+1 animated:NO];
                } else {
                    [_segmentedControl insertSegmentWithTitle:[NSString stringWithFormat:@"File %i", i+1] atIndex:i+1 animated:NO];
                }
            }
            
            barButtonItem = [[UIBarButtonItem alloc] initWithCustomView:_segmentedControl];
        }
        
        [self showWebViewAtIndex:0];
        
        self.navigationItem.rightBarButtonItem = barButtonItem;
        [barButtonItem release];
    }
}

- (void)showWebViewAtIndex:(NSUInteger)index {

    _segmentedControl.selectedSegmentIndex = index;
    
    [_webViews enumerateObjectsUsingBlock:^(UIWebView *webView, NSUInteger idx, BOOL *stop) {
        webView.hidden = index != idx;
    }];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self configureView];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (void)viewWillDisappear:(BOOL)animated {

    [self storeLinkedFileDisplayedRects];
    [super viewWillDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
    } else {
        return YES;
    }
}

#pragma mark - Split view delegate methods

- (void)splitViewController:(UISplitViewController *)splitController willHideViewController:(UIViewController *)viewController withBarButtonItem:(UIBarButtonItem *)barButtonItem forPopoverController:(UIPopoverController *)popoverController
{
    barButtonItem.title = NSLocalizedString(@"Publications", @"Publications");
    [self.navigationItem setLeftBarButtonItem:barButtonItem animated:YES];
    self.masterPopoverController = popoverController;
}

- (void)splitViewController:(UISplitViewController *)splitController willShowViewController:(UIViewController *)viewController invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem
{
    // Called when the view is shown again in the split view, invalidating the button and popover controller.
    [self.navigationItem setLeftBarButtonItem:nil animated:YES];
    self.masterPopoverController = nil;
}

#pragma mark - Web view delegate methods

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {

    if (!_loadingHTTP && ([request.URL.scheme isEqualToString:@"http"] || [request.URL.scheme isEqualToString:@"https"])) {
    
        NSString *urlFragment = request.URL.fragment;

        if (urlFragment) {
        
            NSString *url = request.URL.absoluteString;
            url = [url substringToIndex:url.length - (urlFragment.length+1)];
            
            NSString *currentUrlFragment = webView.request.URL.fragment;
            NSString *currentUrl = webView.request.URL.absoluteString;
            if (currentUrlFragment) currentUrl = [currentUrl substringToIndex:currentUrl.length - (currentUrlFragment.length+1)];
            
            if ([url isEqual:currentUrl]) return YES;
        }
        
        _loadingHTTP = YES;
        [(BDSKAppDelegate *)[UIApplication sharedApplication].delegate showNetworkActivityIndicator];
    }
    
    return YES;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {

    if (_loadingHTTP && ([webView.request.URL.scheme isEqualToString:@"http"] || [webView.request.URL.scheme isEqualToString:@"https"])) {
    
        _loadingHTTP = NO;
        [(BDSKAppDelegate *)[UIApplication sharedApplication].delegate hideNetworkActivityIndicator];
    }
    
    NSUInteger index = [_webViews indexOfObject:webView];
    //NSLog(@"UIWebView %i didFinishLoad", index);
    if (_htmlText == nil || index >= 1) {
        if (_htmlText) index--;
        NSURL *url = _linkedFileURLs[index];
        NSString *urlString = url.absoluteString;
        NSDictionary *displayedRects = [self keyValueStoreObjectForKey:BDSKLinkedFileDisplayedRectsKey];
        NSDictionary *displayedRectDict = [displayedRects objectForKey:urlString];
        if (displayedRectDict) {
            [_linkedFileDisplayedRects setObject:displayedRectDict forKey:urlString];
        }
    }
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {

    if (_loadingHTTP && ([webView.request.URL.scheme isEqualToString:@"http"] || [webView.request.URL.scheme isEqualToString:@"https"])) {
    
        _loadingHTTP = NO;
        [(BDSKAppDelegate *)[UIApplication sharedApplication].delegate hideNetworkActivityIndicator];
    }
}


#pragma mark - URL handler delegate methods

- (void)urlHandlerUpdated:(BDSKBibDeskURLHandler *)urlHandler {

    if (urlHandler.bibItems.count) {
    
        BibItem *firstBibItem = [urlHandler.bibItems objectAtIndex:0];
    
        NSString *defaultTemplatePath = [[NSBundle mainBundle] pathForResource:@"DefaultTemplate.html" ofType:nil];
	
        NSString *templateString = [NSString stringWithContentsOfFile:defaultTemplatePath encoding:NSASCIIStringEncoding error:nil];
    
        BDSKTemplate *template = [BDSKTemplate templateWithString:templateString fileType:@"html"];
        
        [self resetDisplayedData];
        
        _htmlText = [BDSKTemplateObjectProxy stringByParsingTemplate:template withObject:[firstBibItem owner] publications:urlHandler.bibItems];
        [_htmlText retain];
        
        if (urlHandler.bibItems.count == 1) {
        
            for (BDSKLinkedFile *linkedFile in firstBibItem.localFiles) {
            
                NSString *linkedFilePath = [urlHandler.fileStore pathForLinkedFilePath:linkedFile.relativePath relativeToBibFileName:urlHandler.bibFileName];
                if ([urlHandler.fileStore availabilityForLinkedFilePath:linkedFilePath] == Available) {
                    
                    [_linkedFileLocalPaths addObject:[urlHandler.fileStore localPathForLinkedFilePath:linkedFilePath]];
                    NSURL *url = [urlHandler.fileStore urlForLinkedFilePath:linkedFilePath];
                    [_linkedFileURLs addObject:url];
                }
            }
        }
    }
    
    [self configureView];
    
    if (self.masterPopoverController != nil) {
        [self.masterPopoverController dismissPopoverAnimated:YES];
    }
}


#pragma mark - Key Value Observing

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {

    if ([keyPath isEqualToString:@"scrollView.contentSize"]) {
        
        CGSize oldContentSize = [(NSValue *)[change objectForKey:NSKeyValueChangeOldKey] CGSizeValue];
        CGSize newContentSize = [(NSValue *)[change objectForKey:NSKeyValueChangeNewKey] CGSizeValue];
        if (!CGSizeEqualToSize(oldContentSize, newContentSize)) {
            UIWebView *webView = object;
            NSUInteger index = [_webViews indexOfObject:webView];
            if (_htmlText == nil || index >= 1) {
                if (_htmlText) index--;
                NSURL *url = [_linkedFileURLs objectAtIndex:index];
                NSString *urlString = url.absoluteString;
                NSDictionary *displayedRectDict = [_linkedFileDisplayedRects objectForKey:urlString];
                if (displayedRectDict) {
                    [_linkedFileDisplayedRects removeObjectForKey:urlString];
                    //NSLog(@"LinkedFile %i contentSize width: %f height: %f zoomScale: %f", index, newContentSize.width, newContentSize.height, webView.scrollView.zoomScale);
                    CGRect displayedRect;
                    CGRectMakeWithDictionaryRepresentation((CFDictionaryRef)displayedRectDict, &displayedRect);
                    //NSLog(@"displayedRect: %@", NSStringFromCGRect(displayedRect));
                    CGSize viewSize = webView.scrollView.frame.size;
                    CGSize contentSize = webView.scrollView.contentSize;
                    CGFloat zoomScale = webView.scrollView.zoomScale;
                    CGFloat newZoomScale = zoomScale*viewSize.width/(contentSize.width*displayedRect.size.width);
                    CGSize newContentSize = contentSize;
                    newContentSize.width *= newZoomScale/zoomScale;
                    newContentSize.height *= newZoomScale/zoomScale;
                    CGPoint newContentOffset;
                    newContentOffset.x = floorf(newContentSize.width*displayedRect.origin.x);
                    newContentOffset.y = floorf(MIN(newContentSize.height*displayedRect.origin.y, newContentSize.height-viewSize.height));
                    //NSLog(@"newContentSize width: %f height: %f", newContentSize.width, newContentSize.height);
                    //NSLog(@"newContentOffset x: %f y: %f newZoomScale: %f", newContentOffset.x, newContentOffset.y, newZoomScale);
                    dispatch_async(dispatch_get_main_queue(), ^{
                        webView.scrollView.zoomScale = newZoomScale;
                        webView.scrollView.contentOffset = newContentOffset;
                    });
                }
            }
        }
    }
}


#pragma mark - Other methods

- (IBAction)segmentedControlChanged:(id)sender {

    if (sender == _segmentedControl) {
    
        [self showWebViewAtIndex:_segmentedControl.selectedSegmentIndex];
    }
}

- (void)resetDisplayedData {

    [self storeLinkedFileDisplayedRects];

    [_htmlText release];
    _htmlText = nil;
    [_linkedFileLocalPaths removeAllObjects];
    [_linkedFileURLs removeAllObjects];
    [_linkedFileDisplayedRects removeAllObjects];
}

- (UIWebView *)webViewForLinkedFileIndex:(NSUInteger)index {

    NSUInteger offset = _htmlText ? 1 : 0;
    
    return [_webViews objectAtIndex:index+offset];
}

- (void)storeLinkedFileDisplayedRects {

    if (_linkedFileURLs.count == 0) return;
    
    NSMutableDictionary *displayedRects = [[self keyValueStoreObjectForKey:BDSKLinkedFileDisplayedRectsKey] mutableCopy];
    if (!displayedRects) {
        displayedRects = [[NSMutableDictionary alloc] init];
    }
    
    BOOL needsUpdate = NO;

    for (NSUInteger i = 0; i < _linkedFileURLs.count; ++i) {
        
        UIWebView *webView = [self webViewForLinkedFileIndex:i];
        CGSize viewSize = webView.scrollView.frame.size;
        CGSize contentSize = webView.scrollView.contentSize;
        CGPoint contentOffset = webView.scrollView.contentOffset;
        //CGFloat zoomScale = webView.scrollView.zoomScale;
        
        //NSLog(@"linkedFile: %i", i);
        //NSLog(@"viewSize width: %f height: %f", viewSize.width, viewSize.height);
        //NSLog(@"contentSize width: %f height: %f", contentSize.width, contentSize.height);
        //NSLog(@"contentOffset x: %f y: %f", contentOffset.x, contentOffset.y);
        //NSLog(@"zoomScale: %f", zoomScale);
        
        CGRect displayedRect = CGRectMake(contentOffset.x/contentSize.width, contentOffset.y/contentSize.height, viewSize.width/contentSize.width, viewSize.height/contentSize.height);
        
        if (displayedRect.origin.x != 0 || displayedRect.origin.y != 0 || displayedRect.size.width != 1) {
        
            //NSLog(@"displayed rect: %@ maxX: %f, maxY: %f", NSStringFromCGRect(displayedRect), CGRectGetMaxX(displayedRect), CGRectGetMaxY(displayedRect));
            NSDictionary *displayedRectDict = (NSDictionary *)CGRectCreateDictionaryRepresentation(displayedRect);
            NSURL *url = [_linkedFileURLs objectAtIndex:i];
            [displayedRects setObject:displayedRectDict forKey:url.absoluteString];
            [displayedRectDict release];
            needsUpdate = YES;
        }
    }
    
    if (needsUpdate) {
        [self setKeyValueStoreObject:displayedRects forKey:BDSKLinkedFileDisplayedRectsKey];
    }
    
    [displayedRects release];
}

- (id)keyValueStoreObjectForKey:(id)aKey {

#if TARGET_IPHONE_SIMULATOR
    return [[NSUserDefaults standardUserDefaults] objectForKey:aKey];
#else
    return [[NSUbiquitousKeyValueStore defaultStore] objectForKey:aKey];
#endif
}

- (void)setKeyValueStoreObject:(id)anObject forKey:(NSString *)aKey {

#if TARGET_IPHONE_SIMULATOR
    [[NSUserDefaults standardUserDefaults] setObject:anObject forKey:aKey];
#else
    [[NSUbiquitousKeyValueStore defaultStore] setObject:anObject forKey:aKey];
#endif
}

@end

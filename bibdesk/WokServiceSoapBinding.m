#import "WokServiceSoapBinding.h"
#import "NSData_BDSKExtensions.h"

/* Cookies handling provided by http://en.wikibooks.org/wiki/Programming:WebObjects/Web_Services/Web_Service_Provider */
@implementation WokServiceSoapBinding
+ (NSString *)address
{
	return nil;
}
+ (NSString *)namespaceURI
{
	return nil;
}
+ (id)soapBinding
{
	return [[[self alloc] initWithAddress:[self address] namespaceURI:[self namespaceURI]] autorelease];
}
@synthesize address;
@synthesize namespaceURI;
@synthesize defaultTimeout;
@synthesize logXMLInOut;
@synthesize cookies;
@synthesize authUsername;
@synthesize authPassword;
- (id)init
{
	if((self = [super init])) {
		address = nil;
		namespaceURI = nil;
		cookies = nil;
		defaultTimeout = 10;//seconds
		logXMLInOut = NO;
		synchronousOperationComplete = NO;
	}
	
	return self;
}
- (id)initWithAddress:(NSString *)anAddress namespaceURI:(NSString *)aNamespaceURI
{
	if((self = [self init])) {
		self.address = [NSURL URLWithString:anAddress];
		self.namespaceURI = aNamespaceURI;
	}
	
	return self;
}
- (void)addCookie:(NSHTTPCookie *)toAdd
{
	if(toAdd != nil) {
		if(cookies == nil) cookies = [[NSMutableArray alloc] init];
		[cookies addObject:toAdd];
	}
}
- (WokServiceSoapBindingResponse *)performSynchronousOperation:(WokServiceSoapBindingOperation *)operation
{
	synchronousOperationComplete = NO;
	[operation setDelegate:self];
	[operation start];
	
	// Now wait for response
	NSRunLoop *theRL = [NSRunLoop currentRunLoop];
	
	while (!synchronousOperationComplete && [theRL runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]);
	return operation.response;
}
- (void)performAsynchronousOperation:(WokServiceSoapBindingOperation *)operation delegate:(id<WokServiceSoapBindingResponseDelegate>)responseDelegate
{
	[operation start];
}
- (void)operation:(WokServiceSoapBindingOperation *)operation completedWithResponse:(WokServiceSoapBindingResponse *)response
{
	synchronousOperationComplete = YES;
}
- (NSString *)serializedEnvelopeUsingHeaderElements:(NSDictionary *)headerElements bodyElements:(NSDictionary *)bodyElements
{
	NSXMLElement *root = [NSXMLElement elementWithName:@"soap:Envelope"];
	NSXMLDocument *doc = [NSXMLDocument documentWithRootElement:root];
	
	if (doc == nil) {
		NSLog(@"Error creating the xml document tree");
		return @"";
	}
	
	[root addNamespace:[NSXMLNode namespaceWithName:@"soap" stringValue:@"http://schemas.xmlsoap.org/soap/envelope/"]];
	
	NSXMLNode *ns = nil;
	
	if (self.namespaceURI != nil) {
		ns = [NSXMLNode namespaceWithName:@"ns" stringValue:self.namespaceURI];
		[root addNamespace:ns];
	}
	
	if((headerElements != nil) && ([headerElements count] > 0)) {
		NSXMLElement *headerNode = [NSXMLElement elementWithName:@"soap:Header"];
		[root addChild:headerNode];
		
		for(NSString *key in [headerElements allKeys]) {
			id header = [headerElements objectForKey:key];
			[headerNode addChild:[header XMLNodeWithName:key prefix:[ns name]]];
		}
	}
	
	if((bodyElements != nil) && ([bodyElements count] > 0)) {
		NSXMLElement *bodyNode = [NSXMLElement elementWithName:@"soap:Body"];
		[root addChild:bodyNode];
		
		for(NSString *key in [bodyElements allKeys]) {
			id body = [bodyElements objectForKey:key];
			[bodyNode addChild:[body XMLNodeWithName:key prefix:[ns name]]];
		}
	}
	
	NSString *serializedForm = [doc XMLString];
	
	return serializedForm;
}
- (NSURLRequest *)requestUsingBody:(NSString *)outputBody soapAction:(NSString *)soapAction
{
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.address cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:self.defaultTimeout];
	NSData *bodyData = [outputBody dataUsingEncoding:NSUTF8StringEncoding];
	
	if(cookies != nil) {
		[request setAllHTTPHeaderFields:[NSHTTPCookie requestHeaderFieldsWithCookies:cookies]];
	}
	[request setValue:[[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleNameKey] forHTTPHeaderField:@"User-Agent"];
	[request setValue:soapAction forHTTPHeaderField:@"SOAPAction"];
	[request setValue:@"text/xml; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
	[request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)[bodyData length]] forHTTPHeaderField:@"Content-Length"];
	[request setValue:self.address.host forHTTPHeaderField:@"Host"];
	[request setHTTPMethod:@"POST"];
	// set version 1.1 - how?
	[request setHTTPBody:bodyData];
	if (self.authUsername && self.authPassword) {
		NSString *authString = [[[NSString stringWithFormat:@"%@:%@", self.authUsername, self.authPassword] dataUsingEncoding:NSUTF8StringEncoding] base64String];
		[request setValue:[NSString stringWithFormat:@"Basic %@", authString] forHTTPHeaderField:@"Authorization"];
	}
	
	if(self.logXMLInOut) {
		NSLog(@"OutputHeaders:\n%@", [request allHTTPHeaderFields]);
		NSLog(@"OutputBody:\n%@", outputBody);
	}
	
	return request;
}
- (void) dealloc
{
	[address release];
	[namespaceURI release];
	[cookies release];
	[super dealloc];
}
@end

@implementation WokServiceSoapBindingOperation
@synthesize binding;
@synthesize bodyElements;
@synthesize responseClasses;
@synthesize soapAction;
@synthesize response;
@synthesize delegate;
@synthesize responseData;
@synthesize urlConnection;
- (id)initWithBinding:(WokServiceSoapBinding *)aBinding delegate:(id<WokServiceSoapBindingResponseDelegate>)aDelegate soapAction:(NSString *)aSoapAction bodyElements:(NSDictionary *)aBodyElements responseClasses:(NSDictionary *)aResponseClasses
{
	if ((self = [super init])) {
		self.binding = aBinding;
		self.bodyElements = aBodyElements;
		self.responseClasses = aResponseClasses;
		self.soapAction = aSoapAction;
		response = nil;
		self.delegate = aDelegate;
		self.responseData = nil;
		self.urlConnection = nil;
	}
	
	return self;
}
- (id)initWithBinding:(WokServiceSoapBinding *)aBinding delegate:(id<WokServiceSoapBindingResponseDelegate>)aDelegate bodyElements:(NSDictionary *)aBodyElements responseClasses:(NSDictionary *)aResponseClasses
{
	return [self initWithBinding:aBinding delegate:aDelegate soapAction:@"" bodyElements:aBodyElements responseClasses:aResponseClasses];
}
- (void)main
{
	[response autorelease];
	response = [WokServiceSoapBindingResponse new];
	
	NSMutableDictionary *headerElements = [NSMutableDictionary dictionary];
	
	NSString *operationXMLString = [binding serializedEnvelopeUsingHeaderElements:headerElements bodyElements:bodyElements];
	
	NSURLRequest *request = [binding requestUsingBody:operationXMLString soapAction:self.soapAction];
	
	self.urlConnection = [[[NSURLConnection alloc] initWithRequest:request delegate:self] autorelease];
}
- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
	if ([challenge previousFailureCount] == 0) {
		NSURLCredential *newCredential;
		newCredential=[NSURLCredential credentialWithUser:self.binding.authUsername
												 password:self.binding.authPassword
											  persistence:NSURLCredentialPersistenceForSession];
		[[challenge sender] useCredential:newCredential
			   forAuthenticationChallenge:challenge];
	} else {
		[[challenge sender] cancelAuthenticationChallenge:challenge];
		NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"Authentication Error" forKey:NSLocalizedDescriptionKey];
		NSError *authError = [NSError errorWithDomain:@"Connection Authentication" code:0 userInfo:userInfo];
		[self connection:connection didFailWithError:authError];
	}
}
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)urlResponse
{
	NSHTTPURLResponse *httpResponse;
	if ([urlResponse isKindOfClass:[NSHTTPURLResponse class]]) {
		httpResponse = (NSHTTPURLResponse *) urlResponse;
	} else {
		httpResponse = nil;
	}
	
	if(binding.logXMLInOut) {
		NSLog(@"ResponseStatus: %ld\n", (long)[httpResponse statusCode]);
		NSLog(@"ResponseHeaders:\n%@", [httpResponse allHeaderFields]);
	}
	
	NSMutableArray *cookies = [[NSHTTPCookie cookiesWithResponseHeaderFields:[httpResponse allHeaderFields] forURL:binding.address] mutableCopy];
	
	binding.cookies = cookies;
	[cookies release];
	if ([urlResponse.MIMEType rangeOfString:@"text/xml"].length == 0) {
		NSError *error = nil;
		[connection cancel];
		if ([httpResponse statusCode] >= 400) {
			NSDictionary *userInfo = [NSDictionary dictionaryWithObject:[NSHTTPURLResponse localizedStringForStatusCode:[httpResponse statusCode]] forKey:NSLocalizedDescriptionKey];
				
			error = [NSError errorWithDomain:@"WokServiceSoapBindingResponseHTTP" code:[httpResponse statusCode] userInfo:userInfo];
		} else {
			NSDictionary *userInfo = [NSDictionary dictionaryWithObject:
																[NSString stringWithFormat: @"Unexpected response MIME type to SOAP call:%@", urlResponse.MIMEType]
																													 forKey:NSLocalizedDescriptionKey];
			error = [NSError errorWithDomain:@"WokServiceSoapBindingResponseHTTP" code:1 userInfo:userInfo];
		}
				
		[self connection:connection didFailWithError:error];
  }
}
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	if (responseData == nil) {
		responseData = [data mutableCopy];
	} else {
		[responseData appendData:data];
	}
}
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	if (binding.logXMLInOut) {
		NSLog(@"ResponseError:\n%@", error);
	}
	response.error = error;
	[delegate operation:self completedWithResponse:response];
}
- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	if (responseData != nil && delegate != nil)
	{
		
		if (binding.logXMLInOut) {
			NSLog(@"ResponseBody:\n%@", [[[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding] autorelease]);
		}
		
		NSError *error = nil;
		NSXMLDocument *doc = [[NSXMLDocument alloc] initWithData:responseData options:NSXMLDocumentTidyXML error:&error];
		
		if (doc == nil) {
			NSDictionary *userInfo = [NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"Errors while parsing returned XML: %@", [error localizedDescription]] forKey:NSLocalizedDescriptionKey];
			
			response.error = [NSError errorWithDomain:@"WokServiceSoapBindingResponseXML" code:1 userInfo:userInfo];
		} else {
			NSXMLElement *node = [doc rootElement];
			
			for(node in [node children]) {
				if([node kind] == NSXMLElementKind) {
					
					if([[node localName] isEqualToString:@"Body"]) {
						NSMutableArray *responseBodyParts = [NSMutableArray array];
						
						for(NSXMLElement *bodyNode in [node children]) {
							if([bodyNode kind] == NSXMLElementKind) {
								Class responseClass = [self.responseClasses objectForKey:[bodyNode localName]];
								if(responseClass != nil) {
									id bodyObject = [responseClass deserializeNode:bodyNode];
									//NSAssert1(bodyObject != nil, @"Errors while parsing body %s", [bodyNode name]);
									if (bodyObject != nil) [responseBodyParts addObject:bodyObject];
								}
								else if ([[bodyNode prefix] isEqualToString:[node prefix]] && 
									[[bodyNode localName] isEqualToString:@"Fault"]) {
									WokServiceSoapBinding_fault *bodyObject = [WokServiceSoapBinding_fault deserializeNode:bodyNode];
									//NSAssert1(bodyObject != nil, @"Errors while parsing body %s", [bodyNode name]);
									if (bodyObject != nil) [responseBodyParts addObject:bodyObject];
								}
							}
						}
						
						response.bodyParts = responseBodyParts;
					}
				}
			}
			
			[doc release];
		}
		
		[delegate operation:self completedWithResponse:response];
	}
}
- (void)dealloc
{
	[binding release];
	[bodyElements release];
	[responseClasses release];
	[soapAction release];
	[response release];
	delegate = nil;
	[responseData release];
	[urlConnection release];
	
	[super dealloc];
}
@end

@implementation WokServiceSoapBindingResponse
@synthesize headers;
@synthesize bodyParts;
@synthesize error;
- (id)init
{
	if((self = [super init])) {
		headers = nil;
		bodyParts = nil;
		error = nil;
	}
	
	return self;
}
- (void)dealloc {
	if(headers != nil) [headers release];
	if(bodyParts != nil) [bodyParts release];
	if(error != nil) [error release];	
	[super dealloc];
}
@end

@implementation WokServiceSoapBindingElement
- (NSXMLElement *)XMLNodeWithName:(NSString *)elName prefix:(NSString *)elNSPrefix
{
	if(elNSPrefix != nil && [elNSPrefix length] > 0)
	{
		elName = [NSString stringWithFormat:@"%@:%@", elNSPrefix, elName];
	}
	
	NSXMLElement *node = [NSXMLElement elementWithName:elName];
	
	[self addElementsToNode:node];
	
	return node;
}
- (void)addElementsToNode:(NSXMLElement *)node
{
}
+ (id)deserializeNode:(NSXMLElement *)node
{
	id newObject = [[self new] autorelease];
	
	[newObject deserializeElementsFromNode:node];
	
	return newObject;
}
- (void)deserializeElementsFromNode:(NSXMLElement *)node
{
}
@end

@implementation WokServiceSoapBinding_fault
- (id)init
{
	if((self = [super init])) {
		faultcode = nil;
		faultstring = nil;
		faultactor = nil;
	}
	
	return self;
}
- (void)dealloc
{
	if(faultcode != nil) [faultcode release];
	if(faultstring != nil) [faultstring release];
	if(faultactor != nil) [faultactor release];
	
	[super dealloc];
}
- (void)addElementsToNode:(NSXMLElement *)node
{
	if(self.faultcode!= nil) {
		[node addChild:[self.faultcode XMLNodeWithName:@"faultcode" prefix:nil]];
	}
	if(self.faultstring!= nil) {
		[node addChild:[self.faultstring XMLNodeWithName:@"faultstring" prefix:nil]];
	}
	if(self.faultactor!= nil) {
		[node addChild:[self.faultactor XMLNodeWithName:@"faultactor" prefix:nil]];
	}
}
@synthesize faultcode;
@synthesize faultstring;
@synthesize faultactor;
- (void)deserializeElementsFromNode:(NSXMLElement *)node
{
	for( node in [node children] ) {
		if([node kind] == NSXMLElementKind) {
			if([[node localName] isEqualToString:@"faultcode"]) {
				self.faultcode = [NSString deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"faultstring"]) {
				self.faultstring = [NSString deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"faultactor"]) {
				self.faultactor = [NSString deserializeNode:node];
			}
		}
	}
}
@end

@implementation NSString (WokServiceSoapBindingElement)
- (NSXMLElement *)XMLNodeWithName:(NSString *)elName prefix:(NSString *)elNSPrefix
{
	if(elNSPrefix != nil && [elNSPrefix length] > 0)
	{
		elName = [NSString stringWithFormat:@"%@:%@", elNSPrefix, elName];
	}
	
	return [NSXMLElement elementWithName:elName stringValue:self];
}
+ (NSString *)deserializeNode:(NSXMLElement *)node
{
	return [node stringValue];
}
@end

@implementation NSNumber (WokServiceSoapBindingElement)
- (NSXMLElement *)XMLNodeWithName:(NSString *)elName prefix:(NSString *)elNSPrefix
{
	return [[self stringValue] XMLNodeWithName:elName prefix:elNSPrefix];
}
+ (NSNumber *)deserializeNode:(NSXMLElement *)node
{
	return [NSNumber numberWithInteger:[[NSString deserializeNode:node] integerValue]];
}
@end

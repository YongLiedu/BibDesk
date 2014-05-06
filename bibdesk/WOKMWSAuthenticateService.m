#import "WOKMWSAuthenticateService.h"

@implementation WOKMWSAuthenticateServiceElement
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix
{
	NSString *nodeName = nil;
	if(elNSPrefix != nil && [elNSPrefix length] > 0)
	{
		nodeName = [NSString stringWithFormat:@"%@:%@", elNSPrefix, elName];
	}
	else
	{
		nodeName = elName;
	}
	
	xmlNodePtr node = xmlNewDocNode(doc, NULL, [nodeName xmlCString], NULL);
	
	[self addElementsToNode:node];
	
	return node;
}
- (void)addElementsToNode:(xmlNodePtr)node
{
}
+ (id)deserializeNode:(xmlNodePtr)cur
{
	id newObject = [[self new] autorelease];
	
	[newObject deserializeElementsFromNode:cur];
	
	return newObject;
}
- (void)deserializeElementsFromNode:(xmlNodePtr)cur
{
}
@end

@implementation WOKMWSAuthenticateService_authenticate
@end

@implementation WOKMWSAuthenticateService_authenticateResponse
- (id)init
{
	if((self = [super init])) {
		return_ = nil;
	}
	
	return self;
}
- (void)dealloc
{
	if(return_ != nil) [return_ release];
	
	[super dealloc];
}
- (void)addElementsToNode:(xmlNodePtr)node
{
	if(self.return_!= nil) {
		xmlAddChild(node, [self.return_ xmlNodeForDoc:node->doc elementName:@"return" elementNSPrefix:nil]);
	}
}
@synthesize return_;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur
{
	for( cur = cur->children ; cur != NULL ; cur = cur->next ) {
		if(cur->type == XML_ELEMENT_NODE) {
			if(xmlStrEqual(cur->name, (const xmlChar *) "return")) {
				id newChild = [NSString deserializeNode:cur];
				self.return_ = newChild;
			}
		}
	}
}
@end

@implementation WOKMWSAuthenticateService_closeSession
@end

@implementation WOKMWSAuthenticateService_closeSessionResponse
@end

@implementation WOKMWSAuthenticateService
+ (WOKMWSAuthenticateServiceSoapBinding *)WOKMWSAuthenticateServiceSoapBinding
{
	return [[[WOKMWSAuthenticateServiceSoapBinding alloc] initWithAddress:@"http://search.webofknowledge.com/esti/wokmws/ws/WOKMWSAuthenticate"] autorelease];
}
@end

@implementation WOKMWSAuthenticateServiceSoapBinding
@synthesize address;
@synthesize defaultTimeout;
@synthesize logXMLInOut;
@synthesize cookies;
@synthesize authUsername;
@synthesize authPassword;
- (id)init
{
	if((self = [super init])) {
		address = nil;
		cookies = nil;
		defaultTimeout = 10;//seconds
		logXMLInOut = NO;
		synchronousOperationComplete = NO;
	}
	
	return self;
}
- (id)initWithAddress:(NSString *)anAddress
{
	if((self = [self init])) {
		self.address = [NSURL URLWithString:anAddress];
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
- (WOKMWSAuthenticateServiceSoapBindingResponse *)performSynchronousOperationWithBodyElements:(NSDictionary *)bodyElements
{
	WOKMWSAuthenticateServiceSoapBindingOperation *operation = [[[WOKMWSAuthenticateServiceSoapBindingOperation alloc] initWithBinding:self delegate:self bodyElements:bodyElements] autorelease];
	
	synchronousOperationComplete = NO;
	[operation start];
	
	// Now wait for response
	NSRunLoop *theRL = [NSRunLoop currentRunLoop];
	
	while (!synchronousOperationComplete && [theRL runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]);
	return operation.response;
}
- (void)performAsynchronousOperationWithBodyElements:(NSDictionary *)bodyElements delegate:(id<WOKMWSAuthenticateServiceSoapBindingResponseDelegate>)responseDelegate
{
	WOKMWSAuthenticateServiceSoapBindingOperation *operation = [[[WOKMWSAuthenticateServiceSoapBindingOperation alloc] initWithBinding:self delegate:responseDelegate bodyElements:bodyElements] autorelease];
	
	[operation start];
}
- (void) operation:(WOKMWSAuthenticateServiceSoapBindingOperation *)operation completedWithResponse:(WOKMWSAuthenticateServiceSoapBindingResponse *)response
{
	synchronousOperationComplete = YES;
}
- (WOKMWSAuthenticateServiceSoapBindingResponse *)authenticateUsingParameters:(WOKMWSAuthenticateService_authenticate *)aParameters 
{
	NSDictionary *bodyElements = [NSDictionary dictionaryWithObject:aParameters forKey:@"authenticate"];
	return [self performSynchronousOperationWithBodyElements:bodyElements];
}
- (void)authenticateAsyncUsingParameters:(WOKMWSAuthenticateService_authenticate *)aParameters  delegate:(id<WOKMWSAuthenticateServiceSoapBindingResponseDelegate>)responseDelegate
{
	NSDictionary *bodyElements = [NSDictionary dictionaryWithObject:aParameters forKey:@"authenticate"];
	[self performAsynchronousOperationWithBodyElements:bodyElements delegate:responseDelegate];
}
- (WOKMWSAuthenticateServiceSoapBindingResponse *)closeSessionUsingParameters:(WOKMWSAuthenticateService_closeSession *)aParameters 
{
	NSDictionary *bodyElements = [NSDictionary dictionaryWithObject:aParameters forKey:@"closeSession"];
	return [self performSynchronousOperationWithBodyElements:bodyElements];
}
- (void)closeSessionAsyncUsingParameters:(WOKMWSAuthenticateService_closeSession *)aParameters  delegate:(id<WOKMWSAuthenticateServiceSoapBindingResponseDelegate>)responseDelegate
{
	NSDictionary *bodyElements = [NSDictionary dictionaryWithObject:aParameters forKey:@"closeSession"];
	[self performAsynchronousOperationWithBodyElements:bodyElements delegate:responseDelegate];
}
- (void)sendHTTPCallUsingBody:(NSString *)outputBody soapAction:(NSString *)soapAction forOperation:(WOKMWSAuthenticateServiceSoapBindingOperation *)operation
{
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.address 
																												 cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
																										 timeoutInterval:self.defaultTimeout];
	NSData *bodyData = [outputBody dataUsingEncoding:NSUTF8StringEncoding];
	
	if(cookies != nil) {
		[request setAllHTTPHeaderFields:[NSHTTPCookie requestHeaderFieldsWithCookies:cookies]];
	}
	[request setValue:@"wsdl2objc" forHTTPHeaderField:@"User-Agent"];
	[request setValue:soapAction forHTTPHeaderField:@"SOAPAction"];
	[request setValue:@"text/xml; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
	[request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)[bodyData length]] forHTTPHeaderField:@"Content-Length"];
	[request setValue:self.address.host forHTTPHeaderField:@"Host"];
	[request setHTTPMethod: @"POST"];
	// set version 1.1 - how?
	[request setHTTPBody: bodyData];
    if (self.authUsername && self.authPassword) {
        NSString *authString = [[[NSString stringWithFormat:@"%@:%@", self.authUsername, self.authPassword] dataUsingEncoding:NSUTF8StringEncoding] base64Encoding];        
        [request setValue:[NSString stringWithFormat:@"Basic %@", authString] forHTTPHeaderField:@"Authorization"];
    }
		
	if(self.logXMLInOut) {
		NSLog(@"OutputHeaders:\n%@", [request allHTTPHeaderFields]);
		NSLog(@"OutputBody:\n%@", outputBody);
	}
	
	NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:operation];
	
	operation.urlConnection = connection;
	[connection release];
}
- (void) dealloc
{
	[address release];
	[cookies release];
	[super dealloc];
}
@end

@implementation WOKMWSAuthenticateServiceSoapBindingOperation
@synthesize binding;
@synthesize bodyElements;
@synthesize response;
@synthesize delegate;
@synthesize responseData;
@synthesize urlConnection;
- (id)initWithBinding:(WOKMWSAuthenticateServiceSoapBinding *)aBinding delegate:(id<WOKMWSAuthenticateServiceSoapBindingResponseDelegate>)aDelegate bodyElements:(NSDictionary *)aBodyElements
{
	if ((self = [super init])) {
		self.binding = aBinding;
		self.bodyElements = aBodyElements;
		response = nil;
		self.delegate = aDelegate;
		self.responseData = nil;
		self.urlConnection = nil;
	}
	
	return self;
}
- (void)main
{
	[response autorelease];
	response = [WOKMWSAuthenticateServiceSoapBindingResponse new];
	
	WOKMWSAuthenticateServiceSoapBinding_envelope *envelope = [WOKMWSAuthenticateServiceSoapBinding_envelope sharedInstance];
	
	NSString *operationXMLString = [envelope serializedFormUsingHeaderElements:nil bodyElements:bodyElements];
	
	[binding sendHTTPCallUsingBody:operationXMLString soapAction:@"" forOperation:self];
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
				
			error = [NSError errorWithDomain:@"WOKMWSAuthenticateServiceSoapBindingResponseHTTP" code:[httpResponse statusCode] userInfo:userInfo];
		} else {
			NSDictionary *userInfo = [NSDictionary dictionaryWithObject:
																[NSString stringWithFormat: @"Unexpected response MIME type to SOAP call:%@", urlResponse.MIMEType]
																													 forKey:NSLocalizedDescriptionKey];
			error = [NSError errorWithDomain:@"WOKMWSAuthenticateServiceSoapBindingResponseHTTP" code:1 userInfo:userInfo];
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
		xmlDocPtr doc;
		xmlNodePtr cur;
		
		if (binding.logXMLInOut) {
			NSLog(@"ResponseBody:\n%@", [[[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding] autorelease]);
		}
		
		doc = xmlParseMemory([responseData bytes], [responseData length]);
		
		if (doc == NULL) {
			NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"Errors while parsing returned XML" forKey:NSLocalizedDescriptionKey];
			
			response.error = [NSError errorWithDomain:@"WOKMWSAuthenticateServiceSoapBindingResponseXML" code:1 userInfo:userInfo];
			[delegate operation:self completedWithResponse:response];
		} else {
			cur = xmlDocGetRootElement(doc);
			cur = cur->children;
			
			for( ; cur != NULL ; cur = cur->next) {
				if(cur->type == XML_ELEMENT_NODE) {
					
					if(xmlStrEqual(cur->name, (const xmlChar *) "Body")) {
						NSMutableArray *responseBodyParts = [NSMutableArray array];
						
						xmlNodePtr bodyNode;
						for(bodyNode=cur->children ; bodyNode != NULL ; bodyNode = bodyNode->next) {
							if(bodyNode->type == XML_ELEMENT_NODE) {
								Class responseClass = nil;
								if (xmlStrEqual(bodyNode->ns->prefix, cur->ns->prefix) && 
									xmlStrEqual(bodyNode->name, (const xmlChar *) "Fault")) {
									SOAPFault *bodyObject = [SOAPFault deserializeNode:bodyNode];
									//NSAssert1(bodyObject != nil, @"Errors while parsing body %s", bodyNode->name);
									if (bodyObject != nil) [responseBodyParts addObject:bodyObject];
								}
								else if((responseClass = NSClassFromString([NSString stringWithFormat:@"%@_%s", @"WOKMWSAuthenticateService", bodyNode->name]))) {
									id bodyObject = [responseClass deserializeNode:bodyNode];
									//NSAssert1(bodyObject != nil, @"Errors while parsing body %s", bodyNode->name);
									if (bodyObject != nil) [responseBodyParts addObject:bodyObject];
								}
							}
						}
						
						response.bodyParts = responseBodyParts;
					}
				}
			}
			
			xmlFreeDoc(doc);
		}
		
		xmlCleanupParser();
		[delegate operation:self completedWithResponse:response];
	}
}
- (void)dealloc
{
	[binding release];
	[bodyElements release];
	[response release];
	delegate = nil;
	[responseData release];
	[urlConnection release];
	
	[super dealloc];
}
@end

static WOKMWSAuthenticateServiceSoapBinding_envelope *WOKMWSAuthenticateServiceSoapBindingSharedEnvelopeInstance = nil;
@implementation WOKMWSAuthenticateServiceSoapBinding_envelope
+ (WOKMWSAuthenticateServiceSoapBinding_envelope *)sharedInstance
{
	if(WOKMWSAuthenticateServiceSoapBindingSharedEnvelopeInstance == nil) {
		WOKMWSAuthenticateServiceSoapBindingSharedEnvelopeInstance = [WOKMWSAuthenticateServiceSoapBinding_envelope new];
	}
	
	return WOKMWSAuthenticateServiceSoapBindingSharedEnvelopeInstance;
}
- (NSString *)serializedFormUsingHeaderElements:(NSDictionary *)headerElements bodyElements:(NSDictionary *)bodyElements
{
    xmlDocPtr doc;
	
	doc = xmlNewDoc((const xmlChar*)XML_DEFAULT_VERSION);
	if (doc == NULL) {
		NSLog(@"Error creating the xml document tree");
		return @"";
	}
	
	xmlNodePtr root = xmlNewDocNode(doc, NULL, (const xmlChar*)"Envelope", NULL);
	xmlDocSetRootElement(doc, root);
	
	xmlNsPtr soapEnvelopeNs = xmlNewNs(root, (const xmlChar*)"http://schemas.xmlsoap.org/soap/envelope/", (const xmlChar*)"soapenv");
	xmlSetNs(root, soapEnvelopeNs);
	
	xmlNsPtr authNs = xmlNewNs(root, (const xmlChar*)"http://auth.cxf.wokmws.thomsonreuters.com", (const xmlChar*)"auth");
	
	xmlNewNs(root, (const xmlChar*)"http://schemas.xmlsoap.org/wsdl/", (const xmlChar*)"wsdl");
	xmlNewNs(root, (const xmlChar*)"http://schemas.xmlsoap.org/wsdl/soap/", (const xmlChar*)"soap");
	
	if((headerElements != nil) && ([headerElements count] > 0)) {
		xmlNodePtr headerNode = xmlNewDocNode(doc, soapEnvelopeNs, (const xmlChar*)"Header", NULL);
		xmlAddChild(root, headerNode);
		
		for(NSString *key in [headerElements allKeys]) {
			id header = [headerElements objectForKey:key];
			xmlNodePtr child = xmlAddChild(headerNode, [header xmlNodeForDoc:doc elementName:key elementNSPrefix:nil]);
			xmlSetNs(child, authNs);
		}
	}
	
	if((bodyElements != nil) && ([bodyElements count] > 0)) {
		xmlNodePtr bodyNode = xmlNewDocNode(doc, soapEnvelopeNs, (const xmlChar*)"Body", NULL);
		xmlAddChild(root, bodyNode);
		
		for(NSString *key in [bodyElements allKeys]) {
			id body = [bodyElements objectForKey:key];
			xmlNodePtr child = xmlAddChild(bodyNode, [body xmlNodeForDoc:doc elementName:key elementNSPrefix:nil]);
			xmlSetNs(child, authNs);
		}
	}
	
	xmlChar *buf;
	int size;
	xmlDocDumpFormatMemory(doc, &buf, &size, 1);
	
	NSString *serializedForm = [NSString stringWithCString:(const char*)buf encoding:NSUTF8StringEncoding];
	xmlFree(buf);
	
	xmlFreeDoc(doc);	
	return serializedForm;
}
@end

@implementation WOKMWSAuthenticateServiceSoapBindingResponse
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
    self.headers = nil;
    self.bodyParts = nil;
    self.error = nil;	
    [super dealloc];
}
@end

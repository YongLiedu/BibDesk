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
	xmlDocPtr doc;
	
	doc = xmlNewDoc((const xmlChar*)XML_DEFAULT_VERSION);
	if (doc == NULL) {
		NSLog(@"Error creating the xml document tree");
		return @"";
	}
	
	xmlNodePtr root = xmlNewDocNode(doc, NULL, (const xmlChar*)"Envelope", NULL);
	xmlDocSetRootElement(doc, root);
	
	xmlNsPtr soapEnvelopeNs = xmlNewNs(root, (const xmlChar*)"http://schemas.xmlsoap.org/soap/envelope/", (const xmlChar*)"soap");
	xmlSetNs(root, soapEnvelopeNs);
	
	xmlNsPtr ns2 = NULL;
	
	if (self.namespaceURI != nil) {
		ns2 = xmlNewNs(root, (const xmlChar *)[self.namespaceURI UTF8String], (const xmlChar*)"ns2");
	}
	
	if((headerElements != nil) && ([headerElements count] > 0)) {
		xmlNodePtr headerNode = xmlNewDocNode(doc, soapEnvelopeNs, (const xmlChar*)"Header", NULL);
		xmlAddChild(root, headerNode);
		
		for(NSString *key in [headerElements allKeys]) {
			id header = [headerElements objectForKey:key];
			xmlNodePtr child = xmlAddChild(headerNode, [header xmlNodeForDoc:doc elementName:key elementNSPrefix:nil]);
			if(ns2 != NULL) {
				xmlSetNs(child, ns2);
			}
		}
	}
	
	if((bodyElements != nil) && ([bodyElements count] > 0)) {
		xmlNodePtr bodyNode = xmlNewDocNode(doc, soapEnvelopeNs, (const xmlChar*)"Body", NULL);
		xmlAddChild(root, bodyNode);
		
		for(NSString *key in [bodyElements allKeys]) {
			id body = [bodyElements objectForKey:key];
			xmlNodePtr child = xmlAddChild(bodyNode, [body xmlNodeForDoc:doc elementName:key elementNSPrefix:nil]);
			if(ns2 != NULL) {
				xmlSetNs(child, ns2);
			}
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
- (void)sendHTTPCallUsingBody:(NSString *)outputBody soapAction:(NSString *)soapAction forOperation:(WokServiceSoapBindingOperation *)operation
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
	
	NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:operation];
	
	operation.urlConnection = connection;
	[connection release];
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
- (id)initWithBinding:(WokServiceSoapBinding *)aBinding delegate:(id<WokServiceSoapBindingResponseDelegate>)aDelegate bodyElements:(NSDictionary *)aBodyElements responseClasses:(NSDictionary *)aResponseClasses
{
	if ((self = [super init])) {
		self.binding = aBinding;
		self.bodyElements = aBodyElements;
		self.responseClasses = aResponseClasses;
		self.soapAction = @"";
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
	response = [WokServiceSoapBindingResponse new];
	
	NSMutableDictionary *headerElements = [NSMutableDictionary dictionary];
	
	NSString *operationXMLString = [binding serializedEnvelopeUsingHeaderElements:headerElements bodyElements:bodyElements];
	
	[binding sendHTTPCallUsingBody:operationXMLString soapAction:self.soapAction forOperation:self];
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
		xmlDocPtr doc;
		xmlNodePtr cur;
		
		if (binding.logXMLInOut) {
			NSLog(@"ResponseBody:\n%@", [[[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding] autorelease]);
		}
		
		doc = xmlParseMemory([responseData bytes], [responseData length]);
		
		if (doc == NULL) {
			NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"Errors while parsing returned XML" forKey:NSLocalizedDescriptionKey];
			
			response.error = [NSError errorWithDomain:@"WokServiceSoapBindingResponseXML" code:1 userInfo:userInfo];
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
								Class responseClass = [self.responseClasses objectForKey:[NSString stringWithUTF8String:(const char *)bodyNode->name]];
								if(responseClass != nil) {
									id bodyObject = [responseClass deserializeNode:bodyNode];
									//NSAssert1(bodyObject != nil, @"Errors while parsing body %s", bodyNode->name);
									if (bodyObject != nil) [responseBodyParts addObject:bodyObject];
								}
								else if (xmlStrEqual(bodyNode->ns->prefix, cur->ns->prefix) && 
									xmlStrEqual(bodyNode->name, (const xmlChar *) "Fault")) {
									WokServiceSoapBinding_fault *bodyObject = [WokServiceSoapBinding_fault deserializeNode:bodyNode];
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
	self.headers = nil;
	self.bodyParts = nil;
	self.error = nil;	
	[super dealloc];
}
@end

@implementation WokServiceSoapBindingElement
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix
{
	if(elNSPrefix != nil && [elNSPrefix length] > 0)
	{
		elName = [NSString stringWithFormat:@"%@:%@", elNSPrefix, elName];
	}
	
	xmlNodePtr node = xmlNewDocNode(doc, NULL, (const xmlChar *)[elName UTF8String], NULL);
	
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
- (void)addElementsToNode:(xmlNodePtr)node
{
	if(self.faultcode!= nil) {
		xmlAddChild(node, [self.faultcode xmlNodeForDoc:node->doc elementName:@"faultcode" elementNSPrefix:nil]);
	}
	if(self.faultstring!= nil) {
		xmlAddChild(node, [self.faultstring xmlNodeForDoc:node->doc elementName:@"faultstring" elementNSPrefix:nil]);
	}
	if(self.faultactor!= nil) {
		xmlAddChild(node, [self.faultactor xmlNodeForDoc:node->doc elementName:@"faultactor" elementNSPrefix:nil]);
	}
}
@synthesize faultcode;
@synthesize faultstring;
@synthesize faultactor;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur
{
	for( cur = cur->children ; cur != NULL ; cur = cur->next ) {
		if(cur->type == XML_ELEMENT_NODE) {
			if(xmlStrEqual(cur->name, (const xmlChar *) "faultcode")) {
				self.faultcode = [NSString deserializeNode:cur];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "faultstring")) {
				self.faultstring = [NSString deserializeNode:cur];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "faultactor")) {
				self.faultactor = [NSString deserializeNode:cur];
			}
		}
	}
}
@end

@implementation NSString (WokServiceSoapBinding)
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix
{
	if(elNSPrefix != nil && [elNSPrefix length] > 0)
	{
		elName = [NSString stringWithFormat:@"%@:%@", elNSPrefix, elName];
	}
	
	xmlNodePtr node = xmlNewDocNode(doc, NULL, (const xmlChar *)[elName UTF8String], (const xmlChar *)[self UTF8String]);
	
	return node;
}
+ (NSString *)deserializeNode:(xmlNodePtr)cur
{
	xmlChar *elementText = xmlNodeListGetString(cur->doc, cur->children, 1);
	NSString *elementString = nil;
	
	if(elementText != NULL) {
		elementString = [NSString stringWithUTF8String:(char*)elementText];
		xmlFree(elementText);
	}
	
	return elementString;
}
@end

@implementation NSNumber (WokServiceSoapBinding)
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix
{
	return [[self stringValue] xmlNodeForDoc:doc elementName:elName elementNSPrefix:elNSPrefix];
}
+ (NSNumber *)deserializeNode:(xmlNodePtr)cur
{
	return [NSNumber numberWithInteger:[[NSString deserializeNode:cur] integerValue]];
}
@end

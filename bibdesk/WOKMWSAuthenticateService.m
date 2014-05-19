#import "WOKMWSAuthenticateService.h"

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
				self.return_ = [NSString deserializeNode:cur];
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
+ (NSString *)address
{
	return @"http://search.webofknowledge.com/esti/wokmws/ws/WOKMWSAuthenticate";
}
+ (NSString *)namespaceURI
{
	return @"http://auth.cxf.wokmws.thomsonreuters.com";
}
- (WokServiceSoapBindingResponse *)authenticateUsingParameters:(WOKMWSAuthenticateService_authenticate *)parameters
{
	NSDictionary *bodyElements = [NSDictionary dictionaryWithObjectsAndKeys:parameters, @"authenticate", nil];
	NSDictionary *responseClasses = [NSDictionary dictionaryWithObjectsAndKeys:[WOKMWSAuthenticateService_authenticateResponse class], @"authenticateResponse", nil];
	return [self performSynchronousOperation:[[[WokServiceSoapBindingOperation alloc] initWithBinding:self delegate:self bodyElements:bodyElements responseClasses:responseClasses] autorelease]];
}
- (WokServiceSoapBindingResponse *)closeSessionUsingParameters:(WOKMWSAuthenticateService_closeSession *)parameters
{
	NSDictionary *bodyElements = [NSDictionary dictionaryWithObjectsAndKeys:parameters, @"closeSession", nil];
	NSDictionary *responseClasses = [NSDictionary dictionaryWithObjectsAndKeys:[WOKMWSAuthenticateService_closeSessionResponse class], @"closeSessionResponse", nil];
	return [self performSynchronousOperation:[[[WokServiceSoapBindingOperation alloc] initWithBinding:self delegate:self bodyElements:bodyElements responseClasses:responseClasses] autorelease]];
}
@end

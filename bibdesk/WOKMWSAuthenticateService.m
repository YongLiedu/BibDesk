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
- (void)addElementsToNode:(NSXMLElement *)node
{
	if(self.return_!= nil) {
		[node addChild:[self.return_ XMLNodeWithName:@"return" prefix:nil]];
	}
}
@synthesize return_;
- (void)deserializeElementsFromNode:(NSXMLElement *)node
{
	for( node in [node children] ) {
		if([node kind] == NSXMLElementKind) {
			if([[node localName] isEqualToString:@"return"]) {
				self.return_ = [NSString deserializeNode:node];
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

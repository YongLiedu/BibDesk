#import "WOKMWSAuthenticateService.h"

@implementation WOKMWSAuthenticateService_authenticate
- (NSString *)elementName
{
	return @"authenticate";
}
- (NSString *)responseName
{
	return @"authenticateResponse";
}
- (Class)responseClass
{
	return [WOKMWSAuthenticateService_authenticateResponse class];
}
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
- (NSString *)elementName
{
	return @"closeSession";
}
- (NSString *)responseName
{
	return @"closeSessionResponse";
}
- (Class)responseClass
{
	return [WOKMWSAuthenticateService_closeSessionResponse class];
}
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
+ (WokServiceSoapBinding *)soapBinding
{
	return [[[WokServiceSoapBinding alloc] initWithAddress:[self address] namespaceURI:[self namespaceURI]] autorelease];
}
@end

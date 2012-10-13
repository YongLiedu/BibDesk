#import <Foundation/Foundation.h>
#import "USAdditions.h"
#import <libxml/tree.h>
#import "USGlobals.h"
@class WOKMWSAuthenticateService_authenticate;
@class WOKMWSAuthenticateService_authenticateResponse;
@class WOKMWSAuthenticateService_closeSession;
@class WOKMWSAuthenticateService_closeSessionResponse;
@class WOKMWSAuthenticateService_InternalServerException;
@class WOKMWSAuthenticateService_ESTIWSException;
@class WOKMWSAuthenticateService_SessionException;
@class WOKMWSAuthenticateService_AuthenticationException;
@class WOKMWSAuthenticateService_QueryException;
@class WOKMWSAuthenticateService_InvalidInputException;
@interface WOKMWSAuthenticateService_authenticate : NSObject {
	
/* elements */
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WOKMWSAuthenticateService_authenticate *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WOKMWSAuthenticateService_authenticateResponse : NSObject {
	
/* elements */
	NSString * return_;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WOKMWSAuthenticateService_authenticateResponse *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
@property (retain) NSString * return_;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WOKMWSAuthenticateService_closeSession : NSObject {
	
/* elements */
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WOKMWSAuthenticateService_closeSession *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WOKMWSAuthenticateService_closeSessionResponse : NSObject {
	
/* elements */
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WOKMWSAuthenticateService_closeSessionResponse *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WOKMWSAuthenticateService_InternalServerException : NSObject {
	
/* elements */
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WOKMWSAuthenticateService_InternalServerException *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WOKMWSAuthenticateService_ESTIWSException : NSObject {
	
/* elements */
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WOKMWSAuthenticateService_ESTIWSException *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WOKMWSAuthenticateService_SessionException : NSObject {
	
/* elements */
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WOKMWSAuthenticateService_SessionException *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WOKMWSAuthenticateService_AuthenticationException : NSObject {
	
/* elements */
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WOKMWSAuthenticateService_AuthenticationException *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WOKMWSAuthenticateService_QueryException : NSObject {
	
/* elements */
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WOKMWSAuthenticateService_QueryException *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WOKMWSAuthenticateService_InvalidInputException : NSObject {
	
/* elements */
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WOKMWSAuthenticateService_InvalidInputException *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
/* attributes */
- (NSDictionary *)attributes;
@end
/* Cookies handling provided by http://en.wikibooks.org/wiki/Programming:WebObjects/Web_Services/Web_Service_Provider */
#import <libxml/parser.h>
// FIX #import "xsd.h"
// FIX #import "WOKMWSAuthenticateService.h"
@class WOKMWSAuthenticateServiceSoapBinding;
@interface WOKMWSAuthenticateService : NSObject {
	
}
+ (WOKMWSAuthenticateServiceSoapBinding *)WOKMWSAuthenticateServiceSoapBinding;
@end
@class WOKMWSAuthenticateServiceSoapBindingResponse;
@class WOKMWSAuthenticateServiceSoapBindingOperation;
@protocol WOKMWSAuthenticateServiceSoapBindingResponseDelegate <NSObject>
- (void) operation:(WOKMWSAuthenticateServiceSoapBindingOperation *)operation completedWithResponse:(WOKMWSAuthenticateServiceSoapBindingResponse *)response;
@end
@interface WOKMWSAuthenticateServiceSoapBinding : NSObject <WOKMWSAuthenticateServiceSoapBindingResponseDelegate> {
	NSURL *address;
	NSTimeInterval defaultTimeout;
	NSMutableArray *cookies;
	BOOL logXMLInOut;
	BOOL synchronousOperationComplete;
	NSString *authUsername;
	NSString *authPassword;
}
@property (copy) NSURL *address;
@property (assign) BOOL logXMLInOut;
@property (assign) NSTimeInterval defaultTimeout;
@property (nonatomic, retain) NSMutableArray *cookies;
@property (nonatomic, retain) NSString *authUsername;
@property (nonatomic, retain) NSString *authPassword;
- (id)initWithAddress:(NSString *)anAddress;
- (void)sendHTTPCallUsingBody:(NSString *)body soapAction:(NSString *)soapAction forOperation:(WOKMWSAuthenticateServiceSoapBindingOperation *)operation;
- (void)addCookie:(NSHTTPCookie *)toAdd;
- (WOKMWSAuthenticateServiceSoapBindingResponse *)authenticateUsingParameters:(WOKMWSAuthenticateService_authenticate *)aParameters ;
- (void)authenticateAsyncUsingParameters:(WOKMWSAuthenticateService_authenticate *)aParameters  delegate:(id<WOKMWSAuthenticateServiceSoapBindingResponseDelegate>)responseDelegate;
- (WOKMWSAuthenticateServiceSoapBindingResponse *)closeSessionUsingParameters:(WOKMWSAuthenticateService_closeSession *)aParameters ;
- (void)closeSessionAsyncUsingParameters:(WOKMWSAuthenticateService_closeSession *)aParameters  delegate:(id<WOKMWSAuthenticateServiceSoapBindingResponseDelegate>)responseDelegate;
@end
@interface WOKMWSAuthenticateServiceSoapBindingOperation : NSOperation {
	WOKMWSAuthenticateServiceSoapBinding *binding;
	WOKMWSAuthenticateServiceSoapBindingResponse *response;
	id<WOKMWSAuthenticateServiceSoapBindingResponseDelegate> delegate;
	NSMutableData *responseData;
	NSURLConnection *urlConnection;
}
@property (retain) WOKMWSAuthenticateServiceSoapBinding *binding;
@property (readonly) WOKMWSAuthenticateServiceSoapBindingResponse *response;
@property (nonatomic, assign) id<WOKMWSAuthenticateServiceSoapBindingResponseDelegate> delegate;
@property (nonatomic, retain) NSMutableData *responseData;
@property (nonatomic, retain) NSURLConnection *urlConnection;
- (id)initWithBinding:(WOKMWSAuthenticateServiceSoapBinding *)aBinding delegate:(id<WOKMWSAuthenticateServiceSoapBindingResponseDelegate>)aDelegate;
@end
@interface WOKMWSAuthenticateServiceSoapBinding_authenticate : WOKMWSAuthenticateServiceSoapBindingOperation {
	WOKMWSAuthenticateService_authenticate * parameters;
}
@property (retain) WOKMWSAuthenticateService_authenticate * parameters;
- (id)initWithBinding:(WOKMWSAuthenticateServiceSoapBinding *)aBinding delegate:(id<WOKMWSAuthenticateServiceSoapBindingResponseDelegate>)aDelegate
	parameters:(WOKMWSAuthenticateService_authenticate *)aParameters
;
@end
@interface WOKMWSAuthenticateServiceSoapBinding_closeSession : WOKMWSAuthenticateServiceSoapBindingOperation {
	WOKMWSAuthenticateService_closeSession * parameters;
}
@property (retain) WOKMWSAuthenticateService_closeSession * parameters;
- (id)initWithBinding:(WOKMWSAuthenticateServiceSoapBinding *)aBinding delegate:(id<WOKMWSAuthenticateServiceSoapBindingResponseDelegate>)aDelegate
	parameters:(WOKMWSAuthenticateService_closeSession *)aParameters
;
@end
@interface WOKMWSAuthenticateServiceSoapBinding_envelope : NSObject {
}
+ (WOKMWSAuthenticateServiceSoapBinding_envelope *)sharedInstance;
- (NSString *)serializedFormUsingHeaderElements:(NSDictionary *)headerElements bodyElements:(NSDictionary *)bodyElements;
@end
@interface WOKMWSAuthenticateServiceSoapBindingResponse : NSObject {
	NSArray *headers;
	NSArray *bodyParts;
	NSError *error;
}
@property (retain) NSArray *headers;
@property (retain) NSArray *bodyParts;
@property (retain) NSError *error;
@end

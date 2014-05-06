#import <Foundation/Foundation.h>
#import "USAdditions.h"
#import <libxml/tree.h>

@class WOKMWSAuthenticateService_authenticate;
@class WOKMWSAuthenticateService_authenticateResponse;
@class WOKMWSAuthenticateService_closeSession;
@class WOKMWSAuthenticateService_closeSessionResponse;

@interface WOKMWSAuthenticateServiceElement : NSObject {
}
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (id)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
@end

@interface WOKMWSAuthenticateService_authenticate : WOKMWSAuthenticateServiceElement {
}
@end

@interface WOKMWSAuthenticateService_authenticateResponse : WOKMWSAuthenticateServiceElement {
	NSString * return_;
}
@property (retain) NSString * return_;
@end

@interface WOKMWSAuthenticateService_closeSession : WOKMWSAuthenticateServiceElement {
}
@end

@interface WOKMWSAuthenticateService_closeSessionResponse : WOKMWSAuthenticateServiceElement {
}
@end

/* Cookies handling provided by http://en.wikibooks.org/wiki/Programming:WebObjects/Web_Services/Web_Service_Provider */
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
	NSDictionary *bodyElements;
	WOKMWSAuthenticateServiceSoapBindingResponse *response;
	id<WOKMWSAuthenticateServiceSoapBindingResponseDelegate> delegate;
	NSMutableData *responseData;
	NSURLConnection *urlConnection;
}
@property (retain) WOKMWSAuthenticateServiceSoapBinding *binding;
@property (retain) NSDictionary *bodyElements;
@property (readonly) WOKMWSAuthenticateServiceSoapBindingResponse *response;
@property (nonatomic, assign) id<WOKMWSAuthenticateServiceSoapBindingResponseDelegate> delegate;
@property (nonatomic, retain) NSMutableData *responseData;
@property (nonatomic, retain) NSURLConnection *urlConnection;
- (id)initWithBinding:(WOKMWSAuthenticateServiceSoapBinding *)aBinding delegate:(id<WOKMWSAuthenticateServiceSoapBindingResponseDelegate>)aDelegate bodyElements:(NSDictionary *)aBodyElements;
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

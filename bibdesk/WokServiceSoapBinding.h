#import <Foundation/Foundation.h>
#import <libxml/tree.h>

@class WokServiceSoapBindingElement;
@class WokServiceSoapBindingRequest;
@class WokServiceSoapBindingResponse;
@class WokServiceSoapBindingOperation;

@protocol WokServiceSoapBindingResponseDelegate <NSObject>
- (void)operation:(WokServiceSoapBindingOperation *)operation completedWithResponse:(WokServiceSoapBindingResponse *)response;
@end

@interface WokServiceSoapBinding : NSObject <WokServiceSoapBindingResponseDelegate> {
	NSURL *address;
	NSString *namespaceURI;
	NSTimeInterval defaultTimeout;
	NSMutableArray *cookies;
	BOOL logXMLInOut;
	BOOL synchronousOperationComplete;
	NSString *authUsername;
	NSString *authPassword;
}
@property (copy) NSURL *address;
@property (copy) NSString *namespaceURI;
@property (assign) BOOL logXMLInOut;
@property (assign) NSTimeInterval defaultTimeout;
@property (nonatomic, retain) NSMutableArray *cookies;
@property (nonatomic, retain) NSString *authUsername;
@property (nonatomic, retain) NSString *authPassword;
- (id)initWithAddress:(NSString *)anAddress namespaceURI:(NSString *)aNamespaceURI;
- (NSString *)serializedEnvelopeUsingHeaderElements:(NSDictionary *)headerElements bodyElements:(NSDictionary *)bodyElements;
- (void)sendHTTPCallUsingBody:(NSString *)body soapAction:(NSString *)soapAction forOperation:(WokServiceSoapBindingOperation *)operation;
- (void)addCookie:(NSHTTPCookie *)toAdd;
- (WokServiceSoapBindingResponse *)performSynchronousOperationWithParameters:(WokServiceSoapBindingRequest *)parameters;
- (void)performAsynchronousOperationWithParameters:(WokServiceSoapBindingRequest *)parameters delegate:(id<WokServiceSoapBindingResponseDelegate>)responseDelegate;
@end

@interface WokServiceSoapBindingOperation : NSOperation {
	WokServiceSoapBinding *binding;
	WokServiceSoapBindingRequest *parameters;
	WokServiceSoapBindingResponse *response;
	id<WokServiceSoapBindingResponseDelegate> delegate;
	NSMutableData *responseData;
	NSURLConnection *urlConnection;
}
@property (retain) WokServiceSoapBinding *binding;
@property (retain) WokServiceSoapBindingRequest *parameters;
@property (readonly) WokServiceSoapBindingResponse *response;
@property (nonatomic, assign) id<WokServiceSoapBindingResponseDelegate> delegate;
@property (nonatomic, retain) NSMutableData *responseData;
@property (nonatomic, retain) NSURLConnection *urlConnection;
- (id)initWithBinding:(WokServiceSoapBinding *)aBinding delegate:(id<WokServiceSoapBindingResponseDelegate>)aDelegate parameters:(WokServiceSoapBindingRequest *)aParameters;
@end

@interface WokServiceSoapBindingResponse : NSObject {
	NSArray *headers;
	NSArray *bodyParts;
	NSError *error;
}
@property (retain) NSArray *headers;
@property (retain) NSArray *bodyParts;
@property (retain) NSError *error;
@end

@interface WokServiceSoapBindingElement : NSObject {
}
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (id)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
@end

@interface WokServiceSoapBindingRequest : WokServiceSoapBindingElement {
}
@property (readonly) NSString * elementName;
@property (readonly) NSString * responseName;
@property (readonly) Class responseClass;
@property (readonly) NSString * soapAction;
@end

@interface WokServiceSoapBinding_fault : WokServiceSoapBindingElement {
	NSString *faultcode;
	NSString *faultstring;
	NSString *faultactor;
}
@property (retain) NSString *faultcode;
@property (retain) NSString *faultstring;
@property (retain) NSString *faultactor;
@end

@interface NSString (WokServiceSoapBinding)
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
+ (NSString *)deserializeNode:(xmlNodePtr)cur;
@end

@interface NSNumber (WokServiceSoapBinding)
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
+ (NSNumber *)deserializeNode:(xmlNodePtr)cur;
@end

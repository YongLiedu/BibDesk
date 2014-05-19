#import <Foundation/Foundation.h>
#import <libxml/tree.h>

@class WokServiceSoapBindingElement;
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
+ (NSString *)address;
+ (NSString *)namespaceURI;
+ (id)soapBinding;
@property (copy) NSURL *address;
@property (copy) NSString *namespaceURI;
@property (assign) BOOL logXMLInOut;
@property (assign) NSTimeInterval defaultTimeout;
@property (nonatomic, retain) NSMutableArray *cookies;
@property (nonatomic, retain) NSString *authUsername;
@property (nonatomic, retain) NSString *authPassword;
- (id)initWithAddress:(NSString *)anAddress namespaceURI:(NSString *)aNamespaceURI;
- (NSString *)serializedEnvelopeUsingHeaderElements:(NSDictionary *)headerElements bodyElements:(NSDictionary *)bodyElements;
- (NSURLRequest *)requestUsingBody:(NSString *)body soapAction:(NSString *)soapAction;
- (void)addCookie:(NSHTTPCookie *)toAdd;
- (WokServiceSoapBindingResponse *)performSynchronousOperation:(WokServiceSoapBindingOperation *)operation;
- (void)performAsynchronousOperation:(WokServiceSoapBindingOperation *)operation delegate:(id<WokServiceSoapBindingResponseDelegate>)responseDelegate;
@end

@interface WokServiceSoapBindingOperation : NSOperation {
	WokServiceSoapBinding *binding;
	NSDictionary *bodyElements;
	NSDictionary *responseClasses;
	NSString *soapAction;
	WokServiceSoapBindingResponse *response;
	id<WokServiceSoapBindingResponseDelegate> delegate;
	NSMutableData *responseData;
	NSURLConnection *urlConnection;
}
@property (retain) WokServiceSoapBinding *binding;
@property (retain) NSDictionary *bodyElements;
@property (retain) NSDictionary *responseClasses;
@property (retain) NSString *soapAction;
@property (readonly) WokServiceSoapBindingResponse *response;
@property (nonatomic, assign) id<WokServiceSoapBindingResponseDelegate> delegate;
@property (nonatomic, retain) NSMutableData *responseData;
@property (nonatomic, retain) NSURLConnection *urlConnection;
- (id)initWithBinding:(WokServiceSoapBinding *)aBinding delegate:(id<WokServiceSoapBindingResponseDelegate>)aDelegate soapAction:(NSString *)aSoapAction bodyElements:(NSDictionary *)aBodyElements responseClasses:(NSDictionary *)aResponseClasses;
- (id)initWithBinding:(WokServiceSoapBinding *)aBinding delegate:(id<WokServiceSoapBindingResponseDelegate>)aDelegate bodyElements:(NSDictionary *)aBodyElements responseClasses:(NSDictionary *)aResponseClasses;
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

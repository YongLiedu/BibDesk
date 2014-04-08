#import <Foundation/Foundation.h>
#import "USAdditions.h"
#import <libxml/tree.h>
#import "USGlobals.h"
@class WokSearchLiteService_retrieve;
@class WokSearchLiteService_retrieveResponse;
@class WokSearchLiteService_retrieveById;
@class WokSearchLiteService_retrieveByIdResponse;
@class WokSearchLiteService_search;
@class WokSearchLiteService_searchResponse;
@class WokSearchLiteService_retrieveParameters;
@class WokSearchLiteService_searchResults;
@class WokSearchLiteService_queryParameters;
@class WokSearchLiteService_editionDesc;
@class WokSearchLiteService_timeSpan;
@class WokSearchLiteService_sortField;
@class WokSearchLiteService_liteRecord;
@class WokSearchLiteService_labelValuesPair;
@class WokSearchLiteService_FaultInformation;
@class WokSearchLiteService_SupportingWebServiceException;
@class WokSearchLiteService_RawFaultInformation;
@class WokSearchLiteService_QueryException;
@class WokSearchLiteService_AuthenticationException;
@class WokSearchLiteService_InvalidInputException;
@class WokSearchLiteService_ESTIWSException;
@class WokSearchLiteService_InternalServerException;
@class WokSearchLiteService_SessionException;
@interface WokSearchLiteService_sortField : NSObject {
	
/* elements */
	NSString * name;
	NSString * sort;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchLiteService_sortField *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
@property (retain) NSString * name;
@property (retain) NSString * sort;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchLiteService_retrieveParameters : NSObject {
	
/* elements */
	NSNumber * firstRecord;
	NSNumber * count;
	NSMutableArray *sortField;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchLiteService_retrieveParameters *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
@property (retain) NSNumber * firstRecord;
@property (retain) NSNumber * count;
- (void)addSortField:(WokSearchLiteService_sortField *)toAdd;
@property (readonly) NSMutableArray * sortField;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchLiteService_retrieve : NSObject {
	
/* elements */
	NSString * queryId;
	WokSearchLiteService_retrieveParameters * retrieveParameters;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchLiteService_retrieve *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
@property (retain) NSString * queryId;
@property (retain) WokSearchLiteService_retrieveParameters * retrieveParameters;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchLiteService_labelValuesPair : NSObject {
	
/* elements */
	NSString * label;
	NSMutableArray *value;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchLiteService_labelValuesPair *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
@property (retain) NSString * label;
- (void)addValue:(NSString *)toAdd;
@property (readonly) NSMutableArray * value;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchLiteService_liteRecord : NSObject {
	
/* elements */
	NSString * uid;
	NSMutableArray *title;
	NSMutableArray *source;
	NSMutableArray *authors;
	NSMutableArray *keywords;
	NSMutableArray *other;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchLiteService_liteRecord *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
@property (retain) NSString * uid;
- (void)addTitle:(WokSearchLiteService_labelValuesPair *)toAdd;
@property (readonly) NSMutableArray * title;
- (void)addSource:(WokSearchLiteService_labelValuesPair *)toAdd;
@property (readonly) NSMutableArray * source;
- (void)addAuthors:(WokSearchLiteService_labelValuesPair *)toAdd;
@property (readonly) NSMutableArray * authors;
- (void)addKeywords:(WokSearchLiteService_labelValuesPair *)toAdd;
@property (readonly) NSMutableArray * keywords;
- (void)addOther:(WokSearchLiteService_labelValuesPair *)toAdd;
@property (readonly) NSMutableArray * other;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchLiteService_searchResults : NSObject {
	
/* elements */
	NSString * queryId;
	NSNumber * recordsFound;
	NSNumber * recordsSearched;
	WokSearchLiteService_liteRecord * parent;
	NSMutableArray *records;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchLiteService_searchResults *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
@property (retain) NSString * queryId;
@property (retain) NSNumber * recordsFound;
@property (retain) NSNumber * recordsSearched;
@property (retain) WokSearchLiteService_liteRecord * parent;
- (void)addRecords:(WokSearchLiteService_liteRecord *)toAdd;
@property (readonly) NSMutableArray * records;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchLiteService_retrieveResponse : NSObject {
	
/* elements */
	WokSearchLiteService_searchResults * return_;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchLiteService_retrieveResponse *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
@property (retain) WokSearchLiteService_searchResults * return_;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchLiteService_retrieveById : NSObject {
	
/* elements */
	NSString * databaseId;
	NSMutableArray *uid;
	NSString * queryLanguage;
	WokSearchLiteService_retrieveParameters * retrieveParameters;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchLiteService_retrieveById *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
@property (retain) NSString * databaseId;
- (void)addUid:(NSString *)toAdd;
@property (readonly) NSMutableArray * uid;
@property (retain) NSString * queryLanguage;
@property (retain) WokSearchLiteService_retrieveParameters * retrieveParameters;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchLiteService_retrieveByIdResponse : NSObject {
	
/* elements */
	WokSearchLiteService_searchResults * return_;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchLiteService_retrieveByIdResponse *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
@property (retain) WokSearchLiteService_searchResults * return_;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchLiteService_editionDesc : NSObject {
	
/* elements */
	NSString * collection;
	NSString * edition;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchLiteService_editionDesc *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
@property (retain) NSString * collection;
@property (retain) NSString * edition;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchLiteService_timeSpan : NSObject {
	
/* elements */
	NSString * begin;
	NSString * end;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchLiteService_timeSpan *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
@property (retain) NSString * begin;
@property (retain) NSString * end;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchLiteService_queryParameters : NSObject {
	
/* elements */
	NSString * databaseId;
	NSString * userQuery;
	NSMutableArray *editions;
	NSString * symbolicTimeSpan;
	WokSearchLiteService_timeSpan * timeSpan;
	NSString * queryLanguage;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchLiteService_queryParameters *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
@property (retain) NSString * databaseId;
@property (retain) NSString * userQuery;
- (void)addEditions:(WokSearchLiteService_editionDesc *)toAdd;
@property (readonly) NSMutableArray * editions;
@property (retain) NSString * symbolicTimeSpan;
@property (retain) WokSearchLiteService_timeSpan * timeSpan;
@property (retain) NSString * queryLanguage;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchLiteService_search : NSObject {
	
/* elements */
	WokSearchLiteService_queryParameters * queryParameters;
	WokSearchLiteService_retrieveParameters * retrieveParameters;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchLiteService_search *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
@property (retain) WokSearchLiteService_queryParameters * queryParameters;
@property (retain) WokSearchLiteService_retrieveParameters * retrieveParameters;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchLiteService_searchResponse : NSObject {
	
/* elements */
	WokSearchLiteService_searchResults * return_;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchLiteService_searchResponse *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
@property (retain) WokSearchLiteService_searchResults * return_;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchLiteService_SupportingWebServiceException : NSObject {
	
/* elements */
	NSString * remoteNamespace;
	NSString * remoteOperation;
	NSString * remoteCode;
	NSString * remoteReason;
	NSString * handshakeCauseId;
	NSString * handshakeCause;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchLiteService_SupportingWebServiceException *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
@property (retain) NSString * remoteNamespace;
@property (retain) NSString * remoteOperation;
@property (retain) NSString * remoteCode;
@property (retain) NSString * remoteReason;
@property (retain) NSString * handshakeCauseId;
@property (retain) NSString * handshakeCause;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchLiteService_FaultInformation : NSObject {
	
/* elements */
	NSString * code;
	NSString * message;
	NSString * reason;
	NSString * causeType;
	NSString * cause;
	WokSearchLiteService_SupportingWebServiceException * supportingWebServiceException;
	NSString * remedy;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchLiteService_FaultInformation *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
@property (retain) NSString * code;
@property (retain) NSString * message;
@property (retain) NSString * reason;
@property (retain) NSString * causeType;
@property (retain) NSString * cause;
@property (retain) WokSearchLiteService_SupportingWebServiceException * supportingWebServiceException;
@property (retain) NSString * remedy;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchLiteService_RawFaultInformation : NSObject {
	
/* elements */
	NSString * rawFaultstring;
	NSString * rawMessage;
	NSString * rawReason;
	NSString * rawCause;
	NSString * rawRemedy;
	NSMutableArray *messageData;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchLiteService_RawFaultInformation *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
@property (retain) NSString * rawFaultstring;
@property (retain) NSString * rawMessage;
@property (retain) NSString * rawReason;
@property (retain) NSString * rawCause;
@property (retain) NSString * rawRemedy;
- (void)addMessageData:(NSString *)toAdd;
@property (readonly) NSMutableArray * messageData;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchLiteService_QueryException : NSObject {
	
/* elements */
	WokSearchLiteService_FaultInformation * faultInformation;
	WokSearchLiteService_RawFaultInformation * rawFaultInformation;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchLiteService_QueryException *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
@property (retain) WokSearchLiteService_FaultInformation * faultInformation;
@property (retain) WokSearchLiteService_RawFaultInformation * rawFaultInformation;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchLiteService_AuthenticationException : NSObject {
	
/* elements */
	WokSearchLiteService_FaultInformation * faultInformation;
	WokSearchLiteService_RawFaultInformation * rawFaultInformation;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchLiteService_AuthenticationException *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
@property (retain) WokSearchLiteService_FaultInformation * faultInformation;
@property (retain) WokSearchLiteService_RawFaultInformation * rawFaultInformation;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchLiteService_InvalidInputException : NSObject {
	
/* elements */
	WokSearchLiteService_FaultInformation * faultInformation;
	WokSearchLiteService_RawFaultInformation * rawFaultInformation;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchLiteService_InvalidInputException *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
@property (retain) WokSearchLiteService_FaultInformation * faultInformation;
@property (retain) WokSearchLiteService_RawFaultInformation * rawFaultInformation;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchLiteService_ESTIWSException : NSObject {
	
/* elements */
	WokSearchLiteService_FaultInformation * faultInformation;
	WokSearchLiteService_RawFaultInformation * rawFaultInformation;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchLiteService_ESTIWSException *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
@property (retain) WokSearchLiteService_FaultInformation * faultInformation;
@property (retain) WokSearchLiteService_RawFaultInformation * rawFaultInformation;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchLiteService_InternalServerException : NSObject {
	
/* elements */
	WokSearchLiteService_FaultInformation * faultInformation;
	WokSearchLiteService_RawFaultInformation * rawFaultInformation;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchLiteService_InternalServerException *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
@property (retain) WokSearchLiteService_FaultInformation * faultInformation;
@property (retain) WokSearchLiteService_RawFaultInformation * rawFaultInformation;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchLiteService_SessionException : NSObject {
	
/* elements */
	WokSearchLiteService_FaultInformation * faultInformation;
	WokSearchLiteService_RawFaultInformation * rawFaultInformation;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchLiteService_SessionException *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
@property (retain) WokSearchLiteService_FaultInformation * faultInformation;
@property (retain) WokSearchLiteService_RawFaultInformation * rawFaultInformation;
/* attributes */
- (NSDictionary *)attributes;
@end
/* Cookies handling provided by http://en.wikibooks.org/wiki/Programming:WebObjects/Web_Services/Web_Service_Provider */
#import <libxml/parser.h>
// FIX #import "xs.h"
// FIX #import "WokSearchLiteService.h"
@class WokSearchLiteServiceSoapBinding;
@interface WokSearchLiteService : NSObject {
	
}
+ (WokSearchLiteServiceSoapBinding *)WokSearchLiteServiceSoapBinding;
@end
@class WokSearchLiteServiceSoapBindingResponse;
@class WokSearchLiteServiceSoapBindingOperation;
@protocol WokSearchLiteServiceSoapBindingResponseDelegate <NSObject>
- (void) operation:(WokSearchLiteServiceSoapBindingOperation *)operation completedWithResponse:(WokSearchLiteServiceSoapBindingResponse *)response;
@end
@interface WokSearchLiteServiceSoapBinding : NSObject <WokSearchLiteServiceSoapBindingResponseDelegate> {
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
- (void)sendHTTPCallUsingBody:(NSString *)body soapAction:(NSString *)soapAction forOperation:(WokSearchLiteServiceSoapBindingOperation *)operation;
- (void)addCookie:(NSHTTPCookie *)toAdd;
- (WokSearchLiteServiceSoapBindingResponse *)retrieveByIdUsingParameters:(WokSearchLiteService_retrieveById *)aParameters ;
- (void)retrieveByIdAsyncUsingParameters:(WokSearchLiteService_retrieveById *)aParameters  delegate:(id<WokSearchLiteServiceSoapBindingResponseDelegate>)responseDelegate;
- (WokSearchLiteServiceSoapBindingResponse *)retrieveUsingParameters:(WokSearchLiteService_retrieve *)aParameters ;
- (void)retrieveAsyncUsingParameters:(WokSearchLiteService_retrieve *)aParameters  delegate:(id<WokSearchLiteServiceSoapBindingResponseDelegate>)responseDelegate;
- (WokSearchLiteServiceSoapBindingResponse *)searchUsingParameters:(WokSearchLiteService_search *)aParameters ;
- (void)searchAsyncUsingParameters:(WokSearchLiteService_search *)aParameters  delegate:(id<WokSearchLiteServiceSoapBindingResponseDelegate>)responseDelegate;
@end
@interface WokSearchLiteServiceSoapBindingOperation : NSOperation {
	WokSearchLiteServiceSoapBinding *binding;
	WokSearchLiteServiceSoapBindingResponse *response;
	id<WokSearchLiteServiceSoapBindingResponseDelegate> delegate;
	NSMutableData *responseData;
	NSURLConnection *urlConnection;
}
@property (retain) WokSearchLiteServiceSoapBinding *binding;
@property (readonly) WokSearchLiteServiceSoapBindingResponse *response;
@property (nonatomic, assign) id<WokSearchLiteServiceSoapBindingResponseDelegate> delegate;
@property (nonatomic, retain) NSMutableData *responseData;
@property (nonatomic, retain) NSURLConnection *urlConnection;
- (id)initWithBinding:(WokSearchLiteServiceSoapBinding *)aBinding delegate:(id<WokSearchLiteServiceSoapBindingResponseDelegate>)aDelegate;
@end
@interface WokSearchLiteServiceSoapBinding_retrieveById : WokSearchLiteServiceSoapBindingOperation {
	WokSearchLiteService_retrieveById * parameters;
}
@property (retain) WokSearchLiteService_retrieveById * parameters;
- (id)initWithBinding:(WokSearchLiteServiceSoapBinding *)aBinding delegate:(id<WokSearchLiteServiceSoapBindingResponseDelegate>)aDelegate
	parameters:(WokSearchLiteService_retrieveById *)aParameters
;
@end
@interface WokSearchLiteServiceSoapBinding_retrieve : WokSearchLiteServiceSoapBindingOperation {
	WokSearchLiteService_retrieve * parameters;
}
@property (retain) WokSearchLiteService_retrieve * parameters;
- (id)initWithBinding:(WokSearchLiteServiceSoapBinding *)aBinding delegate:(id<WokSearchLiteServiceSoapBindingResponseDelegate>)aDelegate
	parameters:(WokSearchLiteService_retrieve *)aParameters
;
@end
@interface WokSearchLiteServiceSoapBinding_search : WokSearchLiteServiceSoapBindingOperation {
	WokSearchLiteService_search * parameters;
}
@property (retain) WokSearchLiteService_search * parameters;
- (id)initWithBinding:(WokSearchLiteServiceSoapBinding *)aBinding delegate:(id<WokSearchLiteServiceSoapBindingResponseDelegate>)aDelegate
	parameters:(WokSearchLiteService_search *)aParameters
;
@end
@interface WokSearchLiteServiceSoapBinding_envelope : NSObject {
}
+ (WokSearchLiteServiceSoapBinding_envelope *)sharedInstance;
- (NSString *)serializedFormUsingHeaderElements:(NSDictionary *)headerElements bodyElements:(NSDictionary *)bodyElements;
@end
@interface WokSearchLiteServiceSoapBindingResponse : NSObject {
	NSArray *headers;
	NSArray *bodyParts;
	NSError *error;
}
@property (retain) NSArray *headers;
@property (retain) NSArray *bodyParts;
@property (retain) NSError *error;
@end

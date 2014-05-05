#import <Foundation/Foundation.h>
#import "USAdditions.h"
#import <libxml/tree.h>

@class WokSearchService_citedReferences;
@class WokSearchService_citedReferencesResponse;
@class WokSearchService_citedReferencesRetrieve;
@class WokSearchService_citedReferencesRetrieveResponse;
@class WokSearchService_citingArticles;
@class WokSearchService_citingArticlesResponse;
@class WokSearchService_relatedRecords;
@class WokSearchService_relatedRecordsResponse;
@class WokSearchService_retrieve;
@class WokSearchService_retrieveResponse;
@class WokSearchService_retrieveById;
@class WokSearchService_retrieveByIdResponse;
@class WokSearchService_search;
@class WokSearchService_searchResponse;
@class WokSearchService_retrieveParameters;
@class WokSearchService_citedReferencesSearchResults;
@class WokSearchService_citedReference;
@class WokSearchService_editionDesc;
@class WokSearchService_timeSpan;
@class WokSearchService_fullRecordSearchResults;
@class WokSearchService_fullRecordData;
@class WokSearchService_queryParameters;
@class WokSearchService_sortField;
@class WokSearchService_viewField;
@class WokSearchService_keyValuePair;
@class WokSearchService_labelValuesPair;
@class WokSearchService_FaultInformation;
@class WokSearchService_SupportingWebServiceException;
@class WokSearchService_RawFaultInformation;
@class WokSearchService_QueryException;
@class WokSearchService_AuthenticationException;
@class WokSearchService_InvalidInputException;
@class WokSearchService_ESTIWSException;
@class WokSearchService_InternalServerException;
@class WokSearchService_SessionException;

@interface WokSearchServiceElement : NSObject {
}
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (id)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
@end

@interface WokSearchService_sortField : WokSearchServiceElement {
	NSString * name;
	NSString * sort;
}
@property (retain) NSString * name;
@property (retain) NSString * sort;
@end

@interface WokSearchService_viewField : WokSearchServiceElement {
	NSString * collectionName;
	NSMutableArray *fieldName;
}
@property (retain) NSString * collectionName;
- (void)addFieldName:(NSString *)toAdd;
@property (readonly) NSMutableArray * fieldName;
@end

@interface WokSearchService_keyValuePair : WokSearchServiceElement {
	NSString * key;
	NSString * value;
}
@property (retain) NSString * key;
@property (retain) NSString * value;
@end

@interface WokSearchService_retrieveParameters : WokSearchServiceElement {
	NSNumber * firstRecord;
	NSNumber * count;
	NSMutableArray *sortField;
	NSMutableArray *viewField;
	NSMutableArray *option;
}
@property (retain) NSNumber * firstRecord;
@property (retain) NSNumber * count;
- (void)addSortField:(WokSearchService_sortField *)toAdd;
@property (readonly) NSMutableArray * sortField;
- (void)addViewField:(WokSearchService_viewField *)toAdd;
@property (readonly) NSMutableArray * viewField;
- (void)addOption:(WokSearchService_keyValuePair *)toAdd;
@property (readonly) NSMutableArray * option;
@end

@interface WokSearchService_citedReferences : WokSearchServiceElement {
	NSString * databaseId;
	NSString * uid;
	NSString * queryLanguage;
	WokSearchService_retrieveParameters * retrieveParameters;
}
@property (retain) NSString * databaseId;
@property (retain) NSString * uid;
@property (retain) NSString * queryLanguage;
@property (retain) WokSearchService_retrieveParameters * retrieveParameters;
@end

@interface WokSearchService_citedReference : WokSearchServiceElement {
	NSString * uid;
	NSString * docid;
	NSString * articleId;
	NSString * citedAuthor;
	NSString * timesCited;
	NSString * year;
	NSString * page;
	NSString * volume;
	NSString * citedTitle;
	NSString * citedWork;
	NSString * hot;
}
@property (retain) NSString * uid;
@property (retain) NSString * docid;
@property (retain) NSString * articleId;
@property (retain) NSString * citedAuthor;
@property (retain) NSString * timesCited;
@property (retain) NSString * year;
@property (retain) NSString * page;
@property (retain) NSString * volume;
@property (retain) NSString * citedTitle;
@property (retain) NSString * citedWork;
@property (retain) NSString * hot;
@end

@interface WokSearchService_citedReferencesSearchResults : WokSearchServiceElement {
	NSString * queryId;
	NSMutableArray *references;
	NSNumber * recordsFound;
	NSNumber * recordsSearched;
}
@property (retain) NSString * queryId;
- (void)addReferences:(WokSearchService_citedReference *)toAdd;
@property (readonly) NSMutableArray * references;
@property (retain) NSNumber * recordsFound;
@property (retain) NSNumber * recordsSearched;
@end

@interface WokSearchService_citedReferencesResponse : WokSearchServiceElement {
	WokSearchService_citedReferencesSearchResults * return_;
}
@property (retain) WokSearchService_citedReferencesSearchResults * return_;
@end

@interface WokSearchService_citedReferencesRetrieve : WokSearchServiceElement {
	NSString * queryId;
	WokSearchService_retrieveParameters * retrieveParameters;
}
@property (retain) NSString * queryId;
@property (retain) WokSearchService_retrieveParameters * retrieveParameters;
@end

@interface WokSearchService_citedReferencesRetrieveResponse : WokSearchServiceElement {
	NSMutableArray *return_;
}
- (void)addReturn_:(WokSearchService_citedReference *)toAdd;
@property (readonly) NSMutableArray * return_;
@end

@interface WokSearchService_editionDesc : WokSearchServiceElement {
	NSString * collection;
	NSString * edition;
}
@property (retain) NSString * collection;
@property (retain) NSString * edition;
@end

@interface WokSearchService_timeSpan : WokSearchServiceElement {
	NSString * begin;
	NSString * end;
}
@property (retain) NSString * begin;
@property (retain) NSString * end;
@end

@interface WokSearchService_citingArticles : WokSearchServiceElement {
	NSString * databaseId;
	NSString * uid;
	NSMutableArray *editions;
	WokSearchService_timeSpan * timeSpan;
	NSString * queryLanguage;
	WokSearchService_retrieveParameters * retrieveParameters;
}
@property (retain) NSString * databaseId;
@property (retain) NSString * uid;
- (void)addEditions:(WokSearchService_editionDesc *)toAdd;
@property (readonly) NSMutableArray * editions;
@property (retain) WokSearchService_timeSpan * timeSpan;
@property (retain) NSString * queryLanguage;
@property (retain) WokSearchService_retrieveParameters * retrieveParameters;
@end

@interface WokSearchService_labelValuesPair : WokSearchServiceElement {
	NSString * label;
	NSMutableArray *value;
}
@property (retain) NSString * label;
- (void)addValue:(NSString *)toAdd;
@property (readonly) NSMutableArray * value;
@end

@interface WokSearchService_fullRecordSearchResults : WokSearchServiceElement {
	NSString * queryId;
	NSNumber * recordsFound;
	NSNumber * recordsSearched;
	NSString * parent;
	NSMutableArray *optionValue;
	NSString * records;
}
@property (retain) NSString * queryId;
@property (retain) NSNumber * recordsFound;
@property (retain) NSNumber * recordsSearched;
@property (retain) NSString * parent;
- (void)addOptionValue:(WokSearchService_labelValuesPair *)toAdd;
@property (readonly) NSMutableArray * optionValue;
@property (retain) NSString * records;
@end

@interface WokSearchService_citingArticlesResponse : WokSearchServiceElement {
	WokSearchService_fullRecordSearchResults * return_;
}
@property (retain) WokSearchService_fullRecordSearchResults * return_;
@end

@interface WokSearchService_relatedRecords : WokSearchServiceElement {
	NSString * databaseId;
	NSString * uid;
	NSMutableArray *editions;
	WokSearchService_timeSpan * timeSpan;
	NSString * queryLanguage;
	WokSearchService_retrieveParameters * retrieveParameters;
}
@property (retain) NSString * databaseId;
@property (retain) NSString * uid;
- (void)addEditions:(WokSearchService_editionDesc *)toAdd;
@property (readonly) NSMutableArray * editions;
@property (retain) WokSearchService_timeSpan * timeSpan;
@property (retain) NSString * queryLanguage;
@property (retain) WokSearchService_retrieveParameters * retrieveParameters;
@end

@interface WokSearchService_relatedRecordsResponse : WokSearchServiceElement {
	WokSearchService_fullRecordSearchResults * return_;
}
@property (retain) WokSearchService_fullRecordSearchResults * return_;
@end

@interface WokSearchService_retrieve : WokSearchServiceElement {
	NSString * queryId;
	WokSearchService_retrieveParameters * retrieveParameters;
}
@property (retain) NSString * queryId;
@property (retain) WokSearchService_retrieveParameters * retrieveParameters;
@end

@interface WokSearchService_fullRecordData : WokSearchServiceElement {
	NSMutableArray *optionValue;
	NSString * records;
}
- (void)addOptionValue:(WokSearchService_labelValuesPair *)toAdd;
@property (readonly) NSMutableArray * optionValue;
@property (retain) NSString * records;
@end

@interface WokSearchService_retrieveResponse : WokSearchServiceElement {
	WokSearchService_fullRecordData * return_;
}
@property (retain) WokSearchService_fullRecordData * return_;
@end

@interface WokSearchService_retrieveById : WokSearchServiceElement {
	NSString * databaseId;
	NSMutableArray *uid;
	NSString * queryLanguage;
	WokSearchService_retrieveParameters * retrieveParameters;
}
@property (retain) NSString * databaseId;
- (void)addUid:(NSString *)toAdd;
@property (readonly) NSMutableArray * uid;
@property (retain) NSString * queryLanguage;
@property (retain) WokSearchService_retrieveParameters * retrieveParameters;
@end

@interface WokSearchService_retrieveByIdResponse : WokSearchServiceElement {
	WokSearchService_fullRecordSearchResults * return_;
}
@property (retain) WokSearchService_fullRecordSearchResults * return_;
@end

@interface WokSearchService_queryParameters : WokSearchServiceElement {
	NSString * databaseId;
	NSString * userQuery;
	NSMutableArray *editions;
	NSString * symbolicTimeSpan;
	WokSearchService_timeSpan * timeSpan;
	NSString * queryLanguage;
}
@property (retain) NSString * databaseId;
@property (retain) NSString * userQuery;
- (void)addEditions:(WokSearchService_editionDesc *)toAdd;
@property (readonly) NSMutableArray * editions;
@property (retain) NSString * symbolicTimeSpan;
@property (retain) WokSearchService_timeSpan * timeSpan;
@property (retain) NSString * queryLanguage;
@end

@interface WokSearchService_search : WokSearchServiceElement {
	WokSearchService_queryParameters * queryParameters;
	WokSearchService_retrieveParameters * retrieveParameters;
}
@property (retain) WokSearchService_queryParameters * queryParameters;
@property (retain) WokSearchService_retrieveParameters * retrieveParameters;
@end

@interface WokSearchService_searchResponse : WokSearchServiceElement {
	WokSearchService_fullRecordSearchResults * return_;
}
@property (retain) WokSearchService_fullRecordSearchResults * return_;
@end

@interface WokSearchService_SupportingWebServiceException : WokSearchServiceElement {
	NSString * remoteNamespace;
	NSString * remoteOperation;
	NSString * remoteCode;
	NSString * remoteReason;
	NSString * handshakeCauseId;
	NSString * handshakeCause;
}
@property (retain) NSString * remoteNamespace;
@property (retain) NSString * remoteOperation;
@property (retain) NSString * remoteCode;
@property (retain) NSString * remoteReason;
@property (retain) NSString * handshakeCauseId;
@property (retain) NSString * handshakeCause;
@end

@interface WokSearchService_FaultInformation : WokSearchServiceElement {
	NSString * code;
	NSString * message;
	NSString * reason;
	NSString * causeType;
	NSString * cause;
	WokSearchService_SupportingWebServiceException * supportingWebServiceException;
	NSString * remedy;
}
@property (retain) NSString * code;
@property (retain) NSString * message;
@property (retain) NSString * reason;
@property (retain) NSString * causeType;
@property (retain) NSString * cause;
@property (retain) WokSearchService_SupportingWebServiceException * supportingWebServiceException;
@property (retain) NSString * remedy;
@end

@interface WokSearchService_RawFaultInformation : WokSearchServiceElement {
	NSString * rawFaultstring;
	NSString * rawMessage;
	NSString * rawReason;
	NSString * rawCause;
	NSString * rawRemedy;
	NSMutableArray *messageData;
}
@property (retain) NSString * rawFaultstring;
@property (retain) NSString * rawMessage;
@property (retain) NSString * rawReason;
@property (retain) NSString * rawCause;
@property (retain) NSString * rawRemedy;
- (void)addMessageData:(NSString *)toAdd;
@property (readonly) NSMutableArray * messageData;
@end

@interface WokSearchService_QueryException : WokSearchServiceElement {
	WokSearchService_FaultInformation * faultInformation;
	WokSearchService_RawFaultInformation * rawFaultInformation;
}
@property (retain) WokSearchService_FaultInformation * faultInformation;
@property (retain) WokSearchService_RawFaultInformation * rawFaultInformation;
@end

@interface WokSearchService_AuthenticationException : WokSearchServiceElement {
	WokSearchService_FaultInformation * faultInformation;
	WokSearchService_RawFaultInformation * rawFaultInformation;
}
@property (retain) WokSearchService_FaultInformation * faultInformation;
@property (retain) WokSearchService_RawFaultInformation * rawFaultInformation;
@end

@interface WokSearchService_InvalidInputException : WokSearchServiceElement {
	WokSearchService_FaultInformation * faultInformation;
	WokSearchService_RawFaultInformation * rawFaultInformation;
}
@property (retain) WokSearchService_FaultInformation * faultInformation;
@property (retain) WokSearchService_RawFaultInformation * rawFaultInformation;
@end

@interface WokSearchService_ESTIWSException : WokSearchServiceElement {
	WokSearchService_FaultInformation * faultInformation;
	WokSearchService_RawFaultInformation * rawFaultInformation;
}
@property (retain) WokSearchService_FaultInformation * faultInformation;
@property (retain) WokSearchService_RawFaultInformation * rawFaultInformation;
@end

@interface WokSearchService_InternalServerException : WokSearchServiceElement {
	WokSearchService_FaultInformation * faultInformation;
	WokSearchService_RawFaultInformation * rawFaultInformation;
}
@property (retain) WokSearchService_FaultInformation * faultInformation;
@property (retain) WokSearchService_RawFaultInformation * rawFaultInformation;
@end

@interface WokSearchService_SessionException : WokSearchServiceElement {
	WokSearchService_FaultInformation * faultInformation;
	WokSearchService_RawFaultInformation * rawFaultInformation;
}
@property (retain) WokSearchService_FaultInformation * faultInformation;
@property (retain) WokSearchService_RawFaultInformation * rawFaultInformation;
@end

/* Cookies handling provided by http://en.wikibooks.org/wiki/Programming:WebObjects/Web_Services/Web_Service_Provider */
@class WokSearchServiceSoapBinding;
@interface WokSearchService : NSObject {
}
+ (WokSearchServiceSoapBinding *)WokSearchServiceSoapBinding;
@end

@class WokSearchServiceSoapBindingResponse;
@class WokSearchServiceSoapBindingOperation;
@protocol WokSearchServiceSoapBindingResponseDelegate <NSObject>
- (void) operation:(WokSearchServiceSoapBindingOperation *)operation completedWithResponse:(WokSearchServiceSoapBindingResponse *)response;
@end

@interface WokSearchServiceSoapBinding : NSObject <WokSearchServiceSoapBindingResponseDelegate> {
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
- (void)sendHTTPCallUsingBody:(NSString *)body soapAction:(NSString *)soapAction forOperation:(WokSearchServiceSoapBindingOperation *)operation;
- (void)addCookie:(NSHTTPCookie *)toAdd;
- (WokSearchServiceSoapBindingResponse *)citedReferencesRetrieveUsingParameters:(WokSearchService_citedReferencesRetrieve *)aParameters ;
- (void)citedReferencesRetrieveAsyncUsingParameters:(WokSearchService_citedReferencesRetrieve *)aParameters  delegate:(id<WokSearchServiceSoapBindingResponseDelegate>)responseDelegate;
- (WokSearchServiceSoapBindingResponse *)relatedRecordsUsingParameters:(WokSearchService_relatedRecords *)aParameters ;
- (void)relatedRecordsAsyncUsingParameters:(WokSearchService_relatedRecords *)aParameters  delegate:(id<WokSearchServiceSoapBindingResponseDelegate>)responseDelegate;
- (WokSearchServiceSoapBindingResponse *)citedReferencesUsingParameters:(WokSearchService_citedReferences *)aParameters ;
- (void)citedReferencesAsyncUsingParameters:(WokSearchService_citedReferences *)aParameters  delegate:(id<WokSearchServiceSoapBindingResponseDelegate>)responseDelegate;
- (WokSearchServiceSoapBindingResponse *)retrieveUsingParameters:(WokSearchService_retrieve *)aParameters ;
- (void)retrieveAsyncUsingParameters:(WokSearchService_retrieve *)aParameters  delegate:(id<WokSearchServiceSoapBindingResponseDelegate>)responseDelegate;
- (WokSearchServiceSoapBindingResponse *)searchUsingParameters:(WokSearchService_search *)aParameters ;
- (void)searchAsyncUsingParameters:(WokSearchService_search *)aParameters  delegate:(id<WokSearchServiceSoapBindingResponseDelegate>)responseDelegate;
- (WokSearchServiceSoapBindingResponse *)citingArticlesUsingParameters:(WokSearchService_citingArticles *)aParameters ;
- (void)citingArticlesAsyncUsingParameters:(WokSearchService_citingArticles *)aParameters  delegate:(id<WokSearchServiceSoapBindingResponseDelegate>)responseDelegate;
- (WokSearchServiceSoapBindingResponse *)retrieveByIdUsingParameters:(WokSearchService_retrieveById *)aParameters ;
- (void)retrieveByIdAsyncUsingParameters:(WokSearchService_retrieveById *)aParameters  delegate:(id<WokSearchServiceSoapBindingResponseDelegate>)responseDelegate;
@end

@interface WokSearchServiceSoapBindingOperation : NSOperation {
	WokSearchServiceSoapBinding *binding;
	NSDictionary *bodyElements;
	WokSearchServiceSoapBindingResponse *response;
	id<WokSearchServiceSoapBindingResponseDelegate> delegate;
	NSMutableData *responseData;
	NSURLConnection *urlConnection;
}
@property (retain) WokSearchServiceSoapBinding *binding;
@property (retain) NSDictionary *bodyElements;
@property (readonly) WokSearchServiceSoapBindingResponse *response;
@property (nonatomic, assign) id<WokSearchServiceSoapBindingResponseDelegate> delegate;
@property (nonatomic, retain) NSMutableData *responseData;
@property (nonatomic, retain) NSURLConnection *urlConnection;
- (id)initWithBinding:(WokSearchServiceSoapBinding *)aBinding delegate:(id<WokSearchServiceSoapBindingResponseDelegate>)aDelegate bodyElements:(NSDictionary *)aBodyElements;
@end

@interface WokSearchServiceSoapBinding_envelope : NSObject {
}
+ (WokSearchServiceSoapBinding_envelope *)sharedInstance;
- (NSString *)serializedFormUsingHeaderElements:(NSDictionary *)headerElements bodyElements:(NSDictionary *)bodyElements;
@end

@interface WokSearchServiceSoapBindingResponse : NSObject {
	NSArray *headers;
	NSArray *bodyParts;
	NSError *error;
}
@property (retain) NSArray *headers;
@property (retain) NSArray *bodyParts;
@property (retain) NSError *error;
@end

#import <Foundation/Foundation.h>
#import "USAdditions.h"
#import <libxml/tree.h>

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

@interface WokSearchLiteServiceElement : NSObject {
}
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (id)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
@end

@interface WokSearchLiteService_sortField : WokSearchLiteServiceElement {
	NSString * name;
	NSString * sort;
}
@property (retain) NSString * name;
@property (retain) NSString * sort;
@end

@interface WokSearchLiteService_retrieveParameters : WokSearchLiteServiceElement {
	NSNumber * firstRecord;
	NSNumber * count;
	NSMutableArray *sortField;
}
@property (retain) NSNumber * firstRecord;
@property (retain) NSNumber * count;
- (void)addSortField:(WokSearchLiteService_sortField *)toAdd;
@property (readonly) NSMutableArray * sortField;
@end

@interface WokSearchLiteService_retrieve : WokSearchLiteServiceElement {
	NSString * queryId;
	WokSearchLiteService_retrieveParameters * retrieveParameters;
}
@property (retain) NSString * queryId;
@property (retain) WokSearchLiteService_retrieveParameters * retrieveParameters;
@end

@interface WokSearchLiteService_labelValuesPair : WokSearchLiteServiceElement {
	NSString * label;
	NSMutableArray *value;
}
@property (retain) NSString * label;
- (void)addValue:(NSString *)toAdd;
@property (readonly) NSMutableArray * value;
@end

@interface WokSearchLiteService_liteRecord : WokSearchLiteServiceElement {
	NSString * uid;
	NSMutableArray *title;
	NSMutableArray *source;
	NSMutableArray *authors;
	NSMutableArray *keywords;
	NSMutableArray *other;
}
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
@end

@interface WokSearchLiteService_searchResults : WokSearchLiteServiceElement {
	NSString * queryId;
	NSNumber * recordsFound;
	NSNumber * recordsSearched;
	WokSearchLiteService_liteRecord * parent;
	NSMutableArray *records;
}
@property (retain) NSString * queryId;
@property (retain) NSNumber * recordsFound;
@property (retain) NSNumber * recordsSearched;
@property (retain) WokSearchLiteService_liteRecord * parent;
- (void)addRecords:(WokSearchLiteService_liteRecord *)toAdd;
@property (readonly) NSMutableArray * records;
@end

@interface WokSearchLiteService_retrieveResponse : WokSearchLiteServiceElement {
	WokSearchLiteService_searchResults * return_;
}
@property (retain) WokSearchLiteService_searchResults * return_;
@end

@interface WokSearchLiteService_retrieveById : WokSearchLiteServiceElement {
	NSString * databaseId;
	NSMutableArray *uid;
	NSString * queryLanguage;
	WokSearchLiteService_retrieveParameters * retrieveParameters;
}
@property (retain) NSString * databaseId;
- (void)addUid:(NSString *)toAdd;
@property (readonly) NSMutableArray * uid;
@property (retain) NSString * queryLanguage;
@property (retain) WokSearchLiteService_retrieveParameters * retrieveParameters;
@end

@interface WokSearchLiteService_retrieveByIdResponse : WokSearchLiteServiceElement {
	WokSearchLiteService_searchResults * return_;
}
@property (retain) WokSearchLiteService_searchResults * return_;
@end

@interface WokSearchLiteService_editionDesc : WokSearchLiteServiceElement {
	NSString * collection;
	NSString * edition;
}
@property (retain) NSString * collection;
@property (retain) NSString * edition;
@end

@interface WokSearchLiteService_timeSpan : WokSearchLiteServiceElement {
	NSString * begin;
	NSString * end;
}
@property (retain) NSString * begin;
@property (retain) NSString * end;
@end

@interface WokSearchLiteService_queryParameters : WokSearchLiteServiceElement {
	NSString * databaseId;
	NSString * userQuery;
	NSMutableArray *editions;
	NSString * symbolicTimeSpan;
	WokSearchLiteService_timeSpan * timeSpan;
	NSString * queryLanguage;
}
@property (retain) NSString * databaseId;
@property (retain) NSString * userQuery;
- (void)addEditions:(WokSearchLiteService_editionDesc *)toAdd;
@property (readonly) NSMutableArray * editions;
@property (retain) NSString * symbolicTimeSpan;
@property (retain) WokSearchLiteService_timeSpan * timeSpan;
@property (retain) NSString * queryLanguage;
@end

@interface WokSearchLiteService_search : WokSearchLiteServiceElement {
	WokSearchLiteService_queryParameters * queryParameters;
	WokSearchLiteService_retrieveParameters * retrieveParameters;
}
@property (retain) WokSearchLiteService_queryParameters * queryParameters;
@property (retain) WokSearchLiteService_retrieveParameters * retrieveParameters;
@end

@interface WokSearchLiteService_searchResponse : WokSearchLiteServiceElement {
	WokSearchLiteService_searchResults * return_;
}
@property (retain) WokSearchLiteService_searchResults * return_;
@end

/* Cookies handling provided by http://en.wikibooks.org/wiki/Programming:WebObjects/Web_Services/Web_Service_Provider */
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
	NSDictionary *bodyElements;
	WokSearchLiteServiceSoapBindingResponse *response;
	id<WokSearchLiteServiceSoapBindingResponseDelegate> delegate;
	NSMutableData *responseData;
	NSURLConnection *urlConnection;
}
@property (retain) WokSearchLiteServiceSoapBinding *binding;
@property (retain) NSDictionary *bodyElements;
@property (readonly) WokSearchLiteServiceSoapBindingResponse *response;
@property (nonatomic, assign) id<WokSearchLiteServiceSoapBindingResponseDelegate> delegate;
@property (nonatomic, retain) NSMutableData *responseData;
@property (nonatomic, retain) NSURLConnection *urlConnection;
- (id)initWithBinding:(WokSearchLiteServiceSoapBinding *)aBinding delegate:(id<WokSearchLiteServiceSoapBindingResponseDelegate>)aDelegate bodyElements:(NSDictionary *)aBodyElements;
@end

@interface WokSearchLiteServiceSoapBinding_retrieveById : WokSearchLiteServiceSoapBindingOperation {
	WokSearchLiteService_retrieveById * parameters;
}
@property (retain) WokSearchLiteService_retrieveById * parameters;
- (id)initWithBinding:(WokSearchLiteServiceSoapBinding *)aBinding delegate:(id<WokSearchLiteServiceSoapBindingResponseDelegate>)aDelegate
	parameters:(WokSearchLiteService_retrieveById *)aParameters;
@end

@interface WokSearchLiteServiceSoapBinding_retrieve : WokSearchLiteServiceSoapBindingOperation {
	WokSearchLiteService_retrieve * parameters;
}
@property (retain) WokSearchLiteService_retrieve * parameters;
- (id)initWithBinding:(WokSearchLiteServiceSoapBinding *)aBinding delegate:(id<WokSearchLiteServiceSoapBindingResponseDelegate>)aDelegate
	parameters:(WokSearchLiteService_retrieve *)aParameters;
@end

@interface WokSearchLiteServiceSoapBinding_search : WokSearchLiteServiceSoapBindingOperation {
	WokSearchLiteService_search * parameters;
}
@property (retain) WokSearchLiteService_search * parameters;
- (id)initWithBinding:(WokSearchLiteServiceSoapBinding *)aBinding delegate:(id<WokSearchLiteServiceSoapBindingResponseDelegate>)aDelegate
	parameters:(WokSearchLiteService_search *)aParameters;
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

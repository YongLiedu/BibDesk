#import <Foundation/Foundation.h>
#import "WokServiceSoapBinding.h"

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

@interface WokSearchLiteService_sortField : WokServiceSoapBindingElement {
	NSString * name;
	NSString * sort;
}
@property (retain) NSString * name;
@property (retain) NSString * sort;
@end

@interface WokSearchLiteService_retrieveParameters : WokServiceSoapBindingElement {
	NSNumber * firstRecord;
	NSNumber * count;
	NSMutableArray *sortField;
}
@property (retain) NSNumber * firstRecord;
@property (retain) NSNumber * count;
- (void)addSortField:(WokSearchLiteService_sortField *)toAdd;
@property (readonly) NSMutableArray * sortField;
@end

@interface WokSearchLiteService_retrieve : WokServiceSoapBindingElement {
	NSString * queryId;
	WokSearchLiteService_retrieveParameters * retrieveParameters;
}
@property (retain) NSString * queryId;
@property (retain) WokSearchLiteService_retrieveParameters * retrieveParameters;
@end

@interface WokSearchLiteService_labelValuesPair : WokServiceSoapBindingElement {
	NSString * label;
	NSMutableArray *value;
}
@property (retain) NSString * label;
- (void)addValue:(NSString *)toAdd;
@property (readonly) NSMutableArray * value;
@end

@interface WokSearchLiteService_liteRecord : WokServiceSoapBindingElement {
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

@interface WokSearchLiteService_searchResults : WokServiceSoapBindingElement {
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

@interface WokSearchLiteService_retrieveResponse : WokServiceSoapBindingElement {
	WokSearchLiteService_searchResults * return_;
}
@property (retain) WokSearchLiteService_searchResults * return_;
@end

@interface WokSearchLiteService_retrieveById : WokServiceSoapBindingElement {
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

@interface WokSearchLiteService_retrieveByIdResponse : WokServiceSoapBindingElement {
	WokSearchLiteService_searchResults * return_;
}
@property (retain) WokSearchLiteService_searchResults * return_;
@end

@interface WokSearchLiteService_editionDesc : WokServiceSoapBindingElement {
	NSString * collection;
	NSString * edition;
}
@property (retain) NSString * collection;
@property (retain) NSString * edition;
@end

@interface WokSearchLiteService_timeSpan : WokServiceSoapBindingElement {
	NSString * begin;
	NSString * end;
}
@property (retain) NSString * begin;
@property (retain) NSString * end;
@end

@interface WokSearchLiteService_queryParameters : WokServiceSoapBindingElement {
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

@interface WokSearchLiteService_search : WokServiceSoapBindingElement {
	WokSearchLiteService_queryParameters * queryParameters;
	WokSearchLiteService_retrieveParameters * retrieveParameters;
}
@property (retain) WokSearchLiteService_queryParameters * queryParameters;
@property (retain) WokSearchLiteService_retrieveParameters * retrieveParameters;
@end

@interface WokSearchLiteService_searchResponse : WokServiceSoapBindingElement {
	WokSearchLiteService_searchResults * return_;
}
@property (retain) WokSearchLiteService_searchResults * return_;
@end

@interface WokSearchLiteService : NSObject {
}
+ (NSString *)address;
+ (NSString *)namespaceURI;
+ (WokServiceSoapBinding *)soapBinding;
@end

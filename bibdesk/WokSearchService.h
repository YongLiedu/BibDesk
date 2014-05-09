#import <Foundation/Foundation.h>
#import "WokServiceSoapBinding.h"

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

@interface WokSearchService_sortField : WokServiceSoapBindingElement {
	NSString * name;
	NSString * sort;
}
@property (retain) NSString * name;
@property (retain) NSString * sort;
@end

@interface WokSearchService_viewField : WokServiceSoapBindingElement {
	NSString * collectionName;
	NSMutableArray *fieldName;
}
@property (retain) NSString * collectionName;
- (void)addFieldName:(NSString *)toAdd;
@property (readonly) NSMutableArray * fieldName;
@end

@interface WokSearchService_keyValuePair : WokServiceSoapBindingElement {
	NSString * key;
	NSString * value;
}
@property (retain) NSString * key;
@property (retain) NSString * value;
@end

@interface WokSearchService_retrieveParameters : WokServiceSoapBindingElement {
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

@interface WokSearchService_citedReferences : WokServiceSoapBindingElement {
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

@interface WokSearchService_citedReference : WokServiceSoapBindingElement {
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

@interface WokSearchService_citedReferencesSearchResults : WokServiceSoapBindingElement {
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

@interface WokSearchService_citedReferencesResponse : WokServiceSoapBindingElement {
	WokSearchService_citedReferencesSearchResults * return_;
}
@property (retain) WokSearchService_citedReferencesSearchResults * return_;
@end

@interface WokSearchService_citedReferencesRetrieve : WokServiceSoapBindingElement {
	NSString * queryId;
	WokSearchService_retrieveParameters * retrieveParameters;
}
@property (retain) NSString * queryId;
@property (retain) WokSearchService_retrieveParameters * retrieveParameters;
@end

@interface WokSearchService_citedReferencesRetrieveResponse : WokServiceSoapBindingElement {
	NSMutableArray *return_;
}
- (void)addReturn_:(WokSearchService_citedReference *)toAdd;
@property (readonly) NSMutableArray * return_;
@end

@interface WokSearchService_editionDesc : WokServiceSoapBindingElement {
	NSString * collection;
	NSString * edition;
}
@property (retain) NSString * collection;
@property (retain) NSString * edition;
@end

@interface WokSearchService_timeSpan : WokServiceSoapBindingElement {
	NSString * begin;
	NSString * end;
}
@property (retain) NSString * begin;
@property (retain) NSString * end;
@end

@interface WokSearchService_citingArticles : WokServiceSoapBindingElement {
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

@interface WokSearchService_labelValuesPair : WokServiceSoapBindingElement {
	NSString * label;
	NSMutableArray *value;
}
@property (retain) NSString * label;
- (void)addValue:(NSString *)toAdd;
@property (readonly) NSMutableArray * value;
@end

@interface WokSearchService_fullRecordSearchResults : WokServiceSoapBindingElement {
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

@interface WokSearchService_citingArticlesResponse : WokServiceSoapBindingElement {
	WokSearchService_fullRecordSearchResults * return_;
}
@property (retain) WokSearchService_fullRecordSearchResults * return_;
@end

@interface WokSearchService_relatedRecords : WokServiceSoapBindingElement {
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

@interface WokSearchService_relatedRecordsResponse : WokServiceSoapBindingElement {
	WokSearchService_fullRecordSearchResults * return_;
}
@property (retain) WokSearchService_fullRecordSearchResults * return_;
@end

@interface WokSearchService_retrieve : WokServiceSoapBindingElement {
	NSString * queryId;
	WokSearchService_retrieveParameters * retrieveParameters;
}
@property (retain) NSString * queryId;
@property (retain) WokSearchService_retrieveParameters * retrieveParameters;
@end

@interface WokSearchService_fullRecordData : WokServiceSoapBindingElement {
	NSMutableArray *optionValue;
	NSString * records;
}
- (void)addOptionValue:(WokSearchService_labelValuesPair *)toAdd;
@property (readonly) NSMutableArray * optionValue;
@property (retain) NSString * records;
@end

@interface WokSearchService_retrieveResponse : WokServiceSoapBindingElement {
	WokSearchService_fullRecordData * return_;
}
@property (retain) WokSearchService_fullRecordData * return_;
@end

@interface WokSearchService_retrieveById : WokServiceSoapBindingElement {
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

@interface WokSearchService_retrieveByIdResponse : WokServiceSoapBindingElement {
	WokSearchService_fullRecordSearchResults * return_;
}
@property (retain) WokSearchService_fullRecordSearchResults * return_;
@end

@interface WokSearchService_queryParameters : WokServiceSoapBindingElement {
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

@interface WokSearchService_search : WokServiceSoapBindingElement {
	WokSearchService_queryParameters * queryParameters;
	WokSearchService_retrieveParameters * retrieveParameters;
}
@property (retain) WokSearchService_queryParameters * queryParameters;
@property (retain) WokSearchService_retrieveParameters * retrieveParameters;
@end

@interface WokSearchService_searchResponse : WokServiceSoapBindingElement {
	WokSearchService_fullRecordSearchResults * return_;
}
@property (retain) WokSearchService_fullRecordSearchResults * return_;
@end

@interface WokSearchService : NSObject {
}
+ (NSString *)address;
+ (NSString *)namespaceURI;
+ (WokServiceSoapBinding *)soapBinding;
@end

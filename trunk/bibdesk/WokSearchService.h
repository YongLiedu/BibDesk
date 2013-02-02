#import <Foundation/Foundation.h>
#import "USAdditions.h"
#import <libxml/tree.h>
#import "USGlobals.h"
@class WokSearchService_citedReferences;
@class WokSearchService_citedReferencesResponse;
@class WokSearchService_citedReferencesRetrieve;
@class WokSearchService_citedReferencesRetrieveResponse;
@class WokSearchService_citingArticles;
@class WokSearchService_citingArticlesResponse;
@class WokSearchService_relatedRecords;
@class WokSearchService_relatedRecordsResponse;
@class WokSearchService_retrieve;
@class WokSearchService_retrieveById;
@class WokSearchService_retrieveByIdResponse;
@class WokSearchService_retrieveResponse;
@class WokSearchService_search;
@class WokSearchService_searchResponse;
@class WokSearchService_retrieveParameters;
@class WokSearchService_collectionFields;
@class WokSearchService_queryField;
@class WokSearchService_keyValuePair;
@class WokSearchService_citedReference;
@class WokSearchService_editionDesc;
@class WokSearchService_timeSpan;
@class WokSearchService_fullRecordSearchResults;
@class WokSearchService_labelValuesPair;
@class WokSearchService_citedReferencesSearchResults;
@class WokSearchService_fullRecordData;
@class WokSearchService_queryParameters;
@class WokSearchService_QueryException;
@class WokSearchService_AuthenticationException;
@class WokSearchService_InvalidInputException;
@class WokSearchService_ESTIWSException;
@class WokSearchService_InternalServerException;
@class WokSearchService_SessionException;
@interface WokSearchService_editionDesc : NSObject {
	
/* elements */
	NSString * collection;
	NSString * edition;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchService_editionDesc *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
@property (retain) NSString * collection;
@property (retain) NSString * edition;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchService_timeSpan : NSObject {
	
/* elements */
	NSString * begin;
	NSString * end;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchService_timeSpan *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
@property (retain) NSString * begin;
@property (retain) NSString * end;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchService_collectionFields : NSObject {
	
/* elements */
	NSString * collectionName;
	NSMutableArray *fieldList;
	NSString * listName;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchService_collectionFields *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
@property (retain) NSString * collectionName;
- (void)addFieldList:(NSString *)toAdd;
@property (readonly) NSMutableArray * fieldList;
@property (retain) NSString * listName;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchService_queryField : NSObject {
	
/* elements */
	NSString * name;
	NSString * sort;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchService_queryField *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
@property (retain) NSString * name;
@property (retain) NSString * sort;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchService_keyValuePair : NSObject {
	
/* elements */
	NSString * key;
	NSString * value;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchService_keyValuePair *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
@property (retain) NSString * key;
@property (retain) NSString * value;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchService_retrieveParameters : NSObject {
	
/* elements */
	NSMutableArray *collectionFields;
	NSNumber * count;
	NSMutableArray *fields;
	NSNumber * firstRecord;
	NSMutableArray *options;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchService_retrieveParameters *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
- (void)addCollectionFields:(WokSearchService_collectionFields *)toAdd;
@property (readonly) NSMutableArray * collectionFields;
@property (retain) NSNumber * count;
- (void)addFields:(WokSearchService_queryField *)toAdd;
@property (readonly) NSMutableArray * fields;
@property (retain) NSNumber * firstRecord;
- (void)addOptions:(WokSearchService_keyValuePair *)toAdd;
@property (readonly) NSMutableArray * options;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchService_citedReferences : NSObject {
	
/* elements */
	NSString * databaseId;
	NSString * uid;
	NSMutableArray *editions;
	WokSearchService_timeSpan * timeSpan;
	NSString * queryLanguage;
	WokSearchService_retrieveParameters * retrieveParameters;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchService_citedReferences *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
@property (retain) NSString * databaseId;
@property (retain) NSString * uid;
- (void)addEditions:(WokSearchService_editionDesc *)toAdd;
@property (readonly) NSMutableArray * editions;
@property (retain) WokSearchService_timeSpan * timeSpan;
@property (retain) NSString * queryLanguage;
@property (retain) WokSearchService_retrieveParameters * retrieveParameters;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchService_citedReference : NSObject {
	
/* elements */
	NSString * articleID;
	NSString * citedAuthor;
	NSString * citedTitle;
	NSString * citedWork;
	NSString * page;
	NSString * recID;
	NSString * refID;
	NSString * timesCited;
	NSString * volume;
	NSString * year;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchService_citedReference *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
@property (retain) NSString * articleID;
@property (retain) NSString * citedAuthor;
@property (retain) NSString * citedTitle;
@property (retain) NSString * citedWork;
@property (retain) NSString * page;
@property (retain) NSString * recID;
@property (retain) NSString * refID;
@property (retain) NSString * timesCited;
@property (retain) NSString * volume;
@property (retain) NSString * year;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchService_citedReferencesSearchResults : NSObject {
	
/* elements */
	NSString * queryID;
	NSMutableArray *records;
	NSNumber * recordsFound;
	NSNumber * recordsSearched;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchService_citedReferencesSearchResults *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
@property (retain) NSString * queryID;
- (void)addRecords:(WokSearchService_citedReference *)toAdd;
@property (readonly) NSMutableArray * records;
@property (retain) NSNumber * recordsFound;
@property (retain) NSNumber * recordsSearched;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchService_citedReferencesResponse : NSObject {
	
/* elements */
	WokSearchService_citedReferencesSearchResults * return_;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchService_citedReferencesResponse *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
@property (retain) WokSearchService_citedReferencesSearchResults * return_;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchService_citedReferencesRetrieve : NSObject {
	
/* elements */
	NSString * queryId;
	WokSearchService_retrieveParameters * retrieveParameters;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchService_citedReferencesRetrieve *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
@property (retain) NSString * queryId;
@property (retain) WokSearchService_retrieveParameters * retrieveParameters;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchService_citedReferencesRetrieveResponse : NSObject {
	
/* elements */
	NSMutableArray *return_;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchService_citedReferencesRetrieveResponse *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
- (void)addReturn_:(WokSearchService_citedReference *)toAdd;
@property (readonly) NSMutableArray * return_;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchService_citingArticles : NSObject {
	
/* elements */
	NSString * databaseId;
	NSString * uid;
	NSMutableArray *editions;
	WokSearchService_timeSpan * timeSpan;
	NSString * queryLanguage;
	WokSearchService_retrieveParameters * retrieveParameters;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchService_citingArticles *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
@property (retain) NSString * databaseId;
@property (retain) NSString * uid;
- (void)addEditions:(WokSearchService_editionDesc *)toAdd;
@property (readonly) NSMutableArray * editions;
@property (retain) WokSearchService_timeSpan * timeSpan;
@property (retain) NSString * queryLanguage;
@property (retain) WokSearchService_retrieveParameters * retrieveParameters;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchService_labelValuesPair : NSObject {
	
/* elements */
	NSString * label;
	NSMutableArray *values;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchService_labelValuesPair *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
@property (retain) NSString * label;
- (void)addValues:(NSString *)toAdd;
@property (readonly) NSMutableArray * values;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchService_fullRecordSearchResults : NSObject {
	
/* elements */
	NSMutableArray *options;
	NSString * parent;
	NSString * queryID;
	NSString * records;
	NSNumber * recordsFound;
	NSNumber * recordsSearched;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchService_fullRecordSearchResults *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
- (void)addOptions:(WokSearchService_labelValuesPair *)toAdd;
@property (readonly) NSMutableArray * options;
@property (retain) NSString * parent;
@property (retain) NSString * queryID;
@property (retain) NSString * records;
@property (retain) NSNumber * recordsFound;
@property (retain) NSNumber * recordsSearched;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchService_citingArticlesResponse : NSObject {
	
/* elements */
	WokSearchService_fullRecordSearchResults * return_;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchService_citingArticlesResponse *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
@property (retain) WokSearchService_fullRecordSearchResults * return_;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchService_relatedRecords : NSObject {
	
/* elements */
	NSString * databaseId;
	NSString * uid;
	NSMutableArray *editions;
	WokSearchService_timeSpan * timeSpan;
	NSString * queryLanguage;
	WokSearchService_retrieveParameters * retrieveParameters;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchService_relatedRecords *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
@property (retain) NSString * databaseId;
@property (retain) NSString * uid;
- (void)addEditions:(WokSearchService_editionDesc *)toAdd;
@property (readonly) NSMutableArray * editions;
@property (retain) WokSearchService_timeSpan * timeSpan;
@property (retain) NSString * queryLanguage;
@property (retain) WokSearchService_retrieveParameters * retrieveParameters;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchService_relatedRecordsResponse : NSObject {
	
/* elements */
	WokSearchService_fullRecordSearchResults * return_;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchService_relatedRecordsResponse *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
@property (retain) WokSearchService_fullRecordSearchResults * return_;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchService_retrieve : NSObject {
	
/* elements */
	NSString * queryId;
	WokSearchService_retrieveParameters * retrieveParameters;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchService_retrieve *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
@property (retain) NSString * queryId;
@property (retain) WokSearchService_retrieveParameters * retrieveParameters;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchService_retrieveById : NSObject {
	
/* elements */
	NSString * databaseId;
	NSMutableArray *uids;
	NSString * queryLanguage;
	WokSearchService_retrieveParameters * retrieveParameters;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchService_retrieveById *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
@property (retain) NSString * databaseId;
- (void)addUids:(NSString *)toAdd;
@property (readonly) NSMutableArray * uids;
@property (retain) NSString * queryLanguage;
@property (retain) WokSearchService_retrieveParameters * retrieveParameters;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchService_retrieveByIdResponse : NSObject {
	
/* elements */
	WokSearchService_fullRecordSearchResults * return_;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchService_retrieveByIdResponse *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
@property (retain) WokSearchService_fullRecordSearchResults * return_;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchService_fullRecordData : NSObject {
	
/* elements */
	NSMutableArray *options;
	NSString * records;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchService_fullRecordData *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
- (void)addOptions:(WokSearchService_labelValuesPair *)toAdd;
@property (readonly) NSMutableArray * options;
@property (retain) NSString * records;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchService_retrieveResponse : NSObject {
	
/* elements */
	WokSearchService_fullRecordData * return_;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchService_retrieveResponse *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
@property (retain) WokSearchService_fullRecordData * return_;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchService_queryParameters : NSObject {
	
/* elements */
	NSString * databaseID;
	NSMutableArray *editions;
	NSString * queryLanguage;
	NSString * symbolicTimeSpan;
	WokSearchService_timeSpan * timeSpan;
	NSString * userQuery;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchService_queryParameters *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
@property (retain) NSString * databaseID;
- (void)addEditions:(WokSearchService_editionDesc *)toAdd;
@property (readonly) NSMutableArray * editions;
@property (retain) NSString * queryLanguage;
@property (retain) NSString * symbolicTimeSpan;
@property (retain) WokSearchService_timeSpan * timeSpan;
@property (retain) NSString * userQuery;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchService_search : NSObject {
	
/* elements */
	WokSearchService_queryParameters * queryParameters;
	WokSearchService_retrieveParameters * retrieveParameters;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchService_search *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
@property (retain) WokSearchService_queryParameters * queryParameters;
@property (retain) WokSearchService_retrieveParameters * retrieveParameters;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchService_searchResponse : NSObject {
	
/* elements */
	WokSearchService_fullRecordSearchResults * return_;
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchService_searchResponse *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
@property (retain) WokSearchService_fullRecordSearchResults * return_;
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchService_QueryException : NSObject {
	
/* elements */
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchService_QueryException *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchService_AuthenticationException : NSObject {
	
/* elements */
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchService_AuthenticationException *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchService_InvalidInputException : NSObject {
	
/* elements */
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchService_InvalidInputException *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchService_ESTIWSException : NSObject {
	
/* elements */
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchService_ESTIWSException *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchService_InternalServerException : NSObject {
	
/* elements */
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchService_InternalServerException *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
/* attributes */
- (NSDictionary *)attributes;
@end
@interface WokSearchService_SessionException : NSObject {
	
/* elements */
/* attributes */
}
- (NSString *)nsPrefix;
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix;
- (void)addAttributesToNode:(xmlNodePtr)node;
- (void)addElementsToNode:(xmlNodePtr)node;
+ (WokSearchService_SessionException *)deserializeNode:(xmlNodePtr)cur;
- (void)deserializeAttributesFromNode:(xmlNodePtr)cur;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur;
/* elements */
/* attributes */
- (NSDictionary *)attributes;
@end
/* Cookies handling provided by http://en.wikibooks.org/wiki/Programming:WebObjects/Web_Services/Web_Service_Provider */
#import <libxml/parser.h>
// FIX #import "xsd.h"
// FIX #import "WokSearchService.h"
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
	WokSearchServiceSoapBindingResponse *response;
	id<WokSearchServiceSoapBindingResponseDelegate> delegate;
	NSMutableData *responseData;
	NSURLConnection *urlConnection;
}
@property (retain) WokSearchServiceSoapBinding *binding;
@property (readonly) WokSearchServiceSoapBindingResponse *response;
@property (nonatomic, assign) id<WokSearchServiceSoapBindingResponseDelegate> delegate;
@property (nonatomic, retain) NSMutableData *responseData;
@property (nonatomic, retain) NSURLConnection *urlConnection;
- (id)initWithBinding:(WokSearchServiceSoapBinding *)aBinding delegate:(id<WokSearchServiceSoapBindingResponseDelegate>)aDelegate;
@end
@interface WokSearchServiceSoapBinding_citedReferencesRetrieve : WokSearchServiceSoapBindingOperation {
	WokSearchService_citedReferencesRetrieve * parameters;
}
@property (retain) WokSearchService_citedReferencesRetrieve * parameters;
- (id)initWithBinding:(WokSearchServiceSoapBinding *)aBinding delegate:(id<WokSearchServiceSoapBindingResponseDelegate>)aDelegate
	parameters:(WokSearchService_citedReferencesRetrieve *)aParameters
;
@end
@interface WokSearchServiceSoapBinding_relatedRecords : WokSearchServiceSoapBindingOperation {
	WokSearchService_relatedRecords * parameters;
}
@property (retain) WokSearchService_relatedRecords * parameters;
- (id)initWithBinding:(WokSearchServiceSoapBinding *)aBinding delegate:(id<WokSearchServiceSoapBindingResponseDelegate>)aDelegate
	parameters:(WokSearchService_relatedRecords *)aParameters
;
@end
@interface WokSearchServiceSoapBinding_citedReferences : WokSearchServiceSoapBindingOperation {
	WokSearchService_citedReferences * parameters;
}
@property (retain) WokSearchService_citedReferences * parameters;
- (id)initWithBinding:(WokSearchServiceSoapBinding *)aBinding delegate:(id<WokSearchServiceSoapBindingResponseDelegate>)aDelegate
	parameters:(WokSearchService_citedReferences *)aParameters
;
@end
@interface WokSearchServiceSoapBinding_retrieve : WokSearchServiceSoapBindingOperation {
	WokSearchService_retrieve * parameters;
}
@property (retain) WokSearchService_retrieve * parameters;
- (id)initWithBinding:(WokSearchServiceSoapBinding *)aBinding delegate:(id<WokSearchServiceSoapBindingResponseDelegate>)aDelegate
	parameters:(WokSearchService_retrieve *)aParameters
;
@end
@interface WokSearchServiceSoapBinding_search : WokSearchServiceSoapBindingOperation {
	WokSearchService_search * parameters;
}
@property (retain) WokSearchService_search * parameters;
- (id)initWithBinding:(WokSearchServiceSoapBinding *)aBinding delegate:(id<WokSearchServiceSoapBindingResponseDelegate>)aDelegate
	parameters:(WokSearchService_search *)aParameters
;
@end
@interface WokSearchServiceSoapBinding_citingArticles : WokSearchServiceSoapBindingOperation {
	WokSearchService_citingArticles * parameters;
}
@property (retain) WokSearchService_citingArticles * parameters;
- (id)initWithBinding:(WokSearchServiceSoapBinding *)aBinding delegate:(id<WokSearchServiceSoapBindingResponseDelegate>)aDelegate
	parameters:(WokSearchService_citingArticles *)aParameters
;
@end
@interface WokSearchServiceSoapBinding_retrieveById : WokSearchServiceSoapBindingOperation {
	WokSearchService_retrieveById * parameters;
}
@property (retain) WokSearchService_retrieveById * parameters;
- (id)initWithBinding:(WokSearchServiceSoapBinding *)aBinding delegate:(id<WokSearchServiceSoapBindingResponseDelegate>)aDelegate
	parameters:(WokSearchService_retrieveById *)aParameters
;
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

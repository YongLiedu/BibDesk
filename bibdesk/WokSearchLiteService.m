#import "WokSearchLiteService.h"

@implementation WokSearchLiteService_sortField
- (id)init
{
	if((self = [super init])) {
		name = nil;
		sort = nil;
	}
	
	return self;
}
- (void)dealloc
{
	if(name != nil) [name release];
	if(sort != nil) [sort release];
	
	[super dealloc];
}
- (void)addElementsToNode:(xmlNodePtr)node
{
	if(self.name!= nil) {
		xmlAddChild(node, [self.name xmlNodeForDoc:node->doc elementName:@"name" elementNSPrefix:nil]);
	}
	if(self.sort!= nil) {
		xmlAddChild(node, [self.sort xmlNodeForDoc:node->doc elementName:@"sort" elementNSPrefix:nil]);
	}
}
@synthesize name;
@synthesize sort;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur
{
	for( cur = cur->children ; cur != NULL ; cur = cur->next ) {
		if(cur->type == XML_ELEMENT_NODE) {
			if(xmlStrEqual(cur->name, (const xmlChar *) "name")) {
				self.name = [NSString deserializeNode:cur];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "sort")) {
				self.sort = [NSString deserializeNode:cur];
			}
		}
	}
}
@end

@implementation WokSearchLiteService_retrieveParameters
- (id)init
{
	if((self = [super init])) {
		firstRecord = nil;
		count = nil;
		sortField = [[NSMutableArray alloc] init];
	}
	
	return self;
}
- (void)dealloc
{
	if(firstRecord != nil) [firstRecord release];
	if(count != nil) [count release];
	if(sortField != nil) [sortField release];
	
	[super dealloc];
}
- (void)addElementsToNode:(xmlNodePtr)node
{
	if(self.firstRecord!= nil) {
		xmlAddChild(node, [self.firstRecord xmlNodeForDoc:node->doc elementName:@"firstRecord" elementNSPrefix:nil]);
	}
	if(self.count!= nil) {
		xmlAddChild(node, [self.count xmlNodeForDoc:node->doc elementName:@"count" elementNSPrefix:nil]);
	}
	if(self.sortField!= nil) {
		for(WokSearchLiteService_sortField * child in self.sortField) {
			xmlAddChild(node, [child xmlNodeForDoc:node->doc elementName:@"sortField" elementNSPrefix:nil]);
		}
	}
}
@synthesize firstRecord;
@synthesize count;
@synthesize sortField;
- (void)addSortField:(WokSearchLiteService_sortField *)toAdd
{
	if(toAdd != nil) [sortField addObject:toAdd];
}
- (void)deserializeElementsFromNode:(xmlNodePtr)cur
{
	for( cur = cur->children ; cur != NULL ; cur = cur->next ) {
		if(cur->type == XML_ELEMENT_NODE) {
			if(xmlStrEqual(cur->name, (const xmlChar *) "firstRecord")) {
				self.firstRecord = [NSNumber deserializeNode:cur];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "count")) {
				self.count = [NSNumber deserializeNode:cur];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "sortField")) {
				[self addSortField:[WokSearchLiteService_sortField deserializeNode:cur]];
			}
		}
	}
}
@end

@implementation WokSearchLiteService_retrieve
- (id)init
{
	if((self = [super init])) {
		queryId = nil;
		retrieveParameters = nil;
	}
	
	return self;
}
- (void)dealloc
{
	if(queryId != nil) [queryId release];
	if(retrieveParameters != nil) [retrieveParameters release];
	
	[super dealloc];
}
- (void)addElementsToNode:(xmlNodePtr)node
{
	if(self.queryId!= nil) {
		xmlAddChild(node, [self.queryId xmlNodeForDoc:node->doc elementName:@"queryId" elementNSPrefix:nil]);
	}
	if(self.retrieveParameters!= nil) {
		xmlAddChild(node, [self.retrieveParameters xmlNodeForDoc:node->doc elementName:@"retrieveParameters" elementNSPrefix:nil]);
	}
}
@synthesize queryId;
@synthesize retrieveParameters;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur
{
	for( cur = cur->children ; cur != NULL ; cur = cur->next ) {
		if(cur->type == XML_ELEMENT_NODE) {
			if(xmlStrEqual(cur->name, (const xmlChar *) "queryId")) {
				self.queryId = [NSString deserializeNode:cur];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "retrieveParameters")) {
				self.retrieveParameters = [WokSearchLiteService_retrieveParameters deserializeNode:cur];
			}
		}
	}
}
@end

@implementation WokSearchLiteService_labelValuesPair
- (id)init
{
	if((self = [super init])) {
		label = nil;
		value = [[NSMutableArray alloc] init];
	}
	
	return self;
}
- (void)dealloc
{
	if(label != nil) [label release];
	if(value != nil) [value release];
	
	[super dealloc];
}
- (void)addElementsToNode:(xmlNodePtr)node
{
	if(self.label!= nil) {
		xmlAddChild(node, [self.label xmlNodeForDoc:node->doc elementName:@"label" elementNSPrefix:nil]);
	}
	if(self.value!= nil) {
		for(NSString * child in self.value) {
			xmlAddChild(node, [child xmlNodeForDoc:node->doc elementName:@"value" elementNSPrefix:nil]);
		}
	}
}
@synthesize label;
@synthesize value;
- (void)addValue:(NSString *)toAdd
{
	if(toAdd != nil) [value addObject:toAdd];
}
- (void)deserializeElementsFromNode:(xmlNodePtr)cur
{
	for( cur = cur->children ; cur != NULL ; cur = cur->next ) {
		if(cur->type == XML_ELEMENT_NODE) {
			if(xmlStrEqual(cur->name, (const xmlChar *) "label")) {
				self.label = [NSString deserializeNode:cur];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "value")) {
				[self addValue:[NSString deserializeNode:cur]];
			}
		}
	}
}
@end

@implementation WokSearchLiteService_liteRecord
- (id)init
{
	if((self = [super init])) {
		uid = nil;
		title = [[NSMutableArray alloc] init];
		source = [[NSMutableArray alloc] init];
		authors = [[NSMutableArray alloc] init];
		keywords = [[NSMutableArray alloc] init];
		other = [[NSMutableArray alloc] init];
	}
	
	return self;
}
- (void)dealloc
{
	if(uid != nil) [uid release];
	if(title != nil) [title release];
	if(source != nil) [source release];
	if(authors != nil) [authors release];
	if(keywords != nil) [keywords release];
	if(other != nil) [other release];
	
	[super dealloc];
}
- (void)addElementsToNode:(xmlNodePtr)node
{
	if(self.uid!= nil) {
		xmlAddChild(node, [self.uid xmlNodeForDoc:node->doc elementName:@"uid" elementNSPrefix:nil]);
	}
	if(self.title!= nil) {
		for(WokSearchLiteService_labelValuesPair * child in self.title) {
			xmlAddChild(node, [child xmlNodeForDoc:node->doc elementName:@"title" elementNSPrefix:nil]);
		}
	}
	if(self.source!= nil) {
		for(WokSearchLiteService_labelValuesPair * child in self.source) {
			xmlAddChild(node, [child xmlNodeForDoc:node->doc elementName:@"source" elementNSPrefix:nil]);
		}
	}
	if(self.authors!= nil) {
		for(WokSearchLiteService_labelValuesPair * child in self.authors) {
			xmlAddChild(node, [child xmlNodeForDoc:node->doc elementName:@"authors" elementNSPrefix:nil]);
		}
	}
	if(self.keywords!= nil) {
		for(WokSearchLiteService_labelValuesPair * child in self.keywords) {
			xmlAddChild(node, [child xmlNodeForDoc:node->doc elementName:@"keywords" elementNSPrefix:nil]);
		}
	}
	if(self.other!= nil) {
		for(WokSearchLiteService_labelValuesPair * child in self.other) {
			xmlAddChild(node, [child xmlNodeForDoc:node->doc elementName:@"other" elementNSPrefix:nil]);
		}
	}
}
@synthesize uid;
@synthesize title;
- (void)addTitle:(WokSearchLiteService_labelValuesPair *)toAdd
{
	if(toAdd != nil) [title addObject:toAdd];
}
@synthesize source;
- (void)addSource:(WokSearchLiteService_labelValuesPair *)toAdd
{
	if(toAdd != nil) [source addObject:toAdd];
}
@synthesize authors;
- (void)addAuthors:(WokSearchLiteService_labelValuesPair *)toAdd
{
	if(toAdd != nil) [authors addObject:toAdd];
}
@synthesize keywords;
- (void)addKeywords:(WokSearchLiteService_labelValuesPair *)toAdd
{
	if(toAdd != nil) [keywords addObject:toAdd];
}
@synthesize other;
- (void)addOther:(WokSearchLiteService_labelValuesPair *)toAdd
{
	if(toAdd != nil) [other addObject:toAdd];
}
- (void)deserializeElementsFromNode:(xmlNodePtr)cur
{
	for( cur = cur->children ; cur != NULL ; cur = cur->next ) {
		if(cur->type == XML_ELEMENT_NODE) {
			if(xmlStrEqual(cur->name, (const xmlChar *) "uid")) {
				self.uid = [NSString deserializeNode:cur];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "title")) {
				[self addTitle:[WokSearchLiteService_labelValuesPair deserializeNode:cur]];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "source")) {
				[self addSource:[WokSearchLiteService_labelValuesPair deserializeNode:cur]];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "authors")) {
				[self addAuthors:[WokSearchLiteService_labelValuesPair deserializeNode:cur]];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "keywords")) {
				[self addKeywords:[WokSearchLiteService_labelValuesPair deserializeNode:cur]];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "other")) {
				[self addOther:[WokSearchLiteService_labelValuesPair deserializeNode:cur]];
			}
		}
	}
}
@end

@implementation WokSearchLiteService_searchResults
- (id)init
{
	if((self = [super init])) {
		queryId = nil;
		recordsFound = nil;
		recordsSearched = nil;
		parent = nil;
		records = [[NSMutableArray alloc] init];
	}
	
	return self;
}
- (void)dealloc
{
	if(queryId != nil) [queryId release];
	if(recordsFound != nil) [recordsFound release];
	if(recordsSearched != nil) [recordsSearched release];
	if(parent != nil) [parent release];
	if(records != nil) [records release];
	
	[super dealloc];
}
- (void)addElementsToNode:(xmlNodePtr)node
{
	if(self.queryId!= nil) {
		xmlAddChild(node, [self.queryId xmlNodeForDoc:node->doc elementName:@"queryId" elementNSPrefix:nil]);
	}
	if(self.recordsFound!= nil) {
		xmlAddChild(node, [self.recordsFound xmlNodeForDoc:node->doc elementName:@"recordsFound" elementNSPrefix:nil]);
	}
	if(self.recordsSearched!= nil) {
		xmlAddChild(node, [self.recordsSearched xmlNodeForDoc:node->doc elementName:@"recordsSearched" elementNSPrefix:nil]);
	}
	if(self.parent!= nil) {
		xmlAddChild(node, [self.parent xmlNodeForDoc:node->doc elementName:@"parent" elementNSPrefix:nil]);
	}
	if(self.records!= nil) {
		for(WokSearchLiteService_liteRecord * child in self.records) {
			xmlAddChild(node, [child xmlNodeForDoc:node->doc elementName:@"records" elementNSPrefix:nil]);
		}
	}
}
@synthesize queryId;
@synthesize recordsFound;
@synthesize recordsSearched;
@synthesize parent;
@synthesize records;
- (void)addRecords:(WokSearchLiteService_liteRecord *)toAdd
{
	if(toAdd != nil) [records addObject:toAdd];
}
- (void)deserializeElementsFromNode:(xmlNodePtr)cur
{
	for( cur = cur->children ; cur != NULL ; cur = cur->next ) {
		if(cur->type == XML_ELEMENT_NODE) {
			if(xmlStrEqual(cur->name, (const xmlChar *) "queryId")) {
				self.queryId = [NSString deserializeNode:cur];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "recordsFound")) {
				self.recordsFound = [NSNumber deserializeNode:cur];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "recordsSearched")) {
				self.recordsSearched = [NSNumber deserializeNode:cur];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "parent")) {
				self.parent = [WokSearchLiteService_liteRecord deserializeNode:cur];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "records")) {
				[self addRecords:[WokSearchLiteService_liteRecord deserializeNode:cur]];
			}
		}
	}
}
@end

@implementation WokSearchLiteService_retrieveResponse
- (id)init
{
	if((self = [super init])) {
		return_ = nil;
	}
	
	return self;
}
- (void)dealloc
{
	if(return_ != nil) [return_ release];
	
	[super dealloc];
}
- (void)addElementsToNode:(xmlNodePtr)node
{
	if(self.return_!= nil) {
		xmlAddChild(node, [self.return_ xmlNodeForDoc:node->doc elementName:@"return" elementNSPrefix:nil]);
	}
}
@synthesize return_;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur
{
	for( cur = cur->children ; cur != NULL ; cur = cur->next ) {
		if(cur->type == XML_ELEMENT_NODE) {
			if(xmlStrEqual(cur->name, (const xmlChar *) "return")) {
				self.return_ = [WokSearchLiteService_searchResults deserializeNode:cur];
			}
		}
	}
}
@end

@implementation WokSearchLiteService_retrieveById
- (id)init
{
	if((self = [super init])) {
		databaseId = nil;
		uid = [[NSMutableArray alloc] init];
		queryLanguage = nil;
		retrieveParameters = nil;
	}
	
	return self;
}
- (void)dealloc
{
	if(databaseId != nil) [databaseId release];
	if(uid != nil) [uid release];
	if(queryLanguage != nil) [queryLanguage release];
	if(retrieveParameters != nil) [retrieveParameters release];
	
	[super dealloc];
}
- (void)addElementsToNode:(xmlNodePtr)node
{
	if(self.databaseId!= nil) {
		xmlAddChild(node, [self.databaseId xmlNodeForDoc:node->doc elementName:@"databaseId" elementNSPrefix:nil]);
	}
	if(self.uid!= nil) {
		for(NSString * child in self.uid) {
			xmlAddChild(node, [child xmlNodeForDoc:node->doc elementName:@"uid" elementNSPrefix:nil]);
		}
	}
	if(self.queryLanguage!= nil) {
		xmlAddChild(node, [self.queryLanguage xmlNodeForDoc:node->doc elementName:@"queryLanguage" elementNSPrefix:nil]);
	}
	if(self.retrieveParameters!= nil) {
		xmlAddChild(node, [self.retrieveParameters xmlNodeForDoc:node->doc elementName:@"retrieveParameters" elementNSPrefix:nil]);
	}
}
@synthesize databaseId;
@synthesize uid;
- (void)addUid:(NSString *)toAdd
{
	if(toAdd != nil) [uid addObject:toAdd];
}
@synthesize queryLanguage;
@synthesize retrieveParameters;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur
{
	for( cur = cur->children ; cur != NULL ; cur = cur->next ) {
		if(cur->type == XML_ELEMENT_NODE) {
			if(xmlStrEqual(cur->name, (const xmlChar *) "databaseId")) {
				self.databaseId = [NSString deserializeNode:cur];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "uid")) {
				[self addUid:[NSString deserializeNode:cur]];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "queryLanguage")) {
				self.queryLanguage = [NSString deserializeNode:cur];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "retrieveParameters")) {
				self.retrieveParameters = [WokSearchLiteService_retrieveParameters deserializeNode:cur];
			}
		}
	}
}
@end

@implementation WokSearchLiteService_retrieveByIdResponse
- (id)init
{
	if((self = [super init])) {
		return_ = nil;
	}
	
	return self;
}
- (void)dealloc
{
	if(return_ != nil) [return_ release];
	
	[super dealloc];
}
- (void)addElementsToNode:(xmlNodePtr)node
{
	if(self.return_!= nil) {
		xmlAddChild(node, [self.return_ xmlNodeForDoc:node->doc elementName:@"return" elementNSPrefix:nil]);
	}
}
@synthesize return_;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur
{
	for( cur = cur->children ; cur != NULL ; cur = cur->next ) {
		if(cur->type == XML_ELEMENT_NODE) {
			if(xmlStrEqual(cur->name, (const xmlChar *) "return")) {
				self.return_ = [WokSearchLiteService_searchResults deserializeNode:cur];
			}
		}
	}
}
@end

@implementation WokSearchLiteService_editionDesc
- (id)init
{
	if((self = [super init])) {
		collection = nil;
		edition = nil;
	}
	
	return self;
}
- (void)dealloc
{
	if(collection != nil) [collection release];
	if(edition != nil) [edition release];
	
	[super dealloc];
}
- (void)addElementsToNode:(xmlNodePtr)node
{
	if(self.collection!= nil) {
		xmlAddChild(node, [self.collection xmlNodeForDoc:node->doc elementName:@"collection" elementNSPrefix:nil]);
	}
	if(self.edition!= nil) {
		xmlAddChild(node, [self.edition xmlNodeForDoc:node->doc elementName:@"edition" elementNSPrefix:nil]);
	}
}
@synthesize collection;
@synthesize edition;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur
{
	for( cur = cur->children ; cur != NULL ; cur = cur->next ) {
		if(cur->type == XML_ELEMENT_NODE) {
			if(xmlStrEqual(cur->name, (const xmlChar *) "collection")) {
				self.collection = [NSString deserializeNode:cur];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "edition")) {
				self.edition = [NSString deserializeNode:cur];
			}
		}
	}
}
@end

@implementation WokSearchLiteService_timeSpan
- (id)init
{
	if((self = [super init])) {
		begin = nil;
		end = nil;
	}
	
	return self;
}
- (void)dealloc
{
	if(begin != nil) [begin release];
	if(end != nil) [end release];
	
	[super dealloc];
}
- (void)addElementsToNode:(xmlNodePtr)node
{
	if(self.begin!= nil) {
		xmlAddChild(node, [self.begin xmlNodeForDoc:node->doc elementName:@"begin" elementNSPrefix:nil]);
	}
	if(self.end!= nil) {
		xmlAddChild(node, [self.end xmlNodeForDoc:node->doc elementName:@"end" elementNSPrefix:nil]);
	}
}
@synthesize begin;
@synthesize end;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur
{
	for( cur = cur->children ; cur != NULL ; cur = cur->next ) {
		if(cur->type == XML_ELEMENT_NODE) {
			if(xmlStrEqual(cur->name, (const xmlChar *) "begin")) {
				self.begin = [NSString deserializeNode:cur];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "end")) {
				self.end = [NSString deserializeNode:cur];
			}
		}
	}
}
@end

@implementation WokSearchLiteService_queryParameters
- (id)init
{
	if((self = [super init])) {
		databaseId = nil;
		userQuery = nil;
		editions = [[NSMutableArray alloc] init];
		symbolicTimeSpan = nil;
		timeSpan = nil;
		queryLanguage = nil;
	}
	
	return self;
}
- (void)dealloc
{
	if(databaseId != nil) [databaseId release];
	if(userQuery != nil) [userQuery release];
	if(editions != nil) [editions release];
	if(symbolicTimeSpan != nil) [symbolicTimeSpan release];
	if(timeSpan != nil) [timeSpan release];
	if(queryLanguage != nil) [queryLanguage release];
	
	[super dealloc];
}
- (void)addElementsToNode:(xmlNodePtr)node
{
	if(self.databaseId!= nil) {
		xmlAddChild(node, [self.databaseId xmlNodeForDoc:node->doc elementName:@"databaseId" elementNSPrefix:nil]);
	}
	if(self.userQuery!= nil) {
		xmlAddChild(node, [self.userQuery xmlNodeForDoc:node->doc elementName:@"userQuery" elementNSPrefix:nil]);
	}
	if(self.editions!= nil) {
		for(WokSearchLiteService_editionDesc * child in self.editions) {
			xmlAddChild(node, [child xmlNodeForDoc:node->doc elementName:@"editions" elementNSPrefix:nil]);
		}
	}
	if(self.symbolicTimeSpan!= nil) {
		xmlAddChild(node, [self.symbolicTimeSpan xmlNodeForDoc:node->doc elementName:@"symbolicTimeSpan" elementNSPrefix:nil]);
	}
	if(self.timeSpan!= nil) {
		xmlAddChild(node, [self.timeSpan xmlNodeForDoc:node->doc elementName:@"timeSpan" elementNSPrefix:nil]);
	}
	if(self.queryLanguage!= nil) {
		xmlAddChild(node, [self.queryLanguage xmlNodeForDoc:node->doc elementName:@"queryLanguage" elementNSPrefix:nil]);
	}
}
@synthesize databaseId;
@synthesize userQuery;
@synthesize editions;
- (void)addEditions:(WokSearchLiteService_editionDesc *)toAdd
{
	if(toAdd != nil) [editions addObject:toAdd];
}
@synthesize symbolicTimeSpan;
@synthesize timeSpan;
@synthesize queryLanguage;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur
{
	for( cur = cur->children ; cur != NULL ; cur = cur->next ) {
		if(cur->type == XML_ELEMENT_NODE) {
			if(xmlStrEqual(cur->name, (const xmlChar *) "databaseId")) {
				self.databaseId = [NSString deserializeNode:cur];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "userQuery")) {
				self.userQuery = [NSString deserializeNode:cur];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "editions")) {
				[self addEditions:[WokSearchLiteService_editionDesc deserializeNode:cur]];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "symbolicTimeSpan")) {
				self.symbolicTimeSpan = [NSString deserializeNode:cur];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "timeSpan")) {
				self.timeSpan = [WokSearchLiteService_timeSpan deserializeNode:cur];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "queryLanguage")) {
				self.queryLanguage = [NSString deserializeNode:cur];
			}
		}
	}
}
@end

@implementation WokSearchLiteService_search
- (id)init
{
	if((self = [super init])) {
		queryParameters = nil;
		retrieveParameters = nil;
	}
	
	return self;
}
- (void)dealloc
{
	if(queryParameters != nil) [queryParameters release];
	if(retrieveParameters != nil) [retrieveParameters release];
	
	[super dealloc];
}
- (void)addElementsToNode:(xmlNodePtr)node
{
	if(self.queryParameters!= nil) {
		xmlAddChild(node, [self.queryParameters xmlNodeForDoc:node->doc elementName:@"queryParameters" elementNSPrefix:nil]);
	}
	if(self.retrieveParameters!= nil) {
		xmlAddChild(node, [self.retrieveParameters xmlNodeForDoc:node->doc elementName:@"retrieveParameters" elementNSPrefix:nil]);
	}
}
@synthesize queryParameters;
@synthesize retrieveParameters;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur
{
	for( cur = cur->children ; cur != NULL ; cur = cur->next ) {
		if(cur->type == XML_ELEMENT_NODE) {
			if(xmlStrEqual(cur->name, (const xmlChar *) "queryParameters")) {
				self.queryParameters = [WokSearchLiteService_queryParameters deserializeNode:cur];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "retrieveParameters")) {
				self.retrieveParameters = [WokSearchLiteService_retrieveParameters deserializeNode:cur];
			}
		}
	}
}
@end

@implementation WokSearchLiteService_searchResponse
- (id)init
{
	if((self = [super init])) {
		return_ = nil;
	}
	
	return self;
}
- (void)dealloc
{
	if(return_ != nil) [return_ release];
	
	[super dealloc];
}
- (void)addElementsToNode:(xmlNodePtr)node
{
	if(self.return_!= nil) {
		xmlAddChild(node, [self.return_ xmlNodeForDoc:node->doc elementName:@"return" elementNSPrefix:nil]);
	}
}
@synthesize return_;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur
{
	for( cur = cur->children ; cur != NULL ; cur = cur->next ) {
		if(cur->type == XML_ELEMENT_NODE) {
			if(xmlStrEqual(cur->name, (const xmlChar *) "return")) {
				self.return_ = [WokSearchLiteService_searchResults deserializeNode:cur];
			}
		}
	}
}
@end

@implementation WokSearchLiteService
+ (NSString *)address
{
	return @"http://search.webofknowledge.com/esti/wokmws/ws/WokSearchLite";
}
+ (NSString *)namespaceURI
{
	return @"http://woksearchlite.v3.wokmws.thomsonreuters.com";
}
- (WokServiceSoapBindingResponse *)searchUsingParameters:(WokSearchLiteService_search *)parameters
{
	NSDictionary *bodyElements = [NSDictionary dictionaryWithObjectsAndKeys:parameters, @"search", nil];
	NSDictionary *responseClasses = [NSDictionary dictionaryWithObjectsAndKeys:[WokSearchLiteService_searchResponse class], @"searchResponse", nil];
	return [self performSynchronousOperation:[[[WokServiceSoapBindingOperation alloc] initWithBinding:self delegate:self bodyElements:bodyElements responseClasses:responseClasses] autorelease]];
}
- (WokServiceSoapBindingResponse *)retrieveUsingParameters:(WokSearchLiteService_retrieve *)parameters
{
	NSDictionary *bodyElements = [NSDictionary dictionaryWithObjectsAndKeys:parameters, @"retrieve", nil];
	NSDictionary *responseClasses = [NSDictionary dictionaryWithObjectsAndKeys:[WokSearchLiteService_retrieveResponse class], @"retrieveResponse", nil];
	return [self performSynchronousOperation:[[[WokServiceSoapBindingOperation alloc] initWithBinding:self delegate:self bodyElements:bodyElements responseClasses:responseClasses] autorelease]];
}
- (WokServiceSoapBindingResponse *)retrieveByIdUsingParameters:(WokSearchLiteService_retrieveById *)parameters
{
	NSDictionary *bodyElements = [NSDictionary dictionaryWithObjectsAndKeys:parameters, @"retrieveById", nil];
	NSDictionary *responseClasses = [NSDictionary dictionaryWithObjectsAndKeys:[WokSearchLiteService_retrieveByIdResponse class], @"retrieveByIdResponse", nil];
	return [self performSynchronousOperation:[[[WokServiceSoapBindingOperation alloc] initWithBinding:self delegate:self bodyElements:bodyElements responseClasses:responseClasses] autorelease]];
}
@end

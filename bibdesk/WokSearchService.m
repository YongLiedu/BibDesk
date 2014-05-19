#import "WokSearchService.h"

@implementation WokSearchService_sortField
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

@implementation WokSearchService_viewField
- (id)init
{
	if((self = [super init])) {
		collectionName = nil;
		fieldName = [[NSMutableArray alloc] init];
	}
	
	return self;
}
- (void)dealloc
{
	if(collectionName != nil) [collectionName release];
	if(fieldName != nil) [fieldName release];
	
	[super dealloc];
}
- (void)addElementsToNode:(xmlNodePtr)node
{
	if(self.collectionName!= nil) {
		xmlAddChild(node, [self.collectionName xmlNodeForDoc:node->doc elementName:@"collectionName" elementNSPrefix:nil]);
	}
	if(self.fieldName!= nil) {
		for(NSString * child in self.fieldName) {
			xmlAddChild(node, [child xmlNodeForDoc:node->doc elementName:@"fieldName" elementNSPrefix:nil]);
		}
	}
}
@synthesize collectionName;
@synthesize fieldName;
- (void)addFieldName:(NSString *)toAdd
{
	if(toAdd != nil) [fieldName addObject:toAdd];
}
- (void)deserializeElementsFromNode:(xmlNodePtr)cur
{
	for( cur = cur->children ; cur != NULL ; cur = cur->next ) {
		if(cur->type == XML_ELEMENT_NODE) {
			if(xmlStrEqual(cur->name, (const xmlChar *) "collectionName")) {
				self.collectionName = [NSString deserializeNode:cur];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "fieldName")) {
				[self addFieldName:[NSString deserializeNode:cur]];
			}
		}
	}
}
@end

@implementation WokSearchService_keyValuePair
- (id)init
{
	if((self = [super init])) {
		key = nil;
		value = nil;
	}
	
	return self;
}
- (void)dealloc
{
	if(key != nil) [key release];
	if(value != nil) [value release];
	
	[super dealloc];
}
- (void)addElementsToNode:(xmlNodePtr)node
{
	if(self.key!= nil) {
		xmlAddChild(node, [self.key xmlNodeForDoc:node->doc elementName:@"key" elementNSPrefix:nil]);
	}
	if(self.value!= nil) {
		xmlAddChild(node, [self.value xmlNodeForDoc:node->doc elementName:@"value" elementNSPrefix:nil]);
	}
}
@synthesize key;
@synthesize value;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur
{
	for( cur = cur->children ; cur != NULL ; cur = cur->next ) {
		if(cur->type == XML_ELEMENT_NODE) {
			if(xmlStrEqual(cur->name, (const xmlChar *) "key")) {
				self.key = [NSString deserializeNode:cur];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "value")) {
				self.value = [NSString deserializeNode:cur];
			}
		}
	}
}
@end

@implementation WokSearchService_retrieveParameters
- (id)init
{
	if((self = [super init])) {
		firstRecord = nil;
		count = nil;
		sortField = [[NSMutableArray alloc] init];
		viewField = [[NSMutableArray alloc] init];
		option = [[NSMutableArray alloc] init];
	}
	
	return self;
}
- (void)dealloc
{
	if(firstRecord != nil) [firstRecord release];
	if(count != nil) [count release];
	if(sortField != nil) [sortField release];
	if(viewField != nil) [viewField release];
	if(option != nil) [option release];
	
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
		for(WokSearchService_sortField * child in self.sortField) {
			xmlAddChild(node, [child xmlNodeForDoc:node->doc elementName:@"sortField" elementNSPrefix:nil]);
		}
	}
	if(self.viewField!= nil) {
		for(WokSearchService_viewField * child in self.viewField) {
			xmlAddChild(node, [child xmlNodeForDoc:node->doc elementName:@"viewField" elementNSPrefix:nil]);
		}
	}
	if(self.option!= nil) {
		for(WokSearchService_keyValuePair * child in self.option) {
			xmlAddChild(node, [child xmlNodeForDoc:node->doc elementName:@"option" elementNSPrefix:nil]);
		}
	}
}
@synthesize firstRecord;
@synthesize count;
@synthesize sortField;
- (void)addSortField:(WokSearchService_sortField *)toAdd
{
	if(toAdd != nil) [sortField addObject:toAdd];
}
@synthesize viewField;
- (void)addViewField:(WokSearchService_viewField *)toAdd
{
	if(toAdd != nil) [viewField addObject:toAdd];
}
@synthesize option;
- (void)addOption:(WokSearchService_keyValuePair *)toAdd
{
	if(toAdd != nil) [option addObject:toAdd];
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
				[self addSortField:[WokSearchService_sortField deserializeNode:cur]];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "viewField")) {
				[self addViewField:[WokSearchService_viewField deserializeNode:cur]];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "option")) {
				[self addOption:[WokSearchService_keyValuePair deserializeNode:cur]];
			}
		}
	}
}
@end

@implementation WokSearchService_citedReferences
- (id)init
{
	if((self = [super init])) {
		databaseId = nil;
		uid = nil;
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
		xmlAddChild(node, [self.uid xmlNodeForDoc:node->doc elementName:@"uid" elementNSPrefix:nil]);
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
				self.uid = [NSString deserializeNode:cur];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "queryLanguage")) {
				self.queryLanguage = [NSString deserializeNode:cur];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "retrieveParameters")) {
				self.retrieveParameters = [WokSearchService_retrieveParameters deserializeNode:cur];
			}
		}
	}
}
@end

@implementation WokSearchService_citedReference
- (id)init
{
	if((self = [super init])) {
		uid = nil;
		docid = nil;
		articleId = nil;
		citedAuthor = nil;
		timesCited = nil;
		year = nil;
		page = nil;
		volume = nil;
		citedTitle = nil;
		citedWork = nil;
		hot = nil;
	}
	
	return self;
}
- (void)dealloc
{
	if(uid != nil) [uid release];
	if(docid != nil) [docid release];
	if(articleId != nil) [articleId release];
	if(citedAuthor != nil) [citedAuthor release];
	if(timesCited != nil) [timesCited release];
	if(year != nil) [year release];
	if(page != nil) [page release];
	if(volume != nil) [volume release];
	if(citedTitle != nil) [citedTitle release];
	if(citedWork != nil) [citedWork release];
	if(hot != nil) [hot release];
	
	[super dealloc];
}
- (void)addElementsToNode:(xmlNodePtr)node
{
	if(self.uid!= nil) {
		xmlAddChild(node, [self.uid xmlNodeForDoc:node->doc elementName:@"uid" elementNSPrefix:nil]);
	}
	if(self.docid!= nil) {
		xmlAddChild(node, [self.docid xmlNodeForDoc:node->doc elementName:@"docid" elementNSPrefix:nil]);
	}
	if(self.articleId!= nil) {
		xmlAddChild(node, [self.articleId xmlNodeForDoc:node->doc elementName:@"articleId" elementNSPrefix:nil]);
	}
	if(self.citedAuthor!= nil) {
		xmlAddChild(node, [self.citedAuthor xmlNodeForDoc:node->doc elementName:@"citedAuthor" elementNSPrefix:nil]);
	}
	if(self.timesCited!= nil) {
		xmlAddChild(node, [self.timesCited xmlNodeForDoc:node->doc elementName:@"timesCited" elementNSPrefix:nil]);
	}
	if(self.year!= nil) {
		xmlAddChild(node, [self.year xmlNodeForDoc:node->doc elementName:@"year" elementNSPrefix:nil]);
	}
	if(self.page!= nil) {
		xmlAddChild(node, [self.page xmlNodeForDoc:node->doc elementName:@"page" elementNSPrefix:nil]);
	}
	if(self.volume!= nil) {
		xmlAddChild(node, [self.volume xmlNodeForDoc:node->doc elementName:@"volume" elementNSPrefix:nil]);
	}
	if(self.citedTitle!= nil) {
		xmlAddChild(node, [self.citedTitle xmlNodeForDoc:node->doc elementName:@"citedTitle" elementNSPrefix:nil]);
	}
	if(self.citedWork!= nil) {
		xmlAddChild(node, [self.citedWork xmlNodeForDoc:node->doc elementName:@"citedWork" elementNSPrefix:nil]);
	}
	if(self.hot!= nil) {
		xmlAddChild(node, [self.hot xmlNodeForDoc:node->doc elementName:@"hot" elementNSPrefix:nil]);
	}
}
@synthesize uid;
@synthesize docid;
@synthesize articleId;
@synthesize citedAuthor;
@synthesize timesCited;
@synthesize year;
@synthesize page;
@synthesize volume;
@synthesize citedTitle;
@synthesize citedWork;
@synthesize hot;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur
{
	for( cur = cur->children ; cur != NULL ; cur = cur->next ) {
		if(cur->type == XML_ELEMENT_NODE) {
			if(xmlStrEqual(cur->name, (const xmlChar *) "uid")) {
				self.uid = [NSString deserializeNode:cur];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "docid")) {
				self.docid = [NSString deserializeNode:cur];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "articleId")) {
				self.articleId = [NSString deserializeNode:cur];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "citedAuthor")) {
				self.citedAuthor = [NSString deserializeNode:cur];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "timesCited")) {
				self.timesCited = [NSString deserializeNode:cur];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "year")) {
				self.year = [NSString deserializeNode:cur];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "page")) {
				self.page = [NSString deserializeNode:cur];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "volume")) {
				self.volume = [NSString deserializeNode:cur];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "citedTitle")) {
				self.citedTitle = [NSString deserializeNode:cur];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "citedWork")) {
				self.citedWork = [NSString deserializeNode:cur];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "hot")) {
				self.hot = [NSString deserializeNode:cur];
			}
		}
	}
}
@end

@implementation WokSearchService_citedReferencesSearchResults
- (id)init
{
	if((self = [super init])) {
		queryId = nil;
		references = [[NSMutableArray alloc] init];
		recordsFound = nil;
		recordsSearched = nil;
	}
	
	return self;
}
- (void)dealloc
{
	if(queryId != nil) [queryId release];
	if(references != nil) [references release];
	if(recordsFound != nil) [recordsFound release];
	if(recordsSearched != nil) [recordsSearched release];
	
	[super dealloc];
}
- (void)addElementsToNode:(xmlNodePtr)node
{
	if(self.queryId!= nil) {
		xmlAddChild(node, [self.queryId xmlNodeForDoc:node->doc elementName:@"queryId" elementNSPrefix:nil]);
	}
	if(self.references!= nil) {
		for(WokSearchService_citedReference * child in self.references) {
			xmlAddChild(node, [child xmlNodeForDoc:node->doc elementName:@"references" elementNSPrefix:nil]);
		}
	}
	if(self.recordsFound!= nil) {
		xmlAddChild(node, [self.recordsFound xmlNodeForDoc:node->doc elementName:@"recordsFound" elementNSPrefix:nil]);
	}
	if(self.recordsSearched!= nil) {
		xmlAddChild(node, [self.recordsSearched xmlNodeForDoc:node->doc elementName:@"recordsSearched" elementNSPrefix:nil]);
	}
}
@synthesize queryId;
@synthesize references;
- (void)addReferences:(WokSearchService_citedReference *)toAdd
{
	if(toAdd != nil) [references addObject:toAdd];
}
@synthesize recordsFound;
@synthesize recordsSearched;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur
{
	for( cur = cur->children ; cur != NULL ; cur = cur->next ) {
		if(cur->type == XML_ELEMENT_NODE) {
			if(xmlStrEqual(cur->name, (const xmlChar *) "queryId")) {
				self.queryId = [NSString deserializeNode:cur];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "references")) {
				[self addReferences:[WokSearchService_citedReference deserializeNode:cur]];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "recordsFound")) {
				self.recordsFound = [NSNumber deserializeNode:cur];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "recordsSearched")) {
				self.recordsSearched = [NSNumber deserializeNode:cur];
			}
		}
	}
}
@end

@implementation WokSearchService_citedReferencesResponse
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
				self.return_ = [WokSearchService_citedReferencesSearchResults deserializeNode:cur];
			}
		}
	}
}
@end

@implementation WokSearchService_citedReferencesRetrieve
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
				self.retrieveParameters = [WokSearchService_retrieveParameters deserializeNode:cur];
			}
		}
	}
}
@end

@implementation WokSearchService_citedReferencesRetrieveResponse
- (id)init
{
	if((self = [super init])) {
		return_ = [[NSMutableArray alloc] init];
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
		for(WokSearchService_citedReference * child in self.return_) {
			xmlAddChild(node, [child xmlNodeForDoc:node->doc elementName:@"return" elementNSPrefix:nil]);
		}
	}
}
@synthesize return_;
- (void)addReturn_:(WokSearchService_citedReference *)toAdd
{
	if(toAdd != nil) [return_ addObject:toAdd];
}
- (void)deserializeElementsFromNode:(xmlNodePtr)cur
{
	for( cur = cur->children ; cur != NULL ; cur = cur->next ) {
		if(cur->type == XML_ELEMENT_NODE) {
			if(xmlStrEqual(cur->name, (const xmlChar *) "return")) {
				[self addReturn_:[WokSearchService_citedReference deserializeNode:cur]];
			}
		}
	}
}
@end

@implementation WokSearchService_editionDesc
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

@implementation WokSearchService_timeSpan
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

@implementation WokSearchService_citingArticles
- (id)init
{
	if((self = [super init])) {
		databaseId = nil;
		uid = nil;
		editions = [[NSMutableArray alloc] init];
		timeSpan = nil;
		queryLanguage = nil;
		retrieveParameters = nil;
	}
	
	return self;
}
- (void)dealloc
{
	if(databaseId != nil) [databaseId release];
	if(uid != nil) [uid release];
	if(editions != nil) [editions release];
	if(timeSpan != nil) [timeSpan release];
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
		xmlAddChild(node, [self.uid xmlNodeForDoc:node->doc elementName:@"uid" elementNSPrefix:nil]);
	}
	if(self.editions!= nil) {
		for(WokSearchService_editionDesc * child in self.editions) {
			xmlAddChild(node, [child xmlNodeForDoc:node->doc elementName:@"editions" elementNSPrefix:nil]);
		}
	}
	if(self.timeSpan!= nil) {
		xmlAddChild(node, [self.timeSpan xmlNodeForDoc:node->doc elementName:@"timeSpan" elementNSPrefix:nil]);
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
@synthesize editions;
- (void)addEditions:(WokSearchService_editionDesc *)toAdd
{
	if(toAdd != nil) [editions addObject:toAdd];
}
@synthesize timeSpan;
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
				self.uid = [NSString deserializeNode:cur];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "editions")) {
				[self addEditions:[WokSearchService_editionDesc deserializeNode:cur]];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "timeSpan")) {
				self.timeSpan = [WokSearchService_timeSpan deserializeNode:cur];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "queryLanguage")) {
				self.queryLanguage = [NSString deserializeNode:cur];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "retrieveParameters")) {
				self.retrieveParameters = [WokSearchService_retrieveParameters deserializeNode:cur];
			}
		}
	}
}
@end

@implementation WokSearchService_labelValuesPair
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

@implementation WokSearchService_fullRecordSearchResults
- (id)init
{
	if((self = [super init])) {
		queryId = nil;
		recordsFound = nil;
		recordsSearched = nil;
		parent = nil;
		optionValue = [[NSMutableArray alloc] init];
		records = nil;
	}
	
	return self;
}
- (void)dealloc
{
	if(queryId != nil) [queryId release];
	if(recordsFound != nil) [recordsFound release];
	if(recordsSearched != nil) [recordsSearched release];
	if(parent != nil) [parent release];
	if(optionValue != nil) [optionValue release];
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
	if(self.optionValue!= nil) {
		for(WokSearchService_labelValuesPair * child in self.optionValue) {
			xmlAddChild(node, [child xmlNodeForDoc:node->doc elementName:@"optionValue" elementNSPrefix:nil]);
		}
	}
	if(self.records!= nil) {
		xmlAddChild(node, [self.records xmlNodeForDoc:node->doc elementName:@"records" elementNSPrefix:nil]);
	}
}
@synthesize queryId;
@synthesize recordsFound;
@synthesize recordsSearched;
@synthesize parent;
@synthesize optionValue;
- (void)addOptionValue:(WokSearchService_labelValuesPair *)toAdd
{
	if(toAdd != nil) [optionValue addObject:toAdd];
}
@synthesize records;
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
				self.parent = [NSString deserializeNode:cur];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "optionValue")) {
				[self addOptionValue:[WokSearchService_labelValuesPair deserializeNode:cur]];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "records")) {
				self.records = [NSString deserializeNode:cur];
			}
		}
	}
}
@end

@implementation WokSearchService_citingArticlesResponse
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
				self.return_ = [WokSearchService_fullRecordSearchResults deserializeNode:cur];
			}
		}
	}
}
@end

@implementation WokSearchService_relatedRecords
- (id)init
{
	if((self = [super init])) {
		databaseId = nil;
		uid = nil;
		editions = [[NSMutableArray alloc] init];
		timeSpan = nil;
		queryLanguage = nil;
		retrieveParameters = nil;
	}
	
	return self;
}
- (void)dealloc
{
	if(databaseId != nil) [databaseId release];
	if(uid != nil) [uid release];
	if(editions != nil) [editions release];
	if(timeSpan != nil) [timeSpan release];
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
		xmlAddChild(node, [self.uid xmlNodeForDoc:node->doc elementName:@"uid" elementNSPrefix:nil]);
	}
	if(self.editions!= nil) {
		for(WokSearchService_editionDesc * child in self.editions) {
			xmlAddChild(node, [child xmlNodeForDoc:node->doc elementName:@"editions" elementNSPrefix:nil]);
		}
	}
	if(self.timeSpan!= nil) {
		xmlAddChild(node, [self.timeSpan xmlNodeForDoc:node->doc elementName:@"timeSpan" elementNSPrefix:nil]);
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
@synthesize editions;
- (void)addEditions:(WokSearchService_editionDesc *)toAdd
{
	if(toAdd != nil) [editions addObject:toAdd];
}
@synthesize timeSpan;
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
				self.uid = [NSString deserializeNode:cur];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "editions")) {
				[self addEditions:[WokSearchService_editionDesc deserializeNode:cur]];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "timeSpan")) {
				self.timeSpan = [WokSearchService_timeSpan deserializeNode:cur];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "queryLanguage")) {
				self.queryLanguage = [NSString deserializeNode:cur];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "retrieveParameters")) {
				self.retrieveParameters = [WokSearchService_retrieveParameters deserializeNode:cur];
			}
		}
	}
}
@end

@implementation WokSearchService_relatedRecordsResponse
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
				self.return_ = [WokSearchService_fullRecordSearchResults deserializeNode:cur];
			}
		}
	}
}
@end

@implementation WokSearchService_retrieve
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
				self.retrieveParameters = [WokSearchService_retrieveParameters deserializeNode:cur];
			}
		}
	}
}
@end

@implementation WokSearchService_fullRecordData
- (id)init
{
	if((self = [super init])) {
		optionValue = [[NSMutableArray alloc] init];
		records = nil;
	}
	
	return self;
}
- (void)dealloc
{
	if(optionValue != nil) [optionValue release];
	if(records != nil) [records release];
	
	[super dealloc];
}
- (void)addElementsToNode:(xmlNodePtr)node
{
	if(self.optionValue!= nil) {
		for(WokSearchService_labelValuesPair * child in self.optionValue) {
			xmlAddChild(node, [child xmlNodeForDoc:node->doc elementName:@"optionValue" elementNSPrefix:nil]);
		}
	}
	if(self.records!= nil) {
		xmlAddChild(node, [self.records xmlNodeForDoc:node->doc elementName:@"records" elementNSPrefix:nil]);
	}
}
@synthesize optionValue;
- (void)addOptionValue:(WokSearchService_labelValuesPair *)toAdd
{
	if(toAdd != nil) [optionValue addObject:toAdd];
}
@synthesize records;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur
{
	for( cur = cur->children ; cur != NULL ; cur = cur->next ) {
		if(cur->type == XML_ELEMENT_NODE) {
			if(xmlStrEqual(cur->name, (const xmlChar *) "optionValue")) {
				[self addOptionValue:[WokSearchService_labelValuesPair deserializeNode:cur]];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "records")) {
				self.records = [NSString deserializeNode:cur];
			}
		}
	}
}
@end

@implementation WokSearchService_retrieveResponse
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
				self.return_ = [WokSearchService_fullRecordData deserializeNode:cur];
			}
		}
	}
}
@end

@implementation WokSearchService_retrieveById
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
				self.retrieveParameters = [WokSearchService_retrieveParameters deserializeNode:cur];
			}
		}
	}
}
@end

@implementation WokSearchService_retrieveByIdResponse
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
				self.return_ = [WokSearchService_fullRecordSearchResults deserializeNode:cur];
			}
		}
	}
}
@end

@implementation WokSearchService_queryParameters
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
		for(WokSearchService_editionDesc * child in self.editions) {
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
- (void)addEditions:(WokSearchService_editionDesc *)toAdd
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
				[self addEditions:[WokSearchService_editionDesc deserializeNode:cur]];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "symbolicTimeSpan")) {
				self.symbolicTimeSpan = [NSString deserializeNode:cur];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "timeSpan")) {
				self.timeSpan = [WokSearchService_timeSpan deserializeNode:cur];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "queryLanguage")) {
				self.queryLanguage = [NSString deserializeNode:cur];
			}
		}
	}
}
@end

@implementation WokSearchService_search
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
				self.queryParameters = [WokSearchService_queryParameters deserializeNode:cur];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "retrieveParameters")) {
				self.retrieveParameters = [WokSearchService_retrieveParameters deserializeNode:cur];
			}
		}
	}
}
@end

@implementation WokSearchService_searchResponse
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
				self.return_ = [WokSearchService_fullRecordSearchResults deserializeNode:cur];
			}
		}
	}
}
@end

@implementation WokSearchService
+ (NSString *)address
{
	return @"http://search.webofknowledge.com/esti/wokmws/ws/WokSearch";
}
+ (NSString *)namespaceURI
{
	return @"http://woksearch.v3.wokmws.thomsonreuters.com";
}
- (WokServiceSoapBindingResponse *)searchUsingParameters:(WokSearchService_search *)parameters
{
	NSDictionary *bodyElements = [NSDictionary dictionaryWithObjectsAndKeys:parameters, @"search", nil];
	NSDictionary *responseClasses = [NSDictionary dictionaryWithObjectsAndKeys:[WokSearchService_searchResponse class], @"searchResponse", nil];
	return [self performSynchronousOperation:[[[WokServiceSoapBindingOperation alloc] initWithBinding:self delegate:self bodyElements:bodyElements responseClasses:responseClasses] autorelease]];
}
- (WokServiceSoapBindingResponse *)citedReferencesUsingParameters:(WokSearchService_citedReferences *)parameters
{
	NSDictionary *bodyElements = [NSDictionary dictionaryWithObjectsAndKeys:parameters, @"citedReferences", nil];
	NSDictionary *responseClasses = [NSDictionary dictionaryWithObjectsAndKeys:[WokSearchService_citedReferencesResponse class], @"citedReferencesResponse", nil];
	return [self performSynchronousOperation:[[[WokServiceSoapBindingOperation alloc] initWithBinding:self delegate:self bodyElements:bodyElements responseClasses:responseClasses] autorelease]];
}
- (WokServiceSoapBindingResponse *)citedReferencesRetrieveUsingParameters:(WokSearchService_citedReferencesRetrieve *)parameters
{
	NSDictionary *bodyElements = [NSDictionary dictionaryWithObjectsAndKeys:parameters, @"citedReferencesRetrieve", nil];
	NSDictionary *responseClasses = [NSDictionary dictionaryWithObjectsAndKeys:[WokSearchService_citedReferencesRetrieveResponse class], @"citedReferencesRetrieveResponse", nil];
	return [self performSynchronousOperation:[[[WokServiceSoapBindingOperation alloc] initWithBinding:self delegate:self bodyElements:bodyElements responseClasses:responseClasses] autorelease]];
}
- (WokServiceSoapBindingResponse *)citingArticlesUsingParameters:(WokSearchService_citingArticles *)parameters
{
	NSDictionary *bodyElements = [NSDictionary dictionaryWithObjectsAndKeys:parameters, @"citingArticles", nil];
	NSDictionary *responseClasses = [NSDictionary dictionaryWithObjectsAndKeys:[WokSearchService_citingArticlesResponse class], @"citingArticlesResponse", nil];
	return [self performSynchronousOperation:[[[WokServiceSoapBindingOperation alloc] initWithBinding:self delegate:self bodyElements:bodyElements responseClasses:responseClasses] autorelease]];
}
- (WokServiceSoapBindingResponse *)relatedRecordsUsingParameters:(WokSearchService_relatedRecords *)parameters
{
	NSDictionary *bodyElements = [NSDictionary dictionaryWithObjectsAndKeys:parameters, @"relatedRecords", nil];
	NSDictionary *responseClasses = [NSDictionary dictionaryWithObjectsAndKeys:[WokSearchService_relatedRecordsResponse class], @"relatedRecordsResponse", nil];
	return [self performSynchronousOperation:[[[WokServiceSoapBindingOperation alloc] initWithBinding:self delegate:self bodyElements:bodyElements responseClasses:responseClasses] autorelease]];
}
- (WokServiceSoapBindingResponse *)retrieveUsingParameters:(WokSearchService_retrieve *)parameters
{
	NSDictionary *bodyElements = [NSDictionary dictionaryWithObjectsAndKeys:parameters, @"retrieve", nil];
	NSDictionary *responseClasses = [NSDictionary dictionaryWithObjectsAndKeys:[WokSearchService_retrieveResponse class], @"retrieveResponse", nil];
	return [self performSynchronousOperation:[[[WokServiceSoapBindingOperation alloc] initWithBinding:self delegate:self bodyElements:bodyElements responseClasses:responseClasses] autorelease]];
}
- (WokServiceSoapBindingResponse *)retrieveByIdUsingParameters:(WokSearchService_retrieveById *)parameters
{
	NSDictionary *bodyElements = [NSDictionary dictionaryWithObjectsAndKeys:parameters, @"retrieveById", nil];
	NSDictionary *responseClasses = [NSDictionary dictionaryWithObjectsAndKeys:[WokSearchService_retrieveByIdResponse class], @"retrieveByIdResponse", nil];
	return [self performSynchronousOperation:[[[WokServiceSoapBindingOperation alloc] initWithBinding:self delegate:self bodyElements:bodyElements responseClasses:responseClasses] autorelease]];
}
@end

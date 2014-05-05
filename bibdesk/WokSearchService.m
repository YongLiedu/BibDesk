#import "WokSearchService.h"

@implementation WokSearchServiceElement
- (xmlNodePtr)xmlNodeForDoc:(xmlDocPtr)doc elementName:(NSString *)elName elementNSPrefix:(NSString *)elNSPrefix
{
	NSString *nodeName = nil;
	if(elNSPrefix != nil && [elNSPrefix length] > 0)
	{
		nodeName = [NSString stringWithFormat:@"%@:%@", elNSPrefix, elName];
	}
	else
	{
		nodeName = elName;
	}
	
	xmlNodePtr node = xmlNewDocNode(doc, NULL, [nodeName xmlCString], NULL);
	
	[self addElementsToNode:node];
	
	return node;
}
- (void)addElementsToNode:(xmlNodePtr)node
{
}
+ (id)deserializeNode:(xmlNodePtr)cur
{
	id newObject = [[self new] autorelease];
	
	[newObject deserializeElementsFromNode:cur];
	
	return newObject;
}
- (void)deserializeElementsFromNode:(xmlNodePtr)cur
{
}
@end

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
				id newChild = [NSString deserializeNode:cur];
				self.name = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "sort")) {
				id newChild = [NSString deserializeNode:cur];
				self.sort = newChild;
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
				id newChild = [NSString deserializeNode:cur];
				self.collectionName = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "fieldName")) {
				id newChild = [NSString deserializeNode:cur];
				if(newChild != nil) [self.fieldName addObject:newChild];
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
				id newChild = [NSString deserializeNode:cur];
				self.key = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "value")) {
				id newChild = [NSString deserializeNode:cur];
				self.value = newChild;
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
				id newChild = [NSNumber deserializeNode:cur];
				self.firstRecord = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "count")) {
				id newChild = [NSNumber deserializeNode:cur];
				self.count = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "sortField")) {
				id newChild = [WokSearchService_sortField deserializeNode:cur];
				if(newChild != nil) [self.sortField addObject:newChild];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "viewField")) {
				id newChild = [WokSearchService_viewField deserializeNode:cur];
				if(newChild != nil) [self.viewField addObject:newChild];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "option")) {
				id newChild = [WokSearchService_keyValuePair deserializeNode:cur];
				if(newChild != nil) [self.option addObject:newChild];
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
				id newChild = [NSString deserializeNode:cur];
				self.databaseId = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "uid")) {
				id newChild = [NSString deserializeNode:cur];
				self.uid = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "queryLanguage")) {
				id newChild = [NSString deserializeNode:cur];
				self.queryLanguage = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "retrieveParameters")) {
				id newChild = [WokSearchService_retrieveParameters deserializeNode:cur];
				self.retrieveParameters = newChild;
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
				id newChild = [NSString deserializeNode:cur];
				self.uid = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "docid")) {
				id newChild = [NSString deserializeNode:cur];
				self.docid = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "articleId")) {
				id newChild = [NSString deserializeNode:cur];
				self.articleId = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "citedAuthor")) {
				id newChild = [NSString deserializeNode:cur];
				self.citedAuthor = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "timesCited")) {
				id newChild = [NSString deserializeNode:cur];
				self.timesCited = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "year")) {
				id newChild = [NSString deserializeNode:cur];
				self.year = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "page")) {
				id newChild = [NSString deserializeNode:cur];
				self.page = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "volume")) {
				id newChild = [NSString deserializeNode:cur];
				self.volume = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "citedTitle")) {
				id newChild = [NSString deserializeNode:cur];
				self.citedTitle = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "citedWork")) {
				id newChild = [NSString deserializeNode:cur];
				self.citedWork = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "hot")) {
				id newChild = [NSString deserializeNode:cur];
				self.hot = newChild;
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
				id newChild = [NSString deserializeNode:cur];
				self.queryId = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "references")) {
				id newChild = [WokSearchService_citedReference deserializeNode:cur];
				if(newChild != nil) [self.references addObject:newChild];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "recordsFound")) {
				id newChild = [NSNumber deserializeNode:cur];
				self.recordsFound = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "recordsSearched")) {
				id newChild = [NSNumber deserializeNode:cur];
				self.recordsSearched = newChild;
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
				id newChild = [WokSearchService_citedReferencesSearchResults deserializeNode:cur];
				self.return_ = newChild;
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
				id newChild = [NSString deserializeNode:cur];
				self.queryId = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "retrieveParameters")) {
				id newChild = [WokSearchService_retrieveParameters deserializeNode:cur];
				self.retrieveParameters = newChild;
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
				id newChild = [WokSearchService_citedReference deserializeNode:cur];
				if(newChild != nil) [self.return_ addObject:newChild];
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
				id newChild = [NSString deserializeNode:cur];
				self.collection = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "edition")) {
				id newChild = [NSString deserializeNode:cur];
				self.edition = newChild;
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
				id newChild = [NSString deserializeNode:cur];
				self.begin = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "end")) {
				id newChild = [NSString deserializeNode:cur];
				self.end = newChild;
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
				id newChild = [NSString deserializeNode:cur];
				self.databaseId = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "uid")) {
				id newChild = [NSString deserializeNode:cur];
				self.uid = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "editions")) {
				id newChild = [WokSearchService_editionDesc deserializeNode:cur];
				if(newChild != nil) [self.editions addObject:newChild];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "timeSpan")) {
				id newChild = [WokSearchService_timeSpan deserializeNode:cur];
				self.timeSpan = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "queryLanguage")) {
				id newChild = [NSString deserializeNode:cur];
				self.queryLanguage = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "retrieveParameters")) {
				id newChild = [WokSearchService_retrieveParameters deserializeNode:cur];
				self.retrieveParameters = newChild;
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
				id newChild = [NSString deserializeNode:cur];
				self.label = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "value")) {
				id newChild = [NSString deserializeNode:cur];
				if(newChild != nil) [self.value addObject:newChild];
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
				id newChild = [NSString deserializeNode:cur];
				self.queryId = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "recordsFound")) {
				id newChild = [NSNumber deserializeNode:cur];
				self.recordsFound = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "recordsSearched")) {
				id newChild = [NSNumber deserializeNode:cur];
				self.recordsSearched = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "parent")) {
				id newChild = [NSString deserializeNode:cur];
				self.parent = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "optionValue")) {
				id newChild = [WokSearchService_labelValuesPair deserializeNode:cur];
				if(newChild != nil) [self.optionValue addObject:newChild];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "records")) {
				id newChild = [NSString deserializeNode:cur];
				self.records = newChild;
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
				id newChild = [WokSearchService_fullRecordSearchResults deserializeNode:cur];
				self.return_ = newChild;
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
				id newChild = [NSString deserializeNode:cur];
				self.databaseId = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "uid")) {
				id newChild = [NSString deserializeNode:cur];
				self.uid = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "editions")) {
				id newChild = [WokSearchService_editionDesc deserializeNode:cur];
				if(newChild != nil) [self.editions addObject:newChild];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "timeSpan")) {
				id newChild = [WokSearchService_timeSpan deserializeNode:cur];
				self.timeSpan = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "queryLanguage")) {
				id newChild = [NSString deserializeNode:cur];
				self.queryLanguage = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "retrieveParameters")) {
				id newChild = [WokSearchService_retrieveParameters deserializeNode:cur];
				self.retrieveParameters = newChild;
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
				id newChild = [WokSearchService_fullRecordSearchResults deserializeNode:cur];
				self.return_ = newChild;
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
				id newChild = [NSString deserializeNode:cur];
				self.queryId = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "retrieveParameters")) {
				id newChild = [WokSearchService_retrieveParameters deserializeNode:cur];
				self.retrieveParameters = newChild;
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
				id newChild = [WokSearchService_labelValuesPair deserializeNode:cur];
				if(newChild != nil) [self.optionValue addObject:newChild];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "records")) {
				id newChild = [NSString deserializeNode:cur];
				self.records = newChild;
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
				id newChild = [WokSearchService_fullRecordData deserializeNode:cur];
				self.return_ = newChild;
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
				id newChild = [NSString deserializeNode:cur];
				self.databaseId = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "uid")) {
				id newChild = [NSString deserializeNode:cur];
				if(newChild != nil) [self.uid addObject:newChild];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "queryLanguage")) {
				id newChild = [NSString deserializeNode:cur];
				self.queryLanguage = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "retrieveParameters")) {
				id newChild = [WokSearchService_retrieveParameters deserializeNode:cur];
				self.retrieveParameters = newChild;
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
				id newChild = [WokSearchService_fullRecordSearchResults deserializeNode:cur];
				self.return_ = newChild;
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
				id newChild = [NSString deserializeNode:cur];
				self.databaseId = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "userQuery")) {
				id newChild = [NSString deserializeNode:cur];
				self.userQuery = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "editions")) {
				id newChild = [WokSearchService_editionDesc deserializeNode:cur];
				if(newChild != nil) [self.editions addObject:newChild];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "symbolicTimeSpan")) {
				id newChild = [NSString deserializeNode:cur];
				self.symbolicTimeSpan = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "timeSpan")) {
				id newChild = [WokSearchService_timeSpan deserializeNode:cur];
				self.timeSpan = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "queryLanguage")) {
				id newChild = [NSString deserializeNode:cur];
				self.queryLanguage = newChild;
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
				id newChild = [WokSearchService_queryParameters deserializeNode:cur];
				self.queryParameters = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "retrieveParameters")) {
				id newChild = [WokSearchService_retrieveParameters deserializeNode:cur];
				self.retrieveParameters = newChild;
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
				id newChild = [WokSearchService_fullRecordSearchResults deserializeNode:cur];
				self.return_ = newChild;
			}
		}
	}
}
@end

@implementation WokSearchService_SupportingWebServiceException
- (id)init
{
	if((self = [super init])) {
		remoteNamespace = nil;
		remoteOperation = nil;
		remoteCode = nil;
		remoteReason = nil;
		handshakeCauseId = nil;
		handshakeCause = nil;
	}
	
	return self;
}
- (void)dealloc
{
	if(remoteNamespace != nil) [remoteNamespace release];
	if(remoteOperation != nil) [remoteOperation release];
	if(remoteCode != nil) [remoteCode release];
	if(remoteReason != nil) [remoteReason release];
	if(handshakeCauseId != nil) [handshakeCauseId release];
	if(handshakeCause != nil) [handshakeCause release];
	
	[super dealloc];
}
- (void)addElementsToNode:(xmlNodePtr)node
{
	if(self.remoteNamespace!= nil) {
		xmlAddChild(node, [self.remoteNamespace xmlNodeForDoc:node->doc elementName:@"remoteNamespace" elementNSPrefix:nil]);
	}
	if(self.remoteOperation!= nil) {
		xmlAddChild(node, [self.remoteOperation xmlNodeForDoc:node->doc elementName:@"remoteOperation" elementNSPrefix:nil]);
	}
	if(self.remoteCode!= nil) {
		xmlAddChild(node, [self.remoteCode xmlNodeForDoc:node->doc elementName:@"remoteCode" elementNSPrefix:nil]);
	}
	if(self.remoteReason!= nil) {
		xmlAddChild(node, [self.remoteReason xmlNodeForDoc:node->doc elementName:@"remoteReason" elementNSPrefix:nil]);
	}
	if(self.handshakeCauseId!= nil) {
		xmlAddChild(node, [self.handshakeCauseId xmlNodeForDoc:node->doc elementName:@"handshakeCauseId" elementNSPrefix:nil]);
	}
	if(self.handshakeCause!= nil) {
		xmlAddChild(node, [self.handshakeCause xmlNodeForDoc:node->doc elementName:@"handshakeCause" elementNSPrefix:nil]);
	}
}
@synthesize remoteNamespace;
@synthesize remoteOperation;
@synthesize remoteCode;
@synthesize remoteReason;
@synthesize handshakeCauseId;
@synthesize handshakeCause;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur
{
	for( cur = cur->children ; cur != NULL ; cur = cur->next ) {
		if(cur->type == XML_ELEMENT_NODE) {
			if(xmlStrEqual(cur->name, (const xmlChar *) "remoteNamespace")) {
				id newChild = [NSString deserializeNode:cur];
				self.remoteNamespace = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "remoteOperation")) {
				id newChild = [NSString deserializeNode:cur];
				self.remoteOperation = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "remoteCode")) {
				id newChild = [NSString deserializeNode:cur];
				self.remoteCode = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "remoteReason")) {
				id newChild = [NSString deserializeNode:cur];
				self.remoteReason = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "handshakeCauseId")) {
				id newChild = [NSString deserializeNode:cur];
				self.handshakeCauseId = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "handshakeCause")) {
				id newChild = [NSString deserializeNode:cur];
				self.handshakeCause = newChild;
			}
		}
	}
}
@end

@implementation WokSearchService_FaultInformation
- (id)init
{
	if((self = [super init])) {
		code = nil;
		message = nil;
		reason = nil;
		causeType = nil;
		cause = nil;
		supportingWebServiceException = nil;
		remedy = nil;
	}
	
	return self;
}
- (void)dealloc
{
	if(code != nil) [code release];
	if(message != nil) [message release];
	if(reason != nil) [reason release];
	if(causeType != nil) [causeType release];
	if(cause != nil) [cause release];
	if(supportingWebServiceException != nil) [supportingWebServiceException release];
	if(remedy != nil) [remedy release];
	
	[super dealloc];
}
- (void)addElementsToNode:(xmlNodePtr)node
{
	if(self.code!= nil) {
		xmlAddChild(node, [self.code xmlNodeForDoc:node->doc elementName:@"code" elementNSPrefix:nil]);
	}
	if(self.message!= nil) {
		xmlAddChild(node, [self.message xmlNodeForDoc:node->doc elementName:@"message" elementNSPrefix:nil]);
	}
	if(self.reason!= nil) {
		xmlAddChild(node, [self.reason xmlNodeForDoc:node->doc elementName:@"reason" elementNSPrefix:nil]);
	}
	if(self.causeType!= nil) {
		xmlAddChild(node, [self.causeType xmlNodeForDoc:node->doc elementName:@"causeType" elementNSPrefix:nil]);
	}
	if(self.cause!= nil) {
		xmlAddChild(node, [self.cause xmlNodeForDoc:node->doc elementName:@"cause" elementNSPrefix:nil]);
	}
	if(self.supportingWebServiceException!= nil) {
		xmlAddChild(node, [self.supportingWebServiceException xmlNodeForDoc:node->doc elementName:@"supportingWebServiceException" elementNSPrefix:nil]);
	}
	if(self.remedy!= nil) {
		xmlAddChild(node, [self.remedy xmlNodeForDoc:node->doc elementName:@"remedy" elementNSPrefix:nil]);
	}
}
@synthesize code;
@synthesize message;
@synthesize reason;
@synthesize causeType;
@synthesize cause;
@synthesize supportingWebServiceException;
@synthesize remedy;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur
{
	for( cur = cur->children ; cur != NULL ; cur = cur->next ) {
		if(cur->type == XML_ELEMENT_NODE) {
			if(xmlStrEqual(cur->name, (const xmlChar *) "code")) {
				id newChild = [NSString deserializeNode:cur];
				self.code = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "message")) {
				id newChild = [NSString deserializeNode:cur];
				self.message = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "reason")) {
				id newChild = [NSString deserializeNode:cur];
				self.reason = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "causeType")) {
				id newChild = [NSString deserializeNode:cur];
				self.causeType = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "cause")) {
				id newChild = [NSString deserializeNode:cur];
				self.cause = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "supportingWebServiceException")) {
				id newChild = [WokSearchService_SupportingWebServiceException deserializeNode:cur];
				self.supportingWebServiceException = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "remedy")) {
				id newChild = [NSString deserializeNode:cur];
				self.remedy = newChild;
			}
		}
	}
}
@end

@implementation WokSearchService_RawFaultInformation
- (id)init
{
	if((self = [super init])) {
		rawFaultstring = nil;
		rawMessage = nil;
		rawReason = nil;
		rawCause = nil;
		rawRemedy = nil;
		messageData = [[NSMutableArray alloc] init];
	}
	
	return self;
}
- (void)dealloc
{
	if(rawFaultstring != nil) [rawFaultstring release];
	if(rawMessage != nil) [rawMessage release];
	if(rawReason != nil) [rawReason release];
	if(rawCause != nil) [rawCause release];
	if(rawRemedy != nil) [rawRemedy release];
	if(messageData != nil) [messageData release];
	
	[super dealloc];
}
- (void)addElementsToNode:(xmlNodePtr)node
{
	if(self.rawFaultstring!= nil) {
		xmlAddChild(node, [self.rawFaultstring xmlNodeForDoc:node->doc elementName:@"rawFaultstring" elementNSPrefix:nil]);
	}
	if(self.rawMessage!= nil) {
		xmlAddChild(node, [self.rawMessage xmlNodeForDoc:node->doc elementName:@"rawMessage" elementNSPrefix:nil]);
	}
	if(self.rawReason!= nil) {
		xmlAddChild(node, [self.rawReason xmlNodeForDoc:node->doc elementName:@"rawReason" elementNSPrefix:nil]);
	}
	if(self.rawCause!= nil) {
		xmlAddChild(node, [self.rawCause xmlNodeForDoc:node->doc elementName:@"rawCause" elementNSPrefix:nil]);
	}
	if(self.rawRemedy!= nil) {
		xmlAddChild(node, [self.rawRemedy xmlNodeForDoc:node->doc elementName:@"rawRemedy" elementNSPrefix:nil]);
	}
	if(self.messageData!= nil) {
		for(NSString * child in self.messageData) {
			xmlAddChild(node, [child xmlNodeForDoc:node->doc elementName:@"messageData" elementNSPrefix:nil]);
		}
	}
}
@synthesize rawFaultstring;
@synthesize rawMessage;
@synthesize rawReason;
@synthesize rawCause;
@synthesize rawRemedy;
@synthesize messageData;
- (void)addMessageData:(NSString *)toAdd
{
	if(toAdd != nil) [messageData addObject:toAdd];
}
- (void)deserializeElementsFromNode:(xmlNodePtr)cur
{
	for( cur = cur->children ; cur != NULL ; cur = cur->next ) {
		if(cur->type == XML_ELEMENT_NODE) {
			if(xmlStrEqual(cur->name, (const xmlChar *) "rawFaultstring")) {
				id newChild = [NSString deserializeNode:cur];
				self.rawFaultstring = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "rawMessage")) {
				id newChild = [NSString deserializeNode:cur];
				self.rawMessage = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "rawReason")) {
				id newChild = [NSString deserializeNode:cur];
				self.rawReason = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "rawCause")) {
				id newChild = [NSString deserializeNode:cur];
				self.rawCause = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "rawRemedy")) {
				id newChild = [NSString deserializeNode:cur];
				self.rawRemedy = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "messageData")) {
				id newChild = [NSString deserializeNode:cur];
				if(newChild != nil) [self.messageData addObject:newChild];
			}
		}
	}
}
@end

@implementation WokSearchService_QueryException
- (id)init
{
	if((self = [super init])) {
		faultInformation = nil;
		rawFaultInformation = nil;
	}
	
	return self;
}
- (void)dealloc
{
	if(faultInformation != nil) [faultInformation release];
	if(rawFaultInformation != nil) [rawFaultInformation release];
	
	[super dealloc];
}
- (void)addElementsToNode:(xmlNodePtr)node
{
	if(self.faultInformation!= nil) {
		xmlAddChild(node, [self.faultInformation xmlNodeForDoc:node->doc elementName:@"faultInformation" elementNSPrefix:nil]);
	}
	if(self.rawFaultInformation!= nil) {
		xmlAddChild(node, [self.rawFaultInformation xmlNodeForDoc:node->doc elementName:@"rawFaultInformation" elementNSPrefix:nil]);
	}
}
@synthesize faultInformation;
@synthesize rawFaultInformation;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur
{
	for( cur = cur->children ; cur != NULL ; cur = cur->next ) {
		if(cur->type == XML_ELEMENT_NODE) {
			if(xmlStrEqual(cur->name, (const xmlChar *) "faultInformation")) {
				id newChild = [WokSearchService_FaultInformation deserializeNode:cur];
				self.faultInformation = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "rawFaultInformation")) {
				id newChild = [WokSearchService_RawFaultInformation deserializeNode:cur];
				self.rawFaultInformation = newChild;
			}
		}
	}
}
@end

@implementation WokSearchService_AuthenticationException
- (id)init
{
	if((self = [super init])) {
		faultInformation = nil;
		rawFaultInformation = nil;
	}
	
	return self;
}
- (void)dealloc
{
	if(faultInformation != nil) [faultInformation release];
	if(rawFaultInformation != nil) [rawFaultInformation release];
	
	[super dealloc];
}
- (void)addElementsToNode:(xmlNodePtr)node
{
	if(self.faultInformation!= nil) {
		xmlAddChild(node, [self.faultInformation xmlNodeForDoc:node->doc elementName:@"faultInformation" elementNSPrefix:nil]);
	}
	if(self.rawFaultInformation!= nil) {
		xmlAddChild(node, [self.rawFaultInformation xmlNodeForDoc:node->doc elementName:@"rawFaultInformation" elementNSPrefix:nil]);
	}
}
@synthesize faultInformation;
@synthesize rawFaultInformation;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur
{
	for( cur = cur->children ; cur != NULL ; cur = cur->next ) {
		if(cur->type == XML_ELEMENT_NODE) {
			if(xmlStrEqual(cur->name, (const xmlChar *) "faultInformation")) {
				id newChild = [WokSearchService_FaultInformation deserializeNode:cur];
				self.faultInformation = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "rawFaultInformation")) {
				id newChild = [WokSearchService_RawFaultInformation deserializeNode:cur];
				self.rawFaultInformation = newChild;
			}
		}
	}
}
@end

@implementation WokSearchService_InvalidInputException
- (id)init
{
	if((self = [super init])) {
		faultInformation = nil;
		rawFaultInformation = nil;
	}
	
	return self;
}
- (void)dealloc
{
	if(faultInformation != nil) [faultInformation release];
	if(rawFaultInformation != nil) [rawFaultInformation release];
	
	[super dealloc];
}
- (void)addElementsToNode:(xmlNodePtr)node
{
	if(self.faultInformation!= nil) {
		xmlAddChild(node, [self.faultInformation xmlNodeForDoc:node->doc elementName:@"faultInformation" elementNSPrefix:nil]);
	}
	if(self.rawFaultInformation!= nil) {
		xmlAddChild(node, [self.rawFaultInformation xmlNodeForDoc:node->doc elementName:@"rawFaultInformation" elementNSPrefix:nil]);
	}
}
@synthesize faultInformation;
@synthesize rawFaultInformation;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur
{
	for( cur = cur->children ; cur != NULL ; cur = cur->next ) {
		if(cur->type == XML_ELEMENT_NODE) {
			if(xmlStrEqual(cur->name, (const xmlChar *) "faultInformation")) {
				id newChild = [WokSearchService_FaultInformation deserializeNode:cur];
				self.faultInformation = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "rawFaultInformation")) {
				id newChild = [WokSearchService_RawFaultInformation deserializeNode:cur];
				self.rawFaultInformation = newChild;
			}
		}
	}
}
@end

@implementation WokSearchService_ESTIWSException
- (id)init
{
	if((self = [super init])) {
		faultInformation = nil;
		rawFaultInformation = nil;
	}
	
	return self;
}
- (void)dealloc
{
	if(faultInformation != nil) [faultInformation release];
	if(rawFaultInformation != nil) [rawFaultInformation release];
	
	[super dealloc];
}
- (void)addElementsToNode:(xmlNodePtr)node
{
	if(self.faultInformation!= nil) {
		xmlAddChild(node, [self.faultInformation xmlNodeForDoc:node->doc elementName:@"faultInformation" elementNSPrefix:nil]);
	}
	if(self.rawFaultInformation!= nil) {
		xmlAddChild(node, [self.rawFaultInformation xmlNodeForDoc:node->doc elementName:@"rawFaultInformation" elementNSPrefix:nil]);
	}
}
@synthesize faultInformation;
@synthesize rawFaultInformation;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur
{
	for( cur = cur->children ; cur != NULL ; cur = cur->next ) {
		if(cur->type == XML_ELEMENT_NODE) {
			if(xmlStrEqual(cur->name, (const xmlChar *) "faultInformation")) {
				id newChild = [WokSearchService_FaultInformation deserializeNode:cur];
				self.faultInformation = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "rawFaultInformation")) {
				id newChild = [WokSearchService_RawFaultInformation deserializeNode:cur];
				self.rawFaultInformation = newChild;
			}
		}
	}
}
@end

@implementation WokSearchService_InternalServerException
- (id)init
{
	if((self = [super init])) {
		faultInformation = nil;
		rawFaultInformation = nil;
	}
	
	return self;
}
- (void)dealloc
{
	if(faultInformation != nil) [faultInformation release];
	if(rawFaultInformation != nil) [rawFaultInformation release];
	
	[super dealloc];
}
- (void)addElementsToNode:(xmlNodePtr)node
{
	if(self.faultInformation!= nil) {
		xmlAddChild(node, [self.faultInformation xmlNodeForDoc:node->doc elementName:@"faultInformation" elementNSPrefix:nil]);
	}
	if(self.rawFaultInformation!= nil) {
		xmlAddChild(node, [self.rawFaultInformation xmlNodeForDoc:node->doc elementName:@"rawFaultInformation" elementNSPrefix:nil]);
	}
}
@synthesize faultInformation;
@synthesize rawFaultInformation;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur
{
	for( cur = cur->children ; cur != NULL ; cur = cur->next ) {
		if(cur->type == XML_ELEMENT_NODE) {
			if(xmlStrEqual(cur->name, (const xmlChar *) "faultInformation")) {
				id newChild = [WokSearchService_FaultInformation deserializeNode:cur];
				self.faultInformation = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "rawFaultInformation")) {
				id newChild = [WokSearchService_RawFaultInformation deserializeNode:cur];
				self.rawFaultInformation = newChild;
			}
		}
	}
}
@end

@implementation WokSearchService_SessionException
- (id)init
{
	if((self = [super init])) {
		faultInformation = nil;
		rawFaultInformation = nil;
	}
	
	return self;
}
- (void)dealloc
{
	if(faultInformation != nil) [faultInformation release];
	if(rawFaultInformation != nil) [rawFaultInformation release];
	
	[super dealloc];
}
- (void)addElementsToNode:(xmlNodePtr)node
{
	if(self.faultInformation!= nil) {
		xmlAddChild(node, [self.faultInformation xmlNodeForDoc:node->doc elementName:@"faultInformation" elementNSPrefix:nil]);
	}
	if(self.rawFaultInformation!= nil) {
		xmlAddChild(node, [self.rawFaultInformation xmlNodeForDoc:node->doc elementName:@"rawFaultInformation" elementNSPrefix:nil]);
	}
}
@synthesize faultInformation;
@synthesize rawFaultInformation;
- (void)deserializeElementsFromNode:(xmlNodePtr)cur
{
	for( cur = cur->children ; cur != NULL ; cur = cur->next ) {
		if(cur->type == XML_ELEMENT_NODE) {
			if(xmlStrEqual(cur->name, (const xmlChar *) "faultInformation")) {
				id newChild = [WokSearchService_FaultInformation deserializeNode:cur];
				self.faultInformation = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "rawFaultInformation")) {
				id newChild = [WokSearchService_RawFaultInformation deserializeNode:cur];
				self.rawFaultInformation = newChild;
			}
		}
	}
}
@end

@implementation WokSearchService
+ (WokSearchServiceSoapBinding *)WokSearchServiceSoapBinding
{
	return [[[WokSearchServiceSoapBinding alloc] initWithAddress:@"http://search.webofknowledge.com/esti/wokmws/ws/WokSearch"] autorelease];
}
@end

@implementation WokSearchServiceSoapBinding
@synthesize address;
@synthesize defaultTimeout;
@synthesize logXMLInOut;
@synthesize cookies;
@synthesize authUsername;
@synthesize authPassword;
- (id)init
{
	if((self = [super init])) {
		address = nil;
		cookies = nil;
		defaultTimeout = 10;//seconds
		logXMLInOut = NO;
		synchronousOperationComplete = NO;
	}
	
	return self;
}
- (id)initWithAddress:(NSString *)anAddress
{
	if((self = [self init])) {
		self.address = [NSURL URLWithString:anAddress];
	}
	
	return self;
}
- (void)addCookie:(NSHTTPCookie *)toAdd
{
	if(toAdd != nil) {
		if(cookies == nil) cookies = [[NSMutableArray alloc] init];
		[cookies addObject:toAdd];
	}
}
- (WokSearchServiceSoapBindingResponse *)performSynchronousOperationWithBodyElements:(NSDictionary *)bodyElements
{
	WokSearchServiceSoapBindingOperation *operation = [[[WokSearchServiceSoapBindingOperation alloc] initWithBinding:self delegate:self bodyElements:bodyElements] autorelease];
	synchronousOperationComplete = NO;
	[operation start];
	
	// Now wait for response
	NSRunLoop *theRL = [NSRunLoop currentRunLoop];
	
	while (!synchronousOperationComplete && [theRL runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]);
	return operation.response;
}
- (void)performAsynchronousOperationWithBodyElements:(NSDictionary *)bodyElements delegate:(id<WokSearchServiceSoapBindingResponseDelegate>)responseDelegate
{
	WokSearchServiceSoapBindingOperation *operation = [[[WokSearchServiceSoapBindingOperation alloc] initWithBinding:self delegate:responseDelegate bodyElements:bodyElements] autorelease];
	[operation start];
}
- (void) operation:(WokSearchServiceSoapBindingOperation *)operation completedWithResponse:(WokSearchServiceSoapBindingResponse *)response
{
	synchronousOperationComplete = YES;
}
- (WokSearchServiceSoapBindingResponse *)citedReferencesRetrieveUsingParameters:(WokSearchService_citedReferencesRetrieve *)aParameters 
{
	NSDictionary *bodyElements = [NSDictionary dictionaryWithObject:aParameters forKey:@"citedReferencesRetrieve"];
	return [self performSynchronousOperationWithBodyElements:bodyElements];
}
- (void)citedReferencesRetrieveAsyncUsingParameters:(WokSearchService_citedReferencesRetrieve *)aParameters  delegate:(id<WokSearchServiceSoapBindingResponseDelegate>)responseDelegate
{
	NSDictionary *bodyElements = [NSDictionary dictionaryWithObject:aParameters forKey:@"citedReferencesRetrieve"];
	[self performAsynchronousOperationWithBodyElements:bodyElements delegate:responseDelegate];
}
- (WokSearchServiceSoapBindingResponse *)relatedRecordsUsingParameters:(WokSearchService_relatedRecords *)aParameters 
{
	NSDictionary *bodyElements = [NSDictionary dictionaryWithObject:aParameters forKey:@"relatedRecords"];
	return [self performSynchronousOperationWithBodyElements:bodyElements];
}
- (void)relatedRecordsAsyncUsingParameters:(WokSearchService_relatedRecords *)aParameters  delegate:(id<WokSearchServiceSoapBindingResponseDelegate>)responseDelegate
{
	NSDictionary *bodyElements = [NSDictionary dictionaryWithObject:aParameters forKey:@"relatedRecords"];
	[self performAsynchronousOperationWithBodyElements:bodyElements delegate:responseDelegate];
}
- (WokSearchServiceSoapBindingResponse *)citedReferencesUsingParameters:(WokSearchService_citedReferences *)aParameters 
{
	NSDictionary *bodyElements = [NSDictionary dictionaryWithObject:aParameters forKey:@"citedReferences"];
	return [self performSynchronousOperationWithBodyElements:bodyElements];
}
- (void)citedReferencesAsyncUsingParameters:(WokSearchService_citedReferences *)aParameters  delegate:(id<WokSearchServiceSoapBindingResponseDelegate>)responseDelegate
{
	NSDictionary *bodyElements = [NSDictionary dictionaryWithObject:aParameters forKey:@"citedReferences"];
	[self performAsynchronousOperationWithBodyElements:bodyElements delegate:responseDelegate];
}
- (WokSearchServiceSoapBindingResponse *)retrieveUsingParameters:(WokSearchService_retrieve *)aParameters 
{
	NSDictionary *bodyElements = [NSDictionary dictionaryWithObject:aParameters forKey:@"retrieve"];
	return [self performSynchronousOperationWithBodyElements:bodyElements];
}
- (void)retrieveAsyncUsingParameters:(WokSearchService_retrieve *)aParameters  delegate:(id<WokSearchServiceSoapBindingResponseDelegate>)responseDelegate
{
	NSDictionary *bodyElements = [NSDictionary dictionaryWithObject:aParameters forKey:@"retrieve"];
	[self performAsynchronousOperationWithBodyElements:bodyElements delegate:responseDelegate];
}
- (WokSearchServiceSoapBindingResponse *)searchUsingParameters:(WokSearchService_search *)aParameters 
{
	NSDictionary *bodyElements = [NSDictionary dictionaryWithObject:aParameters forKey:@"search"];
	return [self performSynchronousOperationWithBodyElements:bodyElements];
}
- (void)searchAsyncUsingParameters:(WokSearchService_search *)aParameters  delegate:(id<WokSearchServiceSoapBindingResponseDelegate>)responseDelegate
{
	NSDictionary *bodyElements = [NSDictionary dictionaryWithObject:aParameters forKey:@"search"];
	[self performAsynchronousOperationWithBodyElements:bodyElements delegate:responseDelegate];
}
- (WokSearchServiceSoapBindingResponse *)citingArticlesUsingParameters:(WokSearchService_citingArticles *)aParameters 
{
	NSDictionary *bodyElements = [NSDictionary dictionaryWithObject:aParameters forKey:@"citingArticles"];
	return [self performSynchronousOperationWithBodyElements:bodyElements];
}
- (void)citingArticlesAsyncUsingParameters:(WokSearchService_citingArticles *)aParameters  delegate:(id<WokSearchServiceSoapBindingResponseDelegate>)responseDelegate
{
	NSDictionary *bodyElements = [NSDictionary dictionaryWithObject:aParameters forKey:@"citingArticles"];
	[self performAsynchronousOperationWithBodyElements:bodyElements delegate:responseDelegate];
}
- (WokSearchServiceSoapBindingResponse *)retrieveByIdUsingParameters:(WokSearchService_retrieveById *)aParameters 
{
	NSDictionary *bodyElements = [NSDictionary dictionaryWithObject:aParameters forKey:@"retrieveById"];
	return [self performSynchronousOperationWithBodyElements:bodyElements];
}
- (void)retrieveByIdAsyncUsingParameters:(WokSearchService_retrieveById *)aParameters  delegate:(id<WokSearchServiceSoapBindingResponseDelegate>)responseDelegate
{
	NSDictionary *bodyElements = [NSDictionary dictionaryWithObject:aParameters forKey:@"retrieveById"];
	[self performAsynchronousOperationWithBodyElements:bodyElements delegate:responseDelegate];
}
- (void)sendHTTPCallUsingBody:(NSString *)outputBody soapAction:(NSString *)soapAction forOperation:(WokSearchServiceSoapBindingOperation *)operation
{
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.address 
																												 cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
																										 timeoutInterval:self.defaultTimeout];
	NSData *bodyData = [outputBody dataUsingEncoding:NSUTF8StringEncoding];
	
	if(cookies != nil) {
		[request setAllHTTPHeaderFields:[NSHTTPCookie requestHeaderFieldsWithCookies:cookies]];
	}
	[request setValue:@"wsdl2objc" forHTTPHeaderField:@"User-Agent"];
	[request setValue:soapAction forHTTPHeaderField:@"SOAPAction"];
	[request setValue:@"text/xml; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
	[request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)[bodyData length]] forHTTPHeaderField:@"Content-Length"];
	[request setValue:self.address.host forHTTPHeaderField:@"Host"];
	[request setHTTPMethod: @"POST"];
	// set version 1.1 - how?
	[request setHTTPBody: bodyData];
		
	if(self.logXMLInOut) {
		NSLog(@"OutputHeaders:\n%@", [request allHTTPHeaderFields]);
		NSLog(@"OutputBody:\n%@", outputBody);
	}
	
	NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:operation];
	
	operation.urlConnection = connection;
	[connection release];
}
- (void) dealloc
{
	[address release];
	[cookies release];
	[super dealloc];
}
@end

@implementation WokSearchServiceSoapBindingOperation
@synthesize binding;
@synthesize bodyElements;
@synthesize response;
@synthesize delegate;
@synthesize responseData;
@synthesize urlConnection;
- (id)initWithBinding:(WokSearchServiceSoapBinding *)aBinding delegate:(id<WokSearchServiceSoapBindingResponseDelegate>)aDelegate bodyElements:(NSDictionary *)aBodyElements
{
	if ((self = [super init])) {
		self.binding = aBinding;
		self.bodyElements = aBodyElements;
		response = nil;
		self.delegate = aDelegate;
		self.responseData = nil;
		self.urlConnection = nil;
	}
	
	return self;
}
- (void)main
{
	[response autorelease];
	response = [WokSearchServiceSoapBindingResponse new];
	
	WokSearchServiceSoapBinding_envelope *envelope = [WokSearchServiceSoapBinding_envelope sharedInstance];
	
	NSString *operationXMLString = [envelope serializedFormUsingHeaderElements:nil bodyElements:bodyElements];
	
	[binding sendHTTPCallUsingBody:operationXMLString soapAction:@"" forOperation:self];
}
- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
	if ([challenge previousFailureCount] == 0) {
		NSURLCredential *newCredential;
		newCredential=[NSURLCredential credentialWithUser:self.binding.authUsername
												 password:self.binding.authPassword
											  persistence:NSURLCredentialPersistenceForSession];
		[[challenge sender] useCredential:newCredential
			   forAuthenticationChallenge:challenge];
	} else {
		[[challenge sender] cancelAuthenticationChallenge:challenge];
		NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"Authentication Error" forKey:NSLocalizedDescriptionKey];
		NSError *authError = [NSError errorWithDomain:@"Connection Authentication" code:0 userInfo:userInfo];
		[self connection:connection didFailWithError:authError];
	}
}
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)urlResponse
{
	NSHTTPURLResponse *httpResponse;
	if ([urlResponse isKindOfClass:[NSHTTPURLResponse class]]) {
		httpResponse = (NSHTTPURLResponse *) urlResponse;
	} else {
		httpResponse = nil;
	}
	
	if(binding.logXMLInOut) {
		NSLog(@"ResponseStatus: %ld\n", (long)[httpResponse statusCode]);
		NSLog(@"ResponseHeaders:\n%@", [httpResponse allHeaderFields]);
	}
	
	NSMutableArray *cookies = [[NSHTTPCookie cookiesWithResponseHeaderFields:[httpResponse allHeaderFields] forURL:binding.address] mutableCopy];
	
	binding.cookies = cookies;
	[cookies release];
  if ([urlResponse.MIMEType rangeOfString:@"text/xml"].length == 0) {
		NSError *error = nil;
		[connection cancel];
		if ([httpResponse statusCode] >= 400) {
			NSDictionary *userInfo = [NSDictionary dictionaryWithObject:[NSHTTPURLResponse localizedStringForStatusCode:[httpResponse statusCode]] forKey:NSLocalizedDescriptionKey];
				
			error = [NSError errorWithDomain:@"WokSearchServiceSoapBindingResponseHTTP" code:[httpResponse statusCode] userInfo:userInfo];
		} else {
			NSDictionary *userInfo = [NSDictionary dictionaryWithObject:
																[NSString stringWithFormat: @"Unexpected response MIME type to SOAP call:%@", urlResponse.MIMEType]
																													 forKey:NSLocalizedDescriptionKey];
			error = [NSError errorWithDomain:@"WokSearchServiceSoapBindingResponseHTTP" code:1 userInfo:userInfo];
		}
				
		[self connection:connection didFailWithError:error];
  }
}
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
  if (responseData == nil) {
		responseData = [data mutableCopy];
	} else {
		[responseData appendData:data];
	}
}
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	if (binding.logXMLInOut) {
		NSLog(@"ResponseError:\n%@", error);
	}
	response.error = error;
	[delegate operation:self completedWithResponse:response];
}
- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	if (responseData != nil && delegate != nil)
	{
		xmlDocPtr doc;
		xmlNodePtr cur;
		
		if (binding.logXMLInOut) {
			NSLog(@"ResponseBody:\n%@", [[[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding] autorelease]);
		}
		
		doc = xmlParseMemory([responseData bytes], [responseData length]);
		
		if (doc == NULL) {
			NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"Errors while parsing returned XML" forKey:NSLocalizedDescriptionKey];
			
			response.error = [NSError errorWithDomain:@"WokSearchServiceSoapBindingResponseXML" code:1 userInfo:userInfo];
			[delegate operation:self completedWithResponse:response];
		} else {
			cur = xmlDocGetRootElement(doc);
			cur = cur->children;
			
			for( ; cur != NULL ; cur = cur->next) {
				if(cur->type == XML_ELEMENT_NODE) {
					
					if(xmlStrEqual(cur->name, (const xmlChar *) "Body")) {
						NSMutableArray *responseBodyParts = [NSMutableArray array];
						
						xmlNodePtr bodyNode;
						for(bodyNode=cur->children ; bodyNode != NULL ; bodyNode = bodyNode->next) {
							if(cur->type == XML_ELEMENT_NODE) {
								Class responseClass = nil;
								if (xmlStrEqual(bodyNode->ns->prefix, cur->ns->prefix) && 
									xmlStrEqual(bodyNode->name, (const xmlChar *) "Fault")) {
									SOAPFault *bodyObject = [SOAPFault deserializeNode:bodyNode];
									//NSAssert1(bodyObject != nil, @"Errors while parsing body %s", bodyNode->name);
									if (bodyObject != nil) [responseBodyParts addObject:bodyObject];
								}
								else if((responseClass = NSClassFromString([NSString stringWithFormat:@"%@_%s", @"WokSearchService", bodyNode->name]))) {
									id bodyObject = [responseClass deserializeNode:bodyNode];
									//NSAssert1(bodyObject != nil, @"Errors while parsing body %s", bodyNode->name);
									if (bodyObject != nil) [responseBodyParts addObject:bodyObject];
								}
							}
						}
						
						response.bodyParts = responseBodyParts;
					}
				}
			}
			
			xmlFreeDoc(doc);
		}
		
		xmlCleanupParser();
		[delegate operation:self completedWithResponse:response];
	}
}
- (void)dealloc
{
	[binding release];
	[bodyElements release];
	[response release];
	delegate = nil;
	[responseData release];
	[urlConnection release];
	
	[super dealloc];
}
@end

static WokSearchServiceSoapBinding_envelope *WokSearchServiceSoapBindingSharedEnvelopeInstance = nil;
@implementation WokSearchServiceSoapBinding_envelope
+ (WokSearchServiceSoapBinding_envelope *)sharedInstance
{
	if(WokSearchServiceSoapBindingSharedEnvelopeInstance == nil) {
		WokSearchServiceSoapBindingSharedEnvelopeInstance = [WokSearchServiceSoapBinding_envelope new];
	}
	
	return WokSearchServiceSoapBindingSharedEnvelopeInstance;
}
- (NSString *)serializedFormUsingHeaderElements:(NSDictionary *)headerElements bodyElements:(NSDictionary *)bodyElements
{
	xmlDocPtr doc;
	
	doc = xmlNewDoc((const xmlChar*)XML_DEFAULT_VERSION);
	if (doc == NULL) {
		NSLog(@"Error creating the xml document tree");
		return @"";
	}
	
	xmlNodePtr root = xmlNewDocNode(doc, NULL, (const xmlChar*)"Envelope", NULL);
	xmlDocSetRootElement(doc, root);
	
	xmlNsPtr soapEnvelopeNs = xmlNewNs(root, (const xmlChar*)"http://schemas.xmlsoap.org/soap/envelope/", (const xmlChar*)"soapenv");
	xmlSetNs(root, soapEnvelopeNs);
	
    xmlNsPtr woksearchNs = xmlNewNs(root, (const xmlChar*)"http://woksearch.v3.wokmws.thomsonreuters.com", (const xmlChar*)"woksearch");
	
    xmlNewNs(root, (const xmlChar*)"http://schemas.xmlsoap.org/wsdl/", (const xmlChar*)"wsdl");
	xmlNewNs(root, (const xmlChar*)"http://schemas.xmlsoap.org/wsdl/soap/", (const xmlChar*)"soap");
	
	if((headerElements != nil) && ([headerElements count] > 0)) {
		xmlNodePtr headerNode = xmlNewDocNode(doc, soapEnvelopeNs, (const xmlChar*)"Header", NULL);
		xmlAddChild(root, headerNode);
		
		for(NSString *key in [headerElements allKeys]) {
			id header = [headerElements objectForKey:key];
			xmlNodePtr child = xmlAddChild(headerNode, [header xmlNodeForDoc:doc elementName:key elementNSPrefix:nil]);
			xmlSetNs(child, woksearchNs);
		}
	}
	
	if((bodyElements != nil) && ([bodyElements count] > 0)) {
		xmlNodePtr bodyNode = xmlNewDocNode(doc, soapEnvelopeNs, (const xmlChar*)"Body", NULL);
		xmlAddChild(root, bodyNode);
		
		for(NSString *key in [bodyElements allKeys]) {
			id body = [bodyElements objectForKey:key];
			xmlNodePtr child = xmlAddChild(bodyNode, [body xmlNodeForDoc:doc elementName:key elementNSPrefix:nil]);
			xmlSetNs(child, woksearchNs);
		}
	}
	
	xmlChar *buf;
	int size;
	xmlDocDumpFormatMemory(doc, &buf, &size, 1);
	
	NSString *serializedForm = [NSString stringWithCString:(const char*)buf encoding:NSUTF8StringEncoding];
	xmlFree(buf);
	
	xmlFreeDoc(doc);	
	return serializedForm;
}
@end

@implementation WokSearchServiceSoapBindingResponse
@synthesize headers;
@synthesize bodyParts;
@synthesize error;
- (id)init
{
	if((self = [super init])) {
		headers = nil;
		bodyParts = nil;
		error = nil;
	}
	
	return self;
}
- (void)dealloc {
	self.headers = nil;
	self.bodyParts = nil;
	self.error = nil;	
	[super dealloc];
}
@end

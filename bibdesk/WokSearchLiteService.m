#import "WokSearchLiteService.h"

@implementation WokSearchLiteServiceElement
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
				id newChild = [NSNumber deserializeNode:cur];
				self.firstRecord = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "count")) {
				id newChild = [NSNumber deserializeNode:cur];
				self.count = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "sortField")) {
				id newChild = [WokSearchLiteService_sortField deserializeNode:cur];
				if(newChild != nil) [self.sortField addObject:newChild];
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
				id newChild = [NSString deserializeNode:cur];
				self.queryId = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "retrieveParameters")) {
				id newChild = [WokSearchLiteService_retrieveParameters deserializeNode:cur];
				self.retrieveParameters = newChild;
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
				id newChild = [NSString deserializeNode:cur];
				self.uid = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "title")) {
				id newChild = [WokSearchLiteService_labelValuesPair deserializeNode:cur];
				if(newChild != nil) [self.title addObject:newChild];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "source")) {
				id newChild = [WokSearchLiteService_labelValuesPair deserializeNode:cur];
				if(newChild != nil) [self.source addObject:newChild];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "authors")) {
				id newChild = [WokSearchLiteService_labelValuesPair deserializeNode:cur];
				if(newChild != nil) [self.authors addObject:newChild];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "keywords")) {
				id newChild = [WokSearchLiteService_labelValuesPair deserializeNode:cur];
				if(newChild != nil) [self.keywords addObject:newChild];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "other")) {
				id newChild = [WokSearchLiteService_labelValuesPair deserializeNode:cur];
				if(newChild != nil) [self.other addObject:newChild];
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
				id newChild = [WokSearchLiteService_liteRecord deserializeNode:cur];
				self.parent = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "records")) {
				id newChild = [WokSearchLiteService_liteRecord deserializeNode:cur];
				if(newChild != nil) [self.records addObject:newChild];
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
				id newChild = [WokSearchLiteService_searchResults deserializeNode:cur];
				self.return_ = newChild;
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
				id newChild = [WokSearchLiteService_retrieveParameters deserializeNode:cur];
				self.retrieveParameters = newChild;
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
				id newChild = [WokSearchLiteService_searchResults deserializeNode:cur];
				self.return_ = newChild;
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
				id newChild = [NSString deserializeNode:cur];
				self.databaseId = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "userQuery")) {
				id newChild = [NSString deserializeNode:cur];
				self.userQuery = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "editions")) {
				id newChild = [WokSearchLiteService_editionDesc deserializeNode:cur];
				if(newChild != nil) [self.editions addObject:newChild];
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "symbolicTimeSpan")) {
				id newChild = [NSString deserializeNode:cur];
				self.symbolicTimeSpan = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "timeSpan")) {
				id newChild = [WokSearchLiteService_timeSpan deserializeNode:cur];
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
				id newChild = [WokSearchLiteService_queryParameters deserializeNode:cur];
				self.queryParameters = newChild;
			}
			if(xmlStrEqual(cur->name, (const xmlChar *) "retrieveParameters")) {
				id newChild = [WokSearchLiteService_retrieveParameters deserializeNode:cur];
				self.retrieveParameters = newChild;
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
				id newChild = [WokSearchLiteService_searchResults deserializeNode:cur];
				self.return_ = newChild;
			}
		}
	}
}
@end

@implementation WokSearchLiteService
+ (WokSearchLiteServiceSoapBinding *)WokSearchLiteServiceSoapBinding
{
	return [[[WokSearchLiteServiceSoapBinding alloc] initWithAddress:@"http://search.webofknowledge.com/esti/wokmws/ws/WokSearchLite"] autorelease];
}
@end

@implementation WokSearchLiteServiceSoapBinding
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
- (WokSearchLiteServiceSoapBindingResponse *)performSynchronousOperationWitBodyElements:(NSDictionary *)bodyElements
{
	WokSearchLiteServiceSoapBindingOperation *operation = [[[WokSearchLiteServiceSoapBindingOperation alloc] initWithBinding:self delegate:self bodyElements:bodyElements] autorelease];
	
	synchronousOperationComplete = NO;
	[operation start];
	
	// Now wait for response
	NSRunLoop *theRL = [NSRunLoop currentRunLoop];
	
	while (!synchronousOperationComplete && [theRL runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]);
	return operation.response;
}
- (void)performAsynchronousOperationWithBodyElements:(NSDictionary *)bodyElements delegate:(id<WokSearchLiteServiceSoapBindingResponseDelegate>)responseDelegate
{
	WokSearchLiteServiceSoapBindingOperation *operation = [[[WokSearchLiteServiceSoapBindingOperation alloc] initWithBinding:self delegate:responseDelegate bodyElements:bodyElements] autorelease];
	
	[operation start];
}
- (void) operation:(WokSearchLiteServiceSoapBindingOperation *)operation completedWithResponse:(WokSearchLiteServiceSoapBindingResponse *)response
{
	synchronousOperationComplete = YES;
}
- (WokSearchLiteServiceSoapBindingResponse *)retrieveByIdUsingParameters:(WokSearchLiteService_retrieveById *)aParameters 
{
	NSDictionary *bodyElements = [NSDictionary dictionaryWithObject:aParameters forKey:@"retrieveById"];
	return [self performSynchronousOperationWitBodyElements:bodyElements];
}
- (void)retrieveByIdAsyncUsingParameters:(WokSearchLiteService_retrieveById *)aParameters  delegate:(id<WokSearchLiteServiceSoapBindingResponseDelegate>)responseDelegate
{
	NSDictionary *bodyElements = [NSDictionary dictionaryWithObject:aParameters forKey:@"retrieveById"];
	[self performAsynchronousOperationWithBodyElements:bodyElements delegate:responseDelegate];
}
- (WokSearchLiteServiceSoapBindingResponse *)retrieveUsingParameters:(WokSearchLiteService_retrieve *)aParameters 
{
	NSDictionary *bodyElements = [NSDictionary dictionaryWithObject:aParameters forKey:@"retrieve"];
	return [self performSynchronousOperationWitBodyElements:bodyElements];
}
- (void)retrieveAsyncUsingParameters:(WokSearchLiteService_retrieve *)aParameters  delegate:(id<WokSearchLiteServiceSoapBindingResponseDelegate>)responseDelegate
{
	NSDictionary *bodyElements = [NSDictionary dictionaryWithObject:aParameters forKey:@"retrieve"];
	[self performAsynchronousOperationWithBodyElements:bodyElements delegate:responseDelegate];
}
- (WokSearchLiteServiceSoapBindingResponse *)searchUsingParameters:(WokSearchLiteService_search *)aParameters 
{
	NSDictionary *bodyElements = [NSDictionary dictionaryWithObject:aParameters forKey:@"search"];
	return [self performSynchronousOperationWitBodyElements:bodyElements];
}
- (void)searchAsyncUsingParameters:(WokSearchLiteService_search *)aParameters  delegate:(id<WokSearchLiteServiceSoapBindingResponseDelegate>)responseDelegate
{
	NSDictionary *bodyElements = [NSDictionary dictionaryWithObject:aParameters forKey:@"search"];
	[self performAsynchronousOperationWithBodyElements:bodyElements delegate:responseDelegate];
}
- (void)sendHTTPCallUsingBody:(NSString *)outputBody soapAction:(NSString *)soapAction forOperation:(WokSearchLiteServiceSoapBindingOperation *)operation
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
	[request setValue:[NSString stringWithFormat:@"%u", [bodyData length]] forHTTPHeaderField:@"Content-Length"];
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

@implementation WokSearchLiteServiceSoapBindingOperation
@synthesize binding;
@synthesize bodyElements;
@synthesize response;
@synthesize delegate;
@synthesize responseData;
@synthesize urlConnection;
- (id)initWithBinding:(WokSearchLiteServiceSoapBinding *)aBinding delegate:(id<WokSearchLiteServiceSoapBindingResponseDelegate>)aDelegate bodyElements:(NSDictionary *)aBodyElements
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
	response = [WokSearchLiteServiceSoapBindingResponse new];
	
	WokSearchLiteServiceSoapBinding_envelope *envelope = [WokSearchLiteServiceSoapBinding_envelope sharedInstance];
	
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
		NSLog(@"ResponseStatus: %u\n", [httpResponse statusCode]);
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
				
			error = [NSError errorWithDomain:@"WokSearchLiteServiceSoapBindingResponseHTTP" code:[httpResponse statusCode] userInfo:userInfo];
		} else {
			NSDictionary *userInfo = [NSDictionary dictionaryWithObject:
																[NSString stringWithFormat: @"Unexpected response MIME type to SOAP call:%@", urlResponse.MIMEType]
																													 forKey:NSLocalizedDescriptionKey];
			error = [NSError errorWithDomain:@"WokSearchLiteServiceSoapBindingResponseHTTP" code:1 userInfo:userInfo];
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
			
			response.error = [NSError errorWithDomain:@"WokSearchLiteServiceSoapBindingResponseXML" code:1 userInfo:userInfo];
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
								else if((responseClass = NSClassFromString([NSString stringWithFormat:@"%@_%s", @"WokSearchLiteService", bodyNode->name]))) {
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

static WokSearchLiteServiceSoapBinding_envelope *WokSearchLiteServiceSoapBindingSharedEnvelopeInstance = nil;
@implementation WokSearchLiteServiceSoapBinding_envelope
+ (WokSearchLiteServiceSoapBinding_envelope *)sharedInstance
{
	if(WokSearchLiteServiceSoapBindingSharedEnvelopeInstance == nil) {
		WokSearchLiteServiceSoapBindingSharedEnvelopeInstance = [WokSearchLiteServiceSoapBinding_envelope new];
	}
	
	return WokSearchLiteServiceSoapBindingSharedEnvelopeInstance;
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
	
	xmlNsPtr woksearchliteNs = xmlNewNs(root, (const xmlChar*)"http://woksearchlite.v3.wokmws.thomsonreuters.com", (const xmlChar*)"woksearchlite");
	
	xmlNewNs(root, (const xmlChar*)"http://schemas.xmlsoap.org/wsdl/", (const xmlChar*)"wsdl");
	xmlNewNs(root, (const xmlChar*)"http://schemas.xmlsoap.org/wsdl/soap/", (const xmlChar*)"soap");
	
	if((headerElements != nil) && ([headerElements count] > 0)) {
		xmlNodePtr headerNode = xmlNewDocNode(doc, soapEnvelopeNs, (const xmlChar*)"Header", NULL);
		xmlAddChild(root, headerNode);
		
		for(NSString *key in [headerElements allKeys]) {
			id header = [headerElements objectForKey:key];
			xmlNodePtr child = xmlAddChild(headerNode, [header xmlNodeForDoc:doc elementName:key elementNSPrefix:nil]);
			xmlSetNs(child, woksearchliteNs);
		}
	}
	
	if((bodyElements != nil) && ([bodyElements count] > 0)) {
		xmlNodePtr bodyNode = xmlNewDocNode(doc, soapEnvelopeNs, (const xmlChar*)"Body", NULL);
		xmlAddChild(root, bodyNode);
		
		for(NSString *key in [bodyElements allKeys]) {
			id body = [bodyElements objectForKey:key];
			xmlNodePtr child = xmlAddChild(bodyNode, [body xmlNodeForDoc:doc elementName:key elementNSPrefix:nil]);
			xmlSetNs(child, woksearchliteNs);
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

@implementation WokSearchLiteServiceSoapBindingResponse
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

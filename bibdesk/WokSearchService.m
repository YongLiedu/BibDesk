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
- (void)addElementsToNode:(NSXMLElement *)node
{
	if(self.name!= nil) {
		[node addChild:[self.name XMLNodeWithName:@"name" prefix:nil]];
	}
	if(self.sort!= nil) {
		[node addChild:[self.sort XMLNodeWithName:@"sort" prefix:nil]];
	}
}
@synthesize name;
@synthesize sort;
- (void)deserializeElementsFromNode:(NSXMLElement *)node
{
	for( node in [node children] ) {
		if([node kind] == NSXMLElementKind) {
			if([[node localName] isEqualToString:@"name"]) {
				self.name = [NSString deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"sort"]) {
				self.sort = [NSString deserializeNode:node];
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
- (void)addElementsToNode:(NSXMLElement *)node
{
	if(self.collectionName!= nil) {
		[node addChild:[self.collectionName XMLNodeWithName:@"collectionName" prefix:nil]];
	}
	if(self.fieldName!= nil) {
		for(NSString * child in self.fieldName) {
			[node addChild:[child XMLNodeWithName:@"fieldName" prefix:nil]];
		}
	}
}
@synthesize collectionName;
@synthesize fieldName;
- (void)addFieldName:(NSString *)toAdd
{
	if(toAdd != nil) [fieldName addObject:toAdd];
}
- (void)deserializeElementsFromNode:(NSXMLElement *)node
{
	for( node in [node children] ) {
		if([node kind] == NSXMLElementKind) {
			if([[node localName] isEqualToString:@"collectionName"]) {
				self.collectionName = [NSString deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"fieldName"]) {
				[self addFieldName:[NSString deserializeNode:node]];
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
- (void)addElementsToNode:(NSXMLElement *)node
{
	if(self.key!= nil) {
		[node addChild:[self.key XMLNodeWithName:@"key" prefix:nil]];
	}
	if(self.value!= nil) {
		[node addChild:[self.value XMLNodeWithName:@"value" prefix:nil]];
	}
}
@synthesize key;
@synthesize value;
- (void)deserializeElementsFromNode:(NSXMLElement *)node
{
	for( node in [node children] ) {
		if([node kind] == NSXMLElementKind) {
			if([[node localName] isEqualToString:@"key"]) {
				self.key = [NSString deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"value"]) {
				self.value = [NSString deserializeNode:node];
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
- (void)addElementsToNode:(NSXMLElement *)node
{
	if(self.firstRecord!= nil) {
		[node addChild:[self.firstRecord XMLNodeWithName:@"firstRecord" prefix:nil]];
	}
	if(self.count!= nil) {
		[node addChild:[self.count XMLNodeWithName:@"count" prefix:nil]];
	}
	if(self.sortField!= nil) {
		for(WokSearchService_sortField * child in self.sortField) {
			[node addChild:[child XMLNodeWithName:@"sortField" prefix:nil]];
		}
	}
	if(self.viewField!= nil) {
		for(WokSearchService_viewField * child in self.viewField) {
			[node addChild:[child XMLNodeWithName:@"viewField" prefix:nil]];
		}
	}
	if(self.option!= nil) {
		for(WokSearchService_keyValuePair * child in self.option) {
			[node addChild:[child XMLNodeWithName:@"option" prefix:nil]];
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
- (void)deserializeElementsFromNode:(NSXMLElement *)node
{
	for( node in [node children] ) {
		if([node kind] == NSXMLElementKind) {
			if([[node localName] isEqualToString:@"firstRecord"]) {
				self.firstRecord = [NSNumber deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"count"]) {
				self.count = [NSNumber deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"sortField"]) {
				[self addSortField:[WokSearchService_sortField deserializeNode:node]];
			}
			if([[node localName] isEqualToString:@"viewField"]) {
				[self addViewField:[WokSearchService_viewField deserializeNode:node]];
			}
			if([[node localName] isEqualToString:@"option"]) {
				[self addOption:[WokSearchService_keyValuePair deserializeNode:node]];
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
- (void)addElementsToNode:(NSXMLElement *)node
{
	if(self.databaseId!= nil) {
		[node addChild:[self.databaseId XMLNodeWithName:@"databaseId" prefix:nil]];
	}
	if(self.uid!= nil) {
		[node addChild:[self.uid XMLNodeWithName:@"uid" prefix:nil]];
	}
	if(self.queryLanguage!= nil) {
		[node addChild:[self.queryLanguage XMLNodeWithName:@"queryLanguage" prefix:nil]];
	}
	if(self.retrieveParameters!= nil) {
		[node addChild:[self.retrieveParameters XMLNodeWithName:@"retrieveParameters" prefix:nil]];
	}
}
@synthesize databaseId;
@synthesize uid;
@synthesize queryLanguage;
@synthesize retrieveParameters;
- (void)deserializeElementsFromNode:(NSXMLElement *)node
{
	for( node in [node children] ) {
		if([node kind] == NSXMLElementKind) {
			if([[node localName] isEqualToString:@"databaseId"]) {
				self.databaseId = [NSString deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"uid"]) {
				self.uid = [NSString deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"queryLanguage"]) {
				self.queryLanguage = [NSString deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"retrieveParameters"]) {
				self.retrieveParameters = [WokSearchService_retrieveParameters deserializeNode:node];
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
- (void)addElementsToNode:(NSXMLElement *)node
{
	if(self.uid!= nil) {
		[node addChild:[self.uid XMLNodeWithName:@"uid" prefix:nil]];
	}
	if(self.docid!= nil) {
		[node addChild:[self.docid XMLNodeWithName:@"docid" prefix:nil]];
	}
	if(self.articleId!= nil) {
		[node addChild:[self.articleId XMLNodeWithName:@"articleId" prefix:nil]];
	}
	if(self.citedAuthor!= nil) {
		[node addChild:[self.citedAuthor XMLNodeWithName:@"citedAuthor" prefix:nil]];
	}
	if(self.timesCited!= nil) {
		[node addChild:[self.timesCited XMLNodeWithName:@"timesCited" prefix:nil]];
	}
	if(self.year!= nil) {
		[node addChild:[self.year XMLNodeWithName:@"year" prefix:nil]];
	}
	if(self.page!= nil) {
		[node addChild:[self.page XMLNodeWithName:@"page" prefix:nil]];
	}
	if(self.volume!= nil) {
		[node addChild:[self.volume XMLNodeWithName:@"volume" prefix:nil]];
	}
	if(self.citedTitle!= nil) {
		[node addChild:[self.citedTitle XMLNodeWithName:@"citedTitle" prefix:nil]];
	}
	if(self.citedWork!= nil) {
		[node addChild:[self.citedWork XMLNodeWithName:@"citedWork" prefix:nil]];
	}
	if(self.hot!= nil) {
		[node addChild:[self.hot XMLNodeWithName:@"hot" prefix:nil]];
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
- (void)deserializeElementsFromNode:(NSXMLElement *)node
{
	for( node in [node children] ) {
		if([node kind] == NSXMLElementKind) {
			if([[node localName] isEqualToString:@"uid"]) {
				self.uid = [NSString deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"docid"]) {
				self.docid = [NSString deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"articleId"]) {
				self.articleId = [NSString deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"citedAuthor"]) {
				self.citedAuthor = [NSString deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"timesCited"]) {
				self.timesCited = [NSString deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"year"]) {
				self.year = [NSString deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"page"]) {
				self.page = [NSString deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"volume"]) {
				self.volume = [NSString deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"citedTitle"]) {
				self.citedTitle = [NSString deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"citedWork"]) {
				self.citedWork = [NSString deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"hot"]) {
				self.hot = [NSString deserializeNode:node];
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
- (void)addElementsToNode:(NSXMLElement *)node
{
	if(self.queryId!= nil) {
		[node addChild:[self.queryId XMLNodeWithName:@"queryId" prefix:nil]];
	}
	if(self.references!= nil) {
		for(WokSearchService_citedReference * child in self.references) {
			[node addChild:[child XMLNodeWithName:@"references" prefix:nil]];
		}
	}
	if(self.recordsFound!= nil) {
		[node addChild:[self.recordsFound XMLNodeWithName:@"recordsFound" prefix:nil]];
	}
	if(self.recordsSearched!= nil) {
		[node addChild:[self.recordsSearched XMLNodeWithName:@"recordsSearched" prefix:nil]];
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
- (void)deserializeElementsFromNode:(NSXMLElement *)node
{
	for( node in [node children] ) {
		if([node kind] == NSXMLElementKind) {
			if([[node localName] isEqualToString:@"queryId"]) {
				self.queryId = [NSString deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"references"]) {
				[self addReferences:[WokSearchService_citedReference deserializeNode:node]];
			}
			if([[node localName] isEqualToString:@"recordsFound"]) {
				self.recordsFound = [NSNumber deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"recordsSearched"]) {
				self.recordsSearched = [NSNumber deserializeNode:node];
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
- (void)addElementsToNode:(NSXMLElement *)node
{
	if(self.return_!= nil) {
		[node addChild:[self.return_ XMLNodeWithName:@"return" prefix:nil]];
	}
}
@synthesize return_;
- (void)deserializeElementsFromNode:(NSXMLElement *)node
{
	for( node in [node children] ) {
		if([node kind] == NSXMLElementKind) {
			if([[node localName] isEqualToString:@"return"]) {
				self.return_ = [WokSearchService_citedReferencesSearchResults deserializeNode:node];
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
- (void)addElementsToNode:(NSXMLElement *)node
{
	if(self.queryId!= nil) {
		[node addChild:[self.queryId XMLNodeWithName:@"queryId" prefix:nil]];
	}
	if(self.retrieveParameters!= nil) {
		[node addChild:[self.retrieveParameters XMLNodeWithName:@"retrieveParameters" prefix:nil]];
	}
}
@synthesize queryId;
@synthesize retrieveParameters;
- (void)deserializeElementsFromNode:(NSXMLElement *)node
{
	for( node in [node children] ) {
		if([node kind] == NSXMLElementKind) {
			if([[node localName] isEqualToString:@"queryId"]) {
				self.queryId = [NSString deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"retrieveParameters"]) {
				self.retrieveParameters = [WokSearchService_retrieveParameters deserializeNode:node];
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
- (void)addElementsToNode:(NSXMLElement *)node
{
	if(self.return_!= nil) {
		for(WokSearchService_citedReference * child in self.return_) {
			[node addChild:[child XMLNodeWithName:@"return" prefix:nil]];
		}
	}
}
@synthesize return_;
- (void)addReturn_:(WokSearchService_citedReference *)toAdd
{
	if(toAdd != nil) [return_ addObject:toAdd];
}
- (void)deserializeElementsFromNode:(NSXMLElement *)node
{
	for( node in [node children] ) {
		if([node kind] == NSXMLElementKind) {
			if([[node localName] isEqualToString:@"return"]) {
				[self addReturn_:[WokSearchService_citedReference deserializeNode:node]];
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
- (void)addElementsToNode:(NSXMLElement *)node
{
	if(self.collection!= nil) {
		[node addChild:[self.collection XMLNodeWithName:@"collection" prefix:nil]];
	}
	if(self.edition!= nil) {
		[node addChild:[self.edition XMLNodeWithName:@"edition" prefix:nil]];
	}
}
@synthesize collection;
@synthesize edition;
- (void)deserializeElementsFromNode:(NSXMLElement *)node
{
	for( node in [node children] ) {
		if([node kind] == NSXMLElementKind) {
			if([[node localName] isEqualToString:@"collection"]) {
				self.collection = [NSString deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"edition"]) {
				self.edition = [NSString deserializeNode:node];
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
- (void)addElementsToNode:(NSXMLElement *)node
{
	if(self.begin!= nil) {
		[node addChild:[self.begin XMLNodeWithName:@"begin" prefix:nil]];
	}
	if(self.end!= nil) {
		[node addChild:[self.end XMLNodeWithName:@"end" prefix:nil]];
	}
}
@synthesize begin;
@synthesize end;
- (void)deserializeElementsFromNode:(NSXMLElement *)node
{
	for( node in [node children] ) {
		if([node kind] == NSXMLElementKind) {
			if([[node localName] isEqualToString:@"begin"]) {
				self.begin = [NSString deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"end"]) {
				self.end = [NSString deserializeNode:node];
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
- (void)addElementsToNode:(NSXMLElement *)node
{
	if(self.databaseId!= nil) {
		[node addChild:[self.databaseId XMLNodeWithName:@"databaseId" prefix:nil]];
	}
	if(self.uid!= nil) {
		[node addChild:[self.uid XMLNodeWithName:@"uid" prefix:nil]];
	}
	if(self.editions!= nil) {
		for(WokSearchService_editionDesc * child in self.editions) {
			[node addChild:[child XMLNodeWithName:@"editions" prefix:nil]];
		}
	}
	if(self.timeSpan!= nil) {
		[node addChild:[self.timeSpan XMLNodeWithName:@"timeSpan" prefix:nil]];
	}
	if(self.queryLanguage!= nil) {
		[node addChild:[self.queryLanguage XMLNodeWithName:@"queryLanguage" prefix:nil]];
	}
	if(self.retrieveParameters!= nil) {
		[node addChild:[self.retrieveParameters XMLNodeWithName:@"retrieveParameters" prefix:nil]];
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
- (void)deserializeElementsFromNode:(NSXMLElement *)node
{
	for( node in [node children] ) {
		if([node kind] == NSXMLElementKind) {
			if([[node localName] isEqualToString:@"databaseId"]) {
				self.databaseId = [NSString deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"uid"]) {
				self.uid = [NSString deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"editions"]) {
				[self addEditions:[WokSearchService_editionDesc deserializeNode:node]];
			}
			if([[node localName] isEqualToString:@"timeSpan"]) {
				self.timeSpan = [WokSearchService_timeSpan deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"queryLanguage"]) {
				self.queryLanguage = [NSString deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"retrieveParameters"]) {
				self.retrieveParameters = [WokSearchService_retrieveParameters deserializeNode:node];
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
- (void)addElementsToNode:(NSXMLElement *)node
{
	if(self.label!= nil) {
		[node addChild:[self.label XMLNodeWithName:@"label" prefix:nil]];
	}
	if(self.value!= nil) {
		for(NSString * child in self.value) {
			[node addChild:[child XMLNodeWithName:@"value" prefix:nil]];
		}
	}
}
@synthesize label;
@synthesize value;
- (void)addValue:(NSString *)toAdd
{
	if(toAdd != nil) [value addObject:toAdd];
}
- (void)deserializeElementsFromNode:(NSXMLElement *)node
{
	for( node in [node children] ) {
		if([node kind] == NSXMLElementKind) {
			if([[node localName] isEqualToString:@"label"]) {
				self.label = [NSString deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"value"]) {
				[self addValue:[NSString deserializeNode:node]];
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
- (void)addElementsToNode:(NSXMLElement *)node
{
	if(self.queryId!= nil) {
		[node addChild:[self.queryId XMLNodeWithName:@"queryId" prefix:nil]];
	}
	if(self.recordsFound!= nil) {
		[node addChild:[self.recordsFound XMLNodeWithName:@"recordsFound" prefix:nil]];
	}
	if(self.recordsSearched!= nil) {
		[node addChild:[self.recordsSearched XMLNodeWithName:@"recordsSearched" prefix:nil]];
	}
	if(self.parent!= nil) {
		[node addChild:[self.parent XMLNodeWithName:@"parent" prefix:nil]];
	}
	if(self.optionValue!= nil) {
		for(WokSearchService_labelValuesPair * child in self.optionValue) {
			[node addChild:[child XMLNodeWithName:@"optionValue" prefix:nil]];
		}
	}
	if(self.records!= nil) {
		[node addChild:[self.records XMLNodeWithName:@"records" prefix:nil]];
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
- (void)deserializeElementsFromNode:(NSXMLElement *)node
{
	for( node in [node children] ) {
		if([node kind] == NSXMLElementKind) {
			if([[node localName] isEqualToString:@"queryId"]) {
				self.queryId = [NSString deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"recordsFound"]) {
				self.recordsFound = [NSNumber deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"recordsSearched"]) {
				self.recordsSearched = [NSNumber deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"parent"]) {
				self.parent = [NSString deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"optionValue"]) {
				[self addOptionValue:[WokSearchService_labelValuesPair deserializeNode:node]];
			}
			if([[node localName] isEqualToString:@"records"]) {
				self.records = [NSString deserializeNode:node];
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
- (void)addElementsToNode:(NSXMLElement *)node
{
	if(self.return_!= nil) {
		[node addChild:[self.return_ XMLNodeWithName:@"return" prefix:nil]];
	}
}
@synthesize return_;
- (void)deserializeElementsFromNode:(NSXMLElement *)node
{
	for( node in [node children] ) {
		if([node kind] == NSXMLElementKind) {
			if([[node localName] isEqualToString:@"return"]) {
				self.return_ = [WokSearchService_fullRecordSearchResults deserializeNode:node];
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
- (void)addElementsToNode:(NSXMLElement *)node
{
	if(self.databaseId!= nil) {
		[node addChild:[self.databaseId XMLNodeWithName:@"databaseId" prefix:nil]];
	}
	if(self.uid!= nil) {
		[node addChild:[self.uid XMLNodeWithName:@"uid" prefix:nil]];
	}
	if(self.editions!= nil) {
		for(WokSearchService_editionDesc * child in self.editions) {
			[node addChild:[child XMLNodeWithName:@"editions" prefix:nil]];
		}
	}
	if(self.timeSpan!= nil) {
		[node addChild:[self.timeSpan XMLNodeWithName:@"timeSpan" prefix:nil]];
	}
	if(self.queryLanguage!= nil) {
		[node addChild:[self.queryLanguage XMLNodeWithName:@"queryLanguage" prefix:nil]];
	}
	if(self.retrieveParameters!= nil) {
		[node addChild:[self.retrieveParameters XMLNodeWithName:@"retrieveParameters" prefix:nil]];
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
- (void)deserializeElementsFromNode:(NSXMLElement *)node
{
	for( node in [node children] ) {
		if([node kind] == NSXMLElementKind) {
			if([[node localName] isEqualToString:@"databaseId"]) {
				self.databaseId = [NSString deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"uid"]) {
				self.uid = [NSString deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"editions"]) {
				[self addEditions:[WokSearchService_editionDesc deserializeNode:node]];
			}
			if([[node localName] isEqualToString:@"timeSpan"]) {
				self.timeSpan = [WokSearchService_timeSpan deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"queryLanguage"]) {
				self.queryLanguage = [NSString deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"retrieveParameters"]) {
				self.retrieveParameters = [WokSearchService_retrieveParameters deserializeNode:node];
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
- (void)addElementsToNode:(NSXMLElement *)node
{
	if(self.return_!= nil) {
		[node addChild:[self.return_ XMLNodeWithName:@"return" prefix:nil]];
	}
}
@synthesize return_;
- (void)deserializeElementsFromNode:(NSXMLElement *)node
{
	for( node in [node children] ) {
		if([node kind] == NSXMLElementKind) {
			if([[node localName] isEqualToString:@"return"]) {
				self.return_ = [WokSearchService_fullRecordSearchResults deserializeNode:node];
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
- (void)addElementsToNode:(NSXMLElement *)node
{
	if(self.queryId!= nil) {
		[node addChild:[self.queryId XMLNodeWithName:@"queryId" prefix:nil]];
	}
	if(self.retrieveParameters!= nil) {
		[node addChild:[self.retrieveParameters XMLNodeWithName:@"retrieveParameters" prefix:nil]];
	}
}
@synthesize queryId;
@synthesize retrieveParameters;
- (void)deserializeElementsFromNode:(NSXMLElement *)node
{
	for( node in [node children] ) {
		if([node kind] == NSXMLElementKind) {
			if([[node localName] isEqualToString:@"queryId"]) {
				self.queryId = [NSString deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"retrieveParameters"]) {
				self.retrieveParameters = [WokSearchService_retrieveParameters deserializeNode:node];
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
- (void)addElementsToNode:(NSXMLElement *)node
{
	if(self.optionValue!= nil) {
		for(WokSearchService_labelValuesPair * child in self.optionValue) {
			[node addChild:[child XMLNodeWithName:@"optionValue" prefix:nil]];
		}
	}
	if(self.records!= nil) {
		[node addChild:[self.records XMLNodeWithName:@"records" prefix:nil]];
	}
}
@synthesize optionValue;
- (void)addOptionValue:(WokSearchService_labelValuesPair *)toAdd
{
	if(toAdd != nil) [optionValue addObject:toAdd];
}
@synthesize records;
- (void)deserializeElementsFromNode:(NSXMLElement *)node
{
	for( node in [node children] ) {
		if([node kind] == NSXMLElementKind) {
			if([[node localName] isEqualToString:@"optionValue"]) {
				[self addOptionValue:[WokSearchService_labelValuesPair deserializeNode:node]];
			}
			if([[node localName] isEqualToString:@"records"]) {
				self.records = [NSString deserializeNode:node];
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
- (void)addElementsToNode:(NSXMLElement *)node
{
	if(self.return_!= nil) {
		[node addChild:[self.return_ XMLNodeWithName:@"return" prefix:nil]];
	}
}
@synthesize return_;
- (void)deserializeElementsFromNode:(NSXMLElement *)node
{
	for( node in [node children] ) {
		if([node kind] == NSXMLElementKind) {
			if([[node localName] isEqualToString:@"return"]) {
				self.return_ = [WokSearchService_fullRecordData deserializeNode:node];
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
- (void)addElementsToNode:(NSXMLElement *)node
{
	if(self.databaseId!= nil) {
		[node addChild:[self.databaseId XMLNodeWithName:@"databaseId" prefix:nil]];
	}
	if(self.uid!= nil) {
		for(NSString * child in self.uid) {
			[node addChild:[child XMLNodeWithName:@"uid" prefix:nil]];
		}
	}
	if(self.queryLanguage!= nil) {
		[node addChild:[self.queryLanguage XMLNodeWithName:@"queryLanguage" prefix:nil]];
	}
	if(self.retrieveParameters!= nil) {
		[node addChild:[self.retrieveParameters XMLNodeWithName:@"retrieveParameters" prefix:nil]];
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
- (void)deserializeElementsFromNode:(NSXMLElement *)node
{
	for( node in [node children] ) {
		if([node kind] == NSXMLElementKind) {
			if([[node localName] isEqualToString:@"databaseId"]) {
				self.databaseId = [NSString deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"uid"]) {
				[self addUid:[NSString deserializeNode:node]];
			}
			if([[node localName] isEqualToString:@"queryLanguage"]) {
				self.queryLanguage = [NSString deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"retrieveParameters"]) {
				self.retrieveParameters = [WokSearchService_retrieveParameters deserializeNode:node];
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
- (void)addElementsToNode:(NSXMLElement *)node
{
	if(self.return_!= nil) {
		[node addChild:[self.return_ XMLNodeWithName:@"return" prefix:nil]];
	}
}
@synthesize return_;
- (void)deserializeElementsFromNode:(NSXMLElement *)node
{
	for( node in [node children] ) {
		if([node kind] == NSXMLElementKind) {
			if([[node localName] isEqualToString:@"return"]) {
				self.return_ = [WokSearchService_fullRecordSearchResults deserializeNode:node];
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
- (void)addElementsToNode:(NSXMLElement *)node
{
	if(self.databaseId!= nil) {
		[node addChild:[self.databaseId XMLNodeWithName:@"databaseId" prefix:nil]];
	}
	if(self.userQuery!= nil) {
		[node addChild:[self.userQuery XMLNodeWithName:@"userQuery" prefix:nil]];
	}
	if(self.editions!= nil) {
		for(WokSearchService_editionDesc * child in self.editions) {
			[node addChild:[child XMLNodeWithName:@"editions" prefix:nil]];
		}
	}
	if(self.symbolicTimeSpan!= nil) {
		[node addChild:[self.symbolicTimeSpan XMLNodeWithName:@"symbolicTimeSpan" prefix:nil]];
	}
	if(self.timeSpan!= nil) {
		[node addChild:[self.timeSpan XMLNodeWithName:@"timeSpan" prefix:nil]];
	}
	if(self.queryLanguage!= nil) {
		[node addChild:[self.queryLanguage XMLNodeWithName:@"queryLanguage" prefix:nil]];
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
- (void)deserializeElementsFromNode:(NSXMLElement *)node
{
	for( node in [node children] ) {
		if([node kind] == NSXMLElementKind) {
			if([[node localName] isEqualToString:@"databaseId"]) {
				self.databaseId = [NSString deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"userQuery"]) {
				self.userQuery = [NSString deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"editions"]) {
				[self addEditions:[WokSearchService_editionDesc deserializeNode:node]];
			}
			if([[node localName] isEqualToString:@"symbolicTimeSpan"]) {
				self.symbolicTimeSpan = [NSString deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"timeSpan"]) {
				self.timeSpan = [WokSearchService_timeSpan deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"queryLanguage"]) {
				self.queryLanguage = [NSString deserializeNode:node];
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
- (void)addElementsToNode:(NSXMLElement *)node
{
	if(self.queryParameters!= nil) {
		[node addChild:[self.queryParameters XMLNodeWithName:@"queryParameters" prefix:nil]];
	}
	if(self.retrieveParameters!= nil) {
		[node addChild:[self.retrieveParameters XMLNodeWithName:@"retrieveParameters" prefix:nil]];
	}
}
@synthesize queryParameters;
@synthesize retrieveParameters;
- (void)deserializeElementsFromNode:(NSXMLElement *)node
{
	for( node in [node children] ) {
		if([node kind] == NSXMLElementKind) {
			if([[node localName] isEqualToString:@"queryParameters"]) {
				self.queryParameters = [WokSearchService_queryParameters deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"retrieveParameters"]) {
				self.retrieveParameters = [WokSearchService_retrieveParameters deserializeNode:node];
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
- (void)addElementsToNode:(NSXMLElement *)node
{
	if(self.return_!= nil) {
		[node addChild:[self.return_ XMLNodeWithName:@"return" prefix:nil]];
	}
}
@synthesize return_;
- (void)deserializeElementsFromNode:(NSXMLElement *)node
{
	for( node in [node children] ) {
		if([node kind] == NSXMLElementKind) {
			if([[node localName] isEqualToString:@"return"]) {
				self.return_ = [WokSearchService_fullRecordSearchResults deserializeNode:node];
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

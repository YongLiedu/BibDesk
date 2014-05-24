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
- (void)addElementsToNode:(NSXMLElement *)node
{
	if(self.firstRecord!= nil) {
		[node addChild:[self.firstRecord XMLNodeWithName:@"firstRecord" prefix:nil]];
	}
	if(self.count!= nil) {
		[node addChild:[self.count XMLNodeWithName:@"count" prefix:nil]];
	}
	if(self.sortField!= nil) {
		for(WokSearchLiteService_sortField * child in self.sortField) {
			[node addChild:[child XMLNodeWithName:@"sortField" prefix:nil]];
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
				[self addSortField:[WokSearchLiteService_sortField deserializeNode:node]];
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
				self.retrieveParameters = [WokSearchLiteService_retrieveParameters deserializeNode:node];
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
- (void)addElementsToNode:(NSXMLElement *)node
{
	if(self.uid!= nil) {
		[node addChild:[self.uid XMLNodeWithName:@"uid" prefix:nil]];
	}
	if(self.title!= nil) {
		for(WokSearchLiteService_labelValuesPair * child in self.title) {
			[node addChild:[child XMLNodeWithName:@"title" prefix:nil]];
		}
	}
	if(self.source!= nil) {
		for(WokSearchLiteService_labelValuesPair * child in self.source) {
			[node addChild:[child XMLNodeWithName:@"source" prefix:nil]];
		}
	}
	if(self.authors!= nil) {
		for(WokSearchLiteService_labelValuesPair * child in self.authors) {
			[node addChild:[child XMLNodeWithName:@"authors" prefix:nil]];
		}
	}
	if(self.keywords!= nil) {
		for(WokSearchLiteService_labelValuesPair * child in self.keywords) {
			[node addChild:[child XMLNodeWithName:@"keywords" prefix:nil]];
		}
	}
	if(self.other!= nil) {
		for(WokSearchLiteService_labelValuesPair * child in self.other) {
			[node addChild:[child XMLNodeWithName:@"other" prefix:nil]];
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
- (void)deserializeElementsFromNode:(NSXMLElement *)node
{
	for( node in [node children] ) {
		if([node kind] == NSXMLElementKind) {
			if([[node localName] isEqualToString:@"uid"]) {
				self.uid = [NSString deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"title"]) {
				[self addTitle:[WokSearchLiteService_labelValuesPair deserializeNode:node]];
			}
			if([[node localName] isEqualToString:@"source"]) {
				[self addSource:[WokSearchLiteService_labelValuesPair deserializeNode:node]];
			}
			if([[node localName] isEqualToString:@"authors"]) {
				[self addAuthors:[WokSearchLiteService_labelValuesPair deserializeNode:node]];
			}
			if([[node localName] isEqualToString:@"keywords"]) {
				[self addKeywords:[WokSearchLiteService_labelValuesPair deserializeNode:node]];
			}
			if([[node localName] isEqualToString:@"other"]) {
				[self addOther:[WokSearchLiteService_labelValuesPair deserializeNode:node]];
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
	if(self.records!= nil) {
		for(WokSearchLiteService_liteRecord * child in self.records) {
			[node addChild:[child XMLNodeWithName:@"records" prefix:nil]];
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
				self.parent = [WokSearchLiteService_liteRecord deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"records"]) {
				[self addRecords:[WokSearchLiteService_liteRecord deserializeNode:node]];
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
				self.return_ = [WokSearchLiteService_searchResults deserializeNode:node];
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
				self.retrieveParameters = [WokSearchLiteService_retrieveParameters deserializeNode:node];
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
				self.return_ = [WokSearchLiteService_searchResults deserializeNode:node];
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
- (void)addElementsToNode:(NSXMLElement *)node
{
	if(self.databaseId!= nil) {
		[node addChild:[self.databaseId XMLNodeWithName:@"databaseId" prefix:nil]];
	}
	if(self.userQuery!= nil) {
		[node addChild:[self.userQuery XMLNodeWithName:@"userQuery" prefix:nil]];
	}
	if(self.editions!= nil) {
		for(WokSearchLiteService_editionDesc * child in self.editions) {
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
- (void)addEditions:(WokSearchLiteService_editionDesc *)toAdd
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
				[self addEditions:[WokSearchLiteService_editionDesc deserializeNode:node]];
			}
			if([[node localName] isEqualToString:@"symbolicTimeSpan"]) {
				self.symbolicTimeSpan = [NSString deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"timeSpan"]) {
				self.timeSpan = [WokSearchLiteService_timeSpan deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"queryLanguage"]) {
				self.queryLanguage = [NSString deserializeNode:node];
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
				self.queryParameters = [WokSearchLiteService_queryParameters deserializeNode:node];
			}
			if([[node localName] isEqualToString:@"retrieveParameters"]) {
				self.retrieveParameters = [WokSearchLiteService_retrieveParameters deserializeNode:node];
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
				self.return_ = [WokSearchLiteService_searchResults deserializeNode:node];
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

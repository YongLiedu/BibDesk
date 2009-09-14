/*-
 * WSDL stubs for:  http://wok-ws.isiknowledge.com/esti/soap/SearchRetrieve?wsdl
 *   Generated by:  amaxwell
 *           Date:  Tue Jul 10 15:57:13 2007
 *        Emitter:  Objective-C
 */

#import "BDSKISIWebServices.h"

static NSString *BDSKISINamespace = nil;
static NSString *BDSKISIEndpoint = nil;

@implementation BDSKWSGeneratedObj

+ (void)initialize
{
    OBINITIALIZE;
    BDSKISIEndpoint = [([[NSUserDefaults standardUserDefaults] objectForKey:@"BDSKISIEndpoint"] ?: @"http://wok-ws.isiknowledge.com/esti/soap/SearchRetrieve") copy];
    BDSKISINamespace = [([[NSUserDefaults standardUserDefaults] objectForKey:@"BDSKISINamespace"] ?: @"http://esti.isinet.com/soap/search") copy];
}

@end

/*-
 *   Method Name:  describeDatabase
 * Documentation:  <no documentation>
 */
@implementation BDSKISIDescribeDatabase
- (void) setParameters:(NSString*) in_databaseID in_format:(NSString*) in_format
{
    id _paramValues[] = {    
        in_databaseID,        
        in_format,        
    };    
    NSString* _paramNames[] = {    
        @"databaseID",        
        @"format",        
    };    
    [super setParameters:2 values: _paramValues names: _paramNames];    
}

- (id) resultValue
{
    return [[super getResultDictionary] objectForKey: @"describeDatabaseReturn"];    
}

- (WSMethodInvocationRef) genCreateInvocationRef
{
    return [self createInvocationRef    
               /*endpoint*/: BDSKISIEndpoint            
                 methodName: @"describeDatabase"            
                 protocol: (NSString*) kWSSOAP2001Protocol            
                      style: (NSString*) kWSSOAPStyleRPC            
                 soapAction: @"describeDatabase"            
            methodNamespace: BDSKISINamespace            
        ];        
}

@end; /* describeDatabase */


/*-
 *   Method Name:  publisherLinks
 * Documentation:  <no documentation>
 */
@implementation BDSKISIPublisherLinks
- (void) setParameters:(NSString*) in_query in_jsetList:(NSString*) in_jsetList
{
    id _paramValues[] = {    
        in_query,        
        in_jsetList,        
    };    
    NSString* _paramNames[] = {    
        @"query",        
        @"jsetList",        
    };    
    [super setParameters:2 values: _paramValues names: _paramNames];    
}

- (id) resultValue
{
    return [[super getResultDictionary] objectForKey: @"publisherLinksReturn"];    
}

- (WSMethodInvocationRef) genCreateInvocationRef
{
    return [self createInvocationRef    
               /*endpoint*/: BDSKISIEndpoint            
                 methodName: @"publisherLinks"            
                 protocol: (NSString*) kWSSOAP2001Protocol            
                      style: (NSString*) kWSSOAPStyleRPC            
                 soapAction: @"publisherLinks"            
            methodNamespace: BDSKISINamespace            
        ];        
}

@end; /* publisherLinks */


/*-
 *   Method Name:  citingArticlesByRecids
 * Documentation:  <no documentation>
 */
@implementation BDSKISICitingArticlesByRecids
- (void) setParameters:(NSString*) in_databaseID in_recids:(NSString*) in_recids in_depth:(NSString*) in_depth in_editions:(NSString*) in_editions in_sort:(NSString*) in_sort in_firstRec:(SInt32) in_firstRec in_numRecs:(SInt32) in_numRecs in_fields:(NSString*) in_fields
{
    id _paramValues[] = {    
        in_databaseID,        
        in_recids,        
        in_depth,        
        in_editions,        
        in_sort,        
        [NSNumber numberWithInt: in_firstRec],        
        [NSNumber numberWithInt: in_numRecs],        
        in_fields,        
    };    
    NSString* _paramNames[] = {    
        @"databaseID",        
        @"recids",        
        @"depth",        
        @"editions",        
        @"sort",        
        @"firstRec",        
        @"numRecs",        
        @"fields",        
    };    
    [super setParameters:8 values: _paramValues names: _paramNames];    
}

- (id) resultValue
{
    return [[super getResultDictionary] objectForKey: @"citingArticlesByRecidsReturn"];    
}

- (WSMethodInvocationRef) genCreateInvocationRef
{
    return [self createInvocationRef    
               /*endpoint*/: BDSKISIEndpoint            
                 methodName: @"citingArticlesByRecids"            
                 protocol: (NSString*) kWSSOAP2001Protocol            
                      style: (NSString*) kWSSOAPStyleRPC            
                 soapAction: @"citingArticlesByRecids"            
            methodNamespace: BDSKISINamespace            
        ];        
}

@end; /* citingArticlesByRecids */


/*-
 *   Method Name:  retrieveRecid
 * Documentation:  <no documentation>
 */
@implementation BDSKISIRetrieveRecid
- (void) setParameters:(NSString*) in_databaseID in_recid:(NSString*) in_recid in_sort:(NSString*) in_sort in_fields:(NSString*) in_fields
{
    id _paramValues[] = {    
        in_databaseID,        
        in_recid,        
        in_sort,        
        in_fields,        
    };    
    NSString* _paramNames[] = {    
        @"databaseID",        
        @"recid",        
        @"sort",        
        @"fields",        
    };    
    [super setParameters:4 values: _paramValues names: _paramNames];    
}

- (id) resultValue
{
    return [[super getResultDictionary] objectForKey: @"retrieveRecidReturn"];    
}

- (WSMethodInvocationRef) genCreateInvocationRef
{
    return [self createInvocationRef    
               /*endpoint*/: BDSKISIEndpoint            
                 methodName: @"retrieveRecid"            
                 protocol: (NSString*) kWSSOAP2001Protocol            
                      style: (NSString*) kWSSOAPStyleRPC            
                 soapAction: @"retrieveRecid"            
            methodNamespace: BDSKISINamespace            
        ];        
}

@end; /* retrieveRecid */


/*-
 *   Method Name:  sharedReferences
 * Documentation:  <no documentation>
 */
@implementation BDSKISISharedReferences
- (void) setParameters:(NSString*) in_databaseID in_primaryKeys:(NSString*) in_primaryKeys
{
    id _paramValues[] = {    
        in_databaseID,        
        in_primaryKeys,        
    };    
    NSString* _paramNames[] = {    
        @"databaseID",        
        @"primaryKeys",        
    };    
    [super setParameters:2 values: _paramValues names: _paramNames];    
}

- (id) resultValue
{
    return [[super getResultDictionary] objectForKey: @"sharedReferencesReturn"];    
}

- (WSMethodInvocationRef) genCreateInvocationRef
{
    return [self createInvocationRef    
               /*endpoint*/: BDSKISIEndpoint            
                 methodName: @"sharedReferences"            
                 protocol: (NSString*) kWSSOAP2001Protocol            
                      style: (NSString*) kWSSOAPStyleRPC            
                 soapAction: @"sharedReferences"            
            methodNamespace: BDSKISINamespace            
        ];        
}

@end; /* sharedReferences */


/*-
 *   Method Name:  browseDictionary
 * Documentation:  <no documentation>
 */
@implementation BDSKISIBrowseDictionary
- (void) setParameters:(NSString*) in_databaseID in_term:(NSString*) in_term in_index:(NSString*) in_index in_linesBefore:(SInt32) in_linesBefore in_linesAfter:(SInt32) in_linesAfter in_pageNumber:(SInt32) in_pageNumber in_depth:(NSString*) in_depth in_editions:(NSString*) in_editions
{
    id _paramValues[] = {    
        in_databaseID,        
        in_term,        
        in_index,        
        [NSNumber numberWithInt: in_linesBefore],        
        [NSNumber numberWithInt: in_linesAfter],        
        [NSNumber numberWithInt: in_pageNumber],        
        in_depth,        
        in_editions,        
    };    
    NSString* _paramNames[] = {    
        @"databaseID",        
        @"term",        
        @"index",        
        @"linesBefore",        
        @"linesAfter",        
        @"pageNumber",        
        @"depth",        
        @"editions",        
    };    
    [super setParameters:8 values: _paramValues names: _paramNames];    
}

- (id) resultValue
{
    return [[super getResultDictionary] objectForKey: @"browseDictionaryReturn"];    
}

- (WSMethodInvocationRef) genCreateInvocationRef
{
    return [self createInvocationRef    
               /*endpoint*/: BDSKISIEndpoint            
                 methodName: @"browseDictionary"            
                 protocol: (NSString*) kWSSOAP2001Protocol            
                      style: (NSString*) kWSSOAPStyleRPC            
                 soapAction: @"browseDictionary"            
            methodNamespace: BDSKISINamespace            
        ];        
}

@end; /* browseDictionary */


/*-
 *   Method Name:  mapTerms
 * Documentation:  <no documentation>
 */
@implementation BDSKISIMapTerms
- (void) setParameters:(NSString*) in_databaseID in_index:(NSString*) in_index in_terms:(NSString*) in_terms
{
    id _paramValues[] = {    
        in_databaseID,        
        in_index,        
        in_terms,        
    };    
    NSString* _paramNames[] = {    
        @"databaseID",        
        @"index",        
        @"terms",        
    };    
    [super setParameters:3 values: _paramValues names: _paramNames];    
}

- (id) resultValue
{
    return [[super getResultDictionary] objectForKey: @"mapTermsReturn"];    
}

- (WSMethodInvocationRef) genCreateInvocationRef
{
    return [self createInvocationRef    
               /*endpoint*/: BDSKISIEndpoint            
                 methodName: @"mapTerms"            
                 protocol: (NSString*) kWSSOAP2001Protocol            
                      style: (NSString*) kWSSOAPStyleRPC            
                 soapAction: @"mapTerms"            
            methodNamespace: BDSKISINamespace            
        ];        
}

@end; /* mapTerms */


/*-
 *   Method Name:  summary
 * Documentation:  <no documentation>
 */
@implementation BDSKISISummary
- (void) setParameters:(NSString*) in_databaseID in_query:(NSString*) in_query in_depth:(NSString*) in_depth in_editions:(NSString*) in_editions in_sort:(NSString*) in_sort in_firstRec:(SInt32) in_firstRec in_numRecs:(SInt32) in_numRecs
{
    id _paramValues[] = {    
        in_databaseID,        
        in_query,        
        in_depth,        
        in_editions,        
        in_sort,        
        [NSNumber numberWithInt: in_firstRec],        
        [NSNumber numberWithInt: in_numRecs],        
    };    
    NSString* _paramNames[] = {    
        @"databaseID",        
        @"query",        
        @"depth",        
        @"editions",        
        @"sort",        
        @"firstRec",        
        @"numRecs",        
    };    
    [super setParameters:7 values: _paramValues names: _paramNames];    
}

- (id) resultValue
{
    return [[super getResultDictionary] objectForKey: @"summaryReturn"];    
}

- (WSMethodInvocationRef) genCreateInvocationRef
{
    return [self createInvocationRef    
               /*endpoint*/: BDSKISIEndpoint            
                 methodName: @"summary"            
                 protocol: (NSString*) kWSSOAP2001Protocol            
                      style: (NSString*) kWSSOAPStyleRPC            
                 soapAction: @"summary"            
            methodNamespace: BDSKISINamespace            
        ];        
}

@end; /* summary */


/*-
 *   Method Name:  retrieve
 * Documentation:  <no documentation>
 */
@implementation BDSKISIRetrieve
- (void) setParameters:(NSString*) in_databaseID in_primaryKeys:(NSString*) in_primaryKeys in_sort:(NSString*) in_sort in_fields:(NSString*) in_fields
{
    id _paramValues[] = {    
        in_databaseID,        
        in_primaryKeys,        
        in_sort,        
        in_fields,        
    };    
    NSString* _paramNames[] = {    
        @"databaseID",        
        @"primaryKeys",        
        @"sort",        
        @"fields",        
    };    
    [super setParameters:4 values: _paramValues names: _paramNames];    
}

- (id) resultValue
{
    return [[super getResultDictionary] objectForKey: @"retrieveReturn"];    
}

- (WSMethodInvocationRef) genCreateInvocationRef
{
    return [self createInvocationRef    
               /*endpoint*/: BDSKISIEndpoint            
                 methodName: @"retrieve"            
                 protocol: (NSString*) kWSSOAP2001Protocol            
                      style: (NSString*) kWSSOAPStyleRPC            
                 soapAction: @"retrieve"            
            methodNamespace: BDSKISINamespace            
        ];        
}

@end; /* retrieve */


/*-
 *   Method Name:  searchRetrieve
 * Documentation:  <no documentation>
 */
@implementation BDSKISISearchRetrieve
- (void) setParameters:(NSString*) in_databaseID in_query:(NSString*) in_query in_depth:(NSString*) in_depth in_editions:(NSString*) in_editions in_sort:(NSString*) in_sort in_firstRec:(SInt32) in_firstRec in_numRecs:(SInt32) in_numRecs in_fields:(NSString*) in_fields
{
    id _paramValues[] = {    
        in_databaseID,        
        in_query,        
        in_depth,        
        in_editions,        
        in_sort,        
        [NSNumber numberWithInt: in_firstRec],        
        [NSNumber numberWithInt: in_numRecs],        
        in_fields,        
    };    
    NSString* _paramNames[] = {    
        @"databaseID",        
        @"query",        
        @"depth",        
        @"editions",        
        @"sort",        
        @"firstRec",        
        @"numRecs",        
        @"fields",        
    };    
    [super setParameters:8 values: _paramValues names: _paramNames];    
}

- (id) resultValue
{
    return [[super getResultDictionary] objectForKey: @"searchRetrieveReturn"];    
}

- (WSMethodInvocationRef) genCreateInvocationRef
{
    return [self createInvocationRef    
               /*endpoint*/: BDSKISIEndpoint            
                 methodName: @"searchRetrieve"            
                 protocol: (NSString*) kWSSOAP2001Protocol            
                      style: (NSString*) kWSSOAPStyleRPC            
                 soapAction: @"searchRetrieve"            
            methodNamespace: BDSKISINamespace            
        ];        
}

@end; /* searchRetrieve */


/*-
 *   Method Name:  search
 * Documentation:  <no documentation>
 */
@implementation BDSKISISearch
- (void) setParameters:(NSString*) in_databaseID in_query:(NSString*) in_query in_depth:(NSString*) in_depth in_editions:(NSString*) in_editions in_firstRec:(SInt32) in_firstRec in_numRecs:(SInt32) in_numRecs
{
    id _paramValues[] = {    
        in_databaseID,        
        in_query,        
        in_depth,        
        in_editions,        
        [NSNumber numberWithInt: in_firstRec],        
        [NSNumber numberWithInt: in_numRecs],        
    };    
    NSString* _paramNames[] = {    
        @"databaseID",        
        @"query",        
        @"depth",        
        @"editions",        
        @"firstRec",        
        @"numRecs",        
    };    
    [super setParameters:6 values: _paramValues names: _paramNames];    
}

- (id) resultValue
{
    return [[super getResultDictionary] objectForKey: @"searchReturn"];    
}

- (WSMethodInvocationRef) genCreateInvocationRef
{
    return [self createInvocationRef    
               /*endpoint*/: BDSKISIEndpoint            
                 methodName: @"search"            
                 protocol: (NSString*) kWSSOAP2001Protocol            
                      style: (NSString*) kWSSOAPStyleRPC            
                 soapAction: @"search"            
            methodNamespace: BDSKISINamespace            
        ];        
}

@end; /* search */


/*-
 *   Method Name:  citingArticles
 * Documentation:  <no documentation>
 */
@implementation BDSKISICitingArticles
- (void) setParameters:(NSString*) in_databaseID in_primaryKey:(NSString*) in_primaryKey in_depth:(NSString*) in_depth in_editions:(NSString*) in_editions in_sort:(NSString*) in_sort in_firstRec:(SInt32) in_firstRec in_numRecs:(SInt32) in_numRecs in_fields:(NSString*) in_fields
{
    id _paramValues[] = {    
        in_databaseID,        
        in_primaryKey,        
        in_depth,        
        in_editions,        
        in_sort,        
        [NSNumber numberWithInt: in_firstRec],        
        [NSNumber numberWithInt: in_numRecs],        
        in_fields,        
    };    
    NSString* _paramNames[] = {    
        @"databaseID",        
        @"primaryKey",        
        @"depth",        
        @"editions",        
        @"sort",        
        @"firstRec",        
        @"numRecs",        
        @"fields",        
    };    
    [super setParameters:8 values: _paramValues names: _paramNames];    
}

- (id) resultValue
{
    return [[super getResultDictionary] objectForKey: @"citingArticlesReturn"];    
}

- (WSMethodInvocationRef) genCreateInvocationRef
{
    return [self createInvocationRef    
               /*endpoint*/: BDSKISIEndpoint            
                 methodName: @"citingArticles"            
                 protocol: (NSString*) kWSSOAP2001Protocol            
                      style: (NSString*) kWSSOAPStyleRPC            
                 soapAction: @"citingArticles"            
            methodNamespace: BDSKISINamespace            
        ];        
}

@end; /* citingArticles */


/*-
 *   Method Name:  retrieveLinks
 * Documentation:  <no documentation>
 */
@implementation BDSKISIRetrieveLinks
- (void) setParameters:(NSString*) in_query in_jsetList:(NSString*) in_jsetList in_include:(NSString*) in_include in_exclude:(NSString*) in_exclude in_options:(NSString*) in_options
{
    id _paramValues[] = {    
        in_query,        
        in_jsetList,        
        in_include,        
        in_exclude,        
        in_options,        
    };    
    NSString* _paramNames[] = {    
        @"query",        
        @"jsetList",        
        @"include",        
        @"exclude",        
        @"options",        
    };    
    [super setParameters:5 values: _paramValues names: _paramNames];    
}

- (id) resultValue
{
    return [[super getResultDictionary] objectForKey: @"retrieveLinksReturn"];    
}

- (WSMethodInvocationRef) genCreateInvocationRef
{
    return [self createInvocationRef    
               /*endpoint*/: BDSKISIEndpoint            
                 methodName: @"retrieveLinks"            
                 protocol: (NSString*) kWSSOAP2001Protocol            
                      style: (NSString*) kWSSOAPStyleRPC            
                 soapAction: @"retrieveLinks"            
            methodNamespace: BDSKISINamespace            
        ];        
}

@end; /* retrieveLinks */


/*-
 *   Method Name:  relatedRecords
 * Documentation:  <no documentation>
 */
@implementation BDSKISIRelatedRecords
- (void) setParameters:(NSString*) in_databaseID in_primaryKey:(NSString*) in_primaryKey in_depth:(NSString*) in_depth in_editions:(NSString*) in_editions in_sort:(NSString*) in_sort in_firstRec:(SInt32) in_firstRec in_numRecs:(SInt32) in_numRecs in_fields:(NSString*) in_fields
{
    id _paramValues[] = {    
        in_databaseID,        
        in_primaryKey,        
        in_depth,        
        in_editions,        
        in_sort,        
        [NSNumber numberWithInt: in_firstRec],        
        [NSNumber numberWithInt: in_numRecs],        
        in_fields,        
    };    
    NSString* _paramNames[] = {    
        @"databaseID",        
        @"primaryKey",        
        @"depth",        
        @"editions",        
        @"sort",        
        @"firstRec",        
        @"numRecs",        
        @"fields",        
    };    
    [super setParameters:8 values: _paramValues names: _paramNames];    
}

- (id) resultValue
{
    return [[super getResultDictionary] objectForKey: @"relatedRecordsReturn"];    
}

- (WSMethodInvocationRef) genCreateInvocationRef
{
    return [self createInvocationRef    
               /*endpoint*/: BDSKISIEndpoint            
                 methodName: @"relatedRecords"            
                 protocol: (NSString*) kWSSOAP2001Protocol            
                      style: (NSString*) kWSSOAPStyleRPC            
                 soapAction: @"relatedRecords"            
            methodNamespace: BDSKISINamespace            
        ];        
}

@end; /* relatedRecords */


/*-
 *   Method Name:  citedReferences
 * Documentation:  <no documentation>
 */
@implementation BDSKISICitedReferences
- (void) setParameters:(NSString*) in_databaseID in_primaryKey:(NSString*) in_primaryKey
{
    id _paramValues[] = {    
        in_databaseID,        
        in_primaryKey,        
    };    
    NSString* _paramNames[] = {    
        @"databaseID",        
        @"primaryKey",        
    };    
    [super setParameters:2 values: _paramValues names: _paramNames];    
}

- (id) resultValue
{
    return [[super getResultDictionary] objectForKey: @"citedReferencesReturn"];    
}

- (WSMethodInvocationRef) genCreateInvocationRef
{
    return [self createInvocationRef    
               /*endpoint*/: BDSKISIEndpoint            
                 methodName: @"citedReferences"            
                 protocol: (NSString*) kWSSOAP2001Protocol            
                      style: (NSString*) kWSSOAPStyleRPC            
                 soapAction: @"citedReferences"            
            methodNamespace: BDSKISINamespace            
        ];        
}

@end; /* citedReferences */



@implementation BDSKISISearchRetrieveService

+ (id) citedReferences:(NSString*) in_databaseID in_primaryKey:(NSString*) in_primaryKey
{
    id result = NULL;    
    BDSKISICitedReferences* _invocation = [[BDSKISICitedReferences alloc] init];    
    [_invocation setParameters: in_databaseID in_primaryKey:in_primaryKey];    
    result = [[_invocation resultValue] retain];    
    [_invocation release];    
    return result;    
}


+ (id) publisherLinks:(NSString*) in_query in_jsetList:(NSString*) in_jsetList
{
    id result = NULL;    
    BDSKISIPublisherLinks* _invocation = [[BDSKISIPublisherLinks alloc] init];    
    [_invocation setParameters: in_query in_jsetList:in_jsetList];    
    result = [[_invocation resultValue] retain];    
    [_invocation release];    
    return result;    
}


+ (id) citingArticlesByRecids:(NSString*) in_databaseID in_recids:(NSString*) in_recids in_depth:(NSString*) in_depth in_editions:(NSString*) in_editions in_sort:(NSString*) in_sort in_firstRec:(SInt32) in_firstRec in_numRecs:(SInt32) in_numRecs in_fields:(NSString*) in_fields
{
    id result = NULL;    
    BDSKISICitingArticlesByRecids* _invocation = [[BDSKISICitingArticlesByRecids alloc] init];    
    [_invocation setParameters: in_databaseID in_recids:in_recids in_depth:in_depth in_editions:in_editions in_sort:in_sort in_firstRec:in_firstRec in_numRecs:in_numRecs in_fields:in_fields];    
    result = [[_invocation resultValue] retain];    
    [_invocation release];    
    return result;    
}


+ (id) retrieveRecid:(NSString*) in_databaseID in_recid:(NSString*) in_recid in_sort:(NSString*) in_sort in_fields:(NSString*) in_fields
{
    id result = NULL;    
    BDSKISIRetrieveRecid* _invocation = [[BDSKISIRetrieveRecid alloc] init];    
    [_invocation setParameters: in_databaseID in_recid:in_recid in_sort:in_sort in_fields:in_fields];    
    result = [[_invocation resultValue] retain];    
    [_invocation release];    
    return result;    
}


+ (id) sharedReferences:(NSString*) in_databaseID in_primaryKeys:(NSString*) in_primaryKeys
{
    id result = NULL;    
    BDSKISISharedReferences* _invocation = [[BDSKISISharedReferences alloc] init];    
    [_invocation setParameters: in_databaseID in_primaryKeys:in_primaryKeys];    
    result = [[_invocation resultValue] retain];    
    [_invocation release];    
    return result;    
}


+ (id) browseDictionary:(NSString*) in_databaseID in_term:(NSString*) in_term in_index:(NSString*) in_index in_linesBefore:(SInt32) in_linesBefore in_linesAfter:(SInt32) in_linesAfter in_pageNumber:(SInt32) in_pageNumber in_depth:(NSString*) in_depth in_editions:(NSString*) in_editions
{
    id result = NULL;    
    BDSKISIBrowseDictionary* _invocation = [[BDSKISIBrowseDictionary alloc] init];    
    [_invocation setParameters: in_databaseID in_term:in_term in_index:in_index in_linesBefore:in_linesBefore in_linesAfter:in_linesAfter in_pageNumber:in_pageNumber in_depth:in_depth in_editions:in_editions];    
    result = [[_invocation resultValue] retain];    
    [_invocation release];    
    return result;    
}


+ (id) mapTerms:(NSString*) in_databaseID in_index:(NSString*) in_index in_terms:(NSString*) in_terms
{
    id result = NULL;    
    BDSKISIMapTerms* _invocation = [[BDSKISIMapTerms alloc] init];    
    [_invocation setParameters: in_databaseID in_index:in_index in_terms:in_terms];    
    result = [[_invocation resultValue] retain];    
    [_invocation release];    
    return result;    
}


+ (id) summary:(NSString*) in_databaseID in_query:(NSString*) in_query in_depth:(NSString*) in_depth in_editions:(NSString*) in_editions in_sort:(NSString*) in_sort in_firstRec:(SInt32) in_firstRec in_numRecs:(SInt32) in_numRecs
{
    id result = NULL;    
    BDSKISISummary* _invocation = [[BDSKISISummary alloc] init];    
    [_invocation setParameters: in_databaseID in_query:in_query in_depth:in_depth in_editions:in_editions in_sort:in_sort in_firstRec:in_firstRec in_numRecs:in_numRecs];    
    result = [[_invocation resultValue] retain];    
    [_invocation release];    
    return result;    
}


+ (id) retrieve:(NSString*) in_databaseID in_primaryKeys:(NSString*) in_primaryKeys in_sort:(NSString*) in_sort in_fields:(NSString*) in_fields
{
    id result = NULL;    
    BDSKISIRetrieve* _invocation = [[BDSKISIRetrieve alloc] init];    
    [_invocation setParameters: in_databaseID in_primaryKeys:in_primaryKeys in_sort:in_sort in_fields:in_fields];    
    result = [[_invocation resultValue] retain];    
    [_invocation release];    
    return result;    
}


+ (id) searchRetrieve:(NSString*) in_databaseID in_query:(NSString*) in_query in_depth:(NSString*) in_depth in_editions:(NSString*) in_editions in_sort:(NSString*) in_sort in_firstRec:(SInt32) in_firstRec in_numRecs:(SInt32) in_numRecs in_fields:(NSString*) in_fields
{
    id result = NULL;    
    BDSKISISearchRetrieve* _invocation = [[BDSKISISearchRetrieve alloc] init];    
    [_invocation setParameters: in_databaseID in_query:in_query in_depth:in_depth in_editions:in_editions in_sort:in_sort in_firstRec:in_firstRec in_numRecs:in_numRecs in_fields:in_fields];    
    result = [[_invocation resultValue] retain];    
    [_invocation release];    
    return result;    
}


+ (id) search:(NSString*) in_databaseID in_query:(NSString*) in_query in_depth:(NSString*) in_depth in_editions:(NSString*) in_editions in_firstRec:(SInt32) in_firstRec in_numRecs:(SInt32) in_numRecs
{
    id result = NULL;    
    BDSKISISearch* _invocation = [[BDSKISISearch alloc] init];    
    [_invocation setParameters: in_databaseID in_query:in_query in_depth:in_depth in_editions:in_editions in_firstRec:in_firstRec in_numRecs:in_numRecs];    
    result = [[_invocation resultValue] retain];    
    [_invocation release];    
    return result;    
}


+ (id) describeDatabase:(NSString*) in_databaseID in_format:(NSString*) in_format
{
    id result = NULL;    
    BDSKISIDescribeDatabase* _invocation = [[BDSKISIDescribeDatabase alloc] init];    
    [_invocation setParameters: in_databaseID in_format:in_format];    
    result = [[_invocation resultValue] retain];    
    [_invocation release];    
    return result;    
}


+ (id) citingArticles:(NSString*) in_databaseID in_primaryKey:(NSString*) in_primaryKey in_depth:(NSString*) in_depth in_editions:(NSString*) in_editions in_sort:(NSString*) in_sort in_firstRec:(SInt32) in_firstRec in_numRecs:(SInt32) in_numRecs in_fields:(NSString*) in_fields
{
    id result = NULL;    
    BDSKISICitingArticles* _invocation = [[BDSKISICitingArticles alloc] init];    
    [_invocation setParameters: in_databaseID in_primaryKey:in_primaryKey in_depth:in_depth in_editions:in_editions in_sort:in_sort in_firstRec:in_firstRec in_numRecs:in_numRecs in_fields:in_fields];    
    result = [[_invocation resultValue] retain];    
    [_invocation release];    
    return result;    
}


+ (id) retrieveLinks:(NSString*) in_query in_jsetList:(NSString*) in_jsetList in_include:(NSString*) in_include in_exclude:(NSString*) in_exclude in_options:(NSString*) in_options
{
    id result = NULL;    
    BDSKISIRetrieveLinks* _invocation = [[BDSKISIRetrieveLinks alloc] init];    
    [_invocation setParameters: in_query in_jsetList:in_jsetList in_include:in_include in_exclude:in_exclude in_options:in_options];    
    result = [[_invocation resultValue] retain];    
    [_invocation release];    
    return result;    
}


+ (id) relatedRecords:(NSString*) in_databaseID in_primaryKey:(NSString*) in_primaryKey in_depth:(NSString*) in_depth in_editions:(NSString*) in_editions in_sort:(NSString*) in_sort in_firstRec:(SInt32) in_firstRec in_numRecs:(SInt32) in_numRecs in_fields:(NSString*) in_fields
{
    id result = NULL;    
    BDSKISIRelatedRecords* _invocation = [[BDSKISIRelatedRecords alloc] init];    
    [_invocation setParameters: in_databaseID in_primaryKey:in_primaryKey in_depth:in_depth in_editions:in_editions in_sort:in_sort in_firstRec:in_firstRec in_numRecs:in_numRecs in_fields:in_fields];    
    result = [[_invocation resultValue] retain];    
    [_invocation release];    
    return result;    
}



@end;


/*-
 * End of WSDL document at
 * http://wok-ws.isiknowledge.com/esti/soap/SearchRetrieve?wsdl
 */

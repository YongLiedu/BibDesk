/*-
 * WSDL stubs for:  http://wok-ws.isiknowledge.com/esti/soap/SearchRetrieve?wsdl
 *   Generated by:  amaxwell
 *           Date:  Tue Jul 10 15:57:13 2007
 *        Emitter:  Objective-C
 */

#ifndef __WSStub__
#define __WSStub__

#import <CoreServices/CoreServices.h>
#import <Foundation/Foundation.h>
#import "WSGeneratedObj.h"

/*-
 *   Web Service:  SearchRetrieveService
 * Documentation:  <not documented>
 */
/*-
 *   Method Name:  describeDatabase
 * Documentation:  <no documentation>
 */

@interface BDSKWSGeneratedObj : WSGeneratedObj
@end

@interface BDSKISIDescribeDatabase : BDSKWSGeneratedObj

// update the parameter list for the invocation.
- (void) setParameters:(NSString*) in_databaseID in_format:(NSString*) in_format;

// result returns an id from the reply dictionary as specified by the WSDL.
- (id) resultValue;

@end; /* describeDatabase */


/*-
 *   Method Name:  publisherLinks
 * Documentation:  <no documentation>
 */

@interface BDSKISIPublisherLinks : BDSKWSGeneratedObj

// update the parameter list for the invocation.
- (void) setParameters:(NSString*) in_query in_jsetList:(NSString*) in_jsetList;

// result returns an id from the reply dictionary as specified by the WSDL.
- (id) resultValue;

@end; /* publisherLinks */


/*-
 *   Method Name:  citingArticlesByRecids
 * Documentation:  <no documentation>
 */

@interface BDSKISICitingArticlesByRecids : BDSKWSGeneratedObj

// update the parameter list for the invocation.
- (void) setParameters:(NSString*) in_databaseID in_recids:(NSString*) in_recids in_depth:(NSString*) in_depth in_editions:(NSString*) in_editions in_sort:(NSString*) in_sort in_firstRec:(SInt32) in_firstRec in_numRecs:(SInt32) in_numRecs in_fields:(NSString*) in_fields;

// result returns an id from the reply dictionary as specified by the WSDL.
- (id) resultValue;

@end; /* citingArticlesByRecids */


/*-
 *   Method Name:  retrieveRecid
 * Documentation:  <no documentation>
 */

@interface BDSKISIRetrieveRecid : BDSKWSGeneratedObj

// update the parameter list for the invocation.
- (void) setParameters:(NSString*) in_databaseID in_recid:(NSString*) in_recid in_sort:(NSString*) in_sort in_fields:(NSString*) in_fields;

// result returns an id from the reply dictionary as specified by the WSDL.
- (id) resultValue;

@end; /* retrieveRecid */


/*-
 *   Method Name:  sharedReferences
 * Documentation:  <no documentation>
 */

@interface BDSKISISharedReferences : BDSKWSGeneratedObj

// update the parameter list for the invocation.
- (void) setParameters:(NSString*) in_databaseID in_primaryKeys:(NSString*) in_primaryKeys;

// result returns an id from the reply dictionary as specified by the WSDL.
- (id) resultValue;

@end; /* sharedReferences */


/*-
 *   Method Name:  browseDictionary
 * Documentation:  <no documentation>
 */

@interface BDSKISIBrowseDictionary : BDSKWSGeneratedObj

// update the parameter list for the invocation.
- (void) setParameters:(NSString*) in_databaseID in_term:(NSString*) in_term in_index:(NSString*) in_index in_linesBefore:(SInt32) in_linesBefore in_linesAfter:(SInt32) in_linesAfter in_pageNumber:(SInt32) in_pageNumber in_depth:(NSString*) in_depth in_editions:(NSString*) in_editions;

// result returns an id from the reply dictionary as specified by the WSDL.
- (id) resultValue;

@end; /* browseDictionary */


/*-
 *   Method Name:  mapTerms
 * Documentation:  <no documentation>
 */

@interface BDSKISIMapTerms : BDSKWSGeneratedObj

// update the parameter list for the invocation.
- (void) setParameters:(NSString*) in_databaseID in_index:(NSString*) in_index in_terms:(NSString*) in_terms;

// result returns an id from the reply dictionary as specified by the WSDL.
- (id) resultValue;

@end; /* mapTerms */


/*-
 *   Method Name:  summary
 * Documentation:  <no documentation>
 */

@interface BDSKISISummary : BDSKWSGeneratedObj

// update the parameter list for the invocation.
- (void) setParameters:(NSString*) in_databaseID in_query:(NSString*) in_query in_depth:(NSString*) in_depth in_editions:(NSString*) in_editions in_sort:(NSString*) in_sort in_firstRec:(SInt32) in_firstRec in_numRecs:(SInt32) in_numRecs;

// result returns an id from the reply dictionary as specified by the WSDL.
- (id) resultValue;

@end; /* summary */


/*-
 *   Method Name:  retrieve
 * Documentation:  <no documentation>
 */

@interface BDSKISIRetrieve : BDSKWSGeneratedObj

// update the parameter list for the invocation.
- (void) setParameters:(NSString*) in_databaseID in_primaryKeys:(NSString*) in_primaryKeys in_sort:(NSString*) in_sort in_fields:(NSString*) in_fields;

// result returns an id from the reply dictionary as specified by the WSDL.
- (id) resultValue;

@end; /* retrieve */


/*-
 *   Method Name:  searchRetrieve
 * Documentation:  <no documentation>
 */

@interface BDSKISISearchRetrieve : BDSKWSGeneratedObj

// update the parameter list for the invocation.
- (void) setParameters:(NSString*) in_databaseID in_query:(NSString*) in_query in_depth:(NSString*) in_depth in_editions:(NSString*) in_editions in_sort:(NSString*) in_sort in_firstRec:(SInt32) in_firstRec in_numRecs:(SInt32) in_numRecs in_fields:(NSString*) in_fields;

// result returns an id from the reply dictionary as specified by the WSDL.
- (id) resultValue;

@end; /* searchRetrieve */


/*-
 *   Method Name:  search
 * Documentation:  <no documentation>
 */

@interface BDSKISISearch : BDSKWSGeneratedObj

// update the parameter list for the invocation.
- (void) setParameters:(NSString*) in_databaseID in_query:(NSString*) in_query in_depth:(NSString*) in_depth in_editions:(NSString*) in_editions in_firstRec:(SInt32) in_firstRec in_numRecs:(SInt32) in_numRecs;

// result returns an id from the reply dictionary as specified by the WSDL.
- (id) resultValue;

@end; /* search */


/*-
 *   Method Name:  citingArticles
 * Documentation:  <no documentation>
 */

@interface BDSKISICitingArticles : BDSKWSGeneratedObj

// update the parameter list for the invocation.
- (void) setParameters:(NSString*) in_databaseID in_primaryKey:(NSString*) in_primaryKey in_depth:(NSString*) in_depth in_editions:(NSString*) in_editions in_sort:(NSString*) in_sort in_firstRec:(SInt32) in_firstRec in_numRecs:(SInt32) in_numRecs in_fields:(NSString*) in_fields;

// result returns an id from the reply dictionary as specified by the WSDL.
- (id) resultValue;

@end; /* citingArticles */


/*-
 *   Method Name:  retrieveLinks
 * Documentation:  <no documentation>
 */

@interface BDSKISIRetrieveLinks : BDSKWSGeneratedObj

// update the parameter list for the invocation.
- (void) setParameters:(NSString*) in_query in_jsetList:(NSString*) in_jsetList in_include:(NSString*) in_include in_exclude:(NSString*) in_exclude in_options:(NSString*) in_options;

// result returns an id from the reply dictionary as specified by the WSDL.
- (id) resultValue;

@end; /* retrieveLinks */


/*-
 *   Method Name:  relatedRecords
 * Documentation:  <no documentation>
 */

@interface BDSKISIRelatedRecords : BDSKWSGeneratedObj

// update the parameter list for the invocation.
- (void) setParameters:(NSString*) in_databaseID in_primaryKey:(NSString*) in_primaryKey in_depth:(NSString*) in_depth in_editions:(NSString*) in_editions in_sort:(NSString*) in_sort in_firstRec:(SInt32) in_firstRec in_numRecs:(SInt32) in_numRecs in_fields:(NSString*) in_fields;

// result returns an id from the reply dictionary as specified by the WSDL.
- (id) resultValue;

@end; /* relatedRecords */


/*-
 *   Method Name:  citedReferences
 * Documentation:  <no documentation>
 */

@interface BDSKISICitedReferences : BDSKWSGeneratedObj

// update the parameter list for the invocation.
- (void) setParameters:(NSString*) in_databaseID in_primaryKey:(NSString*) in_primaryKey;

// result returns an id from the reply dictionary as specified by the WSDL.
- (id) resultValue;

@end; /* citedReferences */


/*-
 * Web Service:  SearchRetrieveService
 */
@interface BDSKISISearchRetrieveService : NSObject 

+ (id) citedReferences:(NSString*) in_databaseID in_primaryKey:(NSString*) in_primaryKey;
+ (id) publisherLinks:(NSString*) in_query in_jsetList:(NSString*) in_jsetList;
+ (id) citingArticlesByRecids:(NSString*) in_databaseID in_recids:(NSString*) in_recids in_depth:(NSString*) in_depth in_editions:(NSString*) in_editions in_sort:(NSString*) in_sort in_firstRec:(SInt32) in_firstRec in_numRecs:(SInt32) in_numRecs in_fields:(NSString*) in_fields;
+ (id) retrieveRecid:(NSString*) in_databaseID in_recid:(NSString*) in_recid in_sort:(NSString*) in_sort in_fields:(NSString*) in_fields;
+ (id) sharedReferences:(NSString*) in_databaseID in_primaryKeys:(NSString*) in_primaryKeys;
+ (id) browseDictionary:(NSString*) in_databaseID in_term:(NSString*) in_term in_index:(NSString*) in_index in_linesBefore:(SInt32) in_linesBefore in_linesAfter:(SInt32) in_linesAfter in_pageNumber:(SInt32) in_pageNumber in_depth:(NSString*) in_depth in_editions:(NSString*) in_editions;
+ (id) mapTerms:(NSString*) in_databaseID in_index:(NSString*) in_index in_terms:(NSString*) in_terms;
+ (id) summary:(NSString*) in_databaseID in_query:(NSString*) in_query in_depth:(NSString*) in_depth in_editions:(NSString*) in_editions in_sort:(NSString*) in_sort in_firstRec:(SInt32) in_firstRec in_numRecs:(SInt32) in_numRecs;
+ (id) retrieve:(NSString*) in_databaseID in_primaryKeys:(NSString*) in_primaryKeys in_sort:(NSString*) in_sort in_fields:(NSString*) in_fields;
+ (id) searchRetrieve:(NSString*) in_databaseID in_query:(NSString*) in_query in_depth:(NSString*) in_depth in_editions:(NSString*) in_editions in_sort:(NSString*) in_sort in_firstRec:(SInt32) in_firstRec in_numRecs:(SInt32) in_numRecs in_fields:(NSString*) in_fields;
+ (id) search:(NSString*) in_databaseID in_query:(NSString*) in_query in_depth:(NSString*) in_depth in_editions:(NSString*) in_editions in_firstRec:(SInt32) in_firstRec in_numRecs:(SInt32) in_numRecs;
+ (id) describeDatabase:(NSString*) in_databaseID in_format:(NSString*) in_format;
+ (id) citingArticles:(NSString*) in_databaseID in_primaryKey:(NSString*) in_primaryKey in_depth:(NSString*) in_depth in_editions:(NSString*) in_editions in_sort:(NSString*) in_sort in_firstRec:(SInt32) in_firstRec in_numRecs:(SInt32) in_numRecs in_fields:(NSString*) in_fields;
+ (id) retrieveLinks:(NSString*) in_query in_jsetList:(NSString*) in_jsetList in_include:(NSString*) in_include in_exclude:(NSString*) in_exclude in_options:(NSString*) in_options;
+ (id) relatedRecords:(NSString*) in_databaseID in_primaryKey:(NSString*) in_primaryKey in_depth:(NSString*) in_depth in_editions:(NSString*) in_editions in_sort:(NSString*) in_sort in_firstRec:(SInt32) in_firstRec in_numRecs:(SInt32) in_numRecs in_fields:(NSString*) in_fields;

@end;


#endif /* __WSStub__ */
/*-
 * End of WSDL document at
 * http://wok-ws.isiknowledge.com/esti/soap/SearchRetrieve?wsdl
 */

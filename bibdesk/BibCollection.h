//
//  BibCollection.h
//  Bibdesk
//
//  Created by Michael McCracken on 1/5/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

/*!
    @header BibCollection
    @abstract   (description)
    @discussion (description)
*/

/*!
    @class BibCollection
    @abstract   (description)
    @discussion (description)
*/

@interface BibCollection : NSObject {
    NSString *name;
    NSMutableArray *publications;
    NSMutableArray *subCollections;
}

- (void)encodeWithCoder:(NSCoder *)aCoder;
- (id)initWithCoder:(NSCoder *)aDecoder;

/*!
@method name
@abstract the getter corresponding to setName
@result returns value for name
*/
- (NSString *)name;

/*!
@method setName
@abstract sets name to the param
@discussion 
@param newName 
*/
- (void)setName:(NSString *)newName;


/*!
@method publications
@abstract the getter corresponding to setPublications
@result returns value for publications
*/
- (NSMutableArray *)publications;

/*!
@method setPublications
@abstract sets publications to the param
@discussion 
@param newPublications 
*/
- (void)setPublications:(NSMutableArray *)newPublications;



/*!
@method count
@abstract returns the count of the collection's children.
 @discussion This is a courtesy method, it has a somewhat 
 awkward name (it's not really an NSArray) because it makes code elsewhere simpler.
@result returns number of subCollections
*/
- (unsigned)count;

/*!
@method subCollections
@abstract the getter corresponding to setSubCollections
@result returns value for subCollections
*/
- (NSMutableArray *)subCollections;

/*!
@method setSubCollections
@abstract sets subCollections to the param
@discussion 
@param newSubCollections 
*/
- (void)setSubCollections:(NSMutableArray *)newSubCollections;



@end

//
//  BDSKRemoteSource.h
//  Bibdesk
//
//  Created by Michael McCracken on 2/11/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

/*!
    @class BDSKRemoteSource
    @abstract   A superclass for sources.
    @discussion (description)
*/
// should this become a subclass of bibcollection?
@interface BDSKRemoteSource : NSObject{
	NSString *name;
	NSMutableDictionary *data;
}

/*!
* @method name
 * @abstract the getter corresponding to setName
 * @result returns value for name
 */
- (NSString *)name;
	/*!
	* @method setName
	 * @abstract sets name to the param
	 * @discussion 
	 * @param aName 
	 */
- (void)setName:(NSString *)aName;


	/*!
	* @method data
	 * @abstract the getter corresponding to setData
	 * @result returns value for data
	 */
- (NSMutableDictionary *)data;
	/*!
	* @method setData
	 * @abstract sets data to the param
	 * @discussion 
	 * @param aData 
	 */
- (void)setData:(NSMutableDictionary *)aData;


    /*!
    @method     settingsView
     @abstract   returns a view that contains controls for setting up the source
     @discussion (description)
     @result     (description)
     */
- (NSView *)settingsView;

- (NSArray *)items;
- (void)refresh;

@end

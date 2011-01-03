//
//  BDSKGroup.h
//  Bibdesk
//
//  Created by Christiaan Hofman on 8/11/05.
/*
 This software is Copyright (c) 2005-2011
 Christiaan Hofman. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Christiaan Hofman nor the names of any
    contributors may be used to endorse or promote products derived
    from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Cocoa/Cocoa.h>

@class BibItem, BibDocument, BDSKMacroResolver, BDSKParentGroup;

// NSCoding is used only to save the group selection of non-external groups
// NSCoding support is presently limited, in particular it is not supported for external groups

@interface BDSKGroup : NSObject <NSCopying, NSCoding> {
	id name;
	NSInteger count;
    BDSKParentGroup *parent;
    BibDocument *document;
    NSString *uniqueID;
}

/*!
	@method initWithName:
	@abstract Initializes and returns a new group instance with a name and count. 
	@discussion This is the designated initializer. 
	@param aName The name for the group.
*/
- (id)initWithName:(id)aName;

- (id)initWithDictionary:(NSDictionary *)groupDict;
- (NSDictionary *)dictionaryValue;

- (NSString *)uniqueID;

/*!
	@method name
	@abstract Returns the name of the group.
	@discussion -
*/
- (id)name;

- (NSString *)label;

/*!
	@method count
	@abstract Returns the count of the group.
	@discussion -
*/
- (NSInteger)count;

/*!
	@method setCount:
	@abstract Sets the count for the group.
	@discussion -
	@param newCount The new count to set.
*/
- (void)setCount:(NSInteger)newCount;

/*!
	@method count
	@abstract Returns the icon for the group.
	@discussion -
*/
- (NSImage *)icon;

/*!
	@method isParent
	@abstract Boolean, returns whether the receiver is a parent group. 
	@discussion -
*/
- (BOOL)isParent;

/*!
	@method isStatic
	@abstract Boolean, returns whether the receiver is a static group. 
	@discussion -
*/
- (BOOL)isStatic;

/*!
	@method isSmart
	@abstract Boolean, returns whether the receiver is a smart group. 
	@discussion -
*/
- (BOOL)isSmart;

/*!
	@method isCategory
	@abstract Boolean, returns whether the receiver is a category group. 
	@discussion -
*/
- (BOOL)isCategory;

/*!
	@method isShared
	@abstract Boolean, returns whether the receiver is a shared group. 
	@discussion -
*/
- (BOOL)isShared;

/*!
	@method isURL
	@abstract Boolean, returns whether the receiver is a URL group. 
	@discussion -
*/
- (BOOL)isURL;

/*!
	@method isScript
	@abstract Boolean, returns whether the receiver is a script group. 
	@discussion -
*/
- (BOOL)isScript;

/*!
	@method isSearch
	@abstract Boolean, returns whether the receiver is a search group. 
	@discussion -
*/
- (BOOL)isSearch;

/*!
	@method isWeb
	@abstract Boolean, returns whether the receiver is a web group. 
	@discussion -
*/
- (BOOL)isWeb;

/*!
	@method isExternal
	@abstract Boolean, returns whether the receiver is an external source group (shared, URL or script). 
	@discussion -
*/
- (BOOL)isExternal;

/*!
    @method     isNameEditable
    @abstract   Returns NO by default.  Editable subclasses should override this to allow changing the name of a group.
*/
- (BOOL)isNameEditable;

/*!
    @method     isEditable
    @abstract   Returns NO by default.  Editable subclasses should override this to allow editing of its properties.
*/
- (BOOL)isEditable;

/*!
    @method     failedDownload
    @abstract   Method for remote groups.  Returns NO by default.
*/
- (BOOL)failedDownload;

/*!
    @method     isRetrieving
    @abstract   Method for remote groups.  Returns NO by default.
*/
- (BOOL)isRetrieving;

/*!
    @method     isValidDropTarget
    @abstract   Some subclasses (e.g. BDSKSharedGroup) are never valid drop targets, while others are generally valid.  Returns NO by default.
    @discussion (comprehensive description)
    @result     (description)
*/
- (BOOL)isValidDropTarget;

/*!
	@method stringValue
	@abstract Returns string value of the name.
	@discussion -
*/
- (NSString *)stringValue;

/*!
	@method numberValue
	@abstract Returns count as an NSNumber.
	@discussion -
*/
- (NSNumber *)numberValue;

- (NSString *)editingStringValue;

- (id)cellValue;

- (NSString *)toolTip;

- (NSString *)errorMessage;

- (BDSKParentGroup *)parent;
- (void)setParent:(BDSKParentGroup *)newParent;

- (BibDocument *)document;
- (void)setDocument:(BibDocument *)newDocument;

- (BDSKMacroResolver *)macroResolver;

/*!
	@method nameCompare:
	@abstract Compares the string value of the receiver and the otherGroup. 
	@discussion -
	@param otherGroup The group object to compare the receiver with.
*/
- (NSComparisonResult)nameCompare:(BDSKGroup *)otherGroup;

/*!
	@method nameCompare:
	@abstract Compares the number value of the receiver and the otherGroup. 
	@discussion -
	@param otherGroup The group object to compare the receiver with.
*/
- (NSComparisonResult)countCompare:(BDSKGroup *)otherGroup;

/*!
	@method containsItem:
	@abstract Returns a boolean indicating whether the item is contained in the group.
	@discussion -
	@param item A BibItem to test for containment.
*/
- (BOOL)containsItem:(BibItem *)item;

@end


@protocol BDSKMutableGroup <NSObject>

- (void)setName:(id)newName;
- (NSUndoManager *)undoManager;

@end


@interface BDSKMutableGroup : BDSKGroup <BDSKMutableGroup>
@end

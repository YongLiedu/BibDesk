//
//  BibTypeManager.h
//  Bibdesk
//
//  Created by Michael McCracken on Thu Nov 28 2002.
//  Copyright (c) 2002 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BibPrefController.h"

@interface BibTypeManager : NSObject {
    NSDictionary *typeInfoDict;
	NSCharacterSet *invalidCiteKeyCharSet;
}
+ (BibTypeManager *)sharedManager;
- (NSString *)defaultTypeForFileFormat:(NSString *)fileFormat;
- (NSArray *)allRemovableFieldNames;
- (NSArray *)requiredFieldsForType:(NSString *)type;
- (NSArray *)optionalFieldsForType:(NSString *)type;
- (NSArray *)userDefaultFieldsForType:(NSString *)type;
- (NSArray *)bibTypesForFileType:(NSString *)fileType;
- (NSString *)fieldNameForPubMedTag:(NSString *)tag;
- (NSString *)bibtexTypeForPubMedType:(NSString *)type;
/*!
    @method     invalidCharactersForField:inType:
    @abstract   Characters that must not be used in a given key and reference type, currently only for BibTeX.  This is a fairly liberal definition, since it allows
                non-ascii and some math characters.  Used by the formatter subclass for field entry in BibEditor.
    @discussion (comprehensive description)
    @param      fieldName The name of the field (e.g. "Author")
    @param      type The reference type (e.g. BibTeX, RIS)
    @result     A character set of invalid entries.
*/
- (NSCharacterSet *)invalidCharactersForField:(NSString *)fieldName inType:(NSString *)type;
@end

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
    NSDictionary *_typeInfoDict;
	NSCharacterSet *_invalidCiteKeyCharSet;
        NSCharacterSet *_sanitizedCiteKeyCharSet;
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
/*!
    @method     sanitizedCiteKeyCharSet
    @abstract   This is a large character set; it basically excludes anything but ASCII letters and numbers, with :; and -.
    @discussion Based on my (ARM) interpretation of "The LaTeX Companion, 2nd Ed." p. 842, which states that the limitations
                which apply to citekey names are the same as those which apply to command names.  Since most users
                won't have any problem with this unless they ask TeX to typeset their citekeys, we only apply this
                restriction to citekeys generated from within BibDesk.
    @result     A character set of characters which are not recommended for use in BibTeX citekeys.
*/
- (NSCharacterSet *)sanitizedCiteKeyCharSet;
@end

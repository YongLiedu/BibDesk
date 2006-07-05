//
//  BibTypeManager.m
//  BibDesk
//
//  Created by Michael McCracken on Thu Nov 28 2002.
/*
 This software is Copyright (c) 2002,2003,2004,2005,2006
 Michael O. McCracken. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Michael O. McCracken nor the names of any
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

#import "BibTypeManager.h"
#import "BibAppController.h"
#import "NSFileManager_BDSKExtensions.h"

static BibTypeManager *sharedInstance = nil;

@implementation BibTypeManager
+ (BibTypeManager *)sharedManager{
    @synchronized(sharedInstance){
        if(sharedInstance == nil) 
            sharedInstance = [[BibTypeManager alloc] init];
    }
    return sharedInstance;
}

- (id)init{
    self = [super init];
    
    if(!self)
        return nil;
	
	[self reloadTypeInfo];
	
    // this set is used for warning the user on manual entry of a citekey; allows non-ASCII characters and some math symbols
    invalidCiteKeyCharSet = [[NSCharacterSet characterSetWithCharactersInString:@" '\"@,\\#}{~%"] retain];
    
	fragileCiteKeyCharSet = [[NSCharacterSet characterSetWithCharactersInString:@"&$^"] retain];
    
    NSMutableCharacterSet *tmpSet = [[NSCharacterSet characterSetWithRange:NSMakeRange( (unsigned int)'a', 26)] mutableCopy];
    [tmpSet addCharactersInRange:NSMakeRange( (unsigned int)'A', 26)];
    [tmpSet addCharactersInRange:NSMakeRange( (unsigned int)'-', 15)];  //  -./0123456789:;
    
    // this is used for generated cite keys, very strict!
	strictInvalidCiteKeyCharSet = [[tmpSet invertedSet] copy];  // don't release this
    [tmpSet release];

	// this set is used for warning the user on manual entry of a local-url; allows non-ASCII characters and some math symbols
    invalidLocalUrlCharSet = [[NSCharacterSet characterSetWithCharactersInString:@":"] retain];
    
	// this is used for generated local urls
	strictInvalidLocalUrlCharSet = [invalidLocalUrlCharSet copy];  // don't release this

	
	tmpSet = [[NSCharacterSet characterSetWithRange:NSMakeRange(1,31)] mutableCopy];
	[tmpSet addCharactersInString:@"/?<>\\:*|\""];
	
	// this is used for generated local urls, stricted for use of windoze-compatible file names
    veryStrictInvalidLocalUrlCharSet = [tmpSet copy];
    [tmpSet release];
    
	// see the URI specifications for the valid characters
	NSMutableCharacterSet *validSet = [[NSCharacterSet characterSetWithRange:NSMakeRange( (unsigned int)'a', 26)] mutableCopy];
    [validSet addCharactersInRange:NSMakeRange( (unsigned int)'A', 26)];
    [validSet addCharactersInString:@"-._~:/?#[]@!$&'()*+,;="];
	
	// this set is used for warning the user on manual entry of a remote url
    invalidRemoteUrlCharSet = [[validSet invertedSet] copy];
    [validSet release];
    
	// this is used for generated remote urls
	strictInvalidRemoteUrlCharSet = [invalidRemoteUrlCharSet copy];  // don't release this
	
	invalidGeneralCharSet = [[NSCharacterSet alloc] init];
	
	strictInvalidGeneralCharSet = [[NSCharacterSet alloc] init];
    
    localURLFieldsSet = [[NSMutableSet alloc] initWithCapacity:5];
    remoteURLFieldsSet = [[NSMutableSet alloc] initWithCapacity:5];
    allURLFieldsSet = [[NSMutableSet alloc] initWithCapacity:10];
    [self reloadURLFields];
    
    ratingFieldsSet = [[NSMutableSet alloc] initWithCapacity:5];
    triStateFieldsSet = [[NSMutableSet alloc] initWithCapacity:5];
    booleanFieldsSet = [[NSMutableSet alloc] initWithCapacity:5];
    [self reloadSpecialFields];
    
    singleValuedGroupFields = [[NSMutableSet alloc] initWithCapacity:10];
    invalidGroupFields = [[NSMutableSet alloc] initWithCapacity:10];
    [self reloadGroupFields];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(customFieldsDidChange:)
												 name:BDSKCustomFieldsChangedNotification
											   object:nil];
    
	return self;
}

- (void)dealloc{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[fileTypesDict release];
	[fieldsForTypesDict release];
	[typesForFileTypeDict release];
	[fieldNameForPubMedTagDict release];
	[bibtexTypeForPubMedTypeDict release];
    [fieldNameForJSTORTagDict release];
    [fieldDescriptionForJSTORTagDict release];
    [fieldNameForWebOfScienceTagDict release];
    [fieldDescriptionForWebOfScienceTagDict release];
    [bibtexTypeForWebOfScienceTypeDict release];
	[MODSGenresForBibTeXTypeDict release];
	[allFieldNames release];
	[invalidCiteKeyCharSet release];
	[strictInvalidCiteKeyCharSet release];
	[invalidLocalUrlCharSet release];
	[strictInvalidLocalUrlCharSet release];
	[invalidRemoteUrlCharSet release];
	[strictInvalidRemoteUrlCharSet release];
	[invalidGeneralCharSet release];
	[strictInvalidGeneralCharSet release];
    [localURLFieldsSet release];
    [remoteURLFieldsSet release];
    [allURLFieldsSet release];
    [ratingFieldsSet release];
    [triStateFieldsSet release];
    [booleanFieldsSet release];
    [singleValuedGroupFields release];
    [invalidGroupFields release];
	[super dealloc];
}

- (void)reloadTypeInfo{
	@synchronized(self){
        // Load the TypeInfo plists
        NSDictionary *typeInfoDict = [NSDictionary dictionaryWithContentsOfFile:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:TYPE_INFO_FILENAME]];

        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *userTypeInfoPath = [[fm currentApplicationSupportPathForCurrentUser] stringByAppendingPathComponent:TYPE_INFO_FILENAME];
        NSDictionary *userTypeInfoDict;
        
        if ([fm fileExistsAtPath:userTypeInfoPath]) {
            userTypeInfoDict = [NSDictionary dictionaryWithContentsOfFile:userTypeInfoPath];
            // set all the lists we support in the user file
            [self setFieldsForTypesDict:[userTypeInfoDict objectForKey:FIELDS_FOR_TYPES_KEY]];
            [self setTypesForFileTypeDict:[NSDictionary dictionaryWithObjectsAndKeys: 
                [[userTypeInfoDict objectForKey:TYPES_FOR_FILE_TYPE_KEY] objectForKey:BDSKBibtexString], BDSKBibtexString, 
                [[typeInfoDict objectForKey:TYPES_FOR_FILE_TYPE_KEY] objectForKey:@"PubMed"], @"PubMed", nil]];
        } else {
            [self setFieldsForTypesDict:[typeInfoDict objectForKey:FIELDS_FOR_TYPES_KEY]];
            [self setTypesForFileTypeDict:[typeInfoDict objectForKey:TYPES_FOR_FILE_TYPE_KEY]];
        }

        [self setFileTypesDict:[typeInfoDict objectForKey:FILE_TYPES_KEY]];
        [self setFieldNameForPubMedTagDict:[typeInfoDict objectForKey:BIBTEX_FIELDS_FOR_PUBMED_TAGS_KEY]];
        [self setBibtexTypeForPubMedTypeDict:[typeInfoDict objectForKey:BIBTEX_TYPES_FOR_PUBMED_TYPES_KEY]];
        [self setMODSGenresForBibTeXTypeDict:[typeInfoDict objectForKey:MODS_GENRES_FOR_BIBTEX_TYPES_KEY]];
        [self setFieldNameForJSTORTagDict:[typeInfoDict objectForKey:BIBTEX_FIELDS_FOR_JSTOR_TAGS_KEY]];
        [self setFieldDescriptionForJSTORTagDict:[typeInfoDict objectForKey:FIELD_DESCRIPTIONS_FOR_JSTOR_TAGS_KEY]];
        [self setFieldNameForWebOfScienceTagDict:[typeInfoDict objectForKey:BIBTEX_FIELDS_FOR_WOS_TAGS_KEY]];
        [self setFieldDescriptionForWebOfScienceTagDict:[typeInfoDict objectForKey:FIELD_DESCRIPTIONS_FOR_WOS_TAGS_KEY]];
        [self setBibtexTypeForWebOfScienceTypeDict:[typeInfoDict objectForKey:BIBTEX_TYPES_FOR_WOS_TYPES_KEY]];
    }
	
	[self reloadAllFieldNames];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKBibTypeInfoChangedNotification
														object:self
													  userInfo:[NSDictionary dictionary]];
}

- (void)reloadAllFieldNames {
    @synchronized(self){
        NSMutableSet *allFields = [NSMutableSet setWithCapacity:30];
        NSEnumerator *typeEnum = [[self bibTypesForFileType:BDSKBibtexString] objectEnumerator];
        NSString *type;
        
        while (type = [typeEnum nextObject]) {
            [allFields addObjectsFromArray:[[fieldsForTypesDict objectForKey:type] objectForKey:REQUIRED_KEY]];
            [allFields addObjectsFromArray:[[fieldsForTypesDict objectForKey:type] objectForKey:OPTIONAL_KEY]];
        }
        OFPreferenceWrapper *pw = [OFPreferenceWrapper sharedPreferenceWrapper];
        [allFields addObjectsFromArray:[pw stringArrayForKey:BDSKDefaultFieldsKey]];
        [allFields addObjectsFromArray:[pw stringArrayForKey:BDSKLocalFileFieldsKey]];
        [allFields addObjectsFromArray:[pw stringArrayForKey:BDSKRemoteURLFieldsKey]];
        [allFields addObjectsFromArray:[pw stringArrayForKey:BDSKBooleanFieldsKey]];
        [allFields addObjectsFromArray:[pw stringArrayForKey:BDSKRatingFieldsKey]];
        [allFields addObjectsFromArray:[pw stringArrayForKey:BDSKTriStateFieldsKey]];
        
        [self setAllFieldNames:allFields];
    }
    
}

- (void)reloadURLFields {
    @synchronized(self){
        [localURLFieldsSet removeAllObjects];
        [remoteURLFieldsSet removeAllObjects];
        [allURLFieldsSet removeAllObjects];
        
        [localURLFieldsSet addObjectsFromArray:[[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKLocalFileFieldsKey]];
        [remoteURLFieldsSet addObjectsFromArray:[[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKRemoteURLFieldsKey]];
        [allURLFieldsSet unionSet:remoteURLFieldsSet];
        [allURLFieldsSet unionSet:localURLFieldsSet];
    }
}

- (void)reloadSpecialFields{
    @synchronized(self){
        [ratingFieldsSet removeAllObjects];
        [triStateFieldsSet removeAllObjects];
        [booleanFieldsSet removeAllObjects];
        
        [ratingFieldsSet addObjectsFromArray:[[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKRatingFieldsKey]];
        [triStateFieldsSet addObjectsFromArray:[[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKTriStateFieldsKey]];
        [booleanFieldsSet addObjectsFromArray:[[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKBooleanFieldsKey]];    
    }
}

- (void)reloadGroupFields{
    [invalidGroupFields removeAllObjects];
    
    OFPreferenceWrapper *pw = [OFPreferenceWrapper sharedPreferenceWrapper];
	NSMutableSet *invalidFields = [NSMutableSet setWithObjects:
		BDSKDateModifiedString, BDSKDateAddedString, BDSKDateString, 
		BDSKTitleString, BDSKBooktitleString, BDSKVolumetitleString, BDSKContainerString, BDSKChapterString, 
		BDSKVolumeString, BDSKNumberString, BDSKSeriesString, BDSKPagesString, BDSKItemNumberString, 
		BDSKAbstractString, BDSKAnnoteString, BDSKRssDescriptionString, nil];
	[invalidFields addObjectsFromArray:[pw stringArrayForKey:BDSKLocalFileFieldsKey]];
	[invalidFields addObjectsFromArray:[pw stringArrayForKey:BDSKRemoteURLFieldsKey]];
    [invalidGroupFields unionSet:invalidFields];
    
    [singleValuedGroupFields removeAllObjects];
    NSMutableSet *singleValuedFields = [NSMutableSet setWithObjects:BDSKPubTypeString, BDSKTypeString, BDSKCrossrefString, BDSKJournalString, BDSKYearString, BDSKMonthString, BDSKPublisherString, BDSKAddressString, nil];
	[singleValuedFields addObjectsFromArray:[pw stringArrayForKey:BDSKRatingFieldsKey]];
	[singleValuedFields addObjectsFromArray:[pw stringArrayForKey:BDSKBooleanFieldsKey]];
	[singleValuedFields addObjectsFromArray:[pw stringArrayForKey:BDSKTriStateFieldsKey]];  
    [singleValuedGroupFields unionSet:singleValuedFields];
}

- (void)customFieldsDidChange:(NSNotification *)notification {
	[self reloadAllFieldNames];
    [self reloadURLFields];
    [self reloadSpecialFields];
    [self reloadGroupFields];
}

#pragma mark Setters

- (void)setAllFieldNames:(NSSet *)newNames{
    if(allFieldNames != newNames){
        [allFieldNames release];
        allFieldNames = [newNames copy];
    }
}

- (void)setMODSGenresForBibTeXTypeDict:(NSDictionary *)newNames{
    if(MODSGenresForBibTeXTypeDict != newNames){
        [MODSGenresForBibTeXTypeDict release];
        MODSGenresForBibTeXTypeDict = [newNames copy];
    }
}

- (void)setBibtexTypeForPubMedTypeDict:(NSDictionary *)newNames{
    if(bibtexTypeForPubMedTypeDict != newNames){
        [bibtexTypeForPubMedTypeDict release];
        bibtexTypeForPubMedTypeDict = [newNames copy];
    }
}

- (void)setBibtexTypeForWebOfScienceTypeDict:(NSDictionary *)dict{
    if(bibtexTypeForWebOfScienceTypeDict != dict){
        [bibtexTypeForWebOfScienceTypeDict release];
        bibtexTypeForWebOfScienceTypeDict = [dict copy];
    }
}

- (void)setFieldNameForPubMedTagDict:(NSDictionary *)newNames{
    if(fieldNameForPubMedTagDict != newNames){
        [fieldNameForPubMedTagDict release];
        fieldNameForPubMedTagDict = [newNames copy];
    }
}

- (void)setFieldDescriptionForJSTORTagDict:(NSDictionary *)dict{
    if(fieldDescriptionForJSTORTagDict != dict){
        [fieldDescriptionForJSTORTagDict release];
        fieldDescriptionForJSTORTagDict = [dict copy];
    }
}

- (void)setFieldNameForJSTORTagDict:(NSDictionary *)dict{
    if(fieldNameForJSTORTagDict != dict){
        [fieldNameForJSTORTagDict release];
        fieldNameForJSTORTagDict = [dict copy];
    }
}

- (void)setFieldNameForWebOfScienceTagDict:(NSDictionary *)dict{
    if(fieldNameForWebOfScienceTagDict != dict){
        [fieldNameForWebOfScienceTagDict release];
        fieldNameForWebOfScienceTagDict = [dict copy];
    }
}

- (void)setFieldDescriptionForWebOfScienceTagDict:(NSDictionary *)dict{
    if(fieldDescriptionForWebOfScienceTagDict != dict){
        [fieldDescriptionForWebOfScienceTagDict release];
        fieldDescriptionForWebOfScienceTagDict = [dict copy];
    }
}

- (void)setFileTypesDict:(NSDictionary *)newTypes{
    if(fileTypesDict != newTypes){
        [fileTypesDict release];
        fileTypesDict = [newTypes copy];
    }
}

- (void)setFieldsForTypesDict:(NSDictionary *)newFields{
    if(fieldsForTypesDict != newFields){
        [fieldsForTypesDict release];
        fieldsForTypesDict = [newFields copy];
    }
}

- (void)setTypesForFileTypeDict:(NSDictionary *)newTypes{
    if(typesForFileTypeDict != newTypes){
        [typesForFileTypeDict release];
        typesForFileTypeDict = [newTypes copy];
    }
}

#pragma mark Getters

- (NSString *)defaultTypeForFileFormat:(NSString *)fileFormat{
     return [[fileTypesDict objectForKey:fileFormat] objectForKey:@"DefaultType"];
}

- (NSSet *)allFieldNames{
    return allFieldNames;
}

- (NSArray *)allFieldNamesIncluding:(NSArray *)include excluding:(NSArray *)exclude{
    NSMutableArray *fieldNames = [[allFieldNames allObjects] mutableCopy];
    if ([include count])
        [fieldNames addObjectsFromArray:include];
    if([exclude count])
        [fieldNames removeObjectsInArray:exclude];
    [fieldNames sortUsingSelector:@selector(caseInsensitiveCompare:)];
    return [fieldNames autorelease];
}

- (NSArray *)requiredFieldsForType:(NSString *)type{
    NSDictionary *fieldsForType = [fieldsForTypesDict objectForKey:type];
	if(fieldsForType){
        return [fieldsForType objectForKey:REQUIRED_KEY];
    }else{
        return [NSArray array];
    }
}

- (NSArray *)optionalFieldsForType:(NSString *)type{
    NSDictionary *fieldsForType = [fieldsForTypesDict objectForKey:type];
	if(fieldsForType){
        return [fieldsForType objectForKey:OPTIONAL_KEY];
    }else{
        return [NSArray array];
    }
}

- (NSArray *)userDefaultFieldsForType:(NSString *)type{
    return [[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKDefaultFieldsKey];
}

- (NSSet *)invalidGroupFields{
	return invalidGroupFields;
}

- (NSSet *)singleValuedGroupFields{ 
	return singleValuedGroupFields;
}

- (NSArray *)bibTypesForFileType:(NSString *)fileType{
    return [typesForFileTypeDict objectForKey:fileType];
}

- (NSString *)fieldNameForPubMedTag:(NSString *)tag{
    return [fieldNameForPubMedTagDict objectForKey:tag];
}

- (NSString *)bibtexTypeForPubMedType:(NSString *)type{
    return [bibtexTypeForPubMedTypeDict objectForKey:type];
}

- (NSString *)bibtexTypeForWebOfScienceType:(NSString *)type{
    return [bibtexTypeForWebOfScienceTypeDict objectForKey:type];
}

- (NSDictionary *)MODSGenresForBibTeXType:(NSString *)type{
    return [MODSGenresForBibTeXTypeDict objectForKey:type];
}

- (NSString *)RISTagForBibTeXFieldName:(NSString *)name{
    NSArray *types = [fieldNameForPubMedTagDict allKeysForObject:name];
    if([types count])
        return [types objectAtIndex:0];
    else
        return [[name stringByPaddingToLength:2 withString:@"1" startingAtIndex:0] uppercaseString]; // manufacture a guess
}

- (NSString *)RISTypeForBibTeXType:(NSString *)type{
    NSArray *types = [bibtexTypeForPubMedTypeDict allKeysForObject:type];
    if([types count])
        return [types objectAtIndex:0];
    else
        return [[type stringByPaddingToLength:4 withString:@"?" startingAtIndex:0] uppercaseString]; // manufacture a guess
}

- (NSString *)fieldNameForJSTORTag:(NSString *)tag{
    NSString *name = [fieldNameForJSTORTagDict objectForKey:tag];
	if(name == nil){
		name = [fieldDescriptionForJSTORTagDict objectForKey:tag];
		name = [[name capitalizedString] stringByReplacingAllOccurrencesOfString:@" " withString:@"-"];
	}
	return name;
}

- (NSString *)fieldNameForJSTORDescription:(NSString *)name{
    NSArray *tags = [fieldDescriptionForJSTORTagDict allKeysForObject:name];
    if([tags count])
		return [fieldNameForJSTORTagDict objectForKey:[tags objectAtIndex:0]];
	return [[name capitalizedString] stringByReplacingAllOccurrencesOfString:@" " withString:@"-"];
}

- (NSString *)fieldNameForWebOfScienceTag:(NSString *)tag{
    NSString *name = [fieldNameForWebOfScienceTagDict objectForKey:tag];
	if(name == nil){
		name = [fieldDescriptionForWebOfScienceTagDict objectForKey:tag];
		name = [[name capitalizedString] stringByReplacingAllOccurrencesOfString:@" " withString:@"-"];
        if(name == nil)
            name = tag; // guard against a nil return; it turns out that not all WOS tags are documented
	}
    OBPOSTCONDITION(name);
    return name;
}

- (NSString *)fieldNameForWebOfScienceDescription:(NSString *)name{
    NSArray *tags = [fieldDescriptionForWebOfScienceTagDict allKeysForObject:name];
    if([tags count])
        return [fieldNameForWebOfScienceTagDict objectForKey:[tags objectAtIndex:0]];
    return [[name capitalizedString] stringByReplacingAllOccurrencesOfString:@" " withString:@"-"];
}    

- (BOOL)isRemoteURLField:(NSString *)field{
    return [remoteURLFieldsSet containsObject:field];
}

- (BOOL)isLocalURLField:(NSString *)field{
    BOOL rv;
    @synchronized(self){
        rv = [localURLFieldsSet containsObject:field];
    }
    return rv;
}

- (BOOL)isURLField:(NSString *)field{
    return [allURLFieldsSet containsObject:field];
}

- (NSSet *)allURLFieldsSet{
    return allURLFieldsSet;
}

// this one needs to be thread safe
- (NSSet *)localURLFieldsSet{
    NSSet *set;
    @synchronized(self){
        set = [[localURLFieldsSet copy] autorelease];
    }
    return set;
}

- (NSSet *)noteFieldsSet{
    return [NSSet setWithObjects:BDSKAnnoteString, BDSKAbstractString, BDSKRssDescriptionString, nil];
}

- (BOOL)isRatingField:(NSString *)field{
    return [ratingFieldsSet containsObject:field];
}

- (BOOL)isTriStateField:(NSString *)field{
    return [triStateFieldsSet containsObject:field];
}

- (BOOL)isBooleanField:(NSString *)field{
    return [booleanFieldsSet containsObject:field];
}

- (BOOL)isNoteField:(NSString *)field{
    return [[self noteFieldsSet] containsObject:field];
}

- (NSSet *)personFieldsSet{
    static NSSet *persons = nil;
    if(persons == nil)
        persons = [[NSSet alloc] initWithObjects:BDSKAuthorString, BDSKEditorString, nil];
    return persons;
}

#pragma mark Character sets

- (NSCharacterSet *)invalidCharactersForField:(NSString *)fieldName inFileType:(NSString *)type{
	if( [fieldName isEqualToString:BDSKCiteKeyString]){
		return invalidCiteKeyCharSet;
	}
	if([self isLocalURLField:fieldName]){
		return invalidLocalUrlCharSet;
	}
	if([self isRemoteURLField:fieldName]){
		return invalidRemoteUrlCharSet;
	}
	return invalidGeneralCharSet;
}

- (NSCharacterSet *)strictInvalidCharactersForField:(NSString *)fieldName inFileType:(NSString *)type{
	if( [fieldName isEqualToString:BDSKCiteKeyString]){
		return strictInvalidCiteKeyCharSet;
	}
	if([self isLocalURLField:fieldName]){
		return strictInvalidLocalUrlCharSet;
	}
	if([self isRemoteURLField:fieldName]){
		return strictInvalidRemoteUrlCharSet;
	}
	return strictInvalidGeneralCharSet;
}

- (NSCharacterSet *)veryStrictInvalidCharactersForField:(NSString *)fieldName inFileType:(NSString *)type{
	if([self isLocalURLField:fieldName]){
		return veryStrictInvalidLocalUrlCharSet;
	}
	return [self strictInvalidCharactersForField:fieldName inFileType:type];
}

- (NSCharacterSet *)invalidFieldNameCharacterSetForFileType:(NSString *)type{
    if([type isEqualToString:BDSKBibtexString])
        return invalidCiteKeyCharSet;
    else
        [NSException raise:BDSKUnimplementedException format:@"invalidFieldNameCharacterSetForFileType is only implemented for BibTeX"];
    // not reached
    return nil;
}

- (NSCharacterSet *)fragileCiteKeyCharacterSet{
	return fragileCiteKeyCharSet;
}

@end

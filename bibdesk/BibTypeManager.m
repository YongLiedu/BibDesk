//
//  BibTypeManager.m
//  Bibdesk
//
//  Created by Michael McCracken on Thu Nov 28 2002.
//  Copyright (c) 2002 __MyCompanyName__. All rights reserved.
//

#import "BibTypeManager.h"

static BibTypeManager *_sharedInstance = nil;

@implementation BibTypeManager
+ (BibTypeManager *)sharedManager{
    if(!_sharedInstance) _sharedInstance = [[BibTypeManager alloc] init];
    return _sharedInstance;
}

- (id)init{
    self = [super init];
    _typeInfoDict = [[NSDictionary dictionaryWithContentsOfFile:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"TypeInfo.plist"]] retain];
    return self;
}

- (NSString *)defaultTypeForFileFormat:(NSString *)fileFormat{
     return [[[_typeInfoDict objectForKey:@"FileTypes"] objectForKey:fileFormat] objectForKey:@"DefaultType"];
}

- (NSArray *)allRemovableFieldNames{
    return [_typeInfoDict objectForKey:@"AllRemovableFieldNames"];
}

- (NSArray *)requiredFieldsForType:(NSString *)type{
    NSDictionary *fieldsForType = [[_typeInfoDict objectForKey:@"FieldsForTypes"] objectForKey:type];

    if(fieldsForType){
        return [fieldsForType objectForKey:@"required"];
    }

    return [NSArray array];
}

- (NSArray *)optionalFieldsForType:(NSString *)type{
    NSDictionary *fieldsForType = [[_typeInfoDict objectForKey:@"FieldsForTypes"] objectForKey:type];

    if(fieldsForType){
        return [fieldsForType objectForKey:@"optional"];
    }

    return [NSArray array];
}

- (NSArray *)userDefaultFieldsForType:(NSString *)type{
    return [[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKDefaultFieldsKey];
}

- (NSArray *)bibTypesForFileType:(NSString *)fileType{
    return [[_typeInfoDict objectForKey:@"TypesForFileType"] objectForKey:fileType];
}
@end

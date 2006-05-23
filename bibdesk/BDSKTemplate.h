//
//  BDSKTemplate.h
//  Bibdesk
//
//  Created by Adam Maxwell on 05/23/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "BDSKTreeNode.h"

typedef enum _BDSKTemplateFormat {
    BDSKTextTemplateFormat,
    BDSKRTFTemplateFormat,
    BDSKDocTemplateFormat
} BDSKTemplateFormat;

extern NSString *BDSKTemplateRoleString;
extern NSString *BDSKTemplateNameString;
extern NSString *BDSKExportTemplateTree;

extern NSString *BDSKTemplateAccessoryString;
extern NSString *BDSKTemplateMainPageString;
extern NSString *BDSKTemplateDefaultItemString;

// concrete subclass with specific accessors for the template tree
@interface BDSKTemplate : BDSKTreeNode
{
}

+ (NSArray *)allStyleNames;
+ (NSArray *)allStyleNamesForFormat:(BDSKTemplateFormat)formatType;
+ (BDSKTemplate *)templateForStyle:(NSString *)styleName;

- (BDSKTemplateFormat)templateFormat;
- (NSString *)fileExtension;

- (NSURL *)mainPageTemplateURL;
- (NSURL *)defaultItemTemplateURL;
- (NSURL *)templateURLForType:(NSString *)pubType;
- (NSArray *)accessoryFileURLs;
- (NSURL *)representedFileURL;
- (BOOL)setAliasFromURL:(NSURL *)aURL;

- (BOOL)addChildWithURL:(NSURL *)fileURL role:(NSString *)role;
- (id)childForRole:(NSString *)role;
- (NSColor *)representedColorForKey:(NSString *)key;
- (BOOL)hasChildWithRole:(NSString *)aRole;

@end



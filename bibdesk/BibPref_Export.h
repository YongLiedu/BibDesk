//
//  BibPref_Export.h
//  Bibdesk
//
//  Created by Adam Maxwell on 05/18/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "BDSKTreeNode.h"

@interface BibPref_Export : OAPreferenceClient {
    IBOutlet NSOutlineView *outlineView;
    NSMutableArray *itemNodes;
    NSMutableArray *roles;    
}

- (IBAction)changeRole:(id)sender;
- (IBAction)addNode:(id)sender;
- (IBAction)removeNode:(id)sender;

@end

// concrete subclass with specific accessors for the template tree
@interface BDSKTemplate : BDSKTreeNode
{
}

+ (NSArray *)allStyleNames;
+ (BDSKTemplate *)templateForStyle:(NSString *)styleName;

- (NSURL *)mainPageTemplateURL;
- (NSURL *)defaultItemTemplateURL;
- (NSURL *)templateURLForType:(NSString *)pubType;
- (NSArray *)accessoryFileURLs;

@end



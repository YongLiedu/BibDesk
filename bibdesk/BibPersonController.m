//
//  BibPersonController.m
//  Bibdesk
//
//  Created by Michael McCracken on Thu Mar 18 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import "BibPersonController.h"


@implementation BibPersonController

#pragma mark initialization


- (NSString *)windowNibName{return @"BibPersonView";}

- (id)initWithPerson:(BibAuthor *)person document:(BibDocument *)doc{
   //  NSLog(@"personcontroller init");
    self = [super initWithWindowNibName:@"BibPersonView"];
	if(self){
            [self setPerson:person];
            publications = [[self publicationsForAuthor:person document:doc] copy];
            
            [person setPersonController:self];
            
            [[self window] setTitle:[[self person] name]];
            [[self window] setDelegate:self];
	}
	return self;

}

- (void)dealloc{
    // NSLog(@"personcontroller dealloc");
    [_person release];
    [publications release];
    [super dealloc];
}

- (void)awakeFromNib{
	if ([[self superclass] instancesRespondToSelector:@selector(awakeFromNib)]){
        [super awakeFromNib];
	}
	
	[[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handlePubListChanged:)
                                                     name:BDSKAuthorPubListChangedNotification
						object:nil]; 
	[self _updateUI];
}

#pragma mark accessors

- (BibAuthor *)person {
    return _person;
}

- (void)setPerson:(BibAuthor *)newPerson {
	_person = [newPerson retain];
}

- (NSMutableArray *)publicationsForAuthor:(BibAuthor *)person document:(BibDocument *)doc{
    NSArray *pubs = [doc publications];
    NSMutableSet *auths = [NSMutableSet set];
    NSEnumerator *pubEnum = [pubs objectEnumerator];
    BibItem *bi;
    NSMutableArray *personsPubs = [NSMutableArray array];
    
    while(bi = [pubEnum nextObject]){
        [auths addObjectsFromArray:[bi pubAuthors]];
        if([auths member:person] != nil){
            [personsPubs addObject:bi];
        }
        [auths removeAllObjects];
    }
    return personsPubs;
}

#pragma mark actions

- (void)show{
    [self showWindow:self];
}

- (void)_updateUI{
	[nameTextField setStringValue:[_person name]];
	[pubsTableView reloadData];
	// TODO: get picture from AB
}

- (void)handlePubListChanged:(NSNotification *)notification{
	[self _updateUI]; 
}

#pragma mark  table view datasource methods
- (int)numberOfRowsInTableView:(NSTableView *)tableView{
	return [publications count]; 
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn 
			row:(int)row{
	NSString *tcid = [tableColumn identifier];
	BibItem *pub = [publications objectAtIndex:row];

	return [pub valueOfField:tcid];
}

@end

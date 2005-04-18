//
//  BDSKTextImportController.m
//  Bibdesk
//
//  Created by Michael McCracken on 4/13/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "BDSKTextImportController.h"


@implementation BDSKTextImportController

- (id)initWithDocument:(BibDocument *)doc{
    self = [super initWithWindowNibName:@"TextImport"];
    if(self){
        document = doc;
        item = [[BibItem alloc] init];
        fields = [[NSMutableArray alloc] init];
        showingWebView = NO;
        itemsAdded = 0;
    }
    return self;
}

- (void)dealloc{
    [item release];
    [fields release];
    [[sourceTextView enclosingScrollView] release];
    [webView release];
    [super dealloc];
}

- (void)awakeFromNib{
	[itemTableView registerForDraggedTypes:[NSArray arrayWithObject:NSStringPboardType]];
    [statusLine setStringValue:@""];
    [citeKeyLine setStringValue:[item citeKey]];
    [self setupTypeUI];
    [self setupSourceUI];
    [[sourceTextView enclosingScrollView] retain];
    [webView retain];
    [itemTableView setDoubleAction:@selector(addTextToCurrentFieldAction:)];
}


- (void)setupSourceUI{
    NSPasteboard* pb = [NSPasteboard generalPasteboard];

    NSArray *typeArray = [NSArray arrayWithObjects:NSURLPboardType, NSRTFDPboardType, 
        NSRTFPboardType, NSStringPboardType, nil];
    
    NSString *pbType = [pb availableTypeFromArray:typeArray];    
    if([pbType isEqualToString:NSURLPboardType]){
        // setup webview and load page
        
		if (!showingWebView) {
			[webView setFrame:[[sourceTextView enclosingScrollView] frame]];
			[sourceBox replaceSubview:[sourceTextView enclosingScrollView] with:webView];
			showingWebView = YES;
		}
        
        NSArray *urls = (NSArray *)[pb propertyListForType:pbType];
        NSURL *url = [NSURL URLWithString:[urls objectAtIndex:0]];
        NSURLRequest *urlreq = [NSURLRequest requestWithURL:url];
        
        [[webView mainFrame] loadRequest:urlreq];
        
    }else{
		
		if (showingWebView) {
			[sourceBox replaceSubview:webView with:[sourceTextView enclosingScrollView]];
			showingWebView = NO;
		}
		
		if([pbType isEqualToString:NSRTFPboardType]){
			
			NSRange r = NSMakeRange(0,[[sourceTextView string] length]);
			[sourceTextView replaceCharactersInRange:r withRTF:[pb dataForType:pbType]];
			
		}else if([pbType isEqualToString:NSRTFDPboardType]){
			
			NSRange r = NSMakeRange(0,[[sourceTextView string] length]);
			[sourceTextView replaceCharactersInRange:r withRTFD:[pb dataForType:pbType]];

		}else if([pbType isEqualToString:NSStringPboardType]){
			
			[sourceTextView setString:[pb stringForType:pbType]];
			
		}else {
			
			[sourceTextView setString:@""];
		}
	}
}


- (void)setupTypeUI{

    // setup the type popup:
    NSEnumerator *typeNamesE = [[[BibTypeManager sharedManager] bibTypesForFileType:[item fileType]] objectEnumerator];
    NSString *typeName = nil;
    
    [itemTypeButton removeAllItems];
    while(typeName = [typeNamesE nextObject]){
        [itemTypeButton addItemWithTitle:typeName];
    }
    
    NSString *type = [[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKPubTypeStringKey];
    
    [self setType:type];
    
    [itemTableView reloadData];
}


- (void)setType:(NSString *)type{
    
    [itemTypeButton selectItemWithTitle:type];
    [item makeType:type];

    BibTypeManager *typeMan = [BibTypeManager sharedManager];

    [fields removeAllObjects];
    
    [fields addObjectsFromArray:[typeMan requiredFieldsForType:type]];
    [fields addObjectsFromArray:[typeMan optionalFieldsForType:type]];
    [fields addObjectsFromArray:[typeMan userDefaultFieldsForType:type]];

}

#pragma mark Actions
- (IBAction)addCurrentItemAction:(id)sender{
    // make the tableview stop editing:
    [[self window] makeFirstResponder:[self window]];
    
    [document addPublication:[item autorelease]];

    [statusLine setStringValue:[NSString stringWithFormat:NSLocalizedString(@"%d publication%@ added.", @"format string for pubs added. args: one int for number added then one string for plural string."), ++itemsAdded, (itemsAdded > 1 ? @"s" : @"")]];

    item = [[BibItem alloc] init];
    [itemTypeButton selectItemWithTitle:[item type]];
    [citeKeyLine setStringValue:[item citeKey]];
    [itemTableView reloadData];
}

- (IBAction)stopAddingAction:(id)sender{
    [[self window] orderOut:sender];
    [NSApp endSheet:[self window] returnCode:[sender tag]];
}

- (IBAction)addTextToCurrentFieldAction:(id)sender{
    
    [self addCurrentSelectionToFieldAtIndex:[sender selectedRow]];
}


- (void)addCurrentSelectionToFieldAtIndex:(int)index{    
    NSString *selKey = [fields objectAtIndex:index];
    NSString *selString = nil;

    if(showingWebView){
        selString = [[[[webView mainFrame] frameView] documentView] selectedString];
        NSLog(@"selstr %@", selString);
    }else{
        NSRange selRange = [sourceTextView selectedRange];
        NSLayoutManager *layoutManager = [sourceTextView layoutManager];
        NSColor *foregroundColor = [NSColor lightGrayColor]; 
        NSDictionary *highlightAttrs = [NSDictionary dictionaryWithObjectsAndKeys: foregroundColor, NSForegroundColorAttributeName, nil];

        selString = [[sourceTextView string] substringWithRange:selRange];
        [layoutManager addTemporaryAttributes:highlightAttrs
                            forCharacterRange:selRange];
    }
    [item setField:selKey toValue:selString];
    
    [item setCiteKey:[item suggestedCiteKey]];
    [citeKeyLine setStringValue:[item citeKey]];
    
    [itemTableView reloadData];
}

- (IBAction)changeTypeOfBibAction:(id)sender{
    NSString *type = [[sender selectedItem] title];
    [self setType:type];
    [[OFPreferenceWrapper sharedPreferenceWrapper] setObject:type
                                                      forKey:BDSKPubTypeStringKey];
    [item setCiteKey:[item suggestedCiteKey]];
    [citeKeyLine setStringValue:[item citeKey]];

    [itemTableView reloadData];
}

- (IBAction)loadPasteboard:(id)sender{
	[self setupSourceUI];
}

- (IBAction)loadFile:(id)sender{
    NSOpenPanel *oPanel = [NSOpenPanel openPanel];
    [oPanel setAllowsMultipleSelection:NO];
    [oPanel setCanChooseDirectories:NO];

    [oPanel beginSheetForDirectory:nil 
                              file:nil 
							 types:nil
                    modalForWindow:[self window]
                     modalDelegate:self 
                    didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:) 
                       contextInfo:nil];
}

- (void)openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo{

    if(returnCode == NSOKButton){
        NSString *fileName = [sheet filename];
		NSURL *url = [NSURL fileURLWithPath:fileName];
		NSTextStorage *text = [sourceTextView textStorage];
		NSLayoutManager *layoutManager = [[text layoutManagers] objectAtIndex:0];

		[[text mutableString] setString:@""];	// Empty the document
		
		if (showingWebView) {
			[sourceBox replaceSubview:webView with:[sourceTextView enclosingScrollView]];
			showingWebView = NO;
		}
		
		[layoutManager retain];			// Temporarily remove layout manager so it doesn't do any work while loading
		[text removeLayoutManager:layoutManager];
		[text beginEditing];			// Bracket with begin/end editing for efficiency
		[text readFromURL:url options:nil documentAttributes:NULL];	// Read!
		[text endEditing];
		[text addLayoutManager:layoutManager];	// Hook layout manager back up
		[layoutManager release];

    }        
}

- (IBAction)loadWebPage:(id)sender{
	[NSApp beginSheet:urlSheet
       modalForWindow:[self window]
        modalDelegate:self
       didEndSelector:@selector(urlSheetDidEnd:returnCode:contextInfo:)
          contextInfo:nil];
}

- (IBAction)dismissUrlSheet:(id)sender{
    [urlSheet orderOut:sender];
    [NSApp endSheet:urlSheet returnCode:[sender tag]];
}

- (void)urlSheetDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo{

    if(returnCode == NSOKButton){
		// setup webview and load page
        
		if (!showingWebView) {
			[webView setFrame:[[sourceTextView enclosingScrollView] frame]];
			[sourceBox replaceSubview:[sourceTextView enclosingScrollView] with:webView];
			showingWebView = YES;
		}
        
        NSURL *url = [NSURL URLWithString:[urlTextField stringValue]];
        NSURLRequest *urlreq = [NSURLRequest requestWithURL:url];
        
        [[webView mainFrame] loadRequest:urlreq];
    }        
}

#pragma mark WebUIDelegate

- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems{
	NSMutableArray *menuItems = [NSMutableArray arrayWithCapacity:6];
	NSMenuItem *menuItem;
	
	NSEnumerator *iEnum = [defaultMenuItems objectEnumerator];
	while (menuItem = [iEnum nextObject]) { 
		if ([menuItem tag] == WebMenuItemTagCopy ||
			[menuItem tag] == WebMenuItemTagCopyLinkToClipboard) {
			
			[menuItems addObject:menuItem];
		}
	}
	if ([menuItems count] > 0) 
		[menuItems addObject:[NSMenuItem separatorItem]];
	
	menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Back",@"Back")
									  action:@selector(goBack:)
							   keyEquivalent:@""];
	[menuItems addObject:[menuItem autorelease]];
	
	menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Forward",@"Forward")
									  action:@selector(goForward:)
							   keyEquivalent:@""];
	[menuItems addObject:[menuItem autorelease]];
	
	menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Reload",@"Reload")
									  action:@selector(reload:)
							   keyEquivalent:@""];
	[menuItems addObject:[menuItem autorelease]];
	
	menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Stop",@"Stop")
									  action:@selector(stopLoading:)
							   keyEquivalent:@""];
	[menuItems addObject:[menuItem autorelease]];
	
	menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Increase Text Size",@"Increase Text Size")
									  action:@selector(makeTextLarger:)
							   keyEquivalent:@""];
	[menuItems addObject:[menuItem autorelease]];
	
	menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Decrease Text Size",@"Increase Text Size")
									  action:@selector(makeTextSmaller:)
							   keyEquivalent:@""];
	[menuItems addObject:[menuItem autorelease]];
	
	return menuItems;
}

#pragma mark WebFrameLoadDelegate

- (void)webView:(WebView *)sender didStartProvisionalLoadForFrame:(WebFrame *)frame{
	if ([progressIndicator respondsToSelector:@selector(setHidden:)])
		[progressIndicator setHidden:NO];
	[progressIndicator startAnimation:nil];
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame{
	if ([progressIndicator respondsToSelector:@selector(setHidden:)])
		[progressIndicator setHidden:YES];
	[progressIndicator stopAnimation:nil];
}

#pragma mark TableView Data source

- (int)numberOfRowsInTableView:(NSTableView *)tableView{
    return [fields count]; 
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row{
    NSString *key = [fields objectAtIndex:row];
    NSString *tcID = [tableColumn identifier];
    
    if([tcID isEqualToString:@"FieldName"]){
        return key;
    }else if([tcID isEqualToString:@"Num"]){
        if(row < 10)
            return [NSString stringWithFormat:@"%C%d", 0x2318, row];
        else return @"";
    }else{
        return [[item pubFields] objectForKey:key];
    }
}

- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(int)row{
    NSString *tcID = [tableColumn identifier];
    if([tcID isEqualToString:@"FieldName"] ||
       [tcID isEqualToString:@"Num"] ){
        return NO;
    }
    return YES;
}


- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row{
    NSString *tcID = [tableColumn identifier];
    if([tcID isEqualToString:@"FieldName"] ||
       [tcID isEqualToString:@"Num"] ){
        return; // don't edit the first column. Shouldn't happen anyway.
    }
    
    NSString *key = [fields objectAtIndex:row];
    [item setField:key toValue:object];
    [item setCiteKey:[item suggestedCiteKey]];
    [citeKeyLine setStringValue:[item citeKey]];
}

// This method is called after it has been determined that a drag should begin, but before the drag has been started.  To refuse the drag, return NO.  To start a drag, return YES and place the drag data onto the pasteboard (data, owner, etc...).  The drag image and other drag related information will be set up and provided by the table view once this call returns with YES.  The rows array is the list of row numbers that will be participating in the drag.
- (BOOL)tableView:(NSTableView *)tv writeRows:(NSArray*)rows toPasteboard:(NSPasteboard*)pboard{
    return NO;   
}

// This method is used by NSTableView to determine a valid drop target.  Based on the mouse position, the table view will suggest a proposed drop location.  This method must return a value that indicates which dragging operation the data source will perform.  The data source may "re-target" a drop if desired by calling setDropRow:dropOperation: and returning something other than NSDragOperationNone.  One may choose to re-target for various reasons (eg. for better visual feedback when inserting into a sorted position).
- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)op{
    if(op ==  NSTableViewDropOn)
        return NSDragOperationCopy;
    else return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView*)tv acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)op{
    NSPasteboard *pb = [info draggingPasteboard];
    NSString *pbType = [pb availableTypeFromArray:[NSArray arrayWithObjects:NSStringPboardType, nil]];
    if ([NSStringPboardType isEqualToString:pbType]){

        NSString *key = [fields objectAtIndex:row];
        [item setField:key toValue:[pb stringForType:NSStringPboardType]];
        [itemTableView reloadData];
    }
    return YES;
}
    // This method is called when the mouse is released over an outline view that previously decided to allow a drop via the validateDrop method.  The data source should incorporate the data from the dragging pasteboard at this time.

@end


@implementation TextImportItemTableView
- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal {
    if (isLocal) return NSDragOperationEvery;
    else return NSDragOperationCopy;
}

- (BOOL)performKeyEquivalent:(NSEvent *)theEvent{
    
    NSString *chars = [theEvent charactersIgnoringModifiers];
    unsigned int flags = [theEvent modifierFlags];
    
    if (flags | NSCommandKeyMask && 
        [chars containsCharacterInSet:[NSCharacterSet characterSetWithCharactersInString:@"01234567890"]]) {

        unsigned index = (unsigned)[chars characterAtIndex:0];
        [[self delegate] addCurrentSelectionToFieldAtIndex:index-48]; // 48 is the char value of 0.
        return YES;
    }
    
    return [super performKeyEquivalent:theEvent];
}

@end

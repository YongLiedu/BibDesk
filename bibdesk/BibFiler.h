//
//  BibFiler.h
//  Bibdesk
//
//  Created by Michael McCracken on Fri Apr 30 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BibPrefController.h"
#import "BibItem.h"
@class BibDocument;

@interface BibFiler : NSObject {
	NSMutableArray *_fileInfoDicts;
	
	IBOutlet NSWindow *window;
	IBOutlet NSTableView *tv;
	IBOutlet NSButton *actionButton;
	IBOutlet NSButton *cancelButton;
	IBOutlet NSTextField *infoTextField;
	IBOutlet NSButton *cleanupCheckBox;
	IBOutlet NSButton *deleteCheckBox;
	
	NSArray *_currentPapers;
	BibDocument *_currentDocument;
	NSString *_errorString;
	int _moveCount;
	int _movableCount;
	int _deletedCount;
	int _cleanupChangeCount;
}

+ (BibFiler *)sharedFiler;

- (void)filePapers:(NSArray *)papers fromDocument:(BibDocument *)doc ask:(BOOL)ask;
- (void)movePath:(NSString *)path toPath:(NSString *)newPath forPaper:(BibItem *)paper fromDocument:(BibDocument *)doc moveAll:(BOOL)moveAll;
- (void)prepareMoveForDocument:(BibDocument *)doc;
- (void)finishMoveForDocument:(BibDocument *)doc;
- (void)showProblems;
- (IBAction)done:(id)sender;
- (IBAction)showFile:(id)sender;

- (void)showPreviewForPapers:(NSArray *)papers fromDocument:(BibDocument *)doc;
- (void)doMoveAction:(id)sender;
- (IBAction)cancelFromPreview:(id)sender;
- (void)doCleanup;
- (void)file:(BOOL)doFile papers:(NSArray *)papers fromDocument:(BibDocument *)doc;

- (BOOL)fileManager:(NSFileManager *)manager shouldProceedAfterError:(NSDictionary *)errorInfo;

- (IBAction)handleCleanupLinksAction:(id)sender;

@end

//
//  BDSKFiler.h
//  BibDesk
//
//  Created by Michael McCracken on Fri Apr 30 2004.
/*
 This software is Copyright (c) 2004-2011
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

#import <Cocoa/Cocoa.h>

extern NSString *BDSKFilerFileKey;
extern NSString *BDSKFilerPublicationKey;
extern NSString *BDSKFilerOldPathKey;
extern NSString *BDSKFilerNewPathKey;
extern NSString *BDSKFilerStatusKey;
extern NSString *BDSKFilerFlagKey;
extern NSString *BDSKFilerFixKey;

@class BibDocument;

enum {
	BDSKNoError = 0,
	BDSKSourceFileDoesNotExistErrorMask = 1 << 0,
	BDSKTargetFileExistsErrorMask = 1 << 1,
	BDSKCannotMoveFileErrorMask = 1 << 2,
	BDSKCannotRemoveFileErrorMask = 1 << 3,
    BDSKCannotResolveAliasErrorMask = 1 << 4,
    BDSKCannotCreateParentErrorMask = 1 << 5,
	BDSKIncompleteFieldsErrorMask = 1 << 6
};

enum {
    BDSKInitialAutoFileOptionMask = 1 << 0,
    BDSKCheckCompleteAutoFileOptionMask = 1 << 1,
    BDSKForceAutoFileOptionMask = 1 << 2
};
typedef NSUInteger BDSKFilerOptions;

@interface BDSKFiler : NSWindowController {
	IBOutlet NSProgressIndicator *progressIndicator;
}

+ (BDSKFiler *)sharedFiler;

/*!
	@method		autoFileLinkedFiles:fromDocument:doc:check:
	@abstract	Main auto-file routine to file papers in the Papers folder according to a generated location.
	@param		papers An array of linked files to be auto-filed.
	@param		doc The parent document of the papers. 
	@param		check Boolean determines whether to move only entries with all necessary fields set. 
	@discussion	This is the main method that should be used to autofile papers.
It calls the necessary methods to do the move and generates the new locations for the papers. 
*/
- (void)autoFileLinkedFiles:(NSArray *)papers fromDocument:(BibDocument *)doc check:(BOOL)check;

/*!
	@method		movePapers:forField:fromDocument:options:
	@abstract	Tries to move list of papers from a document.
	@param		paperInfos A list of info dictionaries containing a BibItem, a BDSKLinkedFile and for non-initial autofiles a target path.
	@param		field The field for which to move the linked files.
	@param		doc The parent document of the papers. 
	@param		mask Integer, see the AutoFileOptionMask enum for options. 
	@discussion This is the core method to move files. 
It is undoable, but only moves that were succesfull are registered for undo. 
It can handle aliases and symlinks, also when they occur in the middle of the paths. 
Aliases and symlinks are moved unresolved. Relative paths in symlinks will be made absolute. 
BDSKInitialAutoFileOptionMask should be used for initial autofile moves, the new path will be generated. 
BDSKCheckCompleteAutoFileOptionMask indicates that for initial moves a check will be done whether all required fields are set. 
BDSKForceAutoFileOptionMask forces AutoFiling, even if there may be problems moving the file. 
*/
- (void)movePapers:(NSArray *)paperInfos forField:(NSString *)field fromDocument:(BibDocument *)doc options:(BDSKFilerOptions)masks;

@end


@interface NSFileManager (BDSKFilerExtensions)

/*!
	@method		movePath:toPath:force:error:
	@abstract	Extension to movePath:toPath:handler: which can handle symlinks and aliases, and allows for forcing a move when otherwise move errors occur.
	@param		path The path to the file to move. 
	@param		newPath The pathwhere the file should move to. 
	@param		force Boolean. If YES, overwrite an existing file or copy a non-removable file. 
	@param		error An NSError object set when an error occurs.
	@discussion -
*/
- (BOOL)movePath:(NSString *)path toPath:(NSString *)newPath force:(BOOL)force error:(NSError **)error;

@end

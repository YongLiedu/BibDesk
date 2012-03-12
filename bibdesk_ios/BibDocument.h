//
//  BibDocument.h
//  BibDesk
//
//  Created by Colin A. Smith on 3/9/12.
/*
 This software is Copyright (c) 2012-2012
 Colin A. Smith. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Colin A. Smith nor the names of any
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

#import <UIKit/UIKit.h>

#import "BDSKOwnerProtocol.h"

@class BDSKPublicationsArray;
@class BDSKGroupsArray;
@class BDSKMacroResolver;

enum {
    BDSKOperationIgnore = 1, // NSAlertDefaultReturn
    BDSKOperationSet = 0, // NSAlertAlternateReturn
    BDSKOperationAppend = -1, // NSAlertOtherReturn
    BDSKOperationAsk = -2, // NSAlertErrorReturn
};

@interface BibDocument : UIDocument <BDSKOwner> {

#pragma mark Publications and Groups variables

    BDSKPublicationsArray *publications;  // holds all the publications
   
    BDSKGroupsArray *groups;

#pragma mark Macros, Document Info and Front Matter variables

    BDSKMacroResolver *macroResolver;
    
    NSDictionary *documentInfo;
    
    NSString *frontMatter;    // for preambles, and stuff
    
    NSStringEncoding documentStringEncoding;
    
    BOOL wasLoaded;
}

- (BOOL)loadFromContents:(id)contents ofType:(NSString *)typeName error:(NSError **)outError;

- (BDSKGroupsArray *)groups;

- (NSStringEncoding)documentStringEncoding;
- (void)setDocumentStringEncoding:(NSStringEncoding)encoding;

@end

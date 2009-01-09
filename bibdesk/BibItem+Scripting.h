//
//  BibItemClassDescription.h
//  BibDesk
//
//  Created by Sven-S. Porst on Sat Jul 10 2004.
/*
 This software is Copyright (c) 2004-2009
 Sven-S. Porst. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 - Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in
 the documentation and/or other materials provided with the
 distribution.
 
 - Neither the name of Sven-S. Porst nor the names of any
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
#import <Foundation/Foundation.h>
#import "BibItem.h"
#import "BDSKField.h"


@interface BibItem (Scripting) 

- (BDSKField *)valueInBibFieldsWithName:(NSString *)name;
- (NSArray *)bibFields;

- (NSArray *)scriptingAuthors;
- (BibAuthor*)valueInScriptingAuthorsWithName:(NSString*)name;

- (NSArray *)scriptingEditors;
- (BibAuthor *)valueInScriptingEditorsWithName:(NSString *)name;

- (NSArray *)linkedFiles;
- (void)insertInLinkedFiles:(NSURL *)newURL;
- (void)insertObject:(NSURL *)newURL inLinkedFilesAtIndex:(unsigned int)idx;
- (void)removeObjectFromLinkedFilesAtIndex:(unsigned int)idx;

- (NSArray *)linkedURLs;
- (void)insertInLinkedURLs:(NSString *)newURLString;
- (void)insertObject:(NSString *)newURLString inLinkedURLsAtIndex:(unsigned int)idx;
- (void)removeObjectFromLinkedURLsAtIndex:(unsigned int)idx;

- (id)scriptingDocument;
- (id)group;

- (BOOL)isExternal;

- (void)setBibTeXString:(NSString*) btString;

- (NSString *)scriptingCiteKey;
- (void)setScriptingCiteKey:(NSString *)newKey;

- (NSString*)scriptingTitle;
- (void)setScriptingTitle:(NSString *)newTitle;

// wrapping original methods 
- (NSDate*)scriptingDateAdded;
- (NSDate*)scriptingDateModified;

// more (pseudo) accessors for key-value coding
- (NSString*)remoteURLString;
- (void)setRemoteURLString:(NSString*) newURLString;

- (NSString*)localURLString;
- (void)setLocalURLString:(NSString*) newPath;

- (NSString*)abstract;
- (void)setAbstract:(NSString*) newAbstract;

- (NSString*)annotation;
- (void)setAnnotation:(NSString*) newAnnotation;

- (NSString*)rssDescription;
- (void)setRssDescription:(NSString*) newDesc; 

- (NSString*)rssString;

- (NSString*)risString;

- (NSTextStorage *)styledTextValue;

- (NSString *)keywords;
- (void)setKeywords:(NSString *)keywords;

- (int)scriptingRating;
- (void)setScriptingRating:(int)rating;

- (NSScriptObjectSpecifier *) objectSpecifier;


@end





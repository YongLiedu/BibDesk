//
//  NSArray_BDSKExtensions.h
//  Bibdesk
//
//  Created by Adam Maxwell on 12/21/05.
/*
 This software is Copyright (c) 2005-2012
 Adam Maxwell. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 - Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in
 the documentation and/or other materials provided with the
 distribution.
 
 - Neither the name of Adam Maxwell nor the names of any
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


@interface NSArray (BDSKExtensions)

- (id)nonEmpty;

- (id)firstObject;
- (id)secondObject;
- (id)thirdObject;
- (id)fourthObject;
- (id)fifthObject;
- (id)sixthObject;
- (id)seventhObject;
- (id)eighthObject;
- (id)ninthObject;
- (id)tenthObject;

- (NSArray *)firstOneObjects;
- (NSArray *)firstTwoObjects;
- (NSArray *)firstThreeObjects;
- (NSArray *)firstFourObjects;
- (NSArray *)firstFiveObjects;
- (NSArray *)firstSixObjects;
- (NSArray *)lastOneObjects;
- (NSArray *)arrayDroppingFirstObject;
- (NSArray *)arrayDroppingLastObject;

- (NSArray *)arraySortedByAuthor;
- (NSArray *)arraySortedByAuthorOrEditor;
- (NSArray *)arraySortedByTitle;

- (NSString *)componentsJoinedByComma;
- (NSString *)componentsJoinedByAnd;
- (NSString *)componentsJoinedByForwardSlash;
- (NSString *)componentsJoinedBySemicolon;
- (NSString *)componentsJoinedByDefaultJoinString;
- (NSString *)componentsJoinedByCommaAndAnd;
- (NSString *)componentsJoinedByCommaAndAmpersand;
- (NSString *)componentsWithEtAlAfterOne;
- (NSString *)componentsJoinedByAndWithSingleEtAlAfterTwo;
- (NSString *)componentsJoinedByCommaAndAndWithSingleEtAlAfterThree;
- (NSString *)componentsJoinedByAndWithEtAlAfterTwo;
- (NSString *)componentsJoinedByCommaAndAndWithEtAlAfterThree;
- (NSString *)componentsJoinedByAmpersandWithSingleEtAlAfterTwo;
- (NSString *)componentsJoinedByCommaAndAmpersandWithSingleEtAlAfterFive;
- (NSString *)componentsJoinedByCommaAndAmpersandWithEtAlAfterSix;
- (NSString *)componentsJoinedByCommaWithEtAlAfterSix;

- (NSArray *)indexRanges;
- (NSArray *)indexRangeStrings;

- (NSArray *)arrayByRemovingObject:(id)anObject;

- (NSIndexSet *)indexesOfObjects:(NSArray *)objects;
- (NSIndexSet *)indexesOfObjectsIdenticalTo:(NSArray *)objects;
- (NSArray *)objectsAtIndexSpecifiers:(NSArray *)indexes;

- (id)sortedArrayUsingMergesortWithDescriptors:(NSArray *)sortDescriptors;

@end

@interface NSMutableArray (BDSKExtensions)

- (void)addNonDuplicateObjectsFromArray:(NSArray *)otherArray;

- (void)sortUsingSelector:(SEL)comparator ascending:(BOOL)ascend;
- (void)insertObject:anObject inArraySortedUsingDescriptors:(NSArray *)sortDescriptors;
- (void)insertObjects:(NSArray *)objects inArraySortedUsingDescriptors:(NSArray *)sortDescriptors;

- (void)mergeSortUsingDescriptors:(NSArray *)sortDescriptors;

@end

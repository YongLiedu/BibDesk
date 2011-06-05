//
//  NSDictionary_BDSKExtensions.h
//  Bibdesk
//
//  Created by Christiaan Hofman on 8/5/06.
/*
 This software is Copyright (c) 2006-2011
 Christiaan Hofman. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Christiaan Hofman nor the names of any
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
/*
 Omni Source License 2007

 OPEN PERMISSION TO USE AND REPRODUCE OMNI SOURCE CODE SOFTWARE

 Omni Source Code software is available from The Omni Group on their 
 web site at http://www.omnigroup.com/www.omnigroup.com. 

 Permission is hereby granted, free of charge, to any person obtaining 
 a copy of this software and associated documentation files (the 
 "Software"), to deal in the Software without restriction, including 
 without limitation the rights to use, copy, modify, merge, publish, 
 distribute, sublicense, and/or sell copies of the Software, and to 
 permit persons to whom the Software is furnished to do so, subject to 
 the following conditions:

 Any original copyright notices and this permission notice shall be 
 included in all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, 
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF 
 MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. 
 IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY 
 CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, 
 TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE 
 SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import <Cocoa/Cocoa.h>


@interface NSDictionary (BDSKExtensions)

- (id)initWithObjects:(id *)objects forCaseInsensitiveKeys:(NSString **)keys count:(NSUInteger)count;
- (id)initForCaseInsensitiveKeysWithDictionary:(NSDictionary *)aDictionary;

- (BOOL)boolForKey:(NSString *)key defaultValue:(BOOL)defaultValue;
- (NSInteger)integerForKey:(NSString *)key defaultValue:(NSInteger)defaultValue;
- (NSUInteger)unsignedIntegerForKey:(NSString *)key defaultValue:(NSUInteger)defaultValue;
- (double)doubleForKey:(NSString *)key defaultValue:(double)defaultValue;

// these get the default value from NSUserDefaults
- (BOOL)boolForKeyOrDefaultValue:(NSString *)key;
- (NSInteger)integerForKeyOrDefaultValue:(NSString *)key;
- (double)doubleForKeyOrDefaultValue:(NSString *)key;
- (id)objectForKeyOrDefaultValue:(NSString *)key;

@end

#pragma mark -

@interface NSMutableDictionary (BDSKExtensions)

- (id)initForCaseInsensitiveKeys;

- (void)setBool:(BOOL)value forKey:(NSString *)key;
- (void)setInteger:(NSInteger)value forKey:(NSString *)key;
- (void)setUnsignedInteger:(NSUInteger)value forKey:(NSString *)key;
- (void)setDouble:(double)value forKey:(NSString *)key;

@end

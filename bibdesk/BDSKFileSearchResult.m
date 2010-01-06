//
//  BDSKFileSearchResult.m
//  Bibdesk
//
//  Created by Adam Maxwell on 10/12/05.
/*
 This software is Copyright (c) 2005-2009
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

#import "BDSKFileSearchResult.h"
#import "NSImage_BDSKExtensions.h"
#import "BDSKFile.h"

@implementation BDSKFileSearchResult

- (id)initWithURL:(NSURL *)aURL identifierURL:(NSURL *)anIdentifierURL title:(NSString *)aTitle score:(CGFloat)aScore;
{
    
    NSParameterAssert(nil != aURL);
    NSParameterAssert(nil != anIdentifierURL);
        
    if ((self = [super init])) {
        
        url = [aURL copy];

        image = [[NSImage imageForURL:aURL] retain];
        
        string = aTitle ? [aTitle copy] : [[aURL path] copy];
        identifierURL = [anIdentifierURL copy];
        
        score = aScore;
    }
    
    return self;
}

- (void)dealloc
{
    BDSKDESTROY(url);
    BDSKDESTROY(string);
    BDSKDESTROY(identifierURL);
    BDSKDESTROY(image);
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone
{
    BDSKFileSearchResult *copy = [[[self class] allocWithZone:zone] init];
    copy->url = [url copy];
    copy->string = [string copy];
    copy->identifierURL = [identifierURL copy];
    copy->image = [image retain];
    copy->score = score;
    return copy;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"File: %@ \n\t string = \"%@\"", url, string];
}

- (NSUInteger)hash
{
    return [url hash];
}

- (BOOL)isEqual:(id)anObject
{
    // base equality on identifierURL, since items are now displayed per-pub and the same file may appear multiple times
    return ([anObject isKindOfClass:[self class]] && [((BDSKFileSearchResult *)anObject)->url isEqual:url] && [((BDSKFileSearchResult *)anObject)->identifierURL isEqual:identifierURL]);
}

- (NSImage *)image { return image; }
- (NSString *)string { return string; }
- (NSURL *)identifierURL { return identifierURL; }
- (NSURL *)URL { return url; }
- (void)setScore:(double)newScore { score = newScore; }
- (double)score { return score; }

@end


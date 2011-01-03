//
//  TestComplexString.m
//  Bibdesk
//
//  Created by Gregory Jefferis on 2009-01-09.
/* This software is Copyright (c) 2009-2011
 Gregory Jefferis. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Gregory Jefferis nor the names of any
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

#import "TestComplexString.h"
#import "BDSKComplexString.h"
#import "BDSKStringNode.h"
#import "BDSKMacroResolver.h"


@implementation TestStringNode

- (void)testNumberFromBibTeXString{
    BDSKStringNode *sn = [BDSKStringNode nodeWithNumberString:@"14"];
    STAssertNotNil(sn,nil);
    STAssertTrue(BDSKStringNodeNumber==[sn type],nil);
    STAssertEqualObjects(@"14", [sn value],nil);
}

- (void)testStringFromBibTeXString{
    BDSKStringNode *sn = [BDSKStringNode nodeWithQuotedString:@"string"];
    
    STAssertNotNil(sn,nil);
    STAssertTrue(BDSKStringNodeString==[sn type],nil);
    STAssertEqualObjects(@"string", [sn value],nil);
}

- (void)testMacroFromBibTeXString{
    BDSKStringNode *sn = [BDSKStringNode nodeWithMacroString:@"macro"];
    
    STAssertNotNil(sn,nil);
    STAssertTrue(BDSKStringNodeMacro==[sn type],nil);
    STAssertEqualObjects(@"macro", [sn value],nil);
}

@end

@implementation TestComplexString


- (BDSKMacroResolver *)macroResolver;
{
	static BDSKMacroResolver *macroResolver = nil;
	if (macroResolver == nil) {
		macroResolver = [[BDSKMacroResolver alloc] initWithOwner:nil];
		[macroResolver setMacro:@"macro1" toValue:@"expansion1"];
		[macroResolver setMacro:@"macro2" toValue:@"expansion2"];
	}
	return macroResolver;
}

- (void)testLoneMacroFromBibTeXString{
    NSString *cs = [NSString stringWithBibTeXString:@"macro1"
											   macroResolver:[self macroResolver]
													   error:nil];
    
    STAssertNotNil(cs,nil);
    STAssertTrue([cs isComplex],nil);
    STAssertEqualObjects(@"expansion1",cs,nil);
} 

- (void)testQuotedStringFromBibTeXString{
    NSString *cs = [NSString stringWithBibTeXString:@"{quoted string}"
											   macroResolver:[self macroResolver]
													   error:nil];
    STAssertNotNil(cs,nil);
    STAssertFalse([cs isComplex],nil);
    STAssertEqualObjects(@"quoted string",cs,nil);
}

- (void)testLoneNumberFromBibTeXString{
    NSString *cs = [NSString stringWithBibTeXString:@"14"
											   macroResolver:[self macroResolver]
													   error:nil];
    STAssertNotNil(cs,nil);
    STAssertTrue([cs isComplex],nil);
    STAssertEqualObjects(@"14",cs,nil);
}

- (void)testTwoNumbersFromBibTeXString{
    NSString *cs = [NSString stringWithBibTeXString:@"14 # 14"
											   macroResolver:[self macroResolver] error:nil];
    STAssertNotNil(cs,nil);
    STAssertTrue([cs isComplex],nil);
    STAssertEqualObjects(cs,@"1414",nil);
}

- (void)testThreeNumbersFromBibTeXString{
    NSString *cs = [NSString stringWithBibTeXString:@"14 # 14 # 14"
											   macroResolver:[self macroResolver] error:nil];
    STAssertNotNil(cs,nil);
    STAssertTrue([cs isComplex],nil);
    STAssertEqualObjects(cs,@"141414",nil);
}

- (void)testQuotedNestedStringFromBibTeXString{
    NSString *cs = [NSString stringWithBibTeXString:@"{quoted {nested} string}"
											   macroResolver:[self macroResolver] error:nil];
    STAssertNotNil(cs,nil);
    STAssertFalse([cs isComplex],nil);
    STAssertEqualObjects(cs,@"quoted {nested} string",nil);
}

- (void)testQuotedNestedConcatenatedStringFromBibTeXString{
    NSString *cs = [NSString stringWithBibTeXString:@"{A } # {quoted {nested} string} # {dood}"
											   macroResolver:[self macroResolver] error:nil];
    STAssertNotNil(cs,nil);
    STAssertTrue([cs isComplex],nil);
    STAssertEqualObjects( (NSString *)cs,@"A quoted {nested} stringdood",nil);
    STAssertNotNil([cs nodes],nil);
    STAssertTrue([[cs nodes] count]==3,nil);
}

- (void)testDisplayTwoNumbers{
    NSArray *a = [NSArray arrayWithObjects:[BDSKStringNode nodeWithNumberString:@"14"], 
				  [BDSKStringNode nodeWithNumberString:@"14"], nil];
    NSString *cs = [NSString stringWithNodes:a
							   macroResolver:[self macroResolver]];
    STAssertNotNil(cs,nil);
    STAssertTrue([cs isComplex],nil);
    STAssertEqualObjects(cs,@"1414",nil);
}

- (void)testDisplayThreeNumbers{
    NSArray *a = [NSArray arrayWithObjects:[BDSKStringNode nodeWithNumberString:@"14"], 
				  [BDSKStringNode nodeWithNumberString:@"14"], 
				  [BDSKStringNode nodeWithNumberString:@"14"], nil];
    NSString *cs = [NSString stringWithNodes:a
										macroResolver:[self macroResolver]];
    STAssertNotNil(cs,nil);
    STAssertTrue([cs isComplex],nil);
    STAssertEqualObjects(cs,@"141414",nil);
}

- (void)testDisplaySingleStringNode{
    NSArray *a = [NSArray arrayWithObjects:[BDSKStringNode nodeWithQuotedString:@"string"], nil];
    NSString *cs = [NSString stringWithNodes:a
										macroResolver:[self macroResolver]];
    STAssertNotNil(cs,nil);
    STAssertFalse([cs isComplex],nil);
    STAssertEqualObjects(cs,@"string",nil);
}

@end

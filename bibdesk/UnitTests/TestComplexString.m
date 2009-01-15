//
//  TestComplexString.m
//  Bibdesk
//
//  Created by Gregory Jefferis on 2009-01-09.
//  Copyright 2009 Gregory Jefferis. All rights reserved.
//

#import "TestComplexString.h"


@implementation TestStringNode

- (void)testNumberFromBibTeXString{
    BDSKStringNode *sn = [BDSKStringNode nodeWithNumberString:@"14"];
    STAssertNotNil(sn,nil);
    STAssertEquals(BSN_NUMBER, [sn type],nil);
    STAssertEqualObjects(@"14", [sn value],nil);
}

- (void)testStringFromBibTeXString{
    BDSKStringNode *sn = [BDSKStringNode nodeWithQuotedString:@"string"];
    
    STAssertNotNil(sn,nil);
    STAssertEquals(BSN_STRING, [sn type],nil);
    STAssertEqualObjects(@"string", [sn value],nil);
}

- (void)testMacroFromBibTeXString{
    BDSKStringNode *sn = [BDSKStringNode nodeWithMacroString:@"macro"];
    
    STAssertNotNil(sn,nil);
    STAssertEquals(BSN_MACRODEF, [sn type],nil);
    STAssertEqualObjects(@"macro", [sn value],nil);
}

@end

@implementation TestComplexString


- (BDSKMacroResolver *)macroResolver;
{
	static BDSKMacroResolver *macroResolver = nil;
	if (macroResolver == nil) {
		macroResolver = [[BDSKMacroResolver alloc] initWithOwner:nil];
		[macroResolver addMacroDefinition:@"expansion1"  
								 forMacro:@"macro1"];
		[macroResolver addMacroDefinition:@"expansion2"  
								 forMacro:@"macro2"];
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
    STAssertEquals( [[cs nodes] count], (NSUInteger) 3,nil);
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

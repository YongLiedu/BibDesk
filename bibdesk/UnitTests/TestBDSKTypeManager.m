//
//  TestBDSKTypeManager.m
//  Bibdesk
//
//  Created by Gregory Jefferis on 2009-01-06.
//  Copyright 2009 Gregory Jefferis. All rights reserved.
//

#import "TestBDSKTypeManager.h"


@implementation TestBDSKTypeManager
- (void)testReadTypeInfoPlist{
	NSDictionary *tid = [NSDictionary dictionaryWithContentsOfFile:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:TYPE_INFO_FILENAME]];

	// This will fail if TypeInfo.plist has any syntax errors which prevent it from loading
	STAssertTrue([tid count]>0 ,@"Check that we are able to load (and parse) TypeInfo.plist");
}

@end

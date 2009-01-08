//
//  TestUnitTest.m
//  Bibdesk
//
//  Created by Gregory Jefferis on 2009-01-04.
//  Copyright 2009 Gregory Jefferis. All rights reserved.
//

// This is a very simple example unit test that tests if we can actually run a test at all!
// To add a new unit test, Right Click the "Unit Tests" Target and Choose
// Add ... New File ... Cocoa Objective-C test case class
// For tidiness, put the new file in the UnitTests group
// See http://bill.dudney.net/roller/objc/entry/5 and 
// http://developer.apple.com/tools/unittest.html
// for more info.  

#import "TestUnitTest.h"


@implementation TestUnitTest
- (void)setUp {
    // create the object(s) that we want to test
    [super setUp];
//    testable = [[Testable alloc] init];
}

-(void)tearDown {
    // clean up any stuff like open files or whatever
//    [testable release];
    [super tearDown];
}

- (void)testAdd {
    STAssertEquals(4+5, 9, @"should make 9");
}
@end

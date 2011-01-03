//
//  TestUnitTest.m
//  Bibdesk
//
//  Created by Gregory Jefferis on 2009-01-04.
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

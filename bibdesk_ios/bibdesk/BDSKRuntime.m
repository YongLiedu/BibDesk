//
//  BDSKRuntime.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 2/19/09.
/*
 This software is Copyright (c) 2009-2012
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

#import "BDSKRuntime.h"
#import <objc/objc-runtime.h>

#define BDSKAbstractImplementationException @"BDSKAbstractImplementation"

#pragma mark API

// this is essentially class_replaceMethod, but handles instance/class methods, returns any inherited implementation, and can get the types from an inherited implementation
IMP BDSKSetInstanceMethodImplementation(Class aClass, SEL aSelector, IMP anImp, const char *types, NSInteger options) {
    IMP imp = NULL;
    if (anImp) {
        Method method = class_getInstanceMethod(aClass, aSelector);
        if (method) {
            imp = method_getImplementation(method);
            if (types == NULL)
                types = method_getTypeEncoding(method);
        }
        if (types != NULL && (options != BDSKAddOnly || imp == NULL) && (options != BDSKReplaceOnly || imp != NULL))
            class_replaceMethod(aClass, aSelector, anImp, types);
    }
    return imp;
}

IMP BDSKSetInstanceMethodImplementationFromSelector(Class aClass, SEL aSelector, SEL impSelector, NSInteger options) {
    Method method = class_getInstanceMethod(aClass, impSelector);
    return method ? BDSKSetInstanceMethodImplementation(aClass, aSelector, method_getImplementation(method), method_getTypeEncoding(method), options) : NULL;
}

IMP BDSKReplaceInstanceMethodImplementation(Class aClass, SEL aSelector, IMP anImp) {
    return BDSKSetInstanceMethodImplementation(aClass, aSelector, anImp, NULL, BDSKReplaceOnly);
}

void BDSKAddInstanceMethodImplementation(Class aClass, SEL aSelector, IMP anImp, const char *types) {
    BDSKSetInstanceMethodImplementation(aClass, aSelector, anImp, types, BDSKAddOnly);
}

IMP BDSKReplaceInstanceMethodImplementationFromSelector(Class aClass, SEL aSelector, SEL impSelector) {
    return BDSKSetInstanceMethodImplementationFromSelector(aClass, aSelector, impSelector, BDSKReplaceOnly);
}

void BDSKAddInstanceMethodImplementationFromSelector(Class aClass, SEL aSelector, SEL impSelector) {
    BDSKSetInstanceMethodImplementationFromSelector(aClass, aSelector, impSelector, BDSKAddOnly);
}

void BDSKRequestConcreteImplementation(id self, SEL aSelector) {
    BDSKASSERT_NOT_REACHED("Concrete implementation needed");
    [NSException raise:BDSKAbstractImplementationException format:@"%@ needs a concrete implementation of %@%@", [self class], [self class] == self ? @"+" : @"-", NSStringFromSelector(aSelector)];
    exit(1);  // notreached, but needed to pacify the compiler
}

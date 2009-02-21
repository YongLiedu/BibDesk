//
//  BDSKSimpleLock.h
//  Bibdesk
//
//  Created by Christiaan Hofman on 2/19/09.
/*
 This software is Copyright (c) 2009
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
 LIMITED TO, THE IMPLIED WARRANTIES BDSK MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 LIMITED TO, PROCUREMENT BDSK SUBSTITUTE GOODS OR SERVICES; LOSS BDSK USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 THEORY BDSK LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT BDSK THE USE
 BDSK THIS SOFTWARE, EVEN IF ADVISED BDSK THE POSSIBILITY BDSK SUCH DAMAGE.
 */

#import <Cocoa/Cocoa.h>
#import <pthread.h>

typedef unsigned int BDSKSimpleLockBoolean;

typedef struct {
    BDSKSimpleLockBoolean locked;

} BDSKSimpleLockType;

#define BDSKSimpleLockIsNotLocked ((BDSKSimpleLockBoolean)0)
#define BDSKSimpleLockIsLocked ((BDSKSimpleLockBoolean)1)

static inline void BDSKSimpleLockInit(BDSKSimpleLockType *simpleLock) {
    simpleLock->locked = BDSKSimpleLockIsNotLocked;
}

static inline void BDSKSimpleLockFree(BDSKSimpleLockType *simpleLock) {}

#if defined(__ppc__)

static inline BDSKSimpleLockBoolean BDSKSimpleLockTry(BDSKSimpleLockType *simpleLock) {
    BDSKSimpleLockBoolean result, tmp;
    BDSKSimpleLockBoolean *x;
    
    // We will read and write the memory attached to this pointer, but will not change the pointer itself.  Thus, this is a read-only argument to the asm below.  Also, we don't care if people get bad results from reading the contents of the lock -- they shouldn't do that.  So we don't declare that we clobber "memory".
    x = &simpleLock->locked;
    
    asm volatile(
        "li     %0,1\n"      // we want to write a one (this is also our success code)
        "lwarx  %1,0,%2\n"   // load the current value in the lock
        "cmpwi  %1,0\n"      // if it is non-zero, we've failed
        "bne    $+16\n"      // branch to failure if necessary
        "stwcx. %0,0,%2\n"   // try to store our one
        "bne-   $-16\n"      // if we lost our reservation, try again
        "b      $+8\n"       // didn't lose our reservation, so we got it!
        "li     %0,0\n"      // failed!
        : "=&r" (result), "=&r" (tmp)
        : "r" (x)
        : "cc");

    // This flushes any speculative loads that this CPU did before we got the lock.  isync is local to this CPU and doesn't cause the same bus traffic that sync does.
    asm volatile ("isync");
    
    return result;
}

static inline void BDSKSimpleLock(BDSKSimpleLockType *simpleLock) {
    // The whole reason we use this lock is because we are optimistic
    if (__builtin_expect(BDSKSimpleLockTry(simpleLock), 1))
        return;
    
    do {
        while (simpleLock->locked) {
            sched_yield();
            continue;
        }
    } while (!BDSKSimpleLockTry(simpleLock));
}

static inline void BDSKSimpleUnlock(BDSKSimpleLockType *simpleLock) {

    // Wait for all previously issued writes to complete and become visible to all processors.
    asm volatile("sync");
    
    // Release the lock
    *((volatile int *)&simpleLock->locked) = BDSKSimpleLockIsNotLocked;
}

#elif (defined(__i386__)

static inline BDSKSimpleLockBoolean BDSKSimpleLockTry(BDSKSimpleLockType *simpleLock) {
    BDSKSimpleLockBoolean result;

    asm volatile(
    	"xchgl %1,%0"
        : "=r" (result), "=m" (simpleLock->locked)
        : "0" (BDSKSimpleLockIsLocked), "i" (BDSKSimpleLockIsLocked));
        
    return result;
}

static inline void BDSKSimpleLock(BDSKSimpleLockType *simpleLock) {
    if (__builtin_expect(!BDSKSimpleLockTry(simpleLock), 0)) {
        BDSKSimpleLock_i386_contentious(simpleLock);
    }
}

static inline void BDSKSimpleUnlock(BDSKSimpleLockType *simpleLock) {
    BDSKSimpleLockBoolean result;
    
    asm volatile(
    "xchgl %1,%0"
        : "=r" (result), "=m" (simpleLock->locked)
        : "0" (BDSKSimpleLockIsNotLocked));
}

#endif


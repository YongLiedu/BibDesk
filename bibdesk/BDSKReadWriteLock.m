//
//  BDSKReadWriteLock.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 2/22/09.
/*
 This software is Copyright (c) 2009-2010
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

#import "BDSKReadWriteLock.h"


@implementation BDSKReadWriteLock

- (id)init {
    if (self = [super init]) {
		pthread_rwlock_init(&rwlock, NULL);
    }
    return self;
}

- (void)dealloc {
    pthread_rwlock_destroy(&rwlock);
    [super dealloc];
}

- (void)lock {
    [self lockForWriting];
}

- (void)unlock {
    if (0 != pthread_rwlock_unlock(&rwlock))
        NSLog(@"failed to unlock rwlock");
}

- (void)lockForReading {
    if (0 != pthread_rwlock_rdlock(&rwlock))
        NSLog(@"failed to lock rwlock for reading");
}

- (void)lockForWriting {
    if (0 != pthread_rwlock_wrlock(&rwlock))
        NSLog(@"failed to lock rwlock for writing");
}

- (BOOL)tryLock {
    return [self tryLockForWriting];
}

- (BOOL)tryLockForReading {
    return 0 == pthread_rwlock_tryrdlock(&rwlock);
}

- (BOOL)tryLockForWriting {
    return 0 == pthread_rwlock_trywrlock(&rwlock);
}


@end

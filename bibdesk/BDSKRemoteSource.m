//
//  BDSKRemoteSource.m
//  Bibdesk
//
//  Created by Michael McCracken on 2/11/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "BDSKRemoteSource.h"


@implementation BDSKRemoteSource

// init
- (id)init {
    if (self = [super init]) {
        [self setName:nil];
        [self setData:nil];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:[self name] forKey:@"name"];
    [coder encodeObject:[self data] forKey:@"data"];
}

- (id)initWithCoder:(NSCoder *)coder {
    if (self = [super init]) {
        [self setName:[coder decodeObjectForKey:@"name"]];
        [self setData:[coder decodeObjectForKey:@"data"]];
    }
    return self;
}

- (NSString *)name { return [[name retain] autorelease]; }

- (void)setName:(NSString *)aName {
    //NSLog(@"in -setName:, old value of name: %@, changed to: %@", name, aName);
	
    [name release];
    name = [aName copy];
}

- (NSMutableDictionary *)data { return [[data retain] autorelease]; }

- (void)setData:(NSMutableDictionary *)aData {
    //NSLog(@"in -setData:, old value of data: %@, changed to: %@", data, aData);
	
    [data release];
    data = [aData copy];
}

- (NSView *)settingsView{
    [NSException raise:NSInternalInconsistencyException format:@"Must implement a complete subclass."];
    return nil;
}

- (void)dealloc {
    [name release];
    [data release];
    [super dealloc];
}

@end

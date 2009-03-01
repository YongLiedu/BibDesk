//
//  BDSKPasswordController.m
//  BibDesk
//
//  Created by Adam Maxwell on Sat Apr 1 2006.
//  Copyright (c) 2006 Adam R. Maxwell. All rights reserved.
/*
 This software is Copyright (c) 2006-2009
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


#import "BDSKPasswordController.h"
#import <Security/Security.h>
#import "BDSKSharingBrowser.h"
#import "BDSKSharingServer.h"
#import "NSData_BDSKExtensions.h"

NSString *BDSKServiceNameForKeychain = @"BibDesk Sharing";

@interface BDSKPasswordController (Private)
- (void)setName:(NSString *)aName;
- (void)setPassword:(NSString *)aName;
- (void)setStatus:(NSString *)status;
@end

@implementation BDSKPasswordController

- (void)awakeFromNib {
    [self setStatus:@""];
}

- (NSString *)windowNibName { return @"BDSKPasswordController"; }

- (void)dealloc {
    [self setName:nil];
    [self setPassword:nil];
    [super dealloc];
}

// convenience method for keychain
+ (NSData *)sharingPasswordForCurrentUserUnhashed {
    // find password from keychain
    OSStatus err;
    
    void *passwordData = NULL;
    UInt32 passwordLength = 0;
    NSData *data = nil;
    
    const char *serviceName = [BDSKServiceNameForKeychain UTF8String];
    const char *userName = [NSUserName() UTF8String];
    
    err = SecKeychainFindGenericPassword(NULL, strlen(serviceName), serviceName, strlen(userName), userName, &passwordLength, &passwordData, NULL);
    data = [NSData dataWithBytes:passwordData length:passwordLength];
    SecKeychainItemFreeContent(NULL, passwordData);
    
    return data;
}

+ (void)addOrModifyPassword:(NSString *)password name:(NSString *)name userName:(NSString *)userName {
    // default is to use current user's username
    const char *userNameCString = userName == nil ? [NSUserName() UTF8String] : [userName UTF8String];
    
    NSParameterAssert(name != nil);
    const char *nameCString = [name UTF8String];
    
    OSStatus err;
    SecKeychainItemRef itemRef = NULL;    
    const void *passwordData = NULL;
    UInt32 passwordLength = 0;
    
    // first see if the password exists in the keychain
    err = SecKeychainFindGenericPassword(NULL, strlen(nameCString), nameCString, strlen(userNameCString), userNameCString, &passwordLength, (void **)&passwordData, &itemRef);
    
    if(err == noErr){
        // password was on keychain, so flush the buffer and then modify the keychain
        SecKeychainItemFreeContent(NULL, (void *)passwordData);
        passwordData = NULL;
        
        passwordData = [password UTF8String];
        SecKeychainAttribute attrs[] = {
        { kSecAccountItemAttr, strlen(userNameCString), (char *)userNameCString },
        { kSecServiceItemAttr, strlen(nameCString), (char *)nameCString } };
        const SecKeychainAttributeList attributes = { sizeof(attrs) / sizeof(attrs[0]), attrs };
        
        err = SecKeychainItemModifyAttributesAndData(itemRef, &attributes, strlen(passwordData), passwordData);
    } else if(err == errSecItemNotFound){
        // password not on keychain, so add it
        passwordData = [password UTF8String];
        err = SecKeychainAddGenericPassword(NULL, strlen(nameCString), nameCString, strlen(userNameCString), userNameCString, strlen(passwordData), passwordData, &itemRef);    
    } else 
        NSLog(@"Error %d occurred setting password", err);
}

+ (NSData *)passwordHashedForKeychainServiceName:(NSString *)name {
    // use the service name to get password from keychain and hash it with sha1 for comparison purposes
    OSStatus err;
    
    const char *nameCString = [name UTF8String];
    void *password = NULL;
    UInt32 passwordLength = 0;
    NSData *pwData = nil;
    
    err = SecKeychainFindGenericPassword(NULL, strlen(nameCString), nameCString, 0, NULL, &passwordLength, &password, NULL);
    if(err == noErr){
        pwData = [NSData dataWithBytes:password length:passwordLength];
        SecKeychainItemFreeContent(NULL, password);
        
        // hash it for comparison, since we hash before putting it in the TXT
        pwData = [pwData sha1Signature];
    }
    return pwData;
}

+ (NSString *)keychainServiceNameWithComputerName:(NSString *)computerName {
    return [NSString stringWithFormat:@"%@ - %@", computerName, BDSKServiceNameForKeychain];
}

- (void)setName:(NSString *)aName {
    if(name != aName){
        [name release];
        name = [aName retain];
    }
}

- (void)setStatus:(NSString *)status {  
    [self window]; // load window before setStatus
    [statusField setStringValue:status];
}

- (NSString *)password {
    return password;
}

- (NSData *)passwordHashed {
    // is this equivalent to dataUsingEncoding?
    const void *passwordBytes = [[self password] UTF8String];
    return [[NSData dataWithBytes:passwordBytes length:strlen(passwordBytes)] sha1Signature];
}

- (void)setPassword:(NSString *)aPassword {
    if(password != aPassword){
        [password release];
        password = [aPassword retain];
    }
}

- (BDSKPasswordControllerStatus)runModalForKeychainServiceName:(NSString *)aName message:(NSString *)status {
    [self setName:aName];    
    [self setStatus:status ?: @""];
    int returnValue = [NSApp runModalForWindow:[self window]];
    [[self window] orderOut:self];    
    
    return returnValue;
}

- (IBAction)buttonAction:(id)sender
{    
    int returnValue = [sender tag];
    if (returnValue == BDSKPasswordReturn) {
        NSAssert(name != nil, @"name is nil");
        
        [self setPassword:[passwordField stringValue]];
        NSParameterAssert([self password] != nil);
        
        [BDSKPasswordController addOrModifyPassword:password name:name userName:nil];
    }
    [NSApp stopModalWithCode:returnValue];
}

@end

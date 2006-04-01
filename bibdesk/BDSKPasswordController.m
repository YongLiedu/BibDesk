#import "BDSKPasswordController.h"
#import <Security/Security.h>
#import "BibDocument_Sharing.h"

@implementation BDSKPasswordController

- (void)dealloc
{
    [self setService:nil];
    [super dealloc];
}

- (void)setService:(id)aService;
{
    if(service != aService){
        [service release];
        service = [aService retain];
    }
}

- (int)runModalForService:(id)aService;
{
    [self setService:aService];    
    [NSApp runModalForWindow:[self window]];    
    [self setService:nil];
    
    return returnValue;
}

- (NSString *)windowNibName { return @"BDSKPasswordController"; }

- (IBAction)changePassword:(id)sender
{
    NSAssert(service != nil, @"net service is nil");
    NSAssert([service name] != nil, @"tried to set password for unresolved service");
    
    const void *passwordData = NULL;
    SecKeychainItemRef itemRef = NULL;    
    const char *userName = [NSUserName() UTF8String];
    OSStatus err;
    
    NSData *TXTData = [service TXTRecordData];
    NSDictionary *dictionary = nil;
    if(TXTData)
        dictionary = [NSNetService dictionaryFromTXTRecordData:TXTData];
    TXTData = [dictionary objectForKey:[BibDocument TXTKeyForComputerName]];
    const char *serverName = [TXTData bytes];
    UInt32 serverNameLength = [TXTData length];
    NSAssert([TXTData length], @"no computer name in TXT record");
    
    NSString *password = [passwordField stringValue];
    NSParameterAssert(password != nil);

    UInt32 passwordLength = 0;
    err = SecKeychainFindGenericPassword(NULL, serverNameLength, serverName, strlen(userName), userName, &passwordLength, (void **)&passwordData, &itemRef);
    
    if(err == noErr){
        // password was on keychain, so flush the buffer and then modify the keychain
        SecKeychainItemFreeContent(NULL, (void *)passwordData);
        passwordData = NULL;
    
        passwordData = [password UTF8String];
        SecKeychainAttribute attrs[] = {
        { kSecAccountItemAttr, strlen(userName), (char *)userName },
        { kSecServiceItemAttr, serverNameLength, (char *)serverName } };
        const SecKeychainAttributeList attributes = { sizeof(attrs) / sizeof(attrs[0]), attrs };
        
        err = SecKeychainItemModifyAttributesAndData(itemRef, &attributes, strlen(passwordData), passwordData);
    } else if(err == errSecItemNotFound){
        // password not on keychain, so add it
        passwordData = [password UTF8String];
        err = SecKeychainAddGenericPassword(NULL, serverNameLength, serverName, strlen(userName), userName, strlen(passwordData), passwordData, &itemRef);    
    } else 
        NSLog(@"Error %d occurred setting password", err);
}

- (IBAction)buttonAction:(id)sender
{    
    int tag = [sender tag];
    if(tag == 0)
        returnValue = 1;

    if(tag == 1)
        returnValue = 0;
    
    // this is the only way out of the modal session
    [NSApp stopModal];
}

@end

//
//  BDSKAppDelegate.m
//  BibDesk
//
//  Created by Colin A. Smith on 3/3/12.
/*
 This software is Copyright (c) 2012-2012
 Colin A. Smith. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Colin A. Smith nor the names of any
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

#import "BDSKAppDelegate.h"

#import "BDSKDropboxStore.h"

@interface BDSKAppDelegate () {
    NSString *relinkUserId;
    BOOL _dropboxLinked;
}

- (void)setDropboxLinked:(BOOL)linked;

@end

@implementation BDSKAppDelegate

@synthesize window = _window;

- (void)dealloc
{
    [_window release];
    [super dealloc];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.

    // Set these variables before launching the app
    NSString* appKey = @"eq4q5w8c3389t6u";
    NSString* appSecret = @"ezbmorda4ycilxx";
    NSString *root = kDBRootAppFolder; // Should be set to either kDBRootAppFolder or kDBRootDropbox
    
    DBSession* session = 
        [[DBSession alloc] initWithAppKey:appKey appSecret:appSecret root:root];
    session.delegate = self; // DBSessionDelegate methods allow you to handle re-authenticating
    [DBSession setSharedSession:session];
    [session release];
    
    [[BDSKDropboxStore sharedStore] addLocalFiles];
    
    _dropboxLinked = [[DBSession sharedSession] isLinked];
    
    if (self.dropboxLinked) {
        [[BDSKDropboxStore sharedStore] startSync];
    }
    
    NSDictionary *defaults = [NSDictionary dictionaryWithObjectsAndKeys:@",:;", @"BDSKGroupFieldSeparatorCharactersKey", nil];
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
        
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;
        UINavigationController *navigationController = [splitViewController.viewControllers lastObject];
        splitViewController.delegate = (id)navigationController.topViewController;
    }
    
    return YES;
}

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
    if ([[DBSession sharedSession] handleOpenURL:url]) {
        [self setDropboxLinked:[[DBSession sharedSession] isLinked]];
        if (self.dropboxLinked) {
            [[BDSKDropboxStore sharedStore] startSync];
        }
        return YES;
    }
    
    return NO;
}

- (BOOL)dropboxLinked {

    return _dropboxLinked;
}

- (void)setDropboxLinked:(BOOL)linked {

    if (linked != _dropboxLinked) {
        [self willChangeValueForKey:@"dropboxLinked"];
        _dropboxLinked = linked;
        [self didChangeValueForKey:@"dropboxLinked"];
    }
}

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)theKey {
 
    BOOL automatic = NO;
    if ([theKey isEqualToString:@"dropboxLinked"]) {
        automatic = NO;
    } else {
        automatic = [super automaticallyNotifiesObserversForKey:theKey];
    }
    return automatic;
}

- (void)toggleDropboxLink {

    if (!self.dropboxLinked) {
        [[DBSession sharedSession] link];
    } else {
            [[DBSession sharedSession] unlinkAll];
            [[[[UIAlertView alloc] 
                 initWithTitle:@"Account Unlinked!" message:@"Your dropbox account has been unlinked" 
                 delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil]
                autorelease]
             show];
        
        [self setDropboxLinked:NO];
    }
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

#pragma mark -
#pragma mark DBSessionDelegate methods

- (void)sessionDidReceiveAuthorizationFailure:(DBSession*)session userId:(NSString *)userId {
    relinkUserId = [userId retain];
    [[[[UIAlertView alloc] 
       initWithTitle:@"Dropbox Session Ended" message:@"Do you want to relink?" delegate:self 
       cancelButtonTitle:@"Cancel" otherButtonTitles:@"Relink", nil]
      autorelease]
     show];
    
    [self setDropboxLinked:NO];
}


#pragma mark -
#pragma mark UIAlertViewDelegate methods

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)index {
    if (index != alertView.cancelButtonIndex) {
        [[DBSession sharedSession] linkUserId:relinkUserId];
    }
    [relinkUserId release];
    relinkUserId = nil;
}


@end

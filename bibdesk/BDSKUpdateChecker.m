//
//  BDSKUpdateChecker.m
//  Bibdesk
//
//  Created by Adam Maxwell on 10/11/06.
/*
 This software is Copyright (c) 2006
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

#import "BDSKUpdateChecker.h"
#import "BDSKReadMeController.h"
#import "NSError_BDSKExtensions.h"

@interface BDSKUpdateChecker (Private)

- (NSURL *)propertyListURL;
- (void)handleUpdateIntervalChanged:(NSNotification *)note;
- (void)setUpdateTimer:(NSTimer *)aTimer;
- (OFVersionNumber *)localVersionNumber;
- (NSURL *)releaseNotesURL;
- (NSString *)keyForCurrentMajorVersion;
- (BOOL)downloadPropertyListFromServer:(NSError **)error;
- (OFVersionNumber *)latestReleasedVersionNumber;
- (CFGregorianUnits)updateCheckGregorianUnits;
- (NSTimeInterval)updateCheckTimeInterval;
- (NSDate *)nextUpdateCheckDate;
- (BOOL)checkForNetworkAvailability:(NSError **)error;
- (void)checkForUpdatesInBackground:(NSTimer *)timer;
- (void)checkForUpdatesInBackground;
- (void)displayUpdateAvailableWindow:(NSString *)latestVersionNumber;

@end

static id sharedInstance = nil;

@implementation BDSKUpdateChecker

+ (id)sharedChecker;
{
    if (nil == sharedInstance)
        sharedInstance = [[self alloc] init];
    return sharedInstance;
}

- (id)init
{
    if (self = [super init]) {
        plistLock = [[NSLock alloc] init];
        propertyListFromServer = nil;
        updateTimer = nil;
        [OFPreference addObserver:self 
                         selector:@selector(handleUpdateIntervalChanged:) 
                    forPreference:[OFPreference preferenceForKey:BDSKUpdateCheckIntervalKey]];
    }
    return self;
}

- (void)dealloc
{
    [OFPreference removeObserver:self forPreference:nil];
    
    // these objects are only accessed from the main thread
    [releaseNotesWindowController release];
    [self setUpdateTimer:nil];

    // propertyListFromServer is currently the only object shared between threads
    [plistLock lock];
    [propertyListFromServer release];
    propertyListFromServer = nil;
    [plistLock unlock];
    [plistLock release];
    plistLock = nil;
    
    [super dealloc];
}

- (void)scheduleUpdateCheckIfNeeded;
{
    // unschedule any current timers
    [self setUpdateTimer:nil];

    // don't schedule a new timer if updateCheckInterval is zero
    if ([self updateCheckTimeInterval] > 0) {
        
        NSDate *nextCheckDate = [self nextUpdateCheckDate];
        
        // if the date is past, check immediately
        if ([nextCheckDate timeIntervalSinceNow] <= 0) {
            [self checkForUpdatesInBackground:nil];
            
        } else {
            
            // timer will be invalidated after it fires
            NSTimer *timer = [[NSTimer alloc] initWithFireDate:nextCheckDate 
                                                      interval:[self updateCheckTimeInterval] 
                                                        target:self 
                                                      selector:@selector(checkForUpdatesInBackground:) 
                                                      userInfo:nil repeats:NO];
            
            [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
            [self setUpdateTimer:timer];
            [timer release];
        }
    }
}

- (IBAction)checkForUpdates:(id)sender;
{    
    // reset date of last check and reschedule the timer
    [[OFPreferenceWrapper sharedPreferenceWrapper] setObject:[[NSDate date] description] forKey:BDSKUpdateCheckLastDateKey];
    [self scheduleUpdateCheckIfNeeded];

    // check for network availability and display a warning if it's down
    NSError *error = nil;
    if([self checkForNetworkAvailability:&error] == NO || [self downloadPropertyListFromServer:&error] == NO) {
        
        // display a warning based on the error and bail out now
        [NSApp presentError:error];
        return;
    }
    
    OFVersionNumber *remoteVersion = [self latestReleasedVersionNumber];
    
    if (nil != remoteVersion) {
        
        if([remoteVersion compareToVersionNumber:[self localVersionNumber]] == NSOrderedDescending){
            [self displayUpdateAvailableWindow:[remoteVersion cleanVersionString]];
        } else {
            // tell user software is up to date
            NSRunAlertPanel(NSLocalizedString(@"BibDesk is up to date", @"Title of alert when a the user's software is up to date."),
                            NSLocalizedString(@"You have the most recent version of BibDesk.", @"Alert text when the user's software is up to date."),
                            nil, nil, nil);                
        }
    } else {
        
        // likely an error page or other download failure
        [NSApp presentError:error];
    }
    
}

@end

@implementation BDSKUpdateChecker (Private)

- (void)handleUpdateIntervalChanged:(NSNotification *)note;
{
    [self scheduleUpdateCheckIfNeeded];
}

- (void)setUpdateTimer:(NSTimer *)aTimer;
{
    if (updateTimer != aTimer) {
        [updateTimer invalidate];
        [updateTimer release];
        updateTimer = [aTimer retain];
    }
}

- (NSURL *)propertyListURL;
{
    return [NSURL URLWithString:@"http://bibdesk.sourceforge.net/bibdesk-versions-xml.txt"];
}

// we assume this is only called /after/ a successful plist download; if not, it returns nil
- (NSURL *)releaseNotesURL;
{
    [plistLock lock];
    NSString *URLString = [[[[propertyListFromServer objectForKey:[self keyForCurrentMajorVersion]] objectForKey:@"ReleaseNotesBaseURL"] copy] autorelease];
    [plistLock unlock];
    
    NSString *resourcePath = [[NSBundle mainBundle] pathForResource:@"RelNotes" ofType:@"rtf"];
    
    // should be e.g. English.lproj
    NSString *localizationPath = [[resourcePath stringByDeletingLastPathComponent] lastPathComponent];
    URLString = [URLString stringByAppendingPathComponent:localizationPath];
    URLString = [URLString stringByAppendingPathComponent:@"RelNotes.rtf"];
    
    return [NSURL URLWithString:URLString];
}

// string of the form BibDesk1.3 for BibDesk 1.3.x; update check info is keyed to a specific branch of development
- (NSString *)keyForCurrentMajorVersion;
{
    OFVersionNumber *localVersion = [self localVersionNumber];
    NSAssert([localVersion componentCount] == 3, @"expect 3 version components");
    return [NSString stringWithFormat:@"%@%d.%d", @"BibDesk", [localVersion componentAtIndex:0], [localVersion componentAtIndex:1]];
}

- (BOOL)downloadPropertyListFromServer:(NSError **)error;
{
    NSError *downloadError = nil;
    
    // make sure we ignore the cache policy; use default timeout of 60 seconds
    NSURLRequest *request = [NSURLRequest requestWithURL:[self propertyListURL] cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:60.0];
    NSURLResponse *response;
    
    // load it synchronously; either the user requested this on the main thread, or this is the update thread
    NSData *theData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&downloadError];
    NSDictionary *versionDictionary = nil;
    BOOL success;
    
    if(nil != theData){
        NSString *err = nil;
        versionDictionary = [NSPropertyListSerialization propertyListFromData:(NSData *)theData
                                                             mutabilityOption:NSPropertyListImmutable
                                                                       format:NULL
                                                             errorDescription:&err];
        if(nil == versionDictionary){
            if (error) {
                *error = [NSError mutableLocalErrorWithCode:kBDSKPropertyListDeserializationFailed localizedDescription:NSLocalizedString(@"Unable to read the version number from the server", @"")];
                [*error setValue:err forKey:NSLocalizedRecoverySuggestionErrorKey];
                // add the parsing error as underlying error, if the retrieval actually succeeded
                [*error embedError:downloadError];
            }
            [err release];
            
            // see if we have a web server error page and log it to the console; NSUnderlyingErrorKey has \n literals when logged
            NSAttributedString *attrString = [[NSAttributedString alloc] initWithHTML:theData documentAttributes:NULL];
            if ([NSString isEmptyString:[attrString string]] == NO)
                NSLog(@"retrieved HTML data instead of property list: \n\"%@\"", [attrString string]);
            [attrString release];
        } else {
            success = YES;
        }
    } else {
        if(error) *error = downloadError;
        success = NO;
    }    
    
    // will set to nil if failure
    [plistLock lock];
    [propertyListFromServer release];
    propertyListFromServer = [versionDictionary copy];
    [plistLock unlock];
    
    return success;
}

- (OFVersionNumber *)latestReleasedVersionNumber;
{
    [plistLock lock];
    NSDictionary *thisBranchDictionary = [[[propertyListFromServer objectForKey:[self keyForCurrentMajorVersion]] copy] autorelease];
    [plistLock unlock];
    return thisBranchDictionary ? [[[OFVersionNumber alloc] initWithVersionString:[thisBranchDictionary valueForKey:@"LatestVersion"]] autorelease] : nil;
}

// returns the update check granularity
- (CFGregorianUnits)updateCheckGregorianUnits;
{
    BDSKUpdateCheckInterval intervalType = [[OFPreferenceWrapper sharedPreferenceWrapper] integerForKey:BDSKUpdateCheckIntervalKey];
    
    CFGregorianUnits dateUnits = { 0, 0, 0, 0, 0, 0 };
    
    if (BDSKCheckForUpdatesHourly == intervalType)
        dateUnits.hours = 1;
    else if (BDSKCheckForUpdatesDaily == intervalType)
        dateUnits.days = 1;
    else if (BDSKCheckForUpdatesWeekly == intervalType)
        dateUnits.days = 7;
    else if (BDSKCheckForUpdatesMonthly == intervalType)
        dateUnits.months = 1;
    
    return dateUnits;
}

// returns the time in seconds between update checks (converts the CFGregorianUnits to seconds)
// a zero interval indicates that automatic update checking should not be performed
- (NSTimeInterval)updateCheckTimeInterval;
{    
    CFAbsoluteTime time = 0;
    return (NSTimeInterval)CFAbsoluteTimeAddGregorianUnits(time, NULL, [self updateCheckGregorianUnits]);
}

// returns UTC date of next update check
- (NSDate *)nextUpdateCheckDate;
{
    NSDate *lastCheck = [NSDate dateWithString:[[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKUpdateCheckLastDateKey]];    
    
    // if nil, return a date in the past
    if (nil == lastCheck)
        lastCheck = [NSDate distantPast];
    
    CFAbsoluteTime lastCheckTime = CFDateGetAbsoluteTime((CFDateRef)lastCheck);
    
    // use GMT everywhere
    CFAbsoluteTime nextCheckTime = CFAbsoluteTimeAddGregorianUnits(lastCheckTime, NULL, [self updateCheckGregorianUnits]);
    
    return [(id)CFDateCreate(CFAllocatorGetDefault(), nextCheckTime) autorelease];
}

- (void)checkForUpdatesInBackground:(NSTimer *)timer;
{
    [NSThread detachNewThreadSelector:@selector(checkForUpdatesInBackground) toTarget:self withObject:nil];
    
    // set the current date as the date of the last update check
    [[OFPreferenceWrapper sharedPreferenceWrapper] setObject:[[NSDate date] description] forKey:BDSKUpdateCheckLastDateKey];
    [self scheduleUpdateCheckIfNeeded];
}

- (BOOL)attemptRecoveryFromError:(NSError *)error optionIndex:(unsigned int)recoveryOptionIndex;
{
    BOOL didRecover = NO;
    
    // we only receive this for a single error at present
    if ([error isLocalError] && [error code] == kBDSKNetworkConnectionFailed) {
        if (0 == recoveryOptionIndex) {
            // ignore
            didRecover = NO;
            
        } else if (1 == recoveryOptionIndex) {
            // diagnose
            CFURLRef theURL = (CFURLRef)[self propertyListURL];
            CFNetDiagnosticRef diagnostic = CFNetDiagnosticCreateWithURL(CFGetAllocator(theURL), theURL);
            CFNetDiagnosticStatus status = CFNetDiagnosticDiagnoseProblemInteractively(diagnostic);
            CFRelease(diagnostic);
            didRecover = (status == kCFNetDiagnosticNoErr);
            
        } else if (2 == recoveryOptionIndex) {
            // open console
            didRecover = [[NSWorkspace sharedWorkspace] launchAppWithBundleIdentifier:@"com.apple.console" options:0 additionalEventParamDescriptor:nil launchIdentifier:NULL];
        }
    } else {
        didRecover = NO;
    }
    
    return didRecover;
}

- (BOOL)checkForNetworkAvailability:(NSError **)error;
{
    CFURLRef theURL = (CFURLRef)[self propertyListURL];
    CFNetDiagnosticRef diagnostic = CFNetDiagnosticCreateWithURL(CFGetAllocator(theURL), theURL);
    
    NSString *details;
    CFNetDiagnosticStatus status = CFNetDiagnosticCopyNetworkStatusPassively(diagnostic, (CFStringRef *)&details);
    CFRelease(diagnostic);
    [details autorelease];
    
    BOOL success;
    
    if (kCFNetDiagnosticConnectionUp == status) {
        success = YES;
    } else {
        if (nil == details) details = NSLocalizedString(@"Unknown network error", @"");
        
        // This error contains all the information needed for NSErrorRecoveryAttempting.  
        // Note that buttons in the alert will be ordered right-to-left {0, 1, 2} and correspond to objects in the NSLocalizedRecoveryOptionsErrorKey array.
        if (error) {
            *error = [NSError mutableLocalErrorWithCode:kBDSKNetworkConnectionFailed localizedDescription:details];
            [*error setValue:self forKey:NSRecoveryAttempterErrorKey];
            [*error setValue:NSLocalizedString(@"Would you like to ignore this problem or attempt to diagnose it?  You may also open the Console log to check for errors.", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];
            [*error setValue:[NSArray arrayWithObjects:NSLocalizedString(@"Ignore", @""), NSLocalizedString(@"Diagnose", @""), NSLocalizedString(@"Open Console", @""), nil] forKey:NSLocalizedRecoveryOptionsErrorKey];
        }
        success = NO;
    }
    
    return success;
}

- (OFVersionNumber *)localVersionNumber;
{
    NSString *currVersionNumber = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    OFVersionNumber *localVersion = [[[OFVersionNumber alloc] initWithVersionString:currVersionNumber] autorelease];
    return localVersion;
}

- (void)checkForUpdatesInBackground;
{
    // sanity check so we don't spawn dozens of threads
    static int numberOfConcurrentChecks = 0;

    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    numberOfConcurrentChecks++;
    
    // don't bother displaying network availability warnings for an automatic check
    if([self checkForNetworkAvailability:NULL] == NO || numberOfConcurrentChecks > 1){
        numberOfConcurrentChecks--;
        [pool release];
        return;
    }
    
    NSError *error = nil;
    
    // make sure our plist is current
    [self downloadPropertyListFromServer:&error];
    
    OFVersionNumber *remoteVersion = [self latestReleasedVersionNumber];
    
    if(remoteVersion && [remoteVersion compareToVersionNumber:[self localVersionNumber]] == NSOrderedDescending){
        [[OFMessageQueue mainQueue] queueSelector:@selector(displayUpdateAvailableWindow:) forObject:self withObject:[remoteVersion cleanVersionString]];
        
    } else if(nil == remoteVersion && nil != error){
        // was showing an alert for this, but apparently it's really common for the check to fail
        NSLog(@"%@", [error description]);
    }
    [pool release];
    numberOfConcurrentChecks--;
}

- (void)downloadAndDisplayReleaseNotes;
{
    NSURL *theURL = [self releaseNotesURL];
    NSURLRequest *request = [NSURLRequest requestWithURL:theURL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:60.0];
    NSURLResponse *response;
    
    NSError *downloadError;
    
    // load it synchronously; user requested this on the main thread
    NSData *theData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&downloadError];
    
    // @@ use error description for message or display alert?
    // @@ option for user to d/l latest version when displaying this window?
    NSAttributedString *attrString;
    if (theData)
        attrString = [[[NSAttributedString alloc] initWithRTF:theData documentAttributes:NULL] autorelease];
    else
        attrString = [[[NSAttributedString alloc] initWithString:NSLocalizedString(@"Download Failed", @"") attributeName:NSForegroundColorAttributeName attributeValue:[NSColor redColor]] autorelease];
    
    if (nil == releaseNotesWindowController)
        releaseNotesWindowController = [[BDSKReadMeController alloc] initWithWindowNibName:@"ReadMe"];
    
    [releaseNotesWindowController setWindowTitle:NSLocalizedString(@"Latest Release Notes", @"")];
    [releaseNotesWindowController displayAttributedString:attrString];
    [releaseNotesWindowController showWindow:nil];
}

- (void)displayUpdateAvailableWindow:(NSString *)latestVersionNumber;
{
    int button;
    button = NSRunAlertPanel(NSLocalizedString(@"A New Version is Available", @"Alert when new version is available"),
                             NSLocalizedString(@"A new version of BibDesk is available (version %@). Would you like to download the new version now?", @"format string asking if the user would like to get the new version"),
                             NSLocalizedString(@"Download", @""), NSLocalizedString(@"View Release Notes", @"button title"), NSLocalizedString(@"Ignore",@"Ignore"), latestVersionNumber, nil);
    if (button == NSAlertDefaultReturn) {
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://bibdesk.sourceforge.net/"]];
    } else if (button == NSAlertAlternateReturn) {
        [self downloadAndDisplayReleaseNotes];
    }
    
}

@end

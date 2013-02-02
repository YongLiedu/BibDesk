// Copyright 2004-2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease_2007-10-25/OmniGroup/Frameworks/OmniAppKit/OAController.h 93428 2007-10-25 16:36:11Z kc $

#import <OmniFoundation/OFController.h>

@class OAAboutPanelController;

#import <AppKit/NSNibDeclarations.h> // For IBAction and IBOutlet

@interface OAController : OFController
{
    OAAboutPanelController *aboutPanelController;
}

- (OAAboutPanelController *)aboutPanelController;

- (IBAction)showAboutPanel:(id)sender;
- (IBAction)hideAboutPanel:(id)sender;
- (IBAction)sendFeedback:(id)sender;

- (void)getFeedbackAddress:(NSString **)feedbackAddress andSubject:(NSString **)subjectLine;
- (void)sendFeedbackEmailTo:(NSString *)feedbackAddress subject:(NSString *)subjectLine body:(NSString *)body;
- (void)sendFeedbackEmailWithBody:(NSString *)body;

@end

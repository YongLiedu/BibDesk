// BibPref_TeX.m
// BibDesk
// Created by Michael McCracken, 2002
/*
 This software is Copyright (c) 2002-2010
 Michael O. McCracken. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Michael O. McCracken nor the names of any
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

#import "BibPref_TeX.h"
#import "BDSKStringConstants.h"
#import "BDSKAppController.h"
#import "BDSKStringEncodingManager.h"
#import "BDSKPreviewer.h"
#import "NSFileManager_BDSKExtensions.h"
#import "NSWindowController_BDSKExtensions.h"
#import "BDSKShellCommandFormatter.h"
#import "BDSKStringConstants.h"
#import "BDSKPreferenceController.h"

#define BDSK_TEX_DOWNLOAD_URL @"http://tug.org/mactex/"

static NSSet *standardStyles = nil;


@interface BibPref_TeX (Private)
- (void)updateTeXPathUI;
- (void)updateBibTeXPathUI;
@end


@implementation BibPref_TeX

+ (void)initialize{
    BDSKINITIALIZE;
    // contents of /usr/local/gwTeX/texmf.texlive/bibtex/bst/base
    standardStyles = [[NSSet alloc] initWithObjects:@"abbrv", @"acm", @"alpha", @"apalike", @"ieeetr", @"plain", @"siam", @"unsrt", nil];
}

- (void)updateUI {
    [self updateTeXPathUI];
    [self updateBibTeXPathUI];
    
    [usesTeXButton setState:[sud boolForKey:BDSKUsesTeXKey] ? NSOnState : NSOffState];
  
    [bibTeXStyleField setStringValue:[sud objectForKey:BDSKBTStyleKey]];
    [bibTeXStyleField setEnabled:[sud boolForKey:BDSKUsesTeXKey]];
    [encodingPopUpButton setEncoding:[sud integerForKey:BDSKTeXPreviewFileEncodingKey]];
}

- (void)awakeFromNib{
    BDSKShellCommandFormatter *formatter = [[BDSKShellCommandFormatter alloc] init];
    [texBinaryPathField setFormatter:formatter];
    [texBinaryPathField setDelegate:self];
    [bibtexBinaryPathField setFormatter:formatter];
    [bibtexBinaryPathField setDelegate:self];
    [formatter release];
    
    [self updateUI];
}

- (void)updateTeXPathUI{
    NSString *teXPath = [sud objectForKey:BDSKTeXBinPathKey];
    [texBinaryPathField setStringValue:teXPath];
    if ([BDSKShellCommandFormatter isValidExecutableCommand:teXPath])
        [texBinaryPathField setTextColor:[NSColor blackColor]];
    else
        [texBinaryPathField setTextColor:[NSColor redColor]];
}

- (void)defaultsDidRevert {
    // reset UI, but only if we loaded the nib
    if ([self isViewLoaded]) {
         [self updateUI];
    }
}

- (void)updateBibTeXPathUI{
    NSString *bibTeXPath = [sud objectForKey:BDSKBibTeXBinPathKey];
    [bibtexBinaryPathField setStringValue:bibTeXPath];
    if ([BDSKShellCommandFormatter isValidExecutableCommand:bibTeXPath])
        [bibtexBinaryPathField setTextColor:[NSColor blackColor]];
    else
        [bibtexBinaryPathField setTextColor:[NSColor redColor]];
}

-(IBAction)changeTexBinPath:(id)sender{
    [sud setObject:[sender stringValue] forKey:BDSKTeXBinPathKey];
    [self updateTeXPathUI];
}

- (IBAction)changeBibTexBinPath:(id)sender{
    [sud setObject:[sender stringValue] forKey:BDSKBibTeXBinPathKey];
    [self updateBibTeXPathUI];
}

- (IBAction)changeUsesTeX:(id)sender{
    if ([sender state] == NSOffState) {		
        [sud setBool:NO forKey:BDSKUsesTeXKey];
		
		// hide preview panel if necessary
		[[BDSKPreviewer sharedPreviewer] hideWindow:self];
    }else{
        [sud setBool:YES forKey:BDSKUsesTeXKey];
    }
    [bibTeXStyleField setEnabled:[sud boolForKey:BDSKUsesTeXKey]];
}

- (BOOL)control:(NSControl *)control didFailToFormatString:(NSString *)string errorDescription:(NSString *)error
{
    NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Invalid Path",@"Message in alert dialog when binary path for TeX preview is invalid")
                                     defaultButton:nil
                                   alternateButton:nil
                                       otherButton:nil
                         informativeTextWithFormat:@"%@", error];
    [alert beginSheetModalForWindow:[[self view] window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
        
    // allow the user to end editing and ignore the warning, since TeX may not be installed
    return YES;
}

- (void)styleAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo{
    NSString *newStyle = [(id)contextInfo autorelease];
    if (NSAlertDefaultReturn == returnCode) {
        [sud setObject:newStyle forKey:BDSKBTStyleKey];
    } else if (NSAlertAlternateReturn == returnCode) {
        [bibTeXStyleField setStringValue:[sud objectForKey:BDSKBTStyleKey]];
    } else {
        [self openTeXPreviewFile:self];
    }
}

- (BOOL)alertShowHelp:(NSAlert *)alert;
{
    [preferenceController showHelp:nil];
    return YES;
}

- (IBAction)changeStyle:(id)sender{
    NSString *newStyle = [sender stringValue];
    NSString *oldStyle = [sud stringForKey:BDSKBTStyleKey];
    if ([newStyle isEqualToString:oldStyle] == NO) {
        if ([standardStyles containsObject:newStyle]){
            [sud setObject:[sender stringValue] forKey:BDSKBTStyleKey];
        } else {
            NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"This is a not a standard BibTeX style", @"Message in alert dialog")
                                             defaultButton:NSLocalizedString(@"Use Anyway", @"Button title")
                                           alternateButton:NSLocalizedString(@"Use Previous", @"Button title")
                                               otherButton:NSLocalizedString(@"Edit TeX template", @"Button title")
                                 informativeTextWithFormat:NSLocalizedString(@"This style is not one of the standard 8 BibTeX styles.  As such, it may require editing the TeX template manually to add necessary \\usepackage commands.", @"Informative text in alert dialog")];
            // for the help delegate method
            [alert setShowsHelp:YES];
            [alert setDelegate:self];
            [alert beginSheetModalForWindow:[[self view] window]
                              modalDelegate:self
                             didEndSelector:@selector(styleAlertDidEnd:returnCode:contextInfo:)
                                contextInfo:[newStyle copy]];
        }
    }
}

- (void)openTemplateFailureSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode path:(void *)path{
    [(id)path autorelease];
    if(returnCode == NSAlertDefaultReturn)
        [[NSWorkspace sharedWorkspace] selectFile:path inFileViewerRootedAtPath:@""];
}

- (IBAction)openTeXPreviewFile:(id)sender{
    // Edit the TeX template in the Application Support folder
    NSString *applicationSupportPath = [[NSFileManager defaultManager] currentApplicationSupportPathForCurrentUser];
    
    // edit the previewtemplate.tex file, so the bibpreview.tex is only edited by PDFPreviewer
    NSString *path = [applicationSupportPath stringByAppendingPathComponent:@"previewtemplate.tex"];
    NSURL *url = nil;
    
    if([[NSFileManager defaultManager] fileExistsAtPath:path] == NO)
        [self resetTeXPreviewFile:nil];

    url = [NSURL fileURLWithPath:path];
    
    if([[NSWorkspace sharedWorkspace] openURL:url] == NO && [[NSWorkspace sharedWorkspace] openURLs:[NSArray arrayWithObject:url] withAppBundleIdentifier:@"com.apple.textedit" options:0 additionalEventParamDescriptor:nil launchIdentifiers:NULL] == NO) {
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Unable to Open File", @"Message in alert dialog when unable to open file")
                                         defaultButton:NSLocalizedString(@"Reveal", @"Button title")
                                       alternateButton:NSLocalizedString(@"Cancel", @"Button title")
                                           otherButton:nil
                             informativeTextWithFormat:NSLocalizedString(@"The system was unable to find an application to open the TeX template file.  Choose \"Reveal\" to show the template in the Finder.", @"Informative text in alert dialog")];
        [alert beginSheetModalForWindow:[[self view] window]
                          modalDelegate:self
                         didEndSelector:@selector(openTemplateFailureSheetDidEnd:returnCode:path:)
                            contextInfo:[[url path] retain]];
    }
}

- (void)alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo{
    if (returnCode == NSAlertAlternateReturn)
        return;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *applicationSupportPath = [[NSFileManager defaultManager] currentApplicationSupportPathForCurrentUser];
    NSString *previewTemplatePath = [applicationSupportPath stringByAppendingPathComponent:@"previewtemplate.tex"];
    if([fileManager fileExistsAtPath:previewTemplatePath])
        [fileManager removeItemAtPath:previewTemplatePath error:NULL];
    // copy previewtemplate.tex file from the bundle
    [fileManager copyItemAtPath:[[[NSBundle mainBundle] sharedSupportPath] stringByAppendingPathComponent:@"previewtemplate.tex"]
                   toPath:previewTemplatePath error:NULL];
}

- (IBAction)resetTeXPreviewFile:(id)sender{
	NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Reset TeX template to its original value?", @"Message in alert dialog when resetting preview TeX template file") 
									 defaultButton:NSLocalizedString(@"OK", @"Button title") 
								   alternateButton:NSLocalizedString(@"Cancel", @"Button title") 
									   otherButton:nil 
						 informativeTextWithFormat:NSLocalizedString(@"Choosing Reset will revert the TeX template file to its original content.", @"Informative text in alert dialog")];
	[alert beginSheetModalForWindow:[[self view] window] 
					  modalDelegate:self
					 didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) 
						contextInfo:NULL];
}

- (IBAction)downloadTeX:(id)sender {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:BDSK_TEX_DOWNLOAD_URL]];
}

- (IBAction)changeDefaultTeXEncoding:(id)sender{
    [sud setInteger:[(BDSKEncodingPopUpButton *)sender encoding] forKey:BDSKTeXPreviewFileEncodingKey];        
}

@end

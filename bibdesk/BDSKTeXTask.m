//
//  BDSKTeXTask.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 6/8/05.
//
/*
 This software is Copyright (c) 2005-2015
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

#import "BDSKTeXTask.h"
#import "NSFileManager_BDSKExtensions.h"
#import "BDSKStringConstants.h"
#import "BDSKAppController.h"
#import "BDSKShellCommandFormatter.h"
#import "NSSet_BDSKExtensions.h"
#import "BDSKTask.h"
#import "BDSKPreferenceController.h"

#define BDSKTeXTaskRunLoopTimeoutKey @"BDSKTeXTaskRunLoopTimeout"

enum {
	BDSKGeneratedNoneMask = 0,
	BDSKGeneratedLTBMask = 1 << 0,
	BDSKGeneratedLaTeXMask = 1 << 1,
	BDSKGeneratedPDFMask = 1 << 2,
};

@interface BDSKTeXSubTask : BDSKTask {
    NSUInteger generatedType;
}
- (void)setGeneratedType:(NSUInteger)type;
- (NSUInteger)generatedType;
@end

#pragma mark -

@interface BDSKTeXPath : NSObject
{
    NSString *fullPathWithoutExtension;
}
- (id)initWithBasePath:(NSString *)fullPath;
- (NSString *)baseNameWithoutExtension;
- (NSString *)workingDirectory;
- (NSString *)texFilePath;
- (NSString *)bibFilePath;
- (NSString *)bblFilePath;
- (NSString *)pdfFilePath;
- (NSString *)logFilePath;
- (NSString *)blgFilePath;
- (NSString *)auxFilePath;
@end

#pragma mark -

@interface BDSKTeXTask (Private) 

- (NSArray *)helperFileURLs;

- (void)writeHelperFiles;
- (BOOL)writeTeXFileForCiteKeys:(NSArray *)citeKeys isLTB:(BOOL)ltb;
- (BOOL)writeBibTeXFile:(NSString *)bibStr;

- (void)removeFilesFromPreviousRun;

- (BDSKTeXSubTask *)taskForGeneratedType:(NSUInteger)type;

- (BOOL)invokePendingTasks;

- (void)checkTeXPaths;

@end

// modify the TeX template in application support
static void upgradeTemplate()
{
    NSString *texTemplatePath = [[[NSFileManager defaultManager] applicationSupportDirectory] stringByAppendingPathComponent:@"previewtemplate.tex"];
    NSStringEncoding encoding = [[NSUserDefaults standardUserDefaults] integerForKey:BDSKTeXPreviewFileEncodingKey];
    
    NSMutableString *texFile = [[NSMutableString alloc] initWithContentsOfFile:texTemplatePath encoding:encoding error:NULL];
    
    // This is a change required for latex2rtf compatibility.  Old versions used a peculiar "%latex2rtf:" comment at the beginning of a line to indicate a command or section that was needed for latex2rtf.  The latest version (in our vendorsrc tree as of 15 Dec 2007) uses a more typical \if\else\fi construct.
    NSString *oldString = @"%% The following command is provided for LaTeX2RTF compatibility\n"
    @"%% with amslatex.  DO NOT UNCOMMENT THE NEXT LINE!\n"
    @"%latex2rtf:\\providecommand{\\bysame}{\\_\\_\\_\\_\\_}";
    NSString *newString = @"% The following command is provided for LaTeX2RTF compatibility with amslatex.\n"
    @"\\newif\\iflatextortf\n"
    @"\\iflatextortf\n"
    @"\\providecommand{\\bysame}{\\_\\_\\_\\_\\_}\n"
    @"\\fi";
    if ([texFile replaceOccurrencesOfString:oldString withString:newString options:0 range:NSMakeRange(0, [texFile length])])
        [texFile writeToFile:texTemplatePath atomically:YES encoding:encoding error:NULL];
    [texFile release];
}

static double runLoopTimeout = 30;

@implementation BDSKTeXTask

+ (void)initialize
{
    BDSKINITIALIZE;
    
    // returns 0 if the key doesn't exist
    if ([[NSUserDefaults standardUserDefaults] doubleForKey:BDSKTeXTaskRunLoopTimeoutKey] > 1)
        runLoopTimeout = [[NSUserDefaults standardUserDefaults] doubleForKey:BDSKTeXTaskRunLoopTimeoutKey];
        
    upgradeTemplate();
    
}

- (id)init{
    return [self initWithFileName:@"tmpbib" synchronous:YES];
}

- (id)initWithFileName:(NSString *)fileName synchronous:(BOOL)isSync{
    self = [super init];
    if (self) {
		
		NSFileManager *fm = [NSFileManager defaultManager];
        NSString *dirPath = [fm makeTemporaryDirectoryWithBasename:fileName];
        NSParameterAssert([fm fileExistsAtPath:dirPath]);
		texTemplatePath = [[[fm applicationSupportDirectory] stringByAppendingPathComponent:@"previewtemplate.tex"] copy];
        
		NSString *filePath = [dirPath stringByAppendingPathComponent:fileName];
        texPath = [[BDSKTeXPath alloc] initWithBasePath:filePath];
        
		binDirPath = nil; // set from where we run the tasks, since some programs (e.g. XeLaTeX) need a real path setting     
        
        environment = [[[NSProcessInfo processInfo] environment] mutableCopy];
        
        // some users set BIBINPUTS in environment.plist, which will break our preview unless they added "." to the path (bug #1471984)
        NSString *bibinputs = [environment objectForKey:@"BIBINPUTS"];
        if (bibinputs != nil)
            [environment setObject:[NSString stringWithFormat:@"%@:%@", bibinputs, [texPath workingDirectory]] forKey:@"BIBINPUTS"];
		
		[self writeHelperFiles];
		
		delegate = nil;
        currentTask = nil;
        pendingTasks = [[NSMutableArray alloc] init];
        generatedDataMask = BDSKGeneratedNoneMask;
        synchronous = isSync;
	}
	return self;
}

- (void)dealloc{
    [[NSFileManager defaultManager] removeItemAtPath:[texPath workingDirectory] error:NULL];
    BDSKDESTROY(texTemplatePath);
    BDSKDESTROY(texPath);
    BDSKDESTROY(environment);
    BDSKDESTROY(pendingTasks);
	[super dealloc];
}

- (NSString *)description{
    NSMutableString *temporaryDescription = [[NSMutableString alloc] initWithString:[super description]];
    [temporaryDescription appendFormat:@" {\nivars:\n\tdelegate = \"%@\"\n\tfile name = \"%@\"\n\ttemplate = \"%@\"\n\tTeX file = \"%@\"\n\tBibTeX file = \"%@\"\n\tTeX binary path = \"%@\"\n\tEncoding = \"%@\"\n\tBibTeX style = \"%@\"\n\tHelper files = %@\n\nenvironment:\n\tSHELL = \"%s\"\n\tBIBINPUTS = \"%s\"\n\tBSTINPUTS = \"%s\"\n\tTEXINPUTS = \"%s\"\n\tTEXCONFIG = \"%s\"\n\tTEXMFCONFIG = \"%s\"\n\tPATH = \"%s\" }", delegate, [texPath baseNameWithoutExtension], texTemplatePath, [texPath texFilePath], [texPath bibFilePath], binDirPath, [NSString localizedNameOfStringEncoding:[[NSUserDefaults standardUserDefaults] integerForKey:BDSKTeXPreviewFileEncodingKey]], [[NSUserDefaults standardUserDefaults] objectForKey:BDSKBTStyleKey], [[self helperFileURLs] description], getenv("SHELL"), getenv("BIBINPUTS"), getenv("BSTINPUTS"), getenv("TEXINPUTS"), getenv("TEXCONFIG"), getenv("TEXMFCONFIG"), getenv("PATH")];
    NSString *description = [temporaryDescription copy];
    [temporaryDescription release];
    return [description autorelease];
}

- (id<BDSKTeXTaskDelegate>)delegate {
    return delegate;
}

- (void)setDelegate:(id<BDSKTeXTaskDelegate>)newDelegate {
	delegate = newDelegate;
}

- (void)cancel {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSTaskDidTerminateNotification object:currentTask];
    [currentTask terminate];
    BDSKDESTROY(currentTask);
    [pendingTasks removeAllObjects];
}

- (void)terminate{
    [self cancel];
    BDSKDESTROY(pendingTasks);
}

#pragma mark TeX Tasks

- (BOOL)runWithBibTeXString:(NSString *)bibStr citeKeys:(NSArray *)citeKeys generatedTypes:(NSInteger)flag{
	if ([delegate respondsToSelector:@selector(texTaskShouldStartRunning:)] && [delegate texTaskShouldStartRunning:self] == NO)
        return NO;
    
    static BOOL didCheckTeXPaths = NO;
    if (didCheckTeXPaths == NO) {
        didCheckTeXPaths  =YES;
        [self checkTeXPaths];
    }
    
    generatedDataMask = BDSKGeneratedNoneMask;
    
    // make sure the PATH environment variable is set correctly
    NSString *texCommand = [[NSUserDefaults standardUserDefaults] stringForKey:BDSKTeXBinPathKey];
    NSString *texCommandDir = [[BDSKShellCommandFormatter pathByRemovingArgumentsFromCommand:texCommand] stringByDeletingLastPathComponent];

    if (NO == [texCommandDir isEqualToString:binDirPath]) {
        [binDirPath release];
        binDirPath = [texCommandDir retain];
        NSString *path = [[[NSProcessInfo processInfo] environment] objectForKey:@"PATH"];
        [environment setObject:[NSString stringWithFormat:@"%@:%@", path, binDirPath] forKey:@"PATH"];
    }
    
    BOOL isLTB = (flag == BDSKGenerateLTB);
    BOOL success = [self writeTeXFileForCiteKeys:citeKeys isLTB:isLTB] && [self writeBibTeXFile:bibStr];
    
    if (success) {
        NSParameterAssert([pendingTasks count] == 0);
        
        // nuke the log files in case the run fails without generating new ones (not very likely)
        [self removeFilesFromPreviousRun];
        
        // tasks are launched from the end of pendingTasks, so we add them in opposite order
        if (flag >= BDSKGeneratePDF) {
            // pdflatex
            [pendingTasks addObject:[self taskForGeneratedType:BDSKGeneratedPDFMask]];
            // pdflatex
            [pendingTasks addObject:[self taskForGeneratedType:BDSKGeneratedNoneMask]];
        }
        // bibtex
        [pendingTasks addObject:[self taskForGeneratedType:isLTB ? BDSKGeneratedLTBMask : BDSKGeneratedLaTeXMask]];
        // pdflatex
        [pendingTasks addObject:[self taskForGeneratedType:BDSKGeneratedNoneMask]];
        
        success = [self invokePendingTasks];
    }
    
	if (synchronous && [delegate respondsToSelector:@selector(texTask:finishedWithResult:)])
        [delegate texTask:self finishedWithResult:success];

    return success;
}

#pragma mark Data accessors

- (NSString *)logFileString{
    NSString *logString = nil;
    NSString *blgString = nil;
    // @@ unclear if log files will always be written with ASCII encoding
    // these will be nil if the file doesn't exist
    logString = [NSString stringWithContentsOfFile:[texPath logFilePath] encoding:NSASCIIStringEncoding error:NULL];
    blgString = [NSString stringWithContentsOfFile:[texPath blgFilePath] encoding:NSASCIIStringEncoding error:NULL];
    
    NSMutableString *toReturn = [NSMutableString string];
    [toReturn setString:@"---------- TeX log file ----------\n"];
    [toReturn appendFormat:@"File: \"%@\"\n", [texPath logFilePath]];
    [toReturn appendFormat:@"%@\n\n", logString];
    [toReturn appendString:@"---------- BibTeX log file -------\n"];
    [toReturn appendFormat:@"File: \"%@\"\n", [texPath blgFilePath]];
    [toReturn appendFormat:@"%@\n\n", blgString];
    [toReturn appendString:@"---------- BibDesk info ----------\n"];
    [toReturn appendString:[self description]];
    return toReturn;
}    

// the .bbl file contains either a LaTeX style bilbiography or an Amsrefs ltb style bibliography
// which one was generated depends on the generatedTypes argument, and can be seen from the hasLTB and hasLaTeX flags
- (NSString *)LTBString{
    NSString *string = nil;
    if([self hasLTB]) {
        string = [NSString stringWithContentsOfFile:[texPath bblFilePath] encoding:[[NSUserDefaults standardUserDefaults] integerForKey:BDSKTeXPreviewFileEncodingKey] error:NULL];
        NSUInteger start, end;
        start = [string rangeOfString:@"\\bib{"].location;
        end = [string rangeOfString:@"\\end{biblist}" options:NSBackwardsSearch].location;
        if (start != NSNotFound && end != NSNotFound)
            string = [string substringWithRange:NSMakeRange(start, end - start)];
    }
    return string;    
}

- (NSString *)LaTeXString{
    NSString *string = nil;
    if([self hasLaTeX]) {
        string = [NSString stringWithContentsOfFile:[texPath bblFilePath] encoding:[[NSUserDefaults standardUserDefaults] integerForKey:BDSKTeXPreviewFileEncodingKey] error:NULL];
        NSUInteger start, end;
        start = [string rangeOfString:@"\\bibitem"].location;
        end = [string rangeOfString:@"\\end{thebibliography}" options:NSBackwardsSearch].location;
        if (start != NSNotFound && end != NSNotFound)
            string = [string substringWithRange:NSMakeRange(start, end - start)];
    }
    return string;
}

- (NSData *)PDFData{
    return [self hasPDFData] ? [NSData dataWithContentsOfFile:[texPath pdfFilePath]] : nil;
}

- (NSString *)logFilePath{
    return [texPath logFilePath];
}

- (NSString *)LTBFilePath{
    return [self hasLTB] ? [texPath bblFilePath] : nil;
}

- (NSString *)LaTeXFilePath{
    return [self hasLaTeX] ? [texPath bblFilePath] : nil;
}

- (NSString *)PDFFilePath{
    return [self hasPDFData] ? [texPath pdfFilePath] : nil;
}

- (BOOL)hasLTB{
    return 0 != (generatedDataMask & BDSKGeneratedLTBMask);
}

- (BOOL)hasLaTeX{
    return 0 != (generatedDataMask & BDSKGeneratedLaTeXMask);
}

- (BOOL)hasPDFData{
    return 0 != (generatedDataMask & BDSKGeneratedPDFMask);
}

- (BOOL)isProcessing{
	return currentTask != nil;
}

@end


@implementation BDSKTeXTask (Private)

- (NSArray *)helperFileURLs{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *appSupportURL = [NSURL fileURLWithPath:[fm applicationSupportDirectory]];
    NSArray *contents = [fm contentsOfDirectoryAtURL:appSupportURL includingPropertiesForKeys:[NSArray arrayWithObjects:NSURLIsDirectoryKey, nil] options:NSDirectoryEnumerationSkipsHiddenFiles error:NULL];
    NSSet *helperTypes = [NSSet setForCaseInsensitiveStringsWithObjects:@"cfg", @"sty", @"bst", nil];
    NSMutableArray *helperFileURLs = [NSMutableArray array];
    
	// copy all user helper files from application support
	for (NSURL *url in contents) {
        NSNumber *isDir = nil;
        [url getResourceValue:&isDir forKey:NSURLIsDirectoryKey error:NULL];
		if ([isDir boolValue] == NO && [helperTypes containsObject:[url pathExtension]])
            [helperFileURLs addObject:url];
    }
    return helperFileURLs;
}

- (void)writeHelperFiles{
    NSURL *dstDirURL = [NSURL fileURLWithPath:[texPath workingDirectory]];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    for (NSURL *srcURL in [self helperFileURLs]) {
        NSURL *dstURL = [dstDirURL URLByAppendingPathComponent:[srcURL lastPathComponent]];
        NSError *error;
        if (NO == [fm copyItemAtURL:srcURL toURL:dstURL error:&error])
            NSLog(@"unable to copy helper file %@ to %@; error %@", [srcURL path], [dstURL path], [error localizedDescription]);
    }
}

- (BOOL)writeTeXFileForCiteKeys:(NSArray *)citeKeys isLTB:(BOOL)ltb{
    
    NSMutableString *texFile = nil;
    NSString *style = [[NSUserDefaults standardUserDefaults] stringForKey:BDSKBTStyleKey];
    NSStringEncoding encoding = [[NSUserDefaults standardUserDefaults] integerForKey:BDSKTeXPreviewFileEncodingKey];
    NSError *error = nil;
    BOOL didWrite = NO;

	if (ltb) {
		texFile = [[NSMutableString alloc] initWithString:@"\\documentclass{article}\n\\usepackage{amsrefs}\n\\begin{document}\n\\nocite{*}\n\\bibliography{<<File>>}\n\\end{document}\n"];
	} else {
		texFile = [[NSMutableString alloc] initWithContentsOfFile:texTemplatePath encoding:encoding error:&error];
    }
    
    if (nil != texFile) {
        
        NSString *keys = citeKeys ? [citeKeys componentsJoinedByString:@","] : @"*";
        
        [texFile replaceOccurrencesOfString:@"<<File>>" withString:[texPath baseNameWithoutExtension] options:NSCaseInsensitiveSearch range:NSMakeRange(0,[texFile length])];
        [texFile replaceOccurrencesOfString:@"<<Style>>" withString:style options:NSCaseInsensitiveSearch range:NSMakeRange(0,[texFile length])];
        if ([texFile rangeOfString:@"<<CiteKeys>>"].length)
            [texFile replaceOccurrencesOfString:@"<<CiteKeys>>" withString:keys options:NSCaseInsensitiveSearch range:NSMakeRange(0,[texFile length])];
        else
            [texFile replaceOccurrencesOfString:@"\\nocite{*}" withString:[NSString stringWithFormat:@"\\nocite{%@}", keys] options:NSCaseInsensitiveSearch range:NSMakeRange(0,[texFile length])];
        
        // overwrites the old tmpbib.tex file, replacing the previous bibliographystyle
        didWrite = [[texFile dataUsingEncoding:encoding] writeToFile:[texPath texFilePath] atomically:YES];
        if(NO == didWrite)
            NSLog(@"error writing TeX file with encoding %@ for task %@", [NSString localizedNameOfStringEncoding:encoding], self);
	
        [texFile release];
    } else {
        NSLog(@"Unable to read preview template using encoding %@ for task %@", [NSString localizedNameOfStringEncoding:encoding], self);
        NSLog(@"Foundation reported error %@", error);
    }
    
	return didWrite;
}

- (BOOL)writeBibTeXFile:(NSString *)bibStr{
    
    NSStringEncoding encoding = [[NSUserDefaults standardUserDefaults] integerForKey:BDSKTeXPreviewFileEncodingKey];
    NSError *error;
    
    // this should likely be the same encoding as our other files; presumably it's here because the user can have a default @preamble or something that's relevant?
    NSMutableString *bibTemplate = [[NSMutableString alloc] initWithContentsOfFile:
                                    [[[NSUserDefaults standardUserDefaults] stringForKey:BDSKOutputTemplateFileKey] stringByStandardizingPath] encoding:encoding error:&error];
    
    if (nil == bibTemplate) {
        NSLog(@"unable to read file %@ in task %@", [[NSUserDefaults standardUserDefaults] stringForKey:BDSKOutputTemplateFileKey], self);
        NSLog(@"Foundation reported error %@", error);
        bibTemplate = [[NSMutableString alloc] init];
    }
    
	[bibTemplate appendString:@"\n"];
    [bibTemplate appendString:bibStr];
    [bibTemplate appendString:@"\n"];
        
    BOOL didWrite;
    didWrite = [bibTemplate writeToFile:[texPath bibFilePath] atomically:NO encoding:encoding error:&error];
    if(NO == didWrite) {
        NSLog(@"error writing BibTeX file with encoding %@ for task %@", [NSString localizedNameOfStringEncoding:encoding], self);
        NSLog(@"Foundation reported error %@", error);
    }
	
	[bibTemplate release];
	return didWrite;
}

- (void)removeFilesFromPreviousRun{
    NSArray *filesToRemove = [NSArray arrayWithObjects:[texPath blgFilePath], [texPath logFilePath], [texPath bblFilePath], [texPath auxFilePath], [texPath pdfFilePath], nil];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    for (NSString *path in filesToRemove)
        [fm removeItemAtPath:path error:NULL];
}

- (BDSKTeXSubTask *)taskForGeneratedType:(NSUInteger)type {
    NSString *binPath = nil;
    NSArray *arguments = nil;
    
    if (type & (BDSKGeneratedLaTeXMask | BDSKGeneratedLTBMask)) {
        // This task runs bibtex on our bib file 
        NSString *command = [[NSUserDefaults standardUserDefaults] stringForKey:BDSKBibTeXBinPathKey];
        binPath = [BDSKShellCommandFormatter pathByRemovingArgumentsFromCommand:command];
        NSMutableArray *args = [NSMutableArray array];
        [args addObjectsFromArray:[BDSKShellCommandFormatter argumentsFromCommand:command]];
        [args addObject:[texPath baseNameWithoutExtension]];
        arguments = args;
    } else {
        // This task runs latex on our tex file 
        NSString *command = [[NSUserDefaults standardUserDefaults] stringForKey:BDSKTeXBinPathKey];
        binPath = [BDSKShellCommandFormatter pathByRemovingArgumentsFromCommand:command];
        NSMutableArray *args = [NSMutableArray arrayWithObject:@"-interaction=batchmode"];
        [args addObjectsFromArray:[BDSKShellCommandFormatter argumentsFromCommand:command]];
        [args addObject:[texPath baseNameWithoutExtension]];
        arguments = args;
    }
    
    BDSKTeXSubTask *task = [[[BDSKTeXSubTask alloc] init] autorelease];
    [task setCurrentDirectoryPath:[texPath workingDirectory]];
    [task setLaunchPath:binPath];
    [task setArguments:arguments];
    [task setEnvironment:environment];
    [task setStandardOutput:[NSFileHandle fileHandleWithNullDevice]];
    [task setStandardError:[NSFileHandle fileHandleWithNullDevice]];
    [task setGeneratedType:type];
    
    return task;
}

- (void)taskFinished:(NSNotification *)notification{
    NSParameterAssert([notification object] == currentTask);
    NSParameterAssert(NO == synchronous);
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSTaskDidTerminateNotification object:[notification object]];
    BOOL success = ([[notification object] terminationStatus] == 0);
    if (success)
        generatedDataMask |= [currentTask generatedType];
    else
        // avoid launching the remaining tasks; note failure and bail out
        [pendingTasks removeAllObjects];
    if ([pendingTasks count] > 0)
        // previous task succeeded, so run the next one
        [self invokePendingTasks];
    // this was the final task in the queue, or the previous one failed
    else if ([delegate respondsToSelector:@selector(texTask:finishedWithResult:)])
        [delegate texTask:self finishedWithResult:success];
}

- (BOOL)invokePendingTasks {
    BOOL success = YES;
 
    [currentTask release];
    currentTask = [[pendingTasks lastObject] retain];
    [pendingTasks removeLastObject];
    
    [currentTask launch];
    
    if (synchronous) {
        [currentTask waitUntilExit];
        success = (0 == [currentTask terminationStatus]);
        if (success) {
            generatedDataMask |= [currentTask generatedType];
            if ([pendingTasks count] > 0)
                success = [self invokePendingTasks];
        }
    } else if (currentTask) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(taskFinished:) name:NSTaskDidTerminateNotification object:currentTask];
    }
    
    return success;
}

- (void)checkTeXPaths {
    if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_10_MAX) {
        NSUserDefaults *sud = [NSUserDefaults standardUserDefaults];
        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *library = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSLocalDomainMask, YES) lastObject];
        NSString *newTexbinPath = [NSString pathWithComponents:[NSArray arrayWithObjects:library, @"TeX", @"texbin", nil]];
        NSString *oldTexbinPath = @"/usr/texbin/";
        BOOL isDir = NO;
        
        if ([fm fileExistsAtPath:newTexbinPath isDirectory:&isDir] && isDir) {
            NSString *texCmdPath = [sud stringForKey:BDSKTeXBinPathKey];
            NSString *bibtexCmdPath = [sud stringForKey:BDSKBibTeXBinPathKey];
            
            if ([texCmdPath hasPrefix:oldTexbinPath])
                texCmdPath = [newTexbinPath stringByAppendingPathComponent:[texCmdPath substringFromIndex:[oldTexbinPath length]]];
            else
                texCmdPath = nil;
            if ([bibtexCmdPath hasPrefix:oldTexbinPath])
                bibtexCmdPath = [newTexbinPath stringByAppendingPathComponent:[bibtexCmdPath substringFromIndex:[oldTexbinPath length]]];
            else
                bibtexCmdPath = nil;
            
            if (texCmdPath || bibtexCmdPath) {
                
                NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"TeX installation changed", @"Message in alert dialog when detecting old texbin")
                                                 defaultButton:NSLocalizedString(@"Change", @"Button title")
                                               alternateButton:NSLocalizedString(@"Cancel", @"Button title")
                                                   otherButton:NSLocalizedString(@"Go to Preferences", @"Button title")
                                     informativeTextWithFormat:NSLocalizedString(@"Your TeX preferences need to be adjusted for new Apple requirements. Would you like to change your TeX programs to their new location in /Library/TeX/texbin, or set them manually in the Preferences?", @"Informative text in alert dialog")];
                NSInteger rv = [alert runModal];
                
                if (rv == NSAlertDefaultReturn) {
                    if (texCmdPath)
                        [sud setObject:texCmdPath forKey:BDSKTeXBinPathKey];
                    if (bibtexCmdPath)
                        [sud setObject:bibtexCmdPath forKey:BDSKBibTeXBinPathKey];
                } else if (rv == NSAlertOtherReturn) {
                    [[BDSKPreferenceController sharedPreferenceController] showWindow:nil];
                    [[BDSKPreferenceController sharedPreferenceController] selectPaneWithIdentifier:@"edu.ucsd.cs.mmccrack.bibdesk.prefpane.TeX"];
                }
            }
        }
    }
}

@end

#pragma mark -

@implementation BDSKTeXPath

- (id)initWithBasePath:(NSString *)fullPath;
{
    self = [super init];
    if (self) {
        // this gives e.g. /tmp/preview/bibpreview, where bibpreview is the basename of all files, and /tmp/preview is the working directory
        fullPathWithoutExtension = [[fullPath stringByStandardizingPath] copy];
        NSParameterAssert(fullPathWithoutExtension);
    }
    return self;
}

- (void)dealloc
{
    BDSKDESTROY(fullPathWithoutExtension);
    [super dealloc];
}

- (NSString *)baseNameWithoutExtension { return [fullPathWithoutExtension lastPathComponent]; }
- (NSString *)workingDirectory { return [fullPathWithoutExtension stringByDeletingLastPathComponent]; }
- (NSString *)texFilePath { return [fullPathWithoutExtension stringByAppendingPathExtension:@"tex"]; }
- (NSString *)bibFilePath { return [fullPathWithoutExtension stringByAppendingPathExtension:@"bib"]; }
- (NSString *)bblFilePath { return [fullPathWithoutExtension stringByAppendingPathExtension:@"bbl"]; }
- (NSString *)pdfFilePath { return [fullPathWithoutExtension stringByAppendingPathExtension:@"pdf"]; }
- (NSString *)logFilePath { return [fullPathWithoutExtension stringByAppendingPathExtension:@"log"]; }
- (NSString *)blgFilePath { return [fullPathWithoutExtension stringByAppendingPathExtension:@"blg"]; }
- (NSString *)auxFilePath { return [fullPathWithoutExtension stringByAppendingPathExtension:@"aux"]; }

@end

#pragma mark -

@implementation BDSKTeXSubTask

- (id)init {
    self = [super init];
    if (self) {
        generatedType = BDSKGeneratedNoneMask;
    }
    return self;
}

- (void)setGeneratedType:(NSUInteger)type { generatedType = type; }
- (NSUInteger)generatedType { return generatedType; };

@end

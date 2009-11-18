//
//  BDSKTeXTask.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 6/8/05.
//
/*
 This software is Copyright (c) 2005-2009
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
#import "UKDirectoryEnumerator.h"
#import "BDSKShellCommandFormatter.h"
#import <libkern/OSAtomic.h>
#import "NSSet_BDSKExtensions.h"
#import "NSInvocation_BDSKExtensions.h"
#import "BDSKTask.h"
#import "BDSKReadWriteLock.h"

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
- (NSString *)rtfFilePath;
- (NSString *)logFilePath;
- (NSString *)blgFilePath;
- (NSString *)auxFilePath;
@end

@interface BDSKTeXTask (Private) 

- (NSArray *)helperFilePaths;

- (void)writeHelperFiles;

- (BOOL)writeTeXFileForCiteKeys:(NSArray *)citeKeys isLTB:(BOOL)ltb;

- (BOOL)writeBibTeXFile:(NSString *)bibStr;

- (BOOL)runTeXTasksForLaTeX;

- (BOOL)runTeXTasksForPDF;

- (BOOL)runTeXTaskForRTF;

- (NSInteger)runPDFTeXTask;

- (NSInteger)runBibTeXTask;

- (NSInteger)runLaTeX2RTFTask;

- (NSInteger)runTask:(NSString *)binPath withArguments:(NSArray *)arguments;

@end

// modify the TeX template in application support
static void upgradeTemplate()
{
    NSString *texTemplatePath = [[[NSFileManager defaultManager] currentApplicationSupportPathForCurrentUser] stringByAppendingPathComponent:@"previewtemplate.tex"];
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
    if ([[NSUserDefaults standardUserDefaults] floatForKey:@"BDSKTeXTaskRunLoopTimeout"] > 1)
        runLoopTimeout = [[NSUserDefaults standardUserDefaults] floatForKey:@"BDSKTeXTaskRunLoopTimeout"];
        
    upgradeTemplate();
    
}

- (id)init{
    return [self initWithFileName:@"tmpbib"];
}

- (id)initWithFileName:(NSString *)newFileName{
	if (self = [super init]) {
		
		NSFileManager *fm = [NSFileManager defaultManager];
        NSString *dirPath = [fm makeTemporaryDirectoryWithBasename:newFileName];
        NSParameterAssert([fm fileExistsAtPath:dirPath]);
		texTemplatePath = [[[fm currentApplicationSupportPathForCurrentUser] stringByAppendingPathComponent:@"previewtemplate.tex"] copy];
        
		NSString *filePath = [dirPath stringByAppendingPathComponent:newFileName];
        texPath = [[BDSKTeXPath alloc] initWithBasePath:filePath];
        
		binDirPath = nil; // set from where we run the tasks, since some programs (e.g. XeLaTeX) need a real path setting     
        
        // some users set BIBINPUTS in environment.plist, which will break our preview unless they added "." to the path (bug #1471984)
        const char *bibInputs = getenv("BIBINPUTS");
        if(bibInputs != NULL){
            NSString *value = [NSString stringWithFileSystemRepresentation:bibInputs];
            if([value rangeOfString:[texPath workingDirectory]].length == 0){
                value = [NSString stringWithFormat:@"%@:%@", value, [texPath workingDirectory]];
                setenv("BIBINPUTS", [value fileSystemRepresentation], 1);
            }
        }        
		
		[self writeHelperFiles];
		
		delegate = nil;
        currentTask = nil;
        memset(&flags, 0, sizeof(flags));

        processingLock = [[NSLock alloc] init];
        dataFileLock = [[BDSKReadWriteLock alloc] init];
	}
	return self;
}

- (void)dealloc{
    [texTemplatePath release];
    [texPath release];
    [taskShouldStartInvocation release];
    [taskFinishedInvocation release];
    [processingLock release];
    [dataFileLock release];
	[super dealloc];
}

- (NSString *)description{
    NSMutableString *temporaryDescription = [[NSMutableString alloc] initWithString:[super description]];
    [temporaryDescription appendFormat:@" {\nivars:\n\tdelegate = \"%@\"\n\tfile name = \"%@\"\n\ttemplate = \"%@\"\n\tTeX file = \"%@\"\n\tBibTeX file = \"%@\"\n\tTeX binary path = \"%@\"\n\tEncoding = \"%@\"\n\tBibTeX style = \"%@\"\n\tHelper files = %@\n\nenvironment:\n\tSHELL = \"%s\"\n\tBIBINPUTS = \"%s\"\n\tBSTINPUTS = \"%s\"\n\tPATH = \"%s\" }", delegate, [texPath baseNameWithoutExtension], texTemplatePath, [texPath texFilePath], [texPath bibFilePath], binDirPath, [NSString localizedNameOfStringEncoding:[[NSUserDefaults standardUserDefaults] integerForKey:BDSKTeXPreviewFileEncodingKey]], [[NSUserDefaults standardUserDefaults] objectForKey:BDSKBTStyleKey], [[self helperFilePaths] description], getenv("SHELL"), getenv("BIBINPUTS"), getenv("BSTINPUTS"), getenv("PATH")];
    NSString *description = [temporaryDescription copy];
    [temporaryDescription release];
    return [description autorelease];
}

- (id<BDSKTeXTaskDelegate>)delegate {
    return delegate;
}

- (void)setDelegate:(id<BDSKTeXTaskDelegate>)newDelegate {
	delegate = newDelegate;
    
    SEL theSelector;
    
    // set invocations to nil before creating them, since we use that as a check before invoking
    theSelector = @selector(texTaskShouldStartRunning:);
    [taskShouldStartInvocation autorelease];
    taskShouldStartInvocation = nil;
    
    if ([delegate respondsToSelector:theSelector]) {
        taskShouldStartInvocation = [[NSInvocation invocationWithTarget:delegate selector:theSelector argument:&self] retain];
    }
    
    [taskFinishedInvocation autorelease];
    taskFinishedInvocation = nil;
    theSelector = @selector(texTask:finishedWithResult:);

    if ([delegate respondsToSelector:theSelector]) {
        taskFinishedInvocation = [[NSInvocation invocationWithTarget:delegate selector:theSelector argument:&self] retain];
    }        
}

- (void)terminate{
    // This method is mainly to ensure that we don't leave child processes around when exiting; it bypasses the processingLock, so this object is useless after it gets a -terminate message.  We used to wait here for a few seconds, but the application would quit before time was up, and currentTask could be left running.
    if ([self isProcessing] && currentTask){
        [currentTask terminate];
        [currentTask release];
        currentTask = nil;
    }    
}

#pragma mark TeX Tasks

- (BOOL)runWithBibTeXString:(NSString *)bibStr{
	return [self runWithBibTeXString:bibStr citeKeys:nil generatedTypes:BDSKGenerateRTF];
}

- (BOOL)runWithBibTeXString:(NSString *)bibStr citeKeys:(NSArray *)citeKeys{
	return [self runWithBibTeXString:bibStr citeKeys:citeKeys generatedTypes:BDSKGenerateRTF];
}

- (BOOL)runWithBibTeXString:(NSString *)bibStr generatedTypes:(NSInteger)flag{
	return [self runWithBibTeXString:bibStr citeKeys:nil generatedTypes:flag];
}

- (BOOL)runWithBibTeXString:(NSString *)bibStr citeKeys:(NSArray *)citeKeys generatedTypes:(NSInteger)flag{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    if([processingLock tryLock] == NO){
        NSLog(@"%@ couldn't get processing lock", self);
		[pool release];
        return NO;
    }

	if (nil != taskShouldStartInvocation) {
        BOOL shouldStart;
        [taskShouldStartInvocation performSelectorOnMainThread:@selector(invoke) withObject:nil waitUntilDone:YES];
        [taskShouldStartInvocation getReturnValue:&shouldStart];
        
        if (NO == shouldStart) {
            [processingLock unlock];
            [pool release];
            return NO;
        }
	}

    OSAtomicCompareAndSwap32Barrier(1, 0, &flags.hasLTB);
    OSAtomicCompareAndSwap32Barrier(1, 0, &flags.hasLaTeX);
    OSAtomicCompareAndSwap32Barrier(1, 0, &flags.hasPDFData);
    OSAtomicCompareAndSwap32Barrier(1, 0, &flags.hasRTFData);
    
    // make sure the PATH environment variable is set correctly
    NSString *pdfTeXBinPathDir = [[[NSUserDefaults standardUserDefaults] objectForKey:BDSKTeXBinPathKey] stringByDeletingLastPathComponent];

    if(![pdfTeXBinPathDir isEqualToString:binDirPath]){
        [binDirPath release];
        binDirPath = [pdfTeXBinPathDir retain];
        const char *path_cstring = getenv("PATH");
        NSString *original_path = [NSString stringWithFileSystemRepresentation:path_cstring];
        NSString *new_path = [NSString stringWithFormat: @"%@:%@", original_path, binDirPath];
        setenv("PATH", [new_path fileSystemRepresentation], 1);
    }
    
    BOOL success = [self writeTeXFileForCiteKeys:citeKeys isLTB:(flag == BDSKGenerateLTB)] && [self writeBibTeXFile:bibStr];
    
    if (success) {
        success = [self runTeXTasksForLaTeX];
        if (success) {
            if (flag == BDSKGenerateLTB)
                OSAtomicCompareAndSwap32Barrier(0, 1, &flags.hasLTB);
            else
                OSAtomicCompareAndSwap32Barrier(0, 1, &flags.hasLaTeX);
            
            if (flag > BDSKGenerateLaTeX) {
                success = [self runTeXTasksForPDF];
                if (success) {
                    OSAtomicCompareAndSwap32Barrier(0, 1, &flags.hasPDFData);
                    
                    if(flag > BDSKGeneratePDF){
                        success = [self runTeXTaskForRTF];
                        if (success)
                            OSAtomicCompareAndSwap32Barrier(0, 1, &flags.hasRTFData);
                    }
                }
            }
        }
	}
    
	if (nil != taskFinishedInvocation) {
        [taskFinishedInvocation setArgument:&success atIndex:3];
        [taskFinishedInvocation performSelectorOnMainThread:@selector(invoke) withObject:nil waitUntilDone:NO];
	}
    
	[processingLock unlock];
    
	[pool release];
    return success;
}

#pragma mark Data accessors

- (NSString *)logFileString{
    NSString *logString = nil;
    NSString *blgString = nil;
    if([dataFileLock tryLockForReading]) {
        // @@ unclear if log files will always be written with ASCII encoding
        // these will be nil if the file doesn't exist
        logString = [NSString stringWithContentsOfFile:[texPath logFilePath] encoding:NSASCIIStringEncoding error:NULL];
        blgString = [NSString stringWithContentsOfFile:[texPath blgFilePath] encoding:NSASCIIStringEncoding error:NULL];
        [dataFileLock unlock];
    }
    
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
    if([self hasLTB] && [dataFileLock tryLockForReading]) {
        string = [NSString stringWithContentsOfFile:[texPath bblFilePath] encoding:[[NSUserDefaults standardUserDefaults] integerForKey:BDSKTeXPreviewFileEncodingKey] error:NULL];
        [dataFileLock unlock];
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
    if([self hasLaTeX] && [dataFileLock tryLockForReading]) {
        string = [NSString stringWithContentsOfFile:[texPath bblFilePath] encoding:[[NSUserDefaults standardUserDefaults] integerForKey:BDSKTeXPreviewFileEncodingKey] error:NULL];
        [dataFileLock unlock];
        NSUInteger start, end;
        start = [string rangeOfString:@"\\bibitem"].location;
        end = [string rangeOfString:@"\\end{thebibliography}" options:NSBackwardsSearch].location;
        if (start != NSNotFound && end != NSNotFound)
            string = [string substringWithRange:NSMakeRange(start, end - start)];
    }
    return string;
}

- (NSData *)PDFData{
    NSData *data = nil;
    if ([self hasPDFData] && [dataFileLock tryLockForReading]) {
        data = [NSData dataWithContentsOfFile:[texPath pdfFilePath]];
        [dataFileLock unlock];
    }
    return data;
}

- (NSData *)RTFData{
    NSData *data = nil;
    if ([self hasRTFData] && [dataFileLock tryLockForReading]) {
        data = [NSData dataWithContentsOfFile:[texPath rtfFilePath]];
        [dataFileLock unlock];
    }
    return data;
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

- (NSString *)RTFFilePath{
    return [self hasRTFData] ? [texPath rtfFilePath] : nil;
}

- (BOOL)hasLTB{
    OSMemoryBarrier();
    return 1 == flags.hasLTB;
}

- (BOOL)hasLaTeX{
    OSMemoryBarrier();
    return 1 == flags.hasLaTeX;
}

- (BOOL)hasPDFData{
    OSMemoryBarrier();
    return 1 == flags.hasPDFData;
}

- (BOOL)hasRTFData{
    OSMemoryBarrier();
    return 1 == flags.hasRTFData;
}

- (BOOL)isProcessing{
	// just see if we can get the lock, otherwise we are processing
    if([processingLock tryLock]){
		[processingLock unlock];
		return NO;
	}
	return YES;
}

@end


@implementation BDSKTeXTask (Private)

- (NSArray *)helperFilePaths{
    UKDirectoryEnumerator *enumerator = [UKDirectoryEnumerator enumeratorWithPath:[[NSFileManager defaultManager] currentApplicationSupportPathForCurrentUser]];
    [enumerator setDesiredInfo:kFSCatInfoNodeFlags];
    
	NSString *path = nil;
    NSSet *helperTypes = [NSSet setForCaseInsensitiveStringsWithObjects:@"cfg", @"sty", @"bst", nil];
    NSMutableArray *helperFiles = [NSMutableArray array];
    
	// copy all user helper files from application support
	while(path = [enumerator nextObjectFullPath]){
		if([enumerator isDirectory] == NO && [helperTypes containsObject:[path pathExtension]]){
            [helperFiles addObject:path];
        }
    }
    return helperFiles;
}

- (void)writeHelperFiles{
    NSURL *dstURL = [NSURL fileURLWithPath:[texPath workingDirectory]];
    NSError *error;

    for (NSString *srcPath in [self helperFilePaths]) {
        if (![[NSFileManager defaultManager] copyObjectAtURL:[NSURL fileURLWithPath:srcPath] toDirectoryAtURL:dstURL error:&error])
            NSLog(@"unable to copy helper file %@ to %@; error %@", srcPath, [dstURL path], [error localizedDescription]);
    }
}

- (BOOL)writeTeXFileForCiteKeys:(NSArray *)citeKeys isLTB:(BOOL)ltb{
    
    NSMutableString *texFile = nil;
    NSString *style = [[NSUserDefaults standardUserDefaults] objectForKey:BDSKBTStyleKey];
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

// caller must have acquired wrlock on dataFileLock
- (void)removeFilesFromPreviousRun{
    // use FSDeleteObject for thread safety
    const FSRef fileRef;
    NSArray *filesToRemove = [[NSArray alloc] initWithObjects:[texPath blgFilePath], [texPath logFilePath], [texPath bblFilePath], [texPath auxFilePath], [texPath pdfFilePath], [texPath rtfFilePath], nil];
    CFURLRef fileURL;
    
    for (NSString *path in filesToRemove) {
        fileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)path, kCFURLPOSIXPathStyle, FALSE);
        if (fileURL) {
            if(CFURLGetFSRef(fileURL, (struct FSRef *)&fileRef))
                FSDeleteObject(&fileRef);
            CFRelease(fileURL);
        }
    }
    [filesToRemove release];
}

- (BOOL)runTeXTasksForLaTeX{
    volatile NSInteger rv;
    rv = 0;
    
    [dataFileLock lockForWriting];

    // nuke the log files in case the run fails without generating new ones (not very likely)
    [self removeFilesFromPreviousRun];
        
    rv = [self runPDFTeXTask];
    rv |= [self runBibTeXTask];
    
    [dataFileLock unlock];
    
	return rv == 0;
}

- (BOOL)runTeXTasksForPDF{
    volatile NSInteger rv;
    rv = 0;
    
    [dataFileLock lockForWriting];
    
    rv = [self runPDFTeXTask];
    rv |= [self runPDFTeXTask];
    
    [dataFileLock unlock];
    
	return rv == 0;
}

- (BOOL)runTeXTaskForRTF{
    volatile NSInteger rv;
    rv = 0;
    
    [dataFileLock lockForWriting];
    
    rv = [self runLaTeX2RTFTask];
    
    [dataFileLock unlock];
    
	return rv == 0;
}

- (NSInteger)runPDFTeXTask{
    NSString *command = [[NSUserDefaults standardUserDefaults] objectForKey:BDSKTeXBinPathKey];

    NSArray *argArray = [BDSKShellCommandFormatter argumentsFromCommand:command];
    NSString *pdftexbinpath = [BDSKShellCommandFormatter pathByRemovingArgumentsFromCommand:command];
    NSMutableArray *args = [NSMutableArray arrayWithObject:@"-interaction=batchmode"];
    [args addObjectsFromArray:argArray];
    [args addObject:[texPath baseNameWithoutExtension]];
    
    // This task runs latex on our tex file 
    return [self runTask:pdftexbinpath withArguments:args];
}

- (NSInteger)runBibTeXTask{
    NSString *command = [[NSUserDefaults standardUserDefaults] objectForKey:BDSKBibTeXBinPathKey];
	
    NSArray *argArray = [BDSKShellCommandFormatter argumentsFromCommand:command];
    NSString *bibtexbinpath = [BDSKShellCommandFormatter pathByRemovingArgumentsFromCommand:command];
    NSMutableArray *args = [NSMutableArray array];
    [args addObjectsFromArray:argArray];
    [args addObject:[texPath baseNameWithoutExtension]];
    
    // This task runs bibtex on our bib file 
    return [self runTask:bibtexbinpath withArguments:args];
}

- (NSInteger)runLaTeX2RTFTask{
    NSString *latex2rtfpath = [[NSBundle mainBundle] pathForResource:@"latex2rtf" ofType:nil];
    
    // This task runs latex2rtf on our tex file to generate tmpbib.rtf
    // the arguments: it needs -P "path" which is the path to the cfg files in the app wrapper
    return [self runTask:latex2rtfpath withArguments:[NSArray arrayWithObjects:@"-P", [[NSBundle mainBundle] sharedSupportPath], [texPath baseNameWithoutExtension], nil]];
}

- (NSInteger)runTask:(NSString *)binPath withArguments:(NSArray *)arguments{
    currentTask = [[BDSKTask alloc] init];
    [currentTask setCurrentDirectoryPath:[texPath workingDirectory]];
    [currentTask setLaunchPath:binPath];
    [currentTask setArguments:arguments];
    [currentTask setStandardOutput:[NSFileHandle fileHandleWithNullDevice]];
    [currentTask setStandardError:[NSFileHandle fileHandleWithNullDevice]];
    
    NSInteger rv = 0;
    
    [currentTask launch];
    [currentTask waitUntilExit];
    rv = [currentTask terminationStatus];
    
    [currentTask release];
    currentTask = nil;
    
    return rv;
}

@end

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
    [fullPathWithoutExtension release];
    [super dealloc];
}

- (NSString *)baseNameWithoutExtension { return [fullPathWithoutExtension lastPathComponent]; }
- (NSString *)workingDirectory { return [fullPathWithoutExtension stringByDeletingLastPathComponent]; }
- (NSString *)texFilePath { return [fullPathWithoutExtension stringByAppendingPathExtension:@"tex"]; }
- (NSString *)bibFilePath { return [fullPathWithoutExtension stringByAppendingPathExtension:@"bib"]; }
- (NSString *)bblFilePath { return [fullPathWithoutExtension stringByAppendingPathExtension:@"bbl"]; }
- (NSString *)pdfFilePath { return [fullPathWithoutExtension stringByAppendingPathExtension:@"pdf"]; }
- (NSString *)rtfFilePath { return [fullPathWithoutExtension stringByAppendingPathExtension:@"rtf"]; }
- (NSString *)logFilePath { return [fullPathWithoutExtension stringByAppendingPathExtension:@"log"]; }
- (NSString *)blgFilePath { return [fullPathWithoutExtension stringByAppendingPathExtension:@"blg"]; }
- (NSString *)auxFilePath { return [fullPathWithoutExtension stringByAppendingPathExtension:@"aux"]; }

@end

//
//  NSFileManager_BDSKExtensions.h
//  Bibdesk
//
//  Created by Adam Maxwell on 07/08/05.
//
/*
 This software is Copyright (c) 2005-2012
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
/*
 Omni Source License 2007

 OPEN PERMISSION TO USE AND REPRODUCE OMNI SOURCE CODE SOFTWARE

 Omni Source Code software is available from The Omni Group on their 
 web site at http://www.omnigroup.com/www.omnigroup.com. 

 Permission is hereby granted, free of charge, to any person obtaining 
 a copy of this software and associated documentation files (the 
 "Software"), to deal in the Software without restriction, including 
 without limitation the rights to use, copy, modify, merge, publish, 
 distribute, sublicense, and/or sell copies of the Software, and to 
 permit persons to whom the Software is furnished to do so, subject to 
 the following conditions:

 Any original copyright notices and this permission notice shall be 
 included in all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, 
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF 
 MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. 
 IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY 
 CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, 
 TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE 
 SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import <Cocoa/Cocoa.h>


@interface NSFileManager (BDSKExtensions)

- (NSString *)applicationSupportDirectory;
- (NSString *)applicationsDirectory;
- (NSString *)desktopDirectory;
- (NSURL *)downloadFolderURL;
- (NSString *)latestLyXPipePath;

- (BOOL)copyFileFromSharedSupportToApplicationSupport:(NSString *)fileName overwrite:(BOOL)overwrite;

- (void)copyAllExportTemplatesToApplicationSupportAndOverwrite:(BOOL)overwrite;

- (NSString *)temporaryPathForWritingToPath:(NSString *)path error:(NSError **)outError;

// creates a temporary directory with default attributes in a system temp location; this is thread safe
- (NSString *)makeTemporaryDirectoryWithBasename:(NSString *)fileName;

// !!! The next two methods are not thread safe, since they return a name without creating a file, and other threads/processes may return the same value

// accepts a filename and a directory, and returns a unique file name in that directory using the filename as a basename
- (NSString *)uniqueFilePathWithName:(NSString *)fileName atPath:(NSString *)directory;
// creates a file in a system temp location; pass nil for fileName if you want a UUID based name
- (NSString *)temporaryFileWithBasename:(NSString *)fileName;

// for spotlight stuff; thread safe
- (BOOL)spotlightCacheFolderExists;
- (BOOL)removeSpotlightCacheFolder;
- (NSString *)spotlightCacheFolderPathByCreating:(NSError **)anError;
- (BOOL)removeSpotlightCacheFilesForCiteKeys:(NSArray *)itemNames;
- (BOOL)removeSpotlightCacheFileForCiteKey:(NSString *)citeKey;
- (NSString *)spotlightCacheFilePathWithCiteKey:(NSString *)citeKey;

// methods to get/set com.apple.TextEncoding attribute for 10.5 compatibility
// apparently only used by NSString methods with the usedEncoding: parameter
- (NSStringEncoding)appleStringEncodingAtPath:(NSString *)path error:(NSError **)error;
- (BOOL)setAppleStringEncoding:(NSStringEncoding)nsEncoding atPath:(NSString *)path error:(NSError **)error;

// uses createDirectoryAtPath:withIntermediateDirectories:attributes:error: for the containing directory if necessary
- (BOOL)createPathToFile:(NSString *)path attributes:(NSDictionary *)attributes;

- (NSString *)resolveAliasesInPath:(NSString *)path;

//
// Thread safe API
//

- (BOOL)createDirectoryAtPathWithNoAttributes:(NSString *)path;
- (BOOL)objectExistsAtFileURL:(NSURL *)fileURL;
- (BOOL)deleteObjectAtFileURL:(NSURL *)fileURL error:(NSError **)error;
- (BOOL)copyObjectAtURL:(NSURL *)srcURL toDirectoryAtURL:(NSURL *)dstURL error:(NSError **)error;

@end

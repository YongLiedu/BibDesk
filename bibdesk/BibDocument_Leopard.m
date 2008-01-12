//
//  BibDocument_Leopard.m
//  Bibdesk
//
//  Created by Adam Maxwell on 1/11/08.
/*
 This software is Copyright (c) 2008
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

#import "BibDocument_Leopard.h"

// Omni's framework headers won't allow us to compile with 10.4 as min version and 10.5 as SDK.  It may work to build this target with 10.5/10.5 settings and link against the Omni frameworks, but I'm not sure.
@interface NSFileManager (BDSKOFExtensions)
- (NSString *)temporaryPathForWritingToPath:(NSString *)aPath allowOriginalDirectory:(BOOL)allow error:(NSError **)outError;
@end

@implementation BibDocument (Leopard)

- (BOOL)writeSafelyToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation error:(NSError **)outError;
{
    BOOL didSave = [super writeSafelyToURL:absoluteURL ofType:typeName forSaveOperation:saveOperation error:outError];
        
    /* 
     This is a workaround for https://sourceforge.net/tracker/index.php?func=detail&aid=1867790&group_id=61487&atid=497423
     Filed as rdar://problem/5679370
     
     I'm not sure what the semantics of this operation are for NSAutosaveOperation, so it's excluded (but uses a different code path anyway, at least on Leopard).  This also doesn't get hit for save-as or save-to since they don't do a safe-save, but they're handled anyway.  FSExchangeObjects apparently avoids the bugs in FSPathReplaceObject, but doesn't preserve all of the metadata that those do.  It's a shame that Apple can't preserve the file content as well as they preserve the metadata; I'd rather lose the ACLs than lose my bibliography.
     
     TODO:  xattr handling, package vs. flat file (overwrite directory)?  
     xattrs from BibDesk seem to be preserved, so I'm not going to bother with that.
     
     TESTED:  On AFP volume served by 10.4.11 Server, saving from 10.5.1 client; on AFP volume served by 10.5.1 client, saving from 10.5.1 client.  Autosave, Save-As, and Save were tested.  Saving to a local HFS+ volume doesn't hit this code path, and neither does saving to a FAT-32 thumb drive.
     
     */
    
    NSParameterAssert(floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_4);
    
    if (NO == didSave && [absoluteURL isFileURL] && NSAutosaveOperation != saveOperation) {
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        // this will create a new file on the same volume as the original file, which we will overwrite
        // FSExchangeObjects requires both files to be on the same volume
        NSString *tmpPath = [fileManager temporaryPathForWritingToPath:[absoluteURL path] allowOriginalDirectory:YES error:outError];
        NSURL *saveToURL = nil;
        
        // at this point, we're guaranteed that absoluteURL is non-nil and is a fileURL, but the file may not exist
        
        // save to or save as; file doesn't exist, so overwrite it
        if (NSSaveOperation != saveOperation)
            saveToURL = absoluteURL;
        else if (nil != tmpPath)
            saveToURL = [NSURL fileURLWithPath:tmpPath];
        
        // if tmpPath failed, saveToURL is nil
        if (nil != saveToURL)
            didSave = [self writeToURL:saveToURL ofType:typeName forSaveOperation:saveOperation originalContentsURL:absoluteURL error:outError];
        
        if (didSave) {
            NSMutableDictionary *fattrs = [NSMutableDictionary dictionary];
            [fattrs addEntriesFromDictionary:[self fileAttributesToWriteToURL:saveToURL ofType:typeName forSaveOperation:saveOperation originalContentsURL:absoluteURL error:outError]];
            
            // copy POSIX permissions from the old file
            NSNumber *posixPerms = nil;
            
            if ([fileManager fileExistsAtPath:[absoluteURL path]])
                posixPerms = [[fileManager fileAttributesAtPath:[absoluteURL path] traverseLink:YES] objectForKey:NSFilePosixPermissions];
            
            if (nil != posixPerms)
                [fattrs setObject:posixPerms forKey:NSFilePosixPermissions];
            
            // not checking return value here; non-critical
            if ([fattrs count])
                [fileManager changeFileAttributes:fattrs atPath:[saveToURL path]];
        }
        
        // If this is not an overwriting operation, we already saved to absoluteURL, and we're done
        // If this is an overwriting operation, do an atomic swap of the files
        if (didSave && NSSaveOperation == saveOperation) {
            
            FSRef originalRef, newRef;
            OSStatus err = coreFoundationUnknownErr;
            
            FSCatalogInfo catalogInfo;
            if (CFURLGetFSRef((CFURLRef)absoluteURL, &originalRef))
                err = noErr;
            
            if (noErr == err)
                err = FSGetCatalogInfo(&originalRef, kFSCatInfoVolume, &catalogInfo, NULL, NULL, NULL);
            
            GetVolParmsInfoBuffer infoBuffer;
            err = FSGetVolumeParms(catalogInfo.volume, &infoBuffer, sizeof(GetVolParmsInfoBuffer));
            
            if (noErr == err) {
                
                // only meaningful in v3 or greater GetVolParmsInfoBuffer
                SInt32 vmExtAttr = infoBuffer.vMExtendedAttributes;
                
                // in v2 or less or v3 without HFS+ support, the File Manager will implement FSExchangeObjects if bHasFileIDs is set
                
                // MoreFilesX.h has macros that show how to read the bitfields for the enums
                if (infoBuffer.vMVersion > 2 && (vmExtAttr & (1L << bSupportsHFSPlusAPIs)) != 0 && (vmExtAttr & (1L << bSupportsFSExchangeObjects)) != 0)
                    err = noErr;
                else if ((infoBuffer.vMVersion <= 2 || (vmExtAttr & (1L << bSupportsHFSPlusAPIs)) == 0) && (infoBuffer.vMAttrib & (1L << bHasFileIDs)) != 0)
                    err = noErr;
                else
                    err = errFSUnknownCall;
                
                // do an atomic swap of the files
                // On an AFP volume (Server 10.4.11), xattrs from the original file are preserved using either function
                
                if (noErr == err && CFURLGetFSRef((CFURLRef)saveToURL, &newRef)) {   
                    // this avoids breaking aliases and FSRefs
                    err = FSExchangeObjects(&newRef, &originalRef);
                }
                else /* if we couldn't get an FSRef or bSupportsFSExchangeObjects is not supported */ {
                    // rename() is atomic, but it probably breaks aliases and FSRefs
                    // FSExchangeObjects() uses exchangedata() so there's no point in trying that
                    err = rename([[saveToURL path] fileSystemRepresentation], [[absoluteURL path] fileSystemRepresentation]);
                }
            }
            
            if (noErr != err) {
                didSave = NO;
                if (outError) *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil];
            }
            else if ([self keepBackupFile] == NO) {
                // not checking return value here; non-critical, and fails if rename() was used
                [fileManager removeFileAtPath:[saveToURL path] handler:nil];
            }
        }
    }
    return didSave;
}

@end

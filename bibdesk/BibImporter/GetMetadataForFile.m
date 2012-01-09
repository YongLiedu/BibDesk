#include <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
//  Created by Adam Maxwell on 09/26/04.
/*
 This software is Copyright (c) 2004-2012
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
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE
*/

Boolean GetMetadataForFile(void* thisInterface, 
			   CFMutableDictionaryRef attributes, 
			   CFStringRef contentTypeUTI,
			   CFStringRef pathToFile)
{
    /* Pull any available metadata from the file at the specified path */
    /* Return the attribute keys and attribute values in the dict */
    /* Return TRUE if successful, FALSE if there was no data provided */
    
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    Boolean success = FALSE;
    
    CFStringRef cacheUTI = CFSTR("net.sourceforge.bibdesk.bdskcache");
    CFStringRef searchUTI = CFSTR("net.sourceforge.bibdesk.bdsksearch");
    
    if(UTTypeEqual(contentTypeUTI, cacheUTI)){
        
        NSDictionary *dictionary = [[NSDictionary alloc] initWithContentsOfFile:(NSString *)pathToFile];
        success = (dictionary != nil);

        [(NSMutableDictionary *)attributes addEntriesFromDictionary:dictionary];
        
        // don't index this, since it's not useful to mds
        [(NSMutableDictionary *)attributes removeObjectForKey:@"FileAlias"]; 
        [dictionary release];
        
    } else if (UTTypeEqual(contentTypeUTI, searchUTI)) {
        
        NSDictionary *dictionary = [[NSDictionary alloc] initWithContentsOfFile:(NSString *)pathToFile];
        success = (dictionary != nil);
        NSString *value;
        
        // this is what the user sees as the name in BibDesk, so it's a reasonable title
        value = [dictionary objectForKey:@"name"];
        if (value) {
            [(NSMutableDictionary *)attributes setObject:value forKey:(NSString *)kMDItemTitle];
            [(NSMutableDictionary *)attributes setObject:value forKey:(NSString *)kMDItemDisplayName];
        }
        
        // add hostname and database name as kMDItemWhereFroms
        NSMutableArray *whereFroms = [NSMutableArray new];
        value = [dictionary objectForKey:@"host"];
        if (value)
            [whereFroms addObject:value];
        value = [dictionary objectForKey:@"database"];
        if (value)
            [whereFroms addObject:value];
        if ([whereFroms count])
            [(NSMutableDictionary *)attributes setObject:whereFroms forKey:(NSString *)kMDItemWhereFroms];
        [whereFroms release];

        // rest of the information (port, type, options) doesn't seem as useful        
        [dictionary release];
        
    } 
    
    // add the entire file as kMDItemTextContent for plain text file types
    if(UTTypeConformsTo(contentTypeUTI, kUTTypePlainText)){
        
        NSStringEncoding encoding;
        NSError *error = nil;
        
        // try to interpret as Unicode (uses xattrs on 10.5 also)
        NSString *fileString = [[NSString alloc] initWithContentsOfFile:(NSString *)pathToFile usedEncoding:&encoding error:&error];
        
        if(fileString == nil){
            // read file as data instead
            NSData *data = [[NSData alloc] initWithContentsOfFile:(NSString *)pathToFile];
            
            if (nil != data) {
                
                // try UTF-8 next (covers ASCII as well)
                fileString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                
                // last-ditch effort: MacRoman will always succeed
                if(fileString == nil)
                    fileString = [[NSString alloc] initWithData:data encoding:NSMacOSRomanStringEncoding];
                
                // done with this, whether we succeeded or not
                [data release];
            }
        }
        
        if (nil != fileString) {
            [(NSMutableDictionary *)attributes setObject:fileString forKey:(NSString *)kMDItemTextContent];
            [fileString release];
            success = TRUE;
        }
        
    }
    
    if (success == FALSE)
        NSLog(@"Importer failed to import file with UTI %@ at %@", contentTypeUTI, pathToFile);
    
    [pool release];
    return success;
    
}

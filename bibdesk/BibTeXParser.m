//
//  BibTeXParser.m
//  Bibdesk
//
//  Created by Michael McCracken on Thu Nov 28 2002.
//  Copyright (c) 2002 __MyCompanyName__. All rights reserved.
//

#import "BibTeXParser.h"


@implementation BibTeXParser

+ (NSMutableArray *)itemsFromData:(NSData *)inData
                              error:(BOOL *)hadProblems{
    return [BibTeXParser itemsFromData:inData error:hadProblems frontMatter:nil filePath:@"Paste/Drag"];
}

NSRange SafeForwardSearchRange( unsigned startLoc, unsigned seekLength, unsigned maxLoc ){
    seekLength = ( (startLoc + seekLength > maxLoc) ? maxLoc - startLoc : seekLength );
    return NSMakeRange(startLoc, seekLength);
}

+ (void)postParsingErrorNotification:(NSString *)message errorType:(NSString *)type fileName:(NSString *)name errorRange:(NSRange)range{
    
    NSDictionary *errorDict = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:name, [NSNull null], type, message, [NSValue valueWithRange:range], nil]
                                                          forKeys:[NSArray arrayWithObjects:@"fileName", @"lineNumber", @"errorClassName", @"errorMessage", @"errorRange", nil]];
#warning BTPARSE ERROR should be declared as BDSKBibTeXParseError or something
    [[NSNotificationCenter defaultCenter] postNotificationName:@"BTPARSE ERROR"
                                                        object:errorDict];
}


+ (NSMutableArray *)itemsFromString:(NSString *)fullString
                              error:(BOOL *)hadProblems
                        frontMatter:(NSMutableString *)frontMatter
                           filePath:(NSString *)filePath{

// Potential problems with this method:
//
// Error checking is almost non-existent; it's basically just using ad hoc pattern-matching heuristics to scan fragments of text.  The plus side to this is that
// we can read some sloppy (or even incorrect) BibTeX and probably correct it by saving, since BibItem will clean things up for us when it writes out a BibTeX string.
//
// Nested double quotes are bound to cause problems if the entries use the key = "value", instead of key = {value}, approach.  I can't do anything about this; if you're using TeX,
// you shouldn't have double quotes in your files.  This is a non-issue for BibDesk-created files, as BibItem uses curly braces instead of double quotes; JabRef-1.6 appears to use braces, also.
// This problem will only munge a single entry, though, since we scan between @ != \@ markers as entry delimiters; the larger problem is that there is no warning for this case.

#warning ARM: Scan comments into preamble
#warning ARM: Scan strings into a separate container?  Ask mmcc about this.
    
    NSAssert( fullString != nil, @"A nil string was passed to the parser.  This is probably due to an incorrect guess at the string encoding." );

    NSScanner *scanner = [[NSScanner alloc] initWithString:fullString];
    [scanner setCharactersToBeSkipped:nil];
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    unsigned fullStringLength = [fullString length];
    unsigned fileOrder = 0;
    NSCharacterSet *possibleLeftDelimiters = [NSCharacterSet characterSetWithCharactersInString:@"\"{"];
    
    BibItem *newBI;
    NSMutableArray *bibItemArray = [NSMutableArray array];
    
    NSRange firstAtRange = [fullString rangeOfString:@"@" options:NSLiteralSearch range:NSMakeRange(0, [fullString length])];
    
    NSAssert( firstAtRange.location != NSNotFound, @"This does not appear to be a BibTeX entry.  Perhaps due to an incorrect encoding guess?" );
    
    // if the @ is escaped, get the next one
    while(firstAtRange.location >= 1 && [[fullString substringWithRange:NSMakeRange(firstAtRange.location - 1, 1)] isEqualToString:@"\\"])
        firstAtRange = [fullString rangeOfString:@"@" options:NSLiteralSearch range:SafeForwardSearchRange(firstAtRange.location + 1, fullStringLength - firstAtRange.location - 1, fullStringLength)];

    NSRange nextAtRange = [fullString rangeOfString:@"@" options:NSLiteralSearch range:SafeForwardSearchRange(firstAtRange.location + 1, fullStringLength - firstAtRange.location - 1, fullStringLength)];    
    // check this one to make sure the @ is not escaped; make sure there _is_ another one, though
    while(nextAtRange.location != NSNotFound && [[fullString substringWithRange:NSMakeRange(nextAtRange.location - 1, 1)] isEqualToString:@"\\"])
        nextAtRange = [fullString rangeOfString:@"@" options:NSLiteralSearch range:SafeForwardSearchRange(nextAtRange.location + 1, fullStringLength - nextAtRange.location - 1, fullStringLength)];

    if(nextAtRange.location == NSNotFound)
        nextAtRange = NSMakeRange(fullStringLength, 0); // avoid out-of-range exceptions

    NSRange entryClosingBraceRange = [fullString rangeOfString:@"}" options:NSLiteralSearch | NSBackwardsSearch range:NSMakeRange(firstAtRange.location + 1, nextAtRange.location - firstAtRange.location - 1)]; // look back from the next @ to find the closing brace of the present bib entry
    
    if(entryClosingBraceRange.location == NSNotFound && nextAtRange.location != fullStringLength){ // there's another @entry here (next), but we can't find the brace for the present one (first)
        *hadProblems = YES;
        [BibTeXParser postParsingErrorNotification:@"Entry is missing a closing brace."
                                         errorType:@"Parse Error"
                                          fileName:filePath
                                        errorRange:[fullString lineRangeForRange:NSMakeRange(firstAtRange.location, 0)]];
        entryClosingBraceRange.location = nextAtRange.location;
    }    
    
    // NSLog(@"Creating a new bibitem, first one is at %i, second is at %@", firstAtRange.location, ( nextAtRange.location != NSNotFound ? [NSString stringWithFormat:@"%i", nextAtRange.location] : @"NSNotFound" ) );
    
    while(![scanner isAtEnd]){
        
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        
        // get the type and citekey
        NSString *type = nil;
        NSString *citekey = nil;
                
        [scanner setScanLocation:(firstAtRange.location + 1)];

        if(![scanner scanUpToString:@"{" intoString:&type]){
            *hadProblems = YES;
            [BibTeXParser postParsingErrorNotification:@"Reference type not found"
                                             errorType:@"Parse Error"
                                              fileName:filePath
                                            errorRange:[fullString lineRangeForRange:NSMakeRange([scanner scanLocation], 0)]];
        }
        
        
        if(![scanner scanString:@"{" intoString:nil]){
            *hadProblems = YES;
            [BibTeXParser postParsingErrorNotification:@"Brace not found"
                                             errorType:@"Parse Error"
                                              fileName:filePath
                                            errorRange:[fullString lineRangeForRange:NSMakeRange([scanner scanLocation], 0)]];
        }
        
        
        if(![scanner scanUpToString:@"," intoString:&citekey]){
            *hadProblems = YES;
            [BibTeXParser postParsingErrorNotification:@"Citekey not found"
                                             errorType:@"Parse Error"
                                              fileName:filePath
                                            errorRange:[fullString lineRangeForRange:NSMakeRange([scanner scanLocation], 0)]];
        }
        
        // NSAssert( citekey != nil && type != nil, @"Missing a citekey or type" );
        
        newBI = [[BibItem alloc] initWithType:type
                                     fileType:@"BibTeX"
                                      authors:[NSMutableArray array]];        
        
        [newBI setCiteKeyString:citekey];
        
        while(entryClosingBraceRange.location != NSNotFound && [scanner scanLocation] < entryClosingBraceRange.location){ // while we are within bounds of a single bibitem
            NSString *key = nil;
            NSString *value = nil;
            NSRange quoteRange;
            NSRange braceRange;
            BOOL usingBraceDelimiter = YES; // assume BibDesk; double quote also works, though
            NSString *leftDelim = @"{";
            NSString *rightDelim = @"}";
            unsigned leftDelimLocation;
            
            [scanner scanUpToString:@"," intoString:nil]; // find the comma
              
            if([scanner scanLocation] >= entryClosingBraceRange.location){
                // NSLog(@"End of file or reached the next bibitem...breaking");
                break; // either at EOF or scanned into the next bibitem
            }

            [scanner scanString:@"," intoString:nil];// get rid of the comma
            
            [scanner scanUpToString:@"=" intoString:&key]; // this should be our key
                           
            [scanner scanString:@"=" intoString:nil];

            quoteRange = [fullString rangeOfString:@"\"" options:NSLiteralSearch range:SafeForwardSearchRange([scanner scanLocation], 100, fullStringLength)];
            braceRange = [fullString rangeOfString:@"{" options:NSLiteralSearch range:SafeForwardSearchRange([scanner scanLocation], 100, fullStringLength)];

            if(quoteRange.location != NSNotFound){
                usingBraceDelimiter = NO;
                leftDelim = @"\"";
                rightDelim = leftDelim;
            }

            if(braceRange.location != NSNotFound && quoteRange.location != NSNotFound && braceRange.location < quoteRange.location){
                usingBraceDelimiter = YES;
                leftDelim = @"{";
                rightDelim = @"}";
            }

            leftDelimLocation = ( usingBraceDelimiter ? braceRange.location : quoteRange.location );
            
            if([scanner scanLocation] >= entryClosingBraceRange.location){
                break; // break here, since this happens at the end of every entry with JabRef-generated BibTeX, and we don't need to hit the assertion below
            }                
            
            // NSAssert ( leftDelimLocation != NSNotFound, @"Can't find a delimiter.");
#warning ARM: for debugging
            // scan whitespace after the = to see if we have an opening delimiter or not; this will be for macroish stuff
            [scanner scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:nil];
            if(![possibleLeftDelimiters characterIsMember:[fullString characterAtIndex:[scanner scanLocation]]]){
                leftDelimLocation = [scanner scanLocation] - 1; // rewind so we don't lose the first character
                rightDelim = @",\n"; // set the delimiter appropriately for an unquoted value
            } else {
                [scanner setScanLocation:leftDelimLocation + 1];
            }
            
            if(leftDelimLocation == NSNotFound){
                *hadProblems = YES;
                [BibTeXParser postParsingErrorNotification:@"Delimiter not found."
                                                 errorType:@"Parse Error"
                                                  fileName:filePath
                                                errorRange:[fullString lineRangeForRange:NSMakeRange([scanner scanLocation], 0)]];
                break; // nothing more we can do with this one
            }                
                        
            if([scanner scanLocation] >= entryClosingBraceRange.location)
                break;
                        
            unsigned rightDelimLocation = 0;
            if([scanner scanUpToString:rightDelim intoString:nil]){
                rightDelimLocation = [scanner scanLocation];
            } else {
                *hadProblems = YES;
                [BibTeXParser postParsingErrorNotification:[NSString stringWithFormat:@"Delimiter '%@' not found", rightDelim]
                                                 errorType:@"Parse Error" 
                                                  fileName:filePath 
                                                errorRange:[fullString lineRangeForRange:NSMakeRange([scanner scanLocation], 0)]];
            }
               

#warning ARM: Need more testing of nested brace code
            unsigned searchStart = leftDelimLocation + 1;
            NSRange braceSearchRange;
            NSRange braceFoundRange;
            
            while(usingBraceDelimiter){ // should put us at the end of a record if we're using brace delimiters
                braceSearchRange = NSMakeRange(searchStart, rightDelimLocation - searchStart);
                braceFoundRange = [fullString rangeOfString:leftDelim options:NSLiteralSearch range:braceSearchRange];
                
                if(braceFoundRange.location != NSNotFound){ // if there's a "{" between { and }
                    [scanner scanString:rightDelim intoString:nil]; // it wasn't this one, so scan past it
                    [scanner scanUpToString:rightDelim intoString:nil];  // find the next one
                    searchStart = rightDelimLocation + 1; // start from the previous search end
                    rightDelimLocation = [scanner scanLocation];
                } else {
                    break;
                }
            }
                        
            value = [fullString substringWithRange:NSMakeRange(leftDelimLocation + 1, [scanner scanLocation] - leftDelimLocation - 1)]; // here's the "bar" part of foo = bar

            NSAssert( NSMakeRange(leftDelimLocation + 1, [scanner scanLocation] - leftDelimLocation - 1).location <= nextAtRange.location, @"The parser scanned into the next bibitem");

            value = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            value = [[BDSKConverter sharedConverter] stringByDeTeXifyingString:value];
            key = [[key stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] capitalizedString];
            
            NSAssert( value != nil, @"Found a nil value string");
            NSAssert( key != nil, @"Found a nil key string");
            
            [dict setObject:value forKey:key];
            
        }
        
        [newBI setFileOrder:fileOrder];
        [newBI setPubFields:dict];
        [bibItemArray addObject:[newBI autorelease]];

        fileOrder ++;
        
        [dict removeAllObjects];
        
        firstAtRange = nextAtRange; // we know the next one is safe (unescaped)
        
        nextAtRange = [fullString rangeOfString:@"@" options:NSLiteralSearch range:SafeForwardSearchRange(firstAtRange.location + 1, fullStringLength - firstAtRange.location - 1, fullStringLength)];
        // check for an escaped @ string...they're deadly when provoked
        while(nextAtRange.location != NSNotFound && [[fullString substringWithRange:NSMakeRange(nextAtRange.location - 1, 1)] isEqualToString:@"\\"])
            nextAtRange = [fullString rangeOfString:@"@" options:NSLiteralSearch range:SafeForwardSearchRange(nextAtRange.location + 1, fullStringLength - nextAtRange.location - 1, fullStringLength)];

        if(nextAtRange.location == NSNotFound)
            nextAtRange = NSMakeRange(fullStringLength, 0);
        
        if(firstAtRange.location != NSNotFound){ // we get to scan another one, so set the scanner appropriately and find the end of the bibitem
            [scanner setScanLocation:firstAtRange.location];
            entryClosingBraceRange = [fullString rangeOfString:@"}" options:NSLiteralSearch | NSBackwardsSearch range:NSMakeRange(firstAtRange.location + 1, nextAtRange.location - firstAtRange.location - 1)]; // look back from the next @ to find the closing brace of the present bib entry
        } else {
            entryClosingBraceRange.location = NSNotFound;
        }
        
        if(entryClosingBraceRange.location == NSNotFound && nextAtRange.location != fullStringLength){ // there's another @entry here (next), but we can't find the brace for the present one (first)
            *hadProblems = YES;
            [BibTeXParser postParsingErrorNotification:@"Entry is missing a closing brace."
                                             errorType:@"Parse Error"
                                              fileName:filePath
                                            errorRange:[fullString lineRangeForRange:NSMakeRange(firstAtRange.location, 0)]];
            entryClosingBraceRange.location = nextAtRange.location;
        }
        
        // NSLog(@"Finished a bibitem, next one is at %i, following is at %@", firstAtRange.location, ( nextAtRange.location != NSNotFound ? [NSString stringWithFormat:@"%i", nextAtRange.location] : @"NSNotFound" ) );

        [pool release];
    }
    return bibItemArray;    
}

+ (NSMutableArray *)itemsFromData:(NSData *)inData
                              error:(BOOL *)hadProblems
                        frontMatter:(NSMutableString *)frontMatter
                           filePath:(NSString *)filePath{
	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
    int ok = 1;
    long cidx = 0; // used to scan through buf for annotes.
    int braceDepth = 0;
    
    BibItem *newBI = nil;

    // Strings read from file and added to Dictionary object
    char *fieldname = "\0";
    NSString *s = nil;
    NSString *sDeTexified = nil;
    NSString *sFieldName = nil;

    AST *entry = NULL;
    AST *field = NULL;
    int itemOrder = 1;
    BibAppController *appController = (BibAppController *)[NSApp delegate];
    NSString *entryType = nil;
    NSMutableArray *returnArray = [[NSMutableArray alloc] initWithCapacity:1];
    
    const char *buf = NULL; // (char *) malloc(sizeof(char) * [inData length]);

    //dictionary is the bibtex entry
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:6];
    const char * fs_path = NULL;
    NSString *tempFilePath = nil;
    BOOL usingTempFile = NO;
    FILE *infile = NULL;

    NSRange asciiRange;
    NSCharacterSet *asciiLetters;

    //This range defines ASCII, used for the invalid character check during file read
    //we include all the control characters, since anything bad in here should be caught by btparse
    asciiRange.location = 0;
    asciiRange.length = 127; //This should get everything through tilde
    asciiLetters = [NSCharacterSet characterSetWithRange:asciiRange];
    
    
    if( !([filePath isEqualToString:@"Paste/Drag"]) && [[NSFileManager defaultManager] fileExistsAtPath:filePath]){
        fs_path = [[NSFileManager defaultManager] fileSystemRepresentationWithPath:filePath];
        usingTempFile = NO;
    }else{
        tempFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSProcessInfo processInfo] globallyUniqueString]];
        [inData writeToFile:tempFilePath atomically:YES];
        fs_path = [[NSFileManager defaultManager] fileSystemRepresentationWithPath:tempFilePath];
        NSLog(@"using temporary file %@ - was it deleted?",tempFilePath);
        usingTempFile = YES;
    }
    
    infile = fopen(fs_path, "r");

    *hadProblems = NO;

    NS_DURING
       // [inData getBytes:buf length:[inData length]];
        buf = (const char *) [inData bytes];
    NS_HANDLER
        // if we couldn't convert it, we won't be able to read it: just give up.
        // maybe instead of giving up we should find a way to use lossyCString here... ?
        if ([[localException name] isEqualToString:NSCharacterConversionException]) {
            NSLog(@"Exception %@ raised in itemsFromString, handled by giving up.", [localException name]);
            inData = nil;
            NSBeep();
        }else{
            [localException raise];
        }
        NS_ENDHANDLER

        bt_initialize();
        bt_set_stringopts(BTE_PREAMBLE, BTO_EXPAND);
        bt_set_stringopts(BTE_REGULAR, BTO_MINIMAL);

        while(entry =  bt_parse_entry(infile, (char *)fs_path, 0, &ok)){
	    NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
            if (ok){
                // Adding a new BibItem
                if (bt_entry_metatype (entry) != BTE_REGULAR){
                    // put preambles etc. into the frontmatter string so we carry them along.
                    entryType = [NSString stringWithCString:bt_entry_type(entry)];
                    
                    if (frontMatter && [entryType isEqualToString:@"preamble"]){
                        [frontMatter appendString:@"\n@preamble{\""];
                        [frontMatter appendString:[NSString stringWithCString:bt_get_text(entry) ]];
                        [frontMatter appendString:@"\"}"];
                    }
                }else{
                    newBI = [[BibItem alloc] initWithType:
                        [[NSString stringWithCString:bt_entry_type(entry)] lowercaseString]
                                                 fileType:@"BibTeX"
                                                  authors:
                        [NSMutableArray arrayWithCapacity:0]];
					[newBI setFileOrder:itemOrder];
                    itemOrder++;
                    field = NULL;
                    // Returned special case handling of abstract & annote.
                    // Special case is there to avoid losing newlines that exist in preexisting files.
                    while (field = bt_next_field (entry, field, &fieldname))
                    {

                        if(!strcmp(fieldname, "annote") ||
                           !strcmp(fieldname, "abstract") ||
                           !strcmp(fieldname, "rss-description")){
                            if(field->down){
                                cidx = field->down->offset;

                                // the delimiter is at cidx-1
                                if(buf[cidx-1] == '{'){
                                    // scan up to the balanced brace
                                    for(braceDepth = 1; braceDepth > 0; cidx++){
                                        if(buf[cidx] == '{') braceDepth++;
                                        if(buf[cidx] == '}') braceDepth--;
                                    }
                                    cidx--;     // just advanced cidx one past the end of the field.
                                }else if(buf[cidx-1] == '"'){
                                    // scan up to the next quote.
                                    for(; buf[cidx] != '"'; cidx++);
                                }
                                s = [NSString stringWithCString:&buf[field->down->offset] length:(cidx- (field->down->offset))];
                            }else{
                                *hadProblems = YES;
                            }
                        }else{
                            s = [NSString stringWithCString:bt_get_text(field)];
                        }

                        // Now that we have the string from the file, check for invalid characters:
                        
                        //Begin check for valid characters (ASCII); otherwise we mangle the .bib file every time we write out
                        //by inserting two characters for every extended character.

                        // Note (mmcc) : This is necessary only when CharacterConversion.plist doesn't cover a character that's in the file - this may be fixable in BDSKConverter also.
                        
                        NSScanner *validscan;
                        NSString *validscanstring = nil;
                                                
                        validscan = [NSScanner scannerWithString:s];  //Scan string s after we get it from bt
                        
                        [validscan setCharactersToBeSkipped:nil]; //If the first character is a newline or whitespace, NSScanner will skip it by default, which gives a bad length value
                        BOOL scannedCharacters = [validscan scanCharactersFromSet:asciiLetters intoString:&validscanstring];
                        
                        if(scannedCharacters && ([validscanstring length] != [s length])) //Compare it to the original string
                        {
                            NSLog(@"This string was in the file: [%@]",s);
                            NSLog(@"This is the part we can read: [%@]",validscanstring);
                            int errorLine = field->line;
                            NSLog(@"Invalid characters at line [%i]",errorLine);
                            
                            // This sets up an error dictionary object and passes it to the listener
                            NSString *fileName = filePath;  //We call this fileName, but its actually trimmed in BibAppController
                            NSValue *lineNumber = [NSNumber numberWithInt:errorLine];  //Need NSValues for NSArray
                            NSString *errorClassName = @"warning"; //We call it a warning
                            NSString *errorMessage = @"Invalid characters"; //This is the actual error message for the table
                            //Need to make an NSDictionary, see BibAppController.m for implementation
                            NSDictionary *errDict = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:fileName, lineNumber, errorClassName, errorMessage, nil]
                                                                                forKeys:[NSArray arrayWithObjects:@"fileName", @"lineNumber", @"errorClassName", @"errorMessage", nil]];
                            *hadProblems = YES; //Set this before we post the notification
                            //Maybe the dictionary should be passed as userInfo:errDict, but BibAppController expects object:errDict.
                            [[NSNotificationCenter defaultCenter] postNotificationName:@"BTPARSE ERROR"
                                                                                object:errDict];
                            
                        }
                        //End check for valid characters.
                        
                        //deTeXify it (includes conversion of /par to \n\n.)
                        sDeTexified = [[BDSKConverter sharedConverter] stringByDeTeXifyingString:s];
                        //Get fieldname as a capitalized NSString
                        sFieldName = [[NSString stringWithCString: fieldname] capitalizedString];

                        [dictionary setObject:sDeTexified forKey:sFieldName];

                        [appController addString:sDeTexified forCompletionEntry:sFieldName];

                    }// end while field - process next bt field
            
                    [newBI setCiteKeyString:[NSString stringWithCString:bt_entry_key(entry)]];
                    [newBI setPubFields:dictionary];
                    [returnArray addObject:[newBI autorelease]];
                    
                    [dictionary removeAllObjects];
                }
            }else{
                // wasn't ok, record it and deal with it later.
                *hadProblems = YES;
            }
            bt_free_ast(entry);
	    [innerPool release];
        } // while (scanning through file) 

        bt_cleanup();

        if(tempFilePath){
            if (![[NSFileManager defaultManager] removeFileAtPath:tempFilePath handler:nil]) {
                NSLog(@"itemsFromString Failed to delete temporary file. (%@)", tempFilePath);
            }
        }
        fclose(infile);
        if(usingTempFile){
            if(remove(fs_path)){
                NSLog(@"Error - unable to remove temporary file %@", tempFilePath);
            }
        }
        // @@readonly free(buf);
		
		[pool release];
        return [returnArray autorelease];
}


@end

//
//  BibTeXParser.m
//  Bibdesk
//
//  Created by Michael McCracken on Thu Nov 28 2002.
//  Copyright (c) 2002 __MyCompanyName__. All rights reserved.
//

#import "BibTeXParser.h"


@interface BibTeXParser (Private)

// private function to do ASCII checking.
NSString * checkAndTranslateString(NSString *s, int line, NSString *filePath, NSStringEncoding parserEncoding);

// private function to get array value from field:
// "foo" # macro # {string} # 19
// becomes an autoreleased array of dicts of different types.
NSString *stringFromBTField(AST *field, 
							NSString *fieldName, 
							NSString *filePath,
							BibDocument* theDocument);

- (void)postParsingErrorNotification:(NSString *)message errorType:(NSString *)type fileName:(NSString *)name errorRange:(NSRange)range;

@end

@implementation BibTeXParser

- (id)init{
    if(self = [super init])
    return self;
}

- (void)dealloc{
    [super dealloc];
}

/// libbtparse methods
+ (NSMutableArray *)itemsFromData:(NSData *)inData
                              error:(BOOL *)hadProblems{
    if(![inData length]) // btparse chokes on non-BibTeX or empty data, so we'll at least check for zero length
        return [NSMutableArray array];
    BibTeXParser *parser = [[[BibTeXParser alloc] init] autorelease];
    return [parser itemsFromData:inData error:hadProblems frontMatter:nil filePath:@"Paste/Drag" document:nil];
}

+ (NSMutableArray *)itemsFromData:(NSData *)inData error:(BOOL *)hadProblems frontMatter:(NSMutableString *)frontMatter filePath:(NSString *)filePath document:(BibDocument *)aDocument{
    if(![inData length]) // btparse chokes on non-BibTeX or empty data, so we'll at least check for zero length
        return [NSMutableArray array];
    BibTeXParser *parser = [[[BibTeXParser alloc] init] autorelease];
    return [parser itemsFromData:inData error:hadProblems frontMatter:frontMatter filePath:filePath document:aDocument];
}

- (void)setDocument:(BibDocument *)aDocument{
    theDocument = aDocument;
}

- (BibDocument *)document{
    return theDocument;
}

- (NSMutableArray *)itemsFromData:(NSData *)inData
                            error:(BOOL *)hadProblems
                      frontMatter:(NSMutableString *)frontMatter
                         filePath:(NSString *)filePath
                         document:(BibDocument *)aDocument{
	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
    int ok = 1;
    long cidx = 0; // used to scan through buf for annotes.
    int braceDepth = 0;
    
    BibItem *newBI = nil;

    // Strings read from file and added to Dictionary object
    char *fieldname = "\0";
    NSString *s = nil;
    NSString *sFieldName = nil;
    NSString *complexString = nil;
	
    AST *entry = NULL;
    AST *field = NULL;
    int itemOrder = 1;
    NSString *entryType = nil;
    NSMutableArray *returnArray = [[NSMutableArray alloc] initWithCapacity:1];
    
    const char *buf = NULL; // (char *) malloc(sizeof(char) * [inData length]);

    //dictionary is the bibtex entry
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:6];
    
    const char * fs_path = NULL;
    NSString *tempFilePath = nil;
    BOOL usingTempFile = NO;
    FILE *infile = NULL;
    
    [self setDocument:aDocument];
    NSStringEncoding parserEncoding;
    if(!aDocument)
        parserEncoding = [NSString defaultCStringEncoding]; // is this a good assumption?  only used for pasteboard stuff.
    else
        parserEncoding = [[self document] documentStringEncoding]; 
    
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
                entryType = [NSString stringWithBytes:bt_entry_type(entry) encoding:parserEncoding];

                if (bt_entry_metatype (entry) != BTE_REGULAR){
                    // put preambles etc. into the frontmatter string so we carry them along.
                    
                    if (frontMatter && [entryType isEqualToString:@"preamble"]){
                        [frontMatter appendString:@"\n@preamble{\""];
                        [frontMatter appendString:[NSString stringWithBytes:bt_get_text(entry) encoding:parserEncoding]];
                        [frontMatter appendString:@"\"}"];
                    }else if(frontMatter && [entryType isEqualToString:@"string"]){
						field = bt_next_field (entry, NULL, &fieldname);
						NSString *macroKey = [NSString stringWithBytes: field->text encoding:parserEncoding];
						NSString *macroString = [NSString stringWithBytes: field->down->text encoding:parserEncoding];                        
                        if(theDocument)
                            [theDocument addMacroDefinitionWithoutUndo:macroString
                                                   forMacro:macroKey];
					}
                }else{
                    newBI = [[BibItem alloc] initWithType:[entryType lowercaseString]
                                                 fileType:BDSKBibtexString
                                                  authors:[NSMutableArray arrayWithCapacity:0]
                                              createdDate:nil];
					[newBI setFileOrder:itemOrder];
                    itemOrder++;
                    field = NULL;
                    // Returned special case handling of abstract & annote.
                    // Special case is there to avoid losing newlines that exist in preexisting files.
                    while (field = bt_next_field (entry, field, &fieldname))
                    {
                        //Get fieldname as a capitalized NSString
                        sFieldName = [[NSString stringWithBytes: fieldname encoding:parserEncoding] capitalizedString];
                        
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
                                complexString = [[[NSString alloc] initWithData:[NSData dataWithBytes:&buf[field->down->offset] length:(cidx- (field->down->offset))] encoding:parserEncoding] autorelease];
                            }else{
                                *hadProblems = YES;
                            }
                        }else{
                            complexString = stringFromBTField(field, sFieldName, filePath, theDocument);
                        }
                        
                        [dictionary setObject:complexString forKey:sFieldName];

                    }// end while field - process next bt field                    
					
                    [newBI setCiteKeyString:[NSString stringWithBytes:bt_entry_key(entry) encoding:parserEncoding]];
                    [newBI setPubFields:dictionary];
                    [returnArray addObject:[newBI autorelease]];
                    
                    [dictionary removeAllObjects];
                } // end generate BibItem from ENTRY metatype.
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

- (void)postParsingErrorNotification:(NSString *)message errorType:(NSString *)type fileName:(NSString *)name errorRange:(NSRange)range{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    NSDictionary *errorDict = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:name, [NSNull null], type, message, [NSValue valueWithRange:range], nil]
                                                          forKeys:[NSArray arrayWithObjects:@"fileName", @"lineNumber", @"errorClassName", @"errorMessage", @"errorRange", nil]];
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKParserErrorNotification
                                                        object:errorDict];
    [pool release];
}

@end

/// private functions used with libbtparse code

NSString * checkAndTranslateString(NSString *s, int line, NSString *filePath, NSStringEncoding parserEncoding){
    if(![s canBeConvertedToEncoding:parserEncoding]){
        NSString *type = NSLocalizedString(@"Error", @"");
        NSString *message = NSLocalizedString(@"Unable to convert characters to the specified encoding.", @"");
        NSDictionary *errorDict = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:filePath, [NSNumber numberWithInt:line], type, message, nil]
                                                              forKeys:[NSArray arrayWithObjects:@"fileName", @"lineNumber", @"errorClassName", @"errorMessage", nil]];
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKParserErrorNotification
                                                            object:errorDict];
        // make sure the error panel is displayed, regardless of prefs; we can't show the "Keep going/data loss" alert, though
        [[NSApp delegate] performSelectorOnMainThread:@selector(showErrorPanel:) withObject:nil waitUntilDone:NO];
    }
    
    //deTeXify it
    NSString *sDeTexified = [[BDSKConverter sharedConverter] stringByDeTeXifyingString:s];
    return sDeTexified;
}

NSString *stringFromBTField(AST *field, NSString *fieldName, NSString *filePath, BibDocument* document){
    BibAppController *appController = (BibAppController *)[NSApp delegate];
    NSMutableArray *stringValueArray = [[NSMutableArray alloc] initWithCapacity:10];
    NSString *s = NULL;
    BDSKStringNode *sNode;
    AST *simple_value;
    
    NSStringEncoding parserEncoding;
    if(!document)
        parserEncoding = [NSString defaultCStringEncoding];
    else
        parserEncoding = [document documentStringEncoding]; 
    
	if(field->nodetype != BTAST_FIELD){
		NSLog(@"error! expected field here");
	}
	simple_value = field->down;
	
	char *expanded_text = NULL;
	
	while(simple_value){
        if (simple_value->text){
            switch (simple_value->nodetype){
                case BTAST_MACRO:
                    s = [[NSString alloc] initWithBytes:simple_value->text encoding:parserEncoding];
                    
                    // We parse the macros in itemsFromData, but for reference, if we wanted to get the 
                    // macro value we could do this:
                    // expanded_text = bt_macro_text (simple_value->text, (char *)[filePath fileSystemRepresentation], simple_value->line);
                    sNode = [BDSKStringNode nodeWithMacroString:s];
                    
                    break;
                case BTAST_STRING:
                    s = [[NSString alloc] initWithBytes:simple_value->text encoding:parserEncoding];
                    sNode = [BDSKStringNode nodeWithQuotedString:checkAndTranslateString(s, field->line, filePath, parserEncoding)];
                    
                    break;
                case BTAST_NUMBER:
                    s = [[NSString alloc] initWithBytes:simple_value->text encoding:parserEncoding];
                    sNode = [BDSKStringNode nodeWithNumberString:s];
                    
                    break;
                default:
                    [NSException raise:@"bad node type exception" format:@"Node type %d is unexpected.", simple_value->nodetype];
            }
            [stringValueArray addObject:sNode];
            
            // if we have multiple strings for one field, we add them separately.
            [appController addString:s forCompletionEntry:fieldName]; 
            [s release];
            [sNode release];
        }
        
            simple_value = simple_value->right;
	} // while simple_value
	
    // Common case: return a solo string as a non-complex string.
    
    if([stringValueArray count] == 1 &&
       [(BDSKStringNode *)[stringValueArray objectAtIndex:0] type] == BSN_STRING){
        return [(BDSKStringNode *)[stringValueArray objectAtIndex:0] value]; // an NSString
    }
    
    return [NSString complexStringWithArray:stringValueArray macroResolver:document];
}


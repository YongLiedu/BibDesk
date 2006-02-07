//
//  BDSKBibTeXParser.m
//  bd2xtest
//
//  Created by Christiaan Hofman on 2/6/06.
//  Copyright 200. All rights reserved.
//

#import "BDSKBibTeXParser.h"
#import <BTParse/btparse.h>
#import <BTParse/error.h>
#include <stdio.h>
#import "BDSKDocument.h"
#import <CoreFoundation/CoreFoundation.h>


@interface BDSKBibTeXParser (Private)

NSString *stringFromBTField(AST *field, NSString *fieldName, NSString *filePath, BDSKDocument *document);
NSArray *personNamesFromBibTeXString(NSString *aString);
NSManagedObject *publicationFromDictionary(NSString *citeKey, NSDictionary *dictionary, BDSKDocument *document);
void deletePublicationsAndRelationships(NSSet *publications, BDSKDocument *document);

@end

@implementation BDSKBibTeXParser

+ (NSSet *)itemsFromData:(NSData *)data error:(BOOL *)hadProblems document:(BDSKDocument *)document {
    return [self itemsFromData:data error:hadProblems frontMatter:nil filePath:@"Paste/Drag" document:document];
}

+ (NSSet *)itemsFromData:(NSData *)data error:(BOOL *)hadProblems frontMatter:(NSMutableString *)frontMatter filePath:(NSString *)filePath document:(BDSKDocument *)document {
	if(![data length]) // btparse chokes on non-BibTeX or empty data, so we'll at least check for zero length
        return [NSSet set];
		
    int ok = 1;
    long cidx = 0; // used to scan through buf for annotes.
    int braceDepth = 0;
    
    NSManagedObject *newPublication = nil;

    // Strings read from file and added to Dictionary object
    char *fieldname = "\0";
    NSString *sFieldName = nil;
    NSString *complexString = nil;
	
    AST *entry = NULL;
    AST *field = NULL;

    NSString *entryType = nil;
    NSMutableSet *returnSet = [[NSMutableSet alloc] initWithCapacity:1];
    
    const char *buf = NULL;

    //dictionary is the bibtex entry
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:6];
    
    const char * fs_path = NULL;
    FILE *infile = NULL;
    
    // TODO: get encoding from document
    NSStringEncoding parserEncoding = NSUTF8StringEncoding;
    
    if( !([filePath isEqualToString:@"Paste/Drag"]) && [[NSFileManager defaultManager] fileExistsAtPath:filePath]){
        fs_path = [[NSFileManager defaultManager] fileSystemRepresentationWithPath:filePath];
        infile = fopen(fs_path, "r");
    }else{
        infile = [data openReadOnlyStandardIOFile];
        fs_path = NULL; // used for error context in libbtparse
    }    

    *hadProblems = NO;

    buf = (const char *) [data bytes];

    bt_initialize();
    bt_set_stringopts(BTE_PREAMBLE, BTO_EXPAND);
    bt_set_stringopts(BTE_REGULAR, BTO_COLLAPSE);
    
    NSString *tmpStr = nil;

    while(entry =  bt_parse_entry(infile, (char *)fs_path, 0, &ok)){

        if (ok){
            // Adding a new Publication
            tmpStr = [[NSString alloc] initWithBytes:bt_entry_type(entry) encoding:parserEncoding];
            entryType = [tmpStr lowercaseString];
            [tmpStr release];
            
            if (bt_entry_metatype (entry) != BTE_REGULAR){
                // put preambles etc. into the frontmatter string so we carry them along.
                
                if (frontMatter && [entryType isEqualToString:@"preamble"]){
                    [frontMatter appendString:@"\n@preamble{\""];
                    field = NULL;
                    bt_nodetype type = BTAST_STRING;
                    BOOL paste = NO;
                    // bt_get_text() just gives us \\ne for the field, so we'll manually traverse it and poke around in the AST to get what we want.  This is sort of nasty, so if someone finds a better way, go for it.
                    while(field = bt_next_value(entry, field, &type, NULL)){
                        char *text = field->text;
                        if(text){
                            if(paste) [frontMatter appendString:@"\" #\n   \""];
                            tmpStr = [[NSString alloc] initWithBytes:text encoding:parserEncoding];
                            if(tmpStr) 
                                [frontMatter appendString:tmpStr];
                            else
                                NSLog(@"Possible encoding error: unable to create NSString from %s", text);
                            [tmpStr release];
                            paste = YES;
                        }
                    }
                    [frontMatter appendString:@"\"}"];
                }else if(frontMatter && [entryType isEqualToString:@"string"]){
                    field = bt_next_field (entry, NULL, &fieldname);
                    NSString *macroKey = [[NSString alloc] initWithBytes: field->text encoding:parserEncoding];
                    tmpStr = [[NSString alloc] initWithBytes: field->down->text encoding:parserEncoding];                        
                    /* TODO: macros
                    if(document)
                        [document addMacroDefinitionWithoutUndo:tmpStr
                                                        forMacro:macroKey];
                    */
                    [tmpStr release];
                    [macroKey release];
                }else if(frontMatter && [entryType isEqualToString:@"comment"]){
					NSMutableString *commentStr = [[NSMutableString alloc] init];
					field = NULL;
                    char *text = NULL;
                    
					while(field = bt_next_value(entry, field, NULL, &text)){
						if(text){
                            // encoding will be UTF-8 for the plist, so make sure we use it for each line
							tmpStr = [[NSString alloc] initWithBytes:text encoding:parserEncoding];
                            
							if(tmpStr) 
                                [commentStr appendString:tmpStr];
                            else
                                NSLog(@"Possible encoding error: unable to create NSString from %s", text);
							[tmpStr release];
						}
					}
                    [frontMatter appendString:@"\n@comment{"];
                    [frontMatter appendString:commentStr];
                    [frontMatter appendString:@"}"];
					[commentStr release];
                }
            }else{
                field = NULL;
                // Special case handling of abstract & annote is to avoid losing newlines in preexisting files.
                while (field = bt_next_field (entry, field, &fieldname))
                {
                    //Get fieldname as a capitalized NSString
                    tmpStr = [[NSString alloc] initWithBytes:fieldname encoding:parserEncoding];
                    sFieldName = [tmpStr capitalizedString];
                    [tmpStr release];
                    
                    if([sFieldName isEqualToString:@"Annote"] || 
                       [sFieldName isEqualToString:@"Abstract"] || 
                       [sFieldName isEqualToString:@"Rss-Description"]){
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
                            }else [NSException raise:NSInternalInconsistencyException format:@"Unexpected delimiter \"%@\" reached at line %d", [NSString stringWithBytes:&buf[cidx-1] encoding:parserEncoding], field->line];
                            tmpStr = [[NSString alloc] initWithBytes:&buf[field->down->offset] length:(cidx- (field->down->offset)) encoding:parserEncoding];
                            // TODO: deTeXify
                            complexString = [tmpStr autorelease];
                        }else{
                            *hadProblems = YES;
                        }
                    }else{
                        complexString = stringFromBTField(field, sFieldName, filePath, document);
                    }
                    
                    [dictionary setObject:complexString forKey:sFieldName];
                    
                }// end while field - process next bt field                    

                tmpStr = [[NSString alloc] initWithBytes:bt_entry_key(entry) encoding:parserEncoding];
                [dictionary setObject:[entryType lowercaseString] forKey:@"Type"];
                if ([filePath isEqualToString:@"Paste/Drag"]) {
                    NSString *dateStr = [[NSCalendarDate date] description];
                    [dictionary setObject:dateStr forKey:@"Date-Added"];
                    [dictionary setObject:dateStr forKey:@"Date-Modified"];
                }
                newPublication = publicationFromDictionary(tmpStr, dictionary, document);
                [tmpStr release];
                
                [returnSet addObject:newPublication];
                
                [dictionary removeAllObjects];
            } // end generate BibItem from ENTRY metatype.
        }else{
            // wasn't ok, record it and deal with it later.
            *hadProblems = YES;
        }
        bt_free_ast(entry);

    } // while (scanning through file) 
    
    bt_cleanup();

    fclose(infile);
    // @@readonly free(buf);
    
    if(*hadProblems){
        NSLog(@"Problems parsing BibTeX");
        // is there a way to never add them in the first place?
        deletePublicationsAndRelationships(returnSet, document);
        [returnSet removeAllObjects];
    }
    
    return [returnSet autorelease];
}

@end


// TODO: deTeXify
NSString *stringFromBTField(AST *field, NSString *fieldName, NSString *filePath, BDSKDocument *document){
    NSMutableString *returnValue = [[NSMutableString alloc] init];
    NSString *s = nil;
    AST *simple_value;
    
    NSStringEncoding parserEncoding = NSUTF8StringEncoding;
    
	if(field->nodetype != BTAST_FIELD){
		NSLog(@"error! expected field here");
	}
	simple_value = field->down;
		
	while(simple_value){
        if (simple_value->text){
            // for now we just expand complex strings without macro dictionary
            s = [[NSString alloc] initWithBytes:simple_value->text encoding:parserEncoding];
            [returnValue appendString:s];
            [s release];
        }
        
        simple_value = simple_value->right;
	} // while simple_value
    
    return returnValue;
}

NSArray *personNamesFromBibTeXString(NSString *aString){
    char *str = nil;
	NSMutableArray *namesArray = [[NSMutableArray alloc] initWithCapacity:1];
    
    if (aString == nil || [aString isEqualToString:@""]){
        return [namesArray autorelease];
    }
    
    // TODO: we're supposed to collapse whitespace before using bt_split_name, and author names with surrounding whitespace don't display in the table (probably for that reason)
    //aString = [aString fastStringByCollapsingWhitespaceAndRemovingSurroundingWhitespace];
    
    str = (char *)[aString UTF8String];
    
    bt_stringlist *sl = nil;
    int i=0;
    
    NSString *s;
    
    // used as an error description
    NSString *shortDescription = [[NSString alloc] initWithFormat:NSLocalizedString(@"reading authors string %@", @"need an string format specifier"), aString];
    
    sl = bt_split_list(str, "and", "BibTex Name", 0, (char *)[shortDescription UTF8String]);
    
    if (sl != nil) {
        for(i=0; i < sl->num_items; i++){
            if(sl->items[i] != nil){
                s = [[NSString alloc] initWithUTF8String:(sl->items[i])];
				[namesArray addObject:s];
                [s release];
            }
        }
        bt_free_list(sl); // hey! got to free the memory!
    }
    [shortDescription release];
	
	return [namesArray autorelease];
}

NSManagedObject *publicationFromDictionary(NSString *citeKey, NSDictionary *dictionary, BDSKDocument *document){
    NSManagedObjectContext *moc = [document managedObjectContext];
	
    NSManagedObject *publication = [NSEntityDescription insertNewObjectForEntityForName:@"Publication" inManagedObjectContext:moc];
    
    NSMutableSet *keyValuePairs = [publication mutableSetValueForKey:@"keyValuePairs"];
    NSMutableSet *contributors = [publication mutableSetValueForKey:@"contributorRelationships"];
    NSMutableSet *notes = [publication mutableSetValueForKey:@"notes"];
    
    NSEnumerator *keyEnum = [dictionary keyEnumerator];
    NSString *key;
    NSString *value;
    
    //[publications setValue:citeKey forKey:@"citeKey"];
    NSManagedObject *keyValuePair = [NSEntityDescription insertNewObjectForEntityForName:@"KeyValuePair" inManagedObjectContext:moc];
    [keyValuePair setValue:@"Cite-Key" forKey:@"key"];
    [keyValuePair setValue:citeKey forKey:@"value"];
    [keyValuePairs addObject:keyValuePair];
    
    while (key = [keyEnum nextObject]) {
        value = [dictionary objectForKey:key];
        key = [key capitalizedString];
        if ([key isEqualToString:@"Author"] || [key isEqualToString:@"Editor"]) {
            NSArray *names = personNamesFromBibTeXString(value);
            NSEnumerator *nameEnum = [names objectEnumerator];
            NSString *name;
            NSManagedObject *person;
            NSManagedObject *relationship;
            while (name = [nameEnum nextObject]) {
                 // TODO: identify persons with the same name
                 person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:moc];
                 relationship = [NSEntityDescription insertNewObjectForEntityForName:@"ContributorPublicationRelationship" inManagedObjectContext:moc];
                 [person setValue:name forKey:@"name"];
                 [relationship setValue:person forKey:@"contributor"];
                 [relationship setValue:[key lowercaseString] forKey:@"relationshipType"];
                 [relationship setValue:[NSNumber numberWithInt:[contributors count]] forKey:@"index"];
                 [contributors addObject:relationship];
            }
        } else if ([key isEqualToString:@"Annotation"]) {
            NSManagedObject *note = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:moc];
            [notes addObject:note];
        } else if ([key isEqualToString:@"Journal"]) {
            NSManagedObject *venue = [NSEntityDescription insertNewObjectForEntityForName:@"Venue" inManagedObjectContext:moc];
            [venue setValue:value forKey:@"name"];
            [publication setValue:venue forKey:@"venue"];
        } else if ([key isEqualToString:@"Title"]) {
            [publication setValue:value forKey:@"title"];
        } else if ([key isEqualToString:@"Short-Title"]) {
            [publication setValue:value forKey:@"shortTitle"];
        } else if ([key isEqualToString:@"Date-Added"]) {
            [publication setValue:[NSDate dateWithNaturalLanguageString:value] forKey:@"dateAdded"];
        } else if ([key isEqualToString:@"Date-Modified"]) {
            [publication setValue:[NSDate dateWithNaturalLanguageString:value] forKey:@"dateChanged"];
        } else {
            NSManagedObject *keyValuePair = [NSEntityDescription insertNewObjectForEntityForName:@"KeyValuePair" inManagedObjectContext:moc];
            [keyValuePair setValue:key forKey:@"key"];
            [keyValuePair setValue:value forKey:@"value"];
            [keyValuePairs addObject:keyValuePair];
        }
    }
    return publication;
}

void deletePublicationsAndRelationships(NSSet *publications, BDSKDocument *document){
    NSManagedObjectContext *moc = [document managedObjectContext];
    NSEnumerator *moEnum;
    NSManagedObject *mo;
    
    moEnum = [[publications valueForKeyPath:@"@distinctUnionOfSets.contributorRelationships.contributor"] objectEnumerator];
    while (mo = [moEnum nextObject]) {
        [moc deleteObject:mo]; // this implicitly deletes the relationship entity
    }
    
    moEnum = [[publications valueForKeyPath:@"@distinctUnionOfSets.notes"] objectEnumerator];
    while (mo = [moEnum nextObject]) {
        [moc deleteObject:mo];
    }
    
    moEnum = [[publications valueForKeyPath:@"@distinctUnionOfSets.keyValuePairs"] objectEnumerator];
    while (mo = [moEnum nextObject]) {
        [moc deleteObject:mo];
    }
    
    moEnum = [[publications valueForKeyPath:@"venue"] objectEnumerator];
    while (mo = [moEnum nextObject]) {
        [moc deleteObject:mo];
    }
    
    moEnum = [publications objectEnumerator];
    while (mo = [moEnum nextObject]) {
        [moc deleteObject:mo];
    }
}


@implementation NSString (BDSKExtensions)
 
+ (NSString *)stringWithBytes:(const char *)byteString encoding:(NSStringEncoding)encoding{
    return byteString == NULL ? nil : [(NSString *)CFStringCreateWithCString(CFAllocatorGetDefault(), byteString, CFStringConvertNSStringEncodingToEncoding(encoding)) autorelease];
}

- (NSString *)initWithBytes:(const char *)byteString encoding:(NSStringEncoding)encoding{
    return byteString == NULL ? nil : (NSString *)CFStringCreateWithCString(CFAllocatorGetDefault(), byteString, CFStringConvertNSStringEncodingToEncoding(encoding));
}

@end


@implementation NSData (BDSKExtensions)

/*" Creates a stdio FILE pointer for reading from the receiver via the funopen() BSD facility.  The receiver is automatically retained until the returned FILE is closed. "*/

// Same context used for read and write.
typedef struct _NSDataFileContext {
    NSData *data;
    void   *bytes;
    size_t  length;
    size_t  position;
} NSDataFileContext;

static int _NSData_readfn(void *_ctx, char *buf, int nbytes)
{
    //fprintf(stderr, " read(ctx:%p buf:%p nbytes:%d)\n", _ctx, buf, nbytes);
    NSDataFileContext *ctx = (NSDataFileContext *)_ctx;

    nbytes = MIN((unsigned)nbytes, ctx->length - ctx->position);
    memcpy(buf, ctx->bytes + ctx->position, nbytes);
    ctx->position += nbytes;
    return nbytes;
}

static fpos_t _NSData_seekfn(void *_ctx, off_t offset, int whence)
{
    //fprintf(stderr, " seek(ctx:%p off:%qd whence:%d)\n", _ctx, offset, whence);
    NSDataFileContext *ctx = (NSDataFileContext *)_ctx;

    size_t reference;
    if (whence == SEEK_SET)
        reference = 0;
    else if (whence == SEEK_CUR)
        reference = ctx->position;
    else if (whence == SEEK_END)
        reference = ctx->length;
    else
        return -1;

    if (reference + offset >= 0 && reference + offset <= ctx->length) {
        ctx->position = reference + offset;
        return ctx->position;
    }
    return -1;
}

static int _NSData_closefn(void *_ctx)
{
    //fprintf(stderr, "close(ctx:%p)\n", _ctx);
    NSDataFileContext *ctx = (NSDataFileContext *)_ctx;
    [ctx->data release];
    free(ctx);
    
    return 0;
}


- (FILE *)openReadOnlyStandardIOFile {
    NSDataFileContext *ctx = calloc(1, sizeof(NSDataFileContext));
    ctx->data = [self retain];
    ctx->bytes = (void *)[self bytes];
    ctx->length = [self length];
    //fprintf(stderr, "open read -> ctx:%p\n", ctx);

    FILE *f = funopen(ctx, _NSData_readfn, NULL/*writefn*/, _NSData_seekfn, _NSData_closefn);
    if (f == NULL)
        [self release]; // Don't leak ourselves if funopen fails
    return f;
}

@end


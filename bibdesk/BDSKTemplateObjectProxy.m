//
//  BDSKTemplateObjectProxy.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 10/10/06.
/*
 This software is Copyright (c) 2006-2010
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

#import "BDSKTemplateObjectProxy.h"
#import "BDSKTemplate.h"
#import "BibItem.h"
#import "NSTask_BDSKExtensions.h"
#import "BDSKTask.h"


@implementation BDSKTemplateObjectProxy

+ (NSString *)stringByParsingTemplate:(BDSKTemplate *)template withObject:(id)anObject publications:(NSArray *)items {
    return [self stringByParsingTemplate:template withObject:anObject publications:items publicationsContext:nil];
}

+ (NSString *)stringByParsingTemplate:(BDSKTemplate *)template withObject:(id)anObject publications:(NSArray *)items publicationsContext:(NSArray *)itemsContext {
    NSString *string = [template mainPageString];
    NSString *scriptPath = [template scriptPath];
    BDSKTemplateObjectProxy *objectProxy = [[self alloc] initWithObject:anObject publications:items publicationsContext:itemsContext template:template];
    string = [BDSKTemplateParser stringByParsingTemplateString:string usingObject:objectProxy delegate:objectProxy];
    [objectProxy release];
    if(scriptPath)
        string = [BDSKTask outputStringFromTaskWithLaunchPath:scriptPath arguments:nil inputString:string];
    return string;
}

+ (NSAttributedString *)attributedStringByParsingTemplate:(BDSKTemplate *)template withObject:(id)anObject publications:(NSArray *)items documentAttributes:(NSDictionary **)docAttributes {
    return [self attributedStringByParsingTemplate:template withObject:anObject publications:items publicationsContext:nil documentAttributes:docAttributes];
}

+ (NSAttributedString *)attributedStringByParsingTemplate:(BDSKTemplate *)template withObject:(id)anObject publications:(NSArray *)items publicationsContext:(NSArray *)itemsContext documentAttributes:(NSDictionary **)docAttributes {
    NSAttributedString *attrString = nil;
    NSString *scriptPath = [template scriptPath];
    if(scriptPath == nil){
        BDSKTemplateObjectProxy *objectProxy = [[self alloc] initWithObject:anObject publications:items publicationsContext:itemsContext template:template];
        attrString = [template mainPageAttributedStringWithDocumentAttributes:docAttributes];
        attrString = [BDSKTemplateParser attributedStringByParsingTemplateAttributedString:attrString usingObject:objectProxy delegate:objectProxy];
        [objectProxy release];
    }else{
        NSString *docType = nil;
        BDSKTemplateFormat templateFormat = [template templateFormat];
        if(templateFormat == BDSKRichHTMLTemplateFormat)
            docType = NSHTMLTextDocumentType;
        if(templateFormat == BDSKRTFTemplateFormat)
            docType = NSRTFTextDocumentType;
        else if(templateFormat == BDSKRTFDTemplateFormat)
            docType = NSRTFDTextDocumentType;
        else if(templateFormat == BDSKDocTemplateFormat)
            docType = NSDocFormatTextDocumentType;
        else if(templateFormat == BDSKDocxTemplateFormat)
            docType = NSOfficeOpenXMLTextDocumentType;
        else if(templateFormat == BDSKOdtTemplateFormat)
            docType = NSOpenDocumentTextDocumentType;
        else if(templateFormat == BDSKWebArchiveTemplateFormat)
            docType = NSWebArchiveTextDocumentType;
        NSData *data = [self dataByParsingTemplate:template withObject:anObject publications:items];
        attrString = [[[NSAttributedString alloc] initWithData:data options:[NSDictionary dictionaryWithObjectsAndKeys:docType, NSDocumentTypeDocumentOption, nil] documentAttributes:NULL error:NULL] autorelease];
    }
    return attrString;
}

+ (NSData *)dataByParsingTemplate:(BDSKTemplate *)template withObject:(id)anObject publications:(NSArray *)items {
    return [self dataByParsingTemplate:template withObject:anObject publications:items publicationsContext:nil];
}

+ (NSData *)dataByParsingTemplate:(BDSKTemplate *)template withObject:(id)anObject publications:(NSArray *)items publicationsContext:(NSArray *)itemsContext {
    NSString *string = [template mainPageString];
    NSString *scriptPath = [template scriptPath];
    BDSKTemplateObjectProxy *objectProxy = [[self alloc] initWithObject:anObject publications:items publicationsContext:itemsContext template:template];
    string = [BDSKTemplateParser stringByParsingTemplateString:string usingObject:objectProxy delegate:objectProxy];
    [objectProxy release];
    return [BDSKTask outputDataFromTaskWithLaunchPath:scriptPath arguments:nil inputString:string];
}

- (id)initWithObject:(id)anObject publications:(NSArray *)items publicationsContext:(NSArray *)itemsContext template:(BDSKTemplate *)aTemplate {
    if (self = [super init]) {
        object = [anObject retain];
        publications = [items copy];
        publicationsContext = [itemsContext copy];
        template = [aTemplate retain];
    }
    return self;
}

- (void)dealloc {
    BDSKDESTROY(object);
    BDSKDESTROY(publications);
    BDSKDESTROY(publicationsContext);
    BDSKDESTROY(template);
    [super dealloc];
}

- (id)valueForUndefinedKey:(NSString *)key { return [object valueForKey:key]; }

- (NSArray *)publications {
    NSUInteger idx = 0;
    
    for (BibItem *pub in publications) {
        if (publicationsContext) {
            idx = [publicationsContext indexOfObject:pub];
            if (idx == NSNotFound)
                idx = 0;
        } else {
            ++idx;
        }
        [pub setItemIndex:idx];
    }
    
    [publications makeObjectsPerformSelector:@selector(prepareForTemplateParsing)];
    
    return publications;
}

- (id)publicationsUsingTemplate{
    BibItem *pub = nil;
    
    BDSKPRECONDITION(nil != template);
    BDSKTemplateFormat format = [template templateFormat];
    id returnString = nil;
    NSAutoreleasePool *pool = nil;
    NSMutableDictionary *parsedTemplates = [NSMutableDictionary dictionary];
    NSArray *parsedTemplate;
    NSInteger currentIndex = 0;
    
    if (format & BDSKPlainTextTemplateFormat) {
        
        returnString = [NSMutableString stringWithString:@""];        
        for (pub in [self publications]){
            pool = [NSAutoreleasePool new];
            parsedTemplate = [parsedTemplates objectForKey:[pub pubType]];
            if (parsedTemplate == nil) {
                if ([template templateURLForType:[pub pubType]]) {
                    parsedTemplate = [BDSKTemplateParser arrayByParsingTemplateString:[template stringForType:[pub pubType]]];
                } else {
                    parsedTemplate = [parsedTemplates objectForKey:BDSKTemplateDefaultItemString];
                    if (parsedTemplate == nil) {
                        parsedTemplate = [BDSKTemplateParser arrayByParsingTemplateString:[template stringForType:BDSKTemplateDefaultItemString]];
                        BDSKPRECONDITION(nil != parsedTemplate);
                        [parsedTemplates setObject:parsedTemplate forKey:BDSKTemplateDefaultItemString];
                    }
                }
                BDSKPRECONDITION(nil != parsedTemplate);
                if (parsedTemplate)
                    [parsedTemplates setObject:parsedTemplate forKey:[pub pubType]];
            }
            [pub prepareForTemplateParsing];
            [returnString appendString:[BDSKTemplateParser stringFromTemplateArray:parsedTemplate usingObject:pub atIndex:++currentIndex]];
            [pub cleanupAfterTemplateParsing];
            [pool release];
        }
        
    } else if (format & BDSKRichTextTemplateFormat) {
        
        returnString = [[[NSMutableAttributedString alloc] init] autorelease];
        for (pub in [self publications]){
            pool = [NSAutoreleasePool new];
            parsedTemplate = [parsedTemplates objectForKey:[pub pubType]];
            if (parsedTemplate == nil) {
                if ([template templateURLForType:[pub pubType]]) {
                    parsedTemplate = [BDSKTemplateParser arrayByParsingTemplateAttributedString:[template attributedStringForType:[pub pubType]]];
                } else {
                    parsedTemplate = [parsedTemplates objectForKey:BDSKTemplateDefaultItemString];
                    if (parsedTemplate == nil) {
                        parsedTemplate = [BDSKTemplateParser arrayByParsingTemplateAttributedString:[template attributedStringForType:BDSKTemplateDefaultItemString]];
                        [parsedTemplates setObject:parsedTemplate forKey:BDSKTemplateDefaultItemString];
                    }
                }
                [parsedTemplates setObject:parsedTemplate forKey:[pub pubType]];
            }
            [pub prepareForTemplateParsing];
            [returnString appendAttributedString:[BDSKTemplateParser attributedStringFromTemplateArray:parsedTemplate usingObject:pub atIndex:++currentIndex]];
            [pub cleanupAfterTemplateParsing];
            [pool release];
        }
    }
    
    return returnString;
}

// legacy method, as it may appear as a key in older templates
- (id)publicationsAsHTML{ return [self publicationsUsingTemplate]; }

- (NSDate *)currentDate{ return [NSDate date]; }

// BDSKTemplateParserDelegate protocol
- (void)templateParserWillParseTemplate:(id)template usingObject:(id)anObject {
    if ([anObject respondsToSelector:@selector(prepareForTemplateParsing)])
        [(BibItem *)anObject prepareForTemplateParsing];
}

- (void)templateParserDidParseTemplate:(id)template usingObject:(id)anObject {
    if ([anObject respondsToSelector:@selector(cleanupAfterTemplateParsing)])
        [(BibItem *)anObject cleanupAfterTemplateParsing];
}

@end

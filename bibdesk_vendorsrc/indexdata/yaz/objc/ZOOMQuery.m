//
//  ZOOMQuery.m
//  yaz
//
//  Created by Adam Maxwell on 12/26/06.
/*
 Copyright (c) 2006-2016, Adam Maxwell
 All rights reserved.
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 * Neither the name of Adam Maxwell nor the names of its contributors
 may be used to endorse or promote products derived from this
 software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE CONTRIBUTORS ``AS IS'' AND ANY
 EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL THE CONTRIBUTORS BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/ 

#import <yaz/ZOOMQuery.h>
#import <yaz/yaz-iconv.h>

@implementation ZOOMQuery

+ (id)queryWithCCLString:(NSString *)queryString config:(NSString *)confString;
{
    return [[[self allocWithZone:[self zone]] initWithCCLString:queryString config:confString] autorelease];
}

+ (NSString *)defaultConfigString;
{
    static NSString *config = nil;
    if (nil == config) {
        NSBundle *bundle = [NSBundle bundleWithIdentifier:@"net.sourceforge.bibdesk.yaz"];
        config = [[NSString alloc] initWithContentsOfFile:[bundle pathForResource:@"objc_default" ofType:@"bib"] encoding:NSASCIIStringEncoding error:NULL];
        if (nil == config) config = [@"" copy];
    }
    return config;
}

+ (const char *)defaultConfigCString;
{
    static const char *config = NULL;
    if (NULL == config) {
        NSString *str = [self defaultConfigString];
        NSUInteger len = ([str lengthOfBytesUsingEncoding:NSASCIIStringEncoding] + 1);
        char *buf = NSZoneMalloc(NULL, sizeof(char) * len);
        [str getCString:buf maxLength:len encoding:NSASCIIStringEncoding];
        config = buf ? buf : "";
    }
    return config;
}

- (id)initWithCCLString:(NSString *)queryString config:(NSString *)confString;
{
    self = [super init];
    if (self){
        
        const char *conf = NULL;
        
        if (confString) {
            _config = [confString copy];
            conf = [confString UTF8String];
        } else {
            _config = [[[self class] defaultConfigString] copy];
            conf = [[self class] defaultConfigCString];
        }
        
        _query = ZOOM_query_create();
        _queryString = [queryString copy];
        
        int status, error, errorPosition = 0;
        const char *errstring = "";
        
        // Accented chars don't seem to be handled properly by some servers, but they appear to work if the accents are removed first, so the sender may wish to do that transformation.  I tried passing a MARC-8 string, but it either returns 0 results or wrong results.
        status = ZOOM_query_ccl2rpn(_query, [_queryString UTF8String], conf, &error, &errstring, &errorPosition);
        if (status) {
            [self release];
            self = nil;
        }
    }
    return self;
}

- (void)dealloc
{
    ZOOM_query_destroy(_query);
    [_queryString release];
    [_config release];
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone { return [self retain]; }

- (NSUInteger)hash { return [_queryString hash]; }

- (BOOL)isEqualToQuery:(ZOOMQuery *)aQuery;
{
    if (self == aQuery)
        return YES;
    return [_queryString isEqualToString:(aQuery->_queryString)] && [_config isEqualToString:(aQuery->_config)];
}

- (BOOL)isEqual:(id)other
{
    if ([other isKindOfClass:[self class]])
        return [other isEqualToQuery:self];
    return NO;
}

- (ZOOM_query)zoomQuery { return _query; }

@end
        
@implementation ZOOMCCLQueryFormatter

- (id)init
{
    return [self initWithConfigString:nil];
}

- (id)initWithConfigString:(NSString *)config;
{
    self = [super init];
    if (self) {
        const char *config_cstr = config ? [config UTF8String] : [ZOOMQuery defaultConfigCString];
        size_t len = strlen(config_cstr) + 1;
        char *copy = NSZoneMalloc([self zone], len * sizeof(char));
        
        // copy so that we can free it later
        strncpy(copy, config_cstr, len);
        _config = copy;
    }
    return self;
}

- (void)dealloc
{
    NSZoneFree([self zone], (void *)_config);
    [super dealloc];
}

- (NSString *)stringForObjectValue:(id)obj { return obj; }

- (BOOL)getObjectValue:(id *)obj forString:(NSString *)string errorDescription:(NSString **)error;
{
    BOOL success;
    if (string && [@"" isEqualToString:string] == NO) {
        int status, err, errorPosition = 0;
        
        // A user reported a crash under +[NSString stringWithFormat:...] because errstring and errorPosition apparently aren't initialized under all circumstances, and we were using garbage.
        const char *errstring = "Unknown error";
        ZOOM_query query = ZOOM_query_create();
        status = ZOOM_query_ccl2rpn(query, [string UTF8String], _config, &err, &errstring, &errorPosition);
        if (status) {
            if (error) *error = [NSString stringWithFormat:@"This is not a valid CCL query.  The parser reports \"%s\" (at position %d).", errstring, errorPosition];
            success = NO;
        } else {
            success = YES;
        }
        ZOOM_query_destroy(query);
    } else {
        success = YES;
    }
    *obj = string;
    return success;
}

@end


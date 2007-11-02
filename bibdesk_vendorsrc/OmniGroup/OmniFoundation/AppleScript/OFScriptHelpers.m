// Copyright 2006-2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OFScriptHelpers.h"

#import "OFNull.h"

#import <Foundation/NSScriptCommand.h>
#import <Foundation/NSScriptObjectSpecifiers.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease_2007-10-25/OmniGroup/Frameworks/OmniFoundation/AppleScript/OFScriptHelpers.m 90130 2007-08-15 07:15:53Z bungi $")

BOOL _OFCheckClass(id *input, Class cls, const char *name)
{
    id value = *input;

    if (OFISNULL(value))
        value = *input = nil;

    if ([value isKindOfClass:[NSScriptObjectSpecifier class]]) {
        // This can happen if you initialize an object with a properties clause (make new foo with properties {x:MyX})
        NSScriptObjectSpecifier *spec = value;
        *input = value = [spec objectsByEvaluatingSpecifier];
        if (!value) {
            // We had a non-nil specifier, but ended up with a nil value.
            NSScriptCommand *command = [NSScriptCommand currentCommand];
            OBASSERT(command);
            [command setScriptErrorNumber:NSArgumentEvaluationScriptError];
            [command setScriptErrorString:[NSString stringWithFormat:@"Unable to evaluate specifier %@ (%d %@)", spec, [spec evaluationErrorNumber], [spec evaluationErrorSpecifier]]];
            return NO;
        }
    }
    
    if (!value || [value isKindOfClass:cls])
        return YES;
    
    NSScriptCommand *command = [NSScriptCommand currentCommand];
    OBASSERT(command);
    [command setScriptErrorNumber:NSArgumentsWrongScriptError];
    [command setScriptErrorString:[NSString stringWithFormat:@"Wrong type for '%s'.  Should be '%@', but got '%@'", name, NSStringFromClass(cls), NSStringFromClass([value class])]];
    return NO;
}

BOOL _OFRequireNonNil(id object, const char *name)
{
    if (OFNOTNULL(object))
        return YES;
    
    NSScriptCommand *command = [NSScriptCommand currentCommand];
    OBASSERT(command);
    [command setScriptErrorNumber:NSArgumentsWrongScriptError];
    [command setScriptErrorString:[NSString stringWithFormat:@"Attempted to pass a null value for '%s'.", name]];
    return NO;
}

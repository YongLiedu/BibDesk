// Copyright 2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OFXMLComment.h"

#import <OmniBase/rcsid.h>

#import "OFXMLBuffer.h"
#import "OFXMLWhitespaceBehavior.h"
#import "OFXMLDocument.h"
#import "OFXMLString.h"

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease_2007-10-25/OmniGroup/Frameworks/OmniFoundation/XML/OFXMLComment.m 89476 2007-08-01 23:59:32Z kc $")

// OFXMLDocument currently doesn't generate these when reading documents, though that could be done.  Currently this is just intended to allow writers to emit comments.

@implementation OFXMLComment

- initWithString:(NSString *)unquotedString;
{
    // XML comments can't contain '--' since that ends a comment.
    if ([unquotedString containsString:@"--"])
        // Replace any double-dashes with an m-dash.  Cutesy, but it'll at least be valid.
        _quotedString  = [[unquotedString stringByReplacingAllOccurrencesOfString:@"--" withString:[NSString emdashString]] copy];
    else
        _quotedString = [unquotedString copy];

    return self;
}

- (void)dealloc;
{
    [_quotedString release];
    [super dealloc];
}

#pragma mark -
#pragma mark NSObject (OFXMLWriting)

- (void)appendXML:(struct _OFXMLBuffer *)xml withParentWhiteSpaceBehavior:(OFXMLWhitespaceBehaviorType)parentBehavior document:(OFXMLDocument *) doc level:(unsigned int)level;
{
    OFXMLBufferAppendString(xml, CFSTR("<!-- "));

    // Don't need to quote anything but "--" (done in initializer) and characters not representable in the target encoding.  Of course, if we do turn a character into an entity, it wouldn't get turned back when reading into a comment.
    NSString *encoded = OFXMLCreateStringInCFEncoding(_quotedString, [doc stringEncoding]);
    if (encoded) {
        OFXMLBufferAppendString(xml, (CFStringRef)encoded);
        [encoded release];
    }
    
    OFXMLBufferAppendString(xml, CFSTR(" -->"));
}

@end

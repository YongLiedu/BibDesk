// Copyright 2003-2005, 2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease_2007-10-25/OmniGroup/Frameworks/OmniFoundation/XML/OFXMLCursor.h 89466 2007-08-01 23:35:13Z kc $

#import <OmniFoundation/OFObject.h>

@class NSArray;
@class OFXMLDocument, OFXMLElement;

@interface OFXMLCursor : OFObject
{
    OFXMLDocument *_document;
    OFXMLElement *_startingElement;
    struct _OFXMLCursorState *_state;
    unsigned int _stateCount;
    unsigned int _stateSize;
}

- initWithDocument:(OFXMLDocument *)document element:(OFXMLElement *)element;
- initWithDocument:(OFXMLDocument *)document;

- (OFXMLDocument *)document;

- (OFXMLElement *)currentElement;
- (id)currentChild;
- (NSString *)currentPath;

- (id)nextChild;
- (id)peekNextChild;
- (void)openElement;
- (void)closeElement;

// Convenience methods that forward to -currentElement
- (NSString *)name;
- (NSArray *)children;
- (NSString *)attributeNamed:(NSString *)attributeName;

// More complex convenience methods
- (BOOL)openNextChildElementNamed:(NSString *)childElementName;

@end

// Error generating functions
extern NSString *OFXMLLoadError;
extern void OFXMLRejectElement(OFXMLCursor *cursor);

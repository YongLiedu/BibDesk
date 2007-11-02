//
//  FVPDFIcon.h
//  FileView
//
//  Created by Adam Maxwell on 10/21/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FVIcon.h"
#import "FVIcon_Private.h"

@interface FVPDFIcon : FVIcon
{
@private
    NSURL            *_fileURL;
    CGPDFDocumentRef  _pdfDoc;
    CGPDFPageRef      _pdfPage;
    NSSize            _fullSize;
    CGImageRef        _thumbnailRef;
    NSSize            _thumbnailSize;
    NSSize            _desiredSize;
    FVIconType        _iconType;
    BOOL              _inDiskCache;
    char             *_diskCacheName;
    pthread_mutex_t   _mutex;
    NSUInteger        _currentPage;
    NSUInteger        _pageCount;
}
- (id)initWithPDFAtURL:(NSURL *)aURL;
- (id)initWithPostscriptAtURL:(NSURL *)aURL;
@end

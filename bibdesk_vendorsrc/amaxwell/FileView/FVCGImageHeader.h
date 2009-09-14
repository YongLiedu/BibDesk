/*
 *  FVCGImageHeader.h
 *  FileView
 *
 *  Created by Adam Maxwell on 10/21/07.
 */
/*
 This software is Copyright (c) 2007-2009
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
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef FVCGImageHeader_H
#define FVCGImageHeader_H

#import <ApplicationServices/ApplicationServices.h>

typedef struct _FVCGImageHeaderInfo {
    size_t                 w;
    size_t                 h;
    size_t                 bpc;
    size_t                 bpp;
    size_t                 bpr;
    bool                   isGray;
    CGBitmapInfo           bitmapInfo;
    CGColorRenderingIntent renderingIntent;
    bool                   shouldInterpolate;
} FVCGImageHeaderInfo;

// This class isn't really necessary, but I found it amusing to write a C++ class for a change.  Serializing the class directly seems to work, but I'd rather serialize a struct instead, since I'm not sure what the compiler adds to C++ objects.
class FVCGImageHeader {
    
public:
    FVCGImageHeader() { info = new FVCGImageHeaderInfo; }
    FVCGImageHeader(CGImageRef image);
    FVCGImageHeader(FVCGImageHeaderInfo hInfo);
    
    FVCGImageHeader(const FVCGImageHeader &);
    ~FVCGImageHeader();
    
    size_t Width() const { return info->w; }
    size_t Height() const { return info->h; }
    size_t BitsPerComponent() const { return info->bpc; }
    size_t BitsPerPixel() const { return info->bpp; }
    size_t BytesPerRow() const { return info->bpr; }
    bool IsGray() const { return info->isGray; }
    CGBitmapInfo BitmapInfo() const { return info->bitmapInfo; }
    CGColorRenderingIntent ColorRenderingIntent() const { return info->renderingIntent; }
    bool ShouldInterpolate() const { return info->shouldInterpolate; }
    
    const FVCGImageHeaderInfo *HeaderInfo() const { return info; }
    const CGImageRef CreateCGImageWithData(CFDataRef bitmapData);
    
    // for debugging, as in DTSource
    void pinfo(void) const;
    
private:
    FVCGImageHeaderInfo *info;
};

#endif

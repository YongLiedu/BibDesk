/*
 *  FVCGImageHeader.cpp
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

#include "FVCGImageHeader.h"

FVCGImageHeader::FVCGImageHeader(const FVCGImageHeader &H)
{
    info = new FVCGImageHeaderInfo;
    memcpy(info, H.info, sizeof(FVCGImageHeaderInfo));
}

FVCGImageHeader::~FVCGImageHeader()
{
    delete info;
    info = NULL;
}

FVCGImageHeader::FVCGImageHeader(FVCGImageHeaderInfo hInfo)
{
    info = new FVCGImageHeaderInfo;
    memcpy(info, &hInfo, sizeof(FVCGImageHeaderInfo));
}

FVCGImageHeader::FVCGImageHeader(CGImageRef image)
{
    info = new FVCGImageHeaderInfo;
    info->w = CGImageGetWidth(image);
    info->h = CGImageGetHeight(image);
    info->bpc = CGImageGetBitsPerComponent(image);
    info->bpp = CGImageGetBitsPerPixel(image);
    info->bpr = CGImageGetBytesPerRow(image);
    
    // I only support device-specific RGB (3) and Gray (1) colorspaces in bitmap context caching, so just check the number of components since there's no way to get the colorspace name.  I think this is because Apple wants developers to use generic colorspaces, but I want to avoid the conversions for performance reasons.
    info->isGray = CGColorSpaceGetNumberOfComponents(CGImageGetColorSpace(image)) == 1;
    info->bitmapInfo = CGImageGetBitmapInfo(image);
    info->renderingIntent = CGImageGetRenderingIntent(image);
    info->shouldInterpolate = CGImageGetShouldInterpolate(image); 
}

void FVCGImageHeader::pinfo(void) const
{
    fprintf(stderr, "FVCGImageHeader <%p>: width=%lu, height=%lu, bitsPerComponent=%lu, bitsPerPixel=%lu, bytesPerRow=%lu, %s, bitmapInfo=%d, renderingIntent=%d, %s\n", this, (long)info->w, (long)info->h, (long)info->bpc, (long)info->bpp, (long)info->bpr, (info->isGray ? "grayscale" : "rgb"), info->bitmapInfo, info->renderingIntent, (info->shouldInterpolate ? "interpolates" : "does not interpolate"));
    fflush(stderr);
}

const CGImageRef FVCGImageHeader::CreateCGImageWithData(CFDataRef bitmapData)
{
    CGImageRef toReturn = NULL;
    CGColorSpaceRef cspace = this->IsGray() ? CGColorSpaceCreateDeviceGray() : CGColorSpaceCreateDeviceRGB();
    CGDataProviderRef provider = NULL;
    
    if (bitmapData)
        provider = CGDataProviderCreateWithCFData(bitmapData);
    
    if (provider)
        toReturn = CGImageCreate(this->Width(), this->Height(), 
                                 this->BitsPerComponent(), this->BitsPerPixel(), this->BytesPerRow(), 
                                 cspace, this->BitmapInfo(), provider, NULL, 
                                 this->ShouldInterpolate(), this->ColorRenderingIntent());
    
    CGColorSpaceRelease(cspace);
    CGDataProviderRelease(provider);
    return toReturn;
}

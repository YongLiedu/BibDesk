//  BDSKConverter.h

//  Created by Michael McCracken on Thu Mar 07 2002.
/*
This software is Copyright (c) 2001,2002, Michael O. McCracken
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

- Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
-  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
-  Neither the name of Michael O. McCracken nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

/*! @header BDSKConverter.h
    @discussion Declares a class that has no instances and just does the TeX encoding conversions.
*/

#import <Cocoa/Cocoa.h>
#import <OmniFoundation/OFCharacterScanner.h>
#import <OmniFoundation/OFStringScanner.h>

/*!
 @class BDSKConverter
 @abstract converts from UTF-8 <-> TeX
 @discussion This was a pain to write, and more of a pain to link. :)
*/
@interface BDSKConverter : NSObject {
}
/*!
    @method     sharedConverter
    @abstract   Returns a shared instance of the BDSKConverter
    @discussion (comprehensive description)
    @result     (description)
*/
+ (BDSKConverter *)sharedConverter;
/*!
    @method     loadDict
    @abstract   Initialize the converter
    @discussion (comprehensive description)
*/
- (void)loadDict;

/*!
 @method stringByTeXifyingString:
 @abstract UTF-8 -> TeX
 @discussion Uses a dictionary to find replacements for candidate special characters.
 @param s the string to convert into ASCII TeX encoding
 @result the string converted into ASCI TeX encoding
*/
- (NSString *)stringByTeXifyingString:(NSString *)s;
/*!
    @method     convertedStringWithAccentedString:
    @abstract   Convenience method that uses unicode decomposition to convert accented characters into a TeX sequence.
    @discussion (comprehensive description)
    @param      s The string to convert
    @result     A unicode string consisting of either the proper TeX sequence, or the original string decomposed using canonical mapping if a TeX sequence could not be formed.
*/
- (NSString *)convertedStringWithAccentedString:(NSString *)s;
/*!
    @method     convertBunch:usingDict:
    @abstract   Converts a decomposed accented string using a dictionary of accents
    @discussion (comprehensive description)
    @param      s Decomposed string (canonical mapping)
    @param      accents Dictionary of available accents
    @result     TeX sequence representing the character, or the decomposed character.
*/
- (NSString*) convertBunch:(NSString*)s usingDict:(NSDictionary*)accents;
/*!
 @method stringByDeTeXifyingString:
 @abstract TeX -> UTF-8
 @discussion Uses a dictionary to find replacements for strings like {\ ... }.
 @param s the string to convert from ASCII TeX encoding
 @result the string converted from ASCI TeX encoding
*/
- (NSString *)stringByDeTeXifyingString:(NSString *)s;

/*!
 @method runConversionAlertPanel
 @abstract NSRunAlertPanel
 @discussion Gives options to send e-mail if stringByTeXifyingString encounters a character not in the dictionary
 @param none
 @result alert panel
*/
- (void)runConversionAlertPanel:(NSString *)tmpConv;
@end

// BibPrefController 
/*
This software is Copyright (c) 2002, Michael O. McCracken
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

- Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
-  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
-  Neither the name of Michael O. McCracken nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#import <Cocoa/Cocoa.h>
#import <OmniFoundation/OFPreference.h>
#import <OmniAppKit/OmniAppKit.h>

#pragma mark Global CPP macros
// set to YES if testing on non-Jaguar system...
// YES
#define BDSK_USING_JAGUAR (floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_2)
// otherwise

#define foreach(object, enumerator) \
id mjtForeachEnumerator ## object = (enumerator); \
if ( [mjtForeachEnumerator ## object respondsToSelector:@selector(objectEnumerator)] ) \
mjtForeachEnumerator ## object = [mjtForeachEnumerator ## object objectEnumerator]; \
SEL mjtNextObjectSEL ## object = @selector(nextObject); \
IMP mjtNextObjectIMP ## object = [mjtForeachEnumerator ## object methodForSelector:mjtNextObjectSEL ## object]; \
id object; \
while ( object = mjtNextObjectIMP ## object(mjtForeachEnumerator ## object, mjtNextObjectSEL ## object) )

#pragma mark ||  User Defaults Key String Declarations

/*! @const BDSKTeXBinPathKey
@discussion Key for the user default:  the path to tex.
<br> I don't think these are respected yet. why not?
*/
extern NSString *BDSKTeXBinPathKey;

/*! @const BDSKBibTeXBinPathKey 
@discussion Key for the user default: the path to bibtex
*/
extern NSString *BDSKBibTeXBinPathKey;

/*! @const BDSKBTStyleKey Key for user default: The style file name to be inserted into the tex template for preview. */
extern NSString *BDSKBTStyleKey;
extern NSString *BDSKUseUnicodeBibTeXParser;
extern NSString *BDSKUseThreadedFileLoading;
extern NSString *BDSKDefaultStringEncoding;
extern NSString *BDSKDefaultBibFilePathKey;
extern NSString *BDSKStartupBehaviorKey;
extern NSString *BDSKAutoCheckForUpdates;
extern NSString *BDSKDragCopyKey;
extern NSString *BDSKUsesTeXKey;
extern NSString *BDSKEditOnPasteKey;
extern NSString *BDSKSeparateCiteKey;
extern NSString *BDSKShowColsKey;
extern NSString *BDSKShownColsNamesKey;
extern NSString *BDSKDefaultFieldsKey;
extern NSString *BDSKOutputTemplateFileKey;
extern NSString *BDSKTableViewFontKey;
extern NSString *BDSKTableViewFontSizeKey;
extern NSString *BDSKPreviewDisplayKey;
extern NSString *BDSKCustomCiteStringsKey;
extern NSString *BDSKCiteStringKey;
extern NSString *BDSKCiteStartBracketKey;
extern NSString *BDSKCiteEndBracketKey;
extern NSString *BDSKShouldUseTemplateFile;
extern NSString *BDSKSnoopDrawerContentKey;
extern NSString *BDSKBibEditorAutocompletionFields;
extern NSString *BDSKPreviewPaneFontFamily;

extern NSString *BDSKCiteKeyFormatKey;
extern NSString *BDSKCiteKeyFormatPresetKey;
extern NSString *BDSKCiteKeyAutogenerateKey;
extern NSString *BDSKCiteKeyLowercaseKey;

extern NSString *BDSKAutoSaveAsRSSKey;
extern NSString *BDSKRSSDescriptionFieldKey;

extern NSString *BDSKColumnWidthsKey;
extern NSString *BDSKColumnOrderKey;

extern NSString *BDSKPubTypeKey;
extern NSString *BDSKPubTypeStringKey;
extern NSString *BDSKShowWarningsKey;

extern NSString *BDSKCurrentQuickSearchKey;
extern NSString *BDSKCurrentQuickSearchTextDict;
extern NSString *BDSKQuickSearchKeys;

extern NSString *BDSKRowColorRedKey;
extern NSString *BDSKRowColorGreenKey;
extern NSString *BDSKRowColorBlueKey;

extern NSString *BDSKPapersFolderPathKey;
extern NSString *BDSKFilePapersAutomaticallyKey;
extern NSString *BDSKKeepPapersFolderOrganizedKey;
extern NSString *BDSKLocalUrlFormatKey;
extern NSString *BDSKLocalUrlFormatPresetKey;

extern NSString *BDSKLastVersionLaunched;
extern NSString *BDSKSnoopDrawerSavedSize;

#pragma mark Field name strings

extern NSString *BDSKCiteKeyString;
extern NSString *BDSKAnnoteString;
extern NSString *BDSKAbstractString;
extern NSString *BDSKRssDescriptionString;
extern NSString *BDSKLocalUrlString;
extern NSString *BDSKUrlString;
extern NSString *BDSKAuthorString;
extern NSString *BDSKTitleString;
extern NSString *BDSKYearString;
extern NSString *BDSKMonthString;
extern NSString *BDSKKeywordsString;
extern NSString *BDSKJournalString;
extern NSString *BDSKVolumeString;
extern NSString *BDSKPagesString;
extern NSString *BDSKBooktitleString;
extern NSString *BDSKPublisherString;
extern NSString *BDSKDateCreatedString;
extern NSString *BDSKDateModifiedString;
extern NSString *BDSKDateString;
extern NSString *BDSKBibtexString;
extern NSString *BDSKNumberString;


#pragma mark ||  Notification name strings
extern NSString *BDSKDocumentWillSaveNotification;
extern NSString *BDSKDocumentWindowWillCloseNotification;
extern NSString *BDSKDocumentUpdateUINotification;
extern NSString *BDSKTableViewFontChangedNotification;
extern NSString *BDSKPreviewDisplayChangedNotification;
extern NSString *BDSKPreviewNeedsUpdateNotification;
extern NSString *BDSKCustomStringsChangedNotification;
extern NSString *BDSKTableColumnChangedNotification;
extern NSString *BDSKBibItemChangedNotification;
extern NSString *BDSKDocAddItemNotification;
extern NSString *BDSKDocWillRemoveItemNotification;
extern NSString *BDSKDocDelItemNotification;
extern NSString *BDSKAuthorPubListChangedNotification;
extern NSString *BDSKParserErrorNotification;
extern NSString *BDSKBibDocMacroAddedNotification;
extern NSString *BDSKBibDocMacroRemovedNotification;
extern NSString *BDSKBibDocMacroKeyChangedNotification;
extern NSString *BDSKBibDocMacroDefinitionChangedNotification;
extern NSString *BDSKMacroTextFieldWindowWillCloseNotification;
extern NSString *BDSKPreviewPaneFontChangedNotification;

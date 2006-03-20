// BibPrefController.m
// BibDesk 
// Created by Michael McCracken, 2002
/*
 This software is Copyright (c) 2002,2003,2004,2005,2006
 Michael O. McCracken. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Michael O. McCracken nor the names of any
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

#import "BibPrefController.h"
#import <OmniAppKit/OAPreferenceController.h>
#import <OmniAppKit/OAPreferenceClientRecord.h>

@implementation OAPreferenceController (HelpLookup)

NSString *BDSKAllFieldsString = nil;

+ (void)didLoad
{
    BDSKAllFieldsString = [NSLocalizedString(@"Any Field", @"string specifying a search in all fields of an item") copy];
}

- (IBAction)showHelpForClient:(id)sender;
{
    // we override this since Omni's method uses the file URL name, which we generate dynamically
    NSString *helpAnchor = [nonretained_currentClientRecord helpURL];
    
    // log an error is someone mistakenly passes a URL instead of an anchor
    OBASSERT([helpAnchor rangeOfString:@".htm"].location == NSNotFound);
    
	NSString *helpBookName = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleHelpBookName"];
    OBASSERT(helpBookName);
    
	[[NSHelpManager sharedHelpManager] openHelpAnchor:helpAnchor inBook:helpBookName];
}

@end


NSString *BDSKDefaultBibFilePathKey = @"Default Bib File";
NSString *BDSKStartupBehaviorKey = @"Startup Behavior";
NSString *BDSKLastOpenFileNamesKey = @"Last Open FileNames";
NSString *BDSKAutoCheckForUpdatesKey = @"Check for updates when starting";
NSString *BDSKShouldUseTemplateFile = @"Write template file when saving";
NSString *BDSKShowingPreviewKey = @"Showing Preview";
NSString *BDSKSnoopDrawerContentKey = @"Snoop Drawer Content";
NSString *BDSKPreviewPaneFontFamilyKey = @"Font family to use for RTF preview display";
NSString *BDSKFilterFieldHistoryKey = @"Open using filter command history";
NSString *BDSKEditorShouldCheckSpellingContinuouslyKey = @"Check spelling continuously while editing";
NSString *BDSKIgnoredSortTermsKey = @"Terms ignored when sorting";
NSString *BDSKEditorFormShouldAutoCompleteKey = @"BDSKEditorFormShouldAutoCompleteKey";
NSString *BDSKReadExtendedAttributesKey = @"BDSKReadExtendedAttributesKey";
NSString *BDSKShouldUsePDFMetadata = @"BDSKShouldUsePDFMetadata";
NSString *BDSKShouldWritePDFMetadata = @"BDSKShouldWritePDFMetadata";

NSString *BDSKDefaultStringEncodingKey = @"Default string encoding for opening and saving";
NSString *BDSKShouldTeXifyWhenSavingAndCopyingKey = @"TeXify characters when saving or copying BibTeX";
NSString *BDSKTeXPreviewFileEncodingKey = @"Character encoding for TeX preview file";

NSString *BDSKTeXBinPathKey = @"TeX Binary Path";
NSString *BDSKBibTeXBinPathKey = @"BibTeX Binary Path";
NSString *BDSKBTStyleKey = @"BibTeX Style";
NSString *BDSKUsesTeXKey = @"Uses TeX";

NSString *BDSKDragCopyKey = @"Drag and Copy";
NSString *BDSKEditOnPasteKey = @"Edit on Paste";
NSString *BDSKSeparateCiteKey = @"Separate Cite";
NSString *BDSKCitePrependTildeKey = @"Cite Prepend Tilde";
NSString *BDSKCiteStringKey = @"Cite String";
NSString *BDSKCiteStartBracketKey = @"Citation Start Bracket";
NSString *BDSKCiteEndBracketKey = @"Citation End Bracket";

NSString *BDSKCiteKeyFormatKey = @"Cite Key Format";
NSString *BDSKCiteKeyFormatPresetKey = @"Cite Key Format Preset";
NSString *BDSKCiteKeyAutogenerateKey = @"Cite Key Autogenerate";
NSString *BDSKCiteKeyLowercaseKey = @"Cite Key Generate Lowercase";
NSString *BDSKCiteKeyCleanOptionKey = @"Cite Key Clean Braces or TeX";

NSString *BDSKShownColsNamesKey = @"Shown Column Names";
NSString *BDSKColumnWidthsKey = @"Column Widths by Name";
NSString *BDSKColumnOrderKey = @"Column Names in Order";
NSString *BDSKDefaultSortedTableColumnKey = @"Default table column to sort new documents";
NSString *BDSKDefaultSortedTableColumnIsDescendingKey = @"Default table column sort order";

NSString *BDSKShowStatusBarKey = @"Show Status Bar";
NSString *BDSKShowEditorStatusBarKey = @"Show Editor Status Bar";
NSString *BDSKShowFindStatusBarKey = @"Show Find Status Bar";

NSString *BDSKMainTableViewFontNameKey = @"BDSKMainTableViewFontNameKey";
NSString *BDSKMainTableViewFontSizeKey = @"BDSKMainTableViewFontSizeKey";
NSString *BDSKGroupTableViewFontNameKey = @"BDSKGroupTableViewFontNameKey";
NSString *BDSKGroupTableViewFontSizeKey = @"BDSKGroupTableViewFontSizeKey";
NSString *BDSKPersonTableViewFontNameKey = @"BDSKPersonTableViewFontNameKey";
NSString *BDSKPersonTableViewFontSizeKey = @"BDSKPersonTableViewFontSizeKey";
NSString *BDSKEditorFontNameKey = @"BDSKEditorFontNameKey";
NSString *BDSKEditorFontSizeKey = @"BDSKEditorFontSizeKey";
NSString *BDSKPreviewDisplayKey = @"Preview Pane Displays What?";
NSString *BDSKPreviewMaxNumberKey = @"Maximum Number of Items in Preview Pane";

NSString *BDSKPreviewPDFScaleFactorKey = @"Preview PDF Scale Factor";
NSString *BDSKPreviewRTFScaleFactorKey = @"Preview RTF Scale Factor";

NSString *BDSKDefaultFieldsKey = @"Default Fields";
NSString *BDSKLocalFileFieldsKey = @"Local File Fields";
NSString *BDSKRemoteURLFieldsKey = @"Remote URL Fields";
NSString *BDSKRatingFieldsKey = @"Rating fields";
NSString *BDSKBooleanFieldsKey = @"Boolean fields";
NSString *BDSKTriStateFieldsKey = @"Three state fields";
NSString *BDSKOutputTemplateFileKey = @"Output Template File";

NSString *BDSKCustomCiteStringsKey = @"Custom CiteStrings";
NSString *BDSKAutoSaveAsRSSKey = @"Auto-save as RSS";
NSString *BDSKRSSDescriptionFieldKey = @"Field to use as Description in RSS";

NSString *BDSKPubTypeStringKey = @"Current Publication Type String";

NSString *BDSKShowWarningsKey = @"Show Warnings in Error Panel";
NSString *BDSKWarnOnDeleteKey = @"BDSKWarnOnDelete";
NSString *BDSKWarnOnRenameGroupKey = @"BDSKWarnOnRenameGroup";
NSString *BDSKWarnOnRemovalFromGroupKey = @"BDSKWarnOnRemovalFromGroupKey";

NSString *BDSKCurrentQuickSearchKey = @"Current Quick Search Key";
NSString *BDSKCurrentQuickSearchTextDictKey = @"Current Quick Search Text Dictionary";
NSString *BDSKQuickSearchKeys = @"Quick Search Keys";
NSString *BDSKRowColorRedKey = @"RedComponentColor of alternating rows Key";
NSString *BDSKRowColorGreenKey = @"GreenComponentColor of alternating rows Key";
NSString *BDSKRowColorBlueKey = @"BlueComponentColor of alternating rows Key";

NSString *BDSKPapersFolderPathKey = @"Path to the papers folder";
NSString *BDSKFilePapersAutomaticallyKey = @"File papers into the papers folder automatically";
NSString *BDSKAutoFileUsesRelativePathKey = @"AutoFile uses relative path";
NSString *BDSKLocalUrlFormatKey = @"Local-Url Format";
NSString *BDSKLocalUrlFormatPresetKey = @"Local-Url Format Preset";
NSString *BDSKLocalUrlLowercaseKey = @"Local-Url Generate Lowercase";
NSString *BDSKLocalUrlCleanOptionKey = @"Local-Url Clean Braces or TeX";

NSString *BDSKDuplicateBooktitleKey = @"Duplicate Booktitle for Crossref";
NSString *BDSKForceDuplicateBooktitleKey = @"Overwrite Booktitle when Duplicating for Crossref";
NSString *BDSKTypesForDuplicateBooktitleKey = @"Types for Duplicating Booktitle for Crossref";
NSString *BDSKWarnOnEditInheritedKey = @"Warn on Editing Inherited Fields";
NSString *BDSKAutoSortForCrossrefsKey = @"Automatically Sort for Crossrefs";

NSString *BDSKLastVersionLaunchedKey = @"Last launched version number";
NSString *BDSKSnoopDrawerSavedSizeKey = @"Saved size of BibEditor document snoop drawer";
NSString *BDSKShouldSaveNormalizedAuthorNamesKey = @"Save normalized names in BibTeX files";
NSString *BDSKSaveAnnoteAndAbstractAtEndOfItemKey = @"Save Annote and Abstract at End of Item";
NSString *BDSKBibStyleMacroDefinitionsKey = @"Macro definitions from bib style file";
NSString *BDSKGlobalMacroDefinitionsKey = @"BDSKGlobalMacroDefinitionsKey";

NSString *BDSKFindControllerDefaultFindAndReplaceTypeKey = @"Default field for find and replace";
NSString *BDSKFindControllerSearchScopeKey = @"Search scope for find and replace";
NSString *BDSKFindControllerCaseInsensitiveFindAndReplaceKey = @"Use case sensitive search for find and replace";
NSString *BDSKFindControllerFindAndReplaceSelectedItemsKey = @"Search only selected items for find and replace";
NSString *BDSKFindControllerLastFindAndReplaceFieldKey = @"Last field for find and replace";
NSString *BDSKFindControllerFindAsMacroKey = @"Find text as macro for replacement";
NSString *BDSKFindControllerReplaceAsMacroKey = @"Replace found text as macro";
NSString *BDSKPreviewBaseFontSizeKey = @"Font size for preview pane in document view";
NSString *BDSKShouldAutosaveDocumentKey = @"BDSKShouldAutosaveDocumentKey";
NSString *BDSKAutosaveTimeIntervalKey = @"BDSKAutosaveTimeIntervalKey";
NSString *BDSKFileContentSearchSortDescriptorKey = @"BDSKFileContentSearchSortDescriptorKey";

NSString *BDSKScriptHooksKey = @"Script Hooks";
NSString *BDSKGroupFieldsKey = @"BDSKGroupFieldsKey";
NSString *BDSKCurrentGroupFieldKey = @"BDSKCurrentGroupFieldKey";
NSString *BDSKDefaultGroupFieldSeparatorKey = @"BDSKDefaultGroupFieldSeparatorKey";

NSString *BDSKTableHeaderImagesKey = @"BDSKTableHeaderImages";
NSString *BDSKTableHeaderTitlesKey = @"BDSKTableHeaderTitles";
NSString *BDSKCiteseerHostKey = @"BDSKCiteseerHostKey";

NSString *BDSKShouldDisplayFirstNamesKey = @"BDSKShouldDisplayFirstNamesKey";
NSString *BDSKShouldAbbreviateFirstNamesKey = @"BDSKShouldAbbreviateFirstNamesKey";
NSString *BDSKShouldDisplayLastNameFirstKey = @"BDSKShouldDisplayLastNameFirstKey";

#pragma mark Field name strings

NSString *BDSKCiteKeyString = @"Cite Key";
NSString *BDSKAnnoteString = @"Annote";
NSString *BDSKAbstractString = @"Abstract";
NSString *BDSKRssDescriptionString = @"Rss-Description";
NSString *BDSKLocalUrlString = @"Local-Url";
NSString *BDSKUrlString = @"Url";
NSString *BDSKAuthorString = @"Author";
NSString *BDSKEditorString = @"Editor";
NSString *BDSKTitleString = @"Title";
NSString *BDSKChapterString = @"Chapter";
NSString *BDSKContainerString = @"Container";  //See [BibItem container] for explanation
NSString *BDSKYearString = @"Year";
NSString *BDSKMonthString = @"Month";
NSString *BDSKKeywordsString = @"Keywords";
NSString *BDSKJournalString = @"Journal";
NSString *BDSKVolumeString = @"Volume";
NSString *BDSKNumberString = @"Number";
NSString *BDSKSeriesString = @"Series";
NSString *BDSKPagesString = @"Pages";
NSString *BDSKBooktitleString = @"Booktitle";
NSString *BDSKVolumetitleString = @"Volumetitle";
NSString *BDSKPublisherString = @"Publisher";
NSString *BDSKDateCreatedString = @"Date-Added";
NSString *BDSKDateModifiedString = @"Date-Modified";
NSString *BDSKDateString = @"Date";
NSString *BDSKCrossrefString = @"Crossref";
NSString *BDSKRatingString = @"Rating";
NSString *BDSKReadString = @"Read";
NSString *BDSKBibtexString = @"BibTeX";
NSString *BDSKFirstAuthorString = @"1st Author";
NSString *BDSKSecondAuthorString = @"2nd Author";
NSString *BDSKThirdAuthorString = @"3rd Author";
NSString *BDSKFirstAuthorEditorString = @"1st Author or Editor";
NSString *BDSKSecondAuthorEditorString = @"2nd Author or Editor";
NSString *BDSKThirdAuthorEditorString = @"3rd Author or Editor";
NSString *BDSKAuthorEditorString = @"Author or Editor";
NSString *BDSKItemNumberString = @"Item Number";
NSString *BDSKTypeString = @"Type";
NSString *BDSKAddressString = @"Address";
NSString *BDSKDoiString = @"Doi";
NSString *BDSKCiteseerUrlString = @"Citeseerurl";

#pragma mark ||  Notification name strings
NSString *BDSKFinalizeChangesNotification = @"Finalize Changes Notification";
NSString *BDSKDocumentWindowWillCloseNotification = @"Document Window Will Close Notification";
NSString *BDSKMainTableViewFontChangedNotification = @"BDSKMainTableViewFontChangedNotification";
NSString *BDSKGroupTableViewFontChangedNotification = @"BDSKGroupTableViewFontChangedNotification";
NSString *BDSKPersonTableViewFontChangedNotification = @"BDSKPersonTableViewFontChangedNotification";
NSString *BDSKEditorTextViewFontChangedNotification = @"BDSKEditorTextViewFontChangedNotification";
NSString *BDSKPreviewDisplayChangedNotification = @"Preview Pane Preference Change Notification";
NSString *BDSKPreviewNeedsUpdateNotification = @"Preview Needs Update Notification";
NSString *BDSKTableColumnChangedNotification = @"TableColumnChangedNotification";
NSString *BDSKTableSelectionChangedNotification = @"TableSelectionChangedNotification";
NSString *BDSKGroupFieldChangedNotification = @"GroupFieldChangedNotification";
NSString *BDSKGroupAddRemoveNotification = @"BDSKGroupAddRemoveNotification";
NSString *BDSKBibItemChangedNotification = @"BibItem Changed notification";
NSString *BDSKNeedsToBeFiledChangedNotification = @"BibItem NeedsToBeFiled Flag Changed notification";
NSString *BDSKDocSetPublicationsNotification = @"Set the publications of a document";
NSString *BDSKDocAddItemNotification = @"Added a bibitem to a document";
NSString *BDSKDocWillRemoveItemNotification = @"Will remove a bibitem from a document";
NSString *BDSKDocDelItemNotification = @"Removed a bibitem from a document";
NSString *BDSKAuthorPubListChangedNotification = @"added to or deleted a pub from an author";
NSString *BDSKBibDocMacroKeyChangedNotification = @"changed the key of a macro";
NSString *BDSKBibDocMacroDefinitionChangedNotification = @"changed the value of a macro";
NSString *BDSKMacroTextFieldWindowWillCloseNotification = @"Macro TextField Window Will Close Notification";
NSString *BDSKPreviewPaneFontChangedNotification = @"Changed the RTF preview pane font family";
NSString *BDSKBibTypeInfoChangedNotification = @"TypeInfo Changed Notification";
NSString *BDSKCustomFieldsChangedNotification = @"Custom Fields Changed Notification";
NSString *BDSKResortDocumentNotification = @"Update table sort";
NSString *BDSKFilterChangedNotification = @"Filter Changed Notification";
NSString *BDSKStopWordsChangedNotification = @"BDSKStopWordsChangedNotification";

#pragma mark Exception name strings

NSString *BDSKComplexStringException = @"BDSKComplexStringException";
NSString *BDSKTeXifyException = @"BDSKTeXifyException";
NSString *BDSKStringEncodingException = @"BDSKStringEncodingException";
NSString *BDSKUnimplementedException = @"BDSKUnimplementedException";

#pragma mark Error name strings
const char *BDSKParserError = "BDSKParserError";

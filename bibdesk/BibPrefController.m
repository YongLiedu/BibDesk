/*
This software is Copyright (c) 2002, Michael O. McCracken
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

- Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
-  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
-  Neither the name of Michael O. McCracken nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#import "BibPrefController.h"

NSString *BDSKDefaultBibFilePathKey = @"Default Bib File";
NSString *BDSKStartupBehaviorKey = @"Startup Behavior";

NSString *BDSKTeXBinPathKey = @"TeX Binary Path";
NSString *BDSKBibTeXBinPathKey = @"BibTeX Binary Path";
NSString *BDSKBTStyleKey = @"BibTeX Style";
NSString *BDSKUsesTeXKey = @"Uses TeX";

NSString *BDSKDragCopyKey = @"Drag and Copy";
NSString *BDSKEditOnPasteKey = @"Edit on Paste";
NSString *BDSKSeparateCiteKey = @"Separate Cite";
NSString *BDSKCiteStringKey = @"Cite String";
NSString *BDSKCiteStartBracketKey = @"Citation Start Bracket";
NSString *BDSKCiteEndBracketKey = @"Citation End Bracket";

NSString *BDSKShowColsKey = @"Shown Columns";
NSString *BDSKShownColsNamesKey = @"Shown Column Names";
NSString *BDSKColumnWidthsKey = @"Column Widths by Name";
NSString *BDSKColumnOrderKey = @"Column Names in Order";

NSString *BDSKTableViewFontKey = @"TableView Font";
NSString *BDSKTableViewFontSizeKey = @"TableView Font Size";
NSString *BDSKPreviewDisplayKey = @"Preview Pane Displays What?";

NSString *BDSKDefaultFieldsKey = @"Default Fields";
NSString *BDSKOutputTemplateFileKey = @"Output Template File";

NSString *BDSKCustomCiteStringsKey = @"Custom CiteStrings";
NSString *BDSKAutoSaveAsRSSKey = @"Auto-save as RSS";
NSString *BDSKRSSDescriptionFieldKey = @"Field to use as Description in RSS";

NSString *BDSKViewByKey = @"View-by Field";

NSString *BDSKPubTypeKey = @"Current Publication Type";
NSString *BDSKPubTypeStringKey = @"Current Publication Type String";

NSString *BDSKShowWarningsKey = @"Show Warnings in Error Panel";

NSString *BDSKCurrentQuickSearchKey = @"Current Quick Search Key";
NSString *BDSKCurrentQuickSearchTextDict = @"Current Quick Search Text Dictionary";
NSString *BDSKQuickSearchKeys = @"Quick Search Keys";
NSString *BDSKRowColorRedKey = @"RedComponentColor of alternating rows Key";
NSString *BDSKRowColorGreenKey = @"GreenComponentColor of alternating rows Key";
NSString *BDSKRowColorBlueKey = @"BlueComponentColor of alternating rows Key";

#pragma mark ||  Notification name strings
NSString *BDSKDocumentUpdateUINotification = @"General UI update Notification";
NSString *BDSKTableViewFontChangedNotification = @"Tableview font selection is changing Notification";
NSString *BDSKPreviewDisplayChangedNotification = @"Preview Pane Preference Change Notification";
NSString *BDSKCustomStringsChangedNotification = @"CustomStringsChangedNotification";
NSString *BDSKTableColumnChangedNotification = @"TableColumnChangedNotification";

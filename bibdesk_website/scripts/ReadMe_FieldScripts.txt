This script suite contains seven scripts for manipulating fields in BibDesk.

WARNING: Use at your own risk. Always make a backup copy of your data before using these scripts.

Installation:
1)Place all files in the "Put in ~/Library/Application Support/BibDesk/Scripts" folder in ~/Library/Application Support/BibDesk/Scripts/
2)Place all files in the "Put in ~/Library/ScriptingAdditions" folder in ~/Library/ScriptingAdditions

NB:Search & Replace is case insensitive. Searching for "pta" will match "PTA", "pTa" or any other combination and replace it with the Replace string without adjusting for case.

NB:Field Capitalize requires Christiaan Hofman's Capitalize Script Library available at
http://www.weizmann.ac.il/home/hofman/applescript/

Usage:
-To capitalize a field, run Field Capitalize and select the field.
-To copy one field to another, "run Field Copy/Swap," select the source field and the target field, and click "Copy 1 to 2"
-To swap two fields, run "Field Copy or Swap," select the source field and the target field, and click "Swap"
-To add a prefix or suffix to a field, run "Field Prefix or Suffix Add," select the source field, specify the added text, and click "Prefix" or "Suffix"
-To add a field before or after another field, run "Field Put 1 Before or After 2," select the source field and the target field, then click "Put 1 Before 2" or "Put 1 After 2"
-To remove characters from the beginning or end of a field, run "Field Remove Chars from Start or End," select the source field, specify the number of characters, and click "Start or "End"
-To search for one string and replace it with another in a field, run "Field Search&Replace," select the source field, specify the search string, specify the replace string, and click "OK"
-To set a field to a value, run "Field Set," select the source field, specify the new string, and click "OK"
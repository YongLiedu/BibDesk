/* BDSKFieldSheetController */

#import <Cocoa/Cocoa.h>

@interface BDSKFieldSheetController : NSWindowController
{
    NSString *prompt;
    NSArray *fieldsArray;
    NSString *field;
}

- (id)initWithPrompt:(NSString *)prompt fieldsArray:(NSArray *)fields;

- (NSString *)field;
- (void)setField:(NSString *)newField;
- (NSArray *)fieldsArray;
- (void)setFieldsArray:(NSArray *)array;
- (NSString *)prompt;
- (void)setPrompt:(NSString *)promptString;

- (NSString *)runSheetModalForWindow:(NSWindow *)parentWindow;
- (IBAction)dismiss:(id)sender;

@end

@interface BDSKAddFieldSheetController : BDSKFieldSheetController {
    IBOutlet NSComboBox *fieldComboBox;
}
@end

@interface BDSKRemoveFieldSheetController : BDSKFieldSheetController {
    IBOutlet NSPopUpButton *fieldPopup;
}
@end

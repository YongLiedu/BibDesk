/* BDSKFieldSheetController */

#import <Cocoa/Cocoa.h>

@interface BDSKFieldSheetController : NSWindowController
{
    IBOutlet NSControl *fieldsControl;
    IBOutlet NSButton *okButton;
    IBOutlet NSButton *cancelButton;
    IBOutlet NSTextField *promptField;
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
- (void)fixSizes;

@end

@interface BDSKAddFieldSheetController : BDSKFieldSheetController {
}
@end

@interface BDSKRemoveFieldSheetController : BDSKFieldSheetController {
}
@end

/* Inspired by and somewhat copied from Calendar by
 */


#import <AppKit/AppKit.h>
#import "BDSKComplexString.h"


@interface MacroTextFieldWindowController : NSWindowController {
    IBOutlet NSTextField *textField;
    IBOutlet NSTextField *expandedValueTextField;
    NSString *fieldName;
    id macroResolver;
}
// Public
- (void)startEditingValue:(NSString *) string
               atLocation:(NSPoint)point
                    width:(float)width
                 withFont:(NSFont*)font
                fieldName:(NSString *)aFieldName
			macroResolver:(id<BDSKMacroResolver>)aMacroResolver;

// Private
- (void)controlTextDidEndEditing:(NSNotification *)aNotification;
- (void)notifyNewValueAndOrderOut;
- (NSString *)stringValue;
@end

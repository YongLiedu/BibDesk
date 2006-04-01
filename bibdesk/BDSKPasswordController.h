/* BDSKPasswordController */

#import <Cocoa/Cocoa.h>

@interface BDSKPasswordController : NSWindowController
{
    id service; // must implement -name
    int returnValue;
    IBOutlet NSSecureTextField *passwordField;
}
- (void)setService:(id)aService;
- (int)runModalForService:(id)aService;

- (IBAction)buttonAction:(id)sender;
@end

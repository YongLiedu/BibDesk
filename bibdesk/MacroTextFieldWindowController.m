#import "MacroTextFieldWindowController.h"


@implementation MacroTextFieldWindowController

- (id) init {
    if (self = [super initWithWindowNibName:@"MacroTextFieldWindow"]) {
    }
    return self;
}

- (void)dealloc{
    [super dealloc];
}


- (void)windowDidLoad{
    [[self window] setExcludedFromWindowsMenu:TRUE];
    [[self window] setOneShot:TRUE];
}

- (void)startEditingValue:(NSString *) string
               atLocation:(NSPoint)point
                    width:(float)width
                 withFont:(NSFont*)font
                fieldName:(NSString *)aFieldName
			macroResolver:(id<BDSKMacroResolver>)aMacroResolver{
    NSNotificationCenter *nc;
    NSWindow *win = [self window];
    
    fieldName = aFieldName;
    macroResolver = aMacroResolver; // should we retain?
    NSRect currentFrame = [[self window] frame];
    
    // make sure the window starts out at the small size
    // and at the right point, thanks to the above assignment.
    [win setFrame:NSMakeRect(point.x,
                             point.y - currentFrame.size.height,
                             width,
                             currentFrame.size.height)
                    display:YES
                    animate:YES];
    
    
    [expandedValueTextField setStringValue:string];
    if([string isComplex]){
        [textField setStringValue:[string stringAsBibTeXString]];
    }else{
        [textField setStringValue:[NSString stringWithFormat:@"{%@}", string]];
    }
    
    if(font) [textField setFont:font];
    
    [win makeKeyAndOrderFront:self];

    nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self
           selector:@selector(handleDidResignKeyNotification:)
               name:@"NSWindowDidResignKeyNotification"
             object:win];
}

- (void)controlTextDidEndEditing:(NSNotification *)notification{
    [self notifyNewValueAndOrderOut];
}

// note that this might get called twice:
// once from controlTextDidEndEditing and then
// another time from handleDidResignKey...
// so don't do anything here that isn't OK to do 
// more than once without an intervening call to startEditing...

// Any method that uses this class should respond to the 
//  BDSKMacroTextFieldWindowWillCloseNotification by removing itself
// as an observer for that notification so it doesn't get it multiple times.
- (void)notifyNewValueAndOrderOut{
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[self stringValue], @"stringValue", fieldName, @"fieldName", nil];
    [nc postNotificationName:BDSKMacroTextFieldWindowWillCloseNotification
                      object:self
                    userInfo:userInfo];

    [[self window] orderOut:self];
    [nc removeObserver:self
                  name:@"NSWindowDidResignKeyNotification" 
                object:[self window]];
}

- (void)controlTextDidChange:(NSNotification*)aNotification { 
    NSString *value = [self stringValue];
    [expandedValueTextField setStringValue:value];
}

- (NSString *)stringValue{
    return [NSString complexStringWithBibTeXString:[textField stringValue] macroResolver:macroResolver];
}


// we might be calling notifyNewValueAndOrderOut for a second time, because 
// controlTextDidEndEditing calls it too, which then causes this to be called again
// calling orderOut twice in a row doesn't re-send this notification, so we're safe there
// we need to be careful not to do things in notifyNewValueAndOrderOut that 
// assume it is only called once. See also comments above that method.
- (void)handleDidResignKeyNotification:(NSNotification *)notification{
    [self notifyNewValueAndOrderOut];
}

@end

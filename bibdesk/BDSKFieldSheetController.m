#import "BDSKFieldSheetController.h"
#import "BDSKFieldNameFormatter.h"

@implementation BDSKFieldSheetController

- (id)initWithPrompt:(NSString *)promptString fieldsArray:(NSArray *)fields{
    if (self = [super init]) {
        [self window]; // make sure the nib is loaded
        field = nil;
        [self setPrompt:promptString];
        [self setFieldsArray:fields];
    }
    return self;
}

- (void)dealloc {
    [prompt release];
    [fieldsArray release];
    [field release];
    [super dealloc];
}

- (void)awakeFromNib{
}

- (void)fixSizes{
    NSRect fieldsFrame = [fieldsControl frame];
    NSRect oldPromptFrame = [promptField frame];
    [promptField setStringValue:(prompt)? prompt : @""];
    [promptField sizeToFit];
    NSRect newPromptFrame = [promptField frame];
    float dw = NSWidth(newPromptFrame) - NSWidth(oldPromptFrame);
    fieldsFrame.size.width -= dw;
    fieldsFrame.origin.x += dw;
    [fieldsControl setFrame:fieldsFrame];
}

- (NSString *)field{
    return field;
}

- (void)setField:(NSString *)newField{
    [field release];
    field = [newField copy];
}

- (NSArray *)fieldsArray{
    return fieldsArray;
}

- (void)setFieldsArray:(NSArray *)array{
    [fieldsArray release];
    fieldsArray = [array retain];
}

- (NSString *)prompt{
    return prompt;
}

- (void)setPrompt:(NSString *)promptString{
    [prompt release];
    prompt = [promptString retain];
    [self fixSizes];
}

- (NSString *)runSheetModalForWindow:(NSWindow *)parentWindow{
	[NSApp beginSheet:[self window]
	   modalForWindow:parentWindow
		modalDelegate:self
	   didEndSelector:NULL
		  contextInfo:NULL];
	int returnCode = [NSApp runModalForWindow:[self window]];
	
	[NSApp endSheet:[self window] returnCode:returnCode];
	[[self window] orderOut:self];
    
    if(returnCode == NSOKButton){
        NSString *newField = [self field];
        return (newField == nil) ? @"" : [[newField copy] autorelease];
    }else{
        return nil;
    }
}

- (IBAction)dismiss:(id)sender{
    [NSApp stopModalWithCode:[sender tag]];
}

@end


@implementation BDSKAddFieldSheetController

- (void)awakeFromNib{
    [super awakeFromNib];
	[(NSTextField *)fieldsControl setFormatter:[[[BDSKFieldNameFormatter alloc] init] autorelease]];
}

- (NSString *)windowNibName{
    return @"AddFieldSheet";
}

@end

@implementation BDSKRemoveFieldSheetController

- (NSString *)windowNibName{
    return @"RemoveFieldSheet";
}

- (void)setFieldsArray:(NSArray *)array{
    [super setFieldsArray:array];
    if ([fieldsArray count]) {
        [self setField:[fieldsArray objectAtIndex:0]];
        [okButton setEnabled:YES];
    } else {
        [okButton setEnabled:NO];
    }
}

@end

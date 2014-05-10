#import <Foundation/Foundation.h>
#import "WokServiceSoapBinding.h"

@class WOKMWSAuthenticateService_authenticate;
@class WOKMWSAuthenticateService_authenticateResponse;
@class WOKMWSAuthenticateService_closeSession;
@class WOKMWSAuthenticateService_closeSessionResponse;

@interface WOKMWSAuthenticateService_authenticate : WokServiceSoapBindingElement {
}
@end

@interface WOKMWSAuthenticateService_authenticateResponse : WokServiceSoapBindingElement {
	NSString * return_;
}
@property (retain) NSString * return_;
@end

@interface WOKMWSAuthenticateService_closeSession : WokServiceSoapBindingElement {
}
@end

@interface WOKMWSAuthenticateService_closeSessionResponse : WokServiceSoapBindingElement {
}
@end

@interface WOKMWSAuthenticateService : WokServiceSoapBinding {
}
+ (NSString *)address;
+ (NSString *)namespaceURI;
- (WokServiceSoapBindingResponse *)authenticateUsingParameters:(WOKMWSAuthenticateService_authenticate *)parameters;
- (WokServiceSoapBindingResponse *)closeSessionUsingParameters:(WOKMWSAuthenticateService_closeSession *)parameters;
@end

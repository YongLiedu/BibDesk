#import <Foundation/Foundation.h>
#import "WokServiceSoapBinding.h"

@class WOKMWSAuthenticateService_authenticate;
@class WOKMWSAuthenticateService_authenticateResponse;
@class WOKMWSAuthenticateService_closeSession;
@class WOKMWSAuthenticateService_closeSessionResponse;

@interface WOKMWSAuthenticateService_authenticate : WokServiceSoapBindingRequest {
}
@end

@interface WOKMWSAuthenticateService_authenticateResponse : WokServiceSoapBindingElement {
	NSString * return_;
}
@property (retain) NSString * return_;
@end

@interface WOKMWSAuthenticateService_closeSession : WokServiceSoapBindingRequest {
}
@end

@interface WOKMWSAuthenticateService_closeSessionResponse : WokServiceSoapBindingElement {
}
@end

@interface WOKMWSAuthenticateService : NSObject {
}
+ (NSString *)address;
+ (NSString *)namespaceURI;
+ (WokServiceSoapBinding *)soapBinding;
@end

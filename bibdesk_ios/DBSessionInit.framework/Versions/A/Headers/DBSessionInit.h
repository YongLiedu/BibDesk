//
//  DBSessionInit.h
//  DBSessionInit
//
//  Created by Colin Smith on 6/16/12.
//  Copyright (c) 2012 Colin A. Smith. All rights reserved.
//


#import <DropboxSDK/DBSession.h>

@interface DBSession (DBSessionInit)

- (id)initWithBibDeskMobile;

@end

DBSession *NewDBSessionWithBibDeskMobile();

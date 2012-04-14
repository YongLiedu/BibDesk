// Copyright 2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease_2007-10-25/OmniGroup/Frameworks/OmniFoundation/OFErrors.h 93428 2007-10-25 16:36:11Z kc $

// Domain is the OmniFoundation bundle identifier.
enum {
    // Zero typically means no error
    OFCacheFileUnableToWriteError = 1,
    OFFilterDataCommandReturnedErrorCodeError,
    OFUnableToCreatePathError,
    OFUnableToSerializeLockFileDictionaryError,
    OFUnableToCreateLockFileError,
    OFCannotFindTemporaryDirectoryError,
    OFCannotExchangeFileError,
    OFCannotUniqueFileNameError,
};

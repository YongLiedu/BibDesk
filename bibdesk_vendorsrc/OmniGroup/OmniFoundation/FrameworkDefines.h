// Copyright 1997-2000 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// http://www.omnigroup.com/DeveloperResources/OmniSourceLicense.html.
//
// DO NOT MODIFY THIS FILE -- IT IS AUTOGENERATED!
//
// Platform specific defines for marking data and code
// as 'extern'.
//

#ifndef _OmniFoundationDEFINES_H
#define _OmniFoundationDEFINES_H

//
//  OpenStep/Mach or Rhapsody
//

#if defined(__MACH__)

#ifdef __cplusplus
#define OmniFoundation_EXTERN               extern
#define OmniFoundation_PRIVATE_EXTERN       __private_extern__
#else
#define OmniFoundation_EXTERN               extern
#define OmniFoundation_PRIVATE_EXTERN       __private_extern__
#endif


//
//  OpenStep/NT, YellowBox/NT, and YellowBox/95
//

#elif defined(WIN32)

#ifndef _NSBUILDING_OmniFoundation_DLL
#define _OmniFoundation_WINDOWS_DLL_GOOP       __declspec(dllimport)
#else
#define _OmniFoundation_WINDOWS_DLL_GOOP       __declspec(dllexport)
#endif

#ifdef __cplusplus
#define OmniFoundation_EXTERN			_OmniFoundation_WINDOWS_DLL_GOOP extern
#define OmniFoundation_PRIVATE_EXTERN		extern
#else
#define OmniFoundation_EXTERN			_OmniFoundation_WINDOWS_DLL_GOOP extern
#define OmniFoundation_PRIVATE_EXTERN		extern
#endif

//
// Standard UNIX: PDO/Solaris, PDO/HP-UX, GNUstep
//

#elif defined(sun) || defined(hpux) || defined(GNUSTEP)

#ifdef __cplusplus
#  define OmniFoundation_EXTERN               extern
#  define OmniFoundation_PRIVATE_EXTERN       extern
#else
#  define OmniFoundation_EXTERN               extern
#  define OmniFoundation_PRIVATE_EXTERN       extern
#endif

#else

#error Do not know how to define extern on this platform

#endif

#endif // _OmniFoundationDEFINES_H

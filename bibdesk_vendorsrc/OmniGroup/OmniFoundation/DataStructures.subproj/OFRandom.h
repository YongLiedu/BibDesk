// Copyright 1997-2003 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// http://www.omnigroup.com/DeveloperResources/OmniSourceLicense.html.
//
// $Header: /Network/Source/CVS/OmniGroup/Frameworks/OmniFoundation/DataStructures.subproj/OFRandom.h,v 1.14 2003/01/15 22:51:55 kc Exp $

#import <OmniFoundation/OFObject.h>
#import <OmniFoundation/FrameworkDefines.h>

// Some platforms don't provide random number generation and of those that do, there are many different variants.  We provide a common random number generator rather than have to deal with each platform independently.  Additionally, we allow the user to maintain several random number generators.

typedef struct {
    unsigned long y; // current value any number between zero and M-1
} OFRandomState;

OmniFoundation_EXTERN float OFRandomMax;

OmniFoundation_EXTERN unsigned int OFRandomGenerateRandomSeed(void);	// returns a random number (generated from /dev/urandom if possible, otherwise generated via clock information) for use as a seed value for OFRandomSeed().
OmniFoundation_EXTERN void OFRandomSeed(OFRandomState *state, unsigned long y);
OmniFoundation_EXTERN unsigned long OFRandomNextState(OFRandomState *state);

OmniFoundation_EXTERN unsigned long OFRandomNext(void);	// returns a random number generated using a default, shared random state.


static inline float OFRandomFloat(OFRandomState *state)
/*.doc.
Returns a number in the range [0..1]
*/
{
    return (float)OFRandomNextState(state)/(float)OFRandomMax;
}

#define OF_RANDOM_MAX OFRandomMax // For backwards compatibility

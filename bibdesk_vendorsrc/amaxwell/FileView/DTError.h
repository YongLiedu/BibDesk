// Part of DTSource. Copyright 2004-2006. David Adalsteinsson.  BSD License
// see http://www.visualdatatools.com/DTSource/license.html for more information.

#ifndef DTError_H
#define DTError_H

/*
 A central point for error messages.

 Set a breakpoint inside the source code to catch errors, such as out of bounds access to arrays.

*/

#include <string>
#include <vector>
using namespace std;

extern void DTErrorOutOfRange(string type,int i,int m);
extern void DTErrorOutOfRange(string type,int i,int j,int m,int n);
extern void DTErrorOutOfRange(string type,int i,int j,int k,int m,int n,int o);

extern void DTWarningMessage(string fcn,string msg);
extern void DTErrorMessage(string fcn,string msg);
extern void DTErrorMessage(string msg);

extern vector<string> &DTErrorList(void);

#endif

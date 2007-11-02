// Part of DTSource. Copyright 2004-2006. David Adalsteinsson.  BSD License
// see http://www.visualdatatools.com/DTSource/license.html for more information.

#include "DTError.h"
#include "DTUtilities.h"

#include <iostream>

static vector<string> errorList;

vector<string> &DTErrorList(void)
{
    return errorList;
}

void DTErrorMessage(string fcn,string msg)
{
    // Set a breakpoint here, and then trace it back.
    string theErr = fcn + ": " + msg;
    errorList.push_back(theErr);
    cerr << theErr << endl;
    cerr.flush();
}

void DTErrorMessage(string msg)
{
    // Set a breakpoint here, and then trace it back.
    errorList.push_back(msg);
    cerr << msg << endl;
    cerr.flush();
}

void DTWarningMessage(string fcn,string msg)
{
    string theErr = fcn + ": " + msg;
    errorList.push_back(theErr);
    cerr << theErr << endl;
    cerr.flush();
}

void DTErrorOutOfRange(string type,int i,int m)
{
    string toReturn = type + "(" + DTInt2String(i) + ") is not valid, needs to be lie in [0," + DTInt2String(m-1) + "].";
    DTErrorMessage(toReturn);
}

void DTErrorOutOfRange(string type,int i,int j,int m,int n)
{
    string toReturn = type + "(" + DTInt2String(i) + "," + DTInt2String(j) + ") is not valid, needs to lie in [0,"  + DTInt2String(m-1) + "]x[0," + DTInt2String(n-1) + "].";
    DTErrorMessage(toReturn);
}

void DTErrorOutOfRange(string type,int i,int j,int k,int m,int n,int o)
{
    string toReturn = type + "(" + DTInt2String(i) + "," + DTInt2String(j) + "," + DTInt2String(k) + ") is not valid, needs to lie in [0," + DTInt2String(m-1) + "]x[0," + DTInt2String(n-1) + "]x[0," + DTInt2String(o-1) + "].";
    DTErrorMessage(toReturn);
}


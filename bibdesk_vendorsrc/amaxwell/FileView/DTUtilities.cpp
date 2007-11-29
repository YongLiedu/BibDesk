// Part of DTSource. Copyright 2004-2006. David Adalsteinsson.  BSD License
// see http://www.visualdatatools.com/DTSource/license.html for more information.

#include "DTUtilities.h"

string DTInt2String(int n)
{
    char temp[20];
    sprintf(temp,"%d",n);
    return string(temp);
}

string DTFloat2StringShort(double v)
{
    char temp[20];
    sprintf(temp,"%g",v);
    return string(temp);
}


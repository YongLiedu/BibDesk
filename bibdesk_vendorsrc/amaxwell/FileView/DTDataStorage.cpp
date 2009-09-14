// Part of DTSource. Copyright 2004-2006. David Adalsteinsson.  BSD License
// see http://www.visualdatatools.com/DTSource/license.html for more information.

#include "DTDataStorage.h"

#include "DTDoubleArray.h"
#include "DTIntArray.h"
#include "DTCharArray.h"
#include "DTUCharArray.h"
#include "DTFloatArray.h"
#include "DTShortIntArray.h"
#include "DTUShortIntArray.h"
#include "DTError.h"

#include <set>

string DTDataStorage::ResolveName(const string &name) const
{
    if (SavedAsString(name)==false)
        return name;
    
    string theName = ReadString(name);
    
    // First check if this is a one step redirect
    if (SavedAsString(theName)==false)
        return theName;
    
    // Deeper redirect, need to avoid circular references
    set<string> soFar;
    soFar.insert(name);
    while (SavedAsString(theName) && soFar.count(theName)==0) {
        soFar.insert(theName);
        theName = ReadString(theName);
    }
    if (soFar.count(theName)) {
        DTErrorMessage("DTDataStorage::ResolveName","Circular reference for "+name);
        return name;
    }
    else if (Contains(theName)==false)
        return name;
    else
        return theName;
}

void DTDataStorage::Flush(void) const
{
    
}

DTList<string> DTDataStorage::AllVariableNamesWithPrefix(const string &prefix) const
{
    DTList<string> allEntries = AllVariableNames();
    
    // Now go through the entries that start with the given prefix
    // This can clearly be made more efficient, and will be if people request it.
    // Right now, call the virtual function to get all of the entries, and pick from that.

    int howMany = allEntries.Length();
    int i;
    DTMutableIntArray whichAreIncluded(howMany);
    int pos = 0;
    int lenOfPrefix = prefix.length();

    for (i=0;i<howMany;i++) {
        if ((allEntries(i).compare(0,lenOfPrefix,prefix)==0))
            whichAreIncluded(pos++) = i;
    }
    
    DTMutableList<string> toReturn(pos);
    for (i=0;i<pos;i++) {
        toReturn(i) = allEntries(whichAreIncluded(i));
    }
    
    return toReturn;
}

void DTDataStorage::pinfo(void) const
{
    printInfo();
}

void DTDataStorage::printInfo(void) const
{
    // Overwrite to print content.
}

bool DTDataStorage::RunningOnBigEndianMachine(void)
{
    int fourBytes[1];
    fourBytes[0] = 128912422;
    short int *asTwoShorts = (short int *)fourBytes;
    return (asTwoShorts[0]==1967);
}

double DTDataStorage::ReadNumber(const string &name) const
{
    DTDoubleArray theArr = ReadDoubleArray(name);
    if (theArr.IsEmpty() || theArr.Length()!=1)
        return 0.0;

    return theArr(0);
}

int DTDataStorage::ReadInt(const string &name) const
{
    DTIntArray theArr = ReadIntArray(name);
    if (theArr.IsEmpty() || theArr.Length()!=1)
        return 0;

    return theArr(0);
}

void Read(const DTDataStorage &input,const string &name,double &toReturn)
{
    toReturn = input.ReadNumber(name);
}

void Read(const DTDataStorage &input,const string &name,int &toReturn)
{
    double temp;
    Read(input,name,temp);
    toReturn = int(temp);
}

void Write(DTDataStorage &output,const string &name,double theVar)
{
    output.Save(theVar,name);
}

void Read(const DTDataStorage &input,const string &name,string &toReturn)
{
    toReturn = input.ReadString(name);
}

void Write(DTDataStorage &output,const string &name,const string &theVar)
{
    output.Save(theVar,name);
}

void Read(const DTDataStorage &input,const string &name,DTDoubleArray &toReturn)
{
    toReturn = input.ReadDoubleArray(name);
}

void Write(DTDataStorage &output,const string &name,const DTDoubleArray &theVar)
{
    output.Save(theVar,name);
}

void Read(const DTDataStorage &input,const string &name,DTFloatArray &toReturn)
{
    toReturn = input.ReadFloatArray(name);
}

void Write(DTDataStorage &output,const string &name,const DTFloatArray &theVar)
{
    output.Save(theVar,name);
}

void Read(const DTDataStorage &input,const string &name,DTIntArray &toReturn)
{
    toReturn = input.ReadIntArray(name);
}

void Write(DTDataStorage &output,const string &name,const DTIntArray &theVar)
{
    output.Save(theVar,name);
}

void Read(const DTDataStorage &input,const string &name,DTCharArray &toReturn)
{
    toReturn = input.ReadCharArray(name);
}

void Write(DTDataStorage &output,const string &name,const DTCharArray &theVar)
{
    output.Save(theVar,name);
}

void Read(const DTDataStorage &input,const string &name,DTUCharArray &toReturn)
{
    toReturn = input.ReadUCharArray(name);
}

void Write(DTDataStorage &output,const string &name,const DTUCharArray &theVar)
{
    output.Save(theVar,name);
}

void Read(const DTDataStorage &input,const string &name,DTShortIntArray &toReturn)
{
    toReturn = input.ReadShortIntArray(name);
}

void Write(DTDataStorage &output,const string &name,const DTShortIntArray &theVar)
{
    output.Save(theVar,name);
}

void Read(const DTDataStorage &input,const string &name,DTUShortIntArray &toReturn)
{
    toReturn = input.ReadUShortIntArray(name);
}

void Write(DTDataStorage &output,const string &name,const DTUShortIntArray &theVar)
{
    output.Save(theVar,name);
}

void WriteOne(DTDataStorage &output,const string &name,const DTDoubleArray &theVar)
{
    output.Save(theVar,name);
    if (theVar.n()>1)
        output.Save("Array","Seq_"+name);
    else
        output.Save("NumberList","Seq_"+name);
    output.Flush();
}

void WriteOne(DTDataStorage &output,const string &name,const DTFloatArray &theVar)
{
    output.Save(theVar,name);
    if (theVar.n()>1)
        output.Save("Array","Seq_"+name);
    else
        output.Save("NumberList","Seq_"+name);
    output.Flush();
}

void WriteOne(DTDataStorage &output,const string &name,const string &theVar)
{
    output.Save(theVar,name);
    output.Save("String","Seq_"+name);
    output.Flush();
}

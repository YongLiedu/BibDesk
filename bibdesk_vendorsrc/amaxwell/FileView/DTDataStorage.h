// Part of DTSource. Copyright 2004-2006. David Adalsteinsson.  BSD License
// see http://www.visualdatatools.com/DTSource/license.html for more information.

#ifndef DTDataStorage_Header
#define DTDataStorage_Header

/*
 Base class for DTDataContainer (memory based storage), DTDataFile (file based) and DTMatlabDataFile (file based).
 */

#include "DTPointer.h"
#include "DTList.h"

class DTDoubleArray;
class DTFloatArray;
class DTIntArray;
class DTCharArray;
class DTUCharArray;
class DTShortIntArray;
class DTUShortIntArray;

#include <string>

class DTDataStorage {
public:
    virtual ~DTDataStorage() {}

    virtual DTMutablePointer<DTDataStorage> AsPointer() = 0;
    
    DTList<string> AllVariableNamesWithPrefix(const string &) const;
    virtual DTList<string> AllVariableNames(void) const = 0;
    virtual bool Contains(const string &name) const = 0;
    virtual bool IsReadOnly(void) const = 0;

    // Saving data.
    virtual void Save(int,const string &name) = 0;
    virtual void Save(double,const string &name) = 0;
    virtual void Save(const DTDoubleArray &A,const string &name) = 0;
    virtual void Save(const DTFloatArray &A,const string &name) = 0;
    virtual void Save(const DTIntArray &A,const string &name) = 0;
    virtual void Save(const DTCharArray &A,const string &name) = 0;
    virtual void Save(const DTUCharArray &A,const string &name) = 0;
    virtual void Save(const DTShortIntArray &A,const string &name) = 0;
    virtual void Save(const DTUShortIntArray &A,const string &name) = 0;
    virtual void Save(const string &theString,const string &name) = 0;

    virtual bool SavedAsDouble(const string &name) const = 0;
    virtual bool SavedAsString(const string &name) const = 0;

    virtual void Flush(void) const;

    // Reading data.
    virtual DTDoubleArray ReadDoubleArray(const string &name) const = 0;
    virtual DTFloatArray ReadFloatArray(const string &name) const = 0;
    virtual DTIntArray ReadIntArray(const string &name) const = 0;
    virtual DTCharArray ReadCharArray(const string &name) const = 0;
    virtual DTUCharArray ReadUCharArray(const string &name) const = 0;
    virtual DTShortIntArray ReadShortIntArray(const string &name) const = 0;
    virtual DTUShortIntArray ReadUShortIntArray(const string &name) const = 0;
    virtual double ReadNumber(const string &name) const;
    virtual int ReadInt(const string &name) const;
    virtual string ReadString(const string &name) const = 0;

    string ResolveName(const string &name) const;
    static bool RunningOnBigEndianMachine(void);

    // Debug
    void pinfo() const;

protected:
    virtual void printInfo(void) const;
};

extern void Read(const DTDataStorage &input,const string &name,double &toReturn);
extern void Read(const DTDataStorage &input,const string &name,int &toReturn);
extern void Write(DTDataStorage &output,const string &name,double theVar);
extern void Read(const DTDataStorage &input,const string &name,string &toReturn);
extern void Write(DTDataStorage &output,const string &name,const string &theVar);
extern void Read(const DTDataStorage &input,const string &name,DTDoubleArray &toReturn);
extern void Write(DTDataStorage &output,const string &name,const DTDoubleArray &theVar);
extern void Read(const DTDataStorage &input,const string &name,DTFloatArray &toReturn);
extern void Write(DTDataStorage &output,const string &name,const DTFloatArray &theVar);
extern void Read(const DTDataStorage &input,const string &name,DTIntArray &toReturn);
extern void Write(DTDataStorage &output,const string &name,const DTIntArray &theVar);
extern void Read(const DTDataStorage &input,const string &name,DTCharArray &toReturn);
extern void Write(DTDataStorage &output,const string &name,const DTCharArray &theVar);
extern void Read(const DTDataStorage &input,const string &name,DTUCharArray &toReturn);
extern void Write(DTDataStorage &output,const string &name,const DTUCharArray &theVar);
extern void Read(const DTDataStorage &input,const string &name,DTShortIntArray &toReturn);
extern void Write(DTDataStorage &output,const string &name,const DTShortIntArray &theVar);
extern void Read(const DTDataStorage &input,const string &name,DTUShortIntArray &toReturn);
extern void Write(DTDataStorage &output,const string &name,const DTUShortIntArray &theVar);

// Each variable type has a WriteOne(...) function, which will save the variable to a data file 
// along with a type description.  These functions are similar.  However, this will save
// the variable as a "List Of Numbers" if you hand it a vector, but an "Array" if the second dimension is >1.
extern void WriteOne(DTDataStorage &output,const string &name,const DTDoubleArray &theVar);
extern void WriteOne(DTDataStorage &output,const string &name,const DTFloatArray &theVar);
extern void WriteOne(DTDataStorage &output,const string &name,const string &theVar);

#endif

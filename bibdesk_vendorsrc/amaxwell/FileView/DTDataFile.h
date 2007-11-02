// Part of DTSource. Copyright 2004-2006. David Adalsteinsson.  BSD License
// see http://www.visualdatatools.com/DTSource/license.html for more information.

#ifndef DTDataFile_Header
#define DTDataFile_Header

// A binary file format, created specially for DataTank.  Can also use DTMatlabDataFile.
// Both classes are derived from DTDataStorage.

// Usage is
// Create variables by specifying the file name when they are created.
//
// DTDataFile TheFile("FileNameOnDisk");
//
// If A is an array (DTDoubleArray or DTFloatArray), to save it in the file
// under the name "ArrayName", use
//     TheFile.Save(A,"ArrayName");
// to read it from the file
//     = TheFile.ReadDoubleArray("ArrayName");
// similarly for other variable types.

// If you are reading or writing variables with names test_1, test_2, ...
// name = "test+" + DTInt2String(3);

#include <stdio.h>
#include <fstream>
#include <map>

#include "DTDataStorage.h"
#include "DTFile.h"

// The type constants are as follows:
// 0  - Empty
// 1  - Double
// 2  - Single
// 3  - Double complex
// 4  - Single complex
// 5  - Unsigned 64 bits
// 6  - Signed 64 bits
// 7  - Unsigned 32 bit Int
// 8  - Signed 32 bit int
// 9  - Unsigned 16 bit int
// 10 - Signed 16 bit int
// 11 - Unsigned 8 bit int
// 12 - Signed 8 bit int
// 20 - String - unsigned 8 bits

const int DTDataFile_Double = 1;
const int DTDataFile_Single = 2;
const int DTDataFile_Signed32Int = 8;
const int DTDataFile_UnsignedShort = 9;
const int DTDataFile_Short = 10;
const int DTDataFile_Unsigned8Char = 11;
const int DTDataFile_Signed8Char = 12;
const int DTDataFile_String = 20;


class DTDataFileContent;
struct DTDataEntry;

class DTDataFile : public DTDataStorage
{
public:
    DTDataFile();
    DTDataFile(DTFile file);
    DTDataFile(const string &name,DTFile::OpenType=DTFile::ExistingReadWrite);

    ~DTDataFile();
    DTMutablePointer<DTDataStorage> AsPointer();

    // Copying and assignment treat this class as a pointer.
    DTDataFile(const DTDataFile &);
    DTDataFile &operator=(const DTDataFile &);

    bool Contains(const string &name) const;
    DTList<string> AllVariableNames(void) const;
    bool IsReadOnly(void) const;
    FILE *GetFILE(void) const;
    void SaveIndex(void);

    // Saving data.
    void Save(int v,const string &name);
    void Save(double v,const string &name);
    void Save(const DTDoubleArray &A,const string &name);
    void Save(const DTFloatArray &A,const string &name);
    void Save(const DTIntArray &A,const string &name);
    void Save(const DTCharArray &A,const string &name);
    void Save(const DTUCharArray &A,const string &name);
    void Save(const DTShortIntArray &A,const string &name);
    void Save(const DTUShortIntArray &A,const string &name);
    void Save(const string &theString,const string &name);

    void Flush(void) const;

    bool SavedAsDouble(const string &name) const;
    bool SavedAsString(const string &name) const;

    // Reading data.
    DTDoubleArray ReadDoubleArray(const string &name) const;
    DTFloatArray ReadFloatArray(const string &name) const;
    DTIntArray ReadIntArray(const string &name) const;
    DTCharArray ReadCharArray(const string &name) const;
    DTUCharArray ReadUCharArray(const string &name) const;
    DTShortIntArray ReadShortIntArray(const string &name) const;
    DTUShortIntArray ReadUShortIntArray(const string &name) const;
    string ReadString(const string &name) const;

private:
    void printInfo(void) const;
    DTDataEntry FindVariable(const string &name) const;
    void WriteHeaderIfNecessary(void);

    DTDataFileContent *content;
};

#endif

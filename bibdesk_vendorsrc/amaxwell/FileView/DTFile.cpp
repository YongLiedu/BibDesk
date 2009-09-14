// Part of DTSource. Copyright 2004-2006. David Adalsteinsson.  BSD License
// see http://www.visualdatatools.com/DTSource/license.html for more information.

#include "DTFile.h"

#include "DTError.h"
#include <iostream>

#include <string>
#include <math.h>

#include "DTDoubleArray.h"
#include "DTFloatArray.h"
#include "DTIntArray.h"
#include "DTArray.h"
#include "DTCharArray.h"
#include "DTUCharArray.h"
#include "DTShortIntArray.h"
#include "DTUShortIntArray.h"
#include <limits>

struct DTFileStorage
{
    DTFileStorage();
    ~DTFileStorage();
    
    string name;
    FILE *file;
    bool readOnly;
    int retainCount;
    DTFilePosition lengthOfFile;
    
    DTFile::Endian endian;
};

DTFileStorage::DTFileStorage()
{
    retainCount = 1;
    readOnly = true;
    lengthOfFile = -1;
    file = NULL;
    endian = DTFile::Native;
}

DTFileStorage::~DTFileStorage()
{
    if (file) fclose(file);
}

DTFile::DTFile()
{
    storage = new DTFileStorage();
}

DTFile::DTFile(const string &nm,OpenType openT)
{
    storage = new DTFileStorage();
    storage->name = nm;

    if (openT==DTFile::ReadOnly) {
        storage->file = fopen(nm.c_str(),"rb");
        storage->readOnly = true;
    }
    else if (openT==DTFile::ExistingReadWrite) {
        storage->file = fopen(nm.c_str(),"r+b");
        storage->readOnly = false;
    }
    else {
        // Should delete the file first, to preserve hard links.
        remove(storage->name.c_str());
        storage->file = fopen(nm.c_str(),"w+b");
        storage->readOnly = false;
    }

    if (storage->file==NULL) {
        string msg = "Could not open the file \"";
        msg = msg + nm + "\"";
        DTErrorMessage("DTFile(name,type)",msg);
    }
}

DTFile::DTFile(const string &nm,Endian endian,OpenType openT)
{
    storage = new DTFileStorage();
    storage->name = nm;
    storage->endian = endian;

    if (openT==DTFile::ReadOnly) {
        storage->file = fopen(nm.c_str(),"rb");
        storage->readOnly = true;
    }
    else if (openT==DTFile::ExistingReadWrite) {
        storage->file = fopen(nm.c_str(),"r+b");
        storage->readOnly = false;
    }
    else {
        // Should delete the file first, to preserve hard links.
        remove(storage->name.c_str());
        storage->file = fopen(nm.c_str(),"w+b");
        storage->readOnly = false;
    }

    if (storage->file==NULL) {
        string msg = "Could not open the file \"";
        msg = msg + nm + "\"";
        DTErrorMessage("DTFile(name,type)",msg);
    }
}

DTFile::~DTFile()
{
    if (--(storage->retainCount)==0) {
        delete storage;
    }
}

DTFile::DTFile(const DTFile &C)
{
    storage = C.storage;
    storage->retainCount++;
}

DTFile &DTFile::operator=(const DTFile &C)
{
    if (storage!=C.storage) {
        if (--(storage->retainCount)==0) {
            delete storage;
        }
        storage = C.storage;
        storage->retainCount++;
    }
    
    return *this;
}

bool DTFile::CanOpen(const string &name,OpenType)
{
    bool toReturn = false;
    FILE *tempFile = NULL;
    
    tempFile = fopen(name.c_str(),"rb");
    toReturn = (tempFile!=NULL);
    if (tempFile) fclose(tempFile);
    
    return toReturn;
}

DTFilePosition DTFile::Position(void) const
{
    if (!storage->file) return 0;
#ifdef WIN32
    DTFilePosition toReturn = ftell(storage->file);
#else
    DTFilePosition toReturn = ftello(storage->file);
#endif
    return toReturn;
}

void DTFile::SetPosition(DTFilePosition pos) const
{
    if (!storage->file) return;
#ifdef WIN32
    fseek(storage->file,pos,SEEK_SET);
#else
    fseeko(storage->file,pos,SEEK_SET);
#endif
}

void DTFile::MovePosition(DTFilePosition pos) const
{
    if (!storage->file || pos==0) return;
#ifdef WIN32
    fseek(storage->file,pos,SEEK_CUR);
#else
    fseeko(storage->file,pos,SEEK_CUR);
#endif
}

void DTFile::MoveToEnd(void) const
{
    if (!storage->file) return;
#ifdef WIN32
    fseek(storage->file,0,SEEK_END);
#else
    fseeko(storage->file,0,SEEK_END);
#endif
}

void DTFile::Flush(void) const
{
    if (storage->file) fflush(storage->file);
}

FILE *DTFile::GetFILE(void) const
{
    return storage->file;
}

bool DTFile::IsOpen(void) const 
{
    return (storage->file!=NULL);
}

bool DTFile::IsReadOnly(void) const
{
    return storage->readOnly;
}

string DTFile::Name(void) const
{
    return storage->name;
}

DTFile::Endian DTFile::EndianType(void) const
{
    return storage->endian;
}

DTFilePosition DTFile::Length(void) const
{
    if (storage->lengthOfFile>=0)
        return storage->lengthOfFile;
    
    DTFilePosition nowAt = Position();
    MoveToEnd();
    DTFilePosition toReturn = Position();
    SetPosition(nowAt);
    
    storage->lengthOfFile = toReturn;
    
    return toReturn;
}

bool DTFile::Find(char c) const
{
    // Find a specific character in a file.  If the character is found, place
    // the current read position at that character and return true.
    // Otherwise go back to the position that the file had at the start of the read and return false.
    DTFilePosition howLong = Length();
    DTFilePosition nowAt = Position();
    DTFilePosition startsAt = nowAt;
    
    DTMutableCharArray buffer(1024);
    int i,howMuchToRead;
    bool foundIt = false;
    while (1) {
        howMuchToRead = 1024;
        if (nowAt+howMuchToRead>howLong)
            howMuchToRead = howLong-nowAt;
        if (howMuchToRead==0)
            break;
        if (!ReadBinary(buffer,howMuchToRead))
            break;
        nowAt += howMuchToRead;
        for (i=0;i<howMuchToRead;i++) {
            if (buffer(i)==c) {
                foundIt = true;
                break;
            }
        }
        if (i<howMuchToRead)
            break;
    }
    
    if (foundIt)
        MovePosition(i-howMuchToRead);
    else
        SetPosition(startsAt);
    
    return foundIt;
}

string DTFile::ReadLine(int maxLen) const
{
    if (!IsOpen()) {
        DTErrorMessage("DTFile::ReadLine()","No file");
        return string();
    }

    FILE *theFile = GetFILE();

    // Read until we hit \n or \r.  Swallow that character.
    DTMutableCharArray buffer(80);
    char temp;
    int locInBuffer = 0;
    while ((temp = fgetc(theFile))!=EOF && (maxLen<0 || locInBuffer < maxLen)) {
        if (temp=='\n' || temp=='\r' || temp=='\0')
            break;
        if (locInBuffer==buffer.Length()-1)
            buffer = IncreaseSize(buffer,buffer.Length());
        buffer(locInBuffer++) = temp;
    }
    
    // Check if this is a windows text file, where every line ends with a return+new line.
    if (temp=='\r') {
        temp = fgetc(theFile);
        if (temp!='\n') {
            // Step one step back.
            fseek(storage->file,-1,SEEK_CUR);
        }
    }

    buffer(locInBuffer) = '\0';

    string toReturn(buffer.Pointer());

    return toReturn;
}

string DTFile::ReadString(int length) const
{
    if (!IsOpen()) {
        DTErrorMessage("DTFile::ReadString(length)","No file");
        return string();
    }

    if (length<=0)
        return string();

    DTMutableCharArray A(length);
    if (fread(A.Pointer(),1,A.Length(),GetFILE())!=(unsigned int)A.Length()) {
        DTErrorMessage("DTFile::ReadString(length)",
                       "Could not read the required number of characters from the file");
        return string();
    }

    string toReturn(A.Pointer(),length);

    return toReturn;
}

string DTFile::NextWord(void) const
{
    if (!IsOpen()) {
        DTErrorMessage("DTFile::NextWord()","No file");
        return string();
    }
    
    FILE *theFile = GetFILE();
    
    // Read until we hit \n or \r.  Swallow that character.
    DTMutableCharArray buffer(80);
    char temp;
    int locInBuffer = 0;
    int lenBuffer = buffer.Length();
    bool atStart = true;
    while ((temp = fgetc(theFile))!=EOF) {
        // Skip over any leading spaces
        if (temp==32 && atStart) continue;
        atStart = false;
        if (temp<33 || temp>126)
            break;
        if (locInBuffer==lenBuffer-1) {
            buffer = IncreaseSize(buffer,buffer.Length());
            lenBuffer = buffer.Length();
        }
        buffer(locInBuffer++) = temp;
    }
    
    // Check if this is a windows text file, where every line ends with a return+new line.
    if (temp=='\r') {
        temp = fgetc(theFile);
        if (temp!='\n') {
            // Step one step back.
            fseek(storage->file,-1,SEEK_CUR);
        }
    }
    
    buffer(locInBuffer) = '\0';
    
    string toReturn(buffer.Pointer());
    
    return toReturn;
}

unsigned short int DTFile::ReadUnsignedShort() const
{
    unsigned short int toReturn = 0;
    
    if (!IsOpen())
        DTErrorMessage("DTFile::ReadUnsignedShort()","No file");
    else if (fread(&toReturn,sizeof(unsigned short int),1,GetFILE())!=1)
        DTErrorMessage("DTFile::ReadUnsignedShort()","Could not read the number");
    
    return toReturn;
}

float DTFile::ReadFloat() const
{
    float toReturn = 0;
    
    if (!IsOpen())
        DTErrorMessage("DTFile::ReadFloat()","No file");
    else if (fread(&toReturn,sizeof(float),1,GetFILE())!=1)
        DTErrorMessage("DTFile::ReadFloat()","Could not read the number");
    
    return toReturn;
}

bool DTFile::ReadBinary(DTMutableDoubleArray &A) const
{
    if (!IsOpen()) {
        DTErrorMessage("DTFile::ReadBinary(DoubleArray)","No file");
        return false;
    }

    if (A.IsEmpty())
        return true;

    if (fread(A.Pointer(),sizeof(double),A.Length(),GetFILE())!=(unsigned int)A.Length()) {
        DTErrorMessage("DTFile::ReadBinary(DoubleArray)",
                       "Could not read the required number of values from the file");
        return false;
    }

    return true;
}

bool DTFile::ReadBinary(DTMutableFloatArray &A) const
{
    if (!IsOpen()) {
        DTErrorMessage("DTFile::ReadBinary(FloatArray)","No file");
        return false;
    }

    if (A.IsEmpty())
        return true;

    if (fread(A.Pointer(),sizeof(float),A.Length(),GetFILE())!=(unsigned int)A.Length()) {
        DTErrorMessage("DTFile::ReadBinary(FloatArray)",
                       "Could not read the required number of values from the file");
        return false;
    }

    return true;
}

bool DTFile::ReadBinary(DTMutableIntArray &A) const
{
    if (!IsOpen()) {
        DTErrorMessage("DTFile::ReadBinary(IntArray)","No file");
        return false;
    }

    if (A.IsEmpty())
        return true;

    if (fread(A.Pointer(),sizeof(int),A.Length(),GetFILE())!=(unsigned int)A.Length()) {
        DTErrorMessage("DTFile::ReadBinary(IntArray)",
                       "Could not read the required number of values from the file");
        return false;
    }

    return true;
}

bool DTFile::ReadBinary(DTMutableShortIntArray &A) const
{
    if (!IsOpen()) {
        DTErrorMessage("DTFile::ReadBinary(ShortIntArray)","No file");
        return false;
    }

    if (A.IsEmpty())
        return true;

    if (fread(A.Pointer(),2,A.Length(),GetFILE())!=(unsigned int)A.Length()) {
        DTErrorMessage("DTFile::ReadBinary(ShortIntArray)",
                       "Could not read the required number of values from the file");
        return false;
    }

    return true;
}


bool DTFile::ReadBinary(DTMutableUShortIntArray &A) const
{
    if (!IsOpen()) {
        DTErrorMessage("DTFile::ReadBinary(UShortIntArray)","No file");
        return false;
    }

    if (A.IsEmpty())
        return true;

    if (fread(A.Pointer(),2,A.Length(),GetFILE())!=(unsigned int)A.Length()) {
        DTErrorMessage("DTFile::ReadBinary(UShortIntArray)",
                       "Could not read the required number of values from the file");
        return false;
    }

    return true;
}

bool DTFile::ReadBinary(DTMutableUCharArray &A) const
{
    return ReadBinary(A,0,A.Length());
}

bool DTFile::ReadBinary(DTMutableUCharArray &A,int len) const
{
    if (len<0 || A.Length()<len) {
        DTErrorMessage("DTFile::ReadBinary(UCharArray,int)","Invalid length");
        return false;
    }

    return ReadBinary(A,0,len);
}

bool DTFile::ReadBinary(DTMutableUCharArray &A,int startAt,int howMuchToRead) const
{
    if (!IsOpen()) {
        DTErrorMessage("DTFile::ReadBinary(UCharArray)","No file");
        return false;
    }

    if (A.IsEmpty())
        return true;

    if (startAt<0 || howMuchToRead<0 || A.Length()<startAt+howMuchToRead) {
        DTErrorMessage("DTFile::ReadBinary(UCharArray,int start,int length)","Invalid range");
        return false;
    }

    if (howMuchToRead==0)
        return true;

    if (fread(A.Pointer()+startAt,1,howMuchToRead,GetFILE())!=(unsigned int)howMuchToRead) {
        DTErrorMessage("DTFile::ReadBinary(UCharArray)",
                       "Could not read the required number of values from the file");
        return false;
    }

    return true;
}

bool DTFile::ReadBinary(DTMutableCharArray &A) const
{
    return ReadBinary(A,A.Length());
}

bool DTFile::ReadBinary(DTMutableCharArray &A,int len) const
{
    if (!IsOpen()) {
        DTErrorMessage("DTFile::ReadBinary(CharArray)","No file");
        return false;
    }

    if (A.IsEmpty())
        return true;

    if (A.Length()<len) {
        DTErrorMessage("DTFile::ReadBinary(CharArray,int)","Invalid length");
        return false;
    }

    if (fread(A.Pointer(),1,len,GetFILE())!=(unsigned int)len) {
        DTErrorMessage("DTFile::ReadBinary(CharArray)",
                       "Could not read the required number of values from the file");
        return false;
    }

    return true;
}

bool DTFile::ReadAscii(DTMutableDoubleArray &A) const
{
    if (!IsOpen()) {
        DTErrorMessage("DTFile::ReadAscii(DoubleArray)","No file");
        return false;
    }

    FILE *theFile = GetFILE();

    if (A.IsEmpty())
        return true;

    int pos = 0;
    int len = A.Length();
    int howMany;
    char singleChar;

    while (pos<len) {
        howMany = fscanf(theFile,"%lf",&A(pos));
        if (howMany==0) {
            // Try to skip over one character and try again.
            if (fread(&singleChar,1,1,theFile)!=1)
                break; // end of file
            howMany = fscanf(theFile,"%lf",&A(pos));
            if (howMany<=0)
                break;
        }
        else if (howMany==-1) {
            break;
        }
        pos++;
    }

    if (pos<len) {
        if (howMany==-1) {
            DTErrorMessage("DTFile::ReadAscii(DoubleArray)",
                           "Could not read the required number of values from the file");
        }
        return false;
    }

    return true;
}

bool DTFile::ReadAscii(DTMutableFloatArray &A) const
{
    if (!IsOpen()) {
        DTErrorMessage("DTFile::ReadAscii(FloatArray)","No file");
        return false;
    }

    FILE *theFile = GetFILE();

    if (A.IsEmpty())
        return true;

    int pos = 0;
    int len = A.Length();
    int howMany;
    char singleChar;

    while (pos<len) {
        howMany = fscanf(theFile,"%f",&A(pos));
        if (howMany==0) {
            // Try to skip over one character and try again.
            if (fread(&singleChar,1,1,theFile)!=1)
                break; // end of file
            continue;
        }
        pos++;
    }

    if (pos<len) {
        DTErrorMessage("DTFile::ReadAscii(FloatArray)",
                       "Could not read the required number of values from the file");
        return false;
    }

    return true;
}

double DTFile::ReadAsciiNumber(void) const
{
#if defined(WIN32) && !defined(NAN)
#define NAN std::numeric_limits<float>::quiet_NaN();
#endif
    if (!IsOpen()) {
        DTErrorMessage("DTFile::ReadAsciiNumber(DTFile)","No file");
        return NAN;
    }

    double toReturn = NAN;
    double temp;
    char singleChar;
    FILE *theFile = GetFILE();

    while (1) {
        if (fscanf(theFile,"%lf",&temp)==0) {
            // Try to skip over one character and try again.
            if (fread(&singleChar,1,1,theFile)!=1)
                break; // end of file
            continue;
        }
        toReturn = temp;
        break;
    }

    return toReturn;
}

char DTFile::CharacterAtCurrentPosition(void) const
{
    char toReturn = getc(GetFILE());
    MovePosition(-1);
    return toReturn;
}

bool DTFile::CheckWriteErrorState(const char *errStr) const
{
    if (!IsOpen()) {
        DTErrorMessage(errStr,"No file");
        return true;
    }
    if (storage->readOnly) {
        DTErrorMessage(errStr,"Read only");
        return true;
    }

    return false;
}

bool DTFile::WriteString(string theStr)
{
    if (CheckWriteErrorState("DTFile::WriteString(string)"))
        return false;
    
    const char *cStr = theStr.c_str();
    int len = theStr.length();
    
    if (fwrite(cStr,1,len,GetFILE())!=(unsigned int)len) {
        DTErrorMessage("DTFile::WriteString(string)","Could not write the string to the file.");
        return false;
    }
    
    return true;
}

bool DTFile::WriteStringWithZero(string theStr)
{
    if (CheckWriteErrorState("DTFile::WriteStringWithZero(string)"))
        return false;
    
    const char *cStr = theStr.c_str();
    int len = theStr.length()+1;
    
    if (fwrite(cStr,1,len,GetFILE())!=(unsigned int)len) {
        DTErrorMessage("DTFile::WriteStringWithZero(string)","Could not write the string to the file.");
        return false;
    }
    
    return true;
}

bool DTFile::WriteUnsignedShort(unsigned short int v)
{
    if (CheckWriteErrorState("DTFile::WriteUnsignedShort(value)"))
        return false;
    
    if (fwrite(&v,sizeof(unsigned short int),1,GetFILE())!=1) {
        DTErrorMessage("DTFile::WriteUnsignedShort(value)","Could not write the number to the file.");
        return false;
    }
    
    return true;
}

#if defined(WIN32)
bool DTFile::Write8ByteInt(__int64 v)
{
    if (CheckWriteErrorState("DTFile::Write8ByteInt(value)"))
        return false;
    
    if (fwrite(&v,sizeof(__int64),1,GetFILE())!=1) {
        DTErrorMessage("DTFile::Write8ByteInt(value)","Could not write the number to the file.");
        return false;
    }
    
    return true;
}
#else
bool DTFile::Write8ByteInt(int64_t v)
{
    if (CheckWriteErrorState("DTFile::Write8ByteInt(value)"))
        return false;
    
    if (fwrite(&v,sizeof(int64_t),1,GetFILE())!=1) {
        DTErrorMessage("DTFile::Write8ByteInt(value)","Could not write the number to the file.");
        return false;
    }
    
    return true;
}
#endif

bool DTFile::Write4ByteInt(int v)
{
    if (CheckWriteErrorState("DTFile::Write8ByteInt(value)"))
        return false;
    
    if (fwrite(&v,sizeof(int),1,GetFILE())!=1) {
        DTErrorMessage("DTFile::Write8ByteInt(value)","Could not write the number to the file.");
        return false;
    }
    
    return true;
}

bool DTFile::Write2ByteInt(short int v)
{
    if (CheckWriteErrorState("DTFile::Write8ByteInt(value)"))
        return false;
    
    if (fwrite(&v,sizeof(short int),1,GetFILE())!=1) {
        DTErrorMessage("DTFile::Write8ByteInt(value)","Could not write the number to the file.");
        return false;
    }
    
    return true;
}

bool DTFile::Write1ByteInt(char v)
{
    if (CheckWriteErrorState("DTFile::Write8ByteInt(value)"))
        return false;
    
    if (fwrite(&v,sizeof(char),1,GetFILE())!=1) {
        DTErrorMessage("DTFile::Write8ByteInt(value)","Could not write the number to the file.");
        return false;
    }
    
    return true;
}

bool DTFile::WriteRaw(const char *ptr,int howMany)
{
    if (CheckWriteErrorState("DTFile::WriteRaw(value)"))
        return false;
    
    if (int(fwrite(ptr,1,howMany,GetFILE()))!=howMany) {
        DTErrorMessage("DTFile::WriteRaw(ptr,length)","Could not write the data to the file.");
        return false;
    }
    
    return true;
}

bool DTFile::WriteBinary(const DTDoubleArray &A)
{
    if (CheckWriteErrorState("DTFile::WriteBinary(DTDoubleArray)"))
        return false;
    
    if (A.IsEmpty())
        return true;
    
    if (fwrite(A.Pointer(),sizeof(double),A.Length(),GetFILE())!=(unsigned int)A.Length()) {
        DTErrorMessage("DTFile::WriteBinary(DTDoubleArray)",
                       "Could not write the array to the file.");
        return false;
    }
    
    return true;
}

bool DTFile::WriteBinary(const DTFloatArray &A)
{
    if (CheckWriteErrorState("DTFile::WriteBinary(DTFloatArray)"))
        return false;
    
    if (A.IsEmpty())
        return true;
    
    if (fwrite(A.Pointer(),sizeof(float),A.Length(),GetFILE())!=(unsigned int)A.Length()) {
        DTErrorMessage("DTFile::WriteBinary(DTFloatArray)",
                       "Could not write the array to the file.");
        return false;
    }
    
    return true;
}

bool DTFile::WriteBinary(const DTIntArray &A)
{
    if (CheckWriteErrorState("DTFile::WriteBinary(DTIntArray)"))
        return false;
    
    if (A.IsEmpty())
        return true;
    
    if (fwrite(A.Pointer(),sizeof(int),A.Length(),GetFILE())!=(unsigned int)A.Length()) {
        DTErrorMessage("DTFile::WriteBinary(DTIntArray)",
                       "Could not write the array to the file.");
        return false;
    }
    
    return true;
}

bool DTFile::WriteBinary(const DTShortIntArray &A)
{
    if (CheckWriteErrorState("DTFile::WriteBinary(DTShortIntArray)"))
        return false;
    
    if (A.IsEmpty())
        return true;
    
    if (fwrite(A.Pointer(),sizeof(short int),A.Length(),GetFILE())!=(unsigned int)A.Length()) {
        DTErrorMessage("DTFile::WriteBinary(DTShortIntArray)",
                       "Could not write the array to the file.");
        return false;
    }
    
    return true;
}

bool DTFile::WriteBinary(const DTUShortIntArray &A)
{
    if (CheckWriteErrorState("DTFile::WriteBinary(DTUShortIntArray)"))
        return false;
    
    if (A.IsEmpty())
        return true;
    
    if (fwrite(A.Pointer(),sizeof(unsigned short int),A.Length(),GetFILE())!=(unsigned int)A.Length()) {
        DTErrorMessage("DTFile::WriteBinary(DTUShortIntArray)",
                       "Could not write the array to the file.");
        return false;
    }
    
    return true;
}

bool DTFile::WriteBinary(const DTCharArray &A)
{
    if (CheckWriteErrorState("DTFile::WriteBinary(DTCharArray)"))
        return false;
    
    if (A.IsEmpty())
        return true;
    
    if (fwrite(A.Pointer(),1,A.Length(),GetFILE())!=(unsigned int)A.Length()) {
        DTErrorMessage("DTFile::WriteBinary(DTCharArray)",
                       "Could not write the array to the file.");
        return false;
    }
    
    return true;
}

bool DTFile::WriteBinary(const DTUCharArray &A)
{
    if (CheckWriteErrorState("DTFile::WriteBinary(DTUCharArray)"))
        return false;
    
    if (A.IsEmpty())
        return true;

    if (fwrite(A.Pointer(),1,A.Length(),GetFILE())!=(unsigned int)A.Length()) {
        DTErrorMessage("DTFile::WriteBinary(DTUCharArray)",
                       "Could not write the array to the file.");
        return false;
    }

    return true;
}

void DTFile::pinfo(void) const
{
    cerr << "File = " << storage->name;
    if (IsReadOnly()) cerr << " [read only]";
    cerr << endl << flush;
}


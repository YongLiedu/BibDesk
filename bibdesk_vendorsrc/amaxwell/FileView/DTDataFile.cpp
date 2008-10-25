// Part of DTSource. Copyright 2004-2006. David Adalsteinsson.  BSD License
// see http://www.visualdatatools.com/DTSource/license.html for more information.

#include "DTDataFile.h"

#include "DTDoubleArray.h"
#include "DTIntArray.h"
#include "DTCharArray.h"
#include "DTUCharArray.h"
#include "DTFloatArray.h"
#include "DTShortIntArray.h"
#include "DTUShortIntArray.h"
#include "DTArrayConversion.h"
#include "DTUtilities.h"
#include "DTEndianSwap.h"
#include "DTLock.h"

#include "DTError.h"

#include <string>
#include <map>
#include <algorithm>

#if defined(WIN32)
typedef __int64 int64_t;
#endif
 
struct DTDataEntry {
    DTDataEntry() : m(0), n(0), o(0), type(0), location(-1) {}
    int m,n,o,type;
    off_t location; // -1 if not found.
};

struct DTDataFileStructure {
    DTDataFileStructure() : blockLength(0), type(0), m(0), n(0), o(0), nameLength(0) {}
    DTDataFileStructure(int mv,int nv,int ov,int bl,int tp,
                        int nl) : blockLength(bl), type(tp), m(mv), n(nv), o(ov), nameLength(nl) {}
    
    int64_t blockLength;  // Total length of this block (including this entry).
    int type;
    int m;
    int n;
    int o;
    int nameLength;             // Includes the ending \0
};

class DTDataFileContent
{
public:
    DTDataFileContent(DTFile file);
    
    void ReadInContent();
    void AddToIndex(const string &,const DTDataEntry &);
    void AddToIndex(const string &,double,const DTDataEntry &);
    
    void Lock(void) const {accessLock.Lock();}
    void Unlock(void) const {accessLock.Unlock();}
    
    DTLock accessLock;
    int referenceCount;
    map<string,DTDataEntry> content;
    
    DTFile file;
    
    bool saveIndex;
    DTFile indexFile;
    bool isAtEnd; // Where the read-head is.
    bool swapBytes;
    
private:
    DTDataFileContent(const DTDataFileContent &);
    DTDataFileContent &operator=(const DTDataFileContent &);
};

struct DTDataFileIndexEntry {
#ifdef WIN32
    long int location;
#else
    int64_t location;
#endif
    char type;
    int m;
    int n;
    int o;
    int nameLength;
};

DTDataFileContent::DTDataFileContent(DTFile f)
{
    referenceCount = 1;
    file = f;
    saveIndex = false;
    
    if (f.EndianType()==DTFile::Native) {
        swapBytes = false;
    }
    else if (f.EndianType()==DTFile::LittleEndian) {
        swapBytes = (DTDataStorage::RunningOnBigEndianMachine()==true);
    }
    else {
        swapBytes = (DTDataStorage::RunningOnBigEndianMachine()==false);
    }

    // Read in the content of the file, so subsequent access is much faster.
    ReadInContent();
}

void DTDataFileContent::AddToIndex(const string &varName,const DTDataEntry &dataEntry)
{
    if (saveIndex==false)
        return;

    char buff[25];
    // Some brute force pointer manipulation
    *((int64_t *)buff) = dataEntry.location;
    buff[8] = dataEntry.type;
    ((int *)(buff+9))[0] = dataEntry.m;
    ((int *)(buff+9))[1] = dataEntry.n;
    ((int *)(buff+9))[2] = dataEntry.o;
    ((int *)(buff+9))[3] = varName.length()+1;
    if (swapBytes) {
        DTSwap4Bytes((unsigned char *)buff+9,4*4);
    }    
    indexFile.WriteRaw(buff,25);
    indexFile.WriteStringWithZero(varName);
}

void DTDataFileContent::AddToIndex(const string &varName,double val,const DTDataEntry &dataEntry)
{
    if (saveIndex==false)
        return;

    char buff[33];
    // Some brute force pointer manipulation
    *((int64_t *)buff) = dataEntry.location;
    buff[8] = dataEntry.type+100;
    ((int *)(buff+9))[0] = dataEntry.m;
    ((int *)(buff+9))[1] = dataEntry.n;
    ((int *)(buff+9))[2] = dataEntry.o;
    ((int *)(buff+9))[3] = varName.length()+1;
    ((double *)(buff+25))[0] = val;
    if (swapBytes) {
        DTSwap4Bytes((unsigned char *)buff+9,4*4);
        DTSwap8Bytes((unsigned char *)buff+25,8);
    }
    indexFile.WriteRaw(buff,33);
    indexFile.WriteStringWithZero(varName);
}

void DTDataFileContent::ReadInContent(void)
{
    DTDataFileStructure TheHeader;
    DTDataEntry singleEntry;

    if (!file.IsOpen())
        return;

    FILE *theFile = file.GetFILE();
    off_t EndsAt = file.Length();
    
    size_t howMuchWasRead;
    char tempString[255];
    bool IsOK = true;
    off_t StartsAt;
    
    // The file always start with an identification string.
    // DataTank Binary File v1\0  - Always a big endian file (before Apple's Intel plans)
    // DataTank Binary File LE\0  - Little endian
    // DataTank Binary File BE\0  - Big endian
    
    // that is 24 bytes.
    const char *identifierOld = "DataTank Binary File v1\0";
    const char *identifierLE = "DataTank Binary File LE\0";
    const char *identifierBE = "DataTank Binary File BE\0";
    
    int howManyRead = fread(tempString,1,24,theFile);
    if (howManyRead==0) {
        return; // Empty is ok.
    }
    
    if (howManyRead!=24) {
        DTErrorMessage("DTDataFile::ReadInContent","Not a valid DataTank binary format.");
        return;
    }

    // Overwrite the swapBytes
    if (strncmp(identifierOld,tempString,24)==0) {
        swapBytes = (DTDataStorage::RunningOnBigEndianMachine()==false);
    }
    else if (strncmp(identifierLE,tempString,24)==0) {
        swapBytes = (DTDataStorage::RunningOnBigEndianMachine()==true);
    }
    else if (strncmp(identifierBE,tempString,24)==0) {
        swapBytes = (DTDataStorage::RunningOnBigEndianMachine()==false);
    }
    else {
        DTErrorMessage("DTDataFile::ReadInContent","Not a valid DataTank binary format.");
        return;
    }
    
    // See if there is an index file saved.
    string indexName;
    string thisFile = file.Name();
    if (thisFile.length()>=6 && thisFile.substr(thisFile.length()-6,6)==".dtbin") {
        indexName = thisFile.substr(0,thisFile.length()-6)+".index";
    }
    else {
        indexName = thisFile+".index";
    }
    if (DTFile::CanOpen(indexName,DTFile::ReadOnly)) {
        // Read in the portion of the file that is valid.  The index file might
        // include entries that haven't been completely saved in the data file, and
        // those entries should be quietly skipped.
        DTFile tempIndex(indexName,DTFile::ReadOnly);
        FILE *indexF = tempIndex.GetFILE();
        IsOK = (indexF!=NULL);
        short int theSize;
        if (fread(&theSize,2,1,indexF)!=1)
            IsOK = false;
        
        int64_t location,endPosition;
        int64_t startingLocation = 0;
        int nameLength,entrySize;
        
        unsigned char buffer[25];
        while (IsOK) {
            if (fread(buffer,25,1,indexF)==0)
                break; // Assume file ended.
            
            if (swapBytes) {
                DTSwap8Bytes(buffer,8);
                DTSwap4Bytes(buffer+9,16);
            }
            
            // Unpack
            location = *((int64_t *)buffer);
            singleEntry.type = buffer[8]%100;
            singleEntry.m = ((int *)(buffer+9))[0];
            singleEntry.n = ((int *)(buffer+9))[1];
            singleEntry.o = ((int *)(buffer+9))[2];
            nameLength = ((int *)(buffer+9))[3];
            singleEntry.location = location;
            
            if (nameLength==0 || nameLength>255 || singleEntry.m<0 || singleEntry.n<0 || singleEntry.o<0) {
                IsOK = false;
                break;
            }
            
            switch (singleEntry.type) {
                case DTDataFile_Double:
                    entrySize = 8;
                    break;
                case DTDataFile_Single:
                case DTDataFile_Signed32Int:
                    entrySize = 4;
                    break;
                case DTDataFile_UnsignedShort:
                case DTDataFile_Short:
                    entrySize = 2;
                    break;
                case DTDataFile_Unsigned8Char:
                case DTDataFile_Signed8Char:
                case DTDataFile_String:
                    entrySize = 1;
                    break;
                default:
                    IsOK = false;
            }
            if (!IsOK) break;

            // Might include the double value, but ignore it.
            if (buffer[8]>100)
                fread(buffer+9,entrySize,1,indexF);

            if (nameLength!=int(fread(tempString,1,nameLength,indexF))) {
                IsOK = false;
                break;
            }
            endPosition = location + entrySize*singleEntry.m*singleEntry.n*singleEntry.o;
            if (endPosition>EndsAt) {
                // This entry isn't completely stored in the file, ignore it.
                continue;
            }
            if (endPosition>startingLocation)
                startingLocation = endPosition;
            
            content[tempString] = singleEntry;
        }
        
        // Start reading the content from the final position that was saved.
        if (IsOK) {
            file.SetPosition(startingLocation);
        }
    }
    
    while (IsOK) {
        StartsAt = file.Position();

        howMuchWasRead = fread(&TheHeader,28,1,theFile);
        
        if (swapBytes) {
            DTSwap8Bytes(((unsigned char *)&TheHeader),8);
            DTSwap4Bytes(((unsigned char *)&TheHeader)+8,20);
        }
        if (howMuchWasRead==0) {
            break;
        }
        if (TheHeader.blockLength==0 ||
            howMuchWasRead<1 || TheHeader.type>2000 || TheHeader.nameLength>255) {
            DTErrorMessage("Reading In File Content","Invalid file format.");
            break;
        }
        if (int(TheHeader.blockLength)>EndsAt-StartsAt)
            break; // Incomplete data.  Most likely an incomplete write.

        howMuchWasRead = fread(tempString,1,TheHeader.nameLength,theFile);

        // Add this entry to the content list.
        singleEntry.location = StartsAt+28+TheHeader.nameLength;
        singleEntry.m = TheHeader.m;
        singleEntry.n = TheHeader.n;
        singleEntry.o = TheHeader.o;
        singleEntry.type = TheHeader.type;
        content[string(tempString)] = singleEntry;
        
        // Get ready for the next entry.
        file.SetPosition(StartsAt+TheHeader.blockLength);
    }
    isAtEnd = false;
}

DTDataFile::DTDataFile(DTFile file)
: DTDataStorage(), content(NULL)
{
    content = new DTDataFileContent(file);
}

DTDataFile::DTDataFile()
: DTDataStorage(), content(NULL)
{
    DTFile emptyFile;
    content = new DTDataFileContent(emptyFile);
}

DTDataFile::DTDataFile(const string &name,DTFile::OpenType oType)
: DTDataStorage(), content(NULL)
{
    content = new DTDataFileContent(DTFile(name,oType));
}

DTDataFile::DTDataFile(const DTDataFile &C)
: DTDataStorage(C), content(C.content)
{
    C.content->Lock();
    content = C.content;
    content->referenceCount++;
    C.content->Unlock();
}

DTDataFile &DTDataFile::operator=(const DTDataFile &C)
{
    if (content==C.content) return *this; // Slight thread safety issue might come up, if someone is reassigning the content.
    content->Lock();
    C.content->Lock();
    content->referenceCount--;
    if (content->referenceCount==0) {
        content->Unlock();
        delete content;
    }
    else {
        content->Unlock();
    }
    content = C.content;
    content->referenceCount++;
    content->Unlock();
    
    return *this;
}

DTDataFile::~DTDataFile()
{
    content->Lock();
    content->referenceCount--;
    if (content->referenceCount==0) {
        content->Unlock();
        delete content;
    }
    else {
        content->Unlock();
    }
}

DTMutablePointer<DTDataStorage> DTDataFile::AsPointer()
{
    return DTMutablePointer<DTDataStorage>(new DTDataFile(*this));
}

void DTDataFile::Save(int v,const string &name)
{
    DTMutableIntArray temp(1);
    temp(0) = v;
    Save(temp,name);
}

void DTDataFile::WriteHeaderIfNecessary(void)
{
    // Called inside a lock
    if (content->content.size()>0)
        return;
    
    const char *identifierLE = "DataTank Binary File LE\0";
    const char *identifierBE = "DataTank Binary File BE\0";
    const char *identifier;
    
    if (content->swapBytes) {
        if (DTDataStorage::RunningOnBigEndianMachine())
            identifier = identifierLE;
        else
            identifier = identifierBE;
    }
    else {
        if (DTDataStorage::RunningOnBigEndianMachine())
            identifier = identifierBE;
        else
            identifier = identifierLE;
    }
    
    fwrite(identifier,1,24, GetFILE());
}

void DTDataFile::Save(double v,const string &name)
{
    DTMutableDoubleArray temp(1);
    temp(0) = v;
    Save(temp,name);
}

void DTDataFile::Save(const DTDoubleArray &A,const string &VarName)
{
    content->Lock();
    if (IsReadOnly()) {
        DTErrorMessage("DTDataFile::Save","File is read only.");
        content->Unlock();
        return;
    }
    FILE *theFile = GetFILE();
    if (theFile==NULL) {
        DTErrorMessage("DTDataFile::Save","Empty File.");
        content->Unlock();
        return;
    }
    
    DTDataFileStructure TheHeader(A.m(),A.n(),A.o(),
                                  29+VarName.length()+A.Length()*sizeof(double),
                                  DTDataFile_Double,
                                  1+VarName.length());
    
    if (!content->isAtEnd) {
        content->file.MoveToEnd();
        content->isAtEnd = true;
    }
    
    WriteHeaderIfNecessary();
    
    DTDataEntry entry;
    entry.m = TheHeader.m;
    entry.n = TheHeader.n;
    entry.o = TheHeader.o;
    entry.type = TheHeader.type;
    entry.location = content->file.Position()+28+TheHeader.nameLength;
    content->content[VarName] = entry;

    if (content->swapBytes) {
        DTSwap8Bytes(((unsigned char *)&TheHeader),8);
        DTSwap4Bytes(((unsigned char *)&TheHeader)+8,20);
    }
    fwrite(&TheHeader,28, 1, theFile);
    fwrite(VarName.c_str(),sizeof(char),1+VarName.length(),theFile);

    if (A.Length()) {
        if (content->swapBytes) {
            DTMutableDoubleArray Temp = A.Copy();
            SwapEndian(Temp);
            fwrite(Temp.Pointer(),sizeof(double),Temp.Length(),theFile);
        }
        else {
            fwrite(A.Pointer(),sizeof(double),A.Length(),theFile);
        }
    }
    
    if (A.Length()==1) {
        content->AddToIndex(VarName,A(0),entry);
    }
    else {
        content->AddToIndex(VarName,entry);
    }
    content->Unlock();
}

void DTDataFile::Save(const DTFloatArray &A,const string &VarName)
{
    content->Lock();
    if (IsReadOnly()) {
        DTErrorMessage("DTDataFile::Save","File is read only.");
        content->Unlock();
        return;
    }
    FILE *theFile = GetFILE();
    if (theFile==NULL) {
        DTErrorMessage("DTDataFile::Save","Empty File.");
        content->Unlock();
        return;
    }
    
    DTDataFileStructure TheHeader(A.m(),A.n(),A.o(),
                                  29+VarName.length()+A.Length()*sizeof(float),
                                  DTDataFile_Single,
                                  1+VarName.length());

    if (!content->isAtEnd) {
        content->file.MoveToEnd();
        content->isAtEnd = true;
    }
    
    WriteHeaderIfNecessary();

    DTDataEntry entry;
    entry.m = TheHeader.m;
    entry.n = TheHeader.n;
    entry.o = TheHeader.o;
    entry.type = TheHeader.type;
    entry.location = content->file.Position()+28+TheHeader.nameLength;
    content->content[VarName] = entry;
    
    if (content->swapBytes) {
        DTSwap8Bytes(((unsigned char *)&TheHeader),8);
        DTSwap4Bytes(((unsigned char *)&TheHeader)+8,20);
    }
    fwrite(&TheHeader,28, 1, theFile);
    fwrite(VarName.c_str(),sizeof(char),1+VarName.length(),theFile);

    if (A.Length()) {
        if (content->swapBytes) {
            DTMutableFloatArray Temp = A.Copy();
            SwapEndian(Temp);
            fwrite(Temp.Pointer(),sizeof(float),Temp.Length(),theFile);
        }
        else {
            fwrite(A.Pointer(),sizeof(float),A.Length(),theFile);
        }
    }

    content->AddToIndex(VarName,entry);
    content->Unlock();
}

void DTDataFile::Save(const DTIntArray &A,const string &VarName)
{
    content->Lock();
    if (IsReadOnly()) {
        DTErrorMessage("DTDataFile::Save","File is read only.");
        content->Unlock();
        return;
    }
    FILE *theFile = GetFILE();
    if (theFile==NULL) {
        DTErrorMessage("DTDataFile::Save","Empty File.");
        content->Unlock();
        return;
    }
    
    DTDataFileStructure TheHeader(A.m(),A.n(),A.o(),
                                  29+VarName.length()+A.Length()*sizeof(int),
                                  DTDataFile_Signed32Int,
                                  1+VarName.length());
    
    if (!content->isAtEnd) {
        content->file.MoveToEnd();
        content->isAtEnd = true;
    }
    
    WriteHeaderIfNecessary();
    
    DTDataEntry entry;
    entry.m = TheHeader.m;
    entry.n = TheHeader.n;
    entry.o = TheHeader.o;
    entry.type = TheHeader.type;
    entry.location = content->file.Position()+28+TheHeader.nameLength;
    content->content[VarName] = entry;
    
    if (content->swapBytes) {
        DTSwap8Bytes(((unsigned char *)&TheHeader),8);
        DTSwap4Bytes(((unsigned char *)&TheHeader)+8,20);
    }
    fwrite(&TheHeader,28, 1, theFile);
    fwrite(VarName.c_str(),sizeof(char),1+VarName.length(),theFile);

    if (A.Length()) {
        if (content->swapBytes) {
            DTMutableIntArray Temp = A.Copy();
            SwapEndian(Temp);
            fwrite(Temp.Pointer(),sizeof(int),Temp.Length(),theFile);
        }
        else {
            fwrite(A.Pointer(),sizeof(int),A.Length(),theFile);
        }
    }

    content->AddToIndex(VarName,entry);
    content->Unlock();
}

void DTDataFile::Save(const DTUCharArray &A,const string &VarName)
{
    content->Lock();
    if (IsReadOnly()) {
        DTErrorMessage("DTDataFile::Save","File is read only.");
        content->Unlock();
        return;
    }
    FILE *theFile = GetFILE();
    if (theFile==NULL) {
        DTErrorMessage("DTDataFile::Save","Empty File.");
        content->Unlock();
        return;
    }
    
    DTDataFileStructure TheHeader(A.m(),A.n(),A.o(),
                                  29+VarName.length()+A.Length()*sizeof(char),
                                  DTDataFile_Unsigned8Char,
                                  1+VarName.length());

    if (!content->isAtEnd) {
        content->file.MoveToEnd();
        content->isAtEnd = true;
    }
    
    WriteHeaderIfNecessary();
    
    DTDataEntry entry;
    entry.m = TheHeader.m;
    entry.n = TheHeader.n;
    entry.o = TheHeader.o;
    entry.type = TheHeader.type;
    entry.location = content->file.Position()+28+TheHeader.nameLength;
    content->content[VarName] = entry;
    
    if (content->swapBytes) {
        DTSwap8Bytes(((unsigned char *)&TheHeader),8);
        DTSwap4Bytes(((unsigned char *)&TheHeader)+8,20);
    }
    fwrite(&TheHeader,28, 1, theFile);
    fwrite(VarName.c_str(),sizeof(char),1+VarName.length(),theFile);
    if (A.Length()) fwrite(A.Pointer(),sizeof(char),A.Length(),theFile);

    content->AddToIndex(VarName,entry);
    content->Unlock();
}

void DTDataFile::Save(const DTCharArray &A,const string &VarName)
{
    content->Lock();
    if (IsReadOnly()) {
        DTErrorMessage("DTDataFile::Save","File is read only.");
        content->Unlock();
        return;
    }
    FILE *theFile = GetFILE();
    if (theFile==NULL) {
        DTErrorMessage("DTDataFile::Save","Empty File.");
        content->Unlock();
        return;
    }
    
    DTDataFileStructure TheHeader(A.m(),A.n(),A.o(),
                                  29+VarName.length()+A.Length()*sizeof(char),
                                  DTDataFile_Signed8Char,
                                  1+VarName.length());

    if (!content->isAtEnd) {
        content->file.MoveToEnd();
        content->isAtEnd = true;
    }
    
    WriteHeaderIfNecessary();
    
    DTDataEntry entry;
    entry.m = TheHeader.m;
    entry.n = TheHeader.n;
    entry.o = TheHeader.o;
    entry.type = TheHeader.type;
    entry.location = content->file.Position()+28+TheHeader.nameLength;
    content->content[VarName] = entry;

    if (content->swapBytes) {
        DTSwap8Bytes(((unsigned char *)&TheHeader),8);
        DTSwap4Bytes(((unsigned char *)&TheHeader)+8,20);
    }
    fwrite(&TheHeader,28, 1, theFile);
    fwrite(VarName.c_str(),sizeof(char),1+VarName.length(),theFile);
    if (A.Length()) fwrite(A.Pointer(),sizeof(char),A.Length(),theFile);

    content->AddToIndex(VarName,entry);
    content->Unlock();
}

void DTDataFile::Save(const DTShortIntArray &A,const string &VarName)
{
    content->Lock();
    if (IsReadOnly()) {
        DTErrorMessage("DTDataFile::Save","File is read only.");
        content->Unlock();
        return;
    }
    FILE *theFile = GetFILE();
    if (theFile==NULL) {
        DTErrorMessage("DTDataFile::Save","Empty File.");
        content->Unlock();
        return;
    }
    
    DTDataFileStructure TheHeader(A.m(),A.n(),A.o(),
                                  29+VarName.length()+A.Length()*sizeof(short),
                                  DTDataFile_Short,
                                  1+VarName.length());
    
    if (!content->isAtEnd) {
        content->file.MoveToEnd();
        content->isAtEnd = true;
    }
    
    WriteHeaderIfNecessary();
    
    DTDataEntry entry;
    entry.m = TheHeader.m;
    entry.n = TheHeader.n;
    entry.o = TheHeader.o;
    entry.type = TheHeader.type;
    entry.location = content->file.Position()+28+TheHeader.nameLength;
    content->content[VarName] = entry;
    
    if (content->swapBytes) {
        DTSwap8Bytes(((unsigned char *)&TheHeader),8);
        DTSwap4Bytes(((unsigned char *)&TheHeader)+8,20);
    }
    fwrite(&TheHeader,28, 1, theFile);
    fwrite(VarName.c_str(),sizeof(char),1+VarName.length(),theFile);
    
    if (A.Length()) {
        if (content->swapBytes) {
            DTMutableShortIntArray Temp = A.Copy();
            SwapEndian(Temp);
            fwrite(Temp.Pointer(),sizeof(short int),Temp.Length(),theFile);
        }
        else {
            fwrite(A.Pointer(),sizeof(short int),A.Length(),theFile);
        }
    }

    content->AddToIndex(VarName,entry);
    content->Unlock();
}

void DTDataFile::Save(const DTUShortIntArray &A,const string &VarName)
{
    content->Lock();
    if (IsReadOnly()) {
        DTErrorMessage("DTDataFile::Save","File is read only.");
        content->Unlock();
        return;
    }
    FILE *theFile = GetFILE();
    if (theFile==NULL) {
        DTErrorMessage("DTDataFile::Save","Empty File.");
        content->Unlock();
        return;
    }
    
    DTDataFileStructure TheHeader(A.m(),A.n(),A.o(),
                                  29+VarName.length()+A.Length()*sizeof(short),
                                  DTDataFile_UnsignedShort,
                                  1+VarName.length());

    if (!content->isAtEnd) {
        content->file.MoveToEnd();
        content->isAtEnd = true;
    }
    
    WriteHeaderIfNecessary();
    
    DTDataEntry entry;
    entry.m = TheHeader.m;
    entry.n = TheHeader.n;
    entry.o = TheHeader.o;
    entry.type = TheHeader.type;
    entry.location = content->file.Position()+28+TheHeader.nameLength;
    content->content[VarName] = entry;

    if (content->swapBytes) {
        DTSwap8Bytes(((unsigned char *)&TheHeader),8);
        DTSwap4Bytes(((unsigned char *)&TheHeader)+8,20);
    }
    fwrite(&TheHeader,28, 1, theFile);
    fwrite(VarName.c_str(),sizeof(char),1+VarName.length(),theFile);

    if (A.Length()) {
        if (content->swapBytes) {
            DTMutableUShortIntArray Temp = A.Copy();
            SwapEndian(Temp);
            fwrite(Temp.Pointer(),sizeof(unsigned short int),Temp.Length(),theFile);
        }
        else {
            fwrite(A.Pointer(),sizeof(unsigned short int),A.Length(),theFile);
        }
    }

    content->AddToIndex(VarName,entry);
    content->Unlock();
}

void DTDataFile::Save(const string &theString,const string &VarName)
{
    content->Lock();
    if (IsReadOnly()) {
        DTErrorMessage("DTDataFile::Save","File is read only.");
        content->Unlock();
        return;
    }
    FILE *theFile = GetFILE();
    if (theFile==NULL) {
        DTErrorMessage("DTDataFile::Save","Empty File.");
        content->Unlock();
        return;
    }
    
    DTDataFileStructure TheHeader(theString.length()+1,1,1,
                                  29+VarName.length()+theString.length()+1,
                                  DTDataFile_String,
                                  1+VarName.length());

    if (!content->isAtEnd) {
        content->file.MoveToEnd();
        content->isAtEnd = true;
    }
    
    WriteHeaderIfNecessary();
    
    DTDataEntry entry;
    entry.m = TheHeader.m;
    entry.n = TheHeader.n;
    entry.o = TheHeader.o;
    entry.type = TheHeader.type;
    entry.location = content->file.Position()+28+TheHeader.nameLength;
    content->content[VarName] = entry;
    
    if (content->swapBytes) {
        DTSwap8Bytes(((unsigned char *)&TheHeader),8);
        DTSwap4Bytes(((unsigned char *)&TheHeader)+8,20);
    }
    fwrite(&TheHeader,28, 1, theFile);
    fwrite(VarName.c_str(),sizeof(char),1+VarName.length(),theFile);
    fwrite(theString.c_str(),sizeof(char),theString.length()+1,theFile);

    content->AddToIndex(VarName,entry);
    content->Unlock();
}

void DTDataFile::Flush(void) const
{
    if (IsReadOnly()) return;
    
    content->Lock();
    content->file.Flush();
    if (content->saveIndex)
        content->indexFile.Flush();
    content->Unlock();
}

DTDataEntry DTDataFile::FindVariable(const string &name) const
{
    // Inside a lock
    // should be in the content->content list
    map<string,DTDataEntry>::const_iterator searchResult = content->content.find(name);
    
    if (searchResult==content->content.end()) {
        return DTDataEntry();
    }
    else {
        return searchResult->second;
    }
}

DTList<string> DTDataFile::AllVariableNames(void) const
{
    content->Lock();
    DTMutableList<string> toReturn(content->content.size());
    
    map<string,DTDataEntry>::const_iterator mapIterator;
    int pos = 0;
    DTDataEntry fileEntry;
    
    for (mapIterator=content->content.begin();mapIterator!=content->content.end();++mapIterator) {
        toReturn(pos++) = mapIterator->first;
    }
    
    sort(toReturn.Pointer(),toReturn.Pointer()+toReturn.Length());
    
    content->Unlock();
    return toReturn;
}

struct DTDataFilePosString {
    long int pos;
    string description;

    bool operator<(const DTDataFilePosString &A) const {return (pos<A.pos);}
};

void DTDataFile::printInfo(void) const
{
    vector<DTDataFilePosString> list;
    DTDataFilePosString entry;
    string desc,stringValue;
    DTDataEntry fileEntry;

    cerr << "------------------------------------------------------------------------\n";
    cerr << "Content of \"" << content->file.Name() << "\" - ";
    int howMany = content->content.size();
    if (howMany==0)
        cerr << "empty\n";
    else if (howMany==1)
        cerr << "1 entry\n";
    else
        cerr << howMany << " entries\n";
    cerr << "------------------------------------------------------------------------\n";
    
    string padding = ".................................";
    
    map<string,DTDataEntry>::const_iterator mapIterator;
    for (mapIterator=content->content.begin();mapIterator!=content->content.end();++mapIterator) {
        fileEntry = mapIterator->second;
        entry.pos = fileEntry.location;
        desc = mapIterator->first + " ";
        // Pad to make it 30 characters
        if (desc.length()<30)
            desc = desc + string(padding,0,30-desc.length());
        switch (fileEntry.type) {
            case DTDataFile_Double:
                desc += " - double - ";
                break;
            case DTDataFile_Single:
                desc += " -  float - ";
                break;
            case DTDataFile_Signed32Int:
                desc += " -    int - ";
                break;
            case DTDataFile_UnsignedShort:
                desc += " - UShort - ";
                break;
            case DTDataFile_Short:
                desc += " -  short - ";
                break;
            case DTDataFile_Unsigned8Char:
                desc += " -  UChar - ";
                break;
            case DTDataFile_Signed8Char:
                desc += " -   char - ";
                break;
            case DTDataFile_String:
                desc += " - string - ";
                break;
            default:
                desc += " - ?????? - ";
                break;
        }
        // Dimension.
        if (fileEntry.type==DTDataFile_String) {
            stringValue = ReadString(mapIterator->first);
            if (stringValue.length()>25) {
                stringValue = "\""+string(stringValue,0,15) + "...\" - " + DTInt2String(fileEntry.m*fileEntry.n*fileEntry.o) + " characters";
            }
            desc += "\""+stringValue+"\"";
        }
        else {
            if (fileEntry.m==0)
                desc += "Empty";
            else if (fileEntry.m==1 && fileEntry.n==1 && fileEntry.o==1)
                desc += DTFloat2StringShort(ReadNumber(mapIterator->first));
            else if (fileEntry.n==1 && fileEntry.o==1)
                desc += DTInt2String(fileEntry.m) + " numbers";
            else if (fileEntry.o==1)
                desc += DTInt2String(fileEntry.m) + " x " + DTInt2String(fileEntry.n) + " array";
            else
                desc += DTInt2String(fileEntry.m) + " x " + DTInt2String(fileEntry.n) + " x " + DTInt2String(fileEntry.o) + " array";
        }
        entry.description = desc;
        list.push_back(entry);
    }
    
    sort(list.begin(),list.end());

    // Print the content
    int howLong = list.size();
    int pos = 0;
    vector<DTDataFilePosString>::iterator iter;
    for (iter=list.begin();iter!=list.end();++iter) {
        if (pos<390 || pos>howLong-10)
            cerr << iter->description << endl;
        else if (pos==380 && pos<howLong-20)
            cerr << "Skipping " << howLong-400 << " entries.\n";
        pos++;
    }
    cerr << flush;
}

bool DTDataFile::Contains(const string &name) const
{
    content->Lock();
    DTDataEntry entry = FindVariable(name);
    content->Unlock();
    return (entry.location>=0);
}

bool DTDataFile::IsReadOnly() const
{
    return content->file.IsReadOnly();
}

bool DTDataFile::SavedAsDouble(const string &name) const
{
    content->Lock();
    DTDataEntry entry = FindVariable(name);
    content->Unlock();
    if (entry.location<0) return false;
    return (entry.type==DTDataFile_Double);
}

bool DTDataFile::SavedAsString(const string &name) const
{
    content->Lock();
    DTDataEntry entry = FindVariable(name);
    content->Unlock();
    if (entry.location<0) return false;
    return (entry.type==DTDataFile_String);
}

FILE *DTDataFile::GetFILE(void) const
{
    return content->file.GetFILE();
}

void DTDataFile::SaveIndex(void)
{
    content->Lock();
    if (content->saveIndex) {
        content->Unlock();
        return;
    }
    
    content->saveIndex = true;
    
    // The main file needs to exist.
    if (content->file.IsOpen()==false) {
        content->Unlock();
        return;
    }
    
    // The name should have the ending .index
    string theN = content->file.Name();
    if (theN.length()>=6 && theN.substr(theN.length()-6,6)==".dtbin") {
        theN = theN.substr(0,theN.length()-6)+".index";
    }
    else {
        theN = theN+".index";
    }
    DTFile indexFile(theN,DTFile::NewReadWrite);
    if (indexFile.IsOpen()==false) {
        DTErrorMessage("DTDataFile::SaveIndex","Could not create the index file");
        content->saveIndex = false;
        content->Unlock();
        return;
    }
    
    // Write version information.
    indexFile.WriteUnsignedShort(sizeof(int64_t));
    
    // Write each entry as a block of the form:
    // offset - 8 bytes
    // type - 1 byte
    // m - 4 bytes
    // n - 4 bytes
    // o - 4 bytes
    // nameLength - 4 bytes.  Includes 0 termination  Length of next string
    // name
    
    map<string,DTDataEntry>::const_iterator mapIterator;
    string varName;
    DTDataEntry dataEntry;
    char buff[25];
    for (mapIterator=content->content.begin();mapIterator!=content->content.end();++mapIterator) {
        varName = mapIterator->first;
        dataEntry = mapIterator->second;

        // Some brute force pointer manipulation
        *((int64_t *)buff) = dataEntry.location;
        buff[8] = dataEntry.type;
        ((int *)(buff+9))[0] = dataEntry.m;
        ((int *)(buff+9))[1] = dataEntry.n;
        ((int *)(buff+9))[2] = dataEntry.o;
        ((int *)(buff+9))[3] = varName.length()+1;
        indexFile.WriteRaw(buff,25);
        indexFile.WriteStringWithZero(varName);
    }
    
    content->indexFile = indexFile;
    content->file.Flush();
    content->indexFile.Flush();
    content->Unlock();
}

DTDoubleArray DTDataFile::ReadDoubleArray(const string &name) const
{
    content->Lock();
    DTDataEntry entry = FindVariable(name);
    if (entry.location<0) {
        string msg = string("Did not find the variable \"") + name + "\" inside the datafile.";
        DTErrorMessage("dataFile.ReadDoubleArray(name)",msg);
        content->Unlock();
        return DTDoubleArray();
    }

    long int StartsAt = entry.location;

    int m = entry.m;
    int n = entry.n;
    int o = entry.o;

    // Now read the array.
    DTMutableDoubleArray toReturn(m,n,o);

    content->file.SetPosition(StartsAt);
    content->isAtEnd = false;
    if (entry.type==DTDataFile_Double) {
        content->file.ReadBinary(toReturn);
        if (content->swapBytes) SwapEndian(toReturn);
    }
    else if (entry.type==DTDataFile_Single) {
        // This is a float arrray.
        DTMutableFloatArray temp(m,n,o);
        content->file.ReadBinary(temp);
        if (content->swapBytes) SwapEndian(temp);
        ConvertArray(temp,toReturn);
    }
    else if (entry.type==DTDataFile_Signed32Int) {
        // This is an int arrray.
        DTMutableIntArray temp(m,n,o);
        content->file.ReadBinary(temp);
        if (content->swapBytes) SwapEndian(temp);
        ConvertArray(temp,toReturn);
    }
    else if (entry.type==DTDataFile_UnsignedShort) {
        // This is an unsigned short arrray.
        DTMutableUShortIntArray temp(m,n,o);
        content->file.ReadBinary(temp);
        if (content->swapBytes) SwapEndian(temp);
        ConvertArray(temp,toReturn);
    }
    else if (entry.type==DTDataFile_Short) {
        // This is an short arrray.
        DTMutableShortIntArray temp(m,n,o);
        content->file.ReadBinary(temp);
        if (content->swapBytes) SwapEndian(temp);
        ConvertArray(temp,toReturn);
    }
    else if (entry.type==DTDataFile_Unsigned8Char) {
        // This is an unsigned short arrray.
        DTMutableUCharArray temp(m,n,o);
        content->file.ReadBinary(temp);
        ConvertArray(temp,toReturn);
    }
    else if (entry.type==DTDataFile_Signed8Char) {
        // This is an short arrray.
        DTMutableCharArray temp(m,n,o);
        content->file.ReadBinary(temp);
        ConvertArray(temp,toReturn);
    }
    else {
        DTErrorMessage("dataFile.ReadDoubleArray(name)","Trying to read in a string.");
        toReturn = DTMutableDoubleArray();
    }

    content->Unlock();
    return toReturn;
}

DTFloatArray DTDataFile::ReadFloatArray(const string &name) const
{
    content->Lock();
    DTDataEntry entry = FindVariable(name);
    if (entry.location<0) {
        string msg = string("Did not find the variable \"") + name + "\" inside the datafile.";
        DTErrorMessage("dataFile.ReadFloatArray(name)",msg);
        content->Unlock();
        return DTFloatArray();
    }

    long int StartsAt = entry.location;

    int m = entry.m;
    int n = entry.n;
    int o = entry.o;
    
    // Now read the array.
    DTMutableFloatArray toReturn(m,n,o);

    content->file.SetPosition(StartsAt);
    content->isAtEnd = false;
    if (entry.type==DTDataFile_Double) {
        // This is a double arrray.
        DTMutableDoubleArray temp(m,n,o);
        content->file.ReadBinary(temp);
        if (content->swapBytes) SwapEndian(temp);
        ConvertArray(temp,toReturn);
    }
    else if (entry.type==DTDataFile_Single) {
        content->file.ReadBinary(toReturn);
        if (content->swapBytes) SwapEndian(toReturn);
    }
    else if (entry.type==DTDataFile_Signed32Int) {
        // This is an int arrray.
        DTMutableIntArray temp(m,n,o);
        content->file.ReadBinary(temp);
        if (content->swapBytes) SwapEndian(temp);
        ConvertArray(temp,toReturn);
    }
    else if (entry.type==DTDataFile_UnsignedShort) {
        // This is an unsigned short arrray.
        DTMutableUShortIntArray temp(m,n,o);
        content->file.ReadBinary(temp);
        if (content->swapBytes) SwapEndian(temp);
        ConvertArray(temp,toReturn);
    }
    else if (entry.type==DTDataFile_Short) {
        // This is an short arrray.
        DTMutableShortIntArray temp(m,n,o);
        content->file.ReadBinary(temp);
        if (content->swapBytes) SwapEndian(temp);
        ConvertArray(temp,toReturn);
    }
    else if (entry.type==DTDataFile_Unsigned8Char) {
        // This is an unsigned short arrray.
        DTMutableUCharArray temp(m,n,o);
        content->file.ReadBinary(temp);
        ConvertArray(temp,toReturn);
    }
    else if (entry.type==DTDataFile_Signed8Char) {
        // This is an short arrray.
        DTMutableCharArray temp(m,n,o);
        content->file.ReadBinary(temp);
        ConvertArray(temp,toReturn);
    }
    else {
        DTErrorMessage("dataFile.ReadFloatArray(name)","Trying to read in a string.");
        toReturn = DTMutableFloatArray();
    }
    content->Unlock();
    
    return toReturn;
}

DTIntArray DTDataFile::ReadIntArray(const string &name) const
{
    content->Lock();
    DTDataEntry entry = FindVariable(name);
    if (entry.location<0) {
        string msg = string("Did not find the variable \"") + name + "\" inside the datafile.";
        DTErrorMessage("dataFile.ReadIntArray(name)",msg);
        content->Unlock();
        return DTIntArray();
    }

    long int StartsAt = entry.location;

    int m = entry.m;
    int n = entry.n;
    int o = entry.o;
    
    // Now read the array.
    DTMutableIntArray toReturn(m,n,o);
    
    content->file.SetPosition(StartsAt);
    content->isAtEnd = false;
    if (entry.type==DTDataFile_Double) {
        // This is a double arrray.
        DTMutableDoubleArray temp(m,n,o);
        content->file.ReadBinary(temp);
        if (content->swapBytes) SwapEndian(temp);
        ConvertArray(temp,toReturn);
    }
    else if (entry.type==DTDataFile_Single) {
        // This is an float arrray.
        DTMutableFloatArray temp(m,n,o);
        content->file.ReadBinary(temp);
        if (content->swapBytes) SwapEndian(temp);
        ConvertArray(temp,toReturn);
    }
    else if (entry.type==DTDataFile_Signed32Int) {
        content->file.ReadBinary(toReturn);
        if (content->swapBytes) SwapEndian(toReturn);
    }
    else if (entry.type==DTDataFile_UnsignedShort) {
        // This is an unsigned short arrray.
        DTMutableUShortIntArray temp(m,n,o);
        content->file.ReadBinary(temp);
        if (content->swapBytes) SwapEndian(temp);
        ConvertArray(temp,toReturn);
    }
    else if (entry.type==DTDataFile_Short) {
        // This is an short arrray.
        DTMutableShortIntArray temp(m,n,o);
        content->file.ReadBinary(temp);
        if (content->swapBytes) SwapEndian(temp);
        ConvertArray(temp,toReturn);
    }
    else if (entry.type==DTDataFile_Unsigned8Char) {
        // This is an unsigned short arrray.
        DTMutableUCharArray temp(m,n,o);
        content->file.ReadBinary(temp);
        ConvertArray(temp,toReturn);
    }
    else if (entry.type==DTDataFile_Signed8Char) {
        // This is an short arrray.
        DTMutableCharArray temp(m,n,o);
        content->file.ReadBinary(temp);
        ConvertArray(temp,toReturn);
    }
    else {
        DTErrorMessage("dataFile.ReadIntArray(name)","Trying to read in a string.");
        toReturn = DTMutableIntArray();
    }
    content->Unlock();

    return toReturn;
}

DTCharArray DTDataFile::ReadCharArray(const string &name) const
{
    content->Lock();
    DTDataEntry entry = FindVariable(name);
    if (entry.location<0) {
        string msg = string("Did not find the variable \"") + name + "\" inside the datafile.";
        DTErrorMessage("dataFile.ReadCharArray(name)",msg);
        content->Unlock();
        return DTCharArray();
    }

    long int StartsAt = entry.location;

    int m = entry.m;
    int n = entry.n;
    int o = entry.o;

    // Now read the array.
    DTMutableCharArray toReturn(m,n,o);

    content->file.SetPosition(StartsAt);
    content->isAtEnd = false;
    if (entry.type==DTDataFile_Double) {
        // This is a double arrray.
        DTMutableDoubleArray temp(m,n,o);
        content->file.ReadBinary(temp);
        if (content->swapBytes) SwapEndian(temp);
        ConvertArray(temp,toReturn);
    }
    else if (entry.type==DTDataFile_Single) {
        // This is an float arrray.
        DTMutableFloatArray temp(m,n,o);
        content->file.ReadBinary(temp);
        if (content->swapBytes) SwapEndian(temp);
        ConvertArray(temp,toReturn);
    }
    else if (entry.type==DTDataFile_Signed32Int) {
        // This is an int arrray.
        DTMutableIntArray temp(m,n,o);
        content->file.ReadBinary(temp);
        if (content->swapBytes) SwapEndian(temp);
        ConvertArray(temp,toReturn);
    }
    else if (entry.type==DTDataFile_UnsignedShort) {
        // This is an unsigned short arrray.
        DTMutableUShortIntArray temp(m,n,o);
        content->file.ReadBinary(temp);
        if (content->swapBytes) SwapEndian(temp);
        ConvertArray(temp,toReturn);
    }
    else if (entry.type==DTDataFile_Short) {
        // This is an short arrray.
        DTMutableShortIntArray temp(m,n,o);
        content->file.ReadBinary(temp);
        if (content->swapBytes) SwapEndian(temp);
        ConvertArray(temp,toReturn);
    }
    else if (entry.type==DTDataFile_Unsigned8Char) {
        // This is an unsigned short arrray.
        DTMutableUCharArray temp(m,n,o);
        content->file.ReadBinary(temp);
        ConvertArray(temp,toReturn);
    }
    else if (entry.type==DTDataFile_Signed8Char) {
        content->file.ReadBinary(toReturn);
    }
    else if (entry.type==DTDataFile_String || entry.type==DTDataFile_Unsigned8Char) {
        DTMutableUCharArray temp(m,n,o);
        content->file.ReadBinary(temp);
        ConvertArray(temp,toReturn);
    }
    else {
        DTErrorMessage("dataFile.ReadCharArray(name)",
                       "Haven't taken care of this case.");
    }
    content->Unlock();
    
    return toReturn;
}

DTUCharArray DTDataFile::ReadUCharArray(const string &name) const
{
    content->Lock();
    DTDataEntry entry = FindVariable(name);
    if (entry.location<0) {
        string msg = string("Did not find the variable \"") + name + "\" inside the datafile.";
        DTErrorMessage("dataFile.ReadUCharArray(name)",msg);
        content->Unlock();
        return DTUCharArray();
    }

    long int StartsAt = entry.location;

    int m = entry.m;
    int n = entry.n;
    int o = entry.o;
    
    // Now read the array.
    DTMutableUCharArray toReturn(m,n,o);
    
    content->file.SetPosition(StartsAt);
    content->isAtEnd = false;
    if (entry.type==DTDataFile_Double) {
        // This is a double arrray.
        DTMutableDoubleArray temp(m,n,o);
        content->file.ReadBinary(temp);
        if (content->swapBytes) SwapEndian(temp);
        ConvertArray(temp,toReturn);
    }
    else if (entry.type==DTDataFile_Single) {
        // This is an float arrray.
        DTMutableFloatArray temp(m,n,o);
        content->file.ReadBinary(temp);
        if (content->swapBytes) SwapEndian(temp);
        ConvertArray(temp,toReturn);
    }
    else if (entry.type==DTDataFile_Signed32Int) {
        // This is an int arrray.
        DTMutableIntArray temp(m,n,o);
        content->file.ReadBinary(temp);
        if (content->swapBytes) SwapEndian(temp);
        ConvertArray(temp,toReturn);
    }
    else if (entry.type==DTDataFile_UnsignedShort) {
        // This is an unsigned short arrray.
        DTMutableUShortIntArray temp(m,n,o);
        content->file.ReadBinary(temp);
        if (content->swapBytes) SwapEndian(temp);
        ConvertArray(temp,toReturn);
    }
    else if (entry.type==DTDataFile_Short) {
        // This is an short arrray.
        DTMutableShortIntArray temp(m,n,o);
        content->file.ReadBinary(temp);
        if (content->swapBytes) SwapEndian(temp);
        ConvertArray(temp,toReturn);
    }
    else if (entry.type==DTDataFile_String || entry.type==DTDataFile_Unsigned8Char || entry.type==DTDataFile_Signed8Char) {
        content->file.ReadBinary(toReturn);
    }
    else {
        DTErrorMessage("dataFile.ReadCharArray(name)",
                       "Haven't taken care of this case.");
        toReturn = DTMutableUCharArray();
    }
    content->Unlock();
    
    return toReturn;
}

DTShortIntArray DTDataFile::ReadShortIntArray(const string &name) const
{
    content->Lock();
    DTDataEntry entry = FindVariable(name);
    if (entry.location<0) {
        string msg = string("Did not find the variable \"") + name + "\" inside the datafile.";
        DTErrorMessage("dataFile.ReadShortIntArray(name)",msg);
        content->Unlock();
        return DTShortIntArray();
    }

    long int StartsAt = entry.location;

    int m = entry.m;
    int n = entry.n;
    int o = entry.o;

    // Now read the array.
    DTMutableShortIntArray toReturn(m,n,o);

    content->file.SetPosition(StartsAt);
    content->isAtEnd = false;
    if (entry.type==DTDataFile_Double) {
        // This is a double arrray.
        DTMutableDoubleArray temp(m,n,o);
        content->file.ReadBinary(temp);
        if (content->swapBytes) SwapEndian(temp);
        ConvertArray(temp,toReturn);
    }
    else if (entry.type==DTDataFile_Single) {
        // This is an float arrray.
        DTMutableFloatArray temp(m,n,o);
        content->file.ReadBinary(temp);
        if (content->swapBytes) SwapEndian(temp);
        ConvertArray(temp,toReturn);
    }
    else if (entry.type==DTDataFile_Signed32Int) {
        // This is an int arrray.
        DTMutableIntArray temp(m,n,o);
        content->file.ReadBinary(temp);
        if (content->swapBytes) SwapEndian(temp);
        ConvertArray(temp,toReturn);
    }
    else if (entry.type==DTDataFile_UnsignedShort) {
        // This is an unsigned short arrray.
        DTMutableUShortIntArray temp(m,n,o);
        content->file.ReadBinary(temp);
        if (content->swapBytes) SwapEndian(temp);
        ConvertArray(temp,toReturn);
    }
    else if (entry.type==DTDataFile_Short) {
        content->file.ReadBinary(toReturn);
        if (content->swapBytes) SwapEndian(toReturn);
    }
    else if (entry.type==DTDataFile_Unsigned8Char) {
        // This is an unsigned short arrray.
        DTMutableUCharArray temp(m,n,o);
        content->file.ReadBinary(temp);
        ConvertArray(temp,toReturn);
    }
    else if (entry.type==DTDataFile_Signed8Char) {
        // This is an short arrray.
        DTMutableCharArray temp(m,n,o);
        content->file.ReadBinary(temp);
        ConvertArray(temp,toReturn);
    }
    else {
        DTErrorMessage("dataFile.ReadUShortIntArray(name)","Trying to read in a string.");
        toReturn = DTMutableShortIntArray();
    }
    content->Unlock();
    
    return toReturn;
}

DTUShortIntArray DTDataFile::ReadUShortIntArray(const string &name) const
{
    content->Lock();
    DTDataEntry entry = FindVariable(name);
    if (entry.location<0) {
        string msg = string("Did not find the variable \"") + name + "\" inside the datafile.";
        DTErrorMessage("dataFile.ReadUShortIntArray(name)",msg);
        content->Unlock();
        return DTUShortIntArray();
    }
    
    long int StartsAt = entry.location;
    
    int m = entry.m;
    int n = entry.n;
    int o = entry.o;
    
    // Now read the array.
    DTMutableUShortIntArray toReturn(m,n,o);
    
    content->file.SetPosition(StartsAt);
    content->isAtEnd = false;
    if (entry.type==DTDataFile_Double) {
        // This is a double arrray.
        DTMutableDoubleArray temp(m,n,o);
        content->file.ReadBinary(temp);
        if (content->swapBytes) SwapEndian(temp);
        ConvertArray(temp,toReturn);
    }
    else if (entry.type==DTDataFile_Single) {
        // This is an float arrray.
        DTMutableFloatArray temp(m,n,o);
        content->file.ReadBinary(temp);
        if (content->swapBytes) SwapEndian(temp);
        ConvertArray(temp,toReturn);
    }
    else if (entry.type==DTDataFile_Signed32Int) {
        // This is an int arrray.
        DTMutableIntArray temp(m,n,o);
        content->file.ReadBinary(temp);
        if (content->swapBytes) SwapEndian(temp);
        ConvertArray(temp,toReturn);
    }
    else if (entry.type==DTDataFile_UnsignedShort) {
        content->file.ReadBinary(toReturn);
        if (content->swapBytes) SwapEndian(toReturn);
    }
    else if (entry.type==DTDataFile_Short) {
        // This is an short arrray.
        DTMutableShortIntArray temp(m,n,o);
        content->file.ReadBinary(temp);
        if (content->swapBytes) SwapEndian(temp);
        ConvertArray(temp,toReturn);
    }
    else if (entry.type==DTDataFile_Unsigned8Char) {
        // This is an unsigned short arrray.
        DTMutableUCharArray temp(m,n,o);
        content->file.ReadBinary(temp);
        ConvertArray(temp,toReturn);
    }
    else if (entry.type==DTDataFile_Signed8Char) {
        // This is an short arrray.
        DTMutableCharArray temp(m,n,o);
        content->file.ReadBinary(temp);
        ConvertArray(temp,toReturn);
    }
    else {
        DTErrorMessage("dataFile.ReadUShortIntArray(name)","Trying to read in a string.");
        toReturn = DTMutableUShortIntArray();
    }
    content->Unlock();
    
    return toReturn;
}

string DTDataFile::ReadString(const string &name) const
{
    content->Lock();
    DTDataEntry entry = FindVariable(name);
    if (entry.location<0) {
        string msg = string("Did not find the string \"") + name + "\" inside the datafile.";
        DTErrorMessage("dataFile.ReadString(name)",msg);
        content->Unlock();
        return string();
    }
    if (entry.type!=DTDataFile_String) {
        string msg = string("The variable \"") + name + "\" is not a string.";
        DTErrorMessage("dataFile.ReadString(name)",msg);
        content->Unlock();
        return string();
    }

    if (entry.m==0) {
        content->Unlock();
        return string();
    }
    
    int m = entry.m;
    int n = entry.n;
    int o = entry.o;

    // Now read the array.
    content->file.SetPosition(entry.location);
    content->isAtEnd = false;

    DTMutableCharArray temp(m,n,o);
    content->file.ReadBinary(temp);

    string toReturn;
    if (temp(temp.Length()-1)=='\0')
        toReturn = temp.Pointer();
    else
        toReturn = string(temp.Pointer(),temp.Length());
    content->Unlock();
        
    return toReturn;
}


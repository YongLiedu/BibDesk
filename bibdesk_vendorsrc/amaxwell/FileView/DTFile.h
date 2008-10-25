// Part of DTSource. Copyright 2004-2006. David Adalsteinsson.  BSD License
// see http://www.visualdatatools.com/DTSource/license.html for more information.

#ifndef DTFile_Header
#define DTFile_Header

// Wrapper around a FILE pointer.  You can extract the pointer, or use the member functions
// to read the data, set file locations etc.

// This class will "own" the pointer and will call fclose() when the last reference is deleted.

// This is used in the data files, but handles the lowest level access.
// Also contains a number of ascii input routines.

#include <stdio.h>
#include <string>
using namespace std;

class DTDoubleArray;
class DTFloatArray;
class DTIntArray;
class DTShortIntArray;
class DTUShortIntArray;
class DTCharArray;
class DTUCharArray;

class DTMutableDoubleArray;
class DTMutableFloatArray;
class DTMutableIntArray;
class DTMutableCharArray;
class DTMutableUCharArray;
class DTMutableShortIntArray;
class DTMutableUShortIntArray;

class DTFileStorage;

#if defined(WIN32)
typedef __int64 DTFilePosition;
#else
typedef off_t DTFilePosition;
#endif

class DTFile {
public:
    enum OpenType {ReadOnly, ExistingReadWrite, NewReadWrite};
    enum Endian {Native,LittleEndian,BigEndian};

    DTFile();
    DTFile(const string &,OpenType=ExistingReadWrite);
    DTFile(const string &,Endian,OpenType=ExistingReadWrite);
    
    DTFile(const DTFile &);
    ~DTFile();
    DTFile &operator=(const DTFile &);
    
    static bool CanOpen(const string &,OpenType=ExistingReadWrite);

    bool IsOpen(void) const;
    bool IsReadOnly(void) const;
    string Name(void) const;
    DTFilePosition Length(void) const;
    Endian EndianType(void) const;
    
    // Position in the file.
    DTFilePosition Position(void) const;
    void SetPosition(DTFilePosition) const;
    void MovePosition(DTFilePosition) const;
    void MoveToEnd(void) const;

    void Flush(void) const;
        
    // In order to do anything, need to use the underlying FILE pointer.
    FILE *GetFILE(void) const;

    // Reading a string
    string ReadLine(int maxLen=-1) const; // To the next newline or \0 character
    string ReadString(int length) const; // Exact length.
    string NextWord(void) const; // Read until new line, space or non-printable character.  Swallows the next character.
    
    // Searching
    bool Find(char) const; // If found, position=location of character.
    
    // Binary input.  The size is determined by the array size.
    // If you need to change between big and little endian, use SwapEndian()
    // on the array.
    
    // Read in a single number (binary)
    unsigned short int ReadUnsignedShort() const;
    float ReadFloat() const;
    
    // Read in an array of entries.
    bool ReadBinary(DTMutableDoubleArray &A) const;
    bool ReadBinary(DTMutableFloatArray &A) const;
    bool ReadBinary(DTMutableIntArray &A) const;
    bool ReadBinary(DTMutableShortIntArray &A) const;
    bool ReadBinary(DTMutableUShortIntArray &A) const;
    bool ReadBinary(DTMutableUCharArray &A) const;
    bool ReadBinary(DTMutableUCharArray &A,int howMuchToRead) const;
    bool ReadBinary(DTMutableUCharArray &A,int startAt,int howMuchToRead) const;
    bool ReadBinary(DTMutableCharArray &) const;
    bool ReadBinary(DTMutableCharArray &,int howMuchToRead) const;
    
    char CharacterAtCurrentPosition(void) const;
    
    // Ascii input.
    bool ReadAscii(DTMutableDoubleArray &A) const;
    bool ReadAscii(DTMutableFloatArray &A) const;

    double ReadAsciiNumber() const;

    // Binary output
    
    bool WriteUnsignedShort(unsigned short int);
#if defined(WIN32)
    bool Write8ByteInt(__int64);
#else
    bool Write8ByteInt(int64_t);
#endif
    bool Write4ByteInt(int);
    bool Write2ByteInt(short int);
    bool Write1ByteInt(char);
    bool WriteRaw(const char *,int howMany);
    bool WriteString(string); // Will not save \0
    bool WriteStringWithZero(string);
    
    bool WriteBinary(const DTDoubleArray &);
    bool WriteBinary(const DTFloatArray &);
    bool WriteBinary(const DTIntArray &);
    bool WriteBinary(const DTShortIntArray &);
    bool WriteBinary(const DTUShortIntArray &);
    bool WriteBinary(const DTCharArray &);
    bool WriteBinary(const DTUCharArray &);
    
    // Debugging info.
    void pinfo(void) const;
    
private:
    bool CheckWriteErrorState(const char *) const;    
    
    DTFileStorage *storage;
};


#endif

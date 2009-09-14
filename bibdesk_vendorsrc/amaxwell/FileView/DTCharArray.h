// Part of DTSource. Copyright 2004-2006. David Adalsteinsson.  BSD License
// see http://www.visualdatatools.com/DTSource/license.html for more information.

#ifndef DTCharArray_Header
#define DTCharArray_Header

#include <iostream>
#include "DTLock.h"

// By default, range check is turned on.
#ifndef DTRangeCheck
#define DTRangeCheck 1
#endif

// An array of char numbers.  See comments inside DTDoubleArray for more information.
class DTCharArrayStorage {
public:
    DTCharArrayStorage(long int mv,long int nv,long int ov);
    ~DTCharArrayStorage();

    DTLock accessLock;
    long int m,n,o,mn,length;
    int referenceCount;
    char *Data;
    
private:
    DTCharArrayStorage(const DTCharArrayStorage &);
    DTCharArrayStorage &operator=(const DTCharArrayStorage &);
};

class DTMutableCharArray;
class DTIndex;
class DTCharArrayRegion;

class DTCharArray {

public:
    DTCharArray() : Storage(new DTCharArrayStorage(0,0,0)), invalidEntry(0) {}
    virtual ~DTCharArray() {Storage->accessLock.Lock(); int refCnt = (--Storage->referenceCount); Storage->accessLock.Unlock(); if (refCnt==0) delete Storage;}
    DTCharArray(const DTCharArray &A) : Storage(A.Storage), invalidEntry(0) {Storage->accessLock.Lock(); Storage->referenceCount++;Storage->accessLock.Unlock(); }
    DTCharArray &operator=(const DTCharArray &A);

protected:
    // If you get a notice that this is protected, change DTCharArray to DTMutableCharArray
    explicit DTCharArray(long int mv,long int nv=1,long int ov=1) : Storage(new DTCharArrayStorage(mv,nv,ov)), invalidEntry(0) {}

public:
    DTMutableCharArray Copy() const;

    // Size information.
    long int m() const {return Storage->m;}
    long int n() const {return Storage->n;}
    long int o() const {return Storage->o;}
    long int Length() const {return Storage->length;}
    bool IsEmpty() const {return (Storage->length==0);}
    bool NotEmpty() const {return (Storage->length!=0);}

    // Low level access
    int ReferenceCount() const {Storage->accessLock.Lock(); int refCnt = Storage->referenceCount; Storage->accessLock.Unlock(); return refCnt;}
    const char *Pointer() const {return Storage->Data;}

    // Allow A(i) and A(i,j), but check each access.
    char operator()(long int i) const
        {if (i<0 || i>=Storage->length)
            {PrintErrorMessage(i); return invalidEntry;}
            return Storage->Data[i];}
    char operator()(long int i,long int j) const
        {if (i<0 || i>=Storage->m || j<0 || j>=Storage->n)
            {PrintErrorMessage(i,j); return invalidEntry;}
            return Storage->Data[i+j*Storage->m];}
    char operator()(long int i,long int j,long int k) const
        {if (i<0 || i>=Storage->m || j<0 || j>=Storage->n || k<0 || k>=Storage->o)
            {PrintErrorMessage(i,j,k); return invalidEntry;}
            return Storage->Data[i+j*Storage->m+k*Storage->mn];}

    // Debug functions, since gdb can't call the () operator.
    char e(int i) const;
    char e(int i,int j) const;
    char e(int i,int j,int k) const;
    void pinfo(void) const;
    void pi(int i) const; // (i,:)
    void pj(int j) const; // (:,j)
    void pall(void) const;  // Uses the same layout as DataTank in the variable monitor.
    
    // Support for subregions
    const DTCharArrayRegion operator()(DTIndex) const;
    const DTCharArrayRegion operator()(DTIndex,DTIndex) const;
    const DTCharArrayRegion operator()(DTIndex,DTIndex,DTIndex) const;
    
protected:
    DTCharArrayStorage *Storage;
    char invalidEntry;

    // Error messages for index access.
    void PrintErrorMessage(long int i) const;
    void PrintErrorMessage(long int i,long int j) const;
    void PrintErrorMessage(long int i,long int j,long int k) const;
};

class DTMutableCharArray : public DTCharArray
{
public:
    DTMutableCharArray() : DTCharArray() {}
    explicit DTMutableCharArray(long int mv,long int nv=1,long int ov=1) : DTCharArray(mv,nv,ov) {}
    DTMutableCharArray(const DTMutableCharArray &A) : DTCharArray(A) {}

    DTMutableCharArray &operator=(const DTMutableCharArray &A) {DTCharArray::operator=(A); return *this;}

    // Assignment
    DTMutableCharArray &operator=(char a);

    // Raw access
    char *Pointer() {return Storage->Data;}
    const char *Pointer() const {return Storage->Data;}

    // High level access
    char operator()(long int i) const
        {if (i<0 || i>=Storage->length)
            {PrintErrorMessage(i); return invalidEntry;}
            return Storage->Data[i];}
    char &operator()(long int i)
        {if (i<0 || i>=Storage->length)
            {PrintErrorMessage(i); return invalidEntry;}
        return Storage->Data[i];}
    char operator()(long int i,long int j) const
        {if (i<0 || i>=Storage->m || j<0 || j>=Storage->n)
            {PrintErrorMessage(i,j); return invalidEntry;}
            return Storage->Data[i+j*Storage->m];}
    char &operator()(long int i,long int j)
        {if (i<0 || i>=Storage->m || j<0 || j>=Storage->n)
            {PrintErrorMessage(i,j); return invalidEntry;}
        return Storage->Data[i+j*Storage->m];}
    char operator()(long int i,long int j,long int k) const
        {if (i<0 || i>=Storage->m || j<0 || j>=Storage->n || k<0 || k>=Storage->o)
            {PrintErrorMessage(i,j,k); return invalidEntry;}
            return Storage->Data[i+j*Storage->m+k*Storage->mn];}
    char &operator()(long int i,long int j,long int k)
        {if (i<0 || i>=Storage->m || j<0 || j>=Storage->n || k<0 || k>=Storage->o)
            {PrintErrorMessage(i,j,k); return invalidEntry;}
        return Storage->Data[i+j*Storage->m+k*Storage->mn];}
    
    // Support for subregions
    const DTCharArrayRegion operator()(DTIndex) const;
    const DTCharArrayRegion operator()(DTIndex,DTIndex) const;
    const DTCharArrayRegion operator()(DTIndex,DTIndex,DTIndex) const;
    
    DTCharArrayRegion operator()(DTIndex);
    DTCharArrayRegion operator()(DTIndex,DTIndex);
    DTCharArrayRegion operator()(DTIndex,DTIndex,DTIndex);
};

// Misc
extern DTMutableCharArray Transpose(const DTCharArray &A);
extern bool operator==(const DTCharArray &A,const DTCharArray &B);
extern bool operator!=(const DTCharArray &A,const DTCharArray &B);

// Changing the size of an array
extern DTMutableCharArray TruncateSize(const DTCharArray &A,long int length);
extern DTMutableCharArray IncreaseSize(const DTCharArray &A,long int addLength);
extern DTMutableCharArray FlipJ(const DTCharArray &A);

#endif

// Part of DTSource. Copyright 2004-2006. David Adalsteinsson.  BSD License
// see http://www.visualdatatools.com/DTSource/license.html for more information.

#ifndef DTUShortIntArray_Header
#define DTUShortIntArray_Header

#include <iostream>
#include "DTLock.h"

// By default, range check is turned on.
#ifndef DTRangeCheck
#define DTRangeCheck 1
#endif

// An array of unsigned short int numbers.  See comments inside DTDoubleArray for more information.
class DTUShortIntArrayStorage {
public:
    DTUShortIntArrayStorage(long int mv,long int nv,long int ov);
    ~DTUShortIntArrayStorage();

    DTLock accessLock;
    long int m,n,o,mn,length;
    int referenceCount;
    unsigned short int *Data;
private:
    DTUShortIntArrayStorage(const DTUShortIntArrayStorage &);
    DTUShortIntArrayStorage &operator=(const DTUShortIntArrayStorage &);
};

class DTMutableUShortIntArray;
class DTIndex;
class DTUShortIntArrayRegion;

class DTUShortIntArray {

public:
    DTUShortIntArray() : Storage(new DTUShortIntArrayStorage(0,0,0)), invalidEntry(0) {}
    virtual ~DTUShortIntArray() {Storage->accessLock.Lock(); int refCnt = (--Storage->referenceCount); Storage->accessLock.Unlock(); if (refCnt==0) delete Storage;}
    DTUShortIntArray(const DTUShortIntArray &A) : Storage(A.Storage), invalidEntry(0) {Storage->accessLock.Lock(); Storage->referenceCount++;Storage->accessLock.Unlock(); }
    DTUShortIntArray &operator=(const DTUShortIntArray &A);

protected:
    // If you get a notice that this is protected, change DTUShortIntArray to DTMutableUShortIntArray
    explicit DTUShortIntArray(long int mv,long int nv=1,long int ov=1) : Storage(new DTUShortIntArrayStorage(mv,nv,ov)), invalidEntry(0) {}

public:
    DTMutableUShortIntArray Copy() const;

    // Size information.
    long int m() const {return Storage->m;}
    long int n() const {return Storage->n;}
    long int o() const {return Storage->o;}
    long int Length() const {return Storage->length;}
    bool IsEmpty() const {return (Storage->length==0);}
    bool NotEmpty() const {return (Storage->length!=0);}

    // Low level access
    int ReferenceCount() const {Storage->accessLock.Lock(); int refCnt = Storage->referenceCount; Storage->accessLock.Unlock(); return refCnt;}
    const unsigned short int *Pointer() const {return Storage->Data;}

    // Allow A(i) and A(i,j), but check each access.
    unsigned short int operator()(long int i) const
        {if (i<0 || i>=Storage->length)
            {PrintErrorMessage(i); return invalidEntry;}
            return Storage->Data[i];}
    unsigned short int operator()(long int i,long int j) const
        {if (i<0 || i>=Storage->m || j<0 || j>=Storage->n)
            {PrintErrorMessage(i,j); return invalidEntry;}
            return Storage->Data[i+j*Storage->m];}
    unsigned short int operator()(long int i,long int j,long int k) const
        {if (i<0 || i>=Storage->m || j<0 || j>=Storage->n || k<0 || k>=Storage->o)
            {PrintErrorMessage(i,j,k); return invalidEntry;}
            return Storage->Data[i+j*Storage->m+k*Storage->mn];}

    // Debug functions, since gdb can't call the () operator.
    unsigned short int e(int i) const;
    unsigned short int e(int i,int j) const;
    unsigned short int e(int i,int j,int k) const;
    void pinfo(void) const;
    void pi(int i) const; // (i,:)
    void pj(int j) const; // (:,j)
    void pall(void) const;  // Uses the same layout as DataTank in the variable monitor.
    
    // Support for subregions
    const DTUShortIntArrayRegion operator()(DTIndex) const;
    const DTUShortIntArrayRegion operator()(DTIndex,DTIndex) const;
    const DTUShortIntArrayRegion operator()(DTIndex,DTIndex,DTIndex) const;
    
protected:
    DTUShortIntArrayStorage *Storage;
    unsigned short int invalidEntry;

    // Error messages for index access.
    void PrintErrorMessage(long int i) const;
    void PrintErrorMessage(long int i,long int j) const;
    void PrintErrorMessage(long int i,long int j,long int k) const;
};

class DTMutableUShortIntArray : public DTUShortIntArray
{
public:
    DTMutableUShortIntArray() : DTUShortIntArray() {}
    explicit DTMutableUShortIntArray(long int mv,long int nv=1,long int ov=1) : DTUShortIntArray(mv,nv,ov) {}
    DTMutableUShortIntArray(const DTMutableUShortIntArray &A) : DTUShortIntArray(A) {}

    DTMutableUShortIntArray &operator=(const DTMutableUShortIntArray &A) {DTUShortIntArray::operator=(A); return *this;}

    // Assignment
    DTMutableUShortIntArray &operator=(unsigned short int a);

    // Raw access
    unsigned short int *Pointer() {return Storage->Data;}
    const unsigned short int *Pointer() const {return Storage->Data;}

    // High level access
    unsigned short int operator()(long int i) const {if (i<0 || i>=Storage->length) {PrintErrorMessage(i); return invalidEntry;} return Storage->Data[i];}
    unsigned short int &operator()(long int i) {if (i<0 || i>=Storage->length) {PrintErrorMessage(i); return invalidEntry;} return Storage->Data[i];}
    unsigned short int operator()(long int i,long int j) const
        {if (i<0 || i>=Storage->m || j<0 || j>=Storage->n)
            {PrintErrorMessage(i,j); return invalidEntry;}
            return Storage->Data[i+j*Storage->m];}
    unsigned short int &operator()(long int i,long int j)
        {if (i<0 || i>=Storage->m || j<0 || j>=Storage->n)
            {PrintErrorMessage(i,j); return invalidEntry;}
        return Storage->Data[i+j*Storage->m];}
    unsigned short int operator()(long int i,long int j,long int k) const
        {if (i<0 || i>=Storage->m || j<0 || j>=Storage->n || k<0 || k>=Storage->o)
            {PrintErrorMessage(i,j,k); return invalidEntry;}
            return Storage->Data[i+j*Storage->m+k*Storage->mn];}
    unsigned short int &operator()(long int i,long int j,long int k)
        {if (i<0 || i>=Storage->m || j<0 || j>=Storage->n || k<0 || k>=Storage->o)
            {PrintErrorMessage(i,j,k); return invalidEntry;}
        return Storage->Data[i+j*Storage->m+k*Storage->mn];}
    
    // Support for subregions
    const DTUShortIntArrayRegion operator()(DTIndex) const;
    const DTUShortIntArrayRegion operator()(DTIndex,DTIndex) const;
    const DTUShortIntArrayRegion operator()(DTIndex,DTIndex,DTIndex) const;
    
    DTUShortIntArrayRegion operator()(DTIndex);
    DTUShortIntArrayRegion operator()(DTIndex,DTIndex);
    DTUShortIntArrayRegion operator()(DTIndex,DTIndex,DTIndex);
};

// Misc
extern DTMutableUShortIntArray Transpose(const DTUShortIntArray &A);
extern bool operator==(const DTUShortIntArray &A,const DTUShortIntArray &B);
extern bool operator!=(const DTUShortIntArray &A,const DTUShortIntArray &B);

// Changing the size of an array
extern DTMutableUShortIntArray TruncateSize(const DTUShortIntArray &A,long int length);
extern DTMutableUShortIntArray IncreaseSize(const DTUShortIntArray &A,long int addLength);
extern DTMutableUShortIntArray FlipJ(const DTUShortIntArray &A);

#endif

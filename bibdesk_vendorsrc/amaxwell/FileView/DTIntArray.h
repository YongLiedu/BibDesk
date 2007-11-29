// Part of DTSource. Copyright 2004-2006. David Adalsteinsson.  BSD License
// see http://www.visualdatatools.com/DTSource/license.html for more information.

#ifndef DTIntArray_Header
#define DTIntArray_Header

#include <iostream>
#include "DTLock.h"

// By default, range check is turned on.
#ifndef DTRangeCheck
#define DTRangeCheck 1
#endif

// An array of int numbers.  See comments inside DTDoubleArray for more information.
class DTIntArrayStorage {
public:
    DTIntArrayStorage(long int mv,long int nv,long int ov);
    ~DTIntArrayStorage();

    DTLock accessLock;
    long int m,n,o,mn,length;
    int referenceCount;
    int *Data;
    
private:
    DTIntArrayStorage(const DTIntArrayStorage &);
    DTIntArrayStorage &operator=(const DTIntArrayStorage &);
};

class DTMutableIntArray;
class DTIndex;
class DTIntArrayRegion;

class DTIntArray {

public:
    DTIntArray() : Storage(new DTIntArrayStorage(0,0,0)), invalidEntry(0) {}
    virtual ~DTIntArray() {Storage->accessLock.Lock(); int refCnt = (--Storage->referenceCount); Storage->accessLock.Unlock(); if (refCnt==0) delete Storage;}
    DTIntArray(const DTIntArray &A) : Storage(A.Storage), invalidEntry(0) {Storage->accessLock.Lock(); Storage->referenceCount++;Storage->accessLock.Unlock(); }
    DTIntArray &operator=(const DTIntArray &A);

protected:
    // If you get a notice that this is protected, change DTIntArray to DTMutableIntArray
    explicit DTIntArray(long int mv,long int nv=1,long int ov=1) : Storage(new DTIntArrayStorage(mv,nv,ov)), invalidEntry(0) {}

public:
    DTMutableIntArray Copy() const;

    // Size information.
    long int m() const {return Storage->m;}
    long int n() const {return Storage->n;}
    long int o() const {return Storage->o;}
    long int Length() const {return Storage->length;}
    bool IsEmpty() const {return (Storage->length==0);}
    bool NotEmpty() const {return (Storage->length!=0);}

    // Low level access
    int ReferenceCount() const {Storage->accessLock.Lock(); int refCnt = Storage->referenceCount; Storage->accessLock.Unlock(); return refCnt;}
    const int *Pointer() const {return Storage->Data;}

    // Allow A(i) and A(i,j), but check each access.
    int operator()(long int i) const
        {if (i<0 || i>=Storage->length)
            {PrintErrorMessage(i); return invalidEntry;}
            return Storage->Data[i];}
    int operator()(long int i,long int j) const
        {if (i<0 || i>=Storage->m || j<0 || j>=Storage->n)
            {PrintErrorMessage(i,j); return invalidEntry;}
            return Storage->Data[i+j*Storage->m];}
    int operator()(long int i,long int j,long int k) const
        {if (i<0 || i>=Storage->m || j<0 || j>=Storage->n || k<0 || k>=Storage->o)
            {PrintErrorMessage(i,j,k); return invalidEntry;}
            return Storage->Data[i+j*Storage->m+k*Storage->mn];}

    // Debug functions, since gdb can't call the () operator.
    int e(int i) const;
    int e(int i,int j) const;
    int e(int i,int j,int k) const;
    void pinfo(void) const;
    void pi(int i) const; // (i,:)
    void pj(int j) const; // (:,j)
    void pall(void) const;  // Uses the same layout as DataTank in the variable monitor.
    void prange(int s,int e) const; // Offsets [s,e], both included.
    void pcrange(int s,int e) const; // Print (:,[s:e]), otherwise like pall().
    
    long int Find(int v) const;
    
    // Support for subregions
    const DTIntArrayRegion operator()(DTIndex) const;
    const DTIntArrayRegion operator()(DTIndex,DTIndex) const;
    const DTIntArrayRegion operator()(DTIndex,DTIndex,DTIndex) const;
    
protected:
    DTIntArrayStorage *Storage;
    int invalidEntry;

    // Error messages for index access.
    void PrintErrorMessage(long int i) const;
    void PrintErrorMessage(long int i,long int j) const;
    void PrintErrorMessage(long int i,long int j,long int k) const;
};

class DTMutableIntArray : public DTIntArray
{
public:
    DTMutableIntArray() : DTIntArray() {}
    explicit DTMutableIntArray(long int mv,long int nv=1,long int ov=1) : DTIntArray(mv,nv,ov) {}
    DTMutableIntArray(const DTMutableIntArray &A) : DTIntArray(A) {}

    DTMutableIntArray &operator=(const DTMutableIntArray &A) {DTIntArray::operator=(A); return *this;}

    // Assignment
    DTMutableIntArray &operator=(int a);

    // Raw access
    int *Pointer() {return Storage->Data;}
    const int *Pointer() const {return Storage->Data;}

    // High level access
    int operator()(long int i) const
        {if (i<0 || i>=Storage->length)
            {PrintErrorMessage(i); return invalidEntry;}
            return Storage->Data[i];}
    int &operator()(long int i)
        {if (i<0 || i>=Storage->length)
            {PrintErrorMessage(i); return invalidEntry;}
        return Storage->Data[i];}
    int operator()(long int i,long int j) const
        {if (i<0 || i>=Storage->m || j<0 || j>=Storage->n)
            {PrintErrorMessage(i,j); return invalidEntry;}
            return Storage->Data[i+j*Storage->m];}
    int &operator()(long int i,long int j)
        {if (i<0 || i>=Storage->m || j<0 || j>=Storage->n)
            {PrintErrorMessage(i,j); return invalidEntry;}
        return Storage->Data[i+j*Storage->m];}
    int operator()(long int i,long int j,long int k) const
        {if (i<0 || i>=Storage->m || j<0 || j>=Storage->n || k<0 || k>=Storage->o)
            {PrintErrorMessage(i,j,k); return invalidEntry;}
            return Storage->Data[i+j*Storage->m+k*Storage->mn];}
    int &operator()(long int i,long int j,long int k)
        {if (i<0 || i>=Storage->m || j<0 || j>=Storage->n || k<0 || k>=Storage->o)
            {PrintErrorMessage(i,j,k); return invalidEntry;}
        return Storage->Data[i+j*Storage->m+k*Storage->mn];}
    
    // Support for subregions
    const DTIntArrayRegion operator()(DTIndex) const;
    const DTIntArrayRegion operator()(DTIndex,DTIndex) const;
    const DTIntArrayRegion operator()(DTIndex,DTIndex,DTIndex) const;
    
    DTIntArrayRegion operator()(DTIndex);
    DTIntArrayRegion operator()(DTIndex,DTIndex);
    DTIntArrayRegion operator()(DTIndex,DTIndex,DTIndex);
};

bool operator==(const DTIntArray &A,const DTIntArray &B);
bool operator!=(const DTIntArray &A,const DTIntArray &B);

// Misc
extern DTMutableIntArray Transpose(const DTIntArray &A);
extern DTMutableIntArray Reshape(const DTIntArray &A,long int m,long int n=1,long int o=1);
extern DTMutableIntArray Sort(const DTIntArray &A);
extern DTMutableIntArray FlipJ(const DTIntArray &A);

extern long int FindEntry(const DTIntArray &,int); // Linear search for first entry (offset) -1 if not found
extern long int FindEntryInSorted(const DTIntArray &,int); // Same as above, just expects list to be increasing.

// Changing the size of an array
extern DTMutableIntArray TruncateSize(const DTIntArray &A,long int length);
extern DTMutableIntArray IncreaseSize(const DTIntArray &A,long int addLength);

#endif

// Part of DTSource. Copyright 2004-2006. David Adalsteinsson.  BSD License
// see http://www.visualdatatools.com/DTSource/license.html for more information.

#ifndef DTFloatArray_Header
#define DTFloatArray_Header

#include <iostream>
#include "DTLock.h"

// By default, range check is turned on.
#ifndef DTRangeCheck
#define DTRangeCheck 1
#endif

// An array of float numbers.  See comments inside DTDoubleArray for more information.
class DTFloatArrayStorage {
public:
    DTFloatArrayStorage(long int mv,long int nv,long int ov);
    ~DTFloatArrayStorage();

    DTLock accessLock;
    long int m,n,o,mn,length;
    int referenceCount;
    float *Data;
    
private:
    DTFloatArrayStorage(const DTFloatArrayStorage &);
    DTFloatArrayStorage &operator=(const DTFloatArrayStorage &);
};

class DTMutableFloatArray;
class DTIndex;
class DTFloatArrayRegion;

class DTFloatArray {

public:
    DTFloatArray() : Storage(new DTFloatArrayStorage(0,0,0)), invalidEntry(0.0) {}
    virtual ~DTFloatArray() {Storage->accessLock.Lock(); int refCnt = (--Storage->referenceCount); Storage->accessLock.Unlock(); if (refCnt==0) delete Storage;}
    DTFloatArray(const DTFloatArray &A) : Storage(A.Storage), invalidEntry(0.0) {Storage->accessLock.Lock(); Storage->referenceCount++;Storage->accessLock.Unlock(); }
    DTFloatArray &operator=(const DTFloatArray &A);

protected:
    // If you get a notice that this is protected, change DTFloatArray to DTMutableFloatArray
    explicit DTFloatArray(long int mv,long int nv=1,long int ov=1) : Storage(new DTFloatArrayStorage(mv,nv,ov)), invalidEntry(0.0) {}

public:
    DTMutableFloatArray Copy() const;

    // Size information.
    long int m() const {return Storage->m;}
    long int n() const {return Storage->n;}
    long int o() const {return Storage->o;}
    long int Length() const {return Storage->length;}
    bool IsEmpty() const {return (Storage->length==0);}
    bool NotEmpty() const {return (Storage->length!=0);}

    // Low level access
    int ReferenceCount() const {Storage->accessLock.Lock(); int refCnt = Storage->referenceCount; Storage->accessLock.Unlock(); return refCnt;}
    const float *Pointer() const {return Storage->Data;}

    // Allow A(i) and A(i,j), but check each access.
    float operator()(long int i) const
        {if (i<0 || i>=Storage->length)
            {PrintErrorMessage(i); return invalidEntry;}
            return Storage->Data[i];}
    float operator()(long int i,long int j) const
        {if (i<0 || i>=Storage->m || j<0 || j>=Storage->n)
            {PrintErrorMessage(i,j); return invalidEntry;}
            return Storage->Data[i+j*Storage->m];}
    float operator()(long int i,long int j,long int k) const
        {if (i<0 || i>=Storage->m || j<0 || j>=Storage->n || k<0 || k>=Storage->o)
            {PrintErrorMessage(i,j,k); return invalidEntry;}
            return Storage->Data[i+j*Storage->m+k*Storage->mn];}

    // Debug functions, since gdb can't call the () operator.
    float e(int i) const;
    float e(int i,int j) const;
    float e(int i,int j,int k) const;
    void pinfo(void) const;
    void pi(int i) const; // (i,:)
    void pj(int j) const; // (:,j)
    void pall(void) const;  // Uses the same layout as DataTank in the variable monitor.
    
    long int Find(float v) const;
    
    // Support for subregions
    const DTFloatArrayRegion operator()(DTIndex) const;
    const DTFloatArrayRegion operator()(DTIndex,DTIndex) const;
    const DTFloatArrayRegion operator()(DTIndex,DTIndex,DTIndex) const;
    
protected:
    DTFloatArrayStorage *Storage;
    float invalidEntry;

    // Error messages for index access.
    void PrintErrorMessage(long int i) const;
    void PrintErrorMessage(long int i,long int j) const;
    void PrintErrorMessage(long int i,long int j,long int k) const;
};

class DTMutableFloatArray : public DTFloatArray
{
public:
    DTMutableFloatArray() : DTFloatArray() {}
    explicit DTMutableFloatArray(long int mv,long int nv=1,long int ov=1) : DTFloatArray(mv,nv,ov) {}
    DTMutableFloatArray(const DTMutableFloatArray &A) : DTFloatArray(A) {}

    DTMutableFloatArray &operator=(const DTMutableFloatArray &A) {DTFloatArray::operator=(A); return *this;}

    // Assignment
    DTMutableFloatArray &operator=(float a);

    // Raw access
    float *Pointer() {return Storage->Data;}
    const float *Pointer() const {return Storage->Data;}

    // High level access
    float operator()(long int i) const
        {if (i<0 || i>=Storage->length)
            {PrintErrorMessage(i); return invalidEntry;}
            return Storage->Data[i];}
    float &operator()(long int i)
        {if (i<0 || i>=Storage->length)
            {PrintErrorMessage(i); return invalidEntry;}
        return Storage->Data[i];}
    float operator()(long int i,long int j) const
        {if (i<0 || i>=Storage->m || j<0 || j>=Storage->n)
            {PrintErrorMessage(i,j); return invalidEntry;}
            return Storage->Data[i+j*Storage->m];}
    float &operator()(long int i,long int j)
        {if (i<0 || i>=Storage->m || j<0 || j>=Storage->n)
            {PrintErrorMessage(i,j); return invalidEntry;}
        return Storage->Data[i+j*Storage->m];}
    float operator()(long int i,long int j,long int k) const
        {if (i<0 || i>=Storage->m || j<0 || j>=Storage->n || k<0 || k>=Storage->o)
            {PrintErrorMessage(i,j,k); return invalidEntry;}
            return Storage->Data[i+j*Storage->m+k*Storage->mn];}
    float &operator()(long int i,long int j,long int k)
        {if (i<0 || i>=Storage->m || j<0 || j>=Storage->n || k<0 || k>=Storage->o)
            {PrintErrorMessage(i,j,k); return invalidEntry;}
        return Storage->Data[i+j*Storage->m+k*Storage->mn];}

    // Support for subregions
    const DTFloatArrayRegion operator()(DTIndex) const;
    const DTFloatArrayRegion operator()(DTIndex,DTIndex) const;
    const DTFloatArrayRegion operator()(DTIndex,DTIndex,DTIndex) const;
    
    DTFloatArrayRegion operator()(DTIndex);
    DTFloatArrayRegion operator()(DTIndex,DTIndex);
    DTFloatArrayRegion operator()(DTIndex,DTIndex,DTIndex);
};

bool operator==(const DTFloatArray &A,const DTFloatArray &B);
bool operator!=(const DTFloatArray &A,const DTFloatArray &B);

// Misc
extern DTMutableFloatArray Transpose(const DTFloatArray &A);
extern DTMutableFloatArray Reshape(const DTFloatArray &A,long int m,long int n=1,long int o=1);
extern DTMutableFloatArray Sort(const DTFloatArray &A);
extern DTMutableFloatArray FlipJ(const DTFloatArray &A);

// Changing the size of an array
extern DTMutableFloatArray TruncateSize(const DTFloatArray &A,long int length);
extern DTMutableFloatArray IncreaseSize(const DTFloatArray &A,long int addLength);

extern DTMutableFloatArray CombineColumns(const DTFloatArray &First,const DTFloatArray &Second);
extern DTMutableFloatArray CombineColumns(const DTFloatArray &First,const DTFloatArray &Second,long int fromSecond);

#endif

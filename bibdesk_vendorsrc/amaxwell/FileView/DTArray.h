// Part of DTSource. Copyright 2004-2006. David Adalsteinsson.  BSD License
// see http://www.visualdatatools.com/DTSource/license.html for more information.

#ifndef DTArrayT_Header
#define DTArrayT_Header


/*
 1,2,3 dimensional array of any object.  Works in many ways similar to the DTDoubleArray etc, but
 has less functionality
 
 Key features are
 
 DTMutableArray<myType> array(3,3);
 array = singleEntry;
 
 array(0,0) = array(5); // since array(5) = array(2,1), since array(i,j) = array(i+j*m).
 
 array(3,2) = a;  // will give a run time error and call DTErrorOutOfRange(...), found in DTError.cpp
 
 DTArrray brray = array; // Will not copy data, but b will be a const form of the array.
 brray(2,2) = a;  // Will not compile, since brray is a const array.
 
 array.m(), array.n(), array.o() will get the array dimensions.
 array.Length() - total length of the pointer.
 array.Pointer()  - the underlying data as a vector (array(i,j,k) = i+j*m+k*m*n - column major).
 
 See DTDoubleArray.h for more information.
 */

#include "DTError.h"

// By default, range check is turned on.
#ifndef DTRangeCheck
#define DTRangeCheck 1
#endif

template <class T>
class DTArrayStorage {
public:
    DTArrayStorage<T>(long int mv,long int nv,long int ov) {
        // Check if it's called correctly.
        m = mv>0 ? mv : 0;
        n = nv>0 ? nv : 0;
        o = ov>0 ? ov : 0;
        length = m*n*o;
        if (length==0) m = n = o = 0;
        referenceCount = 1;
        mn = m*n;

        Data = length==0 ? NULL : new T[length];
    }
    ~DTArrayStorage<T>() {delete [] Data;}

    long int m,n,o,mn,length;
    int referenceCount;
    T *Data;
};

template <class T> class DTMutableArray;

template <class T>
class DTArray{
public:
    DTArray<T>() : Storage(new DTArrayStorage<T>(0,0,0)) {}
    ~DTArray<T>() {if (--Storage->referenceCount==0) delete Storage;}
    DTArray<T>(const DTArray<T> &A) : Storage(A.Storage) {Storage->referenceCount++;}
    void operator=(const DTArray<T> &A) {
        // Allow A = A
        if (Storage==A.Storage) return;

        Storage->referenceCount--;
        if (Storage->referenceCount==0) delete Storage;
        Storage = A.Storage;
        Storage->referenceCount++;
    }

protected:
    // Standard operators for construction, destruction and assignment.
    explicit DTArray<T>(long int mv,long int nv=1,long int ov=1) : Storage(new DTArrayStorage<T>(mv,nv,ov)) {}

public:
    DTMutableArray<T> Copy() const {DTMutableArray<T> toR(m(),n(),o()); const T *F = Storage->Data; T *To = toR.Storage.Data; long int len = Storage->length; for (long int i=0;i<len;i++) To[i] = F[i];}
    
    // Size information.
    long int m() const {return Storage->m;}
    long int n() const {return Storage->n;}
    long int o() const {return Storage->o;}
    long int Length() const {return Storage->length;}
    bool IsEmpty() const {return (Storage->length==0);}
    bool NotEmpty() const {return (Storage->length!=0);}
    
    // Low level access
    int ReferenceCount() const {return Storage->referenceCount;}
    const T *Pointer() const {return Storage->Data;}
    
    // Allow A(i) and A(i,j), but check each access.
#if DTRangeCheck
    T operator()(long int i) const
        {if (i<0 || i>=Storage->length)
            {DTErrorOutOfRange("DTArray<T>",i,Storage->length); return invalidEntry;}
         return Storage->Data[i];}
    T operator()(long int i,long int j) const
        {if (i<0 || i>=Storage->m || j<0 || j>=Storage->n)
            {DTErrorOutOfRange("DTArray<T>",i,j,Storage->m,Storage->n); return invalidEntry;}
         return Storage->Data[i+j*Storage->m];}
    T operator()(long int i,long int j,long int k) const
        {if (i<0 || i>=Storage->m || j<0 || j>=Storage->n || k<0 || k>=Storage->o)
            {DTErrorOutOfRange("DTArray<T>",i,j,k,Storage->m,Storage->n,Storage->o); return invalidEntry;}
            return Storage->Data[i+j*Storage->m+k*Storage->mn];}
#else
    // No range check.  Slightly faster, but not as safe.
    T operator()(long int i) const {return Storage->Data[i];}
    T operator()(long int i,long int j) const {return Storage->Data[i+j*Storage->m];}
    T operator()(long int i,long int j,long int k) const {return Storage->Data[i+j*Storage->m+k*Storage->mn];}
#endif

protected:
    DTArrayStorage<T> *Storage;
    T invalidEntry;
};

template <class T>
class DTMutableArray : public DTArray<T>
{
public:
    DTMutableArray<T>() : DTArray<T>() {}
    DTMutableArray<T>(long int m,long int n=1,long int o=1) : DTArray<T>(m,n,o) {}
    DTMutableArray<T>(const DTMutableArray<T> &A) : DTArray<T>(A) {}

    void operator=(const DTMutableArray<T> &A) {DTArray<T>::operator=(A);}

    // Assignment
    void operator=(const T &a) {T *D = DTArray<T>::Storage->Data; for (long int i=0;i<DTArray<T>::Storage->length;i++) D[i]=a;}

    // Raw access
    T *Pointer() {return DTArray<T>::Storage->Data;}
    const T *Pointer() const {return DTArray<T>::Storage->Data;}

    // High level access
#if DTRangeCheck
    T operator()(long int i) const
        {if (i<0 || i>=DTArray<T>::Storage->length)
            {DTErrorOutOfRange("DTArray<T>",i,DTArray<T>::Storage->length); return DTArray<T>::invalidEntry;}
            return DTArray<T>::Storage->Data[i];}
    T &operator()(long int i)
        {if (i<0 || i>=DTArray<T>::Storage->length)
            {DTErrorOutOfRange("DTArray<T>",i,DTArray<T>::Storage->length); return DTArray<T>::invalidEntry;}
        return DTArray<T>::Storage->Data[i];}
    T operator()(long int i,long int j) const
        {if (i<0 || i>=DTArray<T>::Storage->m || j<0 || j>=DTArray<T>::Storage->n)
            {DTErrorOutOfRange("DTArray<T>",i,j,DTArray<T>::Storage->m,DTArray<T>::Storage->n); return DTArray<T>::invalidEntry;}
            return DTArray<T>::Storage->Data[i+j*DTArray<T>::Storage->m];}
    T &operator()(long int i,long int j)
        {if (i<0 || i>=DTArray<T>::Storage->m || j<0 || j>=DTArray<T>::Storage->n)
            {DTErrorOutOfRange("DTArray<T>",i,j,DTArray<T>::Storage->m,DTArray<T>::Storage->n); return DTArray<T>::invalidEntry;}
        return DTArray<T>::Storage->Data[i+j*DTArray<T>::Storage->m];}
    T operator()(long int i,long int j,long int k) const
        {if (i<0 || i>=DTArray<T>::Storage->m || j<0 || j>=DTArray<T>::Storage->n || k<0 || k>=DTArray<T>::Storage->o)
            {DTErrorOutOfRange("DTArray<T>",i,j,k,DTArray<T>::Storage->m,DTArray<T>::Storage->n,DTArray<T>::Storage->o); return DTArray<T>::invalidEntry;}
            return DTArray<T>::Storage->Data[i+j*DTArray<T>::Storage->m+k*DTArray<T>::Storage->mn];}
    T &operator()(long int i,long int j,long int k)
        {if (i<0 || i>=DTArray<T>::Storage->m || j<0 || j>=DTArray<T>::Storage->n || k<0 || k>=DTArray<T>::Storage->o)
            {DTErrorOutOfRange("DTArray<T>",i,j,k,DTArray<T>::Storage->m,DTArray<T>::Storage->n,DTArray<T>::Storage->o); return DTArray<T>::invalidEntry;}
        return DTArray<T>::Storage->Data[i+j*DTArray<T>::Storage->m+k*DTArray<T>::Storage->mn];}
#else
    T operator()(long int i) const {return DTArray<T>::Storage->Data[i];}
    T &operator()(long int i) {return DTArray<T>::Storage->Data[i];}
    T operator()(long int i,long int j) const {return DTArray<T>::Storage->Data[i+j*DTArray<T>::Storage->m];}
    T &operator()(long int i,long int j) {return DTArray<T>::Storage->Data[i+j*DTArray<T>::Storage->m];}
    T operator()(long int i,long int j,long int k) const {return DTArray<T>::Storage->Data[i+j*DTArray<T>::Storage->m+k*DTArray<T>::Storage->mn];}
    T &operator()(long int i,long int j,long int k) {return DTArray<T>::Storage->Data[i+j*DTArray<T>::Storage->m+k*DTArray<T>::Storage->mn];}
#endif
};

#endif

// Part of DTSource. Copyright 2004-2006. David Adalsteinsson.  BSD License
// see http://www.visualdatatools.com/DTSource/license.html for more information.

#ifndef DTDoubleArray_Header
#define DTDoubleArray_Header

#include <iostream>
#include "DTLock.h"

// By default, range check is turned on.
#ifndef DTRangeCheck
#define DTRangeCheck 1
#endif

// This is a 1,2,3D array container.  Standard operators are overloaded, and the usage rule are:

// DTDoubleArray is a constant object.  You can not modify any of it's values.
// DTMutableDoubleArray can be modified, but is derived from DTDoubleArray so it can
//       be passed into any function that expects a DTDoubleArray.

// The convention is that any function that takes in a DTMutableDoubleArray can be expected to
// use that to modify values, otherwise the function will only read values and not modify them.

// Assignment treates an array object as a pointer.  That means that
//    A = B
// will cause A use the same underlying pointer as B.  If both are DTDoubleArray this doesn't matter
// since neither should be modified, but for mutable arrays, you need to be aware that changes to
// one array will affect the other.

// To take a true copy, you make that explicit with
//    A = B.Copy()
// this is consistent with the general philosophy of DTSource that any action that could cause
// big blocks of memory to be allocated or a large computation to be instantiated is made
// explicitly.  That means that automatic type conversions are avoided, and instead you make
// your intention explicit with a "conversion" call such as ConvertToDouble(float array).

// To allocate an array (DTMutableDoubleArray) use
//     DTMutableDoubleArray A(100), B(100,100), C(100,100,100);
// this will allocate a single vector of numbers, and subscript it using column-major (fortran)
// format.  This is opposite to the C convention, but is the way DataTank lays out memory and is
// compatible with existing code bases.  Use the Transpose(...) operator to change.
// This is done because C/C++ barely can be considered to have a multi-dimensional array structure.

// To access elements, use the () operator and not the [] (not overloaded).
//     A(3), B(3,3), C(3,3,3)
// you can access any array as a list of numbers B(3311), C(30000) etc.
// the value returned is determined from the layout of the pointer.  That is
//    A(i,j) = A(i + j*A.m())

// To get size information, use m(),n(),o() for each dimension and Length() for the total length.
// To get access to the native list, use the Pointer() member function.  This is needed when passing
// the content to other libraries or to avoid the cost of the index arithmetic and range checking
// (when active).


// Operators such as A*A, A+A etc are declared in DTDoubleArrayOperators.h
// This header file is included by DTSource.
// Block subscripting to allow A(3,4...60) etc is included by using the subregion commands below, and
// if you use that you need to include the DTDoubleArrayRegion.h header.  See the DTIndex.h header for more info.

class DTDoubleArrayStorage {
public:
    DTDoubleArrayStorage(long int mv,long int nv,long int ov);
    ~DTDoubleArrayStorage();

    DTLock accessLock;
    long int m,n,o,mn,length;
    int referenceCount;
    int mutableReferences;
    double *Data;
    
private:
    DTDoubleArrayStorage(const DTDoubleArrayStorage &);
    DTDoubleArrayStorage &operator=(const DTDoubleArrayStorage &);
};

class DTMutableDoubleArray;
class DTIndex;
class DTDoubleArrayRegion;

class DTDoubleArray {

public:
    DTDoubleArray() : Storage(new DTDoubleArrayStorage(0,0,0)), accessLock(), invalidEntry(0.0) {}
    virtual ~DTDoubleArray();
    DTDoubleArray(const DTDoubleArray &A);
    DTDoubleArray &operator=(const DTDoubleArray &A);

protected:
    // If you get a notice that this is protected, change DTDoubleArray to DTMutableDoubleArray
    explicit DTDoubleArray(long int mv,long int nv=1,long int ov=1) : Storage(new DTDoubleArrayStorage(mv,nv,ov)), accessLock(), invalidEntry(0.0) {}

public:
    DTMutableDoubleArray Copy() const;
    
    // Size information.
    long int m() const;
    long int n() const;
    long int o() const;
    long int Length() const;
    bool IsEmpty() const;
    bool NotEmpty() const;
    
    // Low level access
    int ReferenceCount() const;
    int MutableReferences() const; // How many mutable arrays have access to the pointer.
    const double *Pointer() const {return Storage->Data;}
    
    // Allow A(i) and A(i,j), but check each access.
#if DTRangeCheck
    double operator()(long int i) const
        {if (i<0 || i>=Storage->length)
            {PrintErrorMessage(i); return invalidEntry;}
         return Storage->Data[i];}
    double operator()(long int i,long int j) const
        {if (i<0 || i>=Storage->m || j<0 || j>=Storage->n)
            {PrintErrorMessage(i,j); return invalidEntry;}
         return Storage->Data[i+j*Storage->m];}
    double operator()(long int i,long int j,long int k) const
        {if (i<0 || i>=Storage->m || j<0 || j>=Storage->n || k<0 || k>=Storage->o)
            {PrintErrorMessage(i,j,k); return invalidEntry;}
            return Storage->Data[i+j*Storage->m+k*Storage->mn];}
#else
    // No range check.  Slightly faster, but not as safe.
    // For fastest access, extract the underlying pointer and dereference it directly.
    double operator()(long int i) const {return Storage->Data[i];}
    double operator()(long int i,long int j) const {return Storage->Data[i+j*Storage->m];}
    double operator()(long int i,long int j,long int k) const {return Storage->Data[i+j*Storage->m+k*Storage->mn];}
#endif

    // Debug functions, since gdb can't call the () operator.
    double e(int i) const;
    double e(int i,int j) const;
    double e(int i,int j,int k) const;
    void pinfo(void) const;
    void pi(int i) const; // (i,:)
    void pj(int j) const; // (:,j)
    void pall(void) const;  // Uses the same layout as DataTank in the variable monitor.
    void prange(int s,int e) const; // Offsets [s,e], both included.
    void pcrange(int s,int e) const; // Print (:,[s:e]), otherwise like pall().
 
    long int Find(double) const; // Returns -1 if not found.
    
    // Support for subregions
    const DTDoubleArrayRegion operator()(DTIndex) const;
    const DTDoubleArrayRegion operator()(DTIndex,DTIndex) const;
    const DTDoubleArrayRegion operator()(DTIndex,DTIndex,DTIndex) const;
    
protected:
    DTDoubleArrayStorage *Storage;
    DTLock accessLock;
    double invalidEntry;
    
    // Error messages for index access.
    void PrintErrorMessage(long int i) const;
    void PrintErrorMessage(long int i,long int j) const;
    void PrintErrorMessage(long int i,long int j,long int k) const;
};

class DTMutableDoubleArray : public DTDoubleArray
{
public:
    DTMutableDoubleArray() : DTDoubleArray() {Storage->mutableReferences = 1;}
    ~DTMutableDoubleArray();
    explicit DTMutableDoubleArray(long int mv,long int nv=1,long int ov=1) : DTDoubleArray(mv,nv,ov) {Storage->mutableReferences = 1;}
    DTMutableDoubleArray(const DTMutableDoubleArray &A);

    DTMutableDoubleArray &operator=(const DTMutableDoubleArray &A);

    // Assignment
    DTMutableDoubleArray &operator=(double a);

    // Raw access
    double *Pointer() {return Storage->Data;}
    const double *Pointer() const {return Storage->Data;}

    // High level access
#if DTRangeCheck
    double operator()(long int i) const
        {if (i<0 || i>=Storage->length)
            {PrintErrorMessage(i); return invalidEntry;}
            return Storage->Data[i];}
    double &operator()(long int i)
        {if (i<0 || i>=Storage->length)
            {PrintErrorMessage(i); return invalidEntry;}
        return Storage->Data[i];}
    double operator()(long int i,long int j) const
        {if (i<0 || i>=Storage->m || j<0 || j>=Storage->n)
            {PrintErrorMessage(i,j); return invalidEntry;}
            return Storage->Data[i+j*Storage->m];}
    double &operator()(long int i,long int j)
        {if (i<0 || i>=Storage->m || j<0 || j>=Storage->n)
            {PrintErrorMessage(i,j); return invalidEntry;}
        return Storage->Data[i+j*Storage->m];}
    double operator()(long int i,long int j,long int k) const
        {if (i<0 || i>=Storage->m || j<0 || j>=Storage->n || k<0 || k>=Storage->o)
            {PrintErrorMessage(i,j,k); return invalidEntry;}
            return Storage->Data[i+j*Storage->m+k*Storage->mn];}
    double &operator()(long int i,long int j,long int k)
        {if (i<0 || i>=Storage->m || j<0 || j>=Storage->n || k<0 || k>=Storage->o)
            {PrintErrorMessage(i,j,k); return invalidEntry;}
        return Storage->Data[i+j*Storage->m+k*Storage->mn];}
#else
    double operator()(long int i) const {return Storage->Data[i];}
    double &operator()(long int i) {return Storage->Data[i];}
    double operator()(long int i,long int j) const {return Storage->Data[i+j*Storage->m];}
    double &operator()(long int i,long int j) {return Storage->Data[i+j*Storage->m];}
    double operator()(long int i,long int j,long int k) const {return Storage->Data[i+j*Storage->m+k*Storage->mn];}
    double &operator()(long int i,long int j,long int k) {return Storage->Data[i+j*Storage->m+k*Storage->mn];}
#endif

    // Support for subregions
    const DTDoubleArrayRegion operator()(DTIndex) const;
    const DTDoubleArrayRegion operator()(DTIndex,DTIndex) const;
    const DTDoubleArrayRegion operator()(DTIndex,DTIndex,DTIndex) const;

    DTDoubleArrayRegion operator()(DTIndex);
    DTDoubleArrayRegion operator()(DTIndex,DTIndex);
    DTDoubleArrayRegion operator()(DTIndex,DTIndex,DTIndex);
};

bool operator==(const DTDoubleArray &A,const DTDoubleArray &B);
bool operator!=(const DTDoubleArray &A,const DTDoubleArray &B);

// Misc
extern DTMutableDoubleArray Transpose(const DTDoubleArray &A);
extern DTMutableDoubleArray Reshape(const DTDoubleArray &A,long int m,long int n=1,long int o=1);
extern DTMutableDoubleArray Sort(const DTDoubleArray &A);
extern DTMutableDoubleArray FlipJ(const DTDoubleArray &A);

extern double Minimum(const DTDoubleArray &);
extern double Maximum(const DTDoubleArray &);

extern DTMutableDoubleArray CombineColumns(const DTDoubleArray &First,const DTDoubleArray &Second);

// Changing the size of an array
extern DTMutableDoubleArray TruncateSize(const DTDoubleArray &A,long int length);
extern DTMutableDoubleArray IncreaseSize(const DTDoubleArray &A,long int addLength);

#endif

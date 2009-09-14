// Part of DTSource. Copyright 2004-2006. David Adalsteinsson.  BSD License
// see http://www.visualdatatools.com/DTSource/license.html for more information.

#include "DTDoubleArray.h"
#include "DTError.h"

#include "DTArrayTemplates.h"

#include <math.h>
#include <string.h>
#include <algorithm>
#include <limits>

DTDoubleArrayStorage::DTDoubleArrayStorage(long int mv,long int nv,long int ov)
{
    // Check if it's called correctly.
    m = mv>0 ? mv : 0;
    n = nv>0 ? nv : 0;
    o = ov>0 ? ov : 0;
    length = m*n*o;
    if (length==0) m = n = o = 0;
    referenceCount = 1;
    mn = m*n;
    mutableReferences = 0;
    
    Data = length==0 ? NULL : new double[length];
}

DTDoubleArrayStorage::~DTDoubleArrayStorage()
{
    delete Data;
}

DTDoubleArray::~DTDoubleArray()
{
    if (Storage) {
        accessLock.Lock();
        Storage->accessLock.Lock();
        int refCnt = (--Storage->referenceCount);
        Storage->accessLock.Unlock();
        if (refCnt==0) delete Storage;
        accessLock.Unlock();
    }
}

DTDoubleArray::DTDoubleArray(const DTDoubleArray &A) 
{
    accessLock.Lock();
    Storage = A.Storage;
    Storage->accessLock.Lock();
    Storage->referenceCount++;
    Storage->accessLock.Unlock();
    accessLock.Unlock();
}

DTDoubleArray &DTDoubleArray::operator=(const DTDoubleArray &A)
{
    if (accessLock==A.accessLock) {
        // A=A, safe but pointless.
        return *this;
    }
    
    // Allow A = A
    accessLock.Lock();
    A.accessLock.Lock();
    
    if (Storage!=A.Storage) {
        Storage->accessLock.Lock();
        A.Storage->accessLock.Lock();
        Storage->referenceCount--;
        int refCnt = Storage->referenceCount;
        Storage->accessLock.Unlock();
        if (refCnt==0) delete Storage;
        Storage = A.Storage;
        Storage->referenceCount++;
        Storage->accessLock.Unlock();
    }
    
    A.accessLock.Unlock();
    accessLock.Unlock();
    
    return *this;
}

int DTDoubleArray::ReferenceCount() const
{
    accessLock.Lock();
    Storage->accessLock.Lock(); 
    int refCnt = Storage->referenceCount;
    Storage->accessLock.Unlock();
    accessLock.Unlock();
    return refCnt;
}

int DTDoubleArray::MutableReferences() const
{
    accessLock.Lock();
    Storage->accessLock.Lock(); 
    int toReturn = Storage->mutableReferences;
    Storage->accessLock.Unlock();
    accessLock.Unlock();
    return toReturn;
}

long int DTDoubleArray::m() const
{
    return Storage->m;
}

long int DTDoubleArray::n() const
{
    return Storage->n;
}

long int DTDoubleArray::o() const
{
    return Storage->o;
}

long int DTDoubleArray::Length() const
{
    return Storage->length;
}

bool DTDoubleArray::IsEmpty() const
{
    return (Storage->length==0);
}

bool DTDoubleArray::NotEmpty() const
{
    return (Storage->length!=0);
}

double DTDoubleArray::e(int i) const
{
    if (i<0 || i>=Storage->length) {
        cerr << "Out of bounds\n";
        return invalidEntry;
    }
    else
        return Storage->Data[i];
}

double DTDoubleArray::e(int i,int j) const
{
    if (i<0 || i>=Storage->m || j<0 || j>=Storage->n) {
        cerr << "Out of bounds\n";
        return invalidEntry;
    }
    else
        return Storage->Data[i+j*Storage->m];
}

double DTDoubleArray::e(int i,int j,int k) const
{
    if (i<0 || i>=Storage->m || j<0 || j>=Storage->n || k<0 || k>=Storage->o) {
        cerr << "Out of bounds\n";
        return invalidEntry;
    }
    else
        return Storage->Data[i+j*Storage->m+k*Storage->mn];
}

void DTDoubleArray::pinfo(void) const
{
    if (o()==0)
        cerr << "Empty\n";
    else if (o()==1) {
        if (n()==1) {
            if (m()==1) {
                cerr << "double array with one entry\n";
            }
            else {
                cerr << "double vector with " << m() << " entries\n";
            }
        }
        else
            cerr << m() << " x " << n() << " double array\n";
    }
    else
        cerr << m() << " x " << n() << " x " << o() << " double array\n";
    
    cerr << flush;
}

void DTDoubleArray::pi(int i) const
{
    if (i<0 || i>=m()) {
        cerr << "Out of bounds.\n";
    }
    else {
        long int howMany = n();
        long int j;
        for (j=0;j<howMany-1;j++) cerr << operator()(i,j) << ", ";
        if (howMany>0) cerr << operator()(i,howMany-1);
        cerr << endl;
    }
}

void DTDoubleArray::pj(int j) const
{
    if (j<0 || j>=n()) {
        cerr << "Out of bounds.\n";
    }
    else {
        long int howMany = m();
        long int i;
        for (i=0;i<howMany-1;i++) cerr << operator()(i,j) << ", ";
        if (howMany>0) cerr << operator()(howMany-1,j);
        cerr << endl;
    }
}

void DTDoubleArray::pall(void) const
{
    long int mv = m();
    long int nv = n();
    long int i,j;
    if (mv==0) {
        cerr << "Empty\n";
    }
    else {
        for (j=0;j<nv;j++) {
            for (i=0;i<mv-1;i++) cerr << operator()(i,j) << ", ";
            cerr << operator()(mv-1,j);
            cerr << endl;
        }
    }
}

void DTDoubleArray::prange(int startIndex,int endIndex) const
{
    // Offsets [s,e], both included.
    long int i;
    if (startIndex<0) {
        cerr << "start out of bounds\n";
        return;
    }
    if (endIndex>=Length()) {
        cerr << "end out of bounds\n";
        return;
    }
    for (i=startIndex;i<endIndex;i++) {
        cerr << operator()(i) << ", ";
    }
    if (startIndex<=endIndex) {
        cerr << operator()(i) << endl;
    }
}

void DTDoubleArray::pcrange(int startIndex,int endIndex) const
{
    // Print (:,[s:e]), otherwise like pall().
    long int mv = m();
    long int nv = n();
    long int i,j;
    if (startIndex<0) {
        cerr << "start out of bounds\n";
        return;
    }
    if (endIndex>=nv) {
        cerr << "end out of bounds\n";
        return;
    }
    
    for (j=startIndex;j<=endIndex;j++) {
        for (i=0;i<mv-1;i++) cerr << operator()(i,j) << ", ";
        cerr << operator()(mv-1,j);
        cerr << endl;
    }
}

long int DTDoubleArray::Find(double v) const
{
    const double *D = Pointer();
    long int len = Length();
    long int i;
    for (i=0;i<len;i++) {
        if (D[i]==v) break;
    }

    return (i<len ? i : -1);
}

DTMutableDoubleArray DTDoubleArray::Copy() const
{
    DTMutableDoubleArray CopyInto(m(),n(),o());
    // Check that the allocation worked.
    if (CopyInto.Length()!=Length()) return CopyInto; // Failed.  Already printed an error message.
    memcpy(CopyInto.Pointer(),Pointer(),Length()*sizeof(double));
    return CopyInto;
}

void DTDoubleArray::PrintErrorMessage(long int i) const
{
    DTErrorOutOfRange("DTDoubleArray",i,Storage->length);
}

void DTDoubleArray::PrintErrorMessage(long int i,long int j) const
{
    DTErrorOutOfRange("DTDoubleArray",i,j,Storage->m,Storage->n);
}

void DTDoubleArray::PrintErrorMessage(long int i,long int j,long int k) const
{
    DTErrorOutOfRange("DTDoubleArray",i,j,k,Storage->m,Storage->n,Storage->o);
}

DTMutableDoubleArray::DTMutableDoubleArray(const DTMutableDoubleArray &A)
{
    accessLock.Lock();
    Storage = A.Storage;
    Storage->accessLock.Lock();
    Storage->referenceCount++;
    Storage->mutableReferences++;
    Storage->accessLock.Unlock();
    accessLock.Unlock();
}

DTMutableDoubleArray::~DTMutableDoubleArray()
{
    accessLock.Lock();
    Storage->accessLock.Lock();
    int refCnt = (--Storage->referenceCount);
    Storage->mutableReferences--;
    Storage->accessLock.Unlock();
    if (refCnt==0) delete Storage;
    Storage = NULL;
    accessLock.Unlock();
}

DTMutableDoubleArray &DTMutableDoubleArray::operator=(const DTMutableDoubleArray &A)
{
    if (accessLock==A.accessLock) {
        // A=A, safe but pointless.
        return *this;
    }
    
    // Allow A = A
    accessLock.Lock();
    A.accessLock.Lock();
    
    if (Storage!=A.Storage) {
        Storage->accessLock.Lock();
        A.Storage->accessLock.Lock();
        Storage->referenceCount--;
        int refCnt = Storage->referenceCount;
        Storage->mutableReferences--;
        Storage->accessLock.Unlock();
        if (refCnt==0) delete Storage;
        Storage = A.Storage;
        Storage->referenceCount++;
        Storage->mutableReferences++;
        Storage->accessLock.Unlock();
    }
    
    A.accessLock.Unlock();
    accessLock.Unlock();
    
    return *this;
}

DTMutableDoubleArray &DTMutableDoubleArray::operator=(double a)
{
    const long int howManyNumbers = Length();
    if (a==0.0) {
        memset(Pointer(),0,sizeof(double)*howManyNumbers);
    }
    else {
        long int i;
        double *Data = Pointer();
        for (i=0;i<howManyNumbers;i++)
            Data[i] = a;
    }
    
    return *this;
}

bool operator==(const DTDoubleArray &A,const DTDoubleArray &B)
{
    return DTOperatorArrayEqualsArray<DTDoubleArray,double>(A,B);
}

bool operator!=(const DTDoubleArray &A,const DTDoubleArray &B)
{
    return !(A==B);
}

DTMutableDoubleArray TruncateSize(const DTDoubleArray &A,long int length)
{
    return DTTruncateArraySize<DTDoubleArray,DTMutableDoubleArray,double>(A,length);
}

DTMutableDoubleArray IncreaseSize(const DTDoubleArray &A,long int addLength)
{
    return DTIncreaseArraySize<DTDoubleArray,DTMutableDoubleArray,double>(A,addLength);
}

DTMutableDoubleArray Transpose(const DTDoubleArray &A)
{
    return DTTransposeArray<DTDoubleArray,DTMutableDoubleArray,double>(A);
}

DTMutableDoubleArray Reshape(const DTDoubleArray &A,long int m,long int n,long int o)
{
    if (m<0 || n<0 || o<0) {
        DTErrorMessage("Reshape(DTDoubleArray,...)","One of the new dimensions is negative.");
        return DTMutableDoubleArray();
    }
    if (m*n*o!=A.Length()) {
        DTErrorMessage("Reshape(DTDoubleArray,...)","Size before and after need to be the same.");
        return DTMutableDoubleArray();
    }
    
    DTMutableDoubleArray toReturn(m,n,o);
    if (toReturn.Length()) {
        memcpy(toReturn.Pointer(),A.Pointer(),A.Length()*sizeof(double));
    }
    
    return toReturn;
}

DTMutableDoubleArray Sort(const DTDoubleArray &A)
{
    DTMutableDoubleArray toReturn = Reshape(A,A.Length());
    sort(toReturn.Pointer(),toReturn.Pointer()+toReturn.Length());
    return toReturn;
}

DTMutableDoubleArray FlipJ(const DTDoubleArray &A)
{
    return DTArrayFlipJ<DTDoubleArray,DTMutableDoubleArray,double>(A);
}

double Minimum(const DTDoubleArray &A)
{
    long int len = A.Length();
#if defined(WIN32) && !defined(INFINITY)
#define INFINITY std::numeric_limits<float>::infinity();
#endif
    double minV = INFINITY;
    
    double v;
    long int i;
    
    const double *D = A.Pointer();
    
    for (i=0;i<len;i++) {
        v = D[i];
        minV = (v < minV ? v : minV);
    }

    return minV;
}

double Maximum(const DTDoubleArray &A)
{
    long int len = A.Length();
#if defined(WIN32) && !defined(INFINITY)
#define INFINITY std::numeric_limits<float>::infinity();
#endif
    double maxV = -INFINITY;
    
    double v;
    long int i;
    
    const double *D = A.Pointer();
    
    for (i=0;i<len;i++) {
        v = D[i];
        maxV = (maxV < v ? v : maxV);
    }
    
    return maxV;
}

DTMutableDoubleArray CombineColumns(const DTDoubleArray &First,const DTDoubleArray &Second)
{
    if (First.m()!=Second.m()) {
        DTErrorMessage("CombineColumns(A,B)","A and B have to have the same number of rows.");
        return DTMutableDoubleArray();
    }
    if (First.IsEmpty())
        return DTMutableDoubleArray();
    if (First.o()!=1 || Second.o()!=1) {
        DTErrorMessage("CombineColumns(A,B)","A and B have to be two dimensional.");
        return DTMutableDoubleArray();
    }
    
    DTMutableDoubleArray toReturn(First.m(),First.n()+Second.n());
    memcpy(toReturn.Pointer(),First.Pointer(),First.Length()*sizeof(double));
    memcpy(toReturn.Pointer()+First.Length(),Second.Pointer(),Second.Length()*sizeof(double));
    
    return toReturn;
}


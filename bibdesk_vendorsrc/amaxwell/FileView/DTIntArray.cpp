// Part of DTSource. Copyright 2004-2006. David Adalsteinsson.  BSD License
// see http://www.visualdatatools.com/DTSource/license.html for more information.

#include "DTIntArray.h"
#include "DTError.h"
#include "DTArrayTemplates.h"

#include <string.h>
#include <algorithm>

DTIntArrayStorage::DTIntArrayStorage(long int mv,long int nv,long int ov)
{
    // Check if it's called correctly.
    m = mv>0 ? mv : 0;
    n = nv>0 ? nv : 0;
    o = ov>0 ? ov : 0;
    length = m*n*o;
    if (length==0) m = n = o = 0;
    referenceCount = 1;
    mn = m*n;

    Data = length==0 ? NULL : new int[length];
}

DTIntArrayStorage::~DTIntArrayStorage()
{
    delete Data;
}

DTIntArray &DTIntArray::operator=(const DTIntArray &A)
{
    // Allow A = A
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
    
    return *this;
}

DTMutableIntArray DTIntArray::Copy() const
{
    DTMutableIntArray CopyInto(m(),n(),o());
    // Check that the allocation worked.
    if (CopyInto.Length()!=Length()) return CopyInto; // Failed.  Already printed an error message.
    memcpy(CopyInto.Pointer(),Pointer(),Length()*sizeof(int));
    return CopyInto;
}

int DTIntArray::e(int i) const
{
    if (i<0 || i>=Storage->length) {
        cerr << "Out of bounds\n";
        return invalidEntry;
    }
    else
        return Storage->Data[i];
}

int DTIntArray::e(int i,int j) const
{
    if (i<0 || i>=Storage->m || j<0 || j>=Storage->n) {
        cerr << "Out of bounds\n";
        return invalidEntry;
    }
    else
        return Storage->Data[i+j*Storage->m];
}

int DTIntArray::e(int i,int j,int k) const
{
    if (i<0 || i>=Storage->m || j<0 || j>=Storage->n || k<0 || k>=Storage->o) {
        cerr << "Out of bounds\n";
        return invalidEntry;
    }
    else
        return Storage->Data[i+j*Storage->m+k*Storage->mn];
}

void DTIntArray::pinfo(void) const
{
    if (o()==0)
        cerr << "Empty\n";
    else if (o()==1) {
        if (n()==1)
            cerr << m() << " entries\n";
        else
            cerr << m() << " x " << n() << " array\n";
    }
    else
        cerr << m() << " x " << n() << " x " << o() << " array\n";
    cerr << flush;
}

void DTIntArray::pi(int i) const
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

void DTIntArray::pj(int j) const
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

void DTIntArray::pall(void) const
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

void DTIntArray::prange(int startIndex,int endIndex) const
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

void DTIntArray::pcrange(int startIndex,int endIndex) const
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

long int DTIntArray::Find(int v) const
{
    const int *D = Pointer();
    long int len = Length();
    long int i;
    for (i=0;i<len;i++) {
        if (D[i]==v) break;
    }
    
    return (i<len ? i : -1);
}

DTMutableIntArray TruncateSize(const DTIntArray &A,long int length)
{
    // New length needs to fit as a MxNxO array
    // where MNO = length and
    // if o>1, length = m*n*k
    // if o=1 and n>1 length = m*k
    // if o=1 and n=1 everything is ok.

    if (length==0) return DTMutableIntArray();
    if (A.IsEmpty()) {
        DTErrorMessage("TruncateSize(Array,Length)","Array is empty.");
        return DTMutableIntArray();
    }

    long int newM,newN,newO;
    if (A.o()>1) {
        if (length%(A.m()*A.n())!=0) {
            DTErrorMessage("TruncateSize(Array,Length)","Invalid new dimension");
            return DTMutableIntArray();
        }
        newM = A.m();
        newN = A.n();
        newO = length/(A.m()*A.n());
    }
    else if (A.n()>1) {
        if (length%(A.m())!=0) {
            DTErrorMessage("TruncateSize(Array,Length)","Invalid new dimension");
            return DTMutableIntArray();
        }
        newM = A.m();
        newN = length/A.m();
        newO = 1;
    }
    else {
        newM = length;
        newN = 1;
        newO = 1;
    }

    DTMutableIntArray toReturn(newM,newN,newO);
    memcpy(toReturn.Pointer(),A.Pointer(),length*sizeof(int));
    return toReturn;
}

DTMutableIntArray IncreaseSize(const DTIntArray &A,long int addLength)
{
    if (addLength<0) {
        DTErrorMessage("IncreaseSize(Array,Length)","Length needs to be >0.");
        return DTMutableIntArray();
    }

    long int newM,newN,newO;
    if (A.o()>1) {
        if (addLength%(A.m()*A.n())!=0) {
            DTErrorMessage("IncreaseSize(Array,Length)","Length needs to be a multiple of m*n");
            return DTMutableIntArray();
        }
        newM = A.m();
        newN = A.n();
        newO = A.o() + addLength/(A.m()*A.n());
    }
    else if (A.n()>1) {
        if (addLength%(A.m())!=0) {
            DTErrorMessage("IncreaseSize(Array,Length)","Length needs to be a multiple of m");
            return DTMutableIntArray();
        }
        newM = A.m();
        newN = A.n() + addLength/A.m();
        newO = 1;
    }
    else {
        newM = A.m() + addLength;
        newN = 1;
        newO = 1;
    }

    DTMutableIntArray toReturn(newM,newN,newO);
    memcpy(toReturn.Pointer(),A.Pointer(),A.Length()*sizeof(int));
    return toReturn;
}

void DTIntArray::PrintErrorMessage(long int i) const
{
    DTErrorOutOfRange("DTIntArray",i,Storage->length);
}

void DTIntArray::PrintErrorMessage(long int i,long int j) const
{
    DTErrorOutOfRange("DTIntArray",i,j,Storage->m,Storage->n);
}

void DTIntArray::PrintErrorMessage(long int i,long int j,long int k) const
{
    DTErrorOutOfRange("DTIntArray",i,j,k,Storage->m,Storage->n,Storage->o);
}

DTMutableIntArray &DTMutableIntArray::operator=(int a)
{
    const long int howManyNumbers = Length();
    long int i;
    int *Data = Pointer();
    for (i=0;i<howManyNumbers;i++)
        Data[i] = a;
    
    return *this;
}

bool operator==(const DTIntArray &A,const DTIntArray &B)
{
    return DTOperatorArrayEqualsArray<DTIntArray,int>(A,B);
}

bool operator!=(const DTIntArray &A,const DTIntArray &B)
{
    return !(A==B);
}

DTMutableIntArray Transpose(const DTIntArray &A)
{
    return DTTransposeArray<DTIntArray,DTMutableIntArray,int>(A);
}

DTMutableIntArray Reshape(const DTIntArray &A,long int m,long int n,long int o)
{
    if (m<0 || n<0 || o<0) {
        DTErrorMessage("Reshape(DTIntArray,...)","One of the new dimensions is negative.");
        return DTMutableIntArray();
    }
    if (m*n*o!=A.Length()) {
        DTErrorMessage("Reshape(DTIntArray,...)","Size before and after need to be the same.");
        return DTMutableIntArray();
    }

    DTMutableIntArray toReturn(m,n,o);
    if (toReturn.Length()) {
        memcpy(toReturn.Pointer(),A.Pointer(),A.Length()*sizeof(int));
    }

    return toReturn;
}

DTMutableIntArray Sort(const DTIntArray &A)
{
    DTMutableIntArray toReturn = Reshape(A,A.Length());;
    sort(toReturn.Pointer(),toReturn.Pointer()+toReturn.Length());
    return toReturn;
}

DTMutableIntArray FlipJ(const DTIntArray &A)
{
    return DTArrayFlipJ<DTIntArray,DTMutableIntArray,int>(A);
}

long int FindEntry(const DTIntArray &A,int val)
{
    long int Len = A.Length();
    long int i;
    for (i=0;i<Len;i++) {
        if (A(i)==val) break;
    }
    return (i==Len ? -1 : i);
}

long int FindEntryInSorted(const DTIntArray &A,int val)
{
    if (A.Length()==0 || A(0)>val || A(A.Length()-1)<val)
        return -1;
    
    long int StrictlyBefore = A.Length();
    long int AfterOrEqual = 0;
    long int LookAt;
    while (StrictlyBefore-AfterOrEqual>1) {
        LookAt = (AfterOrEqual+StrictlyBefore)/2;
        if (val<A(LookAt))
            StrictlyBefore = LookAt;
        else
            AfterOrEqual = LookAt;
    }
    
    if (A(AfterOrEqual)==val)
        return AfterOrEqual;
    else
        return -1;
}

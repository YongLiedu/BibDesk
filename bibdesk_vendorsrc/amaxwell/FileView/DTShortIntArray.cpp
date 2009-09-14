// Part of DTSource. Copyright 2004-2006. David Adalsteinsson.  BSD License
// see http://www.visualdatatools.com/DTSource/license.html for more information.

#include "DTShortIntArray.h"
#include "DTError.h"
#include "DTArrayTemplates.h"

#include <string.h>

DTShortIntArrayStorage::DTShortIntArrayStorage(long int mv,long int nv,long int ov)
{
    // Check if it's called correctly.
    m = mv>0 ? mv : 0;
    n = nv>0 ? nv : 0;
    o = ov>0 ? ov : 0;
    length = m*n*o;
    if (length==0) m = n = o = 0;
    referenceCount = 1;
    mn = m*n;

    Data = length==0 ? NULL : new short int[length];
}

DTShortIntArrayStorage::~DTShortIntArrayStorage()
{
    delete Data;
}

DTShortIntArray &DTShortIntArray::operator=(const DTShortIntArray &A)
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

DTMutableShortIntArray DTShortIntArray::Copy() const
{
    DTMutableShortIntArray CopyInto(m(),n(),o());
    // Check that the allocation worked.
    if (CopyInto.Length()!=Length()) return CopyInto; // Failed.  Already printed an error message.
    memcpy(CopyInto.Pointer(),Pointer(),Length()*sizeof(short int));
    return CopyInto;
}

short int DTShortIntArray::e(int i) const
{
    if (i<0 || i>=Storage->length) {
        cerr << "Out of bounds\n";
        return invalidEntry;
    }
    else
        return Storage->Data[i];
}

short int DTShortIntArray::e(int i,int j) const
{
    if (i<0 || i>=Storage->m || j<0 || j>=Storage->n) {
        cerr << "Out of bounds\n";
        return invalidEntry;
    }
    else
        return Storage->Data[i+j*Storage->m];
}

short int DTShortIntArray::e(int i,int j,int k) const
{
    if (i<0 || i>=Storage->m || j<0 || j>=Storage->n || k<0 || k>=Storage->o) {
        cerr << "Out of bounds\n";
        return invalidEntry;
    }
    else
        return Storage->Data[i+j*Storage->m+k*Storage->mn];
}

void DTShortIntArray::pinfo(void) const
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

void DTShortIntArray::pi(int i) const
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

void DTShortIntArray::pj(int j) const
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

void DTShortIntArray::pall(void) const
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

DTMutableShortIntArray TruncateSize(const DTShortIntArray &A,long int length)
{
    // New length needs to fit as a MxNxO array
    // where MNO = length and
    // if o>1, length = m*n*k
    // if o=1 and n>1 length = m*k
    // if o=1 and n=1 everything is ok.

    if (length==0) return DTMutableShortIntArray();
    if (A.IsEmpty()) {
        DTErrorMessage("TruncateSize(Array,Length)","Array is empty.");
        return DTMutableShortIntArray();
    }

    long int newM,newN,newO;
    if (A.o()>1) {
        if (length%(A.m()*A.n())!=0) {
            DTErrorMessage("TruncateSize(Array,Length)","Invalid new dimension");
            return DTMutableShortIntArray();
        }
        newM = A.m();
        newN = A.n();
        newO = length/(A.m()*A.n());
    }
    else if (A.n()>1) {
        if (length%(A.m())!=0) {
            DTErrorMessage("TruncateSize(Array,Length)","Invalid new dimension");
            return DTMutableShortIntArray();
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

    DTMutableShortIntArray toReturn(newM,newN,newO);
    memcpy(toReturn.Pointer(),A.Pointer(),length*sizeof(short int));
    return toReturn;
}

DTMutableShortIntArray IncreaseSize(const DTShortIntArray &A,long int addLength)
{
    if (addLength<0) {
        DTErrorMessage("IncreaseSize(Array,Length)","Length needs to be >0.");
        return DTMutableShortIntArray();
    }

    long int newM,newN,newO;
    if (A.o()>1) {
        if (addLength%(A.m()*A.n())!=0) {
            DTErrorMessage("IncreaseSize(Array,Length)","Length needs to be a multiple of m*n");
            return DTMutableShortIntArray();
        }
        newM = A.m();
        newN = A.n();
        newO = A.o() + addLength/(A.m()*A.n());
    }
    else if (A.n()>1) {
        if (addLength%(A.m())!=0) {
            DTErrorMessage("IncreaseSize(Array,Length)","Length needs to be a multiple of m");
            return DTMutableShortIntArray();
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

    DTMutableShortIntArray toReturn(newM,newN,newO);
    memcpy(toReturn.Pointer(),A.Pointer(),A.Length()*sizeof(short int));
    return toReturn;
}

void DTShortIntArray::PrintErrorMessage(long int i) const
{
    DTErrorOutOfRange("DTShortIntArray",i,Storage->length);
}

void DTShortIntArray::PrintErrorMessage(long int i,long int j) const
{
    DTErrorOutOfRange("DTShortIntArray",i,j,Storage->m,Storage->n);
}

void DTShortIntArray::PrintErrorMessage(long int i,long int j,long int k) const
{
    DTErrorOutOfRange("DTShortIntArray",i,j,k,Storage->m,Storage->n,Storage->o);
}

DTMutableShortIntArray &DTMutableShortIntArray::operator=(short int a)
{
    const long int howManyNumbers = Length();
    long int i;
    short int *Data = Pointer();
    for (i=0;i<howManyNumbers;i++)
        Data[i] = a;
    
    return *this;
}

bool operator==(const DTShortIntArray &A,const DTShortIntArray &B)
{
    return DTOperatorArrayEqualsArray<DTShortIntArray,short int>(A,B);
}

bool operator!=(const DTShortIntArray &A,const DTShortIntArray &B)
{
    return !(A==B);
}

DTMutableShortIntArray Transpose(const DTShortIntArray &A)
{
    return DTTransposeArray<DTShortIntArray,DTMutableShortIntArray,short int>(A);
}

DTMutableShortIntArray FlipJ(const DTShortIntArray &A)
{
    return DTArrayFlipJ<DTShortIntArray,DTMutableShortIntArray,short int>(A);
}



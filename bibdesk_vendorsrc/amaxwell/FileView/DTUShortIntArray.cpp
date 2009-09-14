// Part of DTSource. Copyright 2004-2006. David Adalsteinsson.  BSD License
// see http://www.visualdatatools.com/DTSource/license.html for more information.

#include "DTUShortIntArray.h"
#include "DTError.h"
#include "DTArrayTemplates.h"

#include <string.h>

DTUShortIntArrayStorage::DTUShortIntArrayStorage(long int mv,long int nv,long int ov)
{
    // Check if it's called correctly.
    m = mv>0 ? mv : 0;
    n = nv>0 ? nv : 0;
    o = ov>0 ? ov : 0;
    length = m*n*o;
    if (length==0) m = n = o = 0;
    referenceCount = 1;
    mn = m*n;

    Data = length==0 ? NULL : new unsigned short int[length];
}

DTUShortIntArrayStorage::~DTUShortIntArrayStorage()
{
    delete Data;
}

DTUShortIntArray &DTUShortIntArray::operator=(const DTUShortIntArray &A)
{
    // Allow A = A
    if (Storage==A.Storage) return *this;
    
    Storage->accessLock.Lock();
    A.Storage->accessLock.Lock();
    Storage->referenceCount--;
    int refCnt = Storage->referenceCount;
    Storage->accessLock.Unlock();
    if (refCnt==0) delete Storage;
    Storage = A.Storage;
    Storage->referenceCount++;
    Storage->accessLock.Unlock();
    
    return *this;
}

DTMutableUShortIntArray DTUShortIntArray::Copy() const
{
    DTMutableUShortIntArray CopyInto(m(),n(),o());
    // Check that the allocation worked.
    if (CopyInto.Length()!=Length()) return CopyInto; // Failed.  Already printed an error message.
    memcpy(CopyInto.Pointer(),Pointer(),Length()*sizeof(unsigned short int));
    return CopyInto;
}

unsigned short int DTUShortIntArray::e(int i) const
{
    if (i<0 || i>=Storage->length) {
        cerr << "Out of bounds\n";        
        return invalidEntry;
    }
    else
        return Storage->Data[i];
}

unsigned short int DTUShortIntArray::e(int i,int j) const
{
    if (i<0 || i>=Storage->m || j<0 || j>=Storage->n) {
        cerr << "Out of bounds\n";
        return invalidEntry;
    }
    else
        return Storage->Data[i+j*Storage->m];
}

unsigned short int DTUShortIntArray::e(int i,int j,int k) const
{
    if (i<0 || i>=Storage->m || j<0 || j>=Storage->n || k<0 || k>=Storage->o) {
        cerr << "Out of bounds\n";
        return invalidEntry;
    }
    else
        return Storage->Data[i+j*Storage->m+k*Storage->mn];
}

void DTUShortIntArray::pinfo(void) const
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

void DTUShortIntArray::pi(int i) const
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

void DTUShortIntArray::pj(int j) const
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

void DTUShortIntArray::pall(void) const
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

DTMutableUShortIntArray TruncateSize(const DTUShortIntArray &A,long int length)
{
    // New length needs to fit as a MxNxO array
    // where MNO = length and
    // if o>1, length = m*n*k
    // if o=1 and n>1 length = m*k
    // if o=1 and n=1 everything is ok.

    if (length==0) return DTMutableUShortIntArray();
    if (A.IsEmpty()) {
        DTErrorMessage("TruncateSize(Array,Length)","Array is empty.");
        return DTMutableUShortIntArray();
    }

    long int newM,newN,newO;
    if (A.o()>1) {
        if (length%(A.m()*A.n())!=0) {
            DTErrorMessage("TruncateSize(Array,Length)","Invalid new dimension");
            return DTMutableUShortIntArray();
        }
        newM = A.m();
        newN = A.n();
        newO = length/(A.m()*A.n());
    }
    else if (A.n()>1) {
        if (length%(A.m())!=0) {
            DTErrorMessage("TruncateSize(Array,Length)","Invalid new dimension");
            return DTMutableUShortIntArray();
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

    DTMutableUShortIntArray toReturn(newM,newN,newO);
    memcpy(toReturn.Pointer(),A.Pointer(),length*sizeof(unsigned short int));
    return toReturn;
}

DTMutableUShortIntArray IncreaseSize(const DTUShortIntArray &A,long int addLength)
{
    if (addLength<0) {
        DTErrorMessage("IncreaseSize(Array,Length)","Length needs to be >0.");
        return DTMutableUShortIntArray();
    }

    long int newM,newN,newO;
    if (A.o()>1) {
        if (addLength%(A.m()*A.n())!=0) {
            DTErrorMessage("IncreaseSize(Array,Length)","Length needs to be a multiple of m*n");
            return DTMutableUShortIntArray();
        }
        newM = A.m();
        newN = A.n();
        newO = A.o() + addLength/(A.m()*A.n());
    }
    else if (A.n()>1) {
        if (addLength%(A.m())!=0) {
            DTErrorMessage("IncreaseSize(Array,Length)","Length needs to be a multiple of m");
            return DTMutableUShortIntArray();
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

    DTMutableUShortIntArray toReturn(newM,newN,newO);
    memcpy(toReturn.Pointer(),A.Pointer(),A.Length()*sizeof(unsigned short int));
    return toReturn;
}

void DTUShortIntArray::PrintErrorMessage(long int i) const
{
    DTErrorOutOfRange("DTUShortIntArray",i,Storage->length);
}

void DTUShortIntArray::PrintErrorMessage(long int i,long int j) const
{
    DTErrorOutOfRange("DTUShortIntArray",i,j,Storage->m,Storage->n);
}

void DTUShortIntArray::PrintErrorMessage(long int i,long int j,long int k) const
{
    DTErrorOutOfRange("DTUShortIntArray",i,j,k,Storage->m,Storage->n,Storage->o);
}

DTMutableUShortIntArray &DTMutableUShortIntArray::operator=(unsigned short int a)
{
    const long int howManyNumbers = Length();
    long int i;
    unsigned short int *Data = Pointer();
    for (i=0;i<howManyNumbers;i++)
        Data[i] = a;
    
    return *this;
}

bool operator==(const DTUShortIntArray &A,const DTUShortIntArray &B)
{
    return DTOperatorArrayEqualsArray<DTUShortIntArray,unsigned short int>(A,B);
}

bool operator!=(const DTUShortIntArray &A,const DTUShortIntArray &B)
{
    return !(A==B);
}

DTMutableUShortIntArray Transpose(const DTUShortIntArray &A)
{
    return DTTransposeArray<DTUShortIntArray,DTMutableUShortIntArray,unsigned short int>(A);
}

DTMutableUShortIntArray FlipJ(const DTUShortIntArray &A)
{
    return DTArrayFlipJ<DTUShortIntArray,DTMutableUShortIntArray,unsigned short int>(A);
}


// Part of DTSource. Copyright 2004-2006. David Adalsteinsson.  BSD License
// see http://www.visualdatatools.com/DTSource/license.html for more information.

#include "DTCharArray.h"
#include "DTError.h"
#include "DTArrayTemplates.h"

#include <string.h>

DTCharArrayStorage::DTCharArrayStorage(long int mv,long int nv,long int ov)
: accessLock(), m(0), n(0), o(0), mn(0), length(0), referenceCount(1), Data(NULL) {
    // Check if it's called correctly.
    m = mv>0 ? mv : 0;
    n = nv>0 ? nv : 0;
    o = ov>0 ? ov : 0;
    length = m*n*o;
    if (length==0) m = n = o = 0;
    mn = m*n;

    Data = length==0 ? NULL : new char[length];
}

DTCharArrayStorage::~DTCharArrayStorage()
{
    delete Data;
}

DTCharArray &DTCharArray::operator=(const DTCharArray &A)
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

DTMutableCharArray DTCharArray::Copy() const
{
    DTMutableCharArray CopyInto(m(),n(),o());
    // Check that the allocation worked.
    if (CopyInto.Length()!=Length()) return CopyInto; // Failed.  Already printed an error message.
    memcpy(CopyInto.Pointer(),Pointer(),Length()*sizeof(char));
    return CopyInto;
}

char DTCharArray::e(int i) const
{
    if (i<0 || i>=Storage->length) {
        cerr << "Out of bounds\n";
        return invalidEntry;
    }
    else
        return Storage->Data[i];
}

char DTCharArray::e(int i,int j) const
{
    if (i<0 || i>=Storage->m || j<0 || j>=Storage->n) {
        cerr << "Out of bounds\n";
        return invalidEntry;
    }
    else
        return Storage->Data[i+j*Storage->m];
}

char DTCharArray::e(int i,int j,int k) const
{
    if (i<0 || i>=Storage->m || j<0 || j>=Storage->n || k<0 || k>=Storage->o) {
        cerr << "Out of bounds\n";
        return invalidEntry;
    }
    else
        return Storage->Data[i+j*Storage->m+k*Storage->mn];
}

void DTCharArray::pinfo(void) const
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

void DTCharArray::pi(int i) const
{
    if (i<0 || i>=m()) {
        cerr << "Out of bounds.\n";
    }
    else {
        int howMany = n();
        int j;
        for (j=0;j<howMany-1;j++) cerr << (int)operator()(i,j) << ", ";
        if (howMany>0) cerr << (int)operator()(i,howMany-1);
        cerr << endl;
    }
}

void DTCharArray::pj(int j) const
{
    if (j<0 || j>=n()) {
        cerr << "Out of bounds.\n";
    }
    else {
        int howMany = m();
        int i;
        for (i=0;i<howMany-1;i++) cerr << (int)operator()(i,j) << ", ";
        if (howMany>0) cerr << (int)operator()(howMany-1,j);
        cerr << endl;
    }
}

void DTCharArray::pall(void) const
{
    long int mv = m();
    long int nv = n();
    long int i,j;
    if (mv==0) {
        cerr << "Empty\n";
    }
    else {
        for (j=0;j<nv;j++) {
            for (i=0;i<mv-1;i++) cerr << (int)operator()(i,j) << ", ";
            cerr << (int)operator()(mv-1,j);
            cerr << endl;
        }
    }
}

DTMutableCharArray TruncateSize(const DTCharArray &A,long int length)
{
    // New length needs to fit as a MxNxO array
    // where MNO = length and
    // if o>1, length = m*n*k
    // if o=1 and n>1 length = m*k
    // if o=1 and n=1 everything is ok.

    if (length==0) return DTMutableCharArray();
    if (A.IsEmpty()) {
        DTErrorMessage("TruncateSize(Array,Length)","Array is empty.");
        return DTMutableCharArray();
    }

    long int newM,newN,newO;
    if (A.o()>1) {
        if (length%(A.m()*A.n())!=0) {
            DTErrorMessage("TruncateSize(Array,Length)","Invalid new dimension");
            return DTMutableCharArray();
        }
        newM = A.m();
        newN = A.n();
        newO = length/(A.m()*A.n());
    }
    else if (A.n()>1) {
        if (length%(A.m())!=0) {
            DTErrorMessage("TruncateSize(Array,Length)","Invalid new dimension");
            return DTMutableCharArray();
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

    DTMutableCharArray toReturn(newM,newN,newO);
    memcpy(toReturn.Pointer(),A.Pointer(),length*sizeof(char));
    return toReturn;
}

DTMutableCharArray IncreaseSize(const DTCharArray &A,long int addLength)
{
    if (addLength<0) {
        DTErrorMessage("IncreaseSize(Array,Length)","Length needs to be >0.");
        return DTMutableCharArray();
    }

    long int newM,newN,newO;
    if (A.o()>1) {
        if (addLength%(A.m()*A.n())!=0) {
            DTErrorMessage("IncreaseSize(Array,Length)","Length needs to be a multiple of m*n");
            return DTMutableCharArray();
        }
        newM = A.m();
        newN = A.n();
        newO = A.o() + addLength/(A.m()*A.n());
    }
    else if (A.n()>1) {
        if (addLength%(A.m())!=0) {
            DTErrorMessage("IncreaseSize(Array,Length)","Length needs to be a multiple of m");
            return DTMutableCharArray();
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

    DTMutableCharArray toReturn(newM,newN,newO);
    memcpy(toReturn.Pointer(),A.Pointer(),A.Length()*sizeof(char));
    return toReturn;
}

void DTCharArray::PrintErrorMessage(long int i) const
{
    DTErrorOutOfRange("DTCharArray",i,Storage->length);
}

void DTCharArray::PrintErrorMessage(long int i,long int j) const
{
    DTErrorOutOfRange("DTCharArray",i,j,Storage->m,Storage->n);
}

void DTCharArray::PrintErrorMessage(long int i,long int j,long int k) const
{
    DTErrorOutOfRange("DTCharArray",i,j,k,Storage->m,Storage->n,Storage->o);
}

DTMutableCharArray &DTMutableCharArray::operator=(char a)
{
    const long int howManyNumbers = Length();
    long int i;
    char *Data = Pointer();
    for (i=0;i<howManyNumbers;i++)
        Data[i] = a;
    
    return *this;
}

bool operator==(const DTCharArray &A,const DTCharArray &B)
{
    return DTOperatorArrayEqualsArray<DTCharArray,char>(A,B);
}

bool operator!=(const DTCharArray &A,const DTCharArray &B)
{
    return !(A==B);
}

DTMutableCharArray Transpose(const DTCharArray &A)
{
    return DTTransposeArray<DTCharArray,DTMutableCharArray,char>(A);
}

DTMutableCharArray FlipJ(const DTCharArray &A)
{
    return DTArrayFlipJ<DTCharArray,DTMutableCharArray,char>(A);
}


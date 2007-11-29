// Part of DTSource. Copyright 2004-2006. David Adalsteinsson.  BSD License
// see http://www.visualdatatools.com/DTSource/license.html for more information.

#include "DTFloatArray.h"
#include "DTError.h"
#include "DTArrayTemplates.h"

#include <string.h>
#include <algorithm>

DTFloatArrayStorage::DTFloatArrayStorage(long int mv,long int nv,long int ov)
{
    // Check if it's called correctly.
    m = mv>0 ? mv : 0;
    n = nv>0 ? nv : 0;
    o = ov>0 ? ov : 0;
    length = m*n*o;
    if (length==0) m = n = o = 0;
    referenceCount = 1;
    mn = m*n;

    Data = length==0 ? NULL : new float[length];
}

DTFloatArrayStorage::~DTFloatArrayStorage()
{
    delete Data;
}

DTFloatArray &DTFloatArray::operator=(const DTFloatArray &A)
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

DTMutableFloatArray DTFloatArray::Copy() const
{
    DTMutableFloatArray CopyInto(m(),n(),o());
    // Check that the allocation worked.
    if (CopyInto.Length()!=Length()) return CopyInto; // Failed.  Already printed an error message.
    memcpy(CopyInto.Pointer(),Pointer(),Length()*sizeof(float));
    return CopyInto;
}

float DTFloatArray::e(int i) const
{
    if (i<0 || i>=Storage->length) {
        cerr << "Out of bounds\n";
        return invalidEntry;
    }
    else
        return Storage->Data[i];
}

float DTFloatArray::e(int i,int j) const
{
    if (i<0 || i>=Storage->m || j<0 || j>=Storage->n) {
        cerr << "Out of bounds\n";
        return invalidEntry;
    }
    else
        return Storage->Data[i+j*Storage->m];
}

float DTFloatArray::e(int i,int j,int k) const
{
    if (i<0 || i>=Storage->m || j<0 || j>=Storage->n || k<0 || k>=Storage->o) {
        cerr << "Out of bounds\n";
        return invalidEntry;
    }
    else
        return Storage->Data[i+j*Storage->m+k*Storage->mn];
}

void DTFloatArray::pinfo(void) const
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

void DTFloatArray::pi(int i) const
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

void DTFloatArray::pj(int j) const
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

void DTFloatArray::pall(void) const
{
    long int mv = m();
    long int nv = n();
    long int ov = o();
    if (mv*nv*ov>1000) {
        cerr << "More than 1000 numbers, save it to a file instead.\n";
    }
    else if (mv==0) {
        cerr << "Empty\n";
    }
    else {
        long int i,j,k;
        if (ov==1) {
            for (j=0;j<nv;j++) {
                for (i=0;i<mv-1;i++) cerr << operator()(i,j) << ", ";
                cerr << operator()(mv-1,j);
                cerr << endl;
            }
        }
        else {
            for (k=0;k<ov;k++) {
                cerr << "k = " << k << ":\n";
                for (j=0;j<nv;j++) {
                    cerr << "  ";
                    for (i=0;i<mv-1;i++) cerr << operator()(i,j,k) << ", ";
                    cerr << operator()(mv-1,j,k);
                    cerr << endl;
                }
            }
        }
    }
}

long int DTFloatArray::Find(float v) const
{
    const float *D = Pointer();
    long int len = Length();
    long int i;
    for (i=0;i<len;i++) {
        if (D[i]==v) break;
    }
    
    return (i<len ? i : -1);
}

DTMutableFloatArray TruncateSize(const DTFloatArray &A,long int length)
{
    // New length needs to fit as a MxNxO array
    // where MNO = length and
    // if o>1, length = m*n*k
    // if o=1 and n>1 length = m*k
    // if o=1 and n=1 everything is ok.

    if (length==0) return DTMutableFloatArray();
    if (A.IsEmpty()) {
        DTErrorMessage("TruncateSize(Array,Length)","Array is empty.");
        return DTMutableFloatArray();
    }

    long int newM,newN,newO;
    if (A.o()>1) {
        if (length%(A.m()*A.n())!=0) {
            DTErrorMessage("TruncateSize(Array,Length)","Invalid new dimension");
            return DTMutableFloatArray();
        }
        newM = A.m();
        newN = A.n();
        newO = length/(A.m()*A.n());
    }
    else if (A.n()>1) {
        if (length%(A.m())!=0) {
            DTErrorMessage("TruncateSize(Array,Length)","Invalid new dimension");
            return DTMutableFloatArray();
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

    DTMutableFloatArray toReturn(newM,newN,newO);
    memcpy(toReturn.Pointer(),A.Pointer(),length*sizeof(float));
    return toReturn;
}

DTMutableFloatArray IncreaseSize(const DTFloatArray &A,long int addLength)
{
    if (addLength<0) {
        DTErrorMessage("IncreaseSize(Array,Length)","Length needs to be >0.");
        return DTMutableFloatArray();
    }

    long int newM,newN,newO;
    if (A.o()>1) {
        if (addLength%(A.m()*A.n())!=0) {
            DTErrorMessage("IncreaseSize(Array,Length)","Length needs to be a multiple of m*n");
            return DTMutableFloatArray();
        }
        newM = A.m();
        newN = A.n();
        newO = A.o() + addLength/(A.m()*A.n());
    }
    else if (A.n()>1) {
        if (addLength%(A.m())!=0) {
            DTErrorMessage("IncreaseSize(Array,Length)","Length needs to be a multiple of m");
            return DTMutableFloatArray();
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

    DTMutableFloatArray toReturn(newM,newN,newO);
    memcpy(toReturn.Pointer(),A.Pointer(),A.Length()*sizeof(float));
    return toReturn;
}

void DTFloatArray::PrintErrorMessage(long int i) const
{
    DTErrorOutOfRange("DTFloatArray",i,Storage->length);
}

void DTFloatArray::PrintErrorMessage(long int i,long int j) const
{
    DTErrorOutOfRange("DTFloatArray",i,j,Storage->m,Storage->n);
}

void DTFloatArray::PrintErrorMessage(long int i,long int j,long int k) const
{
    DTErrorOutOfRange("DTFloatArray",i,j,k,Storage->m,Storage->n,Storage->o);
}

DTMutableFloatArray &DTMutableFloatArray::operator=(float a)
{
    const long int howManyNumbers = Length();
    long int i;
    float *Data = Pointer();
    for (i=0;i<howManyNumbers;i++)
        Data[i] = a;
    
    return *this;
}

bool operator==(const DTFloatArray &A,const DTFloatArray &B)
{
    return DTOperatorArrayEqualsArray<DTFloatArray,float>(A,B);
}

bool operator!=(const DTFloatArray &A,const DTFloatArray &B)
{
    return !(A==B);
}

DTMutableFloatArray Transpose(const DTFloatArray &A)
{
    if (A.IsEmpty()) return DTMutableFloatArray();

    const long int m = A.m();
    const long int n = A.n();
    const long int o = A.o();
    long int i,j,k;

    DTMutableFloatArray toReturn;
    float *toReturnD;
    const float *AD = A.Pointer();

    if (A.o()!=1) {
        toReturn = DTMutableFloatArray(o,n,m);
        toReturnD = toReturn.Pointer();
        long int ijkNew,ijkOld;
        long int no = n*o;
        for (k=0;k<o;k++) {
            for (j=0;j<n;j++) {
                ijkNew = k + j*o;
                ijkOld = j*m + k*m*n;
                for (i=0;i<m;i++) {
                    toReturnD[ijkNew] = AD[ijkOld]; // toReturn(k,j,i) = A(i,j,k)
                    ijkNew += no;
                    ijkOld++;
                }
            }
        }
    }
    else {
        toReturn = DTMutableFloatArray(n,m);
        toReturnD = toReturn.Pointer();
        long int ijNew, ijOld;
        if (m==1 || n==1) {
            memcpy(toReturn.Pointer(),A.Pointer(),m*n*sizeof(float));
        }
        else {
            for (j=0;j<n;j++) {
                ijNew = j;
                ijOld = j*m;
                for (i=0;i<m;i++) {
                    toReturnD[ijNew] = AD[ijOld]; // toReturn(j,i) = A(i,j)
                    ijNew += n;
                    ijOld++;
                }
            }
        }
    }

    return toReturn;
}

DTMutableFloatArray Reshape(const DTFloatArray &A,long int m,long int n,long int o)
{
    if (m<0 || n<0 || o<0) {
        DTErrorMessage("Reshape(DTFloatArray,...)","One of the new dimensions is negative.");
        return DTMutableFloatArray();
    }
    if (m*n*o!=A.Length()) {
        DTErrorMessage("Reshape(DTFloatArray,...)","Size before and after need to be the same.");
        return DTMutableFloatArray();
    }

    DTMutableFloatArray toReturn(m,n,o);
    if (toReturn.Length()) {
        memcpy(toReturn.Pointer(),A.Pointer(),A.Length()*sizeof(float));
    }

    return toReturn;
}

DTMutableFloatArray Sort(const DTFloatArray &A)
{
    DTMutableFloatArray toReturn = Reshape(A,A.Length());;
    sort(toReturn.Pointer(),toReturn.Pointer()+toReturn.Length());
    return toReturn;
}

DTMutableFloatArray FlipJ(const DTFloatArray &A)
{
    return DTArrayFlipJ<DTFloatArray,DTMutableFloatArray,float>(A);
}

DTMutableFloatArray CombineColumns(const DTFloatArray &First,const DTFloatArray &Second)
{
    return CombineColumns(First,Second,Second.n());
}

DTMutableFloatArray CombineColumns(const DTFloatArray &First,const DTFloatArray &Second,long int fromSecond)
{
    if (First.m()!=Second.m()) {
        DTErrorMessage("CombineColumns(A,B)","A and B have to have the same number of rows.");
        return DTMutableFloatArray();
    }
    if (First.IsEmpty())
        return DTMutableFloatArray();
    if (First.o()!=1 || Second.o()!=1) {
        DTErrorMessage("CombineColumns(A,B)","A and B have to be two dimensional.");
        return DTMutableFloatArray();
    }
    if (fromSecond>Second.n()) {
        DTErrorMessage("CombineColumns(A,B,fromSecond)","Too many columns specified.");
        return DTMutableFloatArray();
    }
    
    DTMutableFloatArray toReturn(First.m(),First.n()+fromSecond);
    memcpy(toReturn.Pointer(),First.Pointer(),First.Length()*sizeof(float));
    memcpy(toReturn.Pointer()+First.Length(),Second.Pointer(),Second.m()*fromSecond*sizeof(float));
    
    return toReturn;
}

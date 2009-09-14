// Part of DTSource. Copyright 2004-2006. David Adalsteinsson.  BSD License
// see http://www.visualdatatools.com/DTSource/license.html for more information.

// Template functions to implement array operators.

#include "DTError.h"

template <class T,class TM,class Td>
TM DTAddArrays(const char *name,const T &A,const T &B)
{
    if (A.m()!=B.m() || A.n()!=B.n() || A.o()!=B.o()) {
        DTErrorMessage(name,"Incompatible sizes.");
        return TM();
    }

    TM toReturn(A.m(),A.n(),A.o());
    int len = A.Length();
    const Td *AP = A.Pointer();
    const Td *BP = B.Pointer();
    Td *retP = toReturn.Pointer();
    int i;
    for (i=0;i<len;i++)
        retP[i] = AP[i]+BP[i];

    return toReturn;
}

template <class T,class TM,class Td>
TM DTSubtractArrays(const char *name,const T &A,const T &B)
{
    if (A.m()!=B.m() || A.n()!=B.n() || A.o()!=B.o()) {
        DTErrorMessage(name,"Incompatible sizes.");
        return TM();
    }
    
    TM toReturn(A.m(),A.n(),A.o());
    int len = A.Length();
    const Td *AP = A.Pointer();
    const Td *BP = B.Pointer();
    Td *retP = toReturn.Pointer();
    int i;
    for (i=0;i<len;i++)
        retP[i] = AP[i]-BP[i];

    return toReturn;
}

template <class T,class TM,class Td>
TM DTMultiplyArrays(const char *name,const T &A,const T &B)
{
    if (A.m()!=B.m() || A.n()!=B.n() || A.o()!=B.o()) {
        DTErrorMessage(name,"Incompatible sizes.");
        return TM();
    }

    TM toReturn(A.m(),A.n(),A.o());
    int len = A.Length();
    const Td *AP = A.Pointer();
    const Td *BP = B.Pointer();
    Td *retP = toReturn.Pointer();
    int i;
    for (i=0;i<len;i++)
        retP[i] = AP[i]*BP[i];

    return toReturn;
}

template <class T,class TM,class Td>
TM DTDivideArrays(const char *name,const T &A,const T &B)
{
    if (A.m()!=B.m() || A.n()!=B.n() || A.o()!=B.o()) {
        DTErrorMessage(name,"Incompatible sizes.");
        return TM();
    }

    TM toReturn(A.m(),A.n(),A.o());
    int len = A.Length();
    const Td *AP = A.Pointer();
    const Td *BP = B.Pointer();
    Td *retP = toReturn.Pointer();
    int i;
    for (i=0;i<len;i++)
        retP[i] = AP[i]/BP[i];

    return toReturn;
}

template <class T,class TM,class Td>
TM DTArrayPlusNumber(const T &A,Td b)
{
    TM toReturn(A.m(),A.n(),A.o());
    int i,len = A.Length();
    const Td *AP = A.Pointer();
    Td *retP = toReturn.Pointer();
    for (i=0;i<len;i++) retP[i] = AP[i]+b;
    return toReturn;
}

template <class T,class TM,class Td>
TM DTArrayTimesNumber(const T &A,Td b)
{
    TM toReturn(A.m(),A.n(),A.o());
    int i,len = A.Length();
    const Td *AP = A.Pointer();
    Td *retP = toReturn.Pointer();
    for (i=0;i<len;i++) retP[i] = AP[i]*b;
    return toReturn;
}

template <class T,class TM,class Td>
TM DTArrayDivideByNumber(const T &A,Td b)
{
    TM toReturn(A.m(),A.n(),A.o());
    int i,len = A.Length();
    const Td *AP = A.Pointer();
    Td *retP = toReturn.Pointer();
    for (i=0;i<len;i++) retP[i] = AP[i]/b;
    return toReturn;
}

template <class T,class TM,class Td>
TM DTNumberMinusArray(Td a,const T &B)
{
    TM toReturn(B.m(),B.n(),B.o());
    int i,len = B.Length();
    const Td *BP = B.Pointer();
    Td *retP = toReturn.Pointer();
    for (i=0;i<len;i++) retP[i] = a-BP[i];
    return toReturn;
}

template <class T,class TM,class Td>
TM DTNumberDividedByArray(Td a,const T &B)
{
    TM toReturn(B.m(),B.n(),B.o());
    int i,len = B.Length();
    const Td *BP = B.Pointer();
    Td *retP = toReturn.Pointer();
    for (i=0;i<len;i++) retP[i] = a/BP[i];
    return toReturn;
}

template <class T,class TM,class Td>
TM DTNegateArray(const T &A)
{
    TM toReturn(A.m(),A.n(),A.o());
    int i,len = A.Length();
    const Td *AP = A.Pointer();
    Td *retP = toReturn.Pointer();
    for (i=0;i<len;i++) retP[i] = -AP[i];
    return toReturn;
}

template <class T,class TM,class Td>
void DTPlusEqualsArray(TM &A,const T &B)
{
    if (A.m()!=B.m() || A.n()!=B.n() || A.o()!=B.o()) {
        DTErrorMessage("A+=B","Incompatible sizes.");
        return;
    }
    int i,len = A.Length();
    Td *AP = A.Pointer();
    const Td *BP = B.Pointer();
    for (i=0;i<len;i++) AP[i] += BP[i];
}

template <class T,class TM,class Td>
void DTMinusEqualsArray(TM &A,const T &B)
{
    if (A.m()!=B.m() || A.n()!=B.n() || A.o()!=B.o()) {
        DTErrorMessage("A-=B","Incompatible sizes.");
        return;
    }
    int i,len = A.Length();
    Td *AP = A.Pointer();
    const Td *BP = B.Pointer();
    for (i=0;i<len;i++) AP[i] -= BP[i];
}

template <class T,class TM,class Td>
void DTTimesEqualsArray(TM &A,const T &B)
{
    if (A.m()!=B.m() || A.n()!=B.n() || A.o()!=B.o()) {
        DTErrorMessage("A*=B","Incompatible sizes.");
        return;
    }
    int i,len = A.Length();
    Td *AP = A.Pointer();
    const Td *BP = B.Pointer();
    for (i=0;i<len;i++) AP[i] *= BP[i];
}

template <class T,class TM,class Td>
void DTDivideEqualsArray(TM &A,const T &B)
{
    if (A.m()!=B.m() || A.n()!=B.n() || A.o()!=B.o()) {
        DTErrorMessage("A/=B","Incompatible sizes.");
        return;
    }
    int i,len = A.Length();
    Td *AP = A.Pointer();
    const Td *BP = B.Pointer();
    for (i=0;i<len;i++) AP[i] /= BP[i];
}

template <class TM,class Td>
void DTPlusEqualsScalar(TM &A,Td b)
{
    int i,len = A.Length();
    Td *AP = A.Pointer();
    for (i=0;i<len;i++) AP[i] += b;
}

template <class TM,class Td>
void DTMinusEqualsScalar(TM &A,Td b)
{
    int i,len = A.Length();
    Td *AP = A.Pointer();
    for (i=0;i<len;i++) AP[i] -= b;
}

template <class TM,class Td>
void DTTimesEqualsScalar(TM &A,Td b)
{
    int i,len = A.Length();
    Td *AP = A.Pointer();
    for (i=0;i<len;i++) AP[i] *= b;
}

template <class TM,class Td>
void DTDivideEqualsScalar(TM &A,Td b)
{
    int i,len = A.Length();
    Td *AP = A.Pointer();
    for (i=0;i<len;i++) AP[i] /= b;
}

template <class T,class TM,class Td>
TM DTTruncateArraySize(const T &A,int length)
{
    // New length needs to fit as a MxNxO array
    // where MNO = length and
    // if o>1, length = m*n*k
    // if o=1 and n>1 length = m*k
    // if o=1 and n=1 everything is ok.

    if (length==0) return TM();
    if (A.IsEmpty()) {
        DTErrorMessage("TruncateSize(Array,Length)","Array is empty.");
        return TM();
    }

    int newM,newN,newO;
    if (A.o()>1) {
        if (length%(A.m()*A.n())!=0) {
            DTErrorMessage("TruncateSize(Array,Length)","Invalid new dimension");
            return TM();
        }
        newM = A.m();
        newN = A.n();
        newO = length/(A.m()*A.n());
    }
    else if (A.n()>1) {
        if (length%(A.m())!=0) {
            DTErrorMessage("TruncateSize(Array,Length)","Invalid new dimension");
            return TM();
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

    TM toReturn(newM,newN,newO);
    memcpy(toReturn.Pointer(),A.Pointer(),length*sizeof(Td));
    return toReturn;
}

template <class T,class TM,class Td>
TM DTIncreaseArraySize(const T &A,int addLength)
{
    if (addLength<0) {
        DTErrorMessage("IncreaseSize(Array,Length)","Length needs to be >0.");
        return TM();
    }

    int newM,newN,newO;
    if (A.o()>1) {
        if (addLength%(A.m()*A.n())!=0) {
            DTErrorMessage("IncreaseSize(Array,Length)","Length needs to be a multiple of m*n");
            return TM();
        }
        newM = A.m();
        newN = A.n();
        newO = A.o() + addLength/(A.m()*A.n());
    }
    else if (A.n()>1) {
        if (addLength%(A.m())!=0) {
            DTErrorMessage("IncreaseSize(Array,Length)","Length needs to be a multiple of m");
            return TM();
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

    TM toReturn(newM,newN,newO);
    memcpy(toReturn.Pointer(),A.Pointer(),A.Length()*sizeof(Td));
    return toReturn;
}

template <class T,class td>
bool DTOperatorArrayEqualsArray(const T &A,const T &B)
{
    if (A.m()!=B.m() || A.n()!=B.n() || A.o()!=B.o())
        return false;
    if (A.Pointer()==B.Pointer())
        return true;
    
    int len = A.Length();
    const td *AP = A.Pointer();
    const td *BP = B.Pointer();
    
    return (memcmp(AP,BP,len*sizeof(td))==0);
}

template <class T,class TM,class Td>
TM DTTransposeArray(const T &A)
{
    if (A.IsEmpty()) return TM();

    const int m = A.m();
    const int n = A.n();
    const int o = A.o();
    int i,j,k;

    TM toReturn;
    Td *toReturnD;
    const Td *AD = A.Pointer();

    if (A.o()!=1) {
        toReturn = TM(o,n,m);
        toReturnD = toReturn.Pointer();
        int ijkNew,ijkOld;
        int no = n*o;
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
        toReturn = TM(n,m);
        toReturnD = toReturn.Pointer();
        int ijNew, ijOld;
        if (m==1 || n==1) {
            memcpy(toReturn.Pointer(),A.Pointer(),m*n*sizeof(Td));
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

template <class T,class TM,class Td>
TM DTArrayFlipJ(const T &A)
{
    TM toReturn(A.m(),A.n(),A.o());
    
    int m = A.m();
    int n = A.n();
    int o = A.o();
    int mn = m*n;
    
    const Td *fromP = A.Pointer();
    Td *toP = toReturn.Pointer();
    
    int j,k;
    for (k=0;k<o;k++) {
        for (j=0;j<n;j++) {
            memcpy(toP+j*m+k*mn,fromP+(n-1-j)*m+k*mn,m*sizeof(Td));
        }
    }
    
    return toReturn;
}


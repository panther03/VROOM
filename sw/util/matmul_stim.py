import numpy as np

Nbits = 1
N = 1 << Nbits

A = np.random.randint(0,(1<<32)-1, size=(N,N))
B = np.random.randint(0,(1<<32)-1, size=(N,N))

for i in range(N):
    for j in range(N):
        A[i][j] = i
        B[i][j] = i + j
        
Expected = np.matmul(A,B)

def printMat(M):
    s = "{\n"

    for i in range(N):
        for j in range(N):
            if (i * N + j) != N*N-1:
                s += f"    [{i*N+j}] = {M[i][j]},\n"
            else:
                s += f"    [{i*N+j}] = {M[i][j]}\n"
    s += "}"
    return s

template = f"""
#INCLUDE "<inc>/Util.hjk"

#MACRO INDEX2 ( M, i, j ) [ M[(i << {Nbits}) + j] ]

FN ArrEquals(
    IN a : ^UWORD,
    IN b : ^UWORD,
) : UWORD
    i := 0
    j := 0
    WHILE i < {N} DO
        WHILE j < {N} DO
            IF INDEX2(a,i,j) != INDEX2(b,i,j) THEN 
                RETURN 0
            END
            j += 1
        END
        i += 1
    END
    RETURN 1
END

A : UWORD[{N*N}]
B : UWORD[{N*N}]
C : UWORD[{N*N}]
Expected : UWORD[{N*N}] = {printMat(Expected)}

FN TestMain () : UWORD    
    i := 0
    j := 0
    WHILE i < {N} DO
        WHILE j < {N} DO
            INDEX2(A,i,j) = i+1
            INDEX2(B,i,j) = i + j
            j += 1
        END
        i += 1
    END

    sum : UWORD
    i = 0
    k := 0
    WHILE i < {N} DO
        j = 0
        WHILE j < {N} DO
            sum = 0
            k = 0
            WHILE k < {N} DO
                sum += SoftMul(INDEX2(A,i,k), INDEX2(B,k,j))
                k += 1
            END
            INDEX2(C,i,j) = sum
            SimPutc(0x30 + (sum & 0xF))
            SimPutc(0x30 + ((sum >> 4) & 0xF))
            SimPutc(0xA)
            j += 1
        END
        i += 1
    END

    RETURN ArrEquals(&C[0], &Expected[0])
END
"""

print(template)
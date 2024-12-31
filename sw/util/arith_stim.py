import numpy as np

N = 20

np.random.seed(0)
A = np.random.randint(-(1<<31),(1<<31)-1, size=N, dtype=np.int64)
B = np.random.randint(-(1<<31),(1<<31)-1, size=N, dtype=np.int64)

fixnum = lambda x:  (x + (1<<32)) & ((1<<32)-1)

Expected = np.zeros((N,4),dtype=np.int64)
for i in range(N):
    Expected[i][0] = (A[i] * B[i]) & ((1<<32)-1)
    Expected[i][1] = int(A[i] / B[i])
    x = fixnum(A[i])
    y = fixnum(B[i])
    Expected[i][2] = int(x / y)
    Expected[i][3] = x % y

def printMat(M):
    s = "{\n"

    for i in range(N):
        for j in range(4):
            if (i * 4 + j) != N*4-1:
                s += f"    [{i*4+j}] = {fixnum(M[i][j])},\n"
            else:
                s += f"    [{i*4+j}] = {fixnum(M[i][j])}\n"
    s += "}"
    return s

def printArr(M): 
    s = "{\n" 
    
    for i in range(N):
        if (i != N-1):
            s += f"    [{i}] = {fixnum(M[i])},\n"
        else:
            s += f"    [{i}] = {fixnum(M[i])}\n"
    s += "}"
    return s

template = f"""
#INCLUDE "<inc>/Util.hjk"

A : ULONG[{N}] = {printArr(A)}
B : ULONG[{N}] = {printArr(B)}
C : ULONG[{4}]
Expected : ULONG[{N*4}] = {printMat(Expected)}

FN TestMain () : UWORD    
    i := 0
    WHILE i < {N} DO
        C[0] = A[i] * B[i]
        divs := (CAST A[i] TO LONG) / (CAST B[i] TO LONG)
        C[1] = CAST divs TO ULONG
        C[2] = A[i] / B[i]
        C[3] = A[i] % B[i]

        j := 0
        cond := 1
        WHILE j < 4 DO
            cond = cond & (C[j] == Expected[(i << 2) + j])
            IF NOT cond THEN
                PrintNumFull(A[i])
                PrintNumFull(B[i])
                PrintNumFull(C[j])
                PrintNumFull(Expected[(i << 2) + j])
                RETURN 1
            END
            j += 1
        END
        i += 1
    END

    RETURN 0
END
"""

print(template)
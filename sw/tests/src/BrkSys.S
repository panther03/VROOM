.section text

.extern SimExit

BrkHandler:
    // immediately go back
    rfe 

SysHandler:
    jalr zero, t3, 0

TestMain:
.global TestMain
    // we load the argument for a0 very early
    li a0, 0
    la t3, SimExit
    la t1, BrkHandler
    // load the instruction
    mov t2, long [t1]
    // store break handler in appropriate place
    mov long [zero + 0x600], t2
    // sys handler is + 1 instruction
    mov t2, long [t1 + 4]
    mov long [zero + 0x200], t2
    // make sure EB is zero
    mtcr eb, zero

    // set return code for failure case
    li a3, 3

    // barrier so that the dcache is flushed out
    mb

    // invalidate icache so it loads the updated program
    mtcr icachectrl, a3

    brk 

    // should come back here after brk exception
    sys

    // if we are here it is a fail
    ret
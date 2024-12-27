.section text

.extern SimExit

ExcHandler:
    jalr zero, t3, 0

TestMain:
.global TestMain
    // we load the argument for a0 very early
    li a0, 0
    la t3, SimExit
    la t1, ExcHandler
    // load the instruction
    mov t2, long [t1]
    // store it at address 0 + 0x800 (ecause offset for privileged access)
    // in memory so we can execute it from there
    mov long [zero + 0x800], t2
    // make sure EB is zero
    mtcr eb, zero

    // set return code for failure case
    li a3, 3

    // barrier so that the dcache is flushed out
    mb

    // invalidate icache so it loads the updated program
    mtcr icachectrl, a3

    // set user mode
    li t1, 1
    mtcr rs, t1


    // should generate an exception now
    mfcr t0, whami
    ret
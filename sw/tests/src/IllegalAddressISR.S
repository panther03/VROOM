.section text

.extern SimExit
.extern PrintNumFull

ExcHandlerStub:
    jalr zero, t3, 0

ExcHandlerFull:
    la t1, PrintNumFull
    mfcr a0, ebadaddr
    jalr zero, t1, 0
    // return code for simexit in routine
    li a0, 0
    la t1, SimExit
    jalr zero, t1, 0

TestMain:
.global TestMain
    la t3, ExcHandlerFull
    la t1, ExcHandlerStub
    // load the instruction
    mov t2, long [t1]
    // store it at address 0 + 0x400 (ecause offset for bus error)
    // in memory so we can execute it from there
    mov long [zero + 0x400], t2
    // make sure EB is zero
    mtcr eb, zero

    // set return code for failure case
    li a3, 3

    // barrier so that the dcache is flushed out
    mb

    // invalidate icache so it loads the updated program
    mtcr icachectrl, a3

    // read from the bad address
    la t1, OutsideBadAddr
    mov t1, long [t1]
    mov t2, long [t1]

    // bus error are asynchronous. wait a couple cycles
    // all we'd need to do to block is access the bus again,
    // because VROOM handles all bus requests serially, but that is too much work.
    nop
    nop
    nop
    nop
    
    ret

.section data 

OutsideBadAddr:
.global OutsideBadAddr
.dl 0xF8000064
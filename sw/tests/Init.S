.section text

.extern SetupAndMain
.extern SimExit

// vector 0 - nothing
    hlt

.align 256
// vector 1 - interrupt
    hlt

.align 256
// vector 2 - syscall
    hlt

.align 256
// vector 3 - nothing
    hlt

.align 256
// vector 4 - bus error
    hlt

.align 256
// vector 5 - NMI
    hlt

.align 256
// vector 6 - breakpoint
    hlt

.align 256
// vector 7 - illegal instruction
    hlt

.align 256
// vector 8 - privilege violation
    hlt

.align 256
// vector 9 - unaligned address
    hlt

.align 256
// vector 10 - nothing
    hlt

.align 256
// vector 11 - nothing
    hlt

.align 256
// vector 12 - page fault read
    nop

.align 256
// vector 13 - page fault write
    nop

.align 256
// vector 14 - nothing
    nop

.align 256
// vector 15 - nothing
    nop

.align 256

//  We should now be at 0xFFFE1000, the reset vector.

FwReset:
.global FwReset
    // Set the initial stack pointer to 1024 bytes.
    li   sp, 0x400

    // todo jalling to the routine right after this yields the wrong address?
    // not sure why
    mov s1, long [sp + 4]
    mov s2, long [sp + 8]

    jal SetupAndMain

    mov a0, a3

    jal SimExit
    

finish: 
    j finish
.section text

.extern SetupAndMain
.extern SimExit

// vector 0 - nothing
    nop

.align 256
// vector 1 - interrupt
    nop

.align 256
// vector 2 - syscall
    nop

.align 256
// vector 3 - nothing
    nop

.align 256
// vector 4 - bus error
    nop

.align 256
// vector 5 - NMI
    nop

.align 256
// vector 6 - breakpoint
    nop

.align 256
// vector 7 - illegal instruction
    nop

.align 256
// vector 8 - privilege violation
    nop

.align 256
// vector 9 - unaligned address
    nop

.align 256
// vector 10 - nothing
    nop

.align 256
// vector 11 - nothing
    nop

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

    jal SetupAndMain

    jal SimExit

finish: 
    j finish
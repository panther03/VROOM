.section text

.extern SetupAndMain
.extern ExceptionCrash
.extern SimExit

// vector 0 - nothing
    li a0, 0
    la t0, ExceptionCrash
    jalr zero, t0, 0

.align 256
// vector 1 - interrupt
    li a0, 1
    la t0, ExceptionCrash
    jalr zero, t0, 0

.align 256
// vector 2 - syscall
    li a0, 2
    la t0, ExceptionCrash
    jalr zero, t0, 0

.align 256
// vector 3 - nothing
    li a0, 3
    la t0, ExceptionCrash
    jalr zero, t0, 0

.align 256
// vector 4 - bus error
    li a0, 4
    la t0, ExceptionCrash
    jalr zero, t0, 0

.align 256
// vector 5 - NMI
    li a0, 5
    la t0, ExceptionCrash
    jalr zero, t0, 0

.align 256
// vector 6 - breakpoint
    li a0, 6
    la t0, ExceptionCrash
    jalr zero, t0, 0

.align 256
// vector 7 - illegal instruction
    li a0, 7
    la t0, ExceptionCrash
    jalr zero, t0, 0

.align 256
// vector 8 - privilege violation
    li a0, 8
    la t0, ExceptionCrash
    jalr zero, t0, 0

.align 256
// vector 9 - unaligned address
    li a0, 9
    la t0, ExceptionCrash
    jalr zero, t0, 0

.align 256
// vector 10 - nothing
    li a0, 10
    la t0, ExceptionCrash
    jalr zero, t0, 0

.align 256
// vector 11 - nothing
    li a0, 11
    la t0, ExceptionCrash
    jalr zero, t0, 0

.align 256
// vector 12 - page fault read
    li a0, 12
    la t0, ExceptionCrash
    jalr zero, t0, 0

.align 256
// vector 13 - page fault write
    li a0, 13
    la t0, ExceptionCrash
    jalr zero, t0, 0

.align 256
// vector 14 - nothing
    li a0, 14
    la t0, ExceptionCrash
    jalr zero, t0, 0

.align 256
// vector 15 - nothing
    li a0, 15
    la t0, ExceptionCrash
    jalr zero, t0, 0

.align 256

//  We should now be at 0xFFFE1000, the reset vector.

FwReset:
.global FwReset
    // Set the exception handler base.
    lui  t0, zero, 0xFFFE0000
    mtcr eb, t0

    // Set the initial stack pointer to 1024 bytes.
    li   sp, 0x400

    jal SetupAndMain

    mov a0, a3

    jal SimExit
    

finish: 
    j finish

.section text

TestMain:
.global TestMain
    mov a3, zero
    li t1, 0x5A5A
    mtcr rs, t1
    mfcr t2, rs
    subi t2, t2, 0x5A5A
    bne t2, fail

    mtcr whami, t1
    mfcr t2, whami
    subi t2, t2, 0x5A5A
    bne t2, fail

    mtcr eb, t1
    mfcr t2, eb
    subi t2, t2, 0x5A5A
    bne t2, fail

    mtcr epc, t1
    mfcr t2, epc
    subi t2, t2, 0x5A5A
    bne t2, fail

    mtcr ebadaddr, t1
    mfcr t2, ebadaddr
    subi t2, t2, 0x5A5A
    bne t2, fail

    mtcr tbmissaddr, t1
    mfcr t2, tbmissaddr
    subi t2, t2, 0x5A5A
    bne t2, fail

    mtcr tbpc, t1
    mfcr t2, tbpc
    subi t2, t2, 0x5A5A
    bne t2, fail

    mtcr scratch0, t1
    mfcr t2, scratch0
    subi t2, t2, 0x5A5A
    bne t2, fail

    mtcr scratch1, t1
    mfcr t2, scratch1
    subi t2, t2, 0x5A5A
    bne t2, fail

    j done
fail:
    li a3, 1
done:
    ret
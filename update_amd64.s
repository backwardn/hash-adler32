// Copyright 2017 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Inspired by
// https://software.intel.com/en-us/articles/fast-computation-of-adler32-checksums
// https://github.com/01org/isa-l
// Special thanks to Roy Oursler

#include "textflag.h"

#define BASE $0xfff1
#define LIMIT $5552

#define xa X0
#define xb X1
#define xsa X2
#define xdata0 X3
#define xdata1 X4

#define a_d SI
#define b_d DI
#define end R9
#define init_d R10
#define data R11
#define size R12
#define s R13

#define PSLLD_BY_2_X1 BYTE $0x66; BYTE $0x0f; BYTE $0x72; BYTE $0xf1; BYTE $0x02
#define PSUBD_X2_X1 BYTE $0x66; BYTE $0x0F; BYTE $0xFA; BYTE $0xca

// func updateSSE(d digest, p []byte) digest
TEXT ·updateSSE(SB), NOSPLIT, $0
	MOVD digest+0(FP), init_d // digest value
	MOVQ dp+8(FP), data       // data pointer
	MOVQ pl+16(FP), size      // len(p)

	MOVD init_d, b_d
	SHRL $16, b_d
	ANDQ $0xffff, init_d
	CMPQ size, $32
	JB   lt32
	MOVD init_d, xa
	PXOR xb, xb
	PXOR xsa, xsa
	
sloop1:
	MOVQ    LIMIT, s
	CMPQ    s, size
	CMOVQGT size, s             //  s = min(size, LIMIT)
	LEAQ    -7(data)(s*1), end  // check more than 8 bytes
	CMPQ    data, end
	JA      skip_loop_1a

sloop1a:
	// do 8 adds
	PMOVZXBD (data), xdata0
	PMOVZXBD 4(data), xdata1
	ADDQ     $8, data
	PADDD    xdata0, xa
	PADDD    xa, xb
	PADDD    xdata1, xa
	PADDD    xa, xb
	CMPQ     data, end
	JB       sloop1a

skip_loop_1a:
	
	ADDQ   $7, end  // restore end index
	SUBQ   s, size
	TESTQ  $7, s
	JNZ do_final

	// hit limit
	PSLLD_BY_2_X1           
	MOVOU  xa, xsa
	PMULLD A_SCALE<>(SB), xsa

	PHADDD xa, xa
	PHADDD xb, xb
	PHADDD xsa, xsa
	PHADDD xa, xa
	PHADDD xb, xb
	PHADDD xsa, xsa

	MOVD xa, AX
	XORQ DX, DX
	MOVL BASE, CX
	DIVL CX
	MOVD DX, a_d

	PSUBD_X2_X1
	MOVD xb, AX
	ADDL b_d, AX
	XORQ DX, DX
	MOVL BASE, CX
	DIVL CX
	MOVD DX, b_d

	TESTQ size, size
	JZ    finish // hit limit or done

	MOVD a_d, xa
	PXOR xb, xb
	JMP  sloop1

finish:
	CMPQ data, end
	JNE  do_final
	MOVD b_d, AX
	SHLQ $16, AX
	ORQ  a_d, AX
	JMP  ret

lt32:
	MOVD  init_d, a_d
	LEAQ  0(data)(size*1), end
	TESTQ size, size
	JNZ   final_loop
	JMP   zero_size

do_final:
	PSLLD_BY_2_X1             
	MOVOU  xa, xsa
	PMULLD A_SCALE<>(SB), xsa

	PHADDD xa, xa
	PHADDD xb, xb
	PHADDD xsa, xsa
	PHADDD xa, xa
	PHADDD xb, xb
	PHADDD xsa, xsa
	PSUBD_X2_X1

	MOVD xa, a_d
	MOVD xb, AX
	ADDQ AX, b_d

final_loop:
	MOVBQZX 0(data), AX
	ADDQ    AX, a_d
	INCQ    data
	ADDQ    a_d, b_d
	CMPQ    data, end
	JB      final_loop

zero_size:
	MOVD a_d, AX
	XORQ DX, DX
	MOVL BASE, CX
	DIVL CX
	MOVD DX, a_d  // a_d % 65521

	MOVD b_d, AX
	XORQ DX, DX
	MOVL BASE, CX
	DIVL CX
	SHLQ $16, DX
	ORL  a_d, DX
	MOVD DX, AX

ret:
	MOVD AX, ret+32(FP)
	RET

// Intel is little endian
DATA A_SCALE<>+0x00(SB)/8, $0x0000000100000000
DATA A_SCALE<>+0x08(SB)/8, $0x0000000300000002
GLOBL A_SCALE<>(SB), 8, $16

SYSt		STRUC
	Mach		dw	0
	DosVer		dw	0
	Processor	dw	88h		; processor 8088
	Coprocessor	dw	0
	XMShere		dw	0
	FirstDevH	dw	0,0
	FirstDiscInBl	dw	0,0
	Drives		db	0
	VideoAdapt	dw	0
SYSt		ENDS
MovDsc	Struc
	From	dd	0
        To	dd	0
MovDsc	EndS
 Descr		Struc
  Limit		DW	0
  BaseLo	DW	0
  BaseHi	DB	0
  DType		DB	0
  Reserved	DB	0
  BaseHigh	DB	0
 Descr		EndS
FLAB		STRUC
Normf		dw	0
ShiftF		dw	0
CtrlF		dw	0
Altf		dw	0
FLAB		ENDS
MDescr		Struc
		dummyd	descr	<0,0,0,0,0,0>
                thisgd	descr	<0,0,0,0,0,0>
                source	descr	<-1,0,0,93h,0,0>
                destin	descr	<-1,0,0,93h,0,0>
                codesd	descr	<0,0,0,0,0,0>
                stcksd	descr	<0,0,0,0,0,0>
MDescr		Ends
Switch         Macro Char,Addr1,Addr2
		push	ax
		push	ax
                mov     al,Char
                push	bp
                push	dx
                push	cx
                push	bx
                lea     bp,Addr1
                lea     dx,Addr2
                jmp     Case
               EndM
GetMem         Macro Size
		push	bx
                mov    bx,Size
                call   MemoryAllocate
                pop	bx
               EndM
GetHeap	       macro Size
		push	bx
                mov	bx,Size
                call	HeapAllocate
                pop	bx
	       Endm
clz	       Macro
                push	ax
                lahf
                and	ah,0bfh
                sahf
                pop	ax
               Endm

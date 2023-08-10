code		segment	public
		assume	cs:code,ds:nothing,es:nothing,ss:nothing
		include	cnmacro.inc
                include	task.inc
public		TESTONMULTITASK,FREEMEM,_SETUP,RSTZBLOCKSIZE,_RESTORE,VIDEO,IS84KEY 
public		XMSDRVADDR,MEMORYALLOCATE,ISITAT,CONVERTWORD,SYSTEM,XMSPRESENT 
public		FREEMEMBLOCK,CASE,BARRIER,CREATEBARRIER,ISITCGA,SEARCH_FREE_INT
public		ismousehere,isitega,zsize1,zsize2,zaddr1,zaddr2,mylastmcb
extrn		mtrestore:near

extrn		irqbase:byte

Video		dw	0
xmsdrvaddr	dd	0
mypsp		dw	0
buttons		db	0
VideoAdapters	label	byte
MCGA		db	'MCGA '
VGA		db	'VGA '
EGA		db	'EGA '
CGA		db	'CGA '
Monocr		db	'MONO '
Processors	label	byte
V20		db	'NECÿV20 '
i88		db	'88 '
i86		db	'86 '
i286		db	'286 '
i386		db	'386 '
i486		db	'486 '
i87		db	'87 '
i287		db	'287 '
i387		db	'387 '
NoneMess	db	'None     '
PCmess		db	'PC '
PCjrmess	db	'PCjr '
XTmess		db	'XT '
ATmess		db	'AT '
Unmess		db	'PC'
intlist		db	50h,58h,68h,78h,0f8h
search_free_int	proc
		push	ds
		xor	ax,ax
		mov	ds,ax
                xor	si,si
                mov	cx,5
     sfreei:    push	cx
                mov	al,intlist[si]
                mov	di,ax
		shl	di,1
                shl	di,1
                mov	bx,[di]
                mov	dx,[di+2]
		mov	cx,7
      testrange:add	di,4
                cmp	bx,[di]
                jne	badrange
                cmp	dx,[di+2]
                jne	badrange
                loop	testrange
		jmp	goodrange
      badrange:	inc	si
		pop	cx
		loop	sfreei
		pop	ds
		ret
      goodrange:pop	cx
		mov	irqbase,al
		pop	ds
		ret
search_free_int	endp
SystemAnalys	Proc
		push	ds
                push	si
                push	es
                push	di
		int	11h
		mov	cl,6
		shr	ax,cl
		and	al,3
		inc	al
		mov	cs:system.drives,al
                xor	ax,ax
                int	33h
		mov	buttons,al
                xor	ax,ax
                not	ax			;ax=FFFF
                mov	ds,ax
                mov	si,0Eh
                mov	al,[si]			;al <- MachType
                push	cs
                pop	ds
                Switch	al,MachTypes,MachInfo
MachPcjr:	lea	si,PCjrMess
		jmp	short TypeY
MachPC:		lea	si,PCMess
		jmp	short TypeY
MachXT:		lea	si,XTMess
		jmp	short TypeY
MachAT:		lea	si,AtMess
		jmp	short TypeY
MachUnKn:	lea	si,Unmess
TypeY:		
ItsAt:          mov	cs:System.Mach,si
		cmp	cs:[si],'TA'
                jnz	NoEMS1
                mov	ah,88h
                int	15h
                mov	cs:System.XMShere,ax
		call	xmspresent
		jne	noems1
		mov	ax,4310h
		xor	bx,bx
		mov	es,bx
		int	2fh
		mov	word ptr cs:xmsdrvaddr,bx
		mov	word ptr cs:xmsdrvaddr+2,es
NOEMS1:		mov	ah,30h
                int	21h
                mov	cs:System.Dosver,ax
                call	GetProcessor
                mov	cs:System.Processor,ax
                ;call	GetCoprocessor
                ;mov	cs:System.Coprocessor,ax
		cmp	cs:system.processor,offset i286
		je	forceAT
		cmp	cs:system.processor,offset i386
		je	forceAT
		cmp	cs:system.processor,offset i486
		je	forceAT
		lea	ax,xtmess
		mov	cs:system.mach,ax
		jmp	msnorm
	forceAT:
		lea	ax,atmess
		mov	cs:system.mach,ax
	msnorm:
		;cli
		;mov	ax,5200h
		;int	21h
		;add	bx,22h
		;mov	cs:System.FirstDevH  ,bx
		;mov	cs:System.FirstDevH+2,es
; Find first disc info table
		;mov	ax,5200h
		;int	21h
		;mov	ax,es:[bx]
                ;mov	cs:System.FirstDiscInBl  ,ax
		;mov	ax,es:[bx+2]
                ;mov	cs:System.FirstDiscInBl+2,ax

; video adapter ?
		mov	ax,40h
                mov	ds,ax                 ; Set DS to BIOS Data
                mov	ax,ds:10h
                and	ax,30h
                cmp	ax,30h
                mov	dx,0b800h
                jnz	ColoMon
                mov	dx,0b000h
ColoMon:	mov	cs:Video,dx
                ;cmp	byte ptr ds:[84h],0
		push	dx
		mov	ax,1200h
                mov	bx,0FF10h
                int	10h
                cmp	bh,0ffh
                pop	dx	
                jnz	EGA_Found
                cmp	dx,0b800h
                jnz	Mono
	CgaHere:
		cmp	cs:video,0b800h
                jne	mono
                lea	ax,CGA
                jmp	short AdDef
Mono:		lea	ax,Monocr
		jmp	short AdDef
EGA_Found:	
		mov	ax,1130h
		push	ds
		int	10h
		pop	ds
	        cmp	dl,byte ptr ds:[84h]
		jne	cgahere
		mov	ah,1ah
		xor	al,al
                xor	bl,bl
                int	10h
                cmp	al,1ah
                jne	Takiega
                lea	ax,MCGA
                cmp	bl,8
                ja	Addef
                lea	ax,VGA
                jmp	short	addef
Takiega:        lea	ax,EGA
AdDef: 		mov	cs:System.VideoAdapt,ax
		pop	di
                pop	es
                pop	si
                pop	ds
		ret
SystemAnalys	Endp
ismousehere	proc
		cmp	buttons,0ffh
		ret
ismousehere	endp
IsitColor	Proc
		cmp	cs:Video,0b800h			; warning !
		ret
IsitColor	Endp
FirstMCBSearch	Proc
		push	es
		push	bx
		mov	ax,5200h
		int	21h
                mov	ax,es:[bx-2]
		mov	cs:Firstmcb,ax
		pop	bx
		pop	es
		ret
FirstMCBSearch	Endp
FindLastMCB	Proc
		push	ax
                push	cx
		mov	es,cs:FirstMCB
FZBL:           mov	ax,es:3
		mov	cx,es
		add	ax,cx
                inc	ax
                mov	es,ax
                cmp	es:0,byte ptr 'Z'
                mov	cs:LastMCB,es
                jnz	FZBL
FZBOK:		pop	cx
		pop	ax
		ret
FindLastMCB	Endp
FindMyLastMCB	proc		; search mcb next after my last mcb
		push	ax
                push	cx
		mov	ax,mypsp
		dec	ax
		mov	es,ax
FMZBL:          
		mov	ax,es:3
		mov	cx,es
		add	ax,cx
                inc	ax
                mov	es,ax
                mov	cx,mypsp
                ;dec	cx
                cmp	es:[1],cx
                jz	FMZBL
                mov	cs:MyLastMCB,es
		pop	cx
		pop	ax
		ret
		ret
FindMyLastMCB	endp

notenmemm	db	7,13,10,'Not enough memory.',13,10,'$'
notenmem:	call	mtrestore
		mov	ah,9
		movr	ds,cs
		lea	dx,notenmemm
		int	21h
		mov	ax,4cffh
		int	21h

MyLastMCB	dw	0
FirstMCB	dw	0
LastMCB		dw	0
EOMem		dw	0
Barrier		dw	0
zsize1		label	word
Binitw		dw	0
zaddr1		dw	0
zsize2		dw	0
zaddr2		dw	0
CreateBarrier	proc	; size in ax
		; allocate 1 para block
                ; his size=1 to make next block Z
                ; his size=1(his cont)+1(next mcb header)+ax to hidde next
                ; we have map: ______________
                ;              |            |
                ;              |            |
                ;              |___________ |
                ;              |last used M |
                ;              |___________ |
                ;              |  Barrier   |
                ;              |___________ |
                ;              |Z for task1 |
                ;              |___________ |
                ;              |Z for task2 |
                ;              |___________ |
		push	ax
                push	ax
                call	FirstMCBSearch
                call	FindMyLastMcb
                pop	ax
                cli
                cmp	es:[3],ax
                jb	notenmem
                mov	cl,es:[0]
                mov	Barrier,es
                mov	dx,es
                add	dx,es:[3]
                mov	eomem,dx
                mov	dx,mypsp
                mov	bx,es:[3]
                mov	es:[0],byte ptr 'M'  ; create 
                mov	es:[1],dx            ; barrier
                mov	es:[3],word ptr 1    ; size=1
                mov	dx,es
                add	dx,2
                mov	es,dx
                mov	es:[0],byte ptr 'Z'  ; create
                mov	es:[1],word ptr 0    ; Zblock
                pop	ax                   ; for task 1
                mov	es:[3],ax            ; size in ax
                mov	binitw,ax	     ; save this value
                mov	zaddr1,es
                add	dx,ax
                inc	dx
                mov	es,dx
                ;mov	es:[0],byte ptr 'Z'  ; create
		mov	es:[0],cl
                mov	es:[1],word ptr 0    ; Zblock
                mov	ax,eomem	     ; for task 2
                mov	dx,es		     ; ajust size with
                sub	ax,dx		     ; eomem
                mov	es:[3],ax
                mov	zaddr2,es
                mov	zsize2,ax
		sti
		ret
CreateBarrier	Endp
RstZBlockSize	proc
		push	ds
                mov	bx,barrier
                mov	ds,bx
                mov	bx,binitw
                add	bx,2
                mov	ds:[3],bx
                pop	ds
		ret
RstZblockSize	endp
System		syst	<>
XMSPresent	Proc
		push	ax
		mov	ax,4300h
		int	2fh
		cmp	al,80h
		pop	ax
		ret
XMSPresent	endp
GetUMB		proc
		call	XMSPresent
		jnz	UMBFail
		mov	dx,bx
		mov	ah,10h
		call	dword ptr [xmsdrvaddr]
		cmp	ax,1
		jne	UMBFail
		dec	bx
		mov	es,bx
		clc
		ret
 UMBFail:	stc
		ret
GetUMB		endp
ConvertByte	Proc
		push	cx
                mov	ah,al
                mov	cl,4
                shr	ah,cl
                and	al,0fh
		cmp	al,10
		jl	num
		add	al,07h
num:		add	al,30h
		cmp	ah,10
		jl	numh
		add	ah,07h
numh:		add	ah,30h
		pop	cx
		ret
ConvertByte	Endp
ConvertWord	Proc
		mov	dl,ah
		call	ConvertByte
		push	ax
		mov	al,dl
		call	ConvertByte
		pop	dx
		ret
ConvertWord	EndP
IsitCGA		proc
		push	bx
		mov	bx,cs:system.Videoadapt
		cmp	byte ptr cs:[bx],'C'
		pop	bx
		ret
		ret
IsitCGA		endp
IsitEGA		Proc
		push	bx
                mov	bx,cs:System.Videoadapt
                cmp	cs:[bx],byte ptr 'E'
		je	Egamf
		cmp	cs:[bx],byte ptr 'V'
egamf:		pop	bx
		ret
IsitEGA		Endp
IsitAT		Proc
		push	si
                mov	si,cs:System.Mach
                cmp	cs:[si],'TA'				; AT ?
                ;cmp	ax,bp
                pop	si
                ret
IsitAT		Endp
MemoryAllocate	Proc
		push	es
                push	di
                push	cx
                push	bx
                push	dx
                push	bx

		push	bx
		call	GetUMB
		pop	bx

		jnc	yma
                ;call	FindLastMCB
		;cmp	es:[3],bx
		;ja	yma
		mov	ah,48h
		int	21h
		pushf
		dec	ax
		mov	es,ax
		popf
		jnc	yma
		pop	bx dx bx cx di es
		ret
	yma:
		cli
                push	es
                ;mov	es:0,byte ptr 'M'
                ;mov	ax,es:3
                ;mov	cx,bx
                ;mov	es:3,bx
                ;mov	dx,cs:MyPSP
                ;mov	es:1,dx
                ;mov	dx,es
                ;add	bx,dx
                ;inc	bx
                ;mov	es,bx
                ;mov	es:0,byte ptr 'Z'
                ;sub	ax,cx
                ;dec	ax
                ;mov	es:3,ax
                ;xor	ax,ax
                ;mov	es:1,ax
                pop	ax
                pop	bx
                inc	ax
		push	ax
                mov	es,ax
                xor	di,di
                mov	cx,bx
                shl	cx,1
                shl	cx,1
                shl	cx,1
		xor	ax,ax
                rep	stosw
		sti
                pop	ax
                pop	dx
                pop	bx
                pop	cx
                pop	di
                pop	es
		ret
MemoryAllocate	Endp
Is84Key		proc
		push	ds ax
		mov	ax,40h
		mov	ds,ax
		test	byte ptr ds:[96h],10h
		pop	ax ds
		ret
Is84Key		endp
_SETUP		Proc
		push	bp ds si di
		call	FirstMCBSearch
		call	SystemAnalys
		clc
		pop	di si ds bp
                retf
_SETUP		Endp
FreeMem        Proc
                mov     bx,sp
                mov     cl,4
                shr     bx,cl
                mov     ax,ss
                add     bx,ax
                mov     ax,es
                sub     bx,ax
                inc     bx
                mov     ax,4a00h
                int     21h
                call    FirstMCBSearch
                mov	ah,62h
                int	21h
                mov	cs:MyPSP,bx
                ret
FreeMem        EndP
FreeMemBlock	proc
		mov	es,ax
		cmp	ax,0A000h
		ja	FreeUMB
		mov	ah,49h
		int	21h
		jmp	mbfreed
 FreeUMB:	mov	dx,es
		mov	ah,11h
		call	dword ptr [xmsdrvaddr]
 mbfreed:	ret
FreeMemBlock	endp
_RESTORE	Proc
		retf
_RESTORE	Endp
sorrymt		db	'Error: multitasker here!',13,10,'$'
DesqVMess	db	'Error: DesqView.',13,10,'$'
NCACHEerr	db	'Error: NCACHE.',13,10,'$'
MachTypes	db	0FBh,  0FCh,  0FDh,    0FEh, 0FFh
MachInfo	dw	MachXT,MachAT,MachPCJr,MachXT,MachPC
		dw	MachUnKn
TestOnMultiTask	Proc
		mov	ax,3000h
		mov	bx,ax
		mov	cx,bx
		mov	dx,bx
		int	21h
		cmp	bx,2020h
		je	sorry
		xor	bx,bx
		mov	ax,2b01h
		mov	cx,'DE'
		mov	dx,'SQ'
		int	21h
		cmp	al,0ffh
		je	nodv
		or	bx,bx
		jne	DesqView
	nodv:	mov	ax,0fe00h
		mov	di,4e55h
		mov	si,4346h
		int	2fh
		cmp	si,6366h
		jne	ok2run
		cmp	al,0
		jne	ok2run
		push	cs
		pop	ds
		lea	dx,NCACHEerr
		mov	ah,9
		int	21h
		jmp	abmt
	ok2run:	ret
DesqView:	
		lea	dx,desqVmess
		push	cs
		pop	ds
		mov	ah,9
		int	21h
		jmp	abmt
sorry:
		lea	dx,sorrymt
		push	cs
		pop	ds
		mov	ah,9
		int	21h
abmt:
		mov	ax,4cffh
		int	21h
TestOnMultiTask	Endp
Case            Proc
		mov     cx,dx
                sub     cx,bp
                mov     bx,bp
                push    di
                mov     di,bp
                push   es
                push   cs
                pop    es
                cld
                repne   scasb
                pop    es
                xchg    di,bx
                jnz     NoChar
                dec     bx
 NoChar:        sub     bx,di
                pop     di
                shl     bx,1
                add     bx,dx
                mov	bp,sp
                mov	ax,cs:[bx]
                mov	[bp+10],ax
                pop	bx
                pop	cx
                pop	dx
                pop	bp
                pop	ax
                ret
Case            EndP
Buff		dd	0,0
que		db	0
buswidt		db	0
blp		dw	0
bds		dw	0
Errorcount	db	30,'time measurement fail.'
timersetup:	cli
		push	ax
		mov	al,36h			; regm 3 , lsb , msb
                out     43h,al                  ; ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
                mov     al,0                    ; ³     timer      ³
                out     40h,al                  ; ³     setup      ³
                mov     al,80h                  ; ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
		out	40h,al			; counter = 8000h
                pop	ax
                sti
                ret
timerrestore:	cli
		push	ax
		mov	al,36h			; regm 3 , lsb , msb
                out     43h,al                  ; ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
                mov     al,0                    ; ³     timer      ³
                out     40h,al                  ; ³     setup      ³
                out     40h,al                  ; ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
                pop	ax
                sti
                ret
getprocessor:   push	ds
		push	es
		;call	Timersetup
;-------------------
		mov	bx,sp
		push	sp
		pop	ax
		cmp	ax,bx
		jne	no80286
                jmp	eto_chto
;-------------------
no80286:
                push	cs
                pop	es
                push	cs
                pop	ds
                lea	di,Zone
                mov	cx,30h
                cld
		cli
                mov	ax,40h
		jmp	short go0                       ; this lines were not
		even                                    ; presented in origin
 go0:           rep	stosb
 Zone:		DB	30h Dup (90h)
 		sub	ax,40h
                mov	bx,30h
                sub	bx,ax
                add	bx,2
                mov	que,bl
		sti
		push	es
		mov	ax,4040h
		mov	bx,ax
		mov	cx,2
		push	cs
		pop	es
		lea	di,Go+1
		jmp	short Go
		EVEN
Go:		stosw
		db	6 dup (90h)
		sub	ax,4040h
		mov	bx,2
		sub	bx,ax
		mov	cl,1;4
		shl	bx,cl
		mov	ax,bx
		pop	es
                mov	buswidt,al
		cmp	que,6
		jmp	i8086
;		jbe	i8086
;		push	sp
;		pop	ax
;		cmp	ax,sp
;		lea	dx,i86				;Z8400ab
;		je	eto_chto
;		jmp	uPdef
	eto_chto:
                push	ds
		push	es
                call	GetInt6
		push	cs
		pop	es
		lea	di,buff
                .386
		stosd
		stosd
		.8086
                call	PutInt6
                cmp	byte ptr cs:Int6Flag,1
		pop	es
                pop	ds
		jz	i80286
i80386:		.386
		pushfd
		pushfd
                pop	ebx
                mov	ecx,ebx
                xor	ebx,00040000h
                push	ebx
                popfd
                pushfd
                pop	ebx
                xor	ebx,ecx
                test	ebx,00040000h
		jz	Taki386		; ATTN! Only temporary! (becouse of 
		popfd
                lea	dx,i486
                jmp	updef
Taki386:	popfd
		.8086
		lea	dx,i386
		mov	blp,4
                mov	bds,3
		jmp	uPdef
i80286:		lea	dx,i286
		mov	blp,3
		jmp	short uPdef
i8086:          call	Timersetup
		push	ds
		cli
		xor	ax,ax			; For BIOS-ROM I wait
		mov	ds,ax                   ; for 0-wait states
		lea	bx,LoopEVEN
                call	Counter
		jnc	CountOk1
		call	SayErrCnt
		call	Timerrestore
		jmp	WorkFin
CountOk1:
		push	ax
		xor	ax,ax			; For BIOS-ROM I wait
		mov	ds,ax                   ; for 0-wait states
                lea	bx,LoopNEVEN
                call	Counter
		jnc	countOk2
	 	call	SayErrCnt
		call	Timerrestore
		jmp	WorkFin
CountOk2:       
		call	Timerrestore
		sti
                pop	ax
                pop	ds
                sub	ax,cx
                cmp	ax,0
                jge	Nax
                neg	ax
Nax:		cmp	ax,2
		ja	i80x86
		cmp	que,6
		jae	t88
		lea	dx,V20
		mov	blp,0
		jmp     short uPdef
t88:            lea	dx,i88
		mov	blp,1
                mov	bds,0
                jmp	short uPdef
i80x86:		lea	dx,i86
		mov	blp,2
                mov	bds,4
                jmp	short uPdef
uPdef:          mov	ax,dx
Workfin:
                pop	es
                pop	ds
		ret
getint6		Proc
		push	es
                push	bx
                push	ds
                push	dx
		mov	ax,3506h
                int	21h
                mov	cs:Old6s,es
                mov	cs:Old6o,bx
                push	cs
                pop	ds
                lea	dx,Procint6
                mov	ax,2506h
                int	21h
                mov	cs:Int6Flag,0
                pop	dx
                pop	ds
                pop	bx
                pop	es
		ret
getint6		endP
Putint6		Proc
		push	ds
                push	dx
                mov	ds,cs:old6s
                mov	dx,cs:old6o
                mov	ax,2506h
                int	21h
                pop	dx
                pop	ds
		ret
Putint6		endP
old6s		dw	0
old6o		dw	0
Int6Flag	db	0
Procint6:	mov	bp,sp
		mov	cs:Int6Flag,1
		add	word ptr [bp],2
		iret
Sayerrcnt	proc
		ret
Sayerrcnt	endp
Counter	Proc	near
		cli
		mov	cs:OflFlag,byte ptr 0
		mov	cs:dsSaver,ds
		xor	ax,ax
        	mov	ds,ax
        	mov	si,4*8		; adrr	int8
        	push	word ptr ds:[si]
        	push	word ptr ds:[si+2]
        	lea	ax,New8
        	mov	ds:[si],ax
        	mov	ds:[si+2],cs
        	push	si
		push	ds
		mov	ds,cs:dsSaver
        	mov	cx,0ffffh
		in	al,21h			; get  IMR
		push	ax			; save IMR
		mov	AL,11111110b		; lock all but IRQ0
		out	21h,al
                xor	dx,dx
                mov	ax,1
                mov	bp,ax
	        sti
	        hlt				; waiting for INT8
		pop	ax			; restore IMR
		out	21h,al			; set old IMR
        	pop	ds
	        pop	si
        	pop	word ptr ds:[si+2]
	        pop	word ptr ds:[si]
		mov	ax,0ffffh
		sub	ax,cx
		mov	cx,ax
		shl	cs:OflFlag,1		; set FC if OflFlag = ffff
	        ret
Counter		EndP
;GetCoprocessor	Proc
;		int	11h
;                and	al,2
;                lea	ax,NoneMess
;                jz	NoneCopr
;                lea	ax,i87
;                call	IsitAT
;                jne	NoneCopr
;                lea	ax,i287
;Nonecopr:	mov	cs:System.Coprocessor,ax
;		ret
;GetCoprocessor	Endp
OflFlag		db	0
dsSaver		dw	0
FastMem		dw	0
new8:
		mov	al,20h
		out	20h,al
		sti
		cmp	cs:OflFlag,byte ptr 0
	        jnz	Second8
        	mov	cs:OflFlag,byte ptr 1
	        call	bx			;LoopN
		mov	cs:OflFlag,byte ptr 0ffh
		hlt
Exit8:		pushf
		pop	ax
		mov	bp,sp
		mov	[bp+4],ax
        	iret
Second8:
		cmp	cs:OflFlag,byte ptr 0FFh
		jz	AboFin
		pop	ax			; Kill Call
aboFin:		mov	al,1
		cmp	al,cs:OflFlag
        	pop	ax
        	pop	ax
        	pop	ax
        	jmp	exit8
                even
LoopEVEN:
		mov	ds:[0],ax
		mov	ds:[0],ax
		mov	ds:[0],ax
		mov	ds:[0],ax
                loop	LoopEVEN
		ret
                even
LoopNEVEN:
		mov	ds:[1],ax
		mov	ds:[1],ax
		mov	ds:[1],ax
		mov	ds:[1],ax
		loop	LoopNEVEN
		ret
code		ends
		end
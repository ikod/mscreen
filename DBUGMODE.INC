;EMMNAME		db	'EMMXXXX0'
;EMMPresent	Proc
;		push	es di bx ds si cx
;		mov	ax,3567h
;               int	21h
;                mov	cx,8
;		mov	di,0ah
;                movr	ds,cs
;                lea	si,emmname
;                cld
;                rep	cmpsb
;                pop	cx si ds bx di es
;		ret
;EmmPresent	Endp
if		DEBUGMODE
dostype		proc
		push	ds bx
		movr	ds,cs
		mov	ah,9
		int	21h
		pop	bx ds
		ret
dostype		endp
machrec		db	'Machine ..$'
procmes		db	'Processor.$'
atma		db	'AT',13,10,'$'
xtma		db	'XT',13,10,'$'
;xmspres		db	'XMS ......$'
;emspres		db	'EMS ......$'
;execmode	db	'Now in ...$'
;realm		db	'real mode',13,10,'$'
;v86m		db	'v86',13,10,'$'
majdosver	db	'DOS ver...$'
oemlabel	db	'OEM.......$'
present		db	'present',13,10,'$'
npresent	db	'not present',13,10,'$'
abort:		mov	ax,4c01h
		int	21h
report		proc
		lea	dx,Machrec
		call	dostype
		lea	dx,xtma
		mov	bx,system.mach
		cmp	word ptr cs:[bx],'TA'
		jne	xtrec
		lea	dx,atma
 xtrec:		call	dostype
		lea	dx,procmes
		call	dostype
		mov	si,system.processor
		movr	ds,cs
   prcloop:	lodsb
		cmp	al,20h
		je	prctyped
		mov	ah,2
		mov	dl,al
		int	21h
		jmp	prcloop
prctyped:	lea	dx,crlf
		call	dostype
		;lea	dx,execmode
		;call	dostype
		;lea	dx,realm
		;call	isitat
		;jne	modedefd
		;.286p
		;smsw	ax
		;.8086
		;test	ax,1
		;jz	modedefd
		;lea	dx,v86m
modedefd:	;call	dostype
		;lea	dx,xmspres
		;call	dostype
		;lea	dx,present
		;call	xmspresent
		;jz	txmss
		;lea	dx,npresent
txmss:		;call	dostype
		;lea	dx,emspres
		;call	dostype
		;call	emmpresent
		;lea	dx,npresent
		;jnz	noems
                ;lea	dx,present
                ;jmp	noems
		
                ;.286p
		;smsw	ax
		;.8086
		;test	ax,1
		;jz	noems
                ;mov	ax,8102h
		;xor	dx,dx
		;xor	bx,bx
		;int	4bh
		;lea	dx,present
                ;jc	unknems
		;lea	dx,Qmaps
		;cmp	bx,0
		;jz	noems
		;lea	dx,emm386
		;cmp	bx,1
		;jz	noems
		;lea	dx,m386max
		;cmp	bx,4560h
		;je	noems
		;lea	dx,vcomm
		;cmp	bx,4d43h
		;je	noems
		;lea	dx,qemm386
		;cmp	bx,5145h
		;je	noems
unknems:	;lea	dx,present
noems:		;call	dostype
		;cmp	bx,1
		;jne	noemm386
abinst:		;call	_restore
		;mov	ax,4c01h
		;int	21h
noemm386:
		lea	dx,majdosver
		call	dostype
		mov	ax,3000h
		int	21h
		push	ax
		push	bx
		add	al,30h
		mov	dl,al
		mov	ah,2
		int	21h
		lea	dx,crlf
		call	dostype
		lea	dx,OEMlabel
		call	dostype
                mov	ax,4412h	; check for old DR-DOS vers.
                clc
                int	21h
                jc	nodrdos
                lea	dx,drdos
                call	dostype
                jmp	abort
	nodrdos:pop	bx
		pop	ax		;restore oema
		xchg	bh,bl
		lea	dx,ibmoem
		cmp	bl,0
                jne	testzen
		cmp	al,3
		jne	testzen
		mov	bl,0ffh
	testzen:lea	dx,zenithoem
		cmp	bl,5
		je	typeoem
		lea	dx,DECoem
		cmp	bl,16h
		je	typeoem
		lea	dx,olivettyoem
		cmp	bl,23h
		je	typeoem
		lea	dx,toshibaoem
		cmp	bl,29h
		jne	nooli
                call	dostype
                jmp	abort
	nooli:	lea	dx,hewlettoem
		cmp	bl,4dh
		je	typeoem
		lea	dx,staroem
		cmp	bl,9dh
		je	typeoem
		lea	dx,microsoem
		cmp	bl,0ffh
		je	typeoem
		lea	dx,unknoem
typeoem:	call	dostype
		lea	dx,crlf
		call	dostype
                lea	dx,irq0willbe
                call	dostype
                mov	al,irqbase
		call	prepbyte
                xchg	ah,al
                mov	word ptr cs:irqm,ax
                lea	dx,cs:irqm
                call	dostype
		ret
report		endp
irq0willbe	db	'IRQ0  -> ..int $'
irqm		db	0,0,'h',13,10,'$'
ibmoem		db	'IBM PC DOS: not tested.$'
zenithoem	db	'Zenith: not tested.$'
DECOem		db	'DEC: not tested.$'
olivettyoem	db	'Olivetti DOS: not supported.',13,10,'$'
toshibaoem	db	'Toshiba: not tested.$'
hewlettoem	db	'HP: not tested.$'
staroem		db	'Starlite (not tested)$'
Microsoem	db	'Microsoft MS DOS$'
DRdos		db	'DR DOS - not supported.',13,10,'$'
unknoem		db	'UNKNOWN and not tested$'
crlf		db	13,10,'$'
starttxt	db	'Starting...$'
getvectxt	db	'Get vect...$'
sPICtxt		db	'PIC setup..$'
oktext		db	'OK.',13,10,'$'
waitmomtxt	db	'Wait a mom.$'
PrepByte:       mov ah,al
                mov cl,4
                shr al,cl
                call    ToAscii
                xchg    al,ah
                call    ToAscii
                ret

ToAscii:        and al,0fh
                or  al,90h
                daa
                adc al,40h
                daa
                ret
saystart	proc
		push	ds dx
		movr	ds,cs
		lea	dx,starttxt
		mov	ah,9
		int	21h
		pop	dx ds
		ret
saystart	endp
say_getvectors	proc
		push	dx
		lea	dx,getvectxt
                call	dostype
		pop	dx
		ret
say_getvectors	endp
say_PIC_set	proc
		push	dx
		lea	dx,spictxt
                call	dostype
		pop	dx
		ret
say_PIC_set	endp
testingwait	proc
		push	bp
		push	dx
		lea	dx,waitmomtxt
                call	dostype
		pop	dx
		mov	ah,0
		int	1ah
		mov	bp,dx
wait1sec:	
		mov	ah,0
		int	1ah
		sub	dx,bp
		cmp	dx,18
		jb	wait1sec
		call	sayok
		pop	bp
		ret
testingwait	endp
sayok		proc
		push	dx
		lea	dx,oktext
                call	dostype
		pop	dx
		ret
sayok		endp
endif

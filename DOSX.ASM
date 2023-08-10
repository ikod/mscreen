code		segment	public
		assume	cs:code,ds:nothing,es:nothing

include		task.inc
include		cnmacro.inc
extrn		taskman:atman

extrn		idle:near,switchallowed:near,switchtask:near,wword:near,case:near
extrn		suspend:near,release_queue:near,lockdos:near,unlockdos:near

extrn		ready:byte

extrn		video:word,taskarea:word

extrn		dosflag:dword,old21:dword

public		new21,dosowner,indos_queue,free_to_dos,indos_c
public		penalty_proc

scanf3		equ	3dh
scanf5		equ	3fh
scanins		equ	52h
scanleft	equ	4bh
scanrght	equ	4dh
scandel		equ	53h
edline		struc
	insmode	db	0
	cnt	db	0
	bufbeg	dw	0
	buflen	dw	0
	diff	dw	0
        drvstat	dw	0
edline		ends
fnums		db	0,1,2,3,4,5,6,7,8,9,0ah,0bh,0ch
funcs		dw	term,kbdin,dsplch,auxinp,auxout
		dw	prnout,conio,noehunfinp,noechinp,dsplstr
		dw	bufrdinp,instatus,clrinp
                dw	term
indos_queue	queue	<>
conq		queue	<>
DosOwner	dw	0
indos_c		db	0
COMMENT		|
signal_deadlock	proc
		cmp	taskman.in_c,0
                jne	signal1
		cmp	taskman.sintlvl,0
                jne	signal2
                cmp	taskman.hintlvl,0
                jne	signal3
		lea	si,odl
                jmp	saydeadlock
signal1:	lea	si,incdl
                jmp	saydeadlock
signal2:	lea	si,insintdl
                jmp	saydeadlock
signal3:	lea	si,inhintdl
                jmp	saydeadlock
saydeadlock:	movr	ds,cs
		mov	es,video
		mov	di,0
		mov	ah,0ah
                push	si
                mov	dl,-1
		lea	si,comfail
 wsig:		lodsb
		or	al,al
		jz	thalt
                stosw
                jmp	wsig
                pop	si
 thalt:		inc	dl
		jz	wsig
 dohalt:	inc	taskman.in_c
		sti
 stop:		jmp	stop
 comfail	db	'ATT. 2 ENTR BUSY DOS WHEN IN',0
 odl		db	'??',0
 incdl		db	'CRSECT.',0
 insintdl	db	'SINT.',0
 inhintdl	db	'HINT.',0
signal_deadlock	endp
		|
free_to_dos	proc
		push	ds si
		lds	si,dosflag
		cmp	word ptr [si-1],0
                pop	si ds
		ret
free_to_dos	endp
old_os		proc
		pushf
                cli		; ???????????????????????????????????????
		;cmp	indos_C,0
		;jnz	wfd
	nodc:	call	free_to_dos
		jz	call_dos
                call	switchallowed
                jnz	call_dos
	wfd:	push	ax
		mov	ax,DosOwner
		cmp	ax,taskman.activetask
		pop	ax
		jnz	gop1
		mov	indos_c,0
		call	unlockdos
                jmp	call_dos
		;---------------------------------
	gop1:	; по пункту 1.
		push	ax es di si ds
		movr	ds,cs
		lea	si,indos_queue
		mov	al,WAIT_FOR_DOS
		call	suspend
		;call	idle
		pop	ds si di es ax
                popf
		jmp	old_os
	singularf:
		;inc	indos_c
                call	lockdos
                push	ax
		mov	ax,taskman.activetask
                mov	DosOwner,ax
                pop	ax
		popf
		pushf
		cli
		call	dword ptr [old21]
		pushf
                call	unlockdos
                ;dec	indos_c
		;popf
		jmp	nodin
	call_dos:
		cmp	ah,59h
		jz	singularF
                cmp	ah,0ch
                jbe	singularF
                cmp	ah,6ch
                ja	singularF
		inc	indos_c
                call	lockdos
                push	ax
		mov	ax,taskman.activetask
                mov	DosOwner,ax
                pop	ax
		popf
		pushf
		cli
		call	dword ptr [old21]
		pushf
		;call	unlockdos
                ;cmp	indos_c,0
                ;jz	nodin
                ;dec	indos_C
	nodin:	cmp	indos_queue.cur_first,-1
		jne	doextract
		popf
		ret
 doextract:
		push	ds si es di ax
		mov	es,taskarea
		movr	ds,cs
		lea	si,indos_queue
		enterpcode
		call	release_queue
		leavepcode
                call	free_to_dos
                jne	norestart
		call	idle			; somebody ask for
						; resource, so give
						; him job
norestart:	pop	ax di es si ds
		popf
		ret
old_os		endp
		
jmp2dos:	popf
		jmp	dword ptr [old21]

msdos:          popf
		call	old_os
		sti
		retf	2

new21		proc
                pushf
		cmp	ready,0
                jz	jmp2dos
		call	penalty_proc
		push	ds si
		lds	si,dosflag
		cmp	byte ptr [si-1],0
		pop	si ds
		jne	jmp2dos
                cmp	taskman.privcode,0
                jne	jmp2dos
                cmp	taskman.sintlvl,0
                jne	jmp2dos
                cmp	taskman.in_c,0
		jne	jmp2dos
                sti
		cmp	ah,50h
                jz	jmp2dos
		cmp	ah,51h
                jz	jmp2dos
		cmp	ah,62h
                jz	jmp2dos
                cmp	ah,64h
                jz	jmp2dos
                cmp	ah,33h
                jz	jmp2dos
 		cmp	ah,0ch
		ja	somehi
		jmp	lowfunct
	somehi:
		cmp	ah,40h
                jne	readfromdev
		call	isitdiskfile
                je	msdos
		jcxz	msdos
                ; посимвольный вывод
		popf
                sti
                push	ds dx cx
 singleout:     mov	ah,40h
                push	cx
                mov	cx,1
                call	old_os
                jc	sberr
                cmp	ax,cx
                jne	sberrx
                pop	cx
                inc	dx
                loop	singleout
                pop	cx dx ds
                mov	ax,cx
                clc
		retf	2

   sberr:	pop	cx cx dx ds
		retf	2	; просто в ax код ошибки

   sberrx:	pop	cx	; сколько осталось писать
		pop	ax	; столько хотели писать
                push	ax
                sub	ax,cx	; столько смогли написать
                pop	cx	; изначальное cx
                pop	dx ds
                clc
                retf	2	; видимо нет места на устройстве
                                              
 readfromdev:	cmp	ah,3fh
		je	rfdev1
                jmp	msdos
	rfdev1:	call	IsItDiskFile
		jne	rfdev2
                jmp	msdos
	rfdev2:	
		call	isitcon
                jz	dorfdev
		call	isitnuldev
		jnz	dorfdev
		jmp	msdos
	dorfdev:popf
                sti
		push	bx cx dx di si ds es bp
		mov	bp,sp			; save sp
		mov	di,dx
		push	ds
		pop	es
		cmp	cx,80h
		jb	uselowc
		mov	cx,80h
	uselowc:
		mov	ax,cx
		add	ax,2
		sub	sp,ax			; give frame for buff
		push	ss
		pop	ds
		mov	dx,sp
		mov	si,sp
		mov	byte ptr [si],cl
		dec	byte ptr [si]
		mov	byte ptr [si+1],0
		push	cx
		push	bp
		call	bufinp
		pop	bp
		push	bx
		mov	bx,1
		mov	al,0ah
		call	doecho
		pop	bx
		pop	cx
		push	ax
		xor	ax,ax		;
		mov	al,[si+1]	;
                add	ax,2
		cmp	ax,cx
                jbe	gotless
                mov	ax,cx
	gotless:mov	cx,ax
                pop	ax
		xor	bx,bx
		mov	bl,[si+1]
		mov	word ptr [si+bx+2],0a0dh
		mov	ax,cx	;bx
		sub	ax,2
		add	si,2
		cld
		push	si
		rep	movsb
		pop	si
		add	ax,2
		cmp	byte ptr [si],01ah
		jne	noCtrlZ
		xor	ax,ax
 NoctrlZ:	mov	sp,bp
		pop	bp es ds si di dx cx bx
		clc
		sti
		retf	2
		;jmp	retfrom21
lowfunct:       popf
		push	bx
		;xor	bx,bx
		;mov	bl,ah
		;shl	bx,1
		;jmp	word ptr funcs[bx]
		switch	ah,fnums,funcs
term:
		pop	bx
                mov	ax,4c00h
                call	old_os
		;jmp	msdos
kbdin:
		xor	bx,bx
		call	doinp
		cmp	al,3
		je	kbcbrk
		mov	bx,1
		call	doecho
		jmp	retfrom21

	kbcbrk:
		mov	bx,1
		call	cbrk
		jmp	kbdin
dsplch:		; char to out in dl
		mov	bx,1
       genout:
		push	ds cx ax
		push	dx
		push	ss
		pop	ds
		mov	dx,sp
		mov	ah,40h
		mov	cx,1
		call	old_os
		pop	dx
		pop	ax cx ds
		jmp	retfrom21

auxinp:         mov	bx,3
		call	isitdiskfile
		jnz	nostdiffa
		pop	bx
                pushf
		jmp	msdos
 nostdiffa:	
		call	stdinput
		cmp	al,3
		jne	ncbrk
		call	cbrk
                jmp	auxinp
	ncbrk:
		call	doecho
		jmp	retfrom21

auxout:		mov	bx,3
		jmp	genout

prnout:		mov	bx,4
		jmp	genout

conio:		cmp	dl,0ffh
		je	inreq
		mov	bx,1
		jmp	genout
	inreq:
		push	ax
		xor	bx,bx
		call	isitdiskfile
		jnz	incnof
		pop	ax
		pop	bx
                pushf
		jmp	msdos
	incnof:	push	dx
		call	getdevinfo
		push	dx
                ;call	lock_con
        	call	forcebinmod
		mov	ax,4406h
		call	old_os
		pop	dx
		call	setdevinfo
                ;call	unlock_con
		pop	dx
		or	al,al
		pop	ax
		jnz	datar
		mov	ax,0600h
                jmp	retfrom21
	datar:	
		push	dx
		call	getdevinfo
		push	dx
                ;call	lock_con
		call	forcebinmod
		push	ds dx cx
		xor	bx,bx
		mov	ah,3fh
		mov	cx,1
		push	ax
		push	ss
		pop	ds
		mov	dx,sp
		call	old_os
		pop	ax
		pop	cx dx ds
		pop	dx
		call	setdevinfo
                ;call	unlock_con
		pop	dx
		or	ah,ah
		jmp	retfrom21
noehunfinp:
		xor	bx,bx
		call	doinp
		;call	stdinput
		jmp	retfrom21
noechinp:
		xor	bx,bx
		call	doinp
		;call	stdinput
		cmp	al,3
		je	cbrk8
		jmp	retfrom21
	cbrk8:
		call	cbrk
                jmp	noechinp
dsplstr:	push	ax cx si dx
		mov	si,dx
	dspll:	lodsb
		cmp	al,'$'
		je	strgprinted
		push	ds
		push	ax
		movr	ds,ss
		mov	dx,sp
		mov	cx,1
		mov	bx,1
		mov	ah,40h
		call	old_os
		pop	ax
		pop	ds
		int	28h
		jmp	dspll
 strgprinted:	pop	dx si cx ax
		jmp	retfrom21

bufrdinp:
		push	bx
		xor	bx,bx
		call	IsItDiskFile
		jz	biff
		call	bufinp
		pop	bx
		jmp	retfrom21
  biff:		call	old_os
		pop	bx
		jmp	retfrom21
instatus:
		xor	bx,bx
		mov	ax,4406h
		call	old_os
                jc	nostdinh
		mov	ah,0bh
		jmp	retfrom21
nostdinh:	mov	ax,0b00h
		jmp	retfrom21
clrinp:
		push	bx
		xor	bx,bx
		call	isitdiskfile
		pop	bx
		jne	clrdrv
		call	old_os
		jmp	retfrom21
	clrdrv:
		push	ax
		xor	bx,bx
		push	dx
                call	getdevinfo
		push	dx
                ;call	lock_con
		call	forcebinmod
     clrloop:
                mov	ah,0bh
                pushf
                push	cs
                call	new21
		or	al,al
		jz	empty
         rtw:   call	stdinput
                or	al,al
                jz	rtw
		jmp	clrloop
	empty:	pop	dx
		call	setdevinfo
                ;call	unlock_con
		pop	dx
		pop	ax
		or	al,al
		jz	clrid
		mov	ah,al
		pushf
                push	cs
                call	new21
		mov	ah,0ch
	clrid:	jmp	retfrom21
retfrom21:
		pop	bx
		sti
		retf	2
new21		endp
rstrdrvstat	proc
		push	ax dx
		mov	ax,4401h
		mov	dx,[bp].drvstat
		xor	dh,dh
		call	old_os
		pop	dx ax
		ret
rstrdrvstat	endp

bufinp		proc
		push	bp ax bx cx dx di si ds es
		push	bx			; save handle
		xor	ax,ax
		mov	bx,dx
		mov	al,[bx]			; ax = leng
		cmp	al,80h
		jbe	nle
		mov	al,80h
	nle:	pop	bx			; restore handle
		sub	sp,ax			; get string buf
		mov	cx,sp
		sub	sp,size edline
		mov	bp,sp
		mov	[bp].insmode,0
		mov	[bp].cnt,0
		mov	[bp].diff,0
		mov	[bp].bufbeg,cx
		mov	[bp].buflen,ax
		mov	si,dx
		mov	di,dx
		call	tmpl2buf
		inc	si
                inc	si
		mov	byte ptr [di+1],0
		;push	ax dx
		;mov	ax,4400h
		;call	old_os
		;mov	[bp].drvstat,dx		; save old driver state
		;call	forcebinmod
		;pop	dx ax
	edwait:
		push	bp
		call	stdinput
                pop	bp
		or	al,al
		jnz	nofkey
		jmp	fkey
	nofkey:
		cmp	al,8
		jne	noleft
		jmp	doleft
	noleft:
		cmp	al,127
		jne	noRUB
		jmp	doleft
	noRUB:
		cmp	al,27
		je	doesc
		cmp	al,13
		je	doenter
		cmp	al,3
		jne	noCtrlC
		mov	al,'^'
		push	bx
		mov	bx,1
		call	doecho
		mov	al,'C'
		call	doecho
		pop	bx
		;call	rstrdrvstat
		mov	ax,[bp].buflen
		add	ax,size edline
		add	sp,ax
		pop	es ds si di dx cx bx ax bp
		add	sp,2
		clc
		int	23h
		jc	aborttask
		pop	bx
		jmp	new21
	aborttask:
		mov	ax,4c00h
		int	21h
	noctrlc:
		jmp	normchar
	doesc:	mov	al,'\'
		push	bx
		mov	bx,1
		call	doecho
		mov	al,13
		call	doecho
		mov	al,10
		call	doecho
		pop	bx
		mov	si,di
		add	si,2
		mov	[bp].insmode,0
		mov	[bp].cnt,0
		mov	[bp].diff,0
		mov	byte ptr [di+1],0
		jmp	edwait
	doenter:
		push	bx
                mov	bx,1
		call	doecho
		pop	bx
		mov	byte ptr [si],al		;13
		;call	rstrdrvstat
		mov	ax,[bp].buflen
		add	ax,size edline
		add	sp,ax
		pop	es ds si di dx cx bx ax bp
		ret
	normchar:
		call	putcharbuf
		jmp	edwait
	fkey:
		call	stdinput
		cmp	al,scanins
		je	doins
		cmp	al,scanf5
		jne	nof5
		jmp	dof5
	nof5:
		cmp	al,scanf3
		jne	nof3
		jmp	dof3
	nof3:
		cmp	al,scanleft
		je	doleft
		cmp	al,scanrght
		jne	tnk1
		jmp	doright
tnk1:		cmp	al,scandel
		je	dodel
		jmp	edwait
	doins:
		mov	[bp].insmode,1
		jmp	edwait
	dodel:
		sub	[bp].diff,1
		jmp	edwait
	doleft:
		mov	[bp].insmode,0
		cmp	[bp].cnt,0
		jne	movlef
		mov	[bp].diff,0
		jmp	edwait
	movlef:	cmp	byte ptr [si-1],9
		jne	notabbs
		push	dx si
		mov	cx,si
		sub	cx,di
		sub	cx,3
		mov	si,di
		add	si,2
		xor	dx,dx
		jcxz	ppcnd
ppcount:
		lodsb
		cmp	al,9
		jne	notc
		mov	ax,dx
		and	ax,7
		add	dx,8
		sub	dx,ax
		loop	ppcount
		jmp	ppcnd
	notc:
		cmp	al,20h
		jae	nocc
		inc	dx
	nocc:	inc	dx
		loop	ppcount
	ppcnd:
		pop	si
		and	dx,7
		mov	cx,8
		sub	cx,dx
		sub	[bp].cnt,cl
deltabloop:	call	dobs
		loop	deltabloop
		pop	dx
		jmp	dodecsi
	notabbs:
		call	dobs
		dec	[bp].cnt
		cmp	byte ptr [si-1],20h
		jae	dodecsi
		call	dobs
		dec	[bp].cnt
	dodecsi:
		dec	si
		dec	byte ptr [di+1]
		jmp	edwait
	doright:
		call	crt
		jmp	edwait
	dof5:
		mov	al,'@'
		push	bx
                mov	bx,1
		call	doecho
		mov	al,13
		call	doecho
		mov	al,10
		call	doecho
		pop	bx
		call	tmpl2buf
		mov	si,di
		inc	si
		inc	si
		mov	[bp].cnt,0
		mov	[bp].diff,0
		mov	byte ptr [di+1],0
		jmp	edwait
	dof3:
		push	bx
		mov	bx,[bp].bufbeg
		xor	cx,cx
		mov	cl,ss:[bx+1]
		sub	cl,[di+1]
		pop	bx
		jc	nmr
		jcxz	nmr
	showtmpl:call	crt
		loop	showtmpl
	nmr:
		jmp	edwait
bufinp		endp
crt		proc
		mov	[bp].insmode,0
		mov	ax,si
		sub	ax,di
		sub	ax,2
		push	bx
		mov	bx,[bp].bufbeg
		sub	ax,[bp].diff
		cmp	al,ss:[bx+1]
		pop	bx
		jb	movright
		ret
	movright:
		call	fromtmpl
		mov	[si],al
		call	typechar
		inc	si
		inc	byte ptr [di+1]
		ret
crt		endp
tmpl2buf	proc
		; ds:dx -> editing buf
		push	si di es cx
		mov	si,di
		push	ss
		pop	es
		mov	di,[bp].bufbeg
		mov	cx,[bp].buflen
		cld
		rep	movsb
		pop	cx es di si
		ret
tmpl2buf	endp
fromtmpl	proc
		push	bx
		mov	bx,[bp].bufbeg
		add	bx,si
		sub	bx,di
		sub	bx,[bp].diff
		mov	al,ss:[bx]
		pop	bx
		ret
fromtmpl	endp
buf2tmpl	proc
		; ds:dx -> editing buf
		push	si di es cx
		mov	di,dx
		push	ss
		pop	ds
		mov	si,[bp].bufbeg
		mov	cx,[bp].buflen
		cld
		rep	movsb
		pop	cx es di si
		ret
buf2tmpl	endp
putcharbuf	proc
		cmp	[bp].insmode,1
		je	inschar
		mov	dl,al
		mov	[si],al
		mov	ax,si
		sub	ax,di
		sub	ax,2
		cmp	al,[di]			; cmp with maxlen
		jae	fullbuf1
		cmp	al,[di+1]		; cmp with curlen
		mov	al,dl
		pushf
		push	bx
		mov	bx,1
		call	typechar
		pop	bx
		popf
		jb	noover
		inc	byte ptr [di+1]
	noover:                	
		inc	si
		ret
	fullbuf1:
		jmp	fullbuf
	inschar:
		mov	[si],al
		inc	byte ptr [di+1]		; inc curr leng
		call	typechar
		inc	[bp].diff
		inc	si			; inc curr ptr
		ret
	fullbuf:
		mov	al,7
		call	doecho
		ret
putcharbuf	endp
typechar	proc
		push	ax
		cmp	al,20h
		jae	normch
		cmp	al,9
		je	puttab
		push	ax
		mov	al,'^'
		call	doecho
		inc	[bp].cnt
		pop	ax
		add	al,'@'
	normch:
		call	doecho
		inc	[bp].cnt
		pop	ax
		ret
	puttab:
		xor	ax,ax
		mov	al,[bp].cnt
		and	al,7
		mov	cx,8
		sub	cx,ax
		mov	al,20h
		add	[bp].cnt,cl
pltabloop:	call	doecho
		loop	pltabloop
		pop	ax
		ret
typechar	endp
dobs		proc
		mov	al,8
		call	doecho
		mov	al,20h
		call	doecho
		mov	al,8
		call	doecho
		ret
dobs		endp
stdinput	proc
		push	cx ds dx
	waitch: push	dx
		call	getdevinfo
		push	dx
                ;call	lock_con
		call	forcebinmod
		mov	ax,4406h
		push	bx
		call	old_os
		pop	bx
		or	al,al
		jnz	chrdy
		pop	dx
                call	setdevinfo
                ;call	unlock_con
		pop	dx
		int	28h
		call	idle
		jmp	waitch
	chrdy:
		mov	ah,3fh
		mov	cx,1
		push	ax		; give place in stack
		push	ss
		pop	ds
		mov	dx,sp		; write to top of stack
		call	old_os
		pop	ax
		pop	dx
                call	setdevinfo
                ;call	unlock_con
		pop	dx
		pop	dx ds cx
		ret
stdinput		endp
doinp		proc
		call	isitdiskfile
		jnz	nostdiffk
		add	sp,2
		pop	bx
                pushf
		jmp 	msdos
 nostdiffk:	;push	dx
		;call	getdevinfo
		;push	dx
		;call	forcebinmod
		call	stdinput
		;pop	dx
		;call	setdevinfo
		;pop	dx
		ret
doinp		endp
forcebinmod	proc
		push	ax dx
		xor	dh,dh
		or	dl,20h			; force binary mode
		mov	ax,4401h
		call	old_os
		pop	dx ax
		ret
forcebinmod	endp
con_busy	db	0
lock_con	proc
		;push	ax
		;mov	al,1
  w_con:        ;xchg	al,con_busy
                ;or	al,al
                ;jz	use_con	
		;push	es di si ds
		;movr	ds,cs
		;lea	si,conq
		;mov	al,WAIT_FOR_CON
		;call	suspend
		;pop	ds si di es
 use_con:       ;pop	ax
		;ret
lock_con	endp
unlock_con	proc
		;cmp	conq.cur_first,-1
		;je	relcon
		;push	ds si es di ax
		;mov	es,taskarea
		;movr	ds,cs
		;lea	si,conq
		;enterpcode
		;call	release_queue
		;mov	conq.cur_first,-1
                ;mov	conq.cur_last,-1
		;leavepcode
		;pop	ax di es si ds
relcon:		;mov	con_busy,0
		;ret
unlock_con	endp
setdevinfo	proc
		push	ax dx
		xor	dh,dh
		mov	ax,4401h
		call	old_os
		pop	dx ax
		ret
setdevinfo	endp
getdevinfo	proc
		push	ax
		mov	ax,4400h
		call	old_os
		pop	ax
		ret
getdevinfo	endp
doecho		proc
		push	ds dx cx bp
		mov	ah,40h
		mov	cx,1
		push	ax
		push	ss
		pop	ds
		mov	dx,sp
		push	bx
		call	old_os
		;pushf
		;call	dword ptr [old21]
		;int	21h
		pop	bx
		pop	ax
		pop	bp cx dx ds
		ret
doecho		endp
cbrk		proc
		push	bp ds
		mov	bp,sp
                movr	ds,ss
                int	23h
                movr	ss,ds
                mov	sp,bp
                pop	ds bp
                jnc	noabcbrk
		mov	al,'^'
		call	doecho
		mov	al,'C'
		call	doecho
		mov	ax,4c01h
		int	21h
 noabcbrk:	ret
cbrk		endp
penalty_proc	proc
		push	es di
		mov	es,taskarea
		mov	di,taskman.activetask
		cmp	es:[di].penalty,0
		je	no2switch
		call	switchallowed
		jne	no2switch
		cmp	taskman.privcode,0
		jne	no2switch
                cmp	taskman.sintlvl,0
                jne	no2switch
		pop	di es
		call	idle
		jmp	penalty_proc
	no2switch:
		pop	di es
		ret
penalty_proc	endp
IsItDiskFile	proc
		; return ZY if disk file
		push	ax dx
		;call	isitcon
                ;jz	nodisk
		mov	ax,4400h
		call	old_os
		test	dl,80h
		pop	dx ax
		ret
	nodisk:	clz
		pop	dx ax
                ret
IsItDiskFile	endp
isitcon		proc
		push	ax dx
		mov	ax,4400h
                call	old_os
                test	dl,03h
                jz	notcon
                cmp	al,al
		jmp	realcon
	notcon:clz
        realcon:pop	dx ax
		ret
isitcon		endp
isitnuldev	proc
		push	ax dx
		call	isitcon
                jz	notanul
		mov	ax,4400h
                call	old_os
                or	dl,0ch
                jz	notanul
                cmp	al,al
		jmp	realnul
	notanul:clz
        realnul:pop	dx ax
		ret
isitnuldev	endp
code		ends
		end
DEBUGMODE=1
SWITCHCODE      equ     0fh
TGFRESHCODE	equ	01h
code            segment public
		assume  cs:code,ds:nothing,es:nothing,ss:stckseg
include         cnmacro.inc
include         task.inc
extrn   testonmultitask:near,freemem:near,Systemanalys:near,is84Key:near
extrn   memoryallocate:near,new21:near,penalty_proc:near,isitat:near,convertword:near
extrn   tablecurins:near,viewobj:near,freememblock:near,xmspresent:near
extrn   setzblocksize:near,rstzblocksize:near,shrinkZblock:near
extrn   system:syst,case:near,createbarrier:near,isitcga:near,free_to_dos:near
extrn	setargv:near,search_free_int:near,isitega:near,zaddr1:word
extrn	zaddr2:word,zsize1:word,zsize2:word,mylastmcb:word

extrn   xmsdrvaddr:dword

extrn   _Restore:far,_Setup:far

extrn	penalty_proc:near

extrn   video:word,dosowner:word,barrier:word

extrn   DOblebord:byte,dosxlogo:byte,indos_c:byte

extrn	indos_queue:queue

public  taskman,taskarea,idle,dosflag,switchallowed,switchtask,old21,wword
public  suspend,release_queue,lockdos,unlockdos,mtrestore,irqbase,ready
		jmp     start
		org	0ah
emmlab		db	'UMMXXXX0'
t2dsc   tskdsc  <offset task2,seg task2,3>;offset dosvdio,seg dosvdio>
t3dsc   tskdsc  <offset task3,seg task3,3>
partitionsize	dw	3e80h
irqbase		db	50h
comspec		dw	commline,code
start:          mov     ax,stckseg
		mov     ss,ax
		mov     sp,offset eostck
		push    es bx
                call	search_comspec
		call    TestOnMultitask
		mov     ax,3548h
		int     21h
		cmp     word ptr es:[bx-4],'TM'
		jne     nomtdup
		cmp     word ptr es:[bx-2],'SA'
		jne     nomtdup
		lea     dx,Dupst
		push    cs
		pop     ds
		mov     ah,9
		int     21h
		mov     ax,4c01h
		int     21h
nomtdup:        pop     bx es
		call    FreeMem
		call    _Setup
		jnc     contw
		jmp     fn

 contw:         call	isitega
		jne	dtestlines
		mov	ax,1130h
                xor	bx,bx
                push	es bp ds
                int	10h
                pop	ds bp es
                cmp	dl,25
                jbe	dtestlines
                mov	dx,offset lerror
                movr	ds,cs
                mov	ah,9
                int	21h
                call	_restore
                mov	ax,4c00h
                int	21h
 dtestlines:
 		call	search_free_int
 parmloop:	call	setargv
		pushf
		push	ds dx
		jnc	chkkey
                jmp	nokeys
	chkkey:
		mov	si,dx
                cmp	byte ptr [si],'/'
                jne	nokeys
                inc	si
                or	byte ptr [si],20h
                cmp	byte ptr [si],'s'
                jne	nops
                call	buildpsize
		add	sp,6
                jmp	parmloop
	nops:	cmp	byte ptr [si],'v'
		jne	noirqv
                call	readirqbase
		add	sp,6
                jmp	parmloop
   noirqv:	cmp	byte ptr [si],'t'
		jne	noticks
		mov	al,[si+1]
		sub	al,30h
                or	al,al
                jz	noticks
		cmp	al,9
                ja	noticks
		mov	t2dsc.tsktcks,al
                mov	al,[si+3]
                sub	al,30h
                or	al,al
                jz	noticks
                cmp	al,9
                ja	noticks
                mov	t3dsc.tsktcks,al
                add	sp,6
                jmp	parmloop
   noticks:	cmp	byte ptr [si],'e'
		jne	nextparm
		mov	cs:emsdisabled,0
		jmp	eoparmloop
	nextparm:
	eoparmloop:
		add	sp,6
                jmp	parmloop
   nokeys:
		call    mtsetup
		mov     ax,partitionsize	;3e80=250K
                call	CreateBarrier	;create block that covers/not Z
                pop	dx ds
		popf
		jc	no1stcl
                ;build 1-st comndline
		mov	byte ptr compar1,2
                mov	word ptr compar1+1,'c/'
		movr	es,cs
		lea	di,cline1
                mov	si,dx
 bcl1:		lodsb
                or	al,al
                jz	no1stcl
                inc	byte ptr compar1
                stosb
                jmp	bcl1
 no1stcl:
		movr    es,cs
		mov     di,offset t2dsc
		call    addtask
		call    MakeNextFrontEnd
		mov     cx,5
idleloop:       call    idle
		loop    idleloop
		call    rstzblocksize
		call	setargv
                jc	no2ndcl
		;build 2-nd command line
		mov	byte ptr compar2,2
                mov	word ptr compar2+1,'c/'
		movr	es,cs
		lea	di,cline2
                mov	si,dx
 bcl2:		lodsb
                or	al,al
                jz	no2ndcl
                inc	byte ptr compar2
                stosb
                jmp	bcl2
 no2ndcl:
		movr    es,cs
		mov     di,offset t3dsc
		call    addtask
                ;call	waitall
                ;jmp	alldone
 main:          ; refresh screens
		call	chkrestart
		call    idle
		xor     si,si
		xor     di,di
		mov     es,video
		mov     cx,5
                ;test	freshallowed,1
                ;jz	frshd1
 freshscreen:   push    si
		mov     ds,taskarea
		mov     si,taskman.frontend
                call	textvmod
                jne	freshed
		mov     al,[si].taskid
		cmp     [si].tstate,ST_DEAD
		je	nxx
		cmp	[si].vidir,1
                ;je	nxx
	nxx:	pop     si
		je      freshed
		dec     al
		xor     ah,ah
		mov     bx,SCREENSIZE/16
		mul     bx
		mov     bx,screens
		add     ax,bx
		mov     ds,ax
		push    cx
		mov     cx,80*5
		cmp     infresh,1
		jb      dofresh
                cmp	swinprogr,0
                jz	dofresh
		pop     cx
		jmp     freshscreen
 dofresh:	call	isitcga
		jne	nocgafresh
		call	cgafresh
		jmp	freshd1
 nocgafresh:	rep     movsw
 freshd1: 	;mov     infresh,0
		pop     cx
 freshed:       loop    freshscreen
 frshd1:	mov     ds,taskarea
		xor     si,si
		cmp     [si+1*(size task)].taskid,0
		je	checktask2
                jmp	main
checktask2:	cmp     [si+2*(size task)].taskid,0
		je	alldone
                jmp	main
		;call   waitall
alldone:        xor	ax,ax
		mov	taskman.frontend,ax
		call	showfrontendscr
		call    mtrestore
		call    _Restore
	fn:     
		movr    ds,cs
		lea     dx,allisdone
		mov     ah,9
		int     21h
		mov     ax,4c00h
		int     21h
allisdone       db      13,10,'Back to DOS...',13,10,'$'
dorestart	db	0
textvmod		proc
                push	ax
		mov	al,[si].vmode
	rtvmo:	cmp	al,startmode
                pop	ax
		ret
textvmod	endp
textvmode	proc
                push	ax
		mov	al,es:[di].vmode
                jmp	rtvmo
textvmode	endp
chkrestart	proc
		cmp	dorestart,0
                jz	crd
                dec	dorestart
                push	ds si es di cx
                mov	ds,taskarea
                mov	si,size task
                cmp	[si].taskid,0	; if 0 this is free task descriptor
                je	restartthis
                add	si,size task
                cmp	[si].taskid,0
                jne	crd0
	restartthis:
		movr	es ds
                mov	di,si
                cld
                mov	cx,size task
                xor	al,al
                rep	stosb
                mov	ds,barrier
                push	word ptr ds:[3]
                push	ds
		movr	es,cs
                mov	di,offset t2dsc
		sub	si,size task
                jnz	run2nd
                mov	word ptr ds:[3],1
                jmp	run1st
        run2nd: mov	di,offset t3dsc
	run1st:	call	addtask
                pop	ds
                pop	word ptr ds:[3]
                call	makenextfrontend
	crd0:	pop	cx di es si ds	
	crd:	ret
chkrestart	endp
readirqbase	proc
		xor	ax,ax
                xor	bx,bx
		mov	cx,2
	xtrd:	inc	si
                mov	al,[si]
                call	ishexdig
                jnz	baddig
		;mov	bh,al
                push	cx
		mov	cl,4
                shl	bx,cl
                or	bl,al
                pop	cx
                loop	xtrd
                mov	irqbase,bl
  baddig:	ret
readirqbase	endp
ishexdig	proc
		cmp	al,'0'
                jc	noxdig
                cmp	al,'9'
                ja	hdig
		sub	al,'0'
                jmp	xdig
	hdig:	and	al,0ffh-20h
		cmp	al,'A'
                jb	noxdig
                cmp	al,'F'
                ja	noxdig
                sub	al,'A'-10
                cmp	al,0fh
                ja	noxdig
  xdig:		cmp	al,al
		ret
noxdig:		ret
ishexdig	endp
buildpsize	proc
		xor	ax,ax
                xor	bx,bx
	bps:	inc	si
		mov	bl,[si]
		sub	bl,30h
                jc	bpsd
		cmp	bl,9
                ja	illegald
		mov	cl,10
		mul	cl
                add	ax,bx
                jmp	bps
 illegald:	stc
		ret

 bpsd:		mov	cl,6
		shl	ax,cl
		mov	partitionsize,ax
		clc
		ret
buildpsize	endp

WaitForCGA	proc
		call	isitCGA
		jne	cgaok
		push	ax dx
		mov	dx,3dah
	waitcga:in	al,dx
		test	al,8
		jne	waitcga
                pop	dx ax
	cgaok:	ret
WaitForCGA	endp
cgafresh	proc
		push	dx
		mov	dx,3dah
 wretrce:	in	al,dx
		test	al,8
		jne	wretrce
                movsw
		loop	wretrce
		pop	dx
		ret
cgafresh	endp
LogoTxt		db	'=MSCREEN= v.1.0.19, I.Khasilev,2:467/3@FIDO, 2:467/2@FIDO, igor@petre.odessa.ua',13,10
		db	'ALT-TAB - another screen.',13,10
                db	'ALT-ESC - screen refresh off.',13,10,'$'
SayLogo		proc
		;movr	ds,cs
		lea	dx,logotxt
                call	dostype
                ;mov	ah,9
                ;int	21h
		ret
SayLogo		endp
task2           proc
		;enterpcode
		;mov    ax,cs:taskman.activetask
		;mov    cs:taskman.frontend,ax
		;leavepcode
		call	SayLogo
		mov     ax,4b00h
		lds	dx,dword ptr comspec
		movr    es,cs
		lea     bx,epb1
		int     21h
		ret
task2           endp
task3           proc
		call	SayLogo
		mov     ax,4b00h
		lds	dx,dword ptr comspec
		movr    es,cs
		lea     bx,epb2
		int     21h
		ret
task3           endp
search_comspec	proc
		push	es ds si di
		mov	es,ds:[2ch]		; mov es,seg env
		xor	di,di
		movr	ds,cs
	slop:	
		lea	si,comsp
		mov	cx,8
         mlop:  mov	al,es:[di]
                inc	di
                or	al,al
		jz	eoparm
                or	al,20h
                cmp	al,[si]
                jnz	srczer
                inc	si
                dec	cx
		cmp	cx,0
                jnz	mlop
                mov	word ptr comspec,  di
                mov	word ptr comspec+2,es
                jmp	scdone
	srczer:	mov	cx,-1
		xor	al,al
		repne	scasb
        eoparm:	cmp	byte ptr es:[di],0
		jne	slop
	scdone:	pop	di si ds es
		ret
search_comspec	endp
comsp		db	'comspec='
commline	db      '\command.com',0
compar1         db      0,0dh,0dh
 cline1		db	32 dup (0dh)
compar2         db      0,0dh,0dh
 cline2		db	32 dup (0dh)
epb1            dw      0
		dw      offset compar1,code
		dw      0,0h            ;5ch,code
		dw      0,0h            ;6ch,code
epb2            dw      0
		dw      offset compar2,code
		dw      0,0h            ;5ch,code
		dw      0,0h            ;6ch,code
;-------------------------------------------------
Ready		db	0
freshallowed	db	1
run_queue       queue   HIPRIO+1 dup (<>)
startmode	db	0
dosflag         dd      0
swaparea        dd      0
swaplen		dw	0
ldptr           dd      0
oldlastdrv      dd      0
lastdrv         dw      0
ldinc           dw      0
emsdisabled	db	1
Dupst           db      13,10,'mscreen is already running!',13,10,'$'
taskman         atman   <>
tregs           regiss  <>
dummyvec        dd      0
old10           dd      0
old13           dd      0
old14           dd      0
old15           dd      0
old16           dd      0
old1a           dd      0
old1b           dd      0
old21           dd      0
old25           dd      0
old26           dd      0
old28           dd      0
old2a           dd      0
old2f           dd      0
old33           dd      0
old48           dd      0
old5c           dd      0
old67           dd      0
old70           dd      0
old71           dd      0
old72           dd      0
old73           dd      0
old74           dd      0
old75           dd      0
old76           dd      0
old77           dd      0
Taskarea        dw      0
Stacks          dw      0
Screens         dw      0
mypsp           dw      0
idle            proc
		call    switchallowed
		jnz     idledone
                push	ax
		xor	ax,ax
		int     48h
		pop	ax
idledone:
		ret
idle            endp
waitno          proc
		; wait until specified task finished
		; input : ax - id of task for waiting
		; output: none
		push    es di
		mov     es,taskarea
		xor     ah,ah
		dec     ax
		mov     bx,size task            ;???
		mul     bx                      ;???
		mov     di,ax
	wdie:   cmp     es:[di].taskid,0
		jz      died
		call    idle
		jmp     wdie
died:           pop     di es
		ret
waitno          endp
waitall         proc
		; wait until all tasks finished
		; input : none
		; output: none
		push    es di
		mov     es,taskarea
	swaitall:
		xor     ax,ax
		mov     di,size task            ; start not from main task
		;enterpcode
	wallt:  or      al,es:[di].taskid
		add     di,size task
		cmp     di,(size task)*taskavail
		jb      wallt
		;leavepcode
		or      al,al
		jz      walld
		call    idle
		jmp     swaitall
	walld:
		pop     di es
		ret
waitall         endp
addtask         proc
		; add specified procedure to tasklist, allocate
		; all resources and put in run_queue
		; enter : ds:si - pointer to task external_descriptor
		; return: al - id of created task
		enterpcode
		mov     tregs.rax,ax
		mov     tregs.rbx,bx
		mov     tregs.rcx,cx
		mov     tregs.rdx,dx
		mov     tregs.rsi,si
		mov     tregs.rdi,di
		mov     tregs.rbp,bp
		mov     tregs.rsp,sp
		mov     tregs.rds,ds
		mov     tregs.res,es
		mov     tregs.rss,ss
		pushf
		pop     tregs.flgs
		movr    ds,es
		mov     si,di
		push    ds si
		call    createtask
		pop     si ds
		mov     al,[si].tsktcks
		mov     es:[di].ticks,al
		mov     es:[di].ltck,al
		push    ds si
		call    SaveTaskEnv
		push    es di                   ; a
		push    es                      ;  s
		pop     ds                      ;   s
		mov     dx,di                   ;    i
		;add     dx,offset curdta        ;     g
		;mov     word ptr es:[di].dta,dx  ;     n   a
		;mov     word ptr es:[di].dta+2,ds;        t
		pop     di es                   ;        d
		call    givestack
		pop     si ds
		mov     ax,[si].tskofs          ; ip
		mov     word ptr es:[di].tcsip,ax
		mov     ax,[si].tskseg          ; cs
		mov     word ptr es:[di].tcsip+2,ax
		mov     ax,[si].xtrnvdio
		mov     word ptr es:[di].extvidi,ax
		mov     ax,[si].xtrnvdis
		mov     word ptr es:[di].extvidi+2,ax
		mov     ax,[si].xtrnkbdo
		mov     word ptr es:[di].extkbd,ax
		mov     ax,[si].xtrnkbds
		mov     word ptr es:[di].extkbd+2,ax
		push    es di ds si
		mov     ah,3
		xor     bh,bh
                call	toold10
		;int     10h
		mov     es:[di].cshape,cx
                push	cx bp
                pop	bp cx
		pop     si ds di es
                mov	ah,startmode
		mov	es:[di].vmode,ah
		mov     al,[si].startprio
		mov     es:[di].prio,al
		call    put2run_Q
		mov     es:[di].tState,ST_RUN
		mov     al,es:[di].taskid
		leavepcode
		ret
addtask         endp
givestack       proc
		; allocate stack for task (internal procedure)
		; enter : di - pointer to task internal_descriptor
		; return: none, tss:tsp -> to start stack for task
		mov     ax,di
		xor     dx,dx
		mov     bx,size task
		div     bx                      ; get task num  
		xor     ah,ah
		dec     ax                      ; main task never
						; request stack !
		xor     dx,dx
		mov     bx,STACKFRAME
		mov     cl,4
		shr     bx,cl                   ; stackframe in PARA
		inc     bx                      ; for some case
		mul     bx
		mov     bx,Stacks
		add     ax,bx                   ; get seg of stack 
						; for this task
		mov     ds,ax
		mov     bx,STACKFRAME
		mov     es:[di].tss,ds
		mov     es:[di].tsp,bx
		mov     [bx],offset trap
		ret
givestack       endp
killmsg		db	7,'$'
isitpsp		proc
		push	bx
                mov	bx,ds
                inc	bx
                cmp	bx,ds:[1]	; psp if this mcb own himself
                pop	bx
		ret
isitpsp		endp
trapdostask:	; close all not closed files of this process
		; and all not closed files of all his parents
		mov	es,taskarea
                mov	di,taskman.activetask
                mov	es:[di].dying,0
                mov	bx,mylastmcb
                mov	ds,bx
  chknmcb:      add	bx,ds:[3]
                inc	bx
                mov	ds,bx		; ? not my mcb
		call	isitpsp
                jne	testiflast
                ; close files
		push	ds
                inc	bx
                mov	ah,50h
                int	21h
		mov	bx,20		; close only 20 files
   closeall:    mov	ah,3eh
		push	bx
                int	21h
                pop	bx
                dec	bx
                jnz	closeall
                pop	ds
	testiflast:
		cmp	ds:[0],byte ptr 'Z'
                jz	killingdone
                mov	bx,ds
                jmp	chknmcb
killingdone:                		
trap            proc
		; trap for finished task
		; task being marked as DEAD and will be removed from
		; tasklist on next switch
		; ret extract ip that addtask put into stack
		mov	di,taskman.activetask
		push	es ax
                mov	es,zaddr1
                mov	ax,zsize1
		cmp	di,size task
                je	ajustz
                ; kill 1st task
		mov	es,zaddr2
                mov	ax,zsize2
	ajustz:	mov	es:[0],byte ptr 'Z'
		mov	es:[1],word ptr 0
                mov	es:[3],word ptr ax        	
                pop	ax es
		mov     es,taskarea
		mov     di,taskman.activetask
		enterpcode
		mov     es:[di].taskid,0
		mov     es:[di].tstate,ST_DEAD
		leavepcode
		call    MakeNextFrontEnd
	ddlock: jmp     ddlock
;               call    idle
		ret
trap            endp
insint          proc
		; test if task in locked software interrupt
		; or dos is busy
		; input  : none
		; output : Z=1 if in int or dos bysy
		; destroy: nothing
		cmp     taskman.sintlvl,0
		jnz     isid
		push    ds si
		lds     si,dosflag
		cmp     byte ptr [si-1],0       ; critical error flag
		pop     si ds
isid:
		ret
insint          endp
inhint          proc
		; test if task in locked hardware interrupt
		; input  : none
		; output : Z=1 if in int
		; destroy: nothing
		cmp     taskman.hintlvl,0
		ret
inhint          endp
showstate       proc
		;push    ds si es ax
		;mov     es,video
		;mov     al,taskman.sintlvl
		;add     al,30h
		;mov     es:[102],al
		;mov     al,taskman.hintlvl
		;add     al,30h
		;mov     es:[104],al
		;mov     al,taskman.privcode
		;add     al,30h
		;mov     es:[106],al
		;lds     si,cs:dosflag
		;mov     al,[si]
		;add     al,30h
		;mov     es:[108],al
		;mov     ds,taskarea
		;mov     si,taskman.activetask
		;mov     al,[si].ltck
		;add     al,30h
		;mov     es:[110],al
		;mov     al,[si].tstate
		;mov     ah,[si].taskid
		;;call   wword
		;pop     ax es si ds
		;ret
showstate       endp
COMMENT		|
chprio          proc
		; change priority of selected task to value in al
		; input : al - new priority,di - task
		; output: NC and al=1 if success,else fail
		;         if al=0 then requested prio>hiprio
		cmp     al,HIPRIO
		ja      toohiprio
		push    es bx
		enterpcode
		mov     es,taskarea
		mov     es:[di].prio,al
		cmp     es:[di].tstate,ST_RUN
		je      succhprio
		mov     bl,size queue
		mul     bl
		mov     bx,ax
		movr    ds,cs
		lea     si,run_queue[bx]
		call    xtract
		mov     ax,di
		call    put2run_Q
 succhprio:     leavepcode
		pop     bx es
		mov     al,1
		clc
		ret
 toohiprio:     xor     al,al
		stc
		ret
chprio          endp
		|
release         proc    ; release previously holded task (ax)
		push    es di
		mov     di,ax
		mov     es,taskarea
		cmp     es:[di].tState,ST_HOLD
		jne     notinhold
		enterpcode
		mov     es:[di].tState,ST_RUN
		mov     es:[di].wait_for_what,0
		call    put2run_q
		leavepcode
notinhold:      pop     di es
		ret
release         endp
COMMENT		|
hold            proc    ; hold task (in ax)
		cmp     ax,taskman.activetask
		jnz     hold_inside
		push    es di                   ; hold currently active task
		mov     es,taskarea
		mov     di,ax
		mov     es:[di].tState,ST_HOLD
		pop     di es
		call    idle
		ret
 hold_inside:   push    ds si es di
		enterpcode
		mov     es,taskarea
		movr    ds,cs
		mov     di,ax
		lea     si,run_queue
		call    correct_si_for_prio
		call    xtract
		mov     es:[di].tState,ST_HOLD
		leavepcode
		pop     di es si ds
		ret
hold            endp
		|
enterc          proc
		; enter critical code
		; input  : none
		; destroy: nothing
		pushf
		inc     taskman.in_c
		popf
		ret
enterc          endp
leavec          proc
		; leave critical code
		; input  : none
		; destroy: nothing
		pushf
		dec     taskman.in_c
		popf
		ret
leavec          endp
COMMENT		|
catch_r         proc
		; get resource or wait until resource will be free
		; input  : ds:si resource descriptor
		; output : nothing
		; destroy: nothing
		push    ax es di
 testrc:        mov     al,1
		xchg    [si].rflag,al
		or      al,al
		jz      catched
		push    si
		lea     si,[si].rqueue
		mov     al,WAIT_FOR_RESOURCE
		call    suspend
		pop     si
		jmp     testrc
 catched:       
		push	ds bx
                mov	ds,taskarea
                mov	bx,taskman.activetask
                inc	[bx].resources_owned
                pop	bx ds
		pop     di es ax
		ret
catch_r         endp
		|
suspend         proc                    
		; suspend active task, place in ds:si queue if task is
		; not dying (else suspend but save dying state)
		; save al in WAIT_FOR_WHAT field
 go_suspend:
		enterpcode
		mov     di,taskman.activetask
		mov     es,taskarea
		mov     es:[di].tState,ST_WAIT
		mov     es:[di].waitfor,si
		mov     es:[di].waitfor+2,ds
		mov     es:[di].wait_for_what,al
		mov     ax,di
		call    to_end_Q
		leavepcode
		call    idle
		ret
suspend         endp
comment		|
release_r       proc
		; release resource, release queue of tasks waiting
		; for this resource, switch if somebody waits for
		; this resource
		; input  : ds:si resource descriptor
		; output : nothing
		; destroy: nothing
		push	ds bx
                mov	ds,taskarea
                mov	bx,taskman.activetask
                dec	[bx].resources_owned
                pop	bx ds
		cmp     [si].rqueue.cur_first,-1
		jne     doextract
		mov     [si].rflag,0
		ret
 doextract:     
		push    es si
		lea     si,[si].rqueue
		enterpcode
		call    release_queue
		pop     si es
		mov     [si].rflag,0
		mov     [si].rqueue.cur_first,-1
		mov     [si].rqueue.cur_last,-1
		leavepcode
		call    idle                    ; somebody ask for this
						; resource, so give
						; him job
		ret
release_r       endp
		|
release_queue   proc
		; move all tasks from queue ds:si
		; to run_queue
		; input : ds:si -> queue
		; output: none
		push    es di
		mov     es,taskarea
 frrloop:       call    Take_1st
		cmp     di,-1
		je      rqfree
		;cmp    es:[di].tState,ST_WAIT
                mov     es:[di].tState,ST_RUN
		mov     es:[di].wait_for_what,0
		call    put2run_Q
		jmp     frrloop
 rqfree:        pop     di es
		ret
release_queue   endp
put2run_Q       proc
		; place task to run_queue
		; input : ax
		; output: none
		push    ds si ax
		movr    ds,cs
		lea     si,run_queue
		mov     ax,di
		call    to_end_PQ
		pop     ax si ds
		ret
put2run_Q       endp
correct_si_for_prio     proc
		push    ax
		mov     ax,HIPRIO
		sub     al,es:[di].prio
		mov     bl,size queue
		mul     bl
		add     si,ax
		pop     ax
		ret
correct_si_for_prio     endp
to_end_PQ       proc    ; ax-process, that will be last,ds:si - *queue
			; place process to end of PRIORITIZED queue
			; returns nothing
		push    es bx di si
		mov     di,ax
		pushf
		mov     es,taskarea
		call    correct_si_for_prio
		mov     bx,[si].cur_last
		cmp     bx,-1
		jz      Paddfrst
		mov     [si].cur_last,ax
		mov     es:[bx].tNext,ax        ; set next in old last
		mov     es:[di].tPrev,bx        ; set prev in new last
		jmp     short Pqnemp1
 Paddfrst:      mov     [si].cur_first,ax
		mov     [si].cur_last,ax
 PQNEMP1:       popf
		pop     si di bx es
		ret
to_end_PQ       endp
to_end_Q        proc    ; ax-process, that will be last,ds:si - *queue
			; place process in end of queue
			; returns nothing
		push    es bx di
		mov     di,ax
		pushf
		mov     es,taskarea
		mov     bx,[si].cur_last
		cmp     bx,-1
		jz      addfrst
		mov     [si].cur_last,ax
		mov     es:[bx].tNext,ax        ; set next in old last
		mov     es:[di].tPrev,bx        ; set prev in new last
		jmp     short qnemp1
 addfrst:       mov     [si].cur_first,ax
		mov     [si].cur_last,ax
 QNEMP1:        popf
		pop     di bx es
		ret
to_end_Q        endp
xtract          proc    ; ds:si -*queue
			;    exctract task [di] from queue
			; returns nothing
		push    ax bx es
		mov     es,taskarea
		cmp     di,[si].cur_first
		jz      xtr1st
		cmp     di,[si].cur_last
		jz      xtrlst
		mov     bx,es:[di].tPrev
		mov     ax,es:[di].tNext
		mov     es:[bx].tNext,ax
		jmp     short xtdone
 xtr1st:        call    take_1st
		jmp     xtdone
 xtrlst:        mov     bx,es:[di].tPrev        ; xtract last (but not single)
		mov     [si].cur_last,bx
 xtdone:        pop     es bx ax
		ret
xtract          endp
Take_1st        proc    ; ds:si - *queue
			; extract (exclude) first task from queue,
			; place next as first
			; returns di - extracted first element
		push    ax es
		pushf
		mov     di,[si].cur_first
		cmp     di,[si].cur_last
		jz      xtrctlast
		mov     ax,es:[di].tNext
		mov     [si].cur_first,ax
		jmp     short xtrctd
 xtrctlast:     mov     ax,-1
		mov     [si].cur_first,ax
		mov     [si].cur_last,ax
 xtrctd:        popf
		pop     es ax
		ret
Take_1st                endp
;--------------------------------------
;---------- TO FLAGS SPECIFIC ---------
;--------------------------------------
COMMENT		|
setflag         proc
		; set   flag to 1
		; release all tasks waiting for this flag
		; ds:si points to flag structure
		push    ds si es di
		enterpcode
		mov     [si].value,1
		cmp     [si].ftaskfirst,-1
		je      nobodywaitflag
		lea     si,[si].ftaskfirst
		call    release_queue
 nobodywaitflag:
		leavepcode
		pop     di es si ds
		ret
setflag         endp
waitflag        proc
		; waiting until flag will be set
		; input : ds:si -> flag structure
		test    [si].value,0ffh
		jnz     flast
		push    es di
		mov     es,taskarea
		mov     di,taskman.activetask
		enterpcode
		;call   xtract
		mov     es:[di].tState,ST_WAIT
		mov     es:[di].waitfor,si
		mov     es:[di].waitfor+2,ds
		mov     es:[di].wait_for_what,WAIT_FOR_FLAG
		mov     ax,di
		push    ds si
		lea     si,[si].ftaskfirst
		call    to_end_Q                ; enqueue this process
		pop     si ds di es
		leavepcode
		call    idle
		jmp     waitflag
	flast:  ret
waitflag        endp
testflag        proc
		test    [si].value,0ffh
		ret
testflag        endp
clearflag       proc
		mov     [si].value,0
		ret
clearflag       endp
;--------------------------------------
;------- TO MAIL BOXES SPECIFIC -------
;--------------------------------------

pack_msg        proc    ; put msg to envelope
			; when enter:
			;       ds:si -> body
			;       es:di -> envelope
			; when return:
			;       none
		push    ax
		mov     word ptr es:[di].msg,  si
		mov     word ptr es:[di].msg+2,ds
		mov     ax,taskman.activetask
		mov     es:[di].from_pid,ax
		xor     ax,ax
		mov     word ptr es:[di].env_nxt,ax
		mov     word ptr es:[di].env_nxt+2,ax
		mov     word ptr es:[di].env_prv,ax
		mov     word ptr es:[di].env_prv+2,ax
		pop     ax
		ret
pack_msg        endp
not_in_box      proc    ; tell if envelope(es:di) extracted from box 
			; (if not you can not pack any msg to envelope)
		push    ax
		mov     ax,word ptr es:[di].env_nxt
		or      ax,word ptr es:[di].env_nxt+2
		or      ax,word ptr es:[di].env_prv
		or      ax,word ptr es:[di].env_prv+2
		pop     ax
		ret
not_in_box      endp
box_empty       proc    ; tell if mailbox is empty
		push    ax
		mov     ax,word ptr [si].env_first
		or      ax,word ptr [si].env_first+2
		pop     ax
		ret
box_empty       endp
send_msg        proc    ; put msg(in envelope) to mailbox
			;       when enter
			;               ds:si -> envelope
			;               es:di -> mailbox
			;       when return:
			;               none
		enterpcode
		push    es di ds si
		push    es di
		les     di,es:[di].env_last
		mov     ax,es
		or      ax,di
		jz      put2empty_box
		mov     word ptr es:[di].env_nxt,  si
		mov     word ptr es:[di].env_nxt+2,ds
		mov     word ptr ds:[si].env_prv,  di
		mov     word ptr ds:[si].env_prv+2,es
		pop     di es
		mov     word ptr es:[di].env_last,  si
		mov     word ptr es:[di].env_last+2,ds
		jmp     short whoW4mail
 put2empty_box: 
		pop     di es
		mov     word ptr es:[di].env_first,  si
		mov     word ptr es:[di].env_first+2,ds
		mov     word ptr es:[di].env_last,   si
		mov     word ptr es:[di].env_last+2, ds
		mov     ax,-1
		mov     word ptr [si].env_prv,  ax      ; mark that envelope
		mov     word ptr [si].env_prv+2,ax      ; is in box
		mov     word ptr [si].env_nxt,  ax      ; mark that envelope
		mov     word ptr [si].env_nxt+2,ax      ; is in box
 whoW4mail:     ; release queue waiting for mail(meal)
		movr    ds,es
		lea     si,[di].wait_first
		call    release_queue
		pop     si ds di es
		leavepcode
		ret
send_msg        endp
isitlastmsg     proc    ; test if env@es:di is last in box@ds:si
		push    ax
		cmp     di,word ptr [si].env_last
		jnz     lmsgt
		mov     ax,es
		cmp     ax,word ptr [si].env_last+2
 lmsgt:         pop     ax
		ret
isitlastmsg     endp
isitfrstmsg     proc    ; test if env@es:di is first in box@ds:si
		push    ax
		cmp     di,word ptr [si].env_first
		jnz     fmsgt
		mov     ax,es
		cmp     ax,word ptr [si].env_first+2
 fmsgt:         pop     ax
		ret
isitfrstmsg     endp
wait_mail       proc    ; wait mail (not from this process)
			; when enter
			;       ds:si -> mailbox
			; when return
			;       es:di -> envelope of received msg
		push    ax
 wmail_loop:    les     di,[si].env_first
		mov     ax,es
		or      ax,di
		jnz     mreceived
		enterpcode
 boxempty:      mov     es,taskarea
		mov     di,taskman.activetask
		;call   xtract
		mov     es:[di].tState,ST_WAIT
		mov     ax,di
		push    ds si
		lea     si,[si].wait_first
		call    to_end_Q                ; enqueue this process
		pop     si ds
		leavepcode
		call    idle
		;push   es
		;mov    es,video
		;inc    byte ptr es:82
		;pop    es
		jmp     wmail_loop
mreceived:      enterpcode
		les     di,[si].env_first
 testmsg:       call    can_I_take_it
		jz      takethis
		call    isitlastmsg
		jz      boxempty
		les     di,es:[di].env_nxt
		jmp     testmsg
 takethis:      call    extract_msg
		leavepcode
		pop     ax
		ret
wait_mail       endp
extract_msg     proc
		call    isitlastmsg
		jz      xlmsg
		call    isitfrstmsg
		jz      xfmsg
		push    ax bx es di
		mov     ax,word ptr es:[di].env_nxt
		mov     bx,word ptr es:[di].env_nxt+2
		les     di,es:[di].env_prv
		mov     word ptr es:[di].env_nxt,ax
		mov     word ptr es:[di].env_nxt+2,bx
		push    ax
		mov     ax,es ;\
		mov     es,bx ;- = xchg es,bx
		mov     bx,ax ;/
		pop     ax
		xchg    di,ax
		mov     word ptr es:[di].env_prv,ax
		mov     word ptr es:[di].env_prv+2,bx
		pop     di es bx ax
		jmp     free_envelope
 xlmsg:         call    isitfrstmsg
		jz      xsngle
		push    es di
		les     di,es:[di].env_prv
		mov     word ptr [si].env_last,di
		mov     word ptr [si].env_last+2,es
		pop     di es
		jmp     free_envelope
 xfmsg:         ;call   isitlastmsg
		;jz     xsngle
		push    es di
		les     di,es:[di].env_nxt
		mov     word ptr [si].env_first,di
		mov     word ptr [si].env_first+2,es
		pop     di es
		jmp     free_envelope
 xsngle:        push    ax
		xor     ax,ax
		mov     word ptr [si].env_first,  ax
		mov     word ptr [si].env_first+2,ax
		mov     word ptr [si].env_last  ,ax
		mov     word ptr [si].env_last+2,ax
		pop     ax
 free_envelope: push    ax
		xor     ax,ax
		mov     word ptr es:[di].env_nxt,ax
		mov     word ptr es:[di].env_nxt+2,ax
		mov     word ptr es:[di].env_prv,ax
		mov     word ptr es:[di].env_prv+2,ax
		pop     ax
		ret
extract_msg     endp
can_I_take_it   proc
		mov     ax,taskman.activetask
		cmp     ax,es:[di].from_pid     ; is this msg from me?
		jz      UcanNot
		cmp     al,al
		ret
UCanNot:        xor     ax,ax
		inc     ax
		ret
can_I_take_it   endp
		|
;________________________________________________
new8            proc
		;call    show8259
		;call    showstate
                ;inc	taskman.in_c
		push	ds ax
		xor	ax,ax
                mov	ds,ax
                in	al,21h
                ;push	ax
		inc	taskman.sintlvl
		pushf
                call	dword ptr ds:[4*8]
                dec	taskman.sintlvl
                ;pop	ax
                out	21h,al
		;int     8
                pop	ax ds
		push	ax
		mov	al,0bh
		out	20h,al
		jmp	$+2
		jmp	$+2
                jmp	$+2
		in	al,20h
		or	al,al
		pop	ax
		jnz	skipany
                ;dec	taskman.in_c
		cmp     taskman.privcode,0
		jnz     skipany
		cmp     taskman.in_c,0
		jne	skipany
                ;cmp	indos_c,0
		;jne     skipany
		enterpcode
		sti
		push    es di
		mov     es,taskarea
		mov     di,taskman.activetask
		dec     es:[di].ltck
		pop     di es
		jz      testswitch
		leavepcode
		iret
	skip0:  ; switch requested but not allowed
		push    es di
		mov     es,taskarea
		mov     di,taskman.activetask
		mov     es:[di].ltck,1
                inc	es:[di].penalty
                cmp	es:[di].penalty,80h
                jbe	pok
                dec	es:[di].penalty
	pok:    pop     di es
		leavepcode
	skipany:
		sti
                call	processswitch
		iret

	testswitch:
		;call   showstate
		call    switchallowed
		jnz     skip0
	switchtask:
		mov     tregs.rax,ax
		mov     tregs.rbx,bx
		mov     tregs.rcx,cx
		mov     tregs.rdx,dx
		mov     tregs.rsi,si
		mov     tregs.rdi,di
		mov     tregs.rbp,bp
		pop     tregs.rip
		pop     tregs.rcs
		pop     tregs.flgs
		mov     tregs.rsp,sp
		mov     tregs.rds,ds
		mov     tregs.res,es
		mov     tregs.rss,ss
		mov     di,taskman.activetask
		mov     es,taskarea
		mov     al,es:[di].ticks
		mov     es:[di].ltck,al
		call    savetaskenv
	getn:	call    getnexttask             ; es:di <- next ready task
		cmp	es:[di].penalty,0
		jz	runthis
                mov	al,es:[di].ticks
                sub	es:[di].penalty,al
                jnc	getn
                mov	es:[di].penalty,0
                jmp	getn
	runthis:
		mov     ax,taskman.activetask   ; set it as active
		call    rstrtaskenv             ; restore its environment
		mov     ax,tregs.rax
		mov     bx,tregs.rbx
		mov     cx,tregs.rcx
		mov     dx,tregs.rdx
		mov     si,tregs.rsi
		mov     di,tregs.rdi
		mov     bp,tregs.rbp
		cli
		mov     sp,tregs.rsp
		mov     ss,tregs.rss
		sti
		mov     ds,tregs.rds
		mov     es,tregs.res
		push    tregs.flgs
		push    tregs.rcs
		push    tregs.rip
		leavepcode
		jmp     skipany
new8            endp
swtrq           db      0
infresh         db      0
swinprogr	db	0
switches	db	0
altstate	db	0b8h
ctrlstate	db	09dh	; 1d & 80 - ctrl released
new9            proc
		push    ax
		in      al,60h
		mov     swtrq,al
		cmp	al,38h
		jz	chaltmode
		cmp	al,0b8h
		jnz	cmodedone
	chaltmode:cmp	al,altstate	; change ALT key status 
		jz	cmodedone
		xor	altstate,80h
                jmp	nochctrlmode
	cmodedone:
		cmp	al,9dh
                je	chctrlmode
                cmp	al,1dh
                jne	nochctrlmode
	chctrlmode:			; change CTRL key status
		cmp	al,ctrlstate
                je	nochctrlmode
                mov	ctrlstate,al
	nochctrlmode:
		; request for kill window?
                cmp	ctrlstate,1dh
                jne	nokillrequest
                cmp	altstate,38h
                jne	nokillrequest
		cmp	al,53h
                je	killrequest
                cmp	al,52h
                je	restartrq
                jmp	nokillrequest
	killrequest:
		call	kbirqfin
		sti
                ; mark frontal task as ill
		push	bx es
                mov	bx,taskman.frontend
                or	bx,bx
                jz	tkilled			; don't kill main task
		mov	es,taskarea
                mov	es:[bx].dying,1
        tkilled:pop	es bx
                pop	ax
                iret
	restartrq:
		call	kbirqfin
                sti
                inc	cs:dorestart		; remember restart request
                pop	ax
                iret
	nokillrequest:
		pop     ax
		;inc     taskman.hintlvl
		push	ax ds si
		mov	ds,taskarea
		mov	si,taskman.frontend
		in	al,21h
		inc	taskman.in_c
		pushf
		call	dword ptr ds:[si+9*4].itbl
		dec	taskman.in_c
		out	21h,al
		pop	si ds ax
		call    SwitchRq
 NoSwitchRqsted:push	ax
		mov	ax,taskman.activetask
                cmp	ax,taskman.frontend
                jz	fract		; frontend is already active now
                cmp	taskman.privcode,0
		jnz	fract		; we are in privileged code now
		call	idle		; give frontal task chance for work
	fract:	pop	ax
                iret
new9            endp
kbirqfin	proc
                ; this code taken from thelp 5.0
		in	al,61h			;
                mov	ah,al			;
                or	al,80h			;
                out	61h,al			;
                mov	al,ah			;
                out	61h,al			;
                mov	al,20h			;
                out	20h,al			;
                ;--------------------------------
		ret
kbirqfin	endp
screenswitched	db	0
processswitch	proc
		cmp	switches,0
                jz	noswitchscreens
                cmp	swinprogr,0
                jnz	noswitchscreens
                cmp	infresh,0
                jne	noswitchscreens
                cmp	taskman.sintlvl,0
                jne	noswitchscreens
                inc	swinprogr
		call    MakeNextFrontEnd
                dec	swinprogr
                mov	switches,0
 noswitchscreens:
                ret
processswitch	endp
SaveFrontEndScr proc
		push    ds si es di ax bx cx dx bp
		mov     ax,SCREENSIZE
		mov     ds,taskarea
		mov     si,taskman.frontend
		mov     bl,[si].taskid
		or      bl,bl
		jz      ssaved
		push	ax bx
                push	ds si
		mov     ah,3
		xor     bh,bh
		call    toold10
		pop     si ds
		mov     [si].cshape,cx
		mov     [si].cpos,dx
                pop	bx ax
		dec     bl
		xor     bh,bh
		xor     dx,dx
		mul     bx
		mov     es,screens
		mov     ds,video
		mov     cx,SCREENSIZE/2
		xor     si,si
		mov     di,ax
		cld
		rep     movsw
	ssaved:
		pop     bp dx cx bx ax di es si ds
		ret
SaveFrontEndScr endp
ShowFrontEndScr proc
		pushf
		push    ds si es di ax bx cx dx bp
		mov     ax,SCREENSIZE
		mov     ds,taskarea
		mov     si,taskman.frontend
		mov     bl,[si].taskid
		or      bl,bl
		jz      sshowed
		dec     bl
		xor     bh,bh
		xor     dx,dx
		mul     bx

		push    ds si
		mov     es,video
		mov     ds,screens
		mov     cx,SCREENSIZE/2
		xor     di,di
		mov     si,ax
		cld
		rep     movsw
		pop     si ds

		push	bx ax
                mov	ax,0f00h
                push	ds si
                call	toold10
                pop	si ds
                push	ds si
                and	al,7fh
                cmp	al,[si].vmode
                jz	dcvmod		; we are in the same mode: don't touch
                mov	ah,0
                mov	al,[si].vmode
                or	al,80h
                call	toold10
	dcvmod:	pop	si ds	
                push	ds si
		mov     ah,2
		xor     bh,bh
		mov     dx,[si].cpos
		;call    toold10
                pop	si ds
		push    ds si
		mov     ah,1
		mov     cx,[si].cshape
		xor     bh,bh
		call    toold10
		pop     si ds
                pop	ax bx
	sshowed:
		pop     bp dx cx bx ax di es si ds
		popf
                ret
ShowFrontEndScr endp
MakeNextFrontEnd proc
		inc     infresh
		push    ds si
		;test	freshallowed,1
		mov	ds,taskarea
                mov	si,taskman.frontend
                cmp	[si].vidir,0
		jz	nossc
		call    SaveFrontEndScr
	nossc:	mov     ds,taskarea
		mov     si,taskman.frontend
	getnxt: add     si,size task
		cmp     si,(size task)*taskavail
		jb      inrun
		;xor    si,si
		mov     si,size task
	inrun:  cmp     [si].taskid,0
		je      getnxt
		mov     taskman.frontend,si
		call    ShowFrontEndScr
                ;inc	taskman.in_c
                inc	screenswitched
                ;cmp	si,taskman.activetask
                ;jne	nosetcur
                ;dec	screenswitched
		;push	ax bx cx dx bp es di
		;mov	ah,2
                ;mov	dx,[si].cpos
                ;xor	bx,bx
		;pushf
		;cli
		;call	dword ptr [old10]
		;pop	di es bp dx cx bx ax
  nosetcur:	;dec	taskman.in_c
		dec     infresh
		pop     si ds
		ret
MakeNextFrontEnd endp

SwitchRq        proc
		push    ds ax
		cmp	Ready,1
		jne	sxx
		;mov     ax,40h
		;mov     ds,ax
		;test    byte ptr ds:[17h],8
		cmp	altstate,0b8h
                jz      sxx
                cmp	byte ptr cs:swtrq,TGFRESHCODE
                jne	notgfr
                ;xor	freshallowed,1
		push	ds si
		mov	ds,taskarea
                mov	si,taskman.frontend
                xor	[si].vidir,1
                pop	si ds
                jmp	sxx
	notgfr:	cmp     byte ptr cs:swtrq,SWITCHCODE
		jne     sxx
                inc	switches
                ;cmp	swinprogr,0
                ;jne	sxx
                ;cmp	infresh,0
                ;jne	sxx
		;cmp     al,al
		;pop     ax ds
		;ret
	sxx:    ;mov     ax,1
		;or      ax,ax
		pop     ax ds
		ret
SwitchRq        endp
new0a           proc
		;inc	taskman.hintlvl
		;call    show8259
		;int     0ah
                push	ax ds
		xor	ax,ax
                mov	ds,ax
                in	al,21h
                push	ax
                pushf
                call	dword ptr ds:[0ah*4]
                pop	ax
                out	21h,al
                pop	ds ax
                ;dec	taskman.hintlvl
		iret
new0a           endp
new0b           proc
		;inc	taskman.hintlvl
		;call    show8259
		;int     0bh
                push	ax ds
		xor	ax,ax
                mov	ds,ax
                in	al,21h
                push	ax
                pushf
                call	dword ptr ds:[0bh*4]
                pop	ax
                out	21h,al
                pop	ds ax
                ;dec	taskman.hintlvl
		iret
new0b           endp
new0c           proc
		;inc	taskman.hintlvl
		;call    show8259
		;int     0ch
                push	ax ds
		xor	ax,ax
                mov	ds,ax
                in	al,21h
                push	ax
                pushf
                call	dword ptr ds:[0ch*4]
                pop	ax
                out	21h,al
                pop	ds ax
                ;dec	taskman.hintlvl
		iret
new0c           endp
new0d           proc
		;inc	taskman.hintlvl
		;call    show8259
		;int     0dh
                push	ax ds
		xor	ax,ax
                mov	ds,ax
                in	al,21h
                push	ax
                pushf
                call	dword ptr ds:[0dh*4]
                pop	ax
                out	21h,al
                pop	ds ax
                ;dec	taskman.hintlvl
		iret
new0d           endp
new0e           proc
		;inc	taskman.hintlvl
		;call    show8259
		;int     0eh
                push	ax ds
		xor	ax,ax
                mov	ds,ax
                in	al,21h
                push	ax
                pushf
                call	dword ptr ds:[0eh*4]
                pop	ax
                out	21h,al
                pop	ds ax
                ;dec	taskman.hintlvl
		iret
new0e           endp
new0f           proc
		;inc	taskman.hintlvl
		;call    show8259
		;int     0fh
                push	ax ds
		xor	ax,ax
                mov	ds,ax
                in	al,21h
                push	ax
                pushf
                call	dword ptr ds:[0fh*4]
                pop	ax
                out	21h,al
                pop	ds ax
                ;dec	taskman.hintlvl
		iret
new0f           endp
new10           proc
        	sti
                inc	infresh
                inc	taskman.sintlvl
		call    redirectvideo
		pushf
                dec	taskman.sintlvl
		dec	infresh
                call	penalty_proc
                popf
		sti
		retf    2
new10           endp
vcmd            db      0,     1,       2,     3,      6,       7,8,9,0ah,0eh,13h
vact            dw      setmod,setshape,setpos,readpos,scrollup,scrolldn
		dw      readchattr,writechattr,wrchar,tty,wrstring
		dw      rdrctedY                ;toold10a
redirectvideo   proc
		cmp     ah,0feh
		je      ShdowBuffRq
		cmp     ah,0ffh
		je      RefreshScreen
		jmp     NoRSISRq
 RefreshScreen: call    istaskfrontend
		jne     rfrshed
		push    es di ds si cx
                push	di
                call	Vscreenaddr
                pop	di
		movr    ds,es
		mov     si,di
		mov     es,video
		cld
		rep     movsw
		pop     cx si ds di es
	rfrshed:ret
 ShdowBuffRq:   
		call    VScreenAddr
		ret
noRSISrq:
		;call   istaskfrontend
		;jne    mkredir
		;jmp    toold10
mkredir:        sti
		push    ax bx cx dx es di ds si bp
		mov     es,taskarea
		mov     di,taskman.activetask
		Switch  ah,vcmd,vact
setmod:		mov	es:[di].vmode,al
		and	es:[di].vmode,7fh
		jmp	rdrcted
setshape:       
		;call	textvmode
                ;je	gosets
                ;jmp	rdrcted
	gosets:	mov     es:[di].cshape,cx
		jmp     rdrcted
setpos:         
		;call	textvmode
                ;je	gosetp
                ;jmp	rdrcted
	gosetp:	mov     es:[di].cpos,dx
		mov	ax,40h
                mov	ds,ax
		mov	ds:[50h],dx
		jmp     rdrcted
readpos:        
		;call	textvmode
                ;je	gorpos
                ;jmp	rdrcted
	gorpos:	mov     dx,es:[di].cpos
		mov     cx,es:[di].cshape
		jmp     rdrctedX
scrollup:
scrolldn:	
		call	textvmode
                je	goscrol
                jmp	rdrcted
	goscrol:call    VirtualScroll
		jmp     rdrcted
readchattr:     push	bx cx dx
		call    VirtualOffset
		lodsw
		pop	dx cx bx
		jmp     rdrctedX
wrchar:         call	textvmode
                je	gowrch
                jmp	rdrcted
	gowrch:	push    ax bx cx dx
		mov     dl,byte ptr es:[di].cpos
		call    VirtualOffset
	wcl:    call    CR_LFs
		je	wclp
		mov     [si],al
                call	istaskfrontend
                jne	nodupwc
		push	es si
		call	realoffs
		mov	es,video
		call	WaitForCGA
		mov	es:[si],al
                pop	si es
	nodupwc:
		add     si,2
		inc     dl
		cmp     dl,80   ; jump over eol?
	wclp:   loopne  wcl
		pop     dx cx bx ax
		jmp     rdrctedX		;?)
		
writechattr:    call	textvmode
                je	gowrcha
                jmp	rdrcted
	gowrcha:push    ax bx cx dx
		call    VirtualOffset
                push	es:[di].cpos
		mov     dl,byte ptr es:[di].cpos
	wcal:   call    CR_LFs
		je	wcallp
		mov     [si],al
		mov     [si+1],bl
		call	istaskfrontend
                jne	nodupcha
		push	es si
		call	realoffs
		mov	es,video
		call	WaitForCGA
		mov	es:[si],al
                mov	es:[si+1],bl
                pop	si es
	nodupcha:
		inc	byte ptr es:[di].cpos
		add     si,2
		inc     dl
		cmp     dl,80
	wcallp: loopne  wcal
		pop	es:[di].cpos
		pop     dx cx bx ax
		jmp     rdrctedX		;?)
wrstring:       ; not implemented
		jmp     rdrcted
tty:		call	textvmode
                jne	rdrcted
                call    CR_LFs
		je      scpos	;rdrcted
		call    VirtualOffset
		mov     [si],al
		call	istaskfrontend
		jne	noduponscr
		push	es si
		call	realoffs
		mov	es,video
		call	WaitForCGA
		mov	es:[si],al
		pop	si es
 noduponscr:
		call    nextpos
	scpos:	call	istaskfrontend
		jne	cposd
        	push	ax bx cx dx
		mov	dx,es:[di].cpos
		mov	ah,2
		xor	bh,bh
                inc	taskman.sintlvl
                inc	infresh
		pushf
                cli
                call	dword ptr [old10]
                dec	infresh
                dec	taskman.sintlvl
		pop	dx cx bx ax
	cposd:	jmp     rdrctedX		;?)
rdrcted:
		pop     bp si ds di es dx cx bx ax
                inc	taskman.sintlvl
                inc	infresh
		call    istaskfrontend
		je      told10b
                dec	infresh
                dec	taskman.sintlvl
		clc
		ret
rdrctedX:       pop     bp si ds di es
		add     sp,8
		clc
		ret
rdrctedY:       pop     bp si ds di es dx cx bx ax
	toold10a:
	toold10:inc     taskman.sintlvl
        	inc	infresh
	told10b:pushf
		cli
		call    dword ptr [old10]
		pushf
                dec	infresh
		dec     taskman.sintlvl
		popf
	rdrtd:  ret
redirectvideo   endp
CR_LFs:         cmp     al,13
		jne     nowrCR
		mov     byte ptr es:[di].cpos,0
		jmp     crorlf
	nowrcr: cmp     al,10
		jne     nowrlf
		inc     byte ptr es:[di].cpos+1
		cmp     byte ptr es:[di].cpos+1,25
		jne     crorlf
		mov     byte ptr es:[di].cpos+1,24
		call    ScrollVScreen
	crorlf: push	dx
		mov	dx,es:[di].cpos
		call	setbioscp
		pop	dx
		cmp     al,al
		ret
	nowrlf: cmp     al,8
		jne     nowrbs
		cmp     byte ptr es:[di].cpos,0
		je      nowrbs
		dec     byte ptr es:[di].cpos
		jmp     crorlf
	nowrbs: cmp	al,7
        	jne	nowrbeep
		inc	taskman.sintlvl
                inc	infresh
                push	ds si es di bp
		pushf
                cli
		call	dword ptr [old10]
                dec	infresh
		pop	bp di es si ds
                dec	taskman.sintlvl
                jmp	crorlf
	nowrbeep:
        	;cmp     al,al
		ret
NextPos         proc
		push    ax bx cx dx
		mov     dx,es:[di].cpos
		inc     dl              ; inc col
		cmp     dl,80
		jb      storenewcp
		inc     dh
		xor     dl,dl
		cmp     dh,25
		jb      storenewcp
		mov     dh,24
		mov     es:[di].cpos,dx
		call    ScrollVscreen
 storenewcp:    mov     es:[di].cpos,dx
		call	setbioscp
		pop     dx cx bx ax
		ret
NextPos         endp
setbioscp	proc
		push	ds ax
		mov	ax,40h
                mov	ds,ax
		mov	ds:[50h],dx
		pop	ax ds
		ret
setbioscp	endp
ScrollVscreen   proc
		push    dx cx bx
		call    VirtualOffset
		mov     bh,[si+1]       ;get last attribute
		xor     cx,cx
		mov     dx,184fh
		mov     ax,0601h        ;scroll up
                push	ax bx cx dx
		call    VirtualScroll
                pop	dx cx bx ax
                call	istaskfrontend
                jne	svsd
                inc	taskman.sintlvl
                inc	infresh
                push	ds si es di bp
		pushf
                cli
		call	dword ptr [old10]
                sti
		pop	bp di es si ds
                dec	infresh
                dec	taskman.sintlvl
	svsd:	pop     bx cx dx
		ret
ScrollVScreen   endp
scrolldata      struc
		strgsrc dw      0
		strgdst dw      0
		leftcpy db      0
		binline db      0
		fattr   db      0
		emptyl  db      0
scrolldata      ends
VirtualScroll   proc
		cmp	ch,dh
		jbe	goodrows
		ret
 goodrows:	cmp	cl,dl
		jbe	goodcolmns
		ret
 goodcolmns: 	cmp	dh,24
		jbe	dhok
		mov	dh,24
 dhok:		cmp	dl,79
		jbe	dlok
		mov	dl,79
 dlok:		push    bp
		push    dx cx
		sub     sp,size scrolldata
		mov     bp,sp
		mov     [bp].fattr,bh
		mov     [bp].emptyl,al
		;                       cx-upper left,dx-lower right
		cmp     ah,7
		jne     scrup
		jmp     scrdn
scrup:
		push    es:[di].cpos
		mov     es:[di].cpos,cx
		push    ax
		neg     al
		add     al,dh
		sub     al,ch
		inc     al
		mov     [bp].leftcpy,al
		mov     al,dl
		sub     al,cl
		inc     al
		mov     [bp].binline,al
		call    VirtualOffset   ; get si of left corner
		pop     ax
		mov     [bp].strgdst,si
		pop     es:[di].cpos
		xor     ah,ah
		mov     bx,160
		mul     bx              ; offset of string to move first
		add     ax,si
		mov     [bp].strgsrc,ax
		push    es di ds si
		push    ds
		pop     es
		mov     di,[bp].strgdst
		mov     si,[bp].strgsrc
		xor     cx,cx
		mov     cl,[bp].leftcpy
		cmp     [bp].emptyl,0
		jz      prep2empty
 doscroll:      push    cx
		push    si di
		mov     cl,[bp].binline
		cld
		rep     movsw
		pop     di si
		add     si,160
		add     di,160
		pop     cx
		loop    doscroll
		mov     cl,[bp].emptyl
 prep2empty:    mov     al,20h
		mov     ah,[bp].fattr
 emptyfy:       push    cx di
		mov     cl,[bp].binline
		cld
		rep     stosw
		pop     di cx
		add     di,160
		loop    emptyfy
		pop     si ds di es
		jmp     scrolled

 scrdn:         push    es:[di].cpos
		push    ax cx
		push    dx
		mov     dl,cl
		mov     es:[di].cpos,dx         ;position of line to move to
		call    VirtualOffset
		pop     dx
		sub     dl,cl
		inc     dl
		mov     [bp].binline,dl
		neg     al
		add     al,dh
		sub     al,ch
		inc     al
		mov     [bp].leftcpy,al
		pop     cx ax
		pop     es:[di].cpos
		mov     [bp].strgdst,si
		xor     ah,ah
		mov     bx,160
		mul     bx
		sub     si,ax
		mov     [bp].strgsrc,si         ;offset of src line(up on al lines)
		; all is ready
		push    ds si es di
		mov     di,[bp].strgdst
		movr    es,ds
		xor     cx,cx
		mov     cl,[bp].leftcpy
		cmp     [bp].emptyl,0
		jz      prep2emptyd
doscrolld:      push    cx
		push    si di
		mov     cl,[bp].binline
		cld
		rep     movsw
		pop     di si
		sub     si,160
		sub     di,160
		pop     cx
		loop    doscrolld
		mov     cl,[bp].emptyl
 prep2emptyd:   mov     al,20h
		mov     ah,[bp].fattr
 emptyfyd:      push    cx di
		mov     cl,[bp].binline
		cld
		rep     stosw
		pop     di cx
		sub     di,160
		loop    emptyfyd
		pop     di es si ds
 scrolled:      add     sp,size scrolldata
		pop     bp
		pop     cx dx
		ret
VirtualScroll   endp
Realoffs	proc
		push	ax bx dx
		xor     ax,ax
		mov     al,byte ptr es:[di+1].cpos      ; get row
		mov     bx,80
		mul     bx
		mov     bl,byte ptr es:[di].cpos        ; get column
		add     ax,bx
		shl     ax,1
		mov	si,ax
		pop	dx bx ax
		ret
Realoffs	endp
VirtualOffset   proc
		push    ax bx dx
		xor     ax,ax
		mov     al,byte ptr es:[di+1].cpos      ; get row
		mov     bx,80
		mul     bx
		mov     bl,byte ptr es:[di].cpos        ; get column
		add     ax,bx
		shl     ax,1
		push    ax
		mov     ax,SCREENSIZE
		xor     bx,bx
		mov     bl,es:[di].taskid
		dec     bl
		mul     bx
		mov     si,ax
		pop     ax
		add     si,ax
		mov     ds,Screens
		pop     dx bx ax
		ret
VirtualOffset   endp
rom13           dd      0
dos13           proc
		inc     taskman.in_c
		pushf
		cli
		call    dword ptr [rom13]
		pushf
		dec     taskman.in_c
		popf
		sti
		retf    2
dos13           endp
go13:		jmp	dword ptr [old13]

		;inc     taskman.in_c
		;pushf
		;cli
		;call    dword ptr [old13]
		;pushf
		;dec     taskman.in_c
		;popf
		;sti
		;retf    2
int13flag	db	0
new13           proc
		cmp	taskman.sintlvl,0
                jne	go13
                cmp	taskman.privcode,0
                jne	go13
                cmp	taskman.in_c,0
                jne	go13
		;cmp	int13flag,0
                ;jz	i13rdy
		;call	idle
                ;cli
                ;jmp	new13
	i13rdy:	inc     taskman.in_c		;int13flag
		pushf
		cli
		call    dword ptr [old13]
		pushf
		dec     taskman.in_c		;int13flag
                ;call	penalty_proc
		popf
		sti
		retf    2
new13           endp
i14_busy	db	0
i14q		queue	<>
new14           proc
                pushf
		push	ax
  bw14:		mov	al,1
  w_14:		xchg	al,i14_busy
                or	al,al
                jz	go14
		push	es di si ds
		movr	ds,cs
		lea	si,i14q
		mov	al,WAIT_FOR_CON
		call	suspend
		pop	ds si di es
                jmp	bw14
 go14:		pop	ax
		push	ds bx
		mov	ds,taskarea
                mov	bx,taskman.activetask
                inc	[bx].resources_owned
                pop	bx ds
		;inc     taskman.sintlvl
		popf
		pushf
		cli
		call    dword ptr [old14]
		pushf
		push	ds bx
                mov	ds,taskarea
                mov	bx,taskman.activetask
                dec	[bx].resources_owned
                pop	bx ds
		cmp	i14q.cur_first,-1
		je	rel_i14
		push	ds si es di ax
		mov	es,taskarea
		movr	ds,cs
		lea	si,i14q
		enterpcode
		call	release_queue
		mov	i14q.cur_first,-1
                mov	i14q.cur_last,-1
		leavepcode
		pop	ax di es si ds
rel_i14:	mov	i14_busy,0
		;dec     taskman.sintlvl
		popf
		sti
		retf    2
new14           endp
new15           proc
		pushf
		inc     taskman.sintlvl
                popf
		pushf
		cli
		call    dword ptr [old15]
		pushf
		dec     taskman.sintlvl
		popf
		sti
		retf    2
new15           endp
new1a           proc
	n1af:	cmp	int13flag,0
                je	allow_CMOS_Access
		call	idle
                jmp	n1af
allow_CMOS_Access:
		inc     taskman.in_c
		pushf
		cli
		call    dword ptr [old1a]
		pushf
		dec     taskman.in_c
		popf
		sti
		retf    2
new1a           endp
new1b           proc
		push    ax
		mov     ax,2e03h
		call    placescan
		pop     ax
		iret
new1b           endp
PrevScBufAddr   dw      0
PlaceScan       Proc
		push    ds
		push    si
		push    di
		push    cx
		mov     cx,40h
		mov     ds,cx
		mov     si,1ch
		cli
		mov     di,[si]
		mov     cs:PrevScBufAddr,di
		mov     [di],ax
		add     di,2
		cmp     di,3eh
		jne     TestOverfl
		mov     di,1eh
TestOverfl:     cmp     di,[si-2]
		jne     NoOvfl
		mov     di,cs:PrevScBufAddr
NoOvfl:
		mov     [si],di
		sti
		pop     cx
		pop     di
		pop     si
		pop     ds
		ret
PlaceScan       Endp
new16           proc
		sti
		cmp     ah,10h
		je      newwait
		cmp     ah,0
		je      newwait
		cmp     ah,11h
		je      newkstatus
		cmp     ah,1
		je      newkstatus
	callold16:
		inc     taskman.sintlvl
                clc
		pushf
		cli
		call    dword ptr [old16]
		pushf
		dec     taskman.sintlvl
		popf
		sti
		retf    2
	newwait:
		push	ax ds si
		mov	ds,taskarea
                mov	si,taskman.activetask
                cmp	[si].kbdexchange,0
                jz	nokstrine
                pushf
                xor	ax,ax
                xchg	ax,[si].kbdexchange
		popf
       nokstrine:
                pop	si ds
                jz	kxempty
		add	sp,2			; not FZ - kill ax in stack
                jmp	stt			; assume add sp don't change ZF
	kxempty:pop	ax
        	call    istaskfrontend
		jnz     nofrontwait
		push    ax
		mov     ah,1
		call    Is84Key
		jz      GetKStat
		mov     ah,11h
	GetKStat:call   getkbdstat
		pop     ax
		jz      kbdempty
		inc     taskman.sintlvl
                clc
		pushf
		cli
		call    dword ptr [old16]
		pushf
		dec     taskman.sintlvl
		popf
		sti
		retf    2
	kbdempty:
		call    idle
		jmp     newwait
	nofrontwait:
		sti
		call    idle
		jmp     newwait
newkstatus:
		push	ax ds si
		mov	ds,taskarea
                mov	si,taskman.activetask
                cmp	[si].kbdexchange,0
                jz	nokstrinex
                mov	ax,[si].kbdexchange
       nokstrinex:
                pop	si ds
                jz	cox
		add	sp,2
                jmp	stt
	cox:	pop	ax
        	call    istaskfrontend
		jnz     NoFrontEndKbdStat
		call    getkbdstat
		jnz     TestonSWKey
 stt:           sti
		retf    2
 testonswkey:   pushf
		cmp     ax,0a500h       ; ALT-TAB
		jz      EatSWkey
		popf
		jmp     stt
 EatSwKey:      
		mov     ah,10h
		call    getkbdstat
		popf
		cmp     al,al
		jmp     stt

	NoFrontEndKbdStat:
		;call	free_to_dos
                ;jnz	nfnw		; don't switch	;
		;call	idle		; if dos check	;!!! DANGEROUS !!!
	nfnw:	cmp     al,al		; keyboard	;
		sti
		retf    2
new16           endp
getkbdstat      proc
		;call   idle                    ; !!!!!!!
		inc     taskman.sintlvl
                clc
		pushf
		cli
		call    dword ptr [old16]
		pushf
		dec     taskman.sintlvl
		popf
		ret
getkbdstat      endp
;int2526r       dd      0
;sp2526         dw      0
lockDOS         proc
		pushf
		push    ds si
		lds     si,dosflag
		inc     byte ptr [si]
		pop     si ds
		popf
		ret
lockDOS         endp
unlockDOS       proc
		pushf
		push    ds si
		lds     si,dosflag
		dec     byte ptr [si]
		pop     si ds
		popf
		ret
unlockDOS       endp
new25           proc
wait13r:        cli
 freeto25a:     push    ds si
		lds     si,dosflag
		cmp     word ptr [si-1],0
		pop     si ds
		jz      freeto25b
		sti
		call    idle
		jmp     wait13r
 freeto25b:     inc     taskman.in_c
		call    dword ptr [old25]
		pushf
		dec     taskman.in_c
		popf
		sti
		retf
new25           endp
new26           proc
wait13w:        cli
 freeto26a:     push    ds si
		lds     si,dosflag
		cmp     word ptr [si-1],0
		pop     si ds
		jz      freeto26b
		sti
		call    idle
		jmp     wait13r
 freeto26b:     inc     taskman.in_c
		call    dword ptr [old26]
		pushf
		dec     taskman.in_c
		popf
		sti
		retf
new26           endp
new28           proc
		;sti
		;call   showstate
		;push    ds si
		;lds     si,dosflag
		;cmp     byte ptr [si-1],0       ; word ptr 
		;pop     si ds
		;jne     callold28
		;push    es di
		;mov     es,taskarea
		;mov     di,taskman.activetask
		;cmp     es:[di].ltck,1
		;pop     di es
		;jne     callold28
		;call    switchallowed
		;jne     callold28
		;enterpcode
		;sti
		;jmp     switchtask

	callold28:
        	call	free_to_dos
                jnz	i28na
                cmp	indos_c,0
                jnz	i28na
                inc	taskman.in_c
		pushf
		cli
		call    dword ptr [old28]
		dec	taskman.in_c
	i28na:	iret
new28           endp
UpdScreen       proc
		call    istaskfrontend
		jne     noupds
		push    ds si es di cx
		call    VScreenAddr
		movr    ds,es
		mov     si,di
		mov     es,Video
		xor     di,di
		mov     cx,SCREENSIZE/2
		cld
		cli
		rep     movsw
		sti
		pop     cx di es si ds
 noupds:        ret
UpdScreen       endp
VScreenAddr     proc
		push    ax bx dx
		mov     es,taskarea
		mov     di,taskman.activetask
		mov     al,es:[di].taskid
		dec     al
		xor     ah,ah
		mov     bx,SCREENSIZE/16
		mul     bx
		mov     bx,screens
		add     ax,bx
		mov     es,ax
		xor     di,di
		pop     dx bx ax
		ret
VScreenAddr     endp
new2a           proc
		pushf
		cmp     ah,87h                  ; enter csestion ?
		je      csec
                cmp	ah,82h
                je	awake
		inc     taskman.sintlvl
		popf
		pushf
		call    dword ptr [old2a]
		dec     taskman.sintlvl
 rf2a:		sti
		retf    2
csec:           
		cmp     al,0
		jne     lcsc
                popf
                pushf
                cli
                call	dword ptr [old2a]
                jc	rf2a
                cmp	indos_c,1
                cmc
                jc	rf2a
		;cmp	taskman.privcode,1
                ;cmc
                ;jc	rf2a
                ;cmp	taskman.sintlvl,1
                ;cmc
                ;jc	rf2a
                ;push	ds si
                ;lds	si,dosflag
                ;cmp	word ptr [si-1],1
                ;pop	si ds
                ;cmc
                ;jc	rf2a
		inc     taskman.in_c
                jmp	rf2a
lcsc:           cmp     al,1
		jne     gtoold2a
		dec     taskman.in_c
 gtoold2a:	popf
	toold2a:cli
		jmp     dword ptr [old2a]
new2a           endp
awake:		;cli
		cmp	indos_c,0
                jz	awk1
                dec	indos_c
                call	unlockdos
		;mov	indos_c,0
	awk1:	;sti
		cmp	indos_queue.cur_first,-1
		jne	dosextract
		popf
		jmp	toold2a
 dosextract:    enterpcode
		sti
		push	ds si es di ax
		mov	es,taskarea
		movr	ds,cs
		lea	si,indos_queue
		call	release_queue
		mov	indos_queue.cur_first,-1
                mov	indos_queue.cur_last,-1
		leavepcode
		call	idle			; somebody ask for
						; resource, so give
						; him job
		pop	ax di es si ds
		popf
		jmp	toold2a
new33           proc
		iret
		;inc     taskman.sintlvl
		;pushf
		;cli
		;call    dword ptr [old33]
		;pushf
		;dec     taskman.sintlvl
		;popf
		;sti
		;retf    2
new33           endp
oxmsstr		db	5 dup (0)
oxmsentry	dd	0
xmscatch	proc
		pushf
		cmp	ah,4
                je	disrq
                cmp	ah,6
                je	disrq
                cmp	ah,3
                je	enbrq
                cmp	ah,5
                je	enbrq
                cmp	ah,7
                je	getA20stat
		inc	taskman.in_c
                popf
                call	dword ptr [oxmsentry]
		pushf
		dec	taskman.in_c
		popf
                retf
xmscatch	endp
newxms          proc
		jmp     short realxms
		nop
		nop
		nop
 realxms:       inc     taskman.in_c
		call    dword ptr [xmsdrvaddr]
		pushf
		dec     taskman.in_c
		popf
		retf
newxms          endp
getA20stat:     popf
		mov	ax,1
		mov	bl,0
                retf
disrq:		popf
		mov	ax,0
		mov	bl,94h
		;clc
                retf
		;inc	taskman.in_c
		;jmp	dword ptr [oxmsentry]
enbrq:		popf
		mov	ax,1
		;clc
                retf
		;call	dword ptr [oxmsentry]
		;pushf
		;dec	taskman.in_c
		;popf
                ;retf

new2f           proc
		pushf
		cmp     ah,12h
		ja      nodosintrnl
                popf
		jmp     dword ptr [old2f]
nodosintrnl:    
		sti
		inc     taskman.sintlvl
		cmp     ax,4310h
		je      xmsaddrrq
		cmp     ax,1605h
		je      MSWindows
 toold2F:       
 		popf
		pushf
		cli
		call    dword ptr [old2f]
	ol2fd:  pushf
		dec     taskman.sintlvl
		popf
		sti
		retf    2

 xmsaddrrq:     popf
		cmp     word ptr xmsdrvaddr+2,0
		je      ol2fd
		movr    es,cs
		lea     bx,newxms
		clc
		jmp     ol2fd
 MSWindows:     popf
		push    ax
		mov     ax,ds
		and     ax,si
		pop     ax
		jnz     toold2F
		push    ax bx ds dx
		movr    ds,cs
		mov     ah,40h          ; write
		mov     bx,2            ; to stderr
		lea     dx,No2MSWin
		mov     cx,72
		int     21h
		pop     dx ds bx ax
		mov     cx,1
		dec     taskman.sintlvl
		iret
new2f           endp
No2MSWin        db      'Can not run. Try real mode. ',13,10,'$'
syscommands	db	0	; request task switch
		db	1	; send scancode in bx to another task
                db	2	; enter critical section | no  test if
                db	3	; leave critical section | dos is busy
		db	4	; al=0 video direct off,al=1 direct on
sysactions	dw	PAUSE
		dw	POST_KEYPRESS
                dw	ENTER_CR_SEC
                dw	LEAVE_CR_SEC
                dw	SETVIDEOMOD
		dw	invalidsysrq
marker          db      'MTAS'
new48           proc
		;call   showstate
		switch	ah,syscommands,sysactions

PAUSE:		sti
		enterpcode
		jmp     switchtask

POST_KEYPRESS:	; put code in bx to kbdbuffer, set c if no place
		push	es di
		push	bx
                mov	di,size task
                mov	ax,taskman.activetask
                cmp	ax,size task
		jne	POSTto1st_task
                ;POST_keystroke_to_2nd_Task
		shl	di,1
 POSTto1st_task:pop	bx
                mov	es,taskarea
                cmp	es:[di].kbdexchange,0
                jne	kbd_exch_not_ready
		mov	es:[di].kbdexchange,bx
                clc
                jmp	kbedone
 kbd_exch_not_ready:
		stc
 kbedone:	pop	di es
                ;leavepcode
		sti
		retf	2
ENTER_CR_SEC:	inc	taskman.in_c
		;leavepcode
                sti
                clc
                retf	2
LEAVE_CR_SEC:	dec	taskman.in_c
		;leavepcode
                sti
                clc
                retf	2
SETVIDEOMOD:	push	ds si
		mov	ds,taskarea
                mov	si,taskman.activetask
                mov	[si].vidir,al
		pop	si ds
		sti
                clc
                retf	2
INVALIDSYSRQ:	;leavepcode
		stc
		sti
		retf	2
new48           endp
new5c           proc
		pushf
		inc     taskman.sintlvl
                popf
		pushf
		call    dword ptr [old5c]
		pushf
		dec     taskman.sintlvl
		popf
		sti
		retf    2
new5c           endp
new67           proc
		pushf
		cmp	emsdisabled,1
                jnz	goems
                popf
                iret
	goems:	inc     taskman.sintlvl
		cmp	ah,58h
                jne	nomaparr
                mov	cx,0
                mov	ax,0
                dec	taskman.sintlvl
                popf
                iret
	nomaparr:
                popf
                ;jmp	dword ptr [old67]
		pushf
		call    dword ptr [old67]
		pushf
		dec     taskman.sintlvl
		popf
		sti
		retf    2
new67           endp
new70           proc
		;inc	taskman.hintlvl
		pushf
		call    dword ptr [old70]
                ;dec	taskman.hintlvl
		iret
new70           endp
new71           proc
		;inc	taskman.hintlvl
		pushf
		call    dword ptr [old71]
                ;dec	taskman.hintlvl
		iret
new71           endp
new72           proc
		;inc	taskman.hintlvl
		pushf
		call    dword ptr [old72]
                ;dec	taskman.hintlvl
		iret
new72           endp
new73           proc
		;inc	taskman.hintlvl
		pushf
		call    dword ptr [old73]
                ;dec	taskman.hintlvl
		iret
new73           endp
new74           proc
		;inc	taskman.hintlvl
		pushf
		call    dword ptr [old74]
                ;dec	taskman.hintlvl
		iret
new74           endp
new75           proc
		;inc	taskman.hintlvl
		pushf
		call    dword ptr [old75]
                ;dec	taskman.hintlvl
		iret
new75           endp
new76           proc
		;inc	taskman.hintlvl
		pushf
		call    dword ptr [old76]
                ;dec	taskman.hintlvl
		iret
new76           endp
new77           proc
		;inc	taskman.hintlvl
		pushf
		call    dword ptr [old77]
                ;dec	taskman.hintlvl
		iret
new77           endp
switchallowed   proc
		;call    inhint
		;jnz     dtrm
		call    insint
		jnz     dtrm
		cmp     taskman.in_c,0
	dtrm:
		ret
switchallowed   endp
istaskfrontend  proc
		push    ax
		mov     ax,taskman.activetask
		cmp     ax,taskman.frontend
		pop     ax
		ret
istaskfrontend  endp
getnexttask     proc            ; take first task in run queue
				; and place it it to end of queue if it has
				; ST_RUN state
				; next task become active
		push    cx
		mov     es,taskarea
		movr    ds,cs
		lea     si,run_queue
		mov     cx,HIPRIO+1
	prioloop:                       ; scan all priority queues
		call    Take_1st
		dec     cx
		cmp     di,0ffffh
		jnz     select_on_this_level
		jcxz    disaster        ; no task to run
		add     si,size queue
		jmp     prioloop        ; test on next priority level
	select_on_this_level:
		call	TestOnKill
		cmp     es:[di].tState,ST_RUN
		jnz     noplaceinrun
		mov     ax,di
		push    si
		lea     si,run_queue
		call    to_end_PQ
		pop     si
noplaceinrun:
		mov     di,[si].cur_first
		add     si,size queue
		cmp     di,-1
		jz      prioloop
		mov     cs:taskman.activetask,di
		pop     cx
		ret
TestOnKill	proc
		cmp	es:[di].dying,0
                jz	notilltask
                call	free_to_dos
                jz	dosnotbusy
		;cmp	Dosowner,di
		;jne	dosnotbusy
                jmp	cantKill
	dosnotbusy:
		cmp	es:[di].resources_owned,0
                jnz	cantkill		; this task own some resource
		; check for resources
		call	PrepForDie
 CantKill:
 notilltask:
		ret
TestOnKill	endp
PrepForDie	proc
		mov	word ptr es:[di].tcsip,  offset trapdostask
                mov	word ptr es:[di+2].tcsip,cs
		ret
PrepForDie	endp
disaster:       movr    ds,cs
		lea     dx,disastermsg
		mov     ah,9
		int     21h
		;call    showstate
		sti
 blackhole:     jmp     blackhole
disastermsg     db      13,10,'DIED!',13,10,'$'
;               mov     es,taskarea
;               mov     di,cs:taskman.activetask
;       fntloop:add     di,size task
;               cmp     di,(size task)*taskavail
;               jb      ntover
;               xor     di,di
;       ntover:
;               cmp     es:[di].taskid,0
;               jz      fntloop
;               mov     cs:taskman.activetask,di
;               ret
getnexttask     endp
mtsetup         proc
		;enterpcode
			IF      DEBUGMODE
				call    report
				call    saystart
			ENDIF
		;call	emmpresent
		cmp	emsdisabled,1
                jz	ncEMS
		mov	byte ptr emmlab,'E'
	ncEMS:
		mov	ax,0f00h
                int	10h
		and	al,7fh
                mov	startmode,al
		mov     ax,(size task)*taskavail/16+1   ; get mem for tasks
		getmem  ax
		jc      amts
		mov     Taskarea,ax
		mov     ax,STACKFRAME/16*TASKAVAIL+1    ; 2K stack foreach
		getmem  ax
		mov     Stacks,ax
		jnc     memok1
	amts:
		call    _restore
		mov     ax,4c00h
		int     21h
	memok1:	mov     ax,5d06h
		int     21h                     ; get swap area addr
		mov     word ptr swaparea,si
		mov     word ptr swaparea+2,ds
                mov	swaplen,dx
		mov     ah,52h
		int     21h
		mov     al,es:[bx+21h]          ; drives (58h bytes each)
		add     bx,16h
		mov     word ptr ldptr,  bx
		mov     word ptr ldptr+2,es
		lds     si,es:[bx]              ; pointer to current lastdrv
		mov     word ptr oldlastdrv,si
		mov     word ptr oldlastdrv+2,ds
		push    ax
		mov     cx,TASKAVAIL*58h/16+1
		xor     ah,ah
		xor     dx,dx
		mul     cx
		getmem  ax
		jc      amts
		mov     lastdrv,ax
		mov     es,ax
		xor     di,di
		pop     ax
		xor     ah,ah
		xor     dx,dx
		mov     bx,58h
		mul     bx
		mov     ldinc,ax
		mov     cx,TASKAVAIL
setld:          push    cx
		mov     cx,ax
		push    ds si
		cld
		rep     movsb
		pop     si ds
		pop     cx
		loop    setld
		lds     si,ldptr
		xor     ax,ax
		cli
		mov     word ptr [si],0
		mov     ax,lastdrv
		mov     [si+2],ax
		sti
		mov     ax,SCREENSIZE/16*TASKAVAIL+1
                add	ax,5				; 1 additional line
		getmem  ax
		jnc     initscreens
                jmp	amts
 initscreens:	mov     screens,ax
		mov     es,ax
		xor     di,di
		mov     cx,SCREENSIZE/2*TASKAVAIL ; no more than ~32 tasks!
		mov     ax,0720h
		rep     stosw                   ; initialize screens with sp.
		mov     tregs.rax,ax
		mov     tregs.rbx,bx
		mov     tregs.rcx,cx
		mov     tregs.rdx,dx
		mov     tregs.rsi,si
		mov     tregs.rdi,di
		mov     tregs.rbp,bp
		mov     tregs.rsp,sp
		mov     tregs.rds,ds
		mov     tregs.res,es
		mov     tregs.rss,ss
		pushf
		pop     tregs.flgs
		call    createtask
		call    put2run_Q
		mov     es:[di].tState,ST_RUN
		push    es di                   ; a
		push    es                      ;  s
		pop     ds                      ;   s
		mov     dx,di                   ;    i
		;add     dx,offset curdta        ;     g
		;mov     ah,1ah                  ;      n   a
		;int     21h                     ;         t
		pop     di es                   ;        d
		call    SaveTaskEnv
		mov     es:[di].ticks,STDTICK
		mov     es:[di].ltck,STDTICK
		mov     es:[di].prio,0
		mov     taskman.activetask,di
		mov     taskman.frontend,di
		push    es di
		mov     ah,3
		xor     bh,bh
		int     10h
		pop     di es
		mov     es:[di].cshape,cx
		mov     es:[di].cpos,dx
		push    es di
		call    saveparent
		mov     ax,3400h
		int     21h
		mov     word ptr dosflag,bx
		mov     word ptr dosflag+2,es
		mov     ah,62h
		int     21h
		mov     mypsp,bx
			IF      DEBUGMODE
				call    sayOK
				call    say_getvectors
			ENDIF
		mov     ax,3510h
		int     21h
		mov     word ptr cs:old10,bx
		mov     word ptr cs:old10+2,es
		mov     ax,2510h
		movr    ds,cs
		lea     dx,new10
		int     21h
		mov     ax,3513h
		int     21h
		mov     word ptr cs:old13,bx
		mov     word ptr cs:old13+2,es
		mov     ax,2513h
		movr    ds,cs
		lea     dx,new13
		int     21h
		mov     ax,offset old14
		mov     bx,offset new14
		mov     cx,14h
		call    setvec
		mov     ax,offset old15
		mov     bx,offset new15
		mov     cx,15h
		call    setvec
		mov     ax,offset old16
		mov     bx,offset new16
		mov     cx,16h
		call    setvec
		mov     ax,offset old1a
		mov     bx,offset new1a
		mov     cx,1ah
		call    setvec
		mov     ax,offset old1b
		mov     bx,offset new1b
		mov     cx,1bh
		call    setvec
		mov     ax,offset old21
		mov     bx,offset new21
		mov     cx,21h
		call    setvec
		mov     ax,offset old25
		mov     bx,offset new25
		mov     cx,25h
		call    setvec
		mov     ax,offset old26
		mov     bx,offset new26
		mov     cx,26h
		call    setvec
		mov     ax,offset old28
		mov     bx,offset new28
		mov     cx,28h
		call    setvec
		mov     ax,offset old2a
		mov     bx,offset new2a
		mov     cx,2ah
		call    setvec
		mov     ax,offset old2f
		mov     bx,offset new2f
		mov     cx,2fh
		call    setvec
		mov     ax,offset old33
		mov     bx,offset new33
		mov     cx,33h
		call    setvec
		mov     ax,offset old48
		mov     bx,offset new48
		mov     cx,48h
		call    setvec
		mov     ax,offset old5c
		mov     bx,offset new5c
		mov     cx,5ch
		call    setvec
		mov     ax,offset old67
		mov     bx,offset new67
		mov     cx,67h
		call    setvec
		mov     ah,13h
		movr    ds,cs
		movr    es,cs
		lea     dx,dos13
		lea     bx,dos13
		int     2fh
		mov     word ptr rom13+2,ds
		mov     word ptr rom13  ,dx
		pop     di es
		call    sethvectors
                cmp	word ptr xmsdrvaddr+2,0
                jz	noxmsdrv
                lds	si,dword ptr xmsdrvaddr
                movr	es,cs
                lea	di,oxmsstr
                mov	cx,5
                cld
                rep	movsb
                lds	si,dword ptr xmsdrvaddr
                cli
                mov	[si],byte ptr 0eah 
		mov	[si+1],offset xmscatch
                mov	[si+3],cs
                sti
                add	si,5
                mov	word ptr oxmsentry,si
                mov	word ptr oxmsentry+2,ds
 noxmsdrv:
			IF      DEBUGMODE
				call    sayOK
				call    say_PIC_set
			ENDIF
		call    setup8259A
			IF      DEBUGMODE
				call    sayOK
				call    testingwait
			ENDIF
		call    savefrontendscr
		mov	Ready,1
		clc
		;leavepcode
		ret
mtsetup         endp
show8259        proc
		;ret
		;.186
		;pusha
		;mov     al,0bh
		;out     20h,al
		;nop
		;nop
		;nop
		;in      al,20h
		;xor     ah,ah
		;;call   wword
		;popa
		;.8086
		;ret
show8259        endp
setup8259a      proc
		cli
		call    Isitat
		jne     xtsetup
                in	al,0a1h
                push	ax
                in	al,021h
                push	ax
		mov     dx,21h
		mov     al,11h
		out     20h,al
		mov     al,IRQBASE
		out     dx,al
		mov     al,4
		out     dx,al
		mov     al,1
		out     dx,al
		mov     al,0ffh
		out     dx,al
		mov     dx,0a1h
		mov     al,11h
		out     0a0h,al
		mov     al,70h
		out     dx,al
		mov     al,2
		out     dx,al
		mov     al,1
		out     dx,al
		mov     al,0ffh
		out     dx,al
                pop	ax
		;xor     al,al
		out     021h,al
		jmp     $+2
                pop	ax
		out     0a1h,al
	en8259: sti
		ret
	xtsetup:
		mov     dx,21h
                in	al,dx
                push	ax
		mov     al,13h
		out     20h,al
		mov     al,IRQBASE
		out     dx,al
		mov     al,9
		out     dx,al
                pop	ax
		out     dx,al
		sti
		ret
setup8259a      endp
restore8259a    proc
		cli
		call    isitat
		jne     xtrestore
                in	al,0a1h
                push	ax
                in	al,21h
                push	ax
		mov     dx,21h
		mov     al,11h
		out     20h,al
		mov     al,8
		out     dx,al
		mov     al,4
		out     dx,al
		mov     al,1
		out     dx,al
		;mov    al,0ffh
		;out    dx,al
		mov     dx,0a1h
		mov     al,11h
		out     0a0h,al
		mov     al,70h
		out     dx,al
		mov     al,2
		out     dx,al
		mov     al,1
		out     dx,al
                pop	ax
                out	21h,al
                pop	ax
                out	0a1h,al
		sti
		ret
	xtrestore:
		mov     dx,21h
                in	al,dx
                push	ax
		mov     al,13h
		out     20h,al
		mov     al,8
		out     dx,al
		mov     al,9
		out     dx,al
		;xor     al,al
                pop	ax
		out     dx,al
		sti
restore8259a    endp
sethvectors     proc
		mov     ax,offset dummyvec
		mov     bx,offset new8
                xor	cx,cx
		mov     cl,IRQBASE                      ;8
		call    setvec
		mov     ax,offset dummyvec
		mov     bx,offset new9
                xor	cx,cx
		mov     cl,IRQBASE
                add	cl,1                    ;9
		call    setvec
		mov     ax,offset dummyvec
		mov     bx,offset new0a
                xor	cx,cx
		mov     cl,IRQBASE
                add	cl,2                    ;0ah
		call    setvec
		mov     ax,offset dummyvec
		mov     bx,offset new0b
                xor	cx,cx
		mov     cl,IRQBASE
                add	cl,3                    ;0bh
		call    setvec
		mov     ax,offset dummyvec
		mov     bx,offset new0c
                xor	cx,cx
		mov     cl,IRQBASE
                add	cl,4                    ;0ch
		call    setvec
		mov     ax,offset dummyvec
		mov     bx,offset new0d
                xor	cx,cx
		mov     cl,IRQBASE
                add	cl,5                    ;0dh
		call    setvec
		mov     ax,offset dummyvec
		mov     bx,offset new0e
                xor	cx,cx
		mov     cl,IRQBASE
                add	cl,6                    ;0eh
		call    setvec
		mov     ax,offset dummyvec
		mov     bx,offset new0f
                xor	cx,cx
		mov     cl,IRQBASE
                add	cl,7                    ;0fh
		call    setvec
		mov     ax,offset old70
		mov     bx,offset new70
		mov     cx,70h
		call    setvec
		mov     ax,offset old71
		mov     bx,offset new71
		mov     cx,71h
		call    setvec
		mov     ax,offset old72
		mov     bx,offset new72
		mov     cx,72h
		call    setvec
		mov     ax,offset old73
		mov     bx,offset new73
		mov     cx,73h
		call    setvec
		mov     ax,offset old74
		mov     bx,offset new74
		mov     cx,74h
		call    setvec
		mov     ax,offset old75
		mov     bx,offset new75
		mov     cx,75h
		call    setvec
		mov     ax,offset old76
		mov     bx,offset new76
		mov     cx,76h
		call    setvec
		mov     ax,offset old77
		mov     bx,offset new77
		mov     cx,77h
		call    setvec
		ret
sethvectors     endp
setvec          proc
		push    ax bx cx bp
		mov     bp,sp
		mov     ah,35h
		mov     al,[bp+2]
		int     21h
		mov     si,[bp+6]
		mov     word ptr cs:[si],bx
		mov     word ptr cs:[si+2],es
		mov     ah,25h
		mov     al,[bp+2]
		movr    ds,cs
		mov     dx,[bp+4]
		int     21h
		pop     bp cx bx ax
		ret
setvec          endp
SaveTaskEnv     proc
		call    saveitab
		call	saveswap
		call    savepsp
		;call    save_handlers
		;call    savedrive
		;call    savedta
		call    saveregs
                call	savecurloc
		ret
SaveTaskEnv     endp
RstrTaskEnv     proc
		call    rstitab
		call	rstrswap
		call    rstregs
		call    rstrpsp
		;call    rstr_handlers
		;call    rstrdta
		;call    rstrdrive
		call    rstrdir
                call	rstrcurloc
		ret
RstrTaskEnv     endp
savecurloc	proc
		;push	ax ds
		mov	ax,40h
		mov	ds,ax
                mov	ax,ds:[50h]
                mov	es:[di].cpos,ax
                ;pop	ds ax
		ret
savecurloc	endp
rstrcurloc	proc
		;push	ax ds
		mov	ax,40h
		mov	ds,ax
                mov	ax,es:[di].cpos
                mov	ds:[50h],ax
                ;ret
                cmp	screenswitched,0
		je	noresc
                cmp	taskman.frontend,di
                jne	noresc
		dec	screenswitched
		push	es di
		mov	dx,es:[di].cpos
                mov	ah,2
                xor	bx,bx
                ;pushf				; dangerous     ???
                ;cli				; for		???
                ;call	dword ptr [old10]	; some		???
                sti				; bios		???
                pop	di es
 noresc:
                ;pop	ds ax
		ret
rstrcurloc	endp
saveswap	proc
		push	es di
                pushf
		add	di,offset swapdata
		lds	si,swaparea
		add	si,2
		mov	cx,swaplen
                cld
                cli
		rep	movsb
		popf
                pop	di es
		ret
saveswap	endp
rstrswap	proc
		push	es di
                pushf
		add	di,offset swapdata
                movr	ds,es
                mov	si,di
		les	di,swaparea
		add	di,2
		mov	cx,swaplen
                cld
                cli
		rep	movsb
		popf
                pop	di es
		ret
rstrswap	endp
saveitab        proc
		push    ds si es di cx
		xor     si,si
		mov     ds,si
		add     di,offset itbl
		mov	cx,0bh*2 		;save all but 0b&0c&0d
		cld
		cli
		rep	movsw
                add	di,3*4
		add	si,3*4
		mov     cx,IENTRYS*2-0eh*2
		rep     movsw
		sti
		pop     cx di es si ds
		ret
saveitab        endp
rstitab         proc
		push    ds si es di cx
		mov     si,di
		add     si,offset itbl
		push	es
		pop	ds
		xor	di,di
		mov	es,di
                mov	cx,0bh*2		;restore all but 0b&0c&0d
		cld
		cli
                rep	movsw
                add	di,3*4
                add	si,3*4
		mov     cx,IENTRYS*2-0eh*2
		rep     movsw
		sti
		pop     cx di es si ds
		ret
rstitab         endp
save_handlers   proc
		;push    ds
		;xor     ax,ax
		;mov     ds,ax
		;mov     ax,ds:[23h*4]
		;mov     word ptr es:[di].int23hn,ax
		;mov     ax,ds:[23h*4+2]
		;mov     word ptr es:[di].int23hn+2,ax
		;mov     ax,ds:[24h*4]
		;mov     word ptr es:[di].int24hn,ax
		;mov     ax,ds:[24h*4+2]
		;mov     word ptr es:[di].int24hn+2,ax
		;pop     ds
		;ret
save_handlers   endp
rstr_handlers   proc
		;push    ds
		;xor     ax,ax
		;mov     ds,ax
		;mov     ax,word ptr es:[di].int23hn
		;mov     ds:[23h*4],ax
		;mov     ax,word ptr es:[di].int23hn+2
		;mov     ds:[23h*4+2],ax
		;mov     ax,word ptr es:[di].int24hn
		;mov     ds:[24h*4],ax
		;mov     ax,word ptr es:[di].int24hn+2
		;mov     ds:[24h*4+2],ax
		;pop     ds
		;ret
rstr_handlers   endp
rstrdta         proc
		;push    ds si es bx
		;lds     si,swaparea
		;les     bx,es:[di].dta
		;mov     [si+0ch],bx
		;mov     [si+0ch+2],es
		;pop     bx es si ds
		;ret
rstrdta         endp
savedta         proc
		;push    ds si
		;lds     si,swaparea
		;lds     si,dword ptr [si+0ch]
		;mov     word ptr es:[di].dta,  si
		;mov     word ptr es:[di].dta+2,ds
		;pop     si ds
		;ret
savedta         endp
rstrdir         proc                    ; attn! only for default drive!
		push    es di
		mov     es,taskarea
		mov     ax,taskman.activetask
		mov     bx,size task
		xor     dx,dx
		div     bx
		mov     bx,ldinc
		xor     dx,dx
		mul     bx
		lds     si,ldptr
                cli
		mov     [si],ax
		mov     ax,lastdrv
		mov     [si+2],ax
                sti
		pop     di es
		ret
rstrdir         endp
savedir         proc
		;ret
savedir         endp
rstrdrive       proc
		;push    es di
		;mov     al,es:[di].curdrv
		;les     di,swaparea
		;mov     es:[di+16h],al
		;pop     di es
		;ret
rstrdrive       endp
savedrive       proc
		;push    es di
		;les     di,swaparea
		;mov     al,es:[di+16h]
		;mov    ah,19h
		;int    21h
		;pop     di es
		;mov     es:[di].curdrv,al
		;ret
savedrive       endp
saveparent      proc
		push    ds si
		mov     ds,mypsp
		lds     si,ds:[2eh]
		mov     word ptr es:[di].sssp21,si
		mov     word ptr es:[di].sssp21+2,ds
		pop     si ds
		ret
saveparent      endp
rstrparent      proc
		push    ds
		mov     ds,mypsp
		mov     cx,word ptr es:[di].sssp21
		mov     ds:[2eh],cx
		mov     cx,word ptr es:[di].sssp21+2
		mov     ds:[2eh+2],cx
		pop     ds
		ret
rstrparent      endp
rstrpsp         proc
		call    rstrparent
		push    es di
		mov     bx,es:[di].psp
		les     di,swaparea
		mov     es:[di+10h],bx
		pop     di es
                mov	bx,es:[di].barrv
                push	ds
                mov	ds,barrier
                mov	ds:[3],bx
                pop	ds
		ret
rstrpsp         endp
savepsp         proc
		call    saveparent
		push    es di
		les     di,swaparea
		mov     bx,es:[di+10h]
		pop     di es
		mov     es:[di].psp,bx
                push	ds
                mov	ds,barrier
                mov	bx,ds:[3]	; get barrier size
                mov	es:[di].barrv,bx
                pop	ds
		ret
savepsp         endp
rstregs         proc
		push    es di
		movr    ds,es
		mov     si,di
		add     si,offset tax
		movr    es,cs
		lea     di,tregs
		mov     cx,size tregs
		cld
		rep     movsb
		pop     di es
		ret
rstregs         endp
saveregs        proc
		push    es di
		add     di,offset tax
		push    cs
		pop     ds
		lea     si,tregs
		mov     cx,size tregs
		cld
		rep     movsb
		pop     di es
		ret
saveregs        endp
createtask      proc
		call    Findfreetask
		jc      allocated
		mov     es:[di].taskid,al
		clc
	allocated:
		ret
createtask      endp
deletetask      proc
		push    ax cx di
		mov     cx,size task
		xor     al,al
		rep     stosb
		pop     di cx ax
		ret
deletetask      endp
wword           proc
		push    ax dx es di
		call    convertword
		mov     es,video
		mov     di,80
		mov     es:[di],ah
		mov     es:[di+2],al
		mov     es:[di+4],dh
		mov     es:[di+6],dl
		pop     di es dx ax
		ret
wword           endp
Findfreetask    proc
		push    dx
		mov     es,taskarea
		xor     bx,bx
		mov     cx,taskavail
	isfreet:
		cmp     es:[bx].taskid,0
		je      thisisfree
		add     bx,size task
		loop    isfreet
		stc
		pop     dx
		ret
	thisisfree:
		mov     di,bx
		mov     ax,di
		xor     dx,dx
		mov     bx,size task    ;???
		div     bx
		inc     al
		clc
		pop     dx
		ret
Findfreetask    endp
mtrestore       proc
		call    idle
		lds     si,dosflag
		cmp     word ptr [si-1],0
		jne     mtrestore
		enterpcode
		mov	ready,0
		call    restore8259a
		mov     ax,3548h
		int     21h
		mov     byte ptr es:[bx-4],0    ; erase marker
		;cli
		lds     dx,old10
		mov     ax,2510h
		int     21h
		lds     dx,old13
		mov     ax,2513h
		int     21h
		lds     dx,old14
		mov     ax,2514h
		int     21h
		lds     dx,old15
		mov     ax,2515h
		int     21h
		lds     dx,old16
		mov     ax,2516h
		int     21h
		lds     dx,old1a
		mov     ax,251ah
		int     21h
		lds     dx,old1b
		mov     ax,251bh
		int     21h
		lds     dx,old21
		mov     ax,2521h
		int     21h
		lds     dx,old25
		mov     ax,2525h
		int     21h
		lds     dx,old26
		mov     ax,2526h
		int     21h
		lds     dx,old28
		mov     ax,2528h
		int     21h
		lds     dx,old2a
		mov     ax,252ah
		int     21h
		lds     dx,old2f
		mov     ax,252fh
		int     21h
		lds     dx,old33
		mov     ax,2533h
		int     21h
		lds     dx,old48
		mov     ax,2548h
		int     21h
		lds     dx,old5c
		mov     ax,255ch
		int     21h
		lds     dx,old67
		mov     ax,2567h
		int     21h
		lds     dx,old70
		mov     ax,2570h
		int     21h
		lds     dx,old71
		mov     ax,2571h
		int     21h
		lds     dx,old72
		mov     ax,2572h
		int     21h
		lds     dx,old73
		mov     ax,2573h
		int     21h
		lds     dx,old74
		mov     ax,2574h
		int     21h
		lds     dx,old75
		mov     ax,2575h
		int     21h
		lds     dx,old76
		mov     ax,2576h
		int     21h
		lds     dx,old77
		mov     ax,2577h
		int     21h
		les     di,oldlastdrv
		lds     si,ldptr
		mov     [si],di
		mov     [si+2],es
		lds     dx,rom13
		les     bx,rom13
		mov     ah,13h
		int     2fh
                cmp	oxmsstr,0
                je	noxmsres
                les	di,xmsdrvaddr
                movr	ds,cs
                lea	si,oxmsstr
                mov	cx,5
                cld
                cli
                rep	movsb
	noxmsres:
		sti
		mov     ax,taskarea
		call    FreeMemBlock
		mov     ax,Stacks
		call    FreeMemBlock
		mov     ax,Lastdrv
		call    FreeMemBlock
		mov     ax,Screens
		call    FreeMemBlock
                call	restoreirqbas
                mov	ah,0
                mov	al,startmode
                int	10h
		ret
mtrestore       endp
restoreirqbas	proc
		push	es ds di
		xor	ax,ax
                mov	ds,ax
                xor	bx,bx
		mov	bl,irqbase
                mov	di,bx
                shl	di,1
                shl	di,1
                mov	cx,16
                cld
                movr	es,ds
		rep	stosw
		pop	di ds es
		ret
restoreirqbas	endp
lerror		db	13,10,'Only 25x80 video mode is valid!',13,10,'$'
		include dbugmode.inc
code            ends
stckseg         segment para stack 'STACK'
		db      10h dup ('_STACK_ ')
eostck          label   word
		db	13,10,'! MSCREEN SWITCHES !',13,10
		db	'/sFIRST_WIN_SIZE_IN_KBYTES',13,10
                db	'/e - dont hide EMS',13,10
                db	'/tTICKS_FOR_TASK1:TICKS_FOR_TASK2',13,10
                db	'/vIRQ0_HEXADECIMAL_VECTOR',13,10
                db	'example:',13,10
                db	'mscreen /s300 /e /t9:6 /v80 task1.bat task2.bat',13,10,'$' 
stckseg         ends
		end

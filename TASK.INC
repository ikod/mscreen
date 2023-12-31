taskavail	equ	3	; total tasks available
STDTICK		equ	6	; standard ticks for task
DTASIZE		equ	1	; size of DOS DTA stuc
STACKFRAME	equ	80h	; standatd stack frame (in bytes)
SCREENSIZE	equ	25*160	; virtual 25x80 screen
HIPRIO		equ	3	; highest level of priority
;IRQBASE		equ	080h	; new IRQ for timer int
IENTRYS		equ	080h
MAXSWAP		equ	20h
LASTDRV_SIZE	equ	60h
; ------- task states ---------
ST_RUN		equ	0	; "Running or in run queue"
ST_WAIT		equ	1	; "Wait" for something
ST_HOLD		equ	2	; "Holded"
ST_DLAY		equ	3	; "Delay"
ST_DEAD		equ	-1	; "Killed"
; ------ task priorities ------
RT		equ	7	; realtime task - can't be interrupted - highest priority
RT_IO		equ	6	; realtime task with multiple io
IO_LTD		equ	5	;
MXED		equ	4	;
CPU_IO_LTD	equ	3	;
CPU_LTD		equ	2	;
; ---------- waitforwhats ------
WAIT_FOR_DOS		equ	1
WAIT_FOR_RESOURCE	equ	2
WAIT_FOR_MAIL		equ	3
WAIT_FOR_FLAG		equ	4
WAIT_FOR_CON		equ	5
regiss	struc
	rax	dw	0
        rbx	dw	0
        rcx	dw	0
        rdx	dw	0
        rsi	dw	0
        rdi	dw	0
        rbp	dw	0
	rsp	dw	0
	rds	dw	0
        res	dw	0
	rss	dw	0
	rip	dw	0
	rcs	dw	0
	flgs	dw	0
regiss	ends
atman		struc
	activetask	dw	0	; currently active task
	frontend	dw	0	; front end task
	privcode	db	0	; currently in privileged code
	sintlvl		db	0	; in software int 
        hintlvl		db	0	; in hardware int
	in_c		db	0	; in user critical section
atman		ends
mhint	equ	4
msint	equ	2
mlock	equ	1
queue	struc				; any kind queue of tasks
	cur_first	dw	-1
	cur_last	dw	-1
queue	ends
tskdsc	struc				; descriptor for add task
	tskofs		dw	0	; ip for start
	tskseg		dw	0	; cs for start
	tsktcks		db	STDTICK	; ticks
	startprio	db	0	;
	xtrnkbdo	dw	0	; external keyboard offset  for the task
	xtrnkbds	dw	0	; external keyboard segment for task
	xtrnvdio	dw	0	; external video offset
	xtrnvdis	dw	0	; external video segment
tskdsc	ends

task	struc
; 		- identification -
;		------------------
		taskid	db	0

; 		-     state	   -
;		------------------
		tstate	db	0
; 		-    priority	   -
;		------------------
		prio	db	0		; lowest priority

; 		-    queueing	   -
;		------------------
		tnext	dw	0		; next task
		tprev	dw	0		; prev task
		waitfor	dw	0,0		; waiting for what ?
	wait_for_what	db	0
        kbdexchange	dw	0		; buffer for single keystroke
	resources_owned	db	0		; how much resources own this task
; 		-  time related  -
;		------------------
		ticks	db	0		; 
		ltck	db	0		; how much leave until switch
		penalty	db	0		
; 		- task registers -
;		------------------
		tax	dw	0
        	tbx	dw	0
        	tcx	dw	0
        	tdx	dw	0
        	tsi	dw	0
        	tdi	dw	0
        	tbp	dw	0
		tsp	dw	0
		tds	dw	0
        	tes	dw	0
		tss	dw	0
		tcsip	dd	0
		tflags	dw	0

; -  substituted  - must be far proc or 0:0
;		------------------
		extkbd	dd	0		; external keyboard
		extvidi	dd	0		; external video

; 		-   environment  -
;		------------------
		sssp21	dd	0		; ss:sp on last dos call
        	psp	dw	0		; psp of this task
                swapdata db	MAXSWAP dup (0)	; dos swap data
		;int23hn	dd	0		; ctrl-brk handler address
		;int24hn	dd	0		; crit err handler address
		;dta	dd	0		; curr dta address
		;curdrv	db	0		; current drv
		;curdta	db	DTASIZE dup (0)	
                cpos	dw	0		; cursor position
                cshape	dw	0		; cursor shape
                barrv	dw	0		; barrier size
                itbl	dd	IENTRYS dup (0)	; interrupts
                vidir	db	0		; dirct video
		dying	db	0
		vmode	db	3		; current video mode
task	ends

inprivcode	macro				; in privileged code?
		cmp	taskman.privcode,1	; set Z if yes
		endm

islocked	macro
		test	word ptr cs:taskman.mainflags,mlock
		endm

Flag		struc		; flag: operations:
				; set,test,test_and_set,clear,wait
		value		db	0
		ftaskfirst	dw	-1
		ftasklast	dw	-1
		fname		db	8 dup (0)
Flag		ends

mailbox		struc		; mailbox: operations
				; send,wait,check
	env_first	dd	0	;- pointer to first envelope in box
	env_last	dd	0	;- pointer to last  envelope in box
	wait_first	dw	-1	;- first process that wait msg in box
	wait_last	dw	-1	;- last  process that wait msg in box
        mbname		db	8 dup (0)
mailbox		ends
envelop		struc			; envelope for message
	env_nxt		dd	0	;- pointer to next envelope
	env_prv		dd	0	;- pointer to prev envelope
	from_pid	dw	0	;- process-source
	msg		dd	0	;- pointer to message body
envelop		ends
resource	struc			; resource descriptor
		rflag	db	0
		rqueue	queue	<>
		rname	db	8 dup (0)
resource	ends
lock_rc		macro	r		; macro for locking resource
		push	ds si ax
		mov	ax, seg r
		mov	ds,ax
		mov	si,offset r
		call	catch_r
		pop	ax si ds
		endm
free_rc		macro r			; macro for release resource
		push	ds si ax
		mov	ax, seg r
		mov	ds,ax
		mov	si,offset r
		call	release_r
		pop	ax si ds
		endm
enterpcode	macro			; enter in privileged code
		local waitpc
		sti
		push	ax
		mov	al,1
waitpc:		xchg	cs:taskman.privcode,al
		cmp	al,1
                jz	waitpc
		pop	ax
		endm

leavepcode	macro			; leave privileged code
		mov	cs:taskman.privcode,0
		endm

movr		macro rd,rs
		push	rs
		pop	rd
		endm

pint		macro	oldv
		local	retpoint
                inc	taskman.in_c
		sub	sp,10
                push	bp
                push	ax
                mov	bp,sp
                mov	[bp+4],offset retpoint
                mov	[bp+6],cs
                mov	ax,[bp+18]
                mov	[bp+8],ax
		mov	ax,[bp+20]
                mov	[bp+10],ax
                mov	ax,[bp+22]
                mov	[bp+12],ax
                pop	ax
                pop	bp
                jmp	dword ptr [oldv]
retpoint:	sti
		push	bp
		push	ax
                pushf
                mov	bp,sp
                mov	ax,[bp]
                mov	[bp+14],ax
                mov	ax,[bp+6]
                mov	[bp+16],ax
                mov	ax,[bp+8]
                mov	[bp+18],ax
                dec	taskman.in_c
                popf
                pop	ax
                pop	bp
                add	sp,4
                iret
                endm  
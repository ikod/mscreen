code		segment	public
		assume	cs:code
Public		SETARGV,NextArgV
SETARGV        Proc
		;
		; Returns : DS points to PSP segment
                ;	  : DX points to next ARGV in PSP segment if CF clear.
                ;
		push	ax
		push	bx
                push	cx
		mov	ah,62h
                int	21h
                mov	ds,bx
		mov	bx,cs:NextArgV
                or	bx,bx
                jnz	GetNext
                mov	bx,81h
                mov	dx,bx
GetNext:	mov	cl,ds:80h
		xor	ch,ch
                add	cx,80h
Begloop:	cmp	bx,cx
		ja	NotF
                mov	al,[bx]
                inc	bx
                cmp	al,' '
		jbe	Begloop
                mov	dx,bx
                dec	dx
                inc	cx
Endloop:	cmp	bx,cx
		ja	NotF
                mov	al,[bx]
                inc	bx
                cmp	al,' '
                ja	Endloop
                mov	byte ptr [bx-1],0
                clc
                jmp	short found
NotF:           stc
Found:		mov	cs:NextArgV,bx
		pop	cx
                pop	bx
                pop	ax
                ret

NextArgV	DW	0

SETARGV        EndP

code		Ends
		end

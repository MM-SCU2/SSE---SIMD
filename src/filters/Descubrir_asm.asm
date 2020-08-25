section .rodata
					 ;xmm: |t|r|g|b|
mask:         times 4 dd 0x00030303 
saturacion:   times 4 dd 0XFF000000
mask_bits:    times 16 db 0x01


Shuffle_B:	dq 0x0C080400
Shuffle_R: 	dq 0x0E0A0602
Shuffle_G:	dq 0x0D090501

Copiar: db 0x00, 0x00, 0x00, 0x00, 0x01, 0x1, 0x1, 0x1, 0x2, 0x2, 0x2, 0x2, 0x3, 0x3, 0x3, 0x3
		

section .text
global Descubrir_asm

Descubrir_asm:
;RDI <- uint8_t *src
;RSI <- uint8_t *dst
;EDX <- int width 
;ECX <- int height
;R8  <-	src_row_size
;R9  <- dst_row_size 

push RBP
mov RBP, RSP

imul RDX, RCX 				
lea R10, [RDI + RDX*4] 		; R10 <- final de la matriz 
sub R10, 16
shr RDX, 2 					
xor R9, R9 					; R9 <- contador fila
	

	movdqu xmm15, [mask]
	
	movdqu xmm14, [Shuffle_G]
	movdqu xmm13, [Shuffle_R]
	movdqu xmm12, [Shuffle_B]

	movdqu xmm11, [Copiar]
	movdqu xmm9, [saturacion]

.Ciclo:
	
	;imagen
	movdqu xmm4, [RDI + R9] 	; xmm0 <- src

	;nos quedamos con los dos bits menos sig
	pand xmm4, xmm15

	;espejo
	movdqu xmm5, [R10]			; xmm5 <- srcMirror

.ShuffleMirror:
	pshufd xmm5, xmm5 , 0x1B
	;00011011

	;(src[(height-1)-i][(width-1)-j].x >> 2
	psrlw xmm5, 2
	pand xmm5, xmm15

	;((src[(height-1)-i][(width-1)-j].x >> 2) ^ src[i][j].x) & 0x3
	pxor xmm4, xmm5

	movdqu xmm1, xmm4
	movdqu xmm2, xmm4

.OrdenamosColor:
	pshufb xmm1, xmm14 	;g
	pshufb xmm2, xmm13  ;r
	pshufb xmm4, xmm12  ;b

 .bitX:
	movdqu xmm10, [mask_bits]
	
	movdqu xmm6, xmm4 	;|000000b4b7|
	pand xmm4, xmm10 	;|0000000b7| 
	psllw xmm4, 7   	;|b70000000| 

	movdqu xmm8, xmm1 	;|000000b3b6|
	pand xmm1, xmm10 	;|0000000b6|
	psllw xmm1, 6 		;|0b6000000|

	movdqu xmm7, xmm2	;|000000b2b5|
	pand xmm2, xmm10 	;|0000000b5| 
	psllw xmm2, 5		;|00b500000| 

	psllw xmm10, 1		;|00000010|

	pand xmm6, xmm10	;|0000000b4|
	psllw xmm6, 3	 	;|000b40000|
	
	pand xmm8, xmm10	;|0000000b3|
	psllw xmm8, 2 		;|0000b3000|
	
	pand xmm7, xmm10	;|0000000b2|
	psllw xmm7, 1  		;|000000b200|

 .defino_Color:
	por xmm4, xmm1 		;|b7b6000000|
	por xmm4, xmm2		;|b7b6b500000|
	por xmm4, xmm6 		;|b7b6b5b40000|
	por xmm4, xmm8 		;|b7b6b5b4b3000|
	por xmm4, xmm7   	;|b7b6b5b4b3b200|

 .duplicamos:
	pshufb xmm4, xmm11
	
.Guardo:
	por xmm4, xmm9
	movdqu [RSI + R9], xmm4

	add R9,16
	sub r10, 16
	dec RDX
	cmp RDX, 0
	jne .Ciclo

.fin:

pop RBP
ret


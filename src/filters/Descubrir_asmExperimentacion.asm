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
;EDX <- int width 320
;ECX <- int height 1c2
;R8  <-	src_row_size c80
;R9  <- dst_row_size 

push RBP
mov RBP, RSP
push RBX
push r12
push r13
push r14
push r15
sub rsp, 16

imul RDX, RCX 				
lea R10, [RDI + RDX*4] 		; R10 <- final de la matriz 
sub R10, 16
shr RDX, 2 					
xor R9, R9 					; R9 <- contador fila
	
	mov ebx, ecx
	mov r12, RSI
	mov r13, RDI
	mov r15, r10  	;para restaurar
	xor rax, rax
	xor r14, r14

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

	add R9, R8  ;rdi y rsi en la sig fila
	sub r10, R8 ;r10 a la sig fila
	
	dec ebx
	cmp ebx, 1
	jne .Ciclo

	;cambio columna
	cmp r14, r8
	je .fin

	mov ebx, ecx ;reestablezco el cont para la altura

	xor r9, R9 	;reestablezco cont rdi y rsi

	mov rdi, r13 ;voy al principio
	mov rsi, r12 ;voy al principio
	mov r10, r15 ;voy para abajo
	
	add r14, 16

	add rdi, r14
	add rsi, r14
	sub r10, r14

	jmp .Ciclo


.fin:
add rsp, 16
pop r15
pop r14
pop r13
pop r12
pop rbx
pop RBP
ret
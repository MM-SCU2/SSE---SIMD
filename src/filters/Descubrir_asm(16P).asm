section .rodata
mask: 			 		times 4 dd 0x00030303
saturacion: 			times 4 dd 0xff000000
mask_bits: 		 		times 16 db 0x01

Shuffle_GB: dq 0x0D0905010C080400
Shuffle_TR: dq 0x0F0B07030E0A0602
Copiar_H:  	dq 0x0303030302020202
Copiar_L:   dq 0x0101010100000000

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

shr EDX, 4

movdqu xmm15, [mask]

movq xmm14, [Shuffle_TR]
pslldq xmm14, 8
movq xmm9, [Shuffle_GB]
por xmm14, xmm9

movdqu xmm12, [mask_bits]

movq xmm13, [Copiar_H]
pslldq xmm13, 8
movq xmm9, [Copiar_L]
por xmm13, xmm9


.ciclo:
; imagen src
movdqu xmm0, [RDI]
add RDI, 16
movdqu xmm1, [RDI]
add RDI, 16
movdqu xmm2, [RDI]
add RDI, 16
movdqu xmm3, [RDI]
add RDI, 16

;nos quedamos con los dos bits menos sig
pand xmm0, xmm15
pand xmm1, xmm15
pand xmm2, xmm15
pand xmm3, xmm15

;imagen mirror
movdqu xmm4, [R10]
sub R10, 16
movdqu xmm5, [R10]
sub R10, 16
movdqu xmm6, [R10]
sub R10, 16
movdqu xmm7, [R10]
sub R10, 16

.ShuffleMirror:
pshufd xmm4, xmm4, 00011011b
pshufd xmm5, xmm5, 00011011b
pshufd xmm6, xmm6, 00011011b
pshufd xmm7, xmm7, 00011011b


;(src[(height-1)-i][(width-1)-j].b >> 2
psrlw xmm4, 2
psrlw xmm5, 2
psrlw xmm6, 2
psrlw xmm7, 2

;& 0x3
pand xmm4, xmm15
pand xmm5, xmm15
pand xmm6, xmm15
pand xmm7, xmm15

;((src[(height-1)-i][(width-1)-j].x >> 2) ^ src[i][j].x) & 0x3
pxor xmm0, xmm4
pxor xmm1, xmm5
pxor xmm2, xmm6
pxor xmm3, xmm7


pshufb xmm0, xmm14
pshufb xmm1, xmm14 
pshufb xmm2, xmm14
pshufb xmm3, xmm14

;Tenemos esto:
;|0|0|0|0|00000b2b5|00000b2b5|00000b2b5|00000b2b5|00000b3b6|00000b3b6|00000b3b6|00000b3b6|000000b4b7|000000b4b7|000000b4b7|000000b4b7|

.OrdenamosColor:
movdqu xmm8, xmm0
movdqu xmm9, xmm0

;unimos xmm0 con xmm1
punpckldq xmm8, xmm1 ; |00000b3b6|00000b3b6|00000b3b6|00000b3b6|00000b3b6|00000b3b6|00000b3b6|00000b3b6|000000b4b7|000000b4b7|000000b4b7|000000b4b7|000000b4b7|000000b4b7|000000b4b7|000000b4b7|
punpckhdq xmm9, xmm1 ; |0		 |0		   |0		 |0		   |0		 |0		   |0		 |0		   |000000b2b5|000000b2b5|000000b2b5|000000b2b5|000000b2b5|000000b2b5|000000b2b5|000000b2b5|

movdqu xmm10, xmm2
movdqu xmm11, xmm2

;unimos xmm2, xmm3
punpckldq xmm10, xmm3 ; |000000b3b6|000000b3b6|000000b3b6|...
punpckhdq xmm11, xmm3 ; |0		   |0         |0		 |0		   |0		 |0		   |0		 |0	

movdqu xmm7, xmm8
movdqu xmm6, xmm8

;ahora dejamos todos los 
;azules en un solo reg
punpcklqdq xmm7, xmm10 ; |000000b4b7|x16

;verdes en un solo reg
punpckhqdq xmm6, xmm10 ; |000000b3b6|x16

movdqu xmm5, xmm9
movdqu xmm4, xmm9

;rojos en un solo reg
punpcklqdq xmm5, xmm11 ;|000000b2b5|


;Ahora seleccionamos los bits 
.bitX_Y_defino_Color:
movdqu xmm0, xmm7
pand xmm0, xmm12 ;|0000000b7| x16
psllw xmm0, 7   ;|b70000000| x16

movdqu xmm1, xmm6
pand xmm1, xmm12 ;|0000000b6| x16
psllw xmm1, 6
por xmm0, xmm1 	;|b7b6000000| x16

movdqu xmm2, xmm5
pand xmm2, xmm12
psllw xmm2, 5
por xmm0, xmm2 ;|b7b6b500000| x16

psllw xmm12, 1 ;|00000010| x16

movdqu xmm3, xmm7
pand xmm3, xmm12
psllw xmm3, 3
por xmm0, xmm3 ; |b7b6b5b40000| x16

movdqu xmm1,xmm6
pand xmm1, xmm12
psllw xmm1, 2
por xmm0, xmm1

movdqu xmm2, xmm5
pand xmm2, xmm12
psllw xmm2, 1
por xmm0, xmm2 ; |b7b6b5b4b3b200| x16

;lo volvemos a dejar como estaba
psrlw xmm12, 1 ;|00000001| x16

.duplicamos:
movdqu xmm1, xmm0
pshufb xmm1, xmm13

;sig pixeles
psrldq xmm0, 4
movdqu xmm2, xmm0
pshufb xmm2, xmm13

;avanzo
psrldq xmm0, 4
movdqu xmm3, xmm0
pshufb xmm3, xmm13

;ultimos
psrldq xmm0, 4
movdqu xmm4, xmm0
pshufb xmm4, xmm13

.Guardo:
;transparecia
movdqu xmm0, [saturacion]

por xmm1, xmm0
por xmm2, xmm0
por xmm3, xmm0
por xmm4, xmm0

;guardo
movdqu [RSI], xmm1
add RSI, 16
movdqu [RSI], xmm2
add RSI, 16
movdqu [RSI], xmm3
add RSI, 16
movdqu [RSI], xmm4
add RSI, 16

dec RDX
cmp RDX, 0
je .fin
jmp .ciclo

.fin:
pop RBP
ret

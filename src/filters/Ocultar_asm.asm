global Ocultar_asm

section .rodata 

mask_Blue: times 4 dd 0x000000ff
mask_Green: times 4 dd 0x0000ff00
mask_Red: times 4 dd 0x00ff0000

mask_byte: db 0x00, 0x00 ,0x00 ,0x00, 0x02, 0x02, 0x02, 0x02, 0x04, 0x04, 0x04, 0x04, 0x06, 0x06, 0x06, 0x06

mask_bits:    times 16 db 0x01
finalMASK: 	  times 4  dd 0x03030303 
maskdestino:  times 16 db 0xFC
saturacion:   times 4 dd 0XFF000000		; para generar la saturacion en alfa

mascaraAntiAlfas: times 4 dd 0x00ffffff	 
Obtener_Verdes:   dw 0x0000,0xFFFF,0x0000,0x0000,0x0000,0xFFFF,0x0000,0x0000

section .text

; rdi , imagen destino 
; rsi , imagen a ocultar, cambiarla a tono de grises 
; rdx , puntero a destino 
; rcx , width 
; r8  , height 
; r9   

; |  pixel 3 |  pixel 2 | pixel 1 | pixel 0  | ..... 
; |t|r|g | b | t|r|g|b  | t|r |g|b| t|r|g | b|

Ocultar_asm:
	push rbp
	mov rbp,rsp 

    ;para levantar los pixeles espejo, 
    ;alcanza con ir al final de la matriz y restar 16
    imul rcx, r8
    lea r10 , [rdi + rcx*4]

    shr rcx,2

	movdqu xmm15,[Obtener_Verdes] 	
	movdqu xmm14,[mascaraAntiAlfas]
	movdqu xmm13,[mask_bits]
	movdqu xmm12,[mask_byte]
	movdqu xmm11,[finalMASK]		
	movdqu xmm10,[maskdestino]
	
	.ciclo:
	cmp rcx,0
	je .fin 
	
	movdqu xmm0,[rsi] 				; guardo los primeros pixeles 
	
	movdqu xmm2,xmm0				; guardo para aplicar la mascara
	movdqu xmm5,xmm0
	
	pand xmm2 , xmm14
	pand xmm5,xmm14

	pxor xmm3, xmm3 				; limpio, para parte baja  
	pxor xmm4, xmm4 				; limpio, para parte alta 
	
	; parte baja 
	PUNPCKLBW xmm2,xmm3				; desenpaqueto para guardar parte BAJA 
	movdqu xmm3,xmm2 				; xmm3 se guarda una copia  del desenpaquetado
	pand xmm2,xmm15				    ; mascara para conseguir los verdes 		
	paddw xmm3 , xmm2  				; sumamos para tener 2 * g 

	;parte alta 
	PUNPCKHBW xmm5 , xmm4 			; desenpaqueto para guardar parte alta  
	movdqu xmm4, xmm5 				; xmm3 se guarda una copia  del desenpaquetado
	pand xmm5,xmm15				    ; mascara para conseguir los verdes 		
	paddw xmm4 , xmm5  				; sumamos para tener 2 * g	 

	;sumas horizontales
       
	phaddw xmm3,xmm4                

	pxor xmm5, xmm5 				; limpio para que queden ceros en la parte alta de xmm3 al hacer sumas horizontales 
	phaddw xmm3,xmm5
 
    psrlw xmm3,2 					; divido por 4 las words para completar la formula 

    pshufb xmm3,xmm12 	 			; repito la escala asi queda gris entodas sus componentes 



; +++++++++++++===~~~~~~~~~~~~~~~~~~~~~~ PROCESAMIENTO DE LOS BITS ~~~~~~~~~~~~~==+++++++++++++++


	;pixeles de imagen destino 
	movdqu xmm4 , [rdi]

    ;pixeles espejo 
 	sub r10,16
    movdqu xmm5, [r10] 

    ;mirror
 	pshufd xmm5, xmm5 ,0X1B
 	
    ;bitsB
    movdqu xmm1,xmm3
    ;bitsG
    movdqu xmm2,xmm3
    ;bitsR
    movdqu xmm6,xmm3

 	
 	movdqu xmm8,xmm4  	;xmm8 <- SRC
 	movdqu xmm9,xmm5 	;xmm9 <- mirror
 	movdqu xmm0,xmm1	;xmm0 <- grises
 	movdqu xmm3,[mask_Blue] 				 

 	pand xmm0,xmm3		;entre grises y azules
 	pand xmm1,xmm3	 	;entre grises y azules
 	pand xmm9,xmm3 		;entre mirror y azules
 	pand xmm8,xmm3		;entre src y azules	

 	;shifteos

 	psrlw xmm0,4 
 	pand xmm0 ,xmm13
 	psllw xmm0,1
 	psrlw xmm1,7
 	pand xmm1,xmm13	;extraer ultimo bit

 	;oeperacion sobre ultimos bit y mirror 

 	por xmm1 , xmm0
 	pand xmm1,xmm11 
 	psrlw xmm9,2
 	pand xmm9,xmm11 
 	;operacion azul sobre imagen destino
 
 	pand xmm8,xmm10 
 	;operacion final 

 	pxor xmm1,xmm9
 	paddb xmm1,xmm8


 	;operacion sobre bits verdes 
 	;shifteo para que se acomode la escala de gris a la posicion de los verdes 

 	;extraigo los "verdes" de todos los registros 
 	movdqu xmm3,[mask_Green]
 	movdqu xmm8,xmm4 		;destino
 	movdqu xmm9,xmm5		;mirror
 	movdqu xmm7,xmm2		;bits 6 y 3
 	pand xmm8,xmm3
 	pand xmm9,xmm3
 	pand xmm2,xmm3
 	pand xmm7,xmm3

 	;operaciones aritmeticas 


 	;shifteos 
 	psrlw  xmm2,3
 	pand   xmm2,xmm13
 	psllw  xmm2,1
 	psrlw  xmm7,6
 	pand   xmm7,xmm13

 	por xmm2,xmm7
 	pand xmm2,xmm11
 	psrlw xmm9,2
 	pand xmm9,xmm11

 	;operacion verde sobre imagen destino 

 	pand xmm8,xmm10 

 	;operacion final
 	pxor xmm2,xmm9
 	paddb xmm2,xmm8 


 	;operacion sobre bits rojos  
 	; no hace falta shiftear ya estan acomodados

 	movdqu xmm3,[mask_Red]
 	movdqu xmm9,xmm5 	;mirror 
 	movdqu xmm7,xmm6
 	movdqu xmm8,xmm4	;fuente 
 	pand xmm6,xmm3
 	pand xmm7,xmm3
 	pand xmm8,xmm3
 	pand xmm9,xmm3
 	;operaciones aritmeticas
 	;shifteos
 
 	psrlw  xmm6,2
 	pand   xmm6,xmm13 
 	psllw  xmm6,1
 	psrlw  xmm7,5
 	pand   xmm7,xmm13



 	por xmm6,xmm7
 	pand xmm6,xmm11 
 	psrlw xmm9,2
 	pand xmm9,xmm11 
	;operaciones rojas sobre imagen destino 

 	pand xmm8,xmm10 

 	;operacion final 
 	pxor xmm6,xmm9
 	paddb xmm6,xmm8

 	;unir todos
 	por xmm1,xmm2
 	por xmm1,xmm6

 	movdqu xmm5,[saturacion]
 	paddusb xmm1,xmm5
 	movdqu [rdx],xmm1

 	
 	add rdi,16
 	add rsi,16
 	add rdx,16

 	sub rcx,1

 	jmp .ciclo

 	.fin:
	
	pop rbp
ret

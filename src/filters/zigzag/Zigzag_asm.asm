global Zigzag_asm


section .rodata


blanqueamiento: times 4 dd  0xffffffff
bordeizquierdo:   dd   0xffffffff,0xffffffff,0x00000000,0x00000000 
bordeDerecho:   dd 	0x00000000,0x00000000,0xffffffff,0xffffffff
aclarar: times 4 dd 0xff000000
filtroPixeles01:dd 0xffffffff,0xffffffff,0x00000000,0x00000000 
filtroPixeles23:dd 0x00000000,0x00000000, 0xffffffff,0xffffffff 
mascaraAntiAlfas: times 4 dd 0x00ffffff	
division_por_5: times 4 DD 5.0
patron : times 4 dd 0x000000ff


mascaraP1: db   0x00,0x04,0x08,0x80, 0x80,0x80,0x80,0x80,  0x80,0x80,0x80,0x80, 0x80,0x80,0x80,0x80
mascaraP2: db   0x80,0x80,0x80,0x80, 0x00,0x04,0x08,0x80, 0x80,0x80,0x80,0x80, 0x80,0x80,0x80,0x80
mascaraP3: db   0x80,0x80,0x80,0x80, 0x80,0x80,0x80,0x80, 0x00,0x04,0x08,0x80, 0x80,0x80,0x80,0x80
mascaraP4: db   0x80,0x80,0x80,0x80, 0x80,0x80,0x80,0x80, 0x80,0x80,0x80,0x80, 0x00,0x04,0x08,0x80



section .text


; rdi , puntero a src (foto a modificar)
; rsi , puntero a destino (lugar a guardar la foto)
; rdx , width (columna)
; rcx , heigth (filas)
; r8 , row size src
; r9 , row size destino

Zigzag_asm:
	push rbp
	mov rbp,rsp 
	push rbx 
	push r12

	mov rbx, rdi 		;para conservar el puntero a src, va a ser necesario para pintar de blanco al final 
	mov r12, rsi		;misma logica para el puntero destino 
	mov r8 , rcx



	;el ciclo principal se mueve segun la cantidad de filas
	;inicializo variable contador de columnas
	xor r10,r10

	movdqu xmm12, [mascaraP1]
	movdqu xmm13, [mascaraP2]
	movdqu xmm14, [mascaraP3]
	movdqu xmm15, [mascaraP4]


.loopPrincipal: 
	cmp rcx , 0
	je .fin
	;ahora armo los casos  
	cmp r10,0	;caso fila congruente a mod 0 
	je .modCeroyDos
	cmp r10,1
	je .modUno
	cmp r10,2
	je .modCeroyDos

; si llego aca es porque es una columna congruente a modulo 3
; me ahorro el salto y romper el pipeline (aun mas) simplemente poniendolo aca 


;~~~~~~~~~~~~~~ /////////////////// columnas modulo 3 //////////////////~~~~~~~~~~~~~

.modTRes:
	mov r11,rdx
	shr r11,2
	sub r11,2 

	movdqu xmm0,[rdi]
	movdqu xmm1,[rdi+16]
	movdqu xmm2,[aclarar]
	pslldq xmm1,8 
	psrldq xmm0,8
	por xmm0,xmm1
	por xmm0,xmm2

	movdqu xmm2,[bordeizquierdo]

	por xmm0,xmm2

	;movdqu xmm0,[patron]
	movdqu [rsi],xmm0

	add rsi,16
	add rdi,16			


.loopTres:
	movdqu xmm0,[rdi]
	movdqu xmm1,[rdi+16]

	psrldq xmm0,8	;| 0 | 0 | P3 | P2 |

	;shifteo a izquierda 8 para hacer el or 
	pslldq xmm1,8 
	por xmm0,xmm1 ; resultado del mergeo

	movdqu xmm1,[aclarar]
	paddusb xmm0,xmm1 


	movdqu [rsi],xmm0 
	
	add rdi,16
	add rsi,16
	sub r11,1
	cmp r11,0
	jnz .loopTres

	; la ultima parte se hace afuera para evitar problemas de seg fault 

	movdqu xmm0,[rdi] 				
 	psrldq xmm0,8					

 	movdqu xmm1,[aclarar]
	por xmm0,xmm1

	movdqu xmm1,[bordeDerecho]
	por xmm0,xmm1

	movdqu [rsi],xmm0

	add rdi,16			
	add rsi,16


	xor r10,r10		   ;reinicia el conteo 
	sub rcx,1
	jmp .loopPrincipal


;~~~~~~~~~~~~~~ /////////////////// columnas modulo 0 //////////////////~~~~~~~~~~~~~


.modCeroyDos:

;   ~~~~~~~~~~~~~~~~++++++++++++++ ENTRADA A LAS FILAS MOD 0 y 2 +++++++++++~~~~~~~~~~~~~~~~~~~~~~

	;este ciclo itera levantando de a 8 desde el puntero rdi,  
	mov r11,rdx
	shr r11,2
	sub r11,2		; ignora los ultimos 8 pixeles y los primeros 4, pueden dar seg fault, de hecho lo hacen  


 	movdqu xmm0,[rdi]
 	movdqu xmm1,[rdi +16]
 	movdqu xmm11,xmm0 

	; primero extiendo los colores pixeles de xmm1 a 32 bits, quedan en registros separados logicamente
	; le saco los alfas para mas comodidad, al final se los satura a 255

	movdqu xmm6,[mascaraAntiAlfas]
	pand xmm1 ,xmm6
	pand xmm0,xmm6 

	; primero la parte baja, pasa a word

	pxor xmm3, xmm3 				; limpio , para parte baja  
	; parte baja 
	PUNPCKLBW xmm0,xmm3				; desenpaqueto para guardar parte BAJA
	movdqu xmm4,xmm0 				; guardo para no perder el desempaquetado, ya que tngo que repetir con la parte alta
 

	; bien, ahora tengo que pasarlo a 32 bits, de nuevo primero la parte baja seria el pixel 0
	PUNPCKLWD xmm4,xmm3
	
	;repito para parte alta del desempaqueado 
	PUNPCKHWD xmm0,xmm3
	movdqu xmm3,xmm0 

	movdqu xmm10,xmm4
	movdqu xmm4,xmm3
	movdqu xmm3,xmm10 

	;repito todo este quilombo para la parte alta de xmm0,
	movdqu xmm0,xmm11

	pxor xmm6, xmm6 			
	
	; parte alta 
	PUNPCKHBW xmm0,xmm6			
	movdqu xmm5,xmm0 				

	PUNPCKLWD xmm5,xmm6
	
	;repito para parte alta del desempaquetado, seria el pixel 3 el que queda aqui 
	PUNPCKHWD xmm0,xmm6
	movdqu xmm6,xmm0


	;convierto la parte baja de xmm1

	pxor xmm8,xmm8

	PUNPCKLBW xmm1,xmm8				; desenpaqueto para guardar parte baja de xmm1
	movdqu xmm7,xmm1 


	; al igual que antes separo los colores extendidos a 32 para la parte alta y baja 


	;parte baja del desempaquetado  
	PUNPCKLWD xmm1,xmm8 		;pixel 4


	;parte alta del desempaquetado

	PUNPCKHWD xmm7,xmm8 		;pixel 5

 	paddd xmm5, xmm3 
 	paddd xmm5, xmm4
 	paddd xmm5, xmm6 
 	paddd xmm5, xmm1 

 	; sumas con p3
 	; estas son p1 + p2 + p4  + p5 + p3
 	; lo mismo con xmm4

 	movdqu xmm6,xmm5 
 	psubd  xmm6,xmm3 
 	paddd  xmm6,xmm7  

	; divisiones 
    CVTDQ2PS xmm5,xmm5
    CVTDQ2PS xmm6,xmm6

    movdqu xmm0,[division_por_5]
    
    divps xmm5,xmm0
    divps xmm6,xmm0

    cvttps2dq xmm5,xmm5
    cvttps2dq xmm6,xmm6

 	; acomodar en xmm0 y ver si esta bien 
 	pxor xmm0,xmm0
 	movdqu xmm1,[mascaraP3]
 	pshufb xmm5,xmm1
 	por xmm0,xmm5
 	movdqu xmm1,[mascaraP4]
 	pshufb xmm6,xmm1 
 	por xmm0,xmm6 

 	movdqu xmm1,[aclarar] 
 	por xmm0,xmm1 


	movdqu xmm2,[bordeizquierdo]
	por xmm0,xmm2
 	
 	movdqu [rsi],xmm0

 	add rsi,16


.loopCero:

	movdqu xmm0,[rdi]
	movdqu xmm1,[rdi+16]
	movdqu xmm2,[rdi+32]


	movdqu xmm6,[mascaraAntiAlfas]
	pand xmm1 ,xmm6
	pand xmm0,xmm6 
	pand xmm2,xmm6 			; sirve para mas adelante
	movdqu xmm11,xmm1 


	; primero la parte baja, pasa a word
	pxor xmm3, xmm3 				

	; parte baja 
	PUNPCKLBW xmm1,xmm3				
	movdqu xmm4,xmm1 				

	;pasarlo a 32 bits
	PUNPCKLWD xmm4,xmm3
	
	;repito para parte alta del desempaqueado 
	PUNPCKHWD xmm1,xmm3
	movdqu xmm3,xmm1 

	movdqu xmm10,xmm3
	movdqu xmm3,xmm4
	movdqu xmm4,xmm10 

	;repito todo este quilombo para la parte alta de xmm1,
	movdqu xmm1,xmm11

	pxor xmm6, xmm6 				; limpio, para parte alta  
	
	; parte alta 
	PUNPCKHBW xmm1,xmm6				; desenpaqueto para guardar parte alta de xmm1
	movdqu xmm5,xmm1 		

	;Ahora tengo que pasarlo a 32 bits
	PUNPCKLWD xmm5,xmm6
	
	;repito para parte alta del desempaquetado, seria el pixel 3 el que queda aqui 
	PUNPCKHWD xmm1,xmm6
	movdqu xmm6,xmm1

	;primero convierto la parte alta de xmm0

	pxor xmm1,xmm1

	PUNPCKHBW xmm0,xmm1				; desenpaqueto para guardar parte alta de xmm1
	movdqu xmm7,xmm0 


	; al igual que antes separo los colores extendidos a 32 para la parte alta y baja 


	;parte baja del desempaquetado  
	PUNPCKLWD xmm0,xmm1 		;pixel 2


	;parte alta del desempaquetado
	PUNPCKHWD xmm7,xmm1 		;pixel 3

 	;necesito el valor original de xmm3 para mas adelante, asi que lo guardo 
 	movdqu xmm8,xmm3

 	paddd xmm3,xmm4
 	paddd xmm3,xmm5
 	paddd xmm3,xmm0
 	paddd xmm3,xmm7 

 	; lo mismo con xmm4 
 	movdqu xmm9,xmm4 

 	paddd xmm4,xmm8
 	paddd xmm4,xmm5
 	paddd xmm4,xmm6
 	paddd xmm4,xmm7

 	;faltan las divisiones 


 	; ahora tengo que extraer la parte baja de xmm2 

 	pxor xmm1,xmm1

	PUNPCKLBW xmm2,xmm1				; desenpaqueto para guardar parte alta de xmm1
	movdqu xmm7,xmm2 


	; al igual que antes separo los colores extendidos a 32 para la parte alta y baja 


	;parte baja del desempaquetado  
	PUNPCKLWD xmm2,xmm1 		;pixel 8


	;parte alta del desempaquetado

	PUNPCKHWD xmm7,xmm1 		

 	;empiezo con p6
 	movdqu xmm10,xmm5



 	paddd xmm5,xmm8
 	paddd xmm5,xmm9
 	paddd xmm5,xmm6 
 	paddd xmm5,xmm2

 	;sigo con p7 
 	;necesito p5,p6,p7,p8,p9

 	paddd xmm6,xmm9
 	paddd xmm6,xmm10
 	paddd xmm6,xmm2
 	paddd xmm6,xmm7

 	; xmm3 = p4       
 	; xmm4 = p5 	   
 	; xmm5 = p6 
 	; xmm6 = p7

 	; hay que dividir estos capos por 5, podria hacer muchas cosas, voy a convertirlos a float y usar division de flotantes
    CVTDQ2PS xmm3,xmm3
    CVTDQ2PS xmm4,xmm4
    CVTDQ2PS xmm5,xmm5
    CVTDQ2PS xmm6,xmm6


    movdqu xmm0,[division_por_5]
    
    divps xmm3,xmm0
    divps xmm4,xmm0
    divps xmm5,xmm0
    divps xmm6,xmm0

    cvttps2dq xmm3,xmm3
    cvttps2dq xmm4,xmm4
    cvttps2dq xmm5,xmm5
    cvttps2dq xmm6,xmm6

    ; ahora hay que unir todo de vuelta
 	;vamos guardando en xmm0 y cargamos la mascara en xmm1
 	pxor xmm0,xmm0


 	pshufb xmm3,xmm12
 	por xmm0,xmm3 

 	pshufb xmm4,xmm13
 	por xmm0,xmm4

 	pshufb xmm5,xmm14
 	por xmm0,xmm5

 	pshufb xmm6,xmm15
 	por xmm0,xmm6 

 	;ponele que ya esta
 	movdqu xmm1,[aclarar]
 	por xmm0,xmm1


	movdqu [rsi],xmm0  
	
	add rdi,16
	add rsi,16
	sub r11,1
	cmp r11,0
	jnz .loopCero
;											TERMINACION DE LOOP 0	
; ~~~~~~~~~~~~~~~~++++++++++++ MODIFICACION DE LOS ULTIMOS PIXELES ++++++++++++~~~~~~~~~~~~~~~~~~~~


	movdqu xmm0,[rdi]
	movdqu xmm1,[rdi+16]

	;en xmm1 esta la ultima tanda 

	;remuevo alfas 
	movdqu xmm2,[mascaraAntiAlfas]
	pand xmm0,xmm2 
	pand xmm1,xmm2
	movdqu xmm11,xmm1 

	;parte alta xmm0 
	pxor xmm8,xmm8
	punpckhbw xmm0,xmm8
	movdqu xmm2,xmm0
	; P2
	punpcklwd xmm2,xmm8

	; P3
	movdqu xmm3,xmm0
	punpckhwd xmm3,xmm8


	pxor xmm0,xmm0 
	; parte baja 
	punpcklbw xmm1,xmm0 
	movdqu xmm4,xmm1
	;parte alta 
	punpckhbw xmm11,xmm0 
	movdqu xmm5,xmm11 

	;convierto a 32 

	; P4 
	punpcklwd xmm4,xmm0 

	;P5
	movdqu xmm5,xmm1 
	punpckhwd xmm5,xmm0 

	;P6
	movdqu xmm6, xmm11 
	punpcklwd xmm6,xmm0 

	;P7 
	movdqu xmm7,xmm11
	punpckhwd xmm7,xmm0 
	;Sumas y divisiones 

	; P4 
	paddd xmm4,xmm2 
	paddd xmm4,xmm3 
	paddd xmm4,xmm5 
	paddd xmm4,xmm6

	; P5
	movdqu xmm5,xmm4 
	psubd  xmm5,xmm2 
	paddd  xmm5,xmm7

	cvtdq2ps xmm4,xmm4 
	cvtdq2ps xmm5,xmm5  

	movdqu xmm0,[division_por_5]

	divps xmm4,xmm0 
	divps xmm5,xmm0 

	cvttps2dq xmm4,xmm4 
	cvttps2dq xmm5,xmm5 

	pshufb xmm4,xmm12
	pshufb xmm5,xmm13 

	pxor xmm0,xmm0 
	por xmm0,xmm4 
	por xmm0,xmm5 

	movdqu xmm1,[aclarar]
	por xmm0,xmm1 
	movdqu xmm1,[bordeDerecho]
	por xmm0,xmm1 

	movdqu [rsi],xmm0 


	add rdi,32 
	add rsi,16
	add r10,1
	sub rcx,1
	jmp .loopPrincipal


;~~~~~~~~~~~~~~ /////////////////// columnas modulo 1 //////////////////~~~~~~~~~~~~~

.modUno:
	mov r11,rdx
	shr r11,2
	sub r11,2 

	movdqu xmm0,[rdi]
  	pslldq xmm0, 8 ;|P1|P0|0|0
  
   movdqu xmm1, [aclarar]
   por xmm0,xmm1


   movdqu xmm2, [bordeizquierdo]

   por xmm0, xmm2

   movdqu [rsi],xmm0
   add rsi,16


.loopUno:
	movdqu xmm0,[rdi] 				 
	movdqu xmm1,[rdi+16]		

	pslldq xmm1,8  		; xmm1 | p5 | p4 | 0 | 0 |
	psrldq xmm0,8       ; xmm0 | 0 | 0 | P3 | P2 |
	por xmm1,xmm0
	movdqu xmm2,[aclarar]
	por xmm1,xmm2

	movdqu [rsi],xmm1  
	
	add rdi,16
	add rsi,16
	sub r11,1
	cmp r11,0
	jnz .loopUno
	; BORDE 

	;la ultima tanda se hace afuera de la iteracion para no levantar de mas 

	movdqu xmm0,[rdi] 				 
	movdqu xmm1,[rdi+16]


	pslldq xmm1,8
	psrldq xmm0,8        	; xmm0 | 0 | 0 | P3 | P2 |
	por xmm1,xmm0 
	movdqu xmm2,[aclarar]
	por xmm1,xmm2

	;movdqu xmm2,[patron]
	movdqu xmm0,[bordeDerecho]
	por xmm1,xmm0

	por xmm1,xmm2 
	movdqu [rsi],xmm1
	
	add rdi,32
	add rsi,16

	
	add r10,1
	sub rcx,1
	jmp .loopPrincipal

.fin:
	mov r11, rdx
	shr r11 ,1

.aclarar:
	movdqu xmm0,[rbx] 		   	   ;levanto pixeles 
	movdqu xmm1,[blanqueamiento]   ;todos los colores deben estar al maximo 
	paddusb xmm0,xmm1 
	movdqu [r12],xmm0

	add rbx,16
	add r12,16

	sub r11,1
 	jnz .aclarar

 	; levanta los primeros 4 y ultimos 4 pixeles de cada fila
 	mov r11, rdx
	shr r11 ,1

	sub rdi,16
	sub rsi,16

.regionFInal:
	movdqu xmm0,[rdi] 		  	   ;levanto pixeles 
	movdqu xmm1,[blanqueamiento]   ;todos los colores deben estar al maximo 
	paddusb xmm0,xmm1 
	movdqu [rsi],xmm0

	sub rdi,16
	sub rsi,16

	sub r11,1
 	jnz .regionFInal

	pop r12
	pop rbx
	pop rbp 
ret
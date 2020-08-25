global Zigzag_asm


section .rodata


blanqueamiento: times 4 dd  0xffffffff
mestizo:   dd   0xffffffff,0xffffffff,0x00000000,0x00000000 
mestizoInverso: dd 	0x00000000,0x00000000,0xffffffff,0xffffffff
aclarar: times 4 dd 0xff000000
filtroPixeles01:dd 0xffffffff,0xffffffff,0x00000000,0x00000000 
filtroPixeles23:dd 0x00000000,0x00000000, 0xffffffff,0xffffffff 
mascaraAntiAlfas: times 4 dd 0x00ffffff	
division_por_5: times 4 DD 5.0

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

.ciclo:




.modCeroyDos:
;~~~~~~~~~~~~~~ /////////////////// columnas modulo 0 //////////////////~~~~~~~~~~~~~

;~~~~~~~~~~~~~~~~++++++++++++++ ENTRADA A LAS FILAS MOD 0 y 2 +++++++++++~~~~~~~~~~~~~~~~~~~~~~

	;este ciclo itera levantando de a 8 desde el puntero rdi,  
	mov r11,rdx
	shr r11,2
	sub r11,2		; ingora los ultimos 8 pixeles y los primeros 4, pueden dar seg fault, de hecho lo hacen  

 ; con el ciclo armado ahora hay que ocuparse de los 2 primeros que hay que modificar 
 ; los levanto  trabajo con la parte alta y los guardo, la parte baja no es necesario tocarla 

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
	movdqu xmm3,xmm4 

	;repito todo este quilombo para la parte alta de xmm0,
	movdqu xmm0,xmm11

	pxor xmm6, xmm6 				; limpio , para parte alta  
	
	; parte alta 
	PUNPCKHBW xmm0,xmm6				; desenpaqueto para guardar parte alta de xmm1
	movdqu xmm5,xmm0 				; guardo para no perder el desempaquetado, ya que tngo que repetir con la parte alta
									; del desempaquetado  

	; bien, ahora tengo que pasarlo a 32 bits, de nuevo primero la parte baja del desempaquetado seria el pixel 2
	PUNPCKLWD xmm5,xmm6
	
	;repito para parte alta del desempaquetado, seria el pixel 3 el que queda aqui 
	PUNPCKHWD xmm0,xmm6
	movdqu xmm6,xmm0

	; en sintesis tenemos

	; xmm3 <--- P0
	; xmm4 <--- P1
	; xmm5 <--- P2
	; xmm6 <--- P3

	;convierto la parte baja de xmm1

	pxor xmm3,xmm3

	PUNPCKLBW xmm1,xmm3				; desenpaqueto para guardar parte baja de xmm1
	movdqu xmm7,xmm1 


	; al igual que antes separo los colores extendidos a 32 para la parte alta y baja 


	;parte baja del desempaquetado  
	PUNPCKLWD xmm0,xmm3 		;pixel 4


	;parte alta del desempaquetado

	PUNPCKHWD xmm7,xmm3 		;pixel 5

	; con esto ya puedo operar los pixeles p2 y p3
 
	; primero las sumas con p2 
	; estas son,  p2+p3 + p0 + p1 + p4 

 	; recuerdo 
 	; xmm3 = p0       xmm0 = p4
 	; xmm4 = p1 	  xmm7 = p5 
 	; xmm5 = p2 
 	; xmm6 = p3

 	;necesito el valor original de xmm5 para mas adelante, asi que lo guardo 
 	movdqu xmm8,xmm5

 	paddd xmm5,xmm6
 	paddd xmm5,xmm0
 	paddd xmm5,xmm4
 	paddd xmm5,xmm3

 	; sumas con p3
 	; estas son p1 + p2 + p4  + p5 + p3
 	; lo mismo con xmm4  

 	paddd xmm6,xmm8
 	paddd xmm6,xmm1
 	paddd xmm6,xmm0
 	paddd xmm6,xmm7

	; divisiones 
    CVTDQ2PS xmm5,xmm5
    CVTDQ2PS xmm6,xmm6


    movdqu xmm0,[division_por_5]
    
    divps xmm5,xmm0
    divps xmm6,xmm0

    CVTPS2DQ xmm5,xmm5
    CVTPS2DQ xmm6,xmm6

 	; acomodar en xmm0 y ver si esta bien 
 	pxor xmm0,xmm0
 	movdqu xmm1,[mascaraP3]
 	pshufb xmm5,xmm1
 	por xmm0,xmm5
 	movdqu xmm1,[mascaraP4]
 	pshufb xmm6,xmm1 
 	por xmm0,xmm6 

 	movdqu xmm1,[aclarar] 
 	paddusb xmm0,xmm1 


	movdqu xmm2,[mestizo]

	paddusb xmm0,xmm2

 	movdqu [rsi],xmm0

 	add rsi,16


.loopCero:

	; este algoritmo es jodido, vamos a escribirlo paso a paso lentamente 
	movdqu xmm0,[rdi]
	movdqu xmm1,[rdi+16]
	movdqu xmm2,[rdi+32]


	; primero extiendo los colores pixeles de xmm1 a 32 bits, quedan en registros separados logicamente
	; le saco los alfas para mas comodidad, al final se los satura a 255

	movdqu xmm6,[mascaraAntiAlfas]
	pand xmm1 ,xmm6
	pand xmm0,xmm6 
	pand xmm2,xmm6 			; sirve para mas adelante
	movdqu xmm11,xmm1 


	; primero la parte baja, pasa a word

	pxor xmm3, xmm3 				; limpio , para parte baja  
	; parte baja 
	PUNPCKLBW xmm1,xmm3				; desenpaqueto para guardar parte BAJA
	movdqu xmm4,xmm1 				; guardo para no perder el desempaquetado, ya que tngo que repetir con la parte alta
									; me di el lujo de perder el xmm1 original porque lo puedo volver a levantar de memoria									; es costoso pero me confundo menos con los reg que uso, capaz se puede mejorar despues 

	; bien, ahora tengo que pasarlo a 32 bits, de nuevo primero la parte baja seria el pixel 0
	PUNPCKLWD xmm4,xmm3
	
	;repito para parte alta del desempaqueado 
	PUNPCKHWD xmm1,xmm3
	movdqu xmm3,xmm1 

	movdqu xmm10,xmm3
	movdqu xmm3,xmm4
	movdqu xmm4,xmm10 



	;repito todo este quilombo para la parte alta de xmm1,
	movdqu xmm1,xmm11

	pxor xmm6, xmm6 				; limpio , para parte alta  
	
	; parte alta 
	PUNPCKHBW xmm1,xmm6				; desenpaqueto para guardar parte alta de xmm1
	movdqu xmm5,xmm1 				; guardo para no perder el desempaquetado, ya que tngo que repetir con la parte alta
									; del desempaquetado  

	; bien, ahora tengo que pasarlo a 32 bits, de nuevo primero la parte baja del desempaquetado seria el pixel 2
	PUNPCKLWD xmm5,xmm6
	
	;repito para parte alta del desempaquetado, seria el pixel 3 el que queda aqui 
	PUNPCKHWD xmm1,xmm6
	movdqu xmm6,xmm1

	; en sintesis tenemos

	; xmm3 <--- P4
	; xmm4 <--- P5
	; xmm5 <--- P6
	; xmm6 <--- P7
	; justo en orden ascendiente, casualidad? intencion? la deducion queda como ejercicio para el lector 


	;esa era la parte mareante por asi decirlo, hay que hacer las sumas ahora
	;ese proceso conlleva aumentara 32 los pixeles necesarios para la operacion, serian 
	;la parte alta de xmm0 y la parte baja de xmm2 
	;con eso tendriamos todo para sumar y despues hacer la conversion a float para dividir, de ahi vemos como seguimos

	;primero convierto la parte alta de xmm0

	pxor xmm1,xmm1

	PUNPCKHBW xmm0,xmm1				; desenpaqueto para guardar parte alta de xmm1
	movdqu xmm7,xmm0 


	; al igual que antes separo los colores extendidos a 32 para la parte alta y baja 


	;parte baja del desempaquetado  
	PUNPCKLWD xmm0,xmm1 		;pixel 2


	;parte alta del desempaquetado

	PUNPCKHWD xmm7,xmm1 		;pixel 3

	; con esto ya puedo operar los pixeles p4 y p5
 
	; primero las sumas con p4 
	; estas son,  p4+p5 + p2 + p3 + p6 

 	; recuerdo 
 	; xmm3 = p4       xmm0 = p2
 	; xmm4 = p5 	  xmm7 = p3 
 	; xmm5 = p6 
 	; xmm6 = p7

 	;necesito el valor original de xmm3 para mas adelante, asi que lo guardo 
 	movdqu xmm8,xmm3

 	paddd xmm3,xmm4
 	paddd xmm3,xmm5
 	paddd xmm3,xmm0
 	paddd xmm3,xmm7 

 	; sumas con p5
 	; estas son p5 + p4 + p6  + p3 + p7
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

	PUNPCKHWD xmm7,xmm1 		;pixel 9


	; ahora hago las sumas con p6 y p7 

	;primero con p6 
	;necesito p4,p5,p6,p7,p8

	;recuerdo
	; xmm8 = p4       xmm2 = p8
 	; xmm9 = p5 	  xmm7 = p9 
 	; xmm5 = p6 
 	; xmm6 = p7

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

    CVTPS2DQ xmm3,xmm3
    CVTPS2DQ xmm4,xmm4
    CVTPS2DQ xmm5,xmm5
    CVTPS2DQ xmm6,xmm6

    ; ahora hay que unir todo de vuelta y rezaar que no haga cajeta todo 

    ; xmm3 = p4       
 	; xmm4 = p5 	   
 	; xmm5 = p6 
 	; xmm6 = p7

 	;primero hay que acomodar p4, uso un shuffle con una mascara para organizar de a bytes , voy guardando en xmm0
 	;cargo la mascara en xmm1
 	pxor xmm0,xmm0


 	movdqu xmm2,[mascaraP1]
 	pshufb xmm3,xmm2
 	por xmm0,xmm3 
 	movdqu xmm2,[mascaraP2]
 	pshufb xmm4,xmm2
 	por xmm0,xmm4
 	movdqu xmm2,[mascaraP3]
 	pshufb xmm5,xmm2
 	por xmm0,xmm5
 	movdqu xmm2,[mascaraP4]
 	pshufb xmm6,xmm2
 	por xmm0,xmm6 

 	;ponele que ya esta
 	movdqu xmm1,[aclarar]
 	paddusb xmm0,xmm1



	movdqu [rsi],xmm0  
	
	add rdi,16
	add rsi,16
	sub r11,1
	cmp r11,0
	jnz .loopCero
;											TERMINACION DE LOOP 0	
; ~~~~~~~~~~~~~~~~++++++++++++ MODIFICACION DE LOS ULTIMOS PIXELES ++++++++++++~~~~~~~~~~~~~~~~~~~~



	; parte final del algoritmo, de aca en adelante una vez terminado,consiste en arreglar fallos
	; bien, para esto necesito levantar tres tandas, la posicion de rdi, rdi + 16 

	movdqu xmm0,[rdi]
	movdqu xmm1,[rdi+16]

	;en xmm1 esta la ultima tanda 

	;hay que aplicarle todo el algoritmo a xmm1 para convertirlo a 32, lo mismo para la parte baja de xmm0 


	movdqu xmm6,[mascaraAntiAlfas]
	pand xmm0,xmm6 
	pand xmm1 ,xmm6


	; primero la parte baja, pasa a word

	pxor xmm3, xmm3 				; limpio , para parte baja  
	; parte baja 
	PUNPCKLBW xmm1,xmm3				; desenpaqueto para guardar parte BAJA
	movdqu xmm4,xmm1 				; guardo para no perder el desempaquetado, ya que tngo que repetir con la parte alta

	PUNPCKLWD xmm4,xmm3
	
	;repito para parte alta del desempaqueado 
	PUNPCKHWD xmm1,xmm3
	movdqu xmm3,xmm1 

	movdqu xmm10,xmm3
	movdqu xmm4,xmm3
	movdqu xmm3,xmm10 

	;quedaron asi 

	; xmm3  |0 | 0| 0 | 0| 0| 0 | 0| r | 0 |0 |0 | g | 0 | 0 | 0 | b P4 colores acomodados a 32 bits 
	; xmm4  |0 | 0| 0 | 0| 0| 0 | 0| r | 0 |0 |0 | g | 0 | 0 | 0 | b P5 colores acomodados a 32 bits  

	movdqu xmm1,[rdi]
	pand xmm1,xmm6					; remuevo alfas 

	pxor xmm6, xmm6 				; limpio , para parte alta  
	
	; parte alta 
	PUNPCKHBW xmm1,xmm6				; desenpaqueto para guardar parte alta de xmm1
	movdqu xmm5,xmm1 				; guardo para no perder el desempaquetado, ya que tngo que repetir con la parte alta
									; del desempaquetado  

	; bien, ahora tengo que pasarlo a 32 bits, de nuevo primero la parte baja del desempaquetado seria el pixel 2
	PUNPCKLWD xmm5,xmm6
	
	;repito para parte alta del desempaquetado, seria el pixel 3 el que queda aqui 
	PUNPCKHWD xmm1,xmm6
	movdqu xmm6,xmm1


;	Repito para parte alta de xmm0 


	pxor xmm3,xmm3

	PUNPCKHBW xmm0,xmm3				; desenpaqueto para guardar parte alta de xmm1
	movdqu xmm7,xmm0 


	; al igual que antes separo los colores extendidos a 32 para la parte alta y baja 


	;parte baja del desempaquetado  
	PUNPCKLWD xmm0,xmm3 		;pixel 4

	;parte alta del desempaquetado
	PUNPCKHWD xmm7,xmm3 		; pixel 5 

; queda asi 

	; xmm3 = p4   	xmm0=   P3  
 	; xmm4 = P5 	xmm7=   p2 
 	; xmm5 = p6 
 	; xmm6 = p7
	
 ; las sumas se llevan acabo sobre p4 y p5 asi que a seguir robando codigo se ha dicho 

 	;necesito el valor original de xmm3 para mas adelante, asi que lo guardo 
 	movdqu xmm8,xmm3

 	paddd xmm3,xmm4
 	paddd xmm3,xmm5
 	paddd xmm3,xmm0
 	paddd xmm3,xmm7 

 	; sumas con p5
 	; estas son p5 + p4 + p6  + p3 + p7
 	; lo mismo con xmm4  

 	paddd xmm4,xmm8
 	paddd xmm4,xmm5
 	paddd xmm4,xmm6
 	paddd xmm4,xmm7


 		; hay que dividir estos capos por 5, podria hacer muchas cosas, voy a convertirlos a float y usar division de flotantes
    CVTDQ2PS xmm3,xmm3
    CVTDQ2PS xmm4,xmm4



    movdqu xmm0,[division_por_5]
    
    divps xmm3,xmm0
    divps xmm4,xmm0

    CVTPS2DQ xmm3,xmm3
    CVTPS2DQ xmm4,xmm4


    ; ahora hay que unir todo de vuelta y rezaar que no haga cajeta todo 

    ; xmm3 = p4       
 	; xmm4 = p5 	   
 	; xmm5 = p6 
 	; xmm6 = p7

 	;primero hay que acomodar p4, uso un shuffle con una mascara para organizar de a bytes , voy guardando en xmm0
 	;cargo la mascara en xmm1
 	pxor xmm0,xmm0

 	movdqu xmm2,[mascaraP1]
 	pshufb xmm3,xmm2
 	por xmm0,xmm3 
 	movdqu xmm2,[mascaraP2]
 	pshufb xmm4,xmm2
 	por xmm0,xmm4

 	movdqu xmm1,[aclarar]

 	paddusb xmm0,xmm1

 	movdqu xmm1,[mestizoInverso]
	paddusb xmm0,xmm1

 	movdqu[rsi],xmm0

	add rdi,32 
	add rsi,16

 	inc r10
 	cmp r10, rcx
 	je .fin

 ;~~~~~~~~~~~~~~ /////////////////// columnas modulo 1 //////////////////~~~~~~~~~~~~~

.modUno:
	mov r11,rdx
	shr r11,2
	sub r11,2 			;esto es para ignorar la primer y ultima tanda de pixeles , caso contrario se produce seg fault


	; esto lo hago para no tener accesos desalineados a memoria, se explaya mejor en el informe 
	; basicamente solo modifico , dos de los pixeles de los primeros 4 del inicio de la fila ,los dos primeros 
	; hay que ponerlos en blanco al final
	movdqu xmm0,[rdi]
	pslldq xmm0,8 
	movdqu xmm1,[aclarar]
	paddusb xmm0,xmm1


	movdqu xmm2,[mestizo]

	paddusb xmm0,xmm2

	movdqu [rsi],xmm0
	;add rdi,16
	add rsi,16

.loopUno:
	movdqu xmm0,[rdi] 				 
	movdqu xmm1,[rdi+16]		

 	
	; la idea es inversa a la de mod 3, aca hay que levantar y mover los dos de la izquierda
	; xmm0 | p3 | p2 | P1 | P0 |
	; xmm1 | p7 | p6 | P5 | P4 |
	; mergeo 
	; xmm1 | p5 | p4 | P3 | P2 |

	; la parte baja de xmm1 tiene que ser la parte alta y la parte alta de xmm0 tiene que ser la baja de xmm1 
	pslldq xmm1,8  	;	; xmm1 | p5 | p4 | 0 | 0 |
	psrldq xmm0,8        ; ; xmm0 | 0 | 0 | P3 | P2 |
	por xmm1,xmm0
	movdqu xmm2,[aclarar]
	paddusb xmm1,xmm2


	movdqu [rsi],xmm1  
	
	add rdi,16
	add rsi,16
	sub r11,1
	cmp r11,0
	jnz .loopUno

	;la ultima tanda se hace afuera de la iteracion para no levantar de mas 
	;add rdi,16

	movdqu xmm0,[rdi] 				 
	movdqu xmm1,[rdi+16]
	psrldq xmm1,8  			; xmm1 | p5 | p4 | 0 | 0 |
	pslldq xmm0,8        	; xmm0 | 0 | 0 | P3 | P2 |
	por xmm1,xmm0
	movdqu xmm2,[aclarar]
	paddusb xmm1,xmm2

	movdqu xmm0,[mestizoInverso]
	paddusb xmm1,xmm0

	movdqu [rsi],xmm1  
	
	add rdi,32
	add rsi,16

	
	inc r10
 	cmp r10, rcx
 	je .fin


 	.modDos:

;   ~~~~~~~~~~~~~~~~++++++++++++++ ENTRADA A LAS FILAS MOD 0 y 2 +++++++++++~~~~~~~~~~~~~~~~~~~~~~

	;este ciclo itera levantando de a 8 desde el puntero rdi,  
	mov r11,rdx
	shr r11,2
	sub r11,2		; ingora los ultimos 8 pixeles y los primeros 4, pueden dar seg fault, de hecho lo hacen  

 ; con el ciclo armado ahora hay que ocuparse de los 2 primeros que hay que modificar 
 ; los levanto  trabajo con la parte alta y los guardo, la parte baja no es necesario tocarla 

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
	movdqu xmm3,xmm4 

	;repito todo este quilombo para la parte alta de xmm0,
	movdqu xmm0,xmm11

	pxor xmm6, xmm6 				; limpio , para parte alta  
	
	; parte alta 
	PUNPCKHBW xmm0,xmm6				; desenpaqueto para guardar parte alta de xmm1
	movdqu xmm5,xmm0 				; guardo para no perder el desempaquetado, ya que tngo que repetir con la parte alta
									; del desempaquetado  

	; bien, ahora tengo que pasarlo a 32 bits, de nuevo primero la parte baja del desempaquetado seria el pixel 2
	PUNPCKLWD xmm5,xmm6
	
	;repito para parte alta del desempaquetado, seria el pixel 3 el que queda aqui 
	PUNPCKHWD xmm0,xmm6
	movdqu xmm6,xmm0

	; en sintesis tenemos

	; xmm3 <--- P0
	; xmm4 <--- P1
	; xmm5 <--- P2
	; xmm6 <--- P3

	;convierto la parte baja de xmm1

	pxor xmm3,xmm3

	PUNPCKLBW xmm1,xmm3				; desenpaqueto para guardar parte baja de xmm1
	movdqu xmm7,xmm1 


	; al igual que antes separo los colores extendidos a 32 para la parte alta y baja 


	;parte baja del desempaquetado  
	PUNPCKLWD xmm0,xmm3 		;pixel 4


	;parte alta del desempaquetado

	PUNPCKHWD xmm7,xmm3 		;pixel 5

	; con esto ya puedo operar los pixeles p2 y p3
 
	; primero las sumas con p2 
	; estas son,  p2+p3 + p0 + p1 + p4 

 	; recuerdo 
 	; xmm3 = p0       xmm0 = p4
 	; xmm4 = p1 	  xmm7 = p5 
 	; xmm5 = p2 
 	; xmm6 = p3

 	;necesito el valor original de xmm5 para mas adelante, asi que lo guardo 
 	movdqu xmm8,xmm5

 	paddd xmm5,xmm6
 	paddd xmm5,xmm0
 	paddd xmm5,xmm4
 	paddd xmm5,xmm3

 	; sumas con p3
 	; estas son p1 + p2 + p4  + p5 + p3
 	; lo mismo con xmm4  

 	paddd xmm6,xmm8
 	paddd xmm6,xmm1
 	paddd xmm6,xmm0
 	paddd xmm6,xmm7

	; divisiones 
    CVTDQ2PS xmm5,xmm5
    CVTDQ2PS xmm6,xmm6


    movdqu xmm0,[division_por_5]
    
    divps xmm5,xmm0
    divps xmm6,xmm0

    CVTPS2DQ xmm5,xmm5
    CVTPS2DQ xmm6,xmm6

 	; acomodar en xmm0 y ver si esta bien 
 	pxor xmm0,xmm0
 	movdqu xmm1,[mascaraP3]
 	pshufb xmm5,xmm1
 	por xmm0,xmm5
 	movdqu xmm1,[mascaraP4]
 	pshufb xmm6,xmm1 
 	por xmm0,xmm6 

 	movdqu xmm1,[aclarar] 
 	paddusb xmm0,xmm1 


	movdqu xmm2,[mestizo]

	paddusb xmm0,xmm2

 	movdqu [rsi],xmm0

 	add rsi,16


.loop_Cero:

	; este algoritmo es jodido, vamos a escribirlo paso a paso lentamente 
	movdqu xmm0,[rdi]
	movdqu xmm1,[rdi+16]
	movdqu xmm2,[rdi+32]


	; primero extiendo los colores pixeles de xmm1 a 32 bits, quedan en registros separados logicamente
	; le saco los alfas para mas comodidad, al final se los satura a 255

	movdqu xmm6,[mascaraAntiAlfas]
	pand xmm1 ,xmm6
	pand xmm0,xmm6 
	pand xmm2,xmm6 			; sirve para mas adelante
	movdqu xmm11,xmm1 


	; primero la parte baja, pasa a word

	pxor xmm3, xmm3 				; limpio , para parte baja  
	; parte baja 
	PUNPCKLBW xmm1,xmm3				; desenpaqueto para guardar parte BAJA
	movdqu xmm4,xmm1 				; guardo para no perder el desempaquetado, ya que tngo que repetir con la parte alta
									; me di el lujo de perder el xmm1 original porque lo puedo volver a levantar de memoria									; es costoso pero me confundo menos con los reg que uso, capaz se puede mejorar despues 

	; bien, ahora tengo que pasarlo a 32 bits, de nuevo primero la parte baja seria el pixel 0
	PUNPCKLWD xmm4,xmm3
	
	;repito para parte alta del desempaqueado 
	PUNPCKHWD xmm1,xmm3
	movdqu xmm3,xmm1 

	movdqu xmm10,xmm3
	movdqu xmm3,xmm4
	movdqu xmm4,xmm10 



	;repito todo este quilombo para la parte alta de xmm1,
	movdqu xmm1,xmm11

	pxor xmm6, xmm6 				; limpio , para parte alta  
	
	; parte alta 
	PUNPCKHBW xmm1,xmm6				; desenpaqueto para guardar parte alta de xmm1
	movdqu xmm5,xmm1 				; guardo para no perder el desempaquetado, ya que tngo que repetir con la parte alta
									; del desempaquetado  

	; bien, ahora tengo que pasarlo a 32 bits, de nuevo primero la parte baja del desempaquetado seria el pixel 2
	PUNPCKLWD xmm5,xmm6
	
	;repito para parte alta del desempaquetado, seria el pixel 3 el que queda aqui 
	PUNPCKHWD xmm1,xmm6
	movdqu xmm6,xmm1

	; en sintesis tenemos

	; xmm3 <--- P4
	; xmm4 <--- P5
	; xmm5 <--- P6
	; xmm6 <--- P7
	; justo en orden ascendiente, casualidad? intencion? la deducion queda como ejercicio para el lector 


	;esa era la parte mareante por asi decirlo, hay que hacer las sumas ahora
	;ese proceso conlleva aumentara 32 los pixeles necesarios para la operacion, serian 
	;la parte alta de xmm0 y la parte baja de xmm2 
	;con eso tendriamos todo para sumar y despues hacer la conversion a float para dividir, de ahi vemos como seguimos

	;primero convierto la parte alta de xmm0

	pxor xmm1,xmm1

	PUNPCKHBW xmm0,xmm1				; desenpaqueto para guardar parte alta de xmm1
	movdqu xmm7,xmm0 


	; al igual que antes separo los colores extendidos a 32 para la parte alta y baja 


	;parte baja del desempaquetado  
	PUNPCKLWD xmm0,xmm1 		;pixel 2


	;parte alta del desempaquetado

	PUNPCKHWD xmm7,xmm1 		;pixel 3

	; con esto ya puedo operar los pixeles p4 y p5
 
	; primero las sumas con p4 
	; estas son,  p4+p5 + p2 + p3 + p6 

 	; recuerdo 
 	; xmm3 = p4       xmm0 = p2
 	; xmm4 = p5 	  xmm7 = p3 
 	; xmm5 = p6 
 	; xmm6 = p7

 	;necesito el valor original de xmm3 para mas adelante, asi que lo guardo 
 	movdqu xmm8,xmm3

 	paddd xmm3,xmm4
 	paddd xmm3,xmm5
 	paddd xmm3,xmm0
 	paddd xmm3,xmm7 

 	; sumas con p5
 	; estas son p5 + p4 + p6  + p3 + p7
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

	PUNPCKHWD xmm7,xmm1 		;pixel 9


	; ahora hago las sumas con p6 y p7 

	;primero con p6 
	;necesito p4,p5,p6,p7,p8

	;recuerdo
	; xmm8 = p4       xmm2 = p8
 	; xmm9 = p5 	  xmm7 = p9 
 	; xmm5 = p6 
 	; xmm6 = p7

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

    CVTPS2DQ xmm3,xmm3
    CVTPS2DQ xmm4,xmm4
    CVTPS2DQ xmm5,xmm5
    CVTPS2DQ xmm6,xmm6

    ; ahora hay que unir todo de vuelta y rezaar que no haga cajeta todo 

    ; xmm3 = p4       
 	; xmm4 = p5 	   
 	; xmm5 = p6 
 	; xmm6 = p7

 	;primero hay que acomodar p4, uso un shuffle con una mascara para organizar de a bytes , voy guardando en xmm0
 	;cargo la mascara en xmm1
 	pxor xmm0,xmm0


 	movdqu xmm2,[mascaraP1]
 	pshufb xmm3,xmm2
 	por xmm0,xmm3 
 	movdqu xmm2,[mascaraP2]
 	pshufb xmm4,xmm2
 	por xmm0,xmm4
 	movdqu xmm2,[mascaraP3]
 	pshufb xmm5,xmm2
 	por xmm0,xmm5
 	movdqu xmm2,[mascaraP4]
 	pshufb xmm6,xmm2
 	por xmm0,xmm6 

 	;ponele que ya esta
 	movdqu xmm1,[aclarar]
 	paddusb xmm0,xmm1



	movdqu [rsi],xmm0  
	
	add rdi,16
	add rsi,16
	sub r11,1
	cmp r11,0
	jnz .loop_Cero
;											TERMINACION DE LOOP 0	
; ~~~~~~~~~~~~~~~~++++++++++++ MODIFICACION DE LOS ULTIMOS PIXELES ++++++++++++~~~~~~~~~~~~~~~~~~~~



	; parte final del algoritmo, de aca en adelante una vez terminado,consiste en arreglar fallos
	; bien, para esto necesito levantar tres tandas, la posicion de rdi, rdi + 16 

	movdqu xmm0,[rdi]
	movdqu xmm1,[rdi+16]

	;en xmm1 esta la ultima tanda 

	;hay que aplicarle todo el algoritmo a xmm1 para convertirlo a 32, lo mismo para la parte baja de xmm0 


	movdqu xmm6,[mascaraAntiAlfas]
	pand xmm0,xmm6 
	pand xmm1 ,xmm6


	; primero la parte baja, pasa a word

	pxor xmm3, xmm3 				; limpio , para parte baja  
	; parte baja 
	PUNPCKLBW xmm1,xmm3				; desenpaqueto para guardar parte BAJA
	movdqu xmm4,xmm1 				; guardo para no perder el desempaquetado, ya que tngo que repetir con la parte alta

	PUNPCKLWD xmm4,xmm3
	
	;repito para parte alta del desempaqueado 
	PUNPCKHWD xmm1,xmm3
	movdqu xmm3,xmm1 

	movdqu xmm10,xmm3
	movdqu xmm4,xmm3
	movdqu xmm3,xmm10 

	;quedaron asi 

	; xmm3  |0 | 0| 0 | 0| 0| 0 | 0| r | 0 |0 |0 | g | 0 | 0 | 0 | b P4 colores acomodados a 32 bits 
	; xmm4  |0 | 0| 0 | 0| 0| 0 | 0| r | 0 |0 |0 | g | 0 | 0 | 0 | b P5 colores acomodados a 32 bits  

	movdqu xmm1,[rdi]
	pand xmm1,xmm6					; remuevo alfas 

	pxor xmm6, xmm6 				; limpio , para parte alta  
	
	; parte alta 
	PUNPCKHBW xmm1,xmm6				; desenpaqueto para guardar parte alta de xmm1
	movdqu xmm5,xmm1 				; guardo para no perder el desempaquetado, ya que tngo que repetir con la parte alta
									; del desempaquetado  

	; bien, ahora tengo que pasarlo a 32 bits, de nuevo primero la parte baja del desempaquetado seria el pixel 2
	PUNPCKLWD xmm5,xmm6
	
	;repito para parte alta del desempaquetado, seria el pixel 3 el que queda aqui 
	PUNPCKHWD xmm1,xmm6
	movdqu xmm6,xmm1


;	Repito para parte alta de xmm0 


	pxor xmm3,xmm3

	PUNPCKHBW xmm0,xmm3				; desenpaqueto para guardar parte alta de xmm1
	movdqu xmm7,xmm0 


	; al igual que antes separo los colores extendidos a 32 para la parte alta y baja 


	;parte baja del desempaquetado  
	PUNPCKLWD xmm0,xmm3 		;pixel 4

	;parte alta del desempaquetado
	PUNPCKHWD xmm7,xmm3 		; pixel 5 

; queda asi 

	; xmm3 = p4   	xmm0=   P3  
 	; xmm4 = P5 	xmm7=   p2 
 	; xmm5 = p6 
 	; xmm6 = p7
	
 ; las sumas se llevan acabo sobre p4 y p5 asi que a seguir robando codigo se ha dicho 

 	;necesito el valor original de xmm3 para mas adelante, asi que lo guardo 
 	movdqu xmm8,xmm3

 	paddd xmm3,xmm4
 	paddd xmm3,xmm5
 	paddd xmm3,xmm0
 	paddd xmm3,xmm7 

 	; sumas con p5
 	; estas son p5 + p4 + p6  + p3 + p7
 	; lo mismo con xmm4  

 	paddd xmm4,xmm8
 	paddd xmm4,xmm5
 	paddd xmm4,xmm6
 	paddd xmm4,xmm7


 		; hay que dividir estos capos por 5, podria hacer muchas cosas, voy a convertirlos a float y usar division de flotantes
    CVTDQ2PS xmm3,xmm3
    CVTDQ2PS xmm4,xmm4



    movdqu xmm0,[division_por_5]
    
    divps xmm3,xmm0
    divps xmm4,xmm0

    CVTPS2DQ xmm3,xmm3
    CVTPS2DQ xmm4,xmm4


    ; ahora hay que unir todo de vuelta y rezaar que no haga cajeta todo 

    ; xmm3 = p4       
 	; xmm4 = p5 	   
 	; xmm5 = p6 
 	; xmm6 = p7

 	;primero hay que acomodar p4, uso un shuffle con una mascara para organizar de a bytes , voy guardando en xmm0
 	;cargo la mascara en xmm1
 	pxor xmm0,xmm0

 	movdqu xmm2,[mascaraP1]
 	pshufb xmm3,xmm2
 	por xmm0,xmm3 
 	movdqu xmm2,[mascaraP2]
 	pshufb xmm4,xmm2
 	por xmm0,xmm4

 	movdqu xmm1,[aclarar]

 	paddusb xmm0,xmm1

 	movdqu xmm1,[mestizoInverso]
	paddusb xmm0,xmm1

 	movdqu[rsi],xmm0

	add rdi,32 
	add rsi,16
	
 	inc r10
 	cmp r10, rcx
 	je .fin

;~~~~~~~~~~~~~~ /////////////////// columnas modulo 3 //////////////////~~~~~~~~~~~~~

.modTRes:
	mov r11,rdx
	shr r11,2
	sub r11,2 	;esto es porque el primero lo modificamos antes de entrar al cilo y al ultimo afuera , son casos excepcionales

	;este opera a la inversa de la mod 1, asi que el algoritmo es casi igual pero al reves
	;hacemos lo mismo pero un poco cambiado, para evitar accesos desalineados a memoria
	;modifico los primeros 4 pixeles

	movdqu xmm0,[rdi]
	movdqu xmm1,[rdi+16]
	movdqu xmm2,[aclarar]
	pslldq xmm1,8 
	psrldq xmm0,8
	por xmm0,xmm1
	paddusb xmm0,xmm2

	movdqu xmm2,[mestizo]

	paddusb xmm0,xmm2

	movdqu [rsi],xmm0

	add rsi,16
	add rdi,16			;no se suma porque necesito poder levantar los anteriores
						;el desfase se corrige al final 


.loopTres:
	movdqu xmm0,[rdi]
	movdqu xmm1,[rdi+16]

	; la parte alta de xmm0 tiene que pasar a ser la baja un shifteo a 8 arregla esto
	; la parte baja de xmm1 tiene que pasar a ser la parte alta de xmm0, los filtro y hago un or
	; un esquema de como tiene que quedar 

	;xmm0 | P3 | P2 | P1 | P0 |
	;XMM1 | P7 | P6 | P5 | P4 | 
	; mergeo
	; | P5 | P4 | P3 | P2 |

	; shifteo a 8 
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
 	pslldq xmm0,8					

 	movdqu xmm1,[aclarar]
	paddusb xmm0,xmm1

	movdqu xmm1,[mestizoInverso]
	paddusb xmm0,xmm1

	movdqu [rsi],xmm0

	add rdi,16				; para corregir el desfase entre rdi y rsi
	add rsi,16

	inc r10
 	cmp r10, rcx
 	je .fin


 	jmp .ciclo

 	.fin:
	mov r11, rdx
	shr r11 ,1

.aclarar:
	movdqu xmm0,[rbx] 		   ;levanto pixeles 
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
	movdqu xmm0,[rdi] 		   ;levanto pixeles 
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


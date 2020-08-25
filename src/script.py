import sys
import os
import matplotlib.pyplot as plt
import numpy as np
import subprocess

from random import randint
from math import sqrt

#Vector con el nombre de los filtros que se ingresan por parametro
filtros = ['Ocultar', 'Descubrir', 'Zigzag']
implementaciones = ['asm', 'O0', 'O1', 'O2', 'O3']

#Los imagenes que usara el script para testear
imagenes = [
'tests/data/imagenes_a_testear/evolution.32x16.bmp',
'tests/data/imagenes_a_testear/evolution.64x32.bmp',
'tests/data/imagenes_a_testear/evolution.128x64.bmp',
'tests/data/imagenes_a_testear/evolution.200x100.bmp',
'tests/data/imagenes_a_testear/evolution.256x128.bmp',
'tests/data/imagenes_a_testear/evolution.400x200.bmp',
'tests/data/imagenes_a_testear/evolution.512x256.bmp',
'tests/data/imagenes_a_testear/evolution.800x400.bmp',
'tests/data/imagenes_a_testear/evolution.1600x800.bmp'
]

imagenesOcultar = [
'tests/data/imagenes_a_testear/idiocracy.32x16.bmp',
'tests/data/imagenes_a_testear/idiocracy.64x32.bmp',
'tests/data/imagenes_a_testear/idiocracy.128x64.bmp',
'tests/data/imagenes_a_testear/idiocracy.200x100.bmp',
'tests/data/imagenes_a_testear/idiocracy.256x128.bmp',
'tests/data/imagenes_a_testear/idiocracy.400x200.bmp',
'tests/data/imagenes_a_testear/idiocracy.512x256.bmp',
'tests/data/imagenes_a_testear/idiocracy.800x400.bmp',
'tests/data/imagenes_a_testear/idiocracy.1600x800.bmp'
]

#tamanios de las imagenes para imprimir en pantalla
tamanios = ['32x16','64x32','128x64','200x100','256x128','400x200','512x256','800x400','1600x800']
parametroDibujar = sys.argv[1]
parametroFiltro = sys.argv[2]
filtro = sys.argv[3]

#Insulto al que usa mal las cosas
assert (filtro in filtros), ('Kpo, deja de decir boludeces ' + filtro + ' no existe y vos tampoco')




def generarBasura():
	for x in xrange(0,len(implementaciones)):
		for y in xrange(0,len(tamanios)):
			f = open("datos/" + implementaciones[x] + "_" + filtro + "_" + str(y) + ".txt", 'w')
			f.write( str(randint(1, 10)) + "," + str(randint(0, 9)))
			f.close()
#Esta funcion tiene el objetivo de cambiar las flags de compilacion del makefile, en particular la siguiente linea, donde cambia los signos de pregunta
#CFLAGS64 = -ggdb -Wall -Wno-unused-parameter -Wextra -std=c99 -no-pie -pedantic -m64 -???? -march=native
def cambiar_optimizacion(n):
	'''
  	Cambia la flags de optimizacion en el archivo makefile

  	''' 
	s = open("filters/Makefile").read()
	s = s.replace('O3', 'O'+str(n))
	s = s.replace('O2', 'O'+str(n))
	s = s.replace('O1', 'O'+str(n))
	s = s.replace('O0', 'O'+str(n))
	f = open("filters/Makefile", 'w')
	f.write(s)
	f.close()
	#Despues de cambiar la flag de compilacion, procede a compilar de nuevo
	subprocess.call("make clean", shell=True)  
	subprocess.call("make", shell=True)  

#Funcion para correr las implementaciones con las distintas flags sobre las distintas imagenes
def correrImplementaciones():
	'''
   Corre la version de ASM guardada en filters/filtro_asm.asm 
   y la compara contra la version de C en filters/filtro_c.asm con distintas flags de optimizacion activadas
   sobre un conjunto de imagenes ya predefinidas

	Returns
	---------
	Genera un archivo ciclos.txt con los diferentes ciclos, luego lo guarda en la carpeta datos, con el siguiente formato
	implementacion + "_" + filtro + "_" + imagenSrc + ".txt"
	para cada imagen un archivo distinto
	''' 
	subprocess.call("make clean", shell=True)  
	subprocess.call("make", shell=True)  

	#implementaciones es un vector con las opciones a usar, se recorre cada opcion y se procede a realizar el algoritmo sobre cada imagen con esa flag
	for numeroImplementacion in xrange(0,len(implementaciones)):
		tipo = "asm "
		#La primera opcion del vector implementaciones es la de ASM, entonces se saltea este caso
		if (numeroImplementacion>0):
			cambiar_optimizacion(numeroImplementacion-1)	
			tipo = 	"c "
		#Recorre cada imagen y ejecuta el algoritmo sobre cada una, midiendo la cantidad de ciclos
		for numImagen in xrange(0,len(imagenes)):
			if (filtro == "Ocultar"):
				comando =  "./build/tp2 " +  filtro  + " -i " +  tipo  + imagenes[numImagen] + " " + imagenesOcultar[numImagen]+ " -t 800"
			else:	
				comando =  "./build/tp2 " +  filtro  + " -i " +  tipo  + imagenes[numImagen] + " -t 800"
			subprocess.call(comando, shell=True)
			os.rename("ciclos.txt", "datos/" + implementaciones[numeroImplementacion] + "_" + filtro + "_" + str(numImagen) + ".txt")



def correrImplementacionesUnicaImagen(modo = 0, imagenSrc = "", imagenOcultar = ""):

	'''
   Corre la version de ASM guardada en filters/filtro_asm.asm 
   y la compara contra la version de C en filters/filtro_c.asm con distintas flags de optimizacion activadas
   en una imagen pasada por parametro
	
	Parametros
    ----------
	modo : int en [0,1]
	Si es 0, indica que se esta corriendo el filtro Descubrir y Zigzag
	Si es 1, indica que se esta corriendo el filtro Ocultar
	Esto es necesario ya que los filtros toman distintos parametros

	imagenSrc : Imagen a procesar
	imagenOcultar: Opcional, imagena a Ocultar si el filtro activado es Ocultar y el modo es 0
	----------

	Returns
	---------
	Genera un archivo ciclos.txt con los diferentes ciclos, luego lo guarda en la carpeta datos, con el siguiente formato
	implementacion + "_" + filtro + "_" + imagenSrc + ".txt"
	''' 

	subprocess.call("make clean", shell=True)  
	subprocess.call("make", shell=True)  

	#implementaciones es un vector con las opciones a usar, se recorre cada opcion y se procede a realizar el algoritmo sobre cada imagen con esa flag
	for numeroImplementacion in xrange(0,len(implementaciones)):
		tipo = "asm "
		#La primera opcion del vector implementaciones es la de ASM, entonces se saltea este caso
		if (numeroImplementacion>0):
			cambiar_optimizacion(numeroImplementacion-1)	
			tipo = 	"c "
		#Recorre cada imagen y ejecuta el algoritmo sobre cada una, midiendo la cantidad de ciclos
		if (modo == 0):
			comando =  "./build/tp2 " +  filtro  + " -i " +  tipo  + imagenSrc + " -t 800"
		else:
			comando =  "./build/tp2 " +  filtro  + " -i " +  tipo  + imagenSrc + imagenOcultar + " -t 800"	
		subprocess.call(comando, shell=True)
		os.rename("ciclos.txt", "datos/" + implementaciones[numeroImplementacion] + "_" + filtro + "_" + "UNA" +  ".txt")


def dibujar(borrarDatos = False, logaritmica = False, inicial = 0, imagen = "",  final = len(tamanios), titulo = "" ,nombre = "comp" ):
	'''
   Realiza el grafico de barras entre ASM y las versiones de C

	
	Parametros
    ----------
    borrarDatos : bool, indica si se procede a eliminar la informacion guardada en data o no
    logaritmica : Bool, indica si el grafico es en escala logaritmica o no
    inicial : int, sobre el size del vector de tamanios, indica por donde empezaar
	final   : int, sobre el size del vector de tamanios, indica por donde terminar
	titulo : string para imprimir en la imagen
	nombre : nombre para el grafico
	
	
	Returns
	---------
	Genera una imagen jpg con un grafico de barras comparando ASM contra las versiones de C sobre distinas imagenes

  	''' 


	colores = ['r', 'b', 'y', 'g', 'c']
	width = 1.3
	separacion = 0.75
	x_pos = np.arange(final-inicial)
	x_pos = x_pos*(final - inicial + 3)
	x_pos = (x_pos* (width + separacion))
	fig, ax = plt.subplots(figsize = (7.5, 4.8))


	for x in xrange(0,len(implementaciones)):
		print(implementaciones[x])
		mean = []
		std =  []
		for y in xrange(inicial,final):
			print(tamanios[y])
			# data es un txt con cantidad de ciclos insumidos para cada corrida
			data = np.genfromtxt("datos/" + implementaciones[x] + "_" + filtro + "_" + str(y) + ".txt",delimiter='\n')
			if (borrarDatos):
				#borramos el archivo generado
				os.remove("datos/" + implementaciones[x] + "_" + filtro + "_" + str(y) + ".txt")
			std.append(data.std())
			mean.append(data.mean())

		#con desviacion
		ax.bar(x_pos + x*(width+separacion) , mean, yerr=std , color = colores[x],  align='center', width = width, log = logaritmica)
		#sin desviacion
		#ax.bar(x_pos + x*(width+separacion) , mean, color = colores[x],  align='center', width = width)



	# Build the plot

	ax.set_ylabel('Clocks', fontsize = 12)
	ax.set_xticks(x_pos + len(implementaciones) * (width+separacion) /2 )
	ax.set_xticklabels(tamanios[inicial:final], fontsize = 10)
	ax.yaxis.grid(True)
	ax.set_title(titulo +  ' en ' + filtro)
	plt.legend(implementaciones)
	
	# si la leyenda queda mal, usar esto
	#box = ax.get_position()
	#ax.set_position([box.x0, box.y0, box.width * 0.8, box.height])

	# Put a legend to the right of the current axis
	#ax.legend(implementaciones,loc='center left', bbox_to_anchor=(1, 0.5))


	#plt.tight_layout()
	#fig.set_figwidth(50)
	plt.savefig(nombre + filtro +  '.png')

def dibujarUnaImagen(borrarDatos = False, logaritmica = False,imageSrc = "", titulo = "" ,nombre = "comp" ):
	'''
   Realiza el grafico de barras entre ASM y las versiones de C

	
	Parametros
    ----------
    borrarDatos : bool, indica si se procede a eliminar la informacion guardada en data o no
    logaritmica : Bool, indica si el grafico es en escala logaritmica o no
    inicial : int, sobre el size del vector de tamanios, indica por donde empezaar
	final   : int, sobre el size del vector de tamanios, indica por donde terminar
	titulo : string para imprimir en la imagen
	nombre : nombre para el grafico
	
	
	Returns
	---------
	Genera una imagen jpg con un grafico de barras comparando ASM contra las versiones de C sobre distinas imagenes

  	''' 


	colores = ['r', 'b', 'y', 'g', 'c']
	width = 1.3
	separacion = 0.75
	x_pos = np.arange(1)
	x_pos = x_pos*(1)
	x_pos = (x_pos* (width + separacion))
	fig, ax = plt.subplots(figsize = (7.5, 4.8))


	for implementacion in xrange(0,len(implementaciones)):
		print(implementaciones[implementacion])
		mean = []
		std =  []
			# data es un txt con cantidad de ciclos insumidos para cada corrida
		data = np.genfromtxt("datos/" + implementaciones[implementacion] + "_" + filtro + "_" + "UNA" + ".txt",delimiter='\n')
		if (borrarDatos):
				#borramos el archivo generado
			os.remove("datos/" + implementaciones[implementacion] + "_" + filtro + "_" + "UNA" + ".txt")
		std.append(data.std())
		mean.append(data.mean())

		#con desviacion
		ax.bar(x_pos + implementacion*(width+separacion) , mean, yerr=std , color = colores[implementacion],  align='center', width = width, log = logaritmica)
		#sin desviacion
		#ax.bar(x_pos + x*(width+separacion) , mean, color = colores[x],  align='center', width = width)



	# Build the plot

	ax.set_ylabel('Clocks', fontsize = 12)
	ax.set_xticks(x_pos + len(implementaciones) * (width+separacion) /2 )
	ax.set_xticklabels("HOLA", fontsize = 10)
	ax.yaxis.grid(True)
	ax.set_title(titulo +  ' en ' + filtro)
	plt.legend(implementaciones)
	
	# si la leyenda queda mal, usar esto
	#box = ax.get_position()
	#ax.set_position([box.x0, box.y0, box.width * 0.8, box.height])

	# Put a legend to the right of the current axis
	#ax.legend(implementaciones,loc='center left', bbox_to_anchor=(1, 0.5))


	#plt.tight_layout()
	#fig.set_figwidth(50)
	plt.savefig(nombre + filtro +  '.png')




#PRECONDICION: La version del experimento tiene que estar guardado en filters y del siguiente formato filtro_asmExperimentacion.asm
def correrAsm(version = 0):
	'''
   Corre la version de ASM guardada en filters/filtro_asm.asm 
   contra la guardada en filters/filtro_asmExperimentacion.asm 

	
	Parametros
    ----------
	Version : int en [0,1]
	Si es 0, indica que se esta corriendo el filtro original
	Si es 1, indica que se esta corriendo el filtro para la experimentacion

	Returns
	---------
	Genera un archivo ciclos.txt con los diferentes ciclos, luego lo guarda en la carpeta datos, con el siguiente formato
	implementacion + "_" + filtro + "_" + imagenSrc + "v" + str(version) + ".txt" para cada version

  	''' 
	#Si es la version 1, entonces se esta corriendo la version para la experimentacion

	if (version == 1):
	#Se cambia el nombre del archivo original por un auxiliar para preservarlo
		os.rename("filters/" + filtro + "_asm.asm", "filters/" + filtro + "_asmAUX.asm")
	#Se cambia el nombre del archivo de experimentacion por el nombre a ejecutar 	
		os.rename("filters/" + filtro + "_asmExperimentacion.asm" , "filters/" + filtro + "_asm.asm")
	#Se procede a compilar
	subprocess.call("make clean", shell=True)  	
	subprocess.call("make", shell=True) 
	tipo = 	"asm "
	#Recorre todas las imagenes y ejecuta el algoritmos sobre todas ellas
	for numImagen in xrange(0,len(imagenes)):
		imagen = imagenes[numImagen]
		#-t 800 corre 800 veces
		if (filtro == "Ocultar"):
			comando =  "./build/tp2 " +  filtro  + " -i " +  tipo  + imagenes[numImagen] + " " + imagenesOcultar[numImagen]+ " -t 800"
			print(comando)
		else:	
			comando =  "./build/tp2 " +  filtro  + " -i " +  tipo  + imagenes[numImagen] + " -t 800"
		subprocess.call(comando, shell=True)
		os.rename("ciclos.txt", "datos/" + implementaciones[0] + "_" + filtro + "_" + str(numImagen) + "v" + str(version) + ".txt")
	if (version == 1):
	#Vuelve a reestablecer los nombres originales
		os.rename("filters/" + filtro + "_asm.asm" , "filters/" + filtro + "_asmExperimentacion.asm")			
		os.rename("filters/" + filtro + "_asmAUX.asm" , "filters/" + filtro + "_asm.asm")


def dibujarVersiones(versiones, logaritmica = False, inicial = 0, final = len(tamanios) ):


	'''
   Realiza el grafico de barras entre las versiones de ASM 

	
	Parametros
    ----------
	version : vector<String> de tamanio dos con los nombres de las etiquetas para el grafico
	logaritmica : Bool, indica si el grafico es en escala logaritmica o no
	inicial : int, sobre el size del vector de tamanios, indica por donde empezaar
	final   : int, sobre el size del vector de tamanios, indica por donde terminar
	Returns
	---------
	Genera una imagen jpg con un grafico de barras comparando las versiones de ASM

  ''' 

	colores = ['r', 'b', 'y', 'g', 'c']
	width = 1.3
	separacion = 0.75
	x_pos = np.arange(final-inicial)
	x_pos = x_pos*(final-inicial + 2)
	x_pos = (x_pos* (width + separacion))

	fig, ax = plt.subplots()
	for version in xrange(0,len(versiones)):
		print(versiones[version])
		mean = []
		std =  []
		for tamanio in xrange(inicial,final):
			print(tamanios[tamanio])
			# data es un txt con cantidad de ciclos insumidos para cada corrida
			data = np.genfromtxt("datos/" + implementaciones[0] + "_" + filtro + "_" + str(tamanio) + "v" + str(version) + ".txt",delimiter='\n')
			std.append(data.std())
			mean.append(data.mean())

		#con desviacion
		ax.bar(x_pos + version*(width+separacion) , mean, yerr=std , color = colores[version],  align='center', width = width, log = logaritmica)
		#sin desviacion
		#ax.bar(x_pos + x*(width+separacion) , mean, color = colores[x],  align='center', width = width)



	# Build the plot

	ax.set_ylabel('Clocks', fontsize = 14)
	ax.set_xticks(x_pos + len(versiones) * (width+separacion) /2 )
	ax.set_xticklabels(tamanios[inicial:final], fontsize = 10)
	ax.yaxis.grid(True)
	plt.legend(versiones)
	ax.set_title('Uso de saltos y accesos a memoria')

	
	# si la leyenda queda mal, usar esto
	#box = ax.get_position()
	#ax.set_position([box.x0, box.y0, box.width * 0.8, box.height])

	# Put a legend to the right of the current axis
	#ax.legend(implementaciones,loc='center left', bbox_to_anchor=(1, 0.5))


	#plt.tight_layout()

	plt.show()




try:
    xrange = xrange
except NameError:
#Parche
 xrange = range


if (parametroDibujar == "0"):
	if (parametroFiltro == "0"):
		imagenSrc     == sys.argv[4]
		if (filtro == "Ocultar"):
			imagenOcultar == sys.argv[5]
			correrImplementacionesUnicaImagen(1, imagenSrc = imagenSrc, imagenOcultar = imagenOcultar)
		correrImplementacionesUnicaImagen(0, imagenSrc = imagenSrc)			
	

#Esta opcion es si se quiere comparar el filtro contra las versiones de C, contra todos los imagenes
	if (parametroFiltro == "1"):
		correrImplementaciones()


	#Esta opcion es para comparar dos versiones de ASM del filtro
	if (parametroFiltro == "2"):
		#Corre la version original de ASM
		correrAsm(version = 0)
		#Corre la version de experimentacion
		correrAsm(version = 1)
	

if (parametroDibujar == "1"):
	
	#Esta opcion es si se quiere comparar el filtro contra las versiones de C, en una sola imagen
	if (parametroFiltro == "0"):
		imagenSrc     = sys.argv[4]
		if (filtro == "Ocultar"):
			imagenOcultar == sys.argv[5]
			correrImplementacionesUnicaImagen(1, imagenSrc, imagenOcultar = imagenOcultar)
		correrImplementacionesUnicaImagen(0, imagenSrc = imagenSrc)	
		dibujarUnaImagen(borrarDatos = True, imageSrc = imagenSrc, nombre = "exp3_comp1")


	#Esta opcion es si se quiere comparar el filtro contra las versiones de C, contra todos los imagenes
	if (parametroFiltro == "1"):

		correrImplementaciones()
		dibujar(inicial = 0, final = 4, nombre = "exp3_comp1")
		dibujar(inicial = 4, nombre = "exp3_comp2")

	#Esta opcion es para comparar dos versiones de ASM del filtro
	if (parametroFiltro == "2"):
		filtro = sys.argv[3]
		nombreOriginal = sys.argv[4]
		nombreExperimentacion = sys.argv[5]
		#Corre la version original de ASM
		correrAsm(version = 0)
		#Corre la version de experimentacion
		correrAsm(version = 1)
		#Realiza la comparacion
		dibujarVersiones([nombreOriginal, nombreExperimentacion])

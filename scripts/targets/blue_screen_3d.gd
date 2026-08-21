class_name BlueScreen3D
extends Node3D

## Pantalla de error que queda encendida sobre un bloque colgado.
##
## Se dibuja como UI dentro de un SubViewport y se proyecta sobre un quad, igual
## que las ventanas disparables, pero no tiene zonas: no hay nada que hacerle.
## Ese es el punto —el bloque quedo inservible— y por eso tampoco invita a
## seguir: el mensaje no ofrece ninguna tecla que apretar.
##
## El texto imita al error de sistema de los noventa sin nombrar a nadie: la
## gracia es el reconocimiento, no la cita textual.

## Cuantos pixeles del SubViewport equivalen a un metro. Se recalcula al ajustar
## la pantalla al bloque, asi que el valor solo importa para verla en el editor.
const DEFAULT_PIXELS_PER_METER := 96.0

@onready var sub_viewport: SubViewport = $SubViewport
@onready var screen: MeshInstance3D = $Screen


## Estira la pantalla para cubrir el bloque entero. El texto no se reflowea: el
## SubViewport mantiene su resolucion y el quad se agranda, asi que en un bloque
## ancho las letras salen mas grandes, que es lo que se quiere de un error que
## tiene que leerse desde lejos.
func fit_to(size: Vector2) -> void:
	var quad := screen.mesh as QuadMesh
	if quad == null or size.x <= 0.0 or size.y <= 0.0:
		return
	quad.size = size
	# El lienzo toma la proporcion del bloque: sin esto un bloque angosto
	# estiraba el texto hasta volverlo ilegible.
	var height := sub_viewport.size.y
	sub_viewport.size = Vector2i(maxi(roundi(height * size.x / size.y), 64), height)


func _ready() -> void:
	var quad := screen.mesh as QuadMesh
	if quad != null and quad.size.is_zero_approx():
		quad.size = Vector2(sub_viewport.size) / DEFAULT_PIXELS_PER_METER

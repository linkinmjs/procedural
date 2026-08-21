@tool
class_name WindowHitZone
extends Control

## Marca un Control de la ventana como zona disparable.
## Se puede adjuntar a cualquier Control: la X de la barra, un boton o un cartel.

@export var zone_id := "close"
@export var closes_window := true
## Si acertarle suma al puntaje. Las zonas que no resuelven nada —traer la
## ventana al frente, por ejemplo— tienen que declararse en false: el puntaje
## cobra cualquier zona acertada, asi que una zona sin efecto y sin esto es
## puntos gratis e infinitos.
@export var scores := true

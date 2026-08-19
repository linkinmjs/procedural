@tool
class_name WindowHitZone
extends Control

## Marca un Control de la ventana como zona disparable.
## Se puede adjuntar a cualquier Control: la X de la barra, un boton o un cartel.

@export var zone_id := "close"
@export var closes_window := true

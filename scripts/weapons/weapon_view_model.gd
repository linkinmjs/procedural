@tool
extends Node3D
class_name WeaponViewModel

## Modelo en primera persona de un arma. Se encarga de mover todas sus mallas a
## la capa de render reservada para las armas, para que solo las ilumine la luz
## del arma y nunca se recorten contra la geometria del nivel.

## Capa visual (bit 20) que usa WeaponLight en player_character.tscn.
@export_flags_3d_render var render_layers: int = 524288:
	set(value):
		render_layers = value
		_apply_render_layers()


func _ready() -> void:
	_apply_render_layers()


func _apply_render_layers() -> void:
	if not is_inside_tree():
		return
	for mesh in find_children("*", "VisualInstance3D", true, false):
		(mesh as VisualInstance3D).layers = render_layers

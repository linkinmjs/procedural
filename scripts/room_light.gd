extends Node3D

@export var energy := 1.35
@export var warm_color := Color(1.0, 0.76, 0.52, 1.0)
@export var min_range := 8.0
@export var max_range := 18.0

@onready var light: OmniLight3D = $OmniLight3D


func _ready() -> void:
	light.light_energy = energy
	light.light_color = warm_color


func configure_for_room(room_size: Vector3) -> void:
	var horizontal_extent := maxf(room_size.x, room_size.z)
	light.omni_range = clampf(horizontal_extent * 0.72, min_range, max_range)

class_name RoomLight
extends Node3D

@export var energy := 1.35
@export var warm_color := Color(1.0, 0.76, 0.52, 1.0)
@export var min_range := 8.0
@export var max_range := 18.0

@onready var light: OmniLight3D = $OmniLight3D
@onready var fixture: MeshInstance3D = $Fixture

## Fraccion de la energia nominal que esta encendida ahora (1 = plena).
var dim_factor := 1.0
var _dim_tween: Tween
## El material del fixture viene compartido por la escena; se duplica para que
## atenuar esta sala no apague las luminarias de las demas.
var _fixture_material: StandardMaterial3D
var _base_emission := 1.0


func _ready() -> void:
	light.light_color = warm_color
	var source := fixture.mesh.material as StandardMaterial3D if fixture.mesh else null
	if source != null:
		_fixture_material = source.duplicate() as StandardMaterial3D
		_base_emission = _fixture_material.emission_energy_multiplier
		fixture.material_override = _fixture_material
	set_dim(dim_factor)


func configure_for_room(room_size: Vector3) -> void:
	var horizontal_extent := maxf(room_size.x, room_size.z)
	light.omni_range = clampf(horizontal_extent * 0.72, min_range, max_range)


## Aplica una fraccion de la energia nominal al instante. Escala sobre el
## export `energy`, no sobre el valor actual, porque el nivel lo fija antes de
## que la escena este lista.
func set_dim(factor: float) -> void:
	dim_factor = clampf(factor, 0.0, 1.0)
	light.light_energy = energy * dim_factor
	if _fixture_material != null:
		_fixture_material.emission_energy_multiplier = _base_emission * dim_factor


## Lleva la luz a `factor` en `duration` segundos. Con `realtime` el fundido
## ignora el time_scale y sigue aunque el arbol se pause, para acompañar la
## camara lenta del cierre de ronda.
func dim_to(factor: float, duration: float, realtime := false) -> void:
	if _dim_tween != null and _dim_tween.is_valid():
		_dim_tween.kill()
	if duration <= 0.0:
		set_dim(factor)
		return
	_dim_tween = create_tween()
	if realtime:
		_dim_tween.set_ignore_time_scale(true)
		_dim_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_dim_tween.tween_method(set_dim, dim_factor, clampf(factor, 0.0, 1.0), duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

@tool
class_name TargetSpawnVolume3D
extends Node3D

signal targets_spawned(targets: Array[Node3D])
signal all_targets_destroyed

## Un objetivo se considera resuelto cuando emite alguna de estas señales.
## Cubre las pelotas (destroyed, left) y las ventanas (closed).
const RESOLVE_SIGNALS: Array[String] = ["destroyed", "left", "closed"]

## Escenas que se pueden distribuir. Cada objetivo elige una al azar. Es como lo
## usan las pelotas, que no tienen familias.
@export var target_scenes: Array[PackedScene] = [preload("res://scenes/targets/target_ball.tscn")]
## Escenas concretas, una por objetivo y en orden. Cuando esta cargada manda
## sobre target_scenes y target_count: es lo que usan los bloques de ventanas,
## donde cada capa declara que familia va en cada lugar y el azar no decide.
@export var scripted_targets: Array[PackedScene] = []
## Configuracion por objetivo, paralela a scripted_targets. Es la variante de un
## diseño del Window Workshop (titulo, mensaje, tamaño); vacia, la escena se
## spawnea tal cual. Se aplica antes de add_child para que _ready la vea.
@export var scripted_configs: Array[Dictionary] = []
@export var penalty_target_scene: PackedScene = preload("res://scenes/targets/blue_penalty_ball.tscn")
@export_range(1, 64, 1) var target_count := 8
@export_range(0, 64, 1) var penalty_target_count := 0
@export var target_color := Color(0.08, 0.78, 1.0, 1.0)
@export var size := Vector3(10.0, 4.0, 0.6):
	set(value):
		size = value.max(Vector3(0.1, 0.1, 0.1))
		_update_debug_bounds()
## Separacion minima entre objetivos. Dos objetivos no se solapan cuando estan
## suficientemente separados en horizontal o en vertical, asi que este valor se
## corresponde con el tamaño del objetivo.
@export var minimum_separation := Vector2(1.0, 1.0)
@export var edge_padding := Vector3(0.4, 0.4, 0.0)
## Separacion en profundidad entre objetivos consecutivos. Los apila como
## ventanas en un escritorio: se pueden superponer sin pelear por el mismo plano.
@export_range(0.0, 1.0, 0.005) var stacking_depth := 0.08
@export var random_seed := 0
@export var spawn_on_ready := true
@export var debug_bounds_visible := true:
	set(value):
		debug_bounds_visible = value
		_update_debug_bounds()

@onready var debug_bounds: MeshInstance3D = $DebugBounds
@onready var targets_container: Node3D = $Targets

var active_targets: Array[Node3D] = []
var _debug_active := false


func _ready() -> void:
	_update_debug_bounds()
	if not Engine.is_editor_hint() and spawn_on_ready:
		spawn_targets()


func spawn_targets() -> void:
	if Engine.is_editor_hint() or _usable_target_scenes().is_empty():
		return
	if not scripted_targets.is_empty():
		target_count = scripted_targets.size()
	_debug_active = true
	_update_debug_bounds()
	clear_targets()
	var rng := RandomNumberGenerator.new()
	if random_seed == 0:
		rng.randomize()
	else:
		rng.seed = random_seed
	var scenes := _usable_target_scenes()
	var positions := _build_spawn_positions(rng)
	var penalty_indices := _pick_penalty_indices(positions.size(), rng)
	for index in positions.size():
		var is_penalty := penalty_indices.has(index)
		var scene_to_spawn := penalty_target_scene if is_penalty else _scene_for_index(index, scenes, rng)
		var target := scene_to_spawn.instantiate() as Node3D
		if target == null:
			push_error("TargetSpawnVolume3D requires target scenes with a Node3D root.")
			continue
		if not is_penalty and target is TargetBall:
			var ball := target as TargetBall
			ball.display_color = target_color
			ball.use_custom_display_color = true
		if not is_penalty and index < scripted_configs.size() and not scripted_configs[index].is_empty():
			target.set("variant_config", scripted_configs[index])
		targets_container.add_child(target)
		target.position = _place_target(target, positions[index], index)
		_connect_target(target)
		active_targets.append(target)
	targets_spawned.emit(active_targets.duplicate())


## Coloca el objetivo dentro del volumen y lo adelanta segun su orden, para que
## dos objetivos superpuestos nunca queden en el mismo plano.
func _place_target(target: Node3D, position: Vector3, index: int) -> Vector3:
	var placed := position
	placed.z += index * stacking_depth
	if not target.has_method("get_window_size"):
		return placed
	var extents: Vector2 = target.call("get_window_size") * 0.5
	var limit := Vector2(maxf(size.x * 0.5 - extents.x, 0.0), maxf(size.y * 0.5 - extents.y, 0.0))
	placed.x = clampf(placed.x, -limit.x, limit.x)
	placed.y = clampf(placed.y, -limit.y, limit.y)
	return placed


## Con una lista escrita, cada lugar recibe la escena que le toca; sin ella, una
## al azar del repertorio.
func _scene_for_index(index: int, scenes: Array[PackedScene], rng: RandomNumberGenerator) -> PackedScene:
	if index < scripted_targets.size():
		return scripted_targets[index]
	return scenes[rng.randi_range(0, scenes.size() - 1)]


func _usable_target_scenes() -> Array[PackedScene]:
	if not scripted_targets.is_empty():
		return scripted_targets.duplicate()
	var scenes: Array[PackedScene] = []
	for scene in target_scenes:
		if scene != null:
			scenes.append(scene)
	return scenes


func _connect_target(target: Node3D) -> void:
	for signal_name in RESOLVE_SIGNALS:
		if target.has_signal(signal_name):
			target.connect(signal_name, _on_target_resolved)


## Suma un objetivo que nacio despues del reparto, como la publicidad que llama a
## otra. Sin esto la capa se daria por limpia con la nueva todavia en pantalla.
##
## Ademas lo ubica dentro del volumen: una ventana que se pone sola al lado de la
## que la llamo termina, despues de unas cuantas, fuera del bloque y debajo del
## piso.
func adopt_target(target: Node3D) -> void:
	if target == null or active_targets.has(target):
		return
	active_targets.append(target)
	_connect_target(target)
	target.position = _random_spot(active_targets.size() - 1, target)


## Un lugar libre dentro del volumen, con el mismo escalonado en profundidad que
## usa el reparto inicial.
func _random_spot(order: int, target: Node3D) -> Vector3:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var half := Vector3(
		maxf(size.x * 0.5 - edge_padding.x, 0.0),
		maxf(size.y * 0.5 - edge_padding.y, 0.0),
		maxf(size.z * 0.5 - edge_padding.z, 0.0)
	)
	var spot := Vector3(
		rng.randf_range(-half.x, half.x),
		rng.randf_range(-half.y, half.y),
		rng.randf_range(-half.z, half.z)
	)
	return _place_target(target, spot, order)


func clear_targets() -> void:
	for target in active_targets:
		if is_instance_valid(target):
			target.queue_free()
	active_targets.clear()


func _build_spawn_positions(rng: RandomNumberGenerator) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	var half_size := Vector3(
		maxf(size.x * 0.5 - edge_padding.x, 0.0),
		maxf(size.y * 0.5 - edge_padding.y, 0.0),
		maxf(size.z * 0.5 - edge_padding.z, 0.0)
	)
	if is_zero_approx(half_size.x) or is_zero_approx(half_size.y) or is_zero_approx(half_size.z):
		push_warning("TargetSpawnVolume3D edge_padding leaves no usable spawn space.")
		return positions
	var attempts_remaining := target_count * 30
	while positions.size() < target_count and attempts_remaining > 0:
		attempts_remaining -= 1
		var candidate := Vector3(
			rng.randf_range(-half_size.x, half_size.x),
			rng.randf_range(-half_size.y, half_size.y),
			rng.randf_range(-half_size.z, half_size.z)
		)
		if positions.all(func(existing: Vector3) -> bool: return _is_separated(existing, candidate)):
			positions.append(candidate)
	if positions.size() < target_count:
		push_warning("TargetSpawnVolume3D could only place %d of %d targets. Increase size or reduce minimum_separation." % [positions.size(), target_count])
	return positions


func _is_separated(existing: Vector3, candidate: Vector3) -> bool:
	return absf(existing.x - candidate.x) >= minimum_separation.x or absf(existing.y - candidate.y) >= minimum_separation.y


func _on_target_resolved(target: Node3D) -> void:
	if not active_targets.has(target):
		return
	active_targets.erase(target)
	if active_targets.is_empty():
		all_targets_destroyed.emit()


func _pick_penalty_indices(available_count: int, rng: RandomNumberGenerator) -> Array[int]:
	var candidates: Array[int] = []
	for index in available_count:
		candidates.append(index)
	for index in range(candidates.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var previous := candidates[index]
		candidates[index] = candidates[swap_index]
		candidates[swap_index] = previous
	return candidates.slice(0, mini(penalty_target_count, available_count))


func _update_debug_bounds() -> void:
	if not is_node_ready():
		return
	debug_bounds.visible = debug_bounds_visible and (Engine.is_editor_hint() or _debug_active)
	var box := debug_bounds.mesh as BoxMesh
	box.size = size

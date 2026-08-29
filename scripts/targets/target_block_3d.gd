class_name TargetBlock3D
extends Area3D

signal closed(block: TargetBlock3D)
## El bloque se colgo: sigue en pie pero ya no trae mas capas.
signal crashed(block: TargetBlock3D)

@export var block_label := "front block"
@export_range(0, 64, 1) var target_count := 4
## Capas de ventanas del bloque, cada una con la familia que va en cada lugar.
## Limpiar una descubre la siguiente; al terminar la ultima el bloque se cierra.
## Es el nivel de adentro: el de afuera son las oleadas de la sala.
@export var layers: Array[PackedStringArray] = []
@export var block_color := Color(0.08, 0.78, 1.0, 1.0)
@export var moves_to_opposite_side := false
@export_range(0.05, 5.0, 0.05) var movement_speed := 0.65
@export_range(0.0, 100.0, 0.1) var travel_distance := 10.0
@export_range(0.0, 100.0, 1.0) var crossing_damage := 15.0
@export var movement_direction := Vector3.ZERO
@export var block_size := Vector2(8.0, 4.0)
## Si las capas nombran familias de ventana y el catalogo resuelve cual va en
## cada lugar. Apagarlo devuelve al bloque al reparto al azar entre
## `target_scenes`, que es como se prueban las pelotas.
@export var uses_window_families := true
## Escenas que reparte el bloque cuando no usa familias. Cada objetivo elige una
## al azar.
@export var target_scenes: Array[PackedScene] = [
	preload("res://scenes/windows/shutdown_window.tscn"),
	preload("res://scenes/windows/close_window.tscn"),
	preload("res://scenes/windows/download_window.tscn"),
]
## Separacion minima entre objetivos y margen interior del bloque, en metros.
## Los valores por defecto contemplan el tamaño de una ventana.
## Con valores menores al tamaño del objetivo las ventanas se superponen, que es
## el comportamiento buscado. El volumen las escalona en profundidad y cada una
## se recorta contra los bordes del bloque, asi que el solape se ve limpio.
@export var target_separation := Vector2(2.0, 1.0)
@export var target_padding := Vector2(0.2, 0.2)
## Zumbido de pantalla del bloque. De lejos apenas se siente; de cerca sube de
## volumen, baja de tono y se le suma un gruñido grave que late: intimida a
## quien se acerca y no molesta a quien esta lejos.
@export_group("Hum")
@export var hum_enabled := true
@export_range(-40.0, 0.0, 0.5) var hum_volume_db := -16.0
@export_range(-40.0, 0.0, 0.5) var hum_near_volume_db := -2.0
## Distancia a la camara desde la que el zumbido esta a pleno.
@export_range(0.5, 20.0, 0.5) var hum_near_distance := 4.0
## Variacion de tono entre bloques, para que no suenen clonados.
@export_range(0.0, 0.5, 0.01) var hum_pitch_jitter := 0.04
## Cuanto baja el tono al acercarse.
@export_range(0.0, 0.5, 0.01) var hum_near_detune := 0.07
## Volumen del gruñido pegado al bloque y desde que distancia esta a pleno; mas
## lejos que el max_distance de su emisor no se oye nada.
@export_range(-40.0, 0.0, 0.5) var growl_near_volume_db := -3.0
@export_range(0.5, 20.0, 0.5) var growl_near_distance := 2.0
@export_group("")

@onready var block_mesh: MeshInstance3D = $BlockMesh
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var spawn_volume: TargetSpawnVolume3D = $TargetSpawnVolume3D
@onready var hum_player: AudioStreamPlayer3D = get_node_or_null("HumPlayer")
@onready var growl_player: AudioStreamPlayer3D = get_node_or_null("GrowlPlayer")
## Volumen del gruñido cuando no hay nadie cerca: inaudible, no apagado, para
## que entre sin click.
const GROWL_SILENT_DB := -60.0

const BLUE_SCREEN_SCENE := preload("res://scenes/targets/blue_screen.tscn")
## Cuanto se adelanta la pantalla de error respecto de la cara del bloque, para
## que no pelee con ella por el mismo plano.
const CRASH_SCREEN_OFFSET := 0.2

var _distance_travelled := 0.0
var _closing := false
## El bloque se colgo por una descarga infectada. Cuenta como resuelto —abre las
## puertas— pero no desaparece: queda en pantalla azul, y si se movia sigue
## moviendose y sigue lastimando al que lo cruce.
var _crashed := false
var _bodies_inside: Array[Node3D] = []
var _layers: Array[PackedStringArray] = []
var _current_layer_index := 0
var _hum_base_pitch := 1.0
## Cercania actual (0 lejos, 1 encima), suavizada para que no salte.
var _hum_closeness := 0.0
var _growl_closeness := 0.0
var _hum_accumulator := 0.0
const HUM_UPDATE_SECONDS := 0.1


func _ready() -> void:
	_update_geometry()
	_update_appearance()
	_start_hum()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_layers.assign(layers)
	# Un bloque configurado a mano en el editor solo dice cuantos objetivos
	# quiere: se lo entiende como una sola capa de ventanas normales.
	if _layers.is_empty() and target_count > 0:
		var single := PackedStringArray()
		for _index in target_count:
			single.append(WindowCatalog.NORMAL_TYPE)
		_layers.append(single)
	if not _layers.is_empty():
		spawn_volume.penalty_target_count = 0
		spawn_volume.spawn_on_ready = false
		spawn_volume.all_targets_destroyed.connect(_on_layer_cleared)
		_spawn_current_layer()
	else:
		spawn_volume.visible = false
		_spawn_close_control()


func _physics_process(delta: float) -> void:
	_update_hum(delta)
	if not moves_to_opposite_side or _closing or movement_direction.is_zero_approx():
		return
	if _distance_travelled >= travel_distance:
		return
	var step := minf(movement_speed * delta, travel_distance - _distance_travelled)
	position += movement_direction.normalized() * step
	_distance_travelled += step


func _update_geometry() -> void:
	var physical_size := Vector3(block_size.x, block_size.y, 0.28)
	var mesh := block_mesh.mesh as BoxMesh
	mesh.size = physical_size
	var shape := collision_shape.shape as BoxShape3D
	shape.size = physical_size
	spawn_volume.position = Vector3(0.0, 0.0, 0.5)
	spawn_volume.size = Vector3(maxf(block_size.x - 1.0, 0.5), maxf(block_size.y - 1.0, 0.5), 0.02)
	spawn_volume.edge_padding = Vector3(target_padding.x, target_padding.y, 0.0)
	spawn_volume.minimum_separation = target_separation
	spawn_volume.target_scenes = target_scenes


func _update_appearance() -> void:
	var mesh := block_mesh.mesh as BoxMesh
	if mesh != null and mesh.material is StandardMaterial3D:
		var material := mesh.material.duplicate() as StandardMaterial3D
		var panel_color := block_color
		panel_color.a = 0.2
		material.albedo_color = panel_color
		material.emission = block_color.darkened(0.45)
		mesh.material = material
	spawn_volume.target_color = block_color


## Una ventana puede tumbar el bloque entero. El bloque se entera por señal: es
## el que conoce al catalogo de ventanas, asi que la ventana no puede conocerlo a
## el sin cerrar un ciclo entre los dos.
func _listen_for_crashes() -> void:
	for target in spawn_volume.active_targets:
		if target.has_signal("system_crashed") and not target.is_connected("system_crashed", _on_target_crashed):
			target.connect("system_crashed", _on_target_crashed)


func _on_target_crashed(window: Node) -> void:
	crash(str(window.get("window_label")))


## Una descarga infectada llego al final: el bloque se cuelga. Las capas que
## faltaban no llegan nunca, pero la sala puede seguir, porque para el encuentro
## el bloque queda resuelto.
func crash(source_label: String) -> void:
	if _crashed or _closing:
		return
	_crashed = true
	# La pantalla se cuelga y el zumbido se corta en seco con ella.
	_stop_hum()
	# Lo que quedaba de la capa se va con el bloque: no hay capa intermedia ni
	# nada mas que romper. El bloque queda inservible de una.
	spawn_volume.clear_targets()
	spawn_volume.visible = false
	block_mesh.visible = false
	_show_blue_screen()
	var controller := _get_round_controller()
	if controller != null:
		controller.add_log(tr("LOG_BLOCK_CRASHED").format({
			"block": block_label.to_upper(),
			"source": source_label.to_upper(),
		}), "danger")
	crashed.emit(self)
	# Se avisa que quedo resuelto sin liberarlo: la pantalla se queda encendida.
	closed.emit(self)


## La pantalla de error, del tamaño del bloque. Reemplaza al panel translucido:
## donde habia objetivos ahora hay una pared encendida que no se apaga.
func _show_blue_screen() -> void:
	var screen := BLUE_SCREEN_SCENE.instantiate() as BlueScreen3D
	screen.name = "BlueScreen"
	add_child(screen)
	screen.fit_to(block_size)
	screen.position = Vector3(0.0, 0.0, CRASH_SCREEN_OFFSET)


func _spawn_current_layer() -> void:
	if _crashed or _closing or _current_layer_index >= _layers.size():
		return
	var types := _layers[_current_layer_index]
	# Sin familias el volumen vuelve a elegir al azar: solo le importa cuantas.
	var scripted: Array[PackedScene] = []
	var configs: Array[Dictionary] = []
	if uses_window_families:
		# El plan trae escena y configuracion por ventana: las familias de
		# fabrica llevan configuracion vacia y los diseños custom, su variante.
		for entry in WindowCatalog.spawn_plan_for(types):
			scripted.append(entry.scene as PackedScene)
			configs.append(entry.config as Dictionary)
	spawn_volume.scripted_targets = scripted
	spawn_volume.scripted_configs = configs
	spawn_volume.target_count = types.size()
	spawn_volume.spawn_targets()
	_listen_for_crashes()
	if spawn_volume.active_targets.is_empty():
		push_warning("%s layer %d could not place any targets; skipping it." % [block_label, _current_layer_index + 1])
		call_deferred("_on_layer_cleared")
	var controller := _get_round_controller()
	if controller != null:
		controller.add_log(tr("LOG_LAYER").format({
			"block": block_label.to_upper(),
			"layer": _current_layer_index + 1,
			"total": _layers.size(),
			"targets": types.size(),
		}), "info")


func _on_layer_cleared() -> void:
	if _crashed:
		return
	_current_layer_index += 1
	if _current_layer_index >= _layers.size():
		_close()
		return
	call_deferred("_spawn_current_layer")


func _spawn_close_control() -> void:
	var close_target := preload("res://scenes/targets/close_target_ball.tscn").instantiate() as TargetBall
	add_child(close_target)
	close_target.position = Vector3(block_size.x * 0.5 - 0.55, block_size.y * 0.5 - 0.55, 0.5)
	close_target.destroyed.connect(_on_close_control_hit)


func _on_close_control_hit(_target: TargetBall) -> void:
	_close()


func _on_body_entered(body: Node3D) -> void:
	if not body is CharacterBody3D or _bodies_inside.has(body):
		return
	_bodies_inside.append(body)
	var controller := _get_round_controller()
	if controller != null:
		controller.report_block_crossed(block_label, crossing_damage)


func _on_body_exited(body: Node3D) -> void:
	_bodies_inside.erase(body)


func _close() -> void:
	if _closing or _crashed:
		return
	_closing = true
	_stop_hum()
	var controller := _get_round_controller()
	if controller != null:
		controller.add_log(tr("LOG_BLOCK_CLOSED").format({"block": block_label.to_upper()}), "system")
	closed.emit(self)
	queue_free()


## Arranca el zumbido desde un punto al azar del loop: varios bloques en fase
## sonarian como uno solo mas fuerte.
func _start_hum() -> void:
	if hum_player == null or not hum_enabled:
		return
	hum_player.stream = LedHumSynth.get_stream()
	_hum_base_pitch = 1.0 + randf_range(-hum_pitch_jitter, hum_pitch_jitter)
	hum_player.pitch_scale = _hum_base_pitch
	hum_player.volume_db = hum_volume_db
	hum_player.play(randf() * LedHumSynth.LOOP_SECONDS)
	if growl_player != null:
		growl_player.stream = LedHumSynth.get_growl_stream()
		growl_player.pitch_scale = _hum_base_pitch
		growl_player.volume_db = GROWL_SILENT_DB
		growl_player.play(randf() * LedHumSynth.LOOP_SECONDS)


func _stop_hum() -> void:
	if hum_player != null:
		hum_player.stop()
	if growl_player != null:
		growl_player.stop()


## Cuanto mas cerca la camara, mas fuerte y mas grave, y el gruñido asoma
## recien en los ultimos metros. Se mide cada decima de segundo y se suaviza:
## la distancia cambia a saltos con el jugador corriendo.
func _update_hum(delta: float) -> void:
	if hum_player == null or not hum_player.playing:
		return
	_hum_accumulator += delta
	if _hum_accumulator < HUM_UPDATE_SECONDS:
		return
	_hum_accumulator = 0.0
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var distance := global_position.distance_to(camera.global_position)
	var far := maxf(hum_player.max_distance, hum_near_distance + 0.01)
	var target := 1.0 - clampf((distance - hum_near_distance) / (far - hum_near_distance), 0.0, 1.0)
	_hum_closeness = lerpf(_hum_closeness, target, 0.35)
	var squared := _hum_closeness * _hum_closeness
	hum_player.volume_db = lerpf(hum_volume_db, hum_near_volume_db, _hum_closeness)
	hum_player.pitch_scale = _hum_base_pitch * (1.0 - hum_near_detune * squared)
	if growl_player != null and growl_player.playing:
		var growl_far := maxf(growl_player.max_distance, growl_near_distance + 0.01)
		var growl_target := 1.0 - clampf((distance - growl_near_distance) / (growl_far - growl_near_distance), 0.0, 1.0)
		_growl_closeness = lerpf(_growl_closeness, growl_target, 0.35)
		growl_player.volume_db = lerpf(GROWL_SILENT_DB, growl_near_volume_db, _growl_closeness * _growl_closeness)


## El controlador de ronda se busca una vez por escena; los bloques lo piden
## en cada cierre y cada cruce.
static var _cached_round_controller: RoundController


func _get_round_controller() -> RoundController:
	if is_instance_valid(_cached_round_controller) and _cached_round_controller.is_inside_tree():
		return _cached_round_controller
	var controllers := get_tree().get_nodes_in_group("round_controller")
	_cached_round_controller = controllers[0] as RoundController if not controllers.is_empty() else null
	return _cached_round_controller

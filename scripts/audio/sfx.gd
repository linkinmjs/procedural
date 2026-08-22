class_name Sfx
extends RefCounted

## Ganchos de sonido del juego, con el audio diferido a una instancia final.
##
## Cada efecto de juice llama Sfx.play() o Sfx.play_at() con un nombre de
## evento estable. Los streams viven en resources/audio/sfx_library.tres:
## mientras un evento no tenga stream asignado, la llamada no hace nada, en
## silencio. Integrar el audio del juego es llenar ese recurso, sin tocar
## gameplay.
##
## Es una clase estatica y no un autoload a proposito: los smoke tests corren
## con `-s` y compilan los scripts antes de que los autoloads existan, asi que
## un identificador de autoload no compila ahi. El host con los reproductores
## se cuelga solo del arbol la primera vez que algo suena.

const LIBRARY_PATH := "res://resources/audio/sfx_library.tres"

static var _host: SfxHost = null


## Sonido sin posicion: UI, HUD, feedback del jugador.
static func play(event: String, pitch: float = 1.0) -> void:
	var host := _ensure_host()
	if host != null:
		host.play_event(event, pitch)


## Sonido posicionado en el mundo: impactos, ventanas, objetivos.
static func play_at(event: String, world_position: Vector3, pitch: float = 1.0) -> void:
	var host := _ensure_host()
	if host != null:
		host.play_event_at(event, world_position, pitch)


static func _ensure_host() -> SfxHost:
	if _host != null and is_instance_valid(_host):
		return _host
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	_host = SfxHost.new()
	_host.name = "SfxHost"
	# Diferido: la primera llamada puede llegar mientras el arbol esta armando
	# hijos, y add_child directo ahi no esta permitido.
	tree.root.add_child.call_deferred(_host)
	return _host


## Nodo real con los pools de reproductores. Vive colgado de la raiz.
class SfxHost:
	extends Node

	const BUS := "SFX"
	const POOL_2D_SIZE := 6
	const POOL_3D_SIZE := 12

	var _library: SfxLibrary
	var _pool_2d: Array[AudioStreamPlayer] = []
	var _pool_3d: Array[AudioStreamPlayer3D] = []

	func _ready() -> void:
		if ResourceLoader.exists(LIBRARY_PATH):
			_library = load(LIBRARY_PATH) as SfxLibrary
		for _i in POOL_2D_SIZE:
			var player := AudioStreamPlayer.new()
			player.bus = BUS
			add_child(player)
			_pool_2d.append(player)
		for _i in POOL_3D_SIZE:
			var player := AudioStreamPlayer3D.new()
			player.bus = BUS
			add_child(player)
			_pool_3d.append(player)

	func play_event(event: String, pitch: float) -> void:
		if not is_inside_tree():
			return
		var stream := _stream_for(event)
		if stream == null:
			return
		var player := _next_free_2d()
		player.stream = stream
		player.pitch_scale = pitch
		player.play()

	func play_event_at(event: String, world_position: Vector3, pitch: float) -> void:
		if not is_inside_tree():
			return
		var stream := _stream_for(event)
		if stream == null:
			return
		var player := _next_free_3d()
		player.global_position = world_position
		player.stream = stream
		player.pitch_scale = pitch
		player.play()

	func _stream_for(event: String) -> AudioStream:
		if _library == null:
			return null
		return _library.streams.get(event) as AudioStream

	## Si todos estan sonando se roba el primero: con este tamanio de pool casi
	## nunca pasa, y cortar el sonido mas viejo es lo menos notorio.
	func _next_free_2d() -> AudioStreamPlayer:
		for player in _pool_2d:
			if not player.playing:
				return player
		return _pool_2d[0]

	func _next_free_3d() -> AudioStreamPlayer3D:
		for player in _pool_3d:
			if not player.playing:
				return player
		return _pool_3d[0]

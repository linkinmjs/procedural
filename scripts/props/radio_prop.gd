class_name RadioProp
extends StaticBody3D

## Radio con musica en loop apoyada en una esquina de la sala.
##
## Lleva dos reproductores con la misma cancion. `PlainSpeaker` es un
## AudioStreamPlayer3D comun que suena siempre y marca el tiempo. `Speaker` es
## el SpatialAudio3D (reverb y oclusion medidas desde la sala), caro en rayos y
## en buses, que el RadioDirector enciende solo en la radio mas cercana al
## jugador, arrancandolo desde la posicion del plain para que la cancion no
## salte. El cruce es en serie: primero se calla uno y recien despues suena el
## otro, porque dos copias de la misma cancion sumadas recortaban y, con unos
## milisegundos de desfase, sonaban a flanger. Donde `Quality` apaga el audio
## espacial (Web) la radio se queda sin `Speaker` antes de entrar al arbol y
## suena solo con el plain. Ambos van al bus Music, asi el volumen de musica
## de las opciones la sigue controlando aunque suene posicionada.
##
## Un disparo la rompe: deja de sonar, suelta esquirlas y queda gris en su
## esquina como rastro de lo que paso.

signal broken(radio: RadioProp)

## Capa 1 (mundo): la radio rota sigue siendo solida pero deja de comer tiros.
const WORLD_LAYER := 1
## Volumen al que se hunde el plain mientras el espacial lleva la cancion.
const SILENT_DB := -80.0
@export_range(0.0, 1.0, 0.05) var crossfade_seconds := 0.25

## Nulo cuando el perfil no paga audio espacial.
@onready var speaker: AudioStreamPlayer3D = get_node_or_null("Speaker")
@onready var plain_speaker: AudioStreamPlayer3D = $PlainSpeaker
@onready var model: MeshInstance3D = $Model

var is_broken := false
var spatial_active := false
var _plain_volume_db := -4.0
var _fade_tween: Tween


## El addon arma sus veinte reproductores y buses en su propio _ready, que
## corre antes que el de la radio: la unica forma de no pagarlos es sacar el
## nodo antes de que entre al arbol.
func _enter_tree() -> void:
	if Quality.spatial_audio_enabled():
		return
	var spatial := get_node_or_null("Speaker")
	if spatial != null:
		remove_child(spatial)
		spatial.free()


func _ready() -> void:
	_plain_volume_db = plain_speaker.volume_db
	if not plain_speaker.playing:
		plain_speaker.play()
	# El addon mide la sala con rayos en cada tick aunque no suene; solo la
	# radio activa paga ese costo.
	_set_spatial_ticking(false)


## Si la radio puede llevar la acustica de sala en esta plataforma.
func has_spatial() -> bool:
	return speaker != null


## Si la fuente del addon esta emitiendo. El nodo Speaker en si nunca "suena":
## delega en los reproductores que crea adentro.
func is_spatial_playing() -> bool:
	if speaker == null:
		return false
	var source: Variant = speaker.get("soundsource")
	if source == null:
		return bool(speaker.playing)
	var player: Variant = source.get("soundplayer_active")
	return player != null and bool(player.playing)


func _set_spatial_ticking(ticking: bool) -> void:
	if speaker != null:
		speaker.set_physics_process(ticking)


## Contrato de los disparos (grupo Target + este metodo). Un impacto alcanza.
func Hit_Successful(_damage: float, _direction := Vector3.ZERO, _hit_position := Vector3.ZERO) -> void:
	break_radio()


func break_radio() -> void:
	if is_broken:
		return
	is_broken = true
	collision_layer = WORLD_LAYER
	remove_from_group("Target")
	_stop_all()
	Sfx.play_at("target_destroyed", global_position, 0.7)
	_spawn_burst()
	_show_broken_look()
	broken.emit(self)


## Enciende o apaga la acustica de sala, siempre en serie: nunca suenan las
## dos copias a la vez. Al encender, el plain se hunde y recien callado arranca
## el espacial desde donde iba; al apagar, el espacial se corta en seco y el
## plain vuelve. Sin Speaker (perfil sin audio espacial) no hay nada que hacer.
func set_spatial_active(active: bool) -> void:
	if is_broken or speaker == null or active == spatial_active:
		return
	spatial_active = active
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	if active:
		_fade_tween.tween_property(plain_speaker, "volume_db", SILENT_DB, crossfade_seconds)
		_fade_tween.tween_callback(_start_spatial)
	else:
		_set_spatial_ticking(false)
		_stop_spatial()
		_fade_tween.tween_property(plain_speaker, "volume_db", _plain_volume_db, crossfade_seconds)


func _start_spatial() -> void:
	if is_broken or not spatial_active or speaker == null:
		return
	_set_spatial_ticking(true)
	var from_position := plain_speaker.get_playback_position() + AudioServer.get_time_since_last_mix()
	if speaker.has_method("do_play"):
		speaker.call("do_play", from_position)
	else:
		speaker.play(from_position)


func _stop_spatial() -> void:
	if speaker == null:
		return
	if speaker.has_method("do_stop"):
		speaker.call("do_stop")
	else:
		speaker.stop()


func _stop_all() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	spatial_active = false
	_set_spatial_ticking(false)
	plain_speaker.stop()
	_stop_spatial()


## La radio rota se apaga de color y da un respingo.
func _show_broken_look() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.16, 0.15, 0.14)
	material.roughness = 0.95
	model.material_override = material
	var base_scale := model.scale
	var tween := create_tween()
	tween.tween_property(model, "scale", base_scale * 1.08, 0.08)
	tween.tween_property(model, "scale", base_scale * 0.96, 0.17) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Esquirlas colgadas del padre, como las de la bola, para que no dependan de
## este nodo. Se construyen por codigo.
func _spawn_burst() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var particles := GPUParticles3D.new()
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.22
	process.spread = 180.0
	process.initial_velocity_min = 1.4
	process.initial_velocity_max = 2.8
	process.gravity = Vector3(0.0, -6.0, 0.0)
	process.scale_min = 0.4
	process.scale_max = 1.0
	particles.process_material = process
	var shard := BoxMesh.new()
	shard.size = Vector3(0.04, 0.04, 0.04)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.55, 0.42, 0.28)
	shard.material = material
	particles.draw_pass_1 = shard
	particles.amount = 12
	particles.lifetime = 0.55
	particles.one_shot = true
	particles.explosiveness = 1.0
	parent.add_child(particles)
	particles.global_position = global_position + Vector3(0.0, 0.3, 0.0)
	# `finished` limpia en el juego real; el timer es el respaldo del renderer
	# dummy (headless), donde las particulas no procesan.
	particles.finished.connect(particles.queue_free)
	particles.get_tree().create_timer(particles.lifetime + 0.5).timeout.connect(func() -> void:
		if is_instance_valid(particles):
			particles.queue_free()
	)
	particles.emitting = true

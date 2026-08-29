class_name RadioDirector
extends Node

## Reparte la acustica de sala entre las radios del nivel.
##
## Cada SpatialAudio3D activo cuesta cientos de rayos por segundo y veinte
## buses con efectos, asi que solo la radio mas cercana a la camara lleva reverb
## y oclusion; el resto suena con su reproductor 3D comun. La histeresis evita
## que dos radios a distancia parecida se roben el turno a cada paso: cada
## cambio calla una radio un instante, asi que mejor pocos. Donde Quality apaga
## el audio espacial (Web) el director no activa ninguna.

@export_range(0.1, 2.0, 0.1) var poll_seconds := 0.5
## Metros que la nueva candidata tiene que ganarle a la activa para reemplazarla.
@export_range(0.0, 20.0, 0.5) var switch_hysteresis := 4.0

var radios: Array[RadioProp] = []
var active: RadioProp
var _elapsed := 0.0


func register(radio: RadioProp) -> void:
	radios.append(radio)
	radio.broken.connect(_on_radio_broken)
	radio.tree_exiting.connect(_forget.bind(radio))


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < poll_seconds:
		return
	_elapsed = 0.0
	poll()


## Elige la radio sana mas cercana y, si vale la pena, le pasa la acustica.
func poll() -> void:
	if not Quality.spatial_audio_enabled():
		return
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null:
		return
	var listener := camera.global_position
	var best: RadioProp = null
	var best_distance := INF
	for radio in radios:
		if radio.is_broken:
			continue
		var distance := radio.global_position.distance_to(listener)
		if distance < best_distance:
			best_distance = distance
			best = radio
	if best == active:
		return
	if active != null and not active.is_broken and best != null:
		var active_distance := active.global_position.distance_to(listener)
		if best_distance + switch_hysteresis >= active_distance:
			return
	_switch(best)


func _switch(next: RadioProp) -> void:
	if active != null and is_instance_valid(active):
		active.set_spatial_active(false)
	active = next
	if active != null:
		active.set_spatial_active(true)


func _on_radio_broken(radio: RadioProp) -> void:
	if radio == active:
		active = null
		poll()


func _forget(radio: RadioProp) -> void:
	radios.erase(radio)
	if radio == active:
		active = null

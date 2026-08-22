extends SceneTree

## La biblioteca de sonidos tiene que cubrir todos los eventos que el juego
## dispara, y cada stream tiene que cargar. Un evento sin stream no falla en
## runtime (Sfx lo ignora en silencio), asi que este es el unico lugar donde
## un sonido olvidado se hace visible.

const LIBRARY_PATH := "res://resources/audio/sfx_library.tres"
const EXPECTED_EVENTS: Array[String] = [
	"impact_wall", "target_destroyed", "window_button", "window_close",
	"window_error", "shield_blocked", "ad_skip_ready", "hitmarker",
	"player_hurt", "footstep", "land", "combo_step_up", "combo_drop",
	"chain_lost", "chain_saved", "chain_tick", "bank",
	"ui_hover", "ui_click", "ui_back",
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var library := load(LIBRARY_PATH) as SfxLibrary
	if library == null:
		_fail("The Sfx library should load as a SfxLibrary resource.")
		return
	for event in EXPECTED_EVENTS:
		var stream := library.stream_for(event)
		if stream == null:
			_fail("Event '%s' has no stream in the library." % event)
			return
		if stream is AudioStreamRandomizer and (stream as AudioStreamRandomizer).streams_count <= 0:
			_fail("Event '%s' uses an empty randomizer." % event)
			return
	for event in library.streams.keys():
		if not EXPECTED_EVENTS.has(str(event)):
			_fail("Library event '%s' is not one the game emits; rename or remove it." % str(event))
			return
	# Sin stream asignado, llamar a Sfx no puede fallar: es el contrato que
	# deja cablear eventos antes de tener su sonido.
	Sfx.play("evento_inexistente")
	Sfx.play_at("evento_inexistente", Vector3.ZERO)
	await process_frame
	await process_frame
	Sfx.play("hitmarker")
	Sfx.play_at("impact_wall", Vector3.ZERO, 1.5)
	await process_frame
	print("Sfx library smoke test passed.")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)

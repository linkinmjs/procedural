class_name MusicActivityWindow
extends WindowPanel3D

## Actividad musical: un teclado de notas en cifrado americano y una consigna.
##
## Es la familia que cobra no saber. No pide punteria ni velocidad: pide
## acordarse de que nota viene despues, cuales forman el acorde o donde cae
## el intervalo. Se resuelve completando la respuesta —en orden si la
## actividad lo pide— y recien ahi se cierra como cualquier otra ventana, asi
## que bloques, capas y oleadas la tratan igual que a un aviso.
##
## La regla es de datos: la actividad (level_designs/music-activities.json)
## dice que pregunta, sobre que notas y como castiga; MusicActivityCatalog
## la convierte en una respuesta concreta y aca solo se compara. Cada acierto
## suena la nota, porque oirla es parte de memorizarla; cada error cobra como
## la trampa del error critico, y segun la actividad ademas reinicia.

## Prefijo de las zonas del teclado: `note:C#`.
const NOTE_ZONE_PREFIX := "note:"
## Zona que se informa por cada nota correcta intermedia. Vale poco (ver
## score_settings.tres) pero suma a la cadena.
const STEP_ZONE := "note"
## Zona que informa la nota que completa la actividad: paga como cerrar.
const COMPLETE_ZONE := "close"
## Zona de la nota equivocada. Es la que el puntaje ya castiga.
const TRAP_ZONE := "trap"
const ZONE_SCRIPT := preload("res://scripts/windows/window_hit_zone.gd")

## Teclas blancas en orden, y a la derecha de que blanca se apoya cada negra.
const WHITE_KEYS := [0, 2, 4, 5, 7, 9, 11]
const BLACK_KEYS := {1: 0, 3: 1, 6: 3, 8: 4, 10: 5}
const BLACK_KEY_WIDTH_RATIO := 0.62
const BLACK_KEY_HEIGHT_RATIO := 0.56
const WHITE_KEY_FONT_SIZE := 14
const BLACK_KEY_FONT_SIZE := 9

const BLACK_KEY_TINT := Color(0.36, 0.37, 0.44)
const DONE_TINT := Color(0.55, 1.0, 0.6)
const HINT_TINT := Color(1.0, 0.92, 0.5)
const WRONG_TINT := Color(1.0, 0.42, 0.42)
const ERROR_FLASH := Color(1.0, 0.45, 0.45)
## La nota equivocada tambien suena, mas baja: escucharla es parte de
## entender por que estuvo mal.
const WRONG_NOTE_DB := -9.0

## Definicion de la actividad. Llega en variant_config desde el plan de spawn
## del catalogo; sin ella la ventana juega la actividad de fabrica.
var activity: Dictionary = {}
## Pregunta concreta armada por el catalogo: respuesta, orden, paleta.
var question: Dictionary = {}
## Cuantas notas de la respuesta ya se tocaron (en orden).
var progress := 0
## Notas ya encontradas, para las respuestas sin orden.
var _found: PackedInt32Array = PackedInt32Array()
var _keys: Dictionary = {}
var _prompt_label: Label
var _progress_label: Label
var _keyboard: Control
var _note_player: AudioStreamPlayer3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	super()
	window_label = "actividad"
	close_style = CLOSE_STYLE_MINIMIZE
	_rng.randomize()
	activity = variant_config if not variant_config.is_empty() else MusicActivityCatalog.default_activity()
	question = MusicActivityCatalog.question_for(activity, _rng)
	_prompt_label = _find_control("Prompt") as Label
	_progress_label = _find_control("Progress") as Label
	_keyboard = _find_control("Keyboard")
	_note_player = get_node_or_null("NotePlayer") as AudioStreamPlayer3D
	var title := _find_control("Title") as Label
	if title != null:
		title.text = str(activity.get("name", tr("MUSIC_ACTIVITY")))
	if _prompt_label != null:
		_prompt_label.text = _prompt_text()
	_build_keyboard()
	_refresh()
	zone_hit.connect(_on_zone)


## Respuesta que hay que tocar, como clases de altura.
func get_answer() -> PackedInt32Array:
	return question.get("answer", PackedInt32Array()) as PackedInt32Array


func is_complete() -> bool:
	if bool(question.get("ordered", false)):
		return progress >= get_answer().size()
	return _found.size() >= get_answer().size()


## Nota que se espera ahora, o -1 si vale cualquiera de las que faltan.
func expected_pitch() -> int:
	if bool(question.get("ordered", false)):
		var answer := get_answer()
		return answer[progress] if progress < answer.size() else -1
	return -1


func _on_zone(zone_id: String, _window: WindowPanel3D) -> void:
	if not zone_id.begins_with(NOTE_ZONE_PREFIX) or is_complete():
		return
	var pitch := MusicTheory.pitch_class(zone_id.trim_prefix(NOTE_ZONE_PREFIX))
	# Toda tecla sigue disponible: una escala repite la tonica, y la nota que
	# hoy estuvo mal puede ser la que toca despues.
	_rearm_keys()
	if _accepts(pitch):
		_on_correct(pitch)
	else:
		_on_wrong(pitch)


func _accepts(pitch: int) -> bool:
	if pitch < 0:
		return false
	if bool(question.get("ordered", false)):
		return pitch == expected_pitch()
	return get_answer().has(pitch) and not _found.has(pitch)


func _on_correct(pitch: int) -> void:
	_play_note(pitch, 0.0)
	if bool(question.get("ordered", false)):
		progress += 1
	else:
		_found.append(pitch)
	_tint_key(pitch, DONE_TINT)
	var complete := is_complete()
	var controller := _get_round_controller()
	if controller != null:
		controller.report_zone_hit(window_label, COMPLETE_ZONE if complete else STEP_ZONE, complete)
	_refresh()
	if complete:
		close()


func _on_wrong(pitch: int) -> void:
	_play_note(pitch, WRONG_NOTE_DB)
	Sfx.play_at("window_error", global_position)
	_flash_error()
	_flash_key(pitch)
	var controller := _get_round_controller()
	if controller != null:
		controller.report_zone_hit(window_label, TRAP_ZONE, false)
	if str(question.get("on_miss", "")) == MusicActivityCatalog.MISS_RESTART:
		progress = 0
		_found.clear()
	_refresh()


## Suena la nota en la octava del teclado, resampleando el tono base.
func _play_note(pitch: int, volume_db: float) -> void:
	if _note_player == null:
		return
	_note_player.stream = NoteSynth.get_stream()
	_note_player.pitch_scale = NoteSynth.pitch_scale_for(pitch)
	_note_player.volume_db = volume_db
	_note_player.play()


## Consigna en palabras, a partir de lo que el catalogo eligio.
func _prompt_text() -> String:
	var root := MusicTheory.display_name(int(question.get("root", 0)))
	match str(question.get("question", "")):
		MusicActivityCatalog.QUESTION_NOTE:
			return tr("MUSIC_PROMPT_NOTE").format({"note": root})
		MusicActivityCatalog.QUESTION_SCALE:
			return tr("MUSIC_PROMPT_SCALE").format({
				"root": root,
				"mode": _term("MUSIC_MODE_", str(question.get("mode", ""))),
				"direction": _term("MUSIC_DIRECTION_", str(question.get("direction", ""))),
			})
		MusicActivityCatalog.QUESTION_CHORD:
			var key := "MUSIC_PROMPT_ARPEGGIO" if bool(question.get("ordered", false)) else "MUSIC_PROMPT_CHORD"
			return tr(key).format({
				"root": root,
				"quality": _term("MUSIC_CHORD_", str(question.get("quality", ""))),
			})
		MusicActivityCatalog.QUESTION_INTERVAL:
			return tr("MUSIC_PROMPT_INTERVAL").format({
				"root": root,
				"interval": _term("MUSIC_INTERVAL_", _interval_key(str(question.get("interval", "")))),
			})
	return ""


## Clave de traduccion de un termino de datos: `harmonic-minor` es
## MUSIC_MODE_HARMONIC_MINOR.
func _term(prefix: String, value: String) -> String:
	return tr(prefix + value.to_upper().replace("-", "_"))


## Los intervalos distinguen mayuscula de minuscula (m3 y M3) y una clave de
## traduccion no puede: se deletrea la calidad.
func _interval_key(interval_name: String) -> String:
	if interval_name.is_empty():
		return ""
	var quality := interval_name.substr(0, 1)
	var number := interval_name.substr(1)
	match quality:
		"m":
			return "MINOR_" + number
		"M":
			return "MAJOR_" + number
		"P":
			return "PERFECT_" + number
	return interval_name


## Linea de progreso: lo tocado con nombre y lo que falta con un hueco.
func _refresh() -> void:
	var answer := get_answer()
	var parts := PackedStringArray()
	var ordered := bool(question.get("ordered", false))
	for index in answer.size():
		var done := index < progress if ordered else _found.has(answer[index])
		parts.append(MusicTheory.display_name(answer[index]) if done else "_")
	if _progress_label != null:
		_progress_label.text = "  ".join(parts)
	_refresh_key_tints()


## Las teclas ya tocadas quedan verdes; en modo guiado, la que toca (o las
## que faltan, si el orden no importa) se ilumina.
func _refresh_key_tints() -> void:
	var ordered := bool(question.get("ordered", false))
	var hints := bool(question.get("hints", false))
	var answer := get_answer()
	var expected := expected_pitch()
	for pitch_variant in _keys:
		var pitch := int(pitch_variant)
		var tint := BLACK_KEY_TINT if not MusicTheory.is_natural(pitch) else Color.WHITE
		var done := false
		if ordered:
			for index in progress:
				if answer[index] == pitch:
					done = true
		else:
			done = _found.has(pitch)
		if done:
			tint = DONE_TINT
		elif hints and ((ordered and pitch == expected) or (not ordered and answer.has(pitch))):
			tint = HINT_TINT
		(_keys[pitch_variant] as Control).self_modulate = tint


## El tinte va en self_modulate y no en modulate: modulate lo usa la base para
## hundir el boton al disparar (y lo devuelve a blanco), y ademas multiplica al
## Label del nombre, que sobre una tecla negra quedaria ilegible.
func _tint_key(pitch: int, tint: Color) -> void:
	var key := _keys.get(pitch, null) as Control
	if key != null:
		key.self_modulate = tint


func _flash_key(pitch: int) -> void:
	var key := _keys.get(pitch, null) as Control
	if key == null:
		return
	key.self_modulate = WRONG_TINT
	var tween := key.create_tween()
	tween.tween_interval(0.25)
	tween.tween_callback(_refresh_key_tints)


## Destello rojo de la ventana entera, como el error critico: el castigo se
## ve, no solo se descuenta.
func _flash_error() -> void:
	var material := _screen_material()
	if material == null or shielded:
		return
	material.albedo_color = ERROR_FLASH
	var tween := create_tween()
	tween.tween_property(material, "albedo_color", Color.WHITE, 0.3)


func _rearm_keys() -> void:
	for body in get_hit_bodies():
		if body.zone_id.begins_with(NOTE_ZONE_PREFIX):
			body.rearm()


## Teclado de piano: siete blancas a lo ancho y las negras montadas encima,
## agregadas despues para que se dibujen —y se disparen— por delante. Con la
## paleta natural las negras quedan escondidas, y una zona escondida no
## genera cuerpo.
func _build_keyboard() -> void:
	if _keyboard == null:
		return
	for child in _keyboard.get_children():
		child.queue_free()
	_keys.clear()
	var area := _keyboard.size
	var white_width := area.x / WHITE_KEYS.size()
	var chromatic := str(question.get("palette", "")) == MusicActivityCatalog.PALETTE_CHROMATIC
	for index in WHITE_KEYS.size():
		var pitch := int(WHITE_KEYS[index])
		var key := _make_key(pitch, Vector2(index * white_width, 0.0), Vector2(white_width, area.y), false)
		_keyboard.add_child(key)
		_keys[pitch] = key
	var black_size := Vector2(white_width * BLACK_KEY_WIDTH_RATIO, area.y * BLACK_KEY_HEIGHT_RATIO)
	for pitch_variant in BLACK_KEYS:
		var pitch := int(pitch_variant)
		var boundary := (int(BLACK_KEYS[pitch_variant]) + 1) * white_width
		var key := _make_key(pitch, Vector2(boundary - black_size.x * 0.5, 0.0), black_size, true)
		key.visible = chromatic
		_keyboard.add_child(key)
		_keys[pitch] = key


func _make_key(pitch: int, key_position: Vector2, key_size: Vector2, black: bool) -> Button:
	var key := Button.new()
	key.name = "Key" + MusicTheory.note_name(pitch).replace("#", "s")
	key.set_script(ZONE_SCRIPT)
	key.set("zone_id", NOTE_ZONE_PREFIX + MusicTheory.note_name(pitch))
	key.set("closes_window", false)
	key.set("scores", false)
	key.position = key_position
	key.size = key_size
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key.focus_mode = Control.FOCUS_NONE
	key.self_modulate = BLACK_KEY_TINT if black else Color.WHITE
	# El texto va en un Label propio: el estilo del boton reserva margenes que
	# no dejan lugar a "C#/Db" en una tecla angosta.
	var label := Label.new()
	label.name = "Name"
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP if black else VERTICAL_ALIGNMENT_BOTTOM
	label.text = MusicTheory.display_name(pitch).replace("/", "\n") if black else MusicTheory.note_name(pitch)
	label.add_theme_font_size_override("font_size", BLACK_KEY_FONT_SIZE if black else WHITE_KEY_FONT_SIZE)
	label.add_theme_color_override("font_color", Color.WHITE if black else Color(0.05, 0.05, 0.08))
	if black:
		label.offset_top = 4.0
	else:
		label.offset_bottom = -6.0
	key.add_child(label)
	return key


func _find_control(node_name: String) -> Control:
	if content == null:
		return null
	return content.find_child(node_name, true, false) as Control

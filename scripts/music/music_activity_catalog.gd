class_name MusicActivityCatalog
extends RefCounted

## Actividades musicales que puede repartir un bloque.
##
## Lee level_designs/music-activities.json, con el mismo patron que
## WindowDesignCatalog: estatico, con reload() para las pruebas. Una actividad
## es una regla de datos —que pregunta hace, sobre que notas, en que orden y
## como castiga el error—, y los niveles la nombran como `music:<id>` en las
## capas de sus bloques. Un id desconocido degrada a una ventana normal, igual
## que un diseño custom borrado.
##
## Formato de una actividad (todo lo que no se declare toma el valor de
## DEFAULTS):
##   id        identificador que usan los niveles (slug en minusculas)
##   name      titulo de la ventana
##   question  "note" | "scale" | "chord" | "interval"
##   roots     lista de notas, o "naturals" o "any"; se elige una al azar
##   mode      escala para "scale" (claves de MusicTheory.SCALES)
##   direction "up" | "down" | "both", para "scale"
##   octave    si la escala cierra con la tonica arriba (o abajo)
##   qualities lista de calidades para "chord" (claves de MusicTheory.CHORDS)
##   intervals lista de intervalos para "interval" (claves de INTERVALS)
##   ordered   si hay que disparar las notas en orden (siempre en "scale")
##   palette   "natural" (7 teclas) | "chromatic" (12). Si la respuesta usa
##             una tecla negra, se pasa sola a cromatica
##   hints     si la ventana ilumina la tecla que toca (modo guiado)
##   onMiss    "continue" | "restart": que pasa con el progreso al errar

const CATALOG_PATH := "res://level_designs/music-activities.json"

const QUESTION_NOTE := "note"
const QUESTION_SCALE := "scale"
const QUESTION_CHORD := "chord"
const QUESTION_INTERVAL := "interval"
const QUESTIONS := [QUESTION_NOTE, QUESTION_SCALE, QUESTION_CHORD, QUESTION_INTERVAL]

const PALETTE_NATURAL := "natural"
const PALETTE_CHROMATIC := "chromatic"
const MISS_CONTINUE := "continue"
const MISS_RESTART := "restart"

const DEFAULTS := {
	"question": QUESTION_SCALE,
	"roots": ["C"],
	"mode": "major",
	"direction": "up",
	"octave": true,
	"qualities": ["major"],
	"intervals": ["M3", "P5"],
	"ordered": false,
	"palette": PALETTE_NATURAL,
	"hints": false,
	"onMiss": MISS_CONTINUE,
}

## Actividad de fabrica para una ventana instanciada sin configuracion (un
## test visual, la escena abierta a mano): la mas facil de todas.
const FALLBACK_ACTIVITY := {
	"id": "escala-c-mayor-asc",
	"name": "Escala de C mayor",
	"question": QUESTION_SCALE,
	"roots": ["C"],
	"mode": "major",
	"direction": "up",
	"hints": true,
}

static var _activities: Dictionary = {}
static var _order: PackedStringArray = PackedStringArray()
static var _loaded := false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(CATALOG_PATH):
		push_warning("Music activity catalog not found: %s" % CATALOG_PATH)
		return
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		push_warning("Music activity catalog could not be opened: %s" % CATALOG_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_warning("Music activity catalog must contain a JSON object.")
		return
	for entry_variant in (parsed as Dictionary).get("activities", []):
		if not entry_variant is Dictionary:
			continue
		var entry := entry_variant as Dictionary
		var id := str(entry.get("id", ""))
		if id.is_empty() or _activities.has(id):
			continue
		if not QUESTIONS.has(str(entry.get("question", DEFAULTS["question"]))):
			push_warning("Music activity '%s' asks an unknown question; skipping it." % id)
			continue
		_activities[id] = entry
		_order.append(id)


## Solo para las pruebas: obliga a releer el catalogo del disco.
static func reload() -> void:
	_loaded = false
	_activities.clear()
	_order.clear()
	_ensure_loaded()


static func has_activity(id: String) -> bool:
	_ensure_loaded()
	return _activities.has(id)


static func get_activity(id: String) -> Dictionary:
	_ensure_loaded()
	return _activities.get(id, {}) as Dictionary


## Ids en el orden del archivo, que es el orden de dificultad pensado.
static func get_ids() -> PackedStringArray:
	_ensure_loaded()
	return _order.duplicate()


static func activity_name(id: String) -> String:
	var activity := get_activity(id)
	var name := str(activity.get("name", ""))
	return name if not name.is_empty() else id


static func default_activity() -> Dictionary:
	_ensure_loaded()
	if not _order.is_empty():
		return _activities[_order[0]]
	return FALLBACK_ACTIVITY


## Valor de un campo, con el de fabrica si la actividad no lo declara.
static func setting(activity: Dictionary, key: String) -> Variant:
	return activity.get(key, DEFAULTS.get(key, null))


## Arma una pregunta concreta a partir de la actividad: elige la tonica, la
## calidad o el intervalo al azar entre lo que la actividad permite, y deja la
## respuesta como clases de altura en el orden en que hay que tocarlas. La
## ventana solo tiene que comparar contra eso.
static func question_for(activity: Dictionary, rng: RandomNumberGenerator = null) -> Dictionary:
	var question := str(setting(activity, "question"))
	var palette := str(setting(activity, "palette"))
	var root := _pick_root(setting(activity, "roots"), palette, rng)
	var answer := PackedInt32Array()
	var ordered := bool(setting(activity, "ordered"))
	var result := {
		"question": question,
		"root": root,
		"mode": "",
		"direction": "",
		"quality": "",
		"interval": "",
	}
	match question:
		QUESTION_NOTE:
			answer.append(root)
		QUESTION_SCALE:
			var mode := str(setting(activity, "mode"))
			var direction := str(setting(activity, "direction"))
			answer = _scale_answer(root, mode, direction, bool(setting(activity, "octave")))
			ordered = true
			result["mode"] = mode
			result["direction"] = direction
		QUESTION_CHORD:
			var quality := str(_pick(setting(activity, "qualities"), rng, "major"))
			answer = MusicTheory.chord(root, quality)
			result["quality"] = quality
		QUESTION_INTERVAL:
			var interval_name := str(_pick(setting(activity, "intervals"), rng, "P5"))
			answer.append(MusicTheory.interval(root, interval_name))
			result["interval"] = interval_name
	# Una respuesta con teclas negras necesita el teclado completo, declare lo
	# que declare la actividad: la paleta natural es una comodidad, no un
	# recorte de la respuesta.
	for pitch in answer:
		if not MusicTheory.is_natural(pitch):
			palette = PALETTE_CHROMATIC
			break
	result["answer"] = answer
	result["ordered"] = ordered
	result["palette"] = palette
	result["hints"] = bool(setting(activity, "hints"))
	result["on_miss"] = str(setting(activity, "onMiss"))
	return result


## Escala en el orden pedido. Subiendo va de la tonica al septimo grado;
## bajando arranca en la tonica y cae; ida y vuelta sube y baja sin repetir
## la nota de arriba. `octave` cierra con la tonica del otro extremo.
static func _scale_answer(root: int, mode: String, direction: String, octave: bool) -> PackedInt32Array:
	var degrees := MusicTheory.scale(root, mode)
	var descending := PackedInt32Array([root])
	for index in range(degrees.size() - 1, 0, -1):
		descending.append(degrees[index])
	var answer := PackedInt32Array()
	match direction:
		"down":
			answer = descending
			if octave:
				answer.append(root)
		"both":
			answer = degrees.duplicate()
			answer.append_array(descending)
			if octave:
				answer.append(root)
		_:
			answer = degrees.duplicate()
			if octave:
				answer.append(root)
	return answer


## Tonica al azar. `roots` puede ser una lista de nombres, "naturals" o "any";
## con la paleta natural, "any" tambien se queda en las blancas.
static func _pick_root(roots: Variant, palette: String, rng: RandomNumberGenerator) -> int:
	var candidates: Array[int] = []
	if roots is Array:
		for name_variant in roots:
			var pitch := MusicTheory.pitch_class(str(name_variant))
			if pitch >= 0:
				candidates.append(pitch)
	elif str(roots) == "any" and palette == PALETTE_CHROMATIC:
		for pitch in 12:
			candidates.append(pitch)
	if candidates.is_empty():
		for name in MusicTheory.NATURAL_NAMES:
			candidates.append(MusicTheory.pitch_class(name))
	return candidates[_index(candidates.size(), rng)]


static func _pick(options: Variant, rng: RandomNumberGenerator, fallback: String) -> String:
	if options is Array and not (options as Array).is_empty():
		return str((options as Array)[_index((options as Array).size(), rng)])
	return str(options) if options is String and not str(options).is_empty() else fallback


static func _index(count: int, rng: RandomNumberGenerator) -> int:
	if count <= 1:
		return 0
	return rng.randi_range(0, count - 1) if rng != null else randi() % count

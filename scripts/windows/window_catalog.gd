class_name WindowCatalog
extends RefCounted

## Traduce la familia de ventana que declara un nivel a la escena que hay que
## instanciar.
##
## Es el eslabon que faltaba: el formato de nivel y la herramienta hablan de
## familias desde hace varias versiones, pero el juego spawneaba una escena al
## azar entre tres y el tipo declarado se perdia en el camino.
##
## Una familia puede tener varias escenas: son variantes visuales de la misma
## regla, como pide el GDD. La familia decide como se juega; la variante, como se
## ve. Las familias que todavia no tienen escena propia caen en `normal`, asi que
## un nivel que las use se puede jugar igual desde el dia que se diseña.

const NORMAL_TYPE := "normal"
## Prefijo con el que una capa nombra un diseño del Window Workshop
## (level_designs/window-designs.json) en lugar de una familia de fabrica.
const CUSTOM_PREFIX := "custom:"
## Prefijo con el que una capa nombra una actividad musical
## (level_designs/music-activities.json). Todas comparten escena: la
## actividad viaja como configuracion y decide que se pregunta.
const MUSIC_PREFIX := "music:"
const MUSIC_ACTIVITY_SCENE := preload("res://scenes/windows/music_activity_window.tscn")

## Escenas de cada familia, con nombre por escena para que un diseño custom
## pueda elegir su base. Tiene que coincidir con BASES en
## tools/level-editor/window-format.js (hay un test de paridad): agregar una
## familia es una entrada aca y otra alla, y todo lo demas se deriva.
const BASE_SCENES := {
	"normal": {
		"close": preload("res://scenes/windows/close_window.tscn"),
		"shutdown": preload("res://scenes/windows/shutdown_window.tscn"),
	},
	# Dos variantes de espera: cinco segundos apura, diez ahoga.
	"popup": {
		"popup": preload("res://scenes/windows/popup_window.tscn"),
		"popup-slow": preload("res://scenes/windows/popup_slow_window.tscn"),
	},
	"download": {"download": preload("res://scenes/windows/download_window.tscn")},
	"infected-download": {"infected-download": preload("res://scenes/windows/infected_download_window.tscn")},
	"firewall": {"firewall": preload("res://scenes/windows/firewall_window.tscn")},
	"critical-error": {"critical-error": preload("res://scenes/windows/critical_error_window.tscn")},
}

## Familia -> lista de escenas, derivada de BASE_SCENES para que las dos vistas
## no puedan discrepar.
static var VARIANTS: Dictionary = _derive_variants()


static func _derive_variants() -> Dictionary:
	var result := {}
	for family in BASE_SCENES:
		result[family] = (BASE_SCENES[family] as Dictionary).values()
	return result


## Escena de una familia. Con varias variantes elige una, usando el generador que
## le pasen para que un nivel con semilla fija se vea siempre igual.
static func scene_for(window_type: String, rng: RandomNumberGenerator = null) -> PackedScene:
	var variants: Array = VARIANTS.get(window_type, VARIANTS[NORMAL_TYPE])
	if variants.is_empty():
		variants = VARIANTS[NORMAL_TYPE]
	if variants.size() == 1:
		return variants[0]
	var index := rng.randi_range(0, variants.size() - 1) if rng != null else randi() % variants.size()
	return variants[index]


## Si la familia tiene comportamiento propio. Las que no, se juegan como normal:
## el nivel las declara igual y el dia que exista su escena empiezan a portarse
## distinto sin tocar el archivo.
static func is_implemented(window_type: String) -> bool:
	return VARIANTS.has(window_type)


## Resuelve una capa entera a escenas concretas, una por ventana.
static func scenes_for(window_types: PackedStringArray, rng: RandomNumberGenerator = null) -> Array[PackedScene]:
	var scenes: Array[PackedScene] = []
	for window_type in window_types:
		scenes.append(scene_for(window_type, rng))
	return scenes


## Resuelve una capa a un plan de spawn: escena y configuracion por ventana.
## Las familias de fabrica llevan configuracion vacia; un tipo `custom:<slug>`
## elige al azar una variante de su diseño, que la ventana aplica al nacer
## (titulo, mensaje, tamaño). Un diseño o una base desconocidos degradan a una
## ventana normal, para que borrar un diseño nunca rompa un nivel que lo usaba.
static func spawn_plan_for(window_types: PackedStringArray, rng: RandomNumberGenerator = null) -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	for window_type in window_types:
		plan.append(_plan_entry(window_type, rng))
	return plan


static func _plan_entry(window_type: String, rng: RandomNumberGenerator) -> Dictionary:
	if window_type.begins_with(MUSIC_PREFIX):
		return _music_entry(window_type.trim_prefix(MUSIC_PREFIX), rng)
	if not window_type.begins_with(CUSTOM_PREFIX):
		return {"scene": scene_for(window_type, rng), "config": {}}
	var slug := window_type.trim_prefix(CUSTOM_PREFIX)
	var design := WindowDesignCatalog.get_design(slug)
	if design.is_empty():
		push_warning("Unknown window design '%s'; spawning a normal window." % slug)
		return {"scene": scene_for(NORMAL_TYPE, rng), "config": {}}
	var family := str(design.get("family", NORMAL_TYPE))
	var bases: Dictionary = BASE_SCENES.get(family, BASE_SCENES[NORMAL_TYPE])
	var variant := WindowDesignCatalog.variant_for(design, rng)
	var scene := bases.get(str(variant.get("base", "")), null) as PackedScene
	if scene == null:
		scene = bases.values()[0]
	return {"scene": scene, "config": variant}


## Una actividad musical: la escena es siempre la misma y la configuracion es
## la actividad entera, que la ventana convierte en una pregunta al nacer. Un
## id que ya no esta en el catalogo degrada a una ventana normal, para que
## borrar una actividad nunca rompa un nivel que la usaba.
static func _music_entry(activity_id: String, rng: RandomNumberGenerator) -> Dictionary:
	var activity := MusicActivityCatalog.get_activity(activity_id)
	if activity.is_empty():
		push_warning("Unknown music activity '%s'; spawning a normal window." % activity_id)
		return {"scene": scene_for(NORMAL_TYPE, rng), "config": {}}
	return {"scene": MUSIC_ACTIVITY_SCENE, "config": activity}

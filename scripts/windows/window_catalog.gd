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

const VARIANTS := {
	"normal": [
		preload("res://scenes/windows/close_window.tscn"),
		preload("res://scenes/windows/shutdown_window.tscn"),
	],
	"download": [preload("res://scenes/windows/download_window.tscn")],
	"infected-download": [preload("res://scenes/windows/infected_download_window.tscn")],
	# Dos variantes de espera: cinco segundos apura, diez ahoga.
	"popup": [
		preload("res://scenes/windows/popup_window.tscn"),
		preload("res://scenes/windows/popup_slow_window.tscn"),
	],
	"firewall": [preload("res://scenes/windows/firewall_window.tscn")],
	"critical-error": [preload("res://scenes/windows/critical_error_window.tscn")],
}


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

extends Node

signal level_changed(index: int, level_path: String)

const CATALOG_PATH := "res://level_designs/level-sequence.json"
const LEVEL_SCENE := "res://scenes/levels/playable_level.tscn"
const MAIN_MENU_SCENE := "res://scenes/ui/menus/main_menu.tscn"

var _levels: Array[Dictionary] = []
var _current_index := 0


func _ready() -> void:
	_load_catalog()


func get_current_level_path() -> String:
	_ensure_catalog_loaded()
	if _levels.is_empty():
		return ""
	return str(_levels[_current_index].path)


func get_current_level_id() -> String:
	_ensure_catalog_loaded()
	if _levels.is_empty():
		return ""
	return str(_levels[_current_index].id)


func get_position_text() -> String:
	_ensure_catalog_loaded()
	if _levels.is_empty():
		return "0 / 0"
	return "%d / %d" % [_current_index + 1, _levels.size()]


func get_level_count() -> int:
	_ensure_catalog_loaded()
	return _levels.size()


func has_next_level() -> bool:
	_ensure_catalog_loaded()
	return _current_index + 1 < _levels.size()


func has_previous_level() -> bool:
	_ensure_catalog_loaded()
	return _current_index > 0


func select_next_level() -> bool:
	if not has_next_level():
		return false
	_current_index += 1
	level_changed.emit(_current_index, get_current_level_path())
	return true


func select_previous_level() -> bool:
	if not has_previous_level():
		return false
	_current_index -= 1
	level_changed.emit(_current_index, get_current_level_path())
	return true


func select_first_level() -> bool:
	_ensure_catalog_loaded()
	if _levels.is_empty():
		return false
	_current_index = 0
	level_changed.emit(_current_index, get_current_level_path())
	return true


## Carga el nivel actual de la campaña. Todas las transiciones pasan por aca
## para que el reintento y el avance no queden escritos en cada menu.
func play_current_level() -> void:
	_change_scene(LEVEL_SCENE)


## Reintentar es recargar el nivel actual. No pide confirmacion ni pasa por
## ninguna otra pantalla: en un modo de puntaje tiene que costar nada.
func restart_current_level() -> void:
	_change_scene(LEVEL_SCENE)


func play_next_level() -> bool:
	if not select_next_level():
		return false
	_change_scene(LEVEL_SCENE)
	return true


func return_to_main_menu() -> void:
	_change_scene(MAIN_MENU_SCENE)


## El cambio se difiere porque puede salir desde el boton de un menu, que sigue
## dentro del arbol que se esta por reemplazar. Y despausa antes, o la escena
## nueva nace congelada.
func _change_scene(path: String) -> void:
	get_tree().paused = false
	get_tree().call_deferred("change_scene_to_file", path)


func _ensure_catalog_loaded() -> void:
	if _levels.is_empty():
		_load_catalog()


func _load_catalog() -> void:
	_levels.clear()
	_current_index = 0
	if not FileAccess.file_exists(CATALOG_PATH):
		push_error("Level sequence catalog does not exist: %s" % CATALOG_PATH)
		return
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
	if not parsed is Dictionary or int((parsed as Dictionary).get("schemaVersion", 0)) != 1 or not (parsed as Dictionary).get("levels", null) is Array:
		push_error("Level sequence catalog is invalid: %s" % CATALOG_PATH)
		return
	var known_ids: Dictionary = {}
	for entry_variant in (parsed as Dictionary).levels:
		if not entry_variant is Dictionary:
			continue
		var entry := entry_variant as Dictionary
		var level_id := str(entry.get("id", ""))
		var level_path := str(entry.get("path", ""))
		if level_id.is_empty() or known_ids.has(level_id) or not FileAccess.file_exists(level_path):
			push_error("Invalid or duplicate level sequence entry: %s" % level_id)
			continue
		var level_file := FileAccess.open(level_path, FileAccess.READ)
		var level_data: Variant = JSON.parse_string(level_file.get_as_text()) if level_file != null else null
		if not level_data is Dictionary or str((level_data as Dictionary).get("id", "")) != level_id:
			push_error("Level sequence ID does not match its JSON definition: %s" % level_id)
			continue
		known_ids[level_id] = true
		_levels.append({"id": level_id, "path": level_path})

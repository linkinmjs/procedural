extends Node

signal level_changed(index: int, level_path: String)

const CATALOG_PATH := "res://level_designs/level-sequence.json"
const LEVEL_SCENE := "res://scenes/levels/playable_level.tscn"
const MAIN_MENU_SCENE := "res://scenes/ui/menus/main_menu.tscn"

var _levels: Array[Dictionary] = []
var _current_index := 0
## Si el proximo nivel que se cargue se presenta con su intertitulo. Arranca en
## true para que abrir el nivel a mano desde el editor tambien lo muestre; lo
## unico que lo apaga es reintentar.
var _announce_next := true


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


## Numero del nivel actual, contando desde 1: es como se lo nombra en pantalla.
func get_current_number() -> int:
	_ensure_catalog_loaded()
	return _current_index + 1


func get_current_index() -> int:
	_ensure_catalog_loaded()
	return _current_index


func get_level_id(index: int) -> String:
	_ensure_catalog_loaded()
	if index < 0 or index >= _levels.size():
		return ""
	return str(_levels[index].id)


## Nombre declarado en el JSON del nivel, o su id si no tiene.
func get_level_name(index: int) -> String:
	_ensure_catalog_loaded()
	if index < 0 or index >= _levels.size():
		return ""
	return str(_levels[index].name)


func get_level_ids() -> PackedStringArray:
	_ensure_catalog_loaded()
	var ids := PackedStringArray()
	for entry in _levels:
		ids.append(str(entry.id))
	return ids


func has_next_level() -> bool:
	_ensure_catalog_loaded()
	return _current_index + 1 < _levels.size()


func has_previous_level() -> bool:
	_ensure_catalog_loaded()
	return _current_index > 0


## Completar un nivel abre el siguiente; el primero esta siempre abierto. Sin
## perfil (los tests que no lo cargan) todo esta abierto.
func is_unlocked(index: int) -> bool:
	_ensure_catalog_loaded()
	if index < 0 or index >= _levels.size():
		return false
	if index == 0:
		return true
	var profile := _profile()
	if profile == null:
		return true
	return profile.is_level_completed(get_level_id(index - 1))


func is_completed(index: int) -> bool:
	var profile := _profile()
	return profile != null and profile.is_level_completed(get_level_id(index))


func select_next_level() -> bool:
	if not has_next_level():
		return false
	_set_index(_current_index + 1)
	return true


func select_previous_level() -> bool:
	if not has_previous_level():
		return false
	_set_index(_current_index - 1)
	return true


func select_first_level() -> bool:
	_ensure_catalog_loaded()
	if _levels.is_empty():
		return false
	_set_index(0)
	return true


## Salta a cualquier nivel del catalogo. El selector de niveles decide si
## corresponde ofrecerlo; aca solo se valida que exista.
func select_level(index: int) -> bool:
	_ensure_catalog_loaded()
	if index < 0 or index >= _levels.size():
		return false
	_set_index(index)
	return true


func select_level_by_id(level_id: String) -> bool:
	_ensure_catalog_loaded()
	return select_level(_index_of(level_id))


## Carga el nivel actual de la campaña. Todas las transiciones pasan por aca
## para que el reintento y el avance no queden escritos en cada menu.
func play_current_level() -> void:
	_announce_next = true
	_change_scene(LEVEL_SCENE)


## Reintentar es recargar el nivel actual. No pide confirmacion ni pasa por
## ninguna otra pantalla: en un modo de puntaje tiene que costar nada. Tampoco
## se presenta: quien reintenta ya sabe en que nivel esta.
func restart_current_level() -> void:
	_announce_next = false
	var profile := _profile()
	if profile != null:
		profile.increment_stat("retries")
	_change_scene(LEVEL_SCENE)


func play_next_level() -> bool:
	if not select_next_level():
		return false
	_announce_next = true
	_change_scene(LEVEL_SCENE)
	return true


## El nivel pregunta una sola vez si le toca presentarse, al construirse. La
## respuesta se consume: recargar la escena de cualquier otra forma no repite
## la presentacion por accidente.
func consume_announcement() -> bool:
	var announce := _announce_next
	_announce_next = false
	return announce


func return_to_main_menu() -> void:
	_change_scene(MAIN_MENU_SCENE)


## El cambio se difiere porque puede salir desde el boton de un menu, que sigue
## dentro del arbol que se esta por reemplazar. Y despausa antes, o la escena
## nueva nace congelada. El perfil se escribe antes de soltar la escena: lo que
## la partida gano no puede depender de que el retardo de guardado alcance.
func _change_scene(path: String) -> void:
	var profile := _profile()
	if profile != null:
		profile.flush()
	get_tree().paused = false
	get_tree().call_deferred("change_scene_to_file", path)


func _set_index(index: int) -> void:
	_current_index = index
	_remember_position()
	level_changed.emit(_current_index, get_current_level_path())


## El perfil recuerda el ultimo nivel jugado: asi la campaña sigue donde quedo
## la proxima vez que se abre el juego.
func _remember_position() -> void:
	var profile := _profile()
	if profile != null:
		profile.set_last_played(get_current_level_id())


func _restore_position() -> void:
	_current_index = 0
	var profile := _profile()
	if profile == null:
		return
	var index := _index_of(profile.get_last_played_id())
	if index >= 0:
		_current_index = index


func _index_of(level_id: String) -> int:
	if level_id.is_empty():
		return -1
	for index in _levels.size():
		if str(_levels[index].id) == level_id:
			return index
	return -1


## El autoload del perfil se busca por nombre y puede no existir (tests que
## corren sin el): nada de la secuencia depende de que este.
func _profile() -> GameProfile:
	return get_node_or_null("/root/PlayerProfile") as GameProfile


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
		_levels.append({
			"id": level_id,
			"path": level_path,
			"name": str((level_data as Dictionary).get("name", level_id)),
		})
	var profile := _profile()
	if profile != null:
		profile.set_catalog_ids(get_level_ids())
	_restore_position()

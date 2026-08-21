class_name LevelDefinitionLoader
extends RefCounted

const SUPPORTED_SCHEMA_VERSION := 9
## Versiones viejas que se leen igual, migrandolas en memoria al cargar. El
## archivo en disco no se toca: se actualiza recien cuando alguien lo guarda
## desde la herramienta.
const MIGRATABLE_SCHEMA_VERSIONS := [8]
const VALID_ROOM_TYPES := ["small", "large", "corridor", "custom"]
const VALID_WALLS := ["north", "east", "south", "west"]
const VALID_BLOCK_SLOTS := ["left", "front", "right"]
const VALID_TEXTURE_SLOTS := ["walls", "floor", "ceiling", "door", "block"]
const VALID_ROLES := ["start", "transition", "exit"]
## Familias de ventana que puede declarar una capa. Tienen que coincidir con
## WINDOW_TYPES en tools/level-editor/level-format.js, que es lo que escribe los
## archivos. Las que todavia no tienen escena propia se spawnean como una
## ventana normal; WindowCatalog es el que sabe cual es cual.
const VALID_WINDOW_TYPES := [
	"normal", "popup", "download", "infected-download", "firewall",
	"critical-error", "confirm", "ad", "fake-close", "task-manager",
	"corrupt-file", "installer",
]
const MAX_WAVE_TARGETS := 64
## Cuantas oleadas de sala se aceptan. El limite no es tecnico: una sala con mas
## de esto deja de ser un encuentro y pasa a ser una prueba de paciencia.
const MAX_ROOM_WAVES := 8
const MIN_CORRIDOR_WIDTH := 1.5
const MAX_CORRIDOR_WIDTH := 12.0
const DEFAULT_CORRIDOR_WIDTH := 3.5
const MIN_BLOCK_HEIGHT := 2.0
const MAX_BLOCK_HEIGHT := 12.0
const DEFAULT_MAX_BLOCK_HEIGHT := 6.0
const MIN_WALL_HEIGHT := 2.0
const MAX_WALL_HEIGHT := 20.0
const DEFAULT_WALL_HEIGHT := 6.0
const DEFAULT_MAGAZINE_AMMO := 17
const DEFAULT_RESERVE_AMMO := 51


static func load_level(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Level definition does not exist: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Level definition could not be opened: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Level definition must contain a JSON object: %s" % path)
		return {}
	var level := (parsed as Dictionary).duplicate(true)
	_migrate(level)
	if not _validate_level(level, path):
		return {}
	return level


## Lleva el nivel a la version que el juego entiende. Cada paso es de una version
## a la siguiente, asi que un archivo viejo pasa por todos los que le faltan.
static func _migrate(level: Dictionary) -> void:
	if int(level.get("schemaVersion", 0)) == 8:
		_migrate_8_to_9(level)


## v8 tenia un solo grupo de bloques por sala, y los tres aparecian juntos. En v9
## la sala declara oleadas y cada una trae su grupo, asi que el grupo unico de v8
## es exactamente una oleada. Adentro del bloque, lo que se llamaba `waves` pasa a
## `layers`: eran las capas de ventanas de ese bloque, y dejarles el mismo nombre
## que a las oleadas de sala volvia el formato imposible de leer.
static func _migrate_8_to_9(level: Dictionary) -> void:
	for room_variant in level.get("rooms", []):
		if not room_variant is Dictionary:
			continue
		var room := room_variant as Dictionary
		var blocks: Variant = room.get("blocks", null)
		if not blocks is Dictionary:
			continue
		for slot_variant in (blocks as Dictionary):
			var block: Variant = (blocks as Dictionary)[slot_variant]
			if block is Dictionary and (block as Dictionary).has("waves"):
				(block as Dictionary)["layers"] = (block as Dictionary)["waves"]
				(block as Dictionary).erase("waves")
		room["waves"] = [{"blocks": blocks}]
		room.erase("blocks")
	level["schemaVersion"] = 9


## Cielo declarado por el nivel. Si no nombra ninguno, o nombra uno que ya no
## existe, se usa el que trae SkyCatalog por defecto.
static func get_sky_id(level: Dictionary) -> String:
	var sky := str(level.get("sky", ""))
	return sky if SkyCatalog.has_sky(sky) else SkyCatalog.DEFAULT_ID


## Sala en la que aparece el jugador. Un nivel declara una sola.
static func get_start_room(level: Dictionary) -> Dictionary:
	return _room_with_role(level, "start")


## Sala que cierra el nivel al ser alcanzada.
static func get_exit_room(level: Dictionary) -> Dictionary:
	return _room_with_role(level, "exit")


static func _room_with_role(level: Dictionary, role: String) -> Dictionary:
	for room_variant in level.get("rooms", []):
		var room := room_variant as Dictionary
		if str(room.get("role", "")) == role:
			return room
	return {}


## Direccion en grados hacia la que mira el jugador al aparecer. 0 es norte.
static func get_room_facing(room: Dictionary) -> float:
	return wrapf(float(room.get("facing", 0.0)), 0.0, 360.0)


## Ancho del pasillo de una conexion, con el predeterminado del nivel de
## respaldo.
static func get_corridor_width(level: Dictionary, connection: Dictionary) -> float:
	var defaults: Dictionary = level.get("defaults", {}) as Dictionary
	var fallback := float(defaults.get("corridorWidth", DEFAULT_CORRIDOR_WIDTH))
	return clampf(float(connection.get("width", fallback)), MIN_CORRIDOR_WIDTH, MAX_CORRIDOR_WIDTH)


## Municion con la que el jugador arranca el nivel.
static func get_starting_ammo(level: Dictionary) -> Dictionary:
	var ammo: Dictionary = level.get("startingAmmo", {}) as Dictionary
	return {
		"magazine": clampi(int(ammo.get("magazine", DEFAULT_MAGAZINE_AMMO)), 0, 200),
		"reserve": clampi(int(ammo.get("reserve", DEFAULT_RESERVE_AMMO)), 0, 999),
	}


## Altura de las paredes de una sala. Un valor nulo hereda el del nivel.
static func get_room_wall_height(level: Dictionary, room: Dictionary) -> float:
	var defaults: Dictionary = level.get("defaults", {}) as Dictionary
	var inherited := float(defaults.get("wallHeight", DEFAULT_WALL_HEIGHT))
	var room_height: Variant = room.get("wallHeight", null)
	if room_height == null:
		return clampf(inherited, MIN_WALL_HEIGHT, MAX_WALL_HEIGHT)
	return clampf(float(room_height), MIN_WALL_HEIGHT, MAX_WALL_HEIGHT)


## Alto maximo del bloque de ventanas. El bloque cubre la pared hasta aca y deja
## libre lo que sobre, para que los objetivos no queden donde no se apunta comodo.
static func get_max_block_height(level: Dictionary) -> float:
	var defaults: Dictionary = level.get("defaults", {}) as Dictionary
	var declared := float(defaults.get("maxBlockHeight", DEFAULT_MAX_BLOCK_HEIGHT))
	return clampf(declared, MIN_BLOCK_HEIGHT, MAX_BLOCK_HEIGHT)


## false deja la sala a cielo abierto. Un valor nulo hereda el del nivel.
static func room_has_ceiling(level: Dictionary, room: Dictionary) -> bool:
	var defaults: Dictionary = level.get("defaults", {}) as Dictionary
	var room_ceiling: Variant = room.get("hasCeiling", null)
	if room_ceiling == null:
		return bool(defaults.get("hasCeiling", true))
	return bool(room_ceiling)


## Bloque de municion que aparece al limpiar la sala. amount vale 0 si no hay.
static func get_room_ammo_reward(room: Dictionary) -> Dictionary:
	var reward: Dictionary = room.get("ammoReward", {}) as Dictionary
	var enabled := bool(reward.get("enabled", false))
	return {
		"enabled": enabled,
		"amount": clampi(int(reward.get("amount", 0)), 0, 999) if enabled else 0,
		"color": Color.from_string(str(reward.get("color", "#f4bc59")), Color(0.96, 0.74, 0.35, 1.0)),
	}


## Textura configurada para una superficie de la sala, con el nivel como
## respaldo. Una cadena vacia significa "usar el material procedural actual".
static func get_room_texture(level: Dictionary, room: Dictionary, slot: String) -> String:
	var room_textures: Dictionary = room.get("textures", {}) as Dictionary
	var room_value := str(room_textures.get(slot, ""))
	if not room_value.is_empty():
		return room_value
	var defaults: Dictionary = level.get("defaults", {}) as Dictionary
	var level_textures: Dictionary = defaults.get("textures", {}) as Dictionary
	return str(level_textures.get(slot, ""))


static func _validate_level(level: Dictionary, path: String) -> bool:
	if int(level.get("schemaVersion", 0)) != SUPPORTED_SCHEMA_VERSION:
		push_error("Unsupported level schema in %s. Expected version %d." % [path, SUPPORTED_SCHEMA_VERSION])
		return false
	if not level.get("rooms", null) is Array or not level.get("connections", null) is Array:
		push_error("Level must define rooms and connections arrays: %s" % path)
		return false
	var time_limit := int(level.get("timeLimitSeconds", 0))
	if time_limit < 1 or time_limit > 3600:
		push_error("Level timeLimitSeconds must be between 1 and 3600: %s" % path)
		return false
	if not _validate_starting_ammo(level, path):
		return false
	if not _validate_defaults(level, path):
		return false
	if not SkyCatalog.has_sky(str(level.get("sky", ""))):
		push_error("Level declares an unknown sky: %s" % path)
		return false
	var room_ids: Dictionary = {}
	for room_variant in level.rooms:
		if not room_variant is Dictionary:
			push_error("Every room must be an object: %s" % path)
			return false
		var room := room_variant as Dictionary
		var room_id := str(room.get("id", ""))
		if room_id.is_empty() or room_ids.has(room_id):
			push_error("Room IDs must be present and unique: %s" % path)
			return false
		room_ids[room_id] = true
		if not VALID_ROOM_TYPES.has(str(room.get("type", ""))):
			push_error("Invalid room type for %s." % room_id)
			return false
		if not VALID_ROLES.has(str(room.get("role", ""))):
			push_error("Invalid room role for %s." % room_id)
			return false
		if not _validate_room(room, room_id):
			return false
	for connection_variant in level.connections:
		if not connection_variant is Dictionary:
			push_error("Every connection must be an object: %s" % path)
			return false
		var connection := connection_variant as Dictionary
		if not room_ids.has(str(connection.get("fromRoomId", ""))) or not room_ids.has(str(connection.get("toRoomId", ""))):
			push_error("Connection references an unknown room: %s" % path)
			return false
		if not VALID_WALLS.has(str(connection.get("fromWall", ""))) or not VALID_WALLS.has(str(connection.get("toWall", ""))):
			push_error("Connection contains an invalid wall: %s" % path)
			return false
		var corridor_width := float(connection.get("width", 0.0))
		if corridor_width < MIN_CORRIDOR_WIDTH or corridor_width > MAX_CORRIDOR_WIDTH:
			push_error("Connection corridor width is out of range: %s" % path)
			return false
	return _validate_roles(level, path)


## El recorrido del nivel necesita saber donde empieza y donde termina.
static func _validate_roles(level: Dictionary, path: String) -> bool:
	var counts := {"start": 0, "transition": 0, "exit": 0}
	for room_variant in level.rooms:
		var role := str((room_variant as Dictionary).get("role", ""))
		counts[role] = int(counts.get(role, 0)) + 1
	if counts.start != 1:
		push_error("A level needs exactly one start room: %s" % path)
		return false
	if counts.exit > 1:
		push_error("A level cannot declare more than one exit room: %s" % path)
		return false
	return true


static func _validate_starting_ammo(level: Dictionary, path: String) -> bool:
	if not level.get("startingAmmo", null) is Dictionary:
		push_error("Level must define a startingAmmo object: %s" % path)
		return false
	var ammo := level.startingAmmo as Dictionary
	var magazine := int(ammo.get("magazine", -1))
	var reserve := int(ammo.get("reserve", -1))
	if magazine < 0 or magazine > 200 or reserve < 0 or reserve > 999:
		push_error("Level startingAmmo is out of range: %s" % path)
		return false
	return true


static func _validate_defaults(level: Dictionary, path: String) -> bool:
	if not level.get("defaults", null) is Dictionary:
		push_error("Level must define a defaults object: %s" % path)
		return false
	var defaults := level.defaults as Dictionary
	var corridor_width := float(defaults.get("corridorWidth", 0.0))
	if corridor_width < MIN_CORRIDOR_WIDTH or corridor_width > MAX_CORRIDOR_WIDTH:
		push_error("Level defaults.corridorWidth is out of range: %s" % path)
		return false
	var wall_height := float(defaults.get("wallHeight", 0.0))
	if wall_height < MIN_WALL_HEIGHT or wall_height > MAX_WALL_HEIGHT:
		push_error("Level defaults.wallHeight must be between %.0f and %.0f: %s" % [MIN_WALL_HEIGHT, MAX_WALL_HEIGHT, path])
		return false
	var max_block_height := float(defaults.get("maxBlockHeight", 0.0))
	if max_block_height < MIN_BLOCK_HEIGHT or max_block_height > MAX_BLOCK_HEIGHT:
		push_error("Level defaults.maxBlockHeight must be between %.0f and %.0f: %s" % [MIN_BLOCK_HEIGHT, MAX_BLOCK_HEIGHT, path])
		return false
	if not defaults.get("hasCeiling", null) is bool:
		push_error("Level defaults.hasCeiling must be a boolean: %s" % path)
		return false
	return _validate_textures(defaults.get("textures", null), "level defaults")


static func _validate_textures(textures_variant: Variant, owner_label: String) -> bool:
	if not textures_variant is Dictionary:
		push_error("%s needs a textures object." % owner_label)
		return false
	var textures := textures_variant as Dictionary
	for slot in VALID_TEXTURE_SLOTS:
		if not textures.get(slot, null) is String:
			push_error("%s is missing its %s texture slot." % [owner_label, slot])
			return false
	return true


static func _validate_room(room: Dictionary, room_id: String) -> bool:
	if not room.get("position", null) is Dictionary or not room.get("size", null) is Dictionary:
		push_error("Room %s needs position and size objects." % room_id)
		return false
	var size := room.size as Dictionary
	if float(size.get("width", 0.0)) < 4.0 or float(size.get("depth", 0.0)) < 4.0:
		push_error("Room %s is too small." % room_id)
		return false
	if not room.get("entry", null) is Dictionary or not VALID_WALLS.has(str(room.entry.get("wall", ""))):
		push_error("Room %s needs a valid entry wall." % room_id)
		return false
	var room_height: Variant = room.get("wallHeight", null)
	if room_height != null and (float(room_height) < MIN_WALL_HEIGHT or float(room_height) > MAX_WALL_HEIGHT):
		push_error("Room %s has an invalid wall height." % room_id)
		return false
	var facing := float(room.get("facing", -1.0))
	if facing < 0.0 or facing > 359.0:
		push_error("Room %s has an invalid facing angle." % room_id)
		return false
	var room_ceiling: Variant = room.get("hasCeiling", null)
	if room_ceiling != null and not room_ceiling is bool:
		push_error("Room %s has an invalid hasCeiling value." % room_id)
		return false
	if not _validate_ammo_reward(room, room_id):
		return false
	if not _validate_textures(room.get("textures", null), "Room %s" % room_id):
		return false
	if not room.get("waves", null) is Array:
		push_error("Room %s needs a waves array." % room_id)
		return false
	if room.waves.size() > MAX_ROOM_WAVES:
		push_error("Room %s declares more than %d waves." % [room_id, MAX_ROOM_WAVES])
		return false
	for wave_variant in room.waves:
		if not _validate_room_wave(wave_variant, room_id):
			return false
	return true


## Una oleada de sala es un grupo de bloques que aparecen juntos. La siguiente
## no llega hasta que se limpia esta.
static func _validate_room_wave(wave_variant: Variant, room_id: String) -> bool:
	if not wave_variant is Dictionary:
		push_error("Room %s has a wave that is not an object." % room_id)
		return false
	var blocks: Variant = (wave_variant as Dictionary).get("blocks", null)
	if not blocks is Dictionary:
		push_error("Room %s has a wave without its blocks object." % room_id)
		return false
	for slot in VALID_BLOCK_SLOTS:
		if not (blocks as Dictionary).get(slot, null) is Dictionary:
			push_error("Room %s is missing its %s block in a wave." % [room_id, slot])
			return false
		if not _validate_block((blocks as Dictionary)[slot], room_id):
			return false
	return true


static func _validate_block(block_variant: Variant, room_id: String) -> bool:
	var block := block_variant as Dictionary
	if not ["static", "opposite"].has(str(block.get("movement", ""))):
		push_error("Room %s has an invalid block movement." % room_id)
		return false
	var movement_speed := float(block.get("movementSpeed", 0.0))
	if movement_speed < 0.05 or movement_speed > 5.0:
		push_error("Room %s has an invalid block movement speed." % room_id)
		return false
	var block_color := str(block.get("color", ""))
	if block_color.length() != 7 or not block_color.begins_with("#") or not Color.html_is_valid(block_color):
		push_error("Room %s has an invalid block color." % room_id)
		return false
	if not block.get("layers", null) is Array:
		push_error("Room %s needs a block layers array." % room_id)
		return false
	for layer_variant in block.layers:
		if not _validate_layer(layer_variant, room_id):
			return false
	return true


## Una capa declara cuantas ventanas de cada familia aparecen a la vez dentro de
## un bloque. Limpiarla descubre la siguiente.
static func _validate_layer(layer_variant: Variant, room_id: String) -> bool:
	if not layer_variant is Dictionary:
		push_error("Room %s has a layer that is not an object." % room_id)
		return false
	var windows_variant: Variant = (layer_variant as Dictionary).get("windows", null)
	if not windows_variant is Dictionary:
		push_error("Room %s has a layer without its windows object." % room_id)
		return false
	var total := 0
	for type_variant in (windows_variant as Dictionary):
		var window_type := str(type_variant)
		if not VALID_WINDOW_TYPES.has(window_type):
			push_error("Room %s declares the unknown window type %s." % [room_id, window_type])
			return false
		var count := int((windows_variant as Dictionary)[type_variant])
		if count < 1 or count > MAX_WAVE_TARGETS:
			push_error("Room %s has an invalid %s window count." % [room_id, window_type])
			return false
		total += count
	if total < 1 or total > MAX_WAVE_TARGETS:
		push_error("Room %s has an invalid layer target count." % room_id)
		return false
	return true


## Oleadas de una sala, en orden. Una sala sin oleadas no tiene nada que pelear.
static func get_room_waves(room: Dictionary) -> Array[Dictionary]:
	var waves: Array[Dictionary] = []
	for wave_variant in room.get("waves", []):
		if wave_variant is Dictionary:
			waves.append(wave_variant as Dictionary)
	return waves


## Bloques habilitados de una oleada, por slot. Los apagados no llegan a existir.
static func get_wave_blocks(wave: Dictionary) -> Dictionary:
	var blocks: Dictionary = {}
	var declared: Dictionary = wave.get("blocks", {})
	for slot in VALID_BLOCK_SLOTS:
		var block_variant: Variant = declared.get(slot, null)
		if block_variant is Dictionary and bool((block_variant as Dictionary).get("enabled", false)):
			blocks[slot] = block_variant
	return blocks


## Capas de un bloque, cada una como la lista de familias que le toca spawnear.
## Se devuelve expandida —una entrada por ventana— porque es lo que el bloque
## necesita: cuantas y de que tipo, en el orden en que se reparten.
static func get_block_layers(block: Dictionary) -> Array[PackedStringArray]:
	var layers: Array[PackedStringArray] = []
	for layer_variant in block.get("layers", []):
		if not layer_variant is Dictionary:
			continue
		var windows: Dictionary = (layer_variant as Dictionary).get("windows", {})
		var types := PackedStringArray()
		for type_variant in windows:
			for _index in int(windows[type_variant]):
				types.append(str(type_variant))
		if not types.is_empty():
			layers.append(types)
	return layers


static func _validate_ammo_reward(room: Dictionary, room_id: String) -> bool:
	if not room.get("ammoReward", null) is Dictionary:
		push_error("Room %s needs an ammoReward object." % room_id)
		return false
	var reward := room.ammoReward as Dictionary
	if not reward.get("enabled", null) is bool:
		push_error("Room %s has an invalid ammoReward.enabled value." % room_id)
		return false
	var amount := int(reward.get("amount", 0))
	if amount < 1 or amount > 999:
		push_error("Room %s has an invalid ammoReward amount." % room_id)
		return false
	var reward_color := str(reward.get("color", ""))
	if reward_color.length() != 7 or not reward_color.begins_with("#") or not Color.html_is_valid(reward_color):
		push_error("Room %s has an invalid ammoReward color." % room_id)
		return false
	return true

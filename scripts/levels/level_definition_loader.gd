class_name LevelDefinitionLoader
extends RefCounted

const SUPPORTED_SCHEMA_VERSION := 3
const VALID_ROOM_TYPES := ["small", "large", "corridor", "custom"]
const VALID_WALLS := ["north", "east", "south", "west"]
const VALID_BLOCK_SLOTS := ["left", "front", "right"]


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
	if not _validate_level(level, path):
		return {}
	return level


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
	if not room.get("blocks", null) is Dictionary:
		push_error("Room %s needs block configuration." % room_id)
		return false
	for slot in VALID_BLOCK_SLOTS:
		if not room.blocks.get(slot, null) is Dictionary:
			push_error("Room %s is missing its %s block." % [room_id, slot])
			return false
		var block := room.blocks[slot] as Dictionary
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
		if not block.get("waves", null) is Array:
			push_error("Room %s needs a block waves array." % room_id)
			return false
		for count_variant in block.waves:
			var wave_count := int(count_variant)
			if wave_count < 1 or wave_count > 64:
				push_error("Room %s has an invalid wave target count." % room_id)
				return false
	return true

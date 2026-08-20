class_name ScoreRecords
extends RefCounted

## Records locales por nivel, guardados en user://.
##
## Cada record viaja con la version de formula con la que se logro: si despues
## se recalibra un peso, el record viejo queda marcado como de otra version en
## vez de convertirse en una comparacion mentirosa.

const RECORDS_PATH := "user://score_records.cfg"


static func load_record(level_id: String) -> Dictionary:
	if level_id.is_empty():
		return {}
	var config := ConfigFile.new()
	if config.load(RECORDS_PATH) != OK:
		return {}
	if not config.has_section(level_id):
		return {}
	var record: Dictionary = {}
	for key in config.get_section_keys(level_id):
		record[key] = config.get_value(level_id, key)
	return record


## Guarda el intento y devuelve que campos quedaron como record nuevo.
static func save_attempt(level_id: String, attempt: Dictionary) -> Dictionary:
	if level_id.is_empty():
		return {}
	var config := ConfigFile.new()
	config.load(RECORDS_PATH)
	var previous := load_record(level_id)
	var improved: Dictionary = {}
	for key in ["score", "ratio", "chain", "bank", "accuracy"]:
		if _store_best(config, level_id, key, attempt, previous):
			improved[key] = true
	if attempt.has("time") and float(attempt.time) > 0.0:
		var best_time := float(previous.get("time", INF))
		if float(attempt.time) < best_time:
			config.set_value(level_id, "time", float(attempt.time))
			improved["time"] = true
	if bool(attempt.get("no_damage", false)):
		config.set_value(level_id, "no_damage", true)
	config.set_value(level_id, "attempts", int(previous.get("attempts", 0)) + 1)
	config.set_value(level_id, "formula_version", int(attempt.get("formula_version", 1)))
	if config.save(RECORDS_PATH) != OK:
		push_warning("ScoreRecords could not write %s." % RECORDS_PATH)
	return improved


static func _store_best(config: ConfigFile, level_id: String, key: String, attempt: Dictionary, previous: Dictionary) -> bool:
	if not attempt.has(key):
		return false
	var value := float(attempt[key])
	if value <= float(previous.get(key, -INF)):
		return false
	config.set_value(level_id, key, value)
	return true


static func clear() -> void:
	if FileAccess.file_exists(RECORDS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RECORDS_PATH))

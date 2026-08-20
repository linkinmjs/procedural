class_name LevelScorePlan
extends RefCounted

## Techo de puntaje y par de tiempo de un nivel, calculados sobre su JSON.
##
## La cadena vive dentro de una sala, asi que el maximo de una sala es
## aritmetica sobre su contenido y no una estimacion: sus objetivos, la zona mas
## cara de cada uno y el escalon al que llega esa cantidad de hits.
##
## El techo se calcula con la corrida perfecta jugada al par: quien ademas vaya
## mas rapido que el par lo supera, y eso es deliberado.

var settings: ScoreSettings
## Por room_id: objetivos, par de tiempo y techo de puntaje de esa sala.
var rooms: Dictionary = {}
var targets_total := 0
var par_seconds := 0.0
var ceiling := 0


func _init(level_data: Dictionary, score_settings: ScoreSettings) -> void:
	settings = score_settings if score_settings != null else ScoreSettings.new()
	if level_data.is_empty():
		return
	_build_rooms(level_data)
	ceiling = _sum_room_ceilings() + _level_bonus_ceiling(level_data)


func room_targets(room_id: String) -> int:
	return int((rooms.get(room_id, {}) as Dictionary).get("targets", 0))


func room_par(room_id: String) -> float:
	return float((rooms.get(room_id, {}) as Dictionary).get("par", 0.0))


func room_ceiling(room_id: String) -> int:
	return int((rooms.get(room_id, {}) as Dictionary).get("ceiling", 0))


func _build_rooms(level_data: Dictionary) -> void:
	for room_variant in level_data.get("rooms", []):
		var room := room_variant as Dictionary
		var room_id := str(room.get("id", ""))
		var targets := _count_room_targets(room)
		targets_total += targets
		var par := 0.0
		var room_max := 0
		if targets > 0:
			par = targets * settings.par_seconds_per_target + settings.par_transit_seconds
			room_max = _room_ceiling(targets)
		par_seconds += par
		rooms[room_id] = {"targets": targets, "par": par, "ceiling": room_max}


## Una sala sin objetivos no paga bonos: no hay nada que resolver bien en ella.
func _room_ceiling(targets: int) -> int:
	var pot := targets * settings.best_zone_value()
	var multiplier := settings.multiplier_for_hits(targets)
	return roundi(pot * multiplier) \
			+ settings.room_clean_bonus \
			+ settings.room_single_chain_bonus \
			+ settings.room_intact_chain_bonus \
			+ settings.max_room_accuracy_bonus()


func _sum_room_ceilings() -> int:
	var total := 0
	for room_id in rooms:
		total += int((rooms[room_id] as Dictionary).ceiling)
	return total


## Los bonos de nivel que dependen del jugador se cuentan como los rendiria una
## corrida perfecta: una bala por objetivo y el nivel resuelto justo al par. El
## bono por bajar del par de cada sala queda fuera porque al par vale cero.
func _level_bonus_ceiling(level_data: Dictionary) -> int:
	var starting_ammo := LevelDefinitionLoader.get_starting_ammo(level_data)
	var ammo_total := int(starting_ammo.magazine) + int(starting_ammo.reserve)
	var ammo_left := maxi(ammo_total - targets_total, 0)
	var duration := float(level_data.get("timeLimitSeconds", 0))
	var seconds_left := maxi(floori(duration - par_seconds), 0)
	return ammo_left * settings.ammo_bonus_per_round \
			+ seconds_left * settings.time_bonus_per_second \
			+ settings.level_no_damage_bonus \
			+ settings.level_all_rooms_clean_bonus \
			+ settings.level_perfect_bonus


## Cuantos objetivos spawnea la sala en total, sumando bloques y oleadas.
static func _count_room_targets(room: Dictionary) -> int:
	var total := 0
	var blocks: Dictionary = room.get("blocks", {}) as Dictionary
	for slot in blocks:
		var block: Dictionary = blocks[slot] as Dictionary
		if not bool(block.get("enabled", false)):
			continue
		for count in LevelDefinitionLoader.get_wave_counts(block):
			total += count
	return total

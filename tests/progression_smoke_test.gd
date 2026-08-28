extends SceneTree

## Prueba la progresion sin disco ni autoloads: tabla de niveles, XP que solo
## sube, historial acotado, serializacion ida y vuelta y catalogo de logros
## sano (ids unicos, escaleras crecientes, estadisticas conocidas y textos).

const SETTINGS_PATH := "res://resources/gameplay/progression_settings.tres"

var _settings: ProgressionSettings


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_settings = load(SETTINGS_PATH) as ProgressionSettings
	if _settings == null:
		_fail("The progression settings resource should load.")
		return
	if not _check_level_table():
		return
	if not _check_extrapolation():
		return
	if not _check_progress():
		return
	if not _check_xp_only_rises():
		return
	if not _check_log_limit():
		return
	if not _check_round_trip():
		return
	if not _check_defaults():
		return
	if not _check_catalog():
		return
	print("Progression smoke test passed.")
	quit()


## Los umbrales arrancan en cero y crecen estrictamente, y cada nivel se
## reconoce desde su propio umbral.
func _check_level_table() -> bool:
	if _settings.level_thresholds.is_empty() or _settings.level_thresholds[0] != 0:
		return _fail("The first level must start at zero XP.")
	if _settings.level_thresholds.size() != _settings.level_names.size():
		return _fail("Every level threshold needs a name.")
	for index in range(1, _settings.level_thresholds.size()):
		if _settings.level_thresholds[index] <= _settings.level_thresholds[index - 1]:
			return _fail("Level thresholds must rise at index %d." % index)
	if _settings.level_for_xp(0) != 1:
		return _fail("Zero XP must sit on level 1.")
	for level in range(1, _settings.level_thresholds.size() + 1):
		if _settings.level_for_xp(_settings.threshold_for_level(level)) != level:
			return _fail("Level %d does not round-trip through its threshold." % level)
		if _settings.level_for_xp(_settings.threshold_for_level(level + 1) - 1) != level:
			return _fail("One XP short of level %d should still be level %d." % [level + 1, level])
	if _settings.level_name(1) != _settings.level_names[0]:
		return _fail("Level 1 should carry the first name of the table.")
	var second_gap := _settings.threshold_for_level(3) - _settings.threshold_for_level(2)
	var first_gap := _settings.threshold_for_level(2) - _settings.threshold_for_level(1)
	if second_gap <= first_gap:
		return _fail("Early levels should come faster than later ones.")
	return true


## Mas alla de la tabla siempre hay un nivel siguiente, mas caro que el anterior.
func _check_extrapolation() -> bool:
	var size := _settings.level_thresholds.size()
	var previous_gap := _settings.threshold_for_level(size) - _settings.threshold_for_level(size - 1)
	for level in range(size + 1, size + 6):
		var gap := _settings.threshold_for_level(level) - _settings.threshold_for_level(level - 1)
		if gap <= previous_gap:
			return _fail("Levels past the table must keep getting more expensive (level %d)." % level)
		previous_gap = gap
		if _settings.level_name(level).is_empty() or _settings.level_name(level) == _settings.level_name(level - 1):
			return _fail("Levels past the table need a distinct name (level %d)." % level)
	var huge := _settings.threshold_for_level(size + 5) + 1
	if _settings.level_for_xp(huge) != size + 5:
		return _fail("A huge XP total should resolve to an extrapolated level.")
	return true


## La barra nunca llega al 100%: siempre queda algo para el siguiente nivel.
func _check_progress() -> bool:
	for xp in [0, 1, 199, 200, 201, 1499, 1500, 149999, 150000, 999999]:
		var progress := _settings.progress(xp)
		if float(progress.ratio) < 0.0 or float(progress.ratio) >= 1.0:
			return _fail("Progress ratio must stay below 100%% (xp %d)." % xp)
		if int(progress.remaining) <= 0:
			return _fail("There must always be XP remaining to the next level (xp %d)." % xp)
		if int(progress.next_level) != int(progress.level) + 1:
			return _fail("The next level is always the one after the current.")
	var at_threshold := _settings.progress(200)
	if int(at_threshold.level) != 2 or int(at_threshold.current) != 0:
		return _fail("Landing exactly on a threshold should start that level with an empty bar.")
	return true


## La XP solo sube, y el nivel sube con ella de forma determinista.
func _check_xp_only_rises() -> bool:
	var profile := ProfileData.new()
	var result := profile.add_xp(150, "test", {}, _settings)
	if profile.xp != 150 or bool(result.leveled_up):
		return _fail("150 XP should not reach level 2 yet.")
	result = profile.add_xp(50, "test", {}, _settings)
	if not bool(result.leveled_up) or int(result.level_after) != 2 or int(result.level_before) != 1:
		return _fail("Crossing 200 XP should level up from 1 to 2.")
	result = profile.add_xp(-500, "test", {}, _settings)
	if profile.xp != 200 or int(result.delta) != 0:
		return _fail("Negative XP must be ignored: XP never goes down.")
	result = profile.add_xp(0, "test", {}, _settings)
	if profile.xp_log.size() != 2:
		return _fail("Only real XP awards should be logged.")
	if _settings.xp_for("zone_hit", 3) != 3 * int(_settings.xp_values.zone_hit):
		return _fail("xp_for should scale by count.")
	if _settings.xp_for("shots_fired") != 0:
		return _fail("Shooting must not pay XP.")
	if _settings.score_xp_for(1234) != 12:
		return _fail("Score XP should be one per hundred points.")
	if _settings.rank_xp_for(5) != 600 or _settings.rank_xp_for(-1) != 0 or _settings.rank_xp_for(99) != 600:
		return _fail("Rank XP should clamp to the table.")
	return true


func _check_log_limit() -> bool:
	var profile := ProfileData.new()
	for index in _settings.xp_log_limit + 20:
		profile.add_xp(1, "spam", {"index": index}, _settings)
	if profile.xp_log.size() != _settings.xp_log_limit:
		return _fail("The XP log must be capped at xp_log_limit.")
	if int(profile.xp_log.back().ctx.index) != _settings.xp_log_limit + 19:
		return _fail("The XP log must keep the newest entries.")
	var recent := profile.recent_xp(3)
	if recent.size() != 3 or int(recent[0].ctx.index) < int(recent[2].ctx.index):
		return _fail("recent_xp should return the newest entries first.")
	return true


func _check_round_trip() -> bool:
	var profile := ProfileData.new()
	profile.created_at = 1000
	profile.add_xp(700, "test", {"level_id": "lvl"}, _settings)
	profile.increment_stat("windows_closed", 7)
	profile.raise_stat("best_multiplier", 4.0)
	profile.add_stat("time_played", 12.5)
	profile.mark_completed("lvl-a")
	profile.mark_completed("lvl-a")
	profile.last_played_id = "lvl-b"
	profile.grant_badge("kill_9")
	var copy := ProfileData.from_dict(profile.to_dict())
	if copy.to_dict() != profile.to_dict():
		return _fail("A profile should survive a to_dict/from_dict round trip.")
	if copy.xp != 700 or copy.level != 3 or int(copy.get_stat("windows_closed")) != 7:
		return _fail("The copy should carry XP, level and stats.")
	if not is_equal_approx(float(copy.get_stat("best_multiplier")), 4.0) or not is_equal_approx(float(copy.get_stat("time_played")), 12.5):
		return _fail("Float stats should survive the round trip.")
	if copy.completed.size() != 1 or not copy.is_completed("lvl-a") or copy.last_played_id != "lvl-b":
		return _fail("Campaign progress should survive the round trip.")
	if not copy.has_badge("kill_9") or copy.grant_badge("kill_9"):
		return _fail("A badge is granted once and never lost.")
	if copy.xp_log.size() != 1:
		return _fail("The XP log should survive the round trip.")
	return true


## Un diccionario vacio (archivo viejo o inexistente) da un perfil por defecto.
func _check_defaults() -> bool:
	var profile := ProfileData.from_dict({})
	if profile.xp != 0 or profile.level != 1 or profile.version != ProfileData.VERSION:
		return _fail("An empty dictionary should yield a fresh profile.")
	for key in ProfileData.DEFAULT_STATS:
		if not profile.stats.has(key):
			return _fail("Every stat should have a default (%s)." % key)
	var partial := ProfileData.from_dict({"xp": {"total": 650}, "stats": {"windows_closed": 3, "unknown": 9}})
	if partial.xp != 650 or int(partial.get_stat("windows_closed")) != 3 or partial.stats.has("unknown"):
		return _fail("A partial dictionary should fill in what it has and drop unknown stats.")
	if not partial.recalibrate(_settings) or partial.level != 3:
		return _fail("Recalibrating should derive the level from the XP.")
	return true


func _check_catalog() -> bool:
	var problems := AchievementCatalog.validate()
	if not problems.is_empty():
		return _fail("The achievement catalog has problems: %s" % ", ".join(problems))
	if AchievementCatalog.all().size() < 20:
		return _fail("The catalog should ship with a full first set of badges.")
	if AchievementCatalog.by_stat("windows_closed").size() < 4:
		return _fail("Window closes should feed several badges.")
	if AchievementCatalog.find("hello_world").is_empty() or not AchievementCatalog.find("nope").is_empty():
		return _fail("find should locate badges by id.")
	if not AchievementCatalog.is_hidden(AchievementCatalog.find("segfault")) or AchievementCatalog.is_hidden(AchievementCatalog.find("kill_9")):
		return _fail("Surprise badges are hidden; the rest are not.")
	if AchievementCatalog.display_name(AchievementCatalog.find("kill_9")) != "KILL -9":
		return _fail("Badge names come from the CSV and are not translated.")
	return true


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false

extends SceneTree

## Prueba el perfil como autoload aislado: bienvenida al crearse, guardado
## diferido con flush, recarga identica desde disco, archivo viejo que se
## completa con valores por defecto y archivo corrupto que se aparta.
##
## Usa una ruta propia, asi que no toca el perfil del jugador ni el de los
## otros tests.

const PATH := "user://_test_profile_persistence.cfg"

var _profile: GameProfile


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_cleanup_files()
	if not await _check_fresh_profile():
		return
	if not _check_deferred_save():
		return
	if not await _check_reload():
		return
	if not await _check_old_file():
		return
	if not await _check_corrupt_file():
		return
	_cleanup_files()
	print("Profile persistence smoke test passed.")
	quit()


## Un jugador nuevo arranca con la bienvenida pagada y el archivo escrito.
func _check_fresh_profile() -> bool:
	_profile = _open(PATH)
	await process_frame
	if _profile.get_xp() != _profile.settings.xp_for("welcome"):
		return _fail("A fresh profile should start with the welcome XP.")
	if _profile.get_level() != 1 or _profile.get_level_name() != _profile.settings.level_name(1):
		return _fail("A fresh profile should sit on level 1.")
	if _profile.badge_count() != 0:
		return _fail("A fresh profile has no badges yet.")
	_profile.flush()
	if not FileAccess.file_exists(PATH):
		return _fail("Flushing a fresh profile should create its file.")
	return true


## Guardar diferido no es no guardar: lo pendiente llega al disco con flush.
func _check_deferred_save() -> bool:
	_profile.award("room_cleared")
	_profile.increment_stat("windows_closed")
	if not _profile.has_badge("kill_9"):
		return _fail("Closing the first window should unlock KILL -9.")
	var expected := _profile.settings.xp_for("welcome") + _profile.settings.xp_for("room_cleared") + int(AchievementCatalog.find("kill_9").xp)
	if _profile.get_xp() != expected:
		return _fail("XP should add the award and the badge.")
	var config := ConfigFile.new()
	config.load(PATH)
	if int(config.get_value("xp", "total", 0)) == expected:
		return _fail("The save should be deferred instead of hitting the disk on every award.")
	_profile.flush()
	config = ConfigFile.new()
	config.load(PATH)
	if int(config.get_value("xp", "total", 0)) != expected:
		return _fail("Flushing should write the pending XP.")
	if not config.has_section_key("achievements", "kill_9"):
		return _fail("Flushing should write the badge.")
	return true


## Cerrar una partida escribe en el acto, y otra instancia lee lo mismo.
func _check_reload() -> bool:
	_profile.set_catalog_ids(PackedStringArray(["lvl-a", "lvl-b"]))
	var report := _profile.record_run("lvl-a", _fake_summary(true))
	if not bool(report.first_clear) or int(report.xp_earned) <= 0:
		return _fail("Completing a level for the first time should report a first clear with XP.")
	if not _profile.is_level_completed("lvl-a") or _profile.completed_count() != 1:
		return _fail("record_run should mark the level as completed.")
	_profile.set_last_played("lvl-b")
	_profile.flush()
	var before := _profile.data.to_dict()
	_close()
	_profile = _open(PATH)
	await process_frame
	var after := _profile.data.to_dict()
	for section in ["xp", "stats", "achievements", "campaign"]:
		if before[section] != after[section]:
			return _fail("Section %s should survive a reload." % section)
	if _profile.get_last_played_id() != "lvl-b":
		return _fail("The last played level should survive a reload.")
	if int(_profile.get_stat("runs_completed")) != 1:
		return _fail("Stats should survive a reload.")
	_close()
	return true


## Un archivo de antes, con lo minimo, se completa con valores por defecto y
## se reescribe con la version actual.
func _check_old_file() -> bool:
	_cleanup_files()
	var config := ConfigFile.new()
	config.set_value("xp", "total", 650)
	config.set_value("profile", "created_at", 12345)
	config.save(PATH)
	_profile = _open(PATH)
	await process_frame
	if _profile.get_xp() != 650:
		return _fail("An old file should keep its XP.")
	if _profile.get_level() != _profile.settings.level_for_xp(650):
		return _fail("Loading should derive the level from the XP.")
	if int(_profile.get_stat("windows_closed")) != 0:
		return _fail("Missing stats should default to zero.")
	_profile.award("room_cleared")
	_profile.flush()
	config = ConfigFile.new()
	config.load(PATH)
	if int(config.get_value("profile", "version", 0)) != ProfileData.VERSION:
		return _fail("Writing should stamp the current file version.")
	if int(config.get_value("profile", "progression_version", 0)) != _profile.settings.progression_version:
		return _fail("Writing should stamp the progression version.")
	_close()
	return true


## Un archivo ilegible se aparta como copia y el juego sigue con un perfil
## nuevo en vez de romperse.
func _check_corrupt_file() -> bool:
	_cleanup_files()
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("[xp\ntotal = = 12\n{{{")
	file.close()
	_profile = _open(PATH)
	await process_frame
	if _profile.get_xp() != _profile.settings.xp_for("welcome"):
		return _fail("A corrupt file should yield a fresh profile.")
	if not FileAccess.file_exists(PATH + GameProfile.BACKUP_SUFFIX):
		return _fail("A corrupt file should be kept as a backup.")
	_profile.flush()
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return _fail("The fresh profile should overwrite the corrupt file.")
	_close()
	return true


func _open(path: String) -> GameProfile:
	var profile := GameProfile.new()
	profile.storage_path = path
	root.add_child(profile)
	return profile


func _close() -> void:
	if _profile == null:
		return
	root.remove_child(_profile)
	_profile.free()
	_profile = null


func _fake_summary(completed: bool) -> Dictionary:
	return {
		"completed": completed,
		"reason": "exit_reached" if completed else "time_expired",
		"total": 4200,
		"ceiling": 6000,
		"ratio": 0.7,
		"rank": {"letter": "B", "label": "POWER USER", "index": 2},
		"best_multiplier": 3.0,
		"best_chain": 12,
		"best_bank": 1800,
		"no_damage": true,
		"hits": 20,
		"attacks": 22,
		"accuracy_percent": 90.9,
		"record": {"is_new": true, "had_previous": false, "previous": 0, "delta": 4200},
	}


func _cleanup_files() -> void:
	for path in [PATH, PATH + GameProfile.BACKUP_SUFFIX]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _fail(message: String) -> bool:
	_close()
	_cleanup_files()
	push_error(message)
	quit(1)
	return false

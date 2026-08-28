class_name AchievementCatalog
extends RefCounted

## Catalogo de logros: una fila por logro, declarativa.
##
## Toda condicion se reduce a "una estadistica del perfil llego a un umbral",
## asi que agregar un logro es agregar una fila y dos claves al CSV de textos.
## Es una clase estatica y no un recurso porque las condiciones no caben en un
## JSON y los nombres viven en el CSV de todos modos.
##
## Tipos: LADDER son escaleras con varios tramos sobre la misma estadistica
## (los tramos se anuncian y se ven venir), SINGLE se gana una vez y SURPRISE
## esta oculto hasta ganarlo, para que un fallo tambien tenga premio.
##
## El `id` es contrato: viaja en el perfil guardado y en las claves de texto.

enum Kind { LADDER, SINGLE, SURPRISE }

const ICON_STAR := "star"
const ICON_FOLDER := "folder"
const ICON_GEAR := "gear"
const ICON_COMPUTER := "computer"
const ICON_RECYCLE := "recycle"
const ICON_POWER := "power"

const BADGES: Array[Dictionary] = [
	# Primer contacto: se ganan en la primera partida, para que el sistema se
	# presente regalando y no exigiendo.
	{"id": "hello_world", "stat": "runs_started", "threshold": 1, "kind": Kind.SINGLE, "xp": 50, "icon": ICON_STAR},
	{"id": "kill_9", "stat": "windows_closed", "threshold": 1, "kind": Kind.SINGLE, "xp": 50, "icon": ICON_STAR},
	# Escalera de ventanas cerradas.
	{"id": "end_task_5", "stat": "windows_closed", "threshold": 5, "kind": Kind.LADDER, "ladder": "end_task", "tier": 1, "xp": 50, "icon": ICON_COMPUTER},
	{"id": "end_task_25", "stat": "windows_closed", "threshold": 25, "kind": Kind.LADDER, "ladder": "end_task", "tier": 2, "xp": 100, "icon": ICON_COMPUTER},
	{"id": "end_task_100", "stat": "windows_closed", "threshold": 100, "kind": Kind.LADDER, "ladder": "end_task", "tier": 3, "xp": 200, "icon": ICON_COMPUTER},
	{"id": "end_task_500", "stat": "windows_closed", "threshold": 500, "kind": Kind.LADDER, "ladder": "end_task", "tier": 4, "xp": 400, "icon": ICON_COMPUTER},
	# Escalera de cierres por la X.
	{"id": "alt_f4_10", "stat": "closed_close", "threshold": 10, "kind": Kind.LADDER, "ladder": "alt_f4", "tier": 1, "xp": 50, "icon": ICON_RECYCLE},
	{"id": "alt_f4_50", "stat": "closed_close", "threshold": 50, "kind": Kind.LADDER, "ladder": "alt_f4", "tier": 2, "xp": 100, "icon": ICON_RECYCLE},
	{"id": "alt_f4_200", "stat": "closed_close", "threshold": 200, "kind": Kind.LADDER, "ladder": "alt_f4", "tier": 3, "xp": 200, "icon": ICON_RECYCLE},
	# Escalera de salas limpiadas.
	{"id": "defrag_1", "stat": "rooms_cleared", "threshold": 1, "kind": Kind.LADDER, "ladder": "defrag", "tier": 1, "xp": 50, "icon": ICON_FOLDER},
	{"id": "defrag_10", "stat": "rooms_cleared", "threshold": 10, "kind": Kind.LADDER, "ladder": "defrag", "tier": 2, "xp": 100, "icon": ICON_FOLDER},
	{"id": "defrag_50", "stat": "rooms_cleared", "threshold": 50, "kind": Kind.LADDER, "ladder": "defrag", "tier": 3, "xp": 200, "icon": ICON_FOLDER},
	# Ejecucion.
	{"id": "clean_build", "stat": "rooms_perfect", "threshold": 1, "kind": Kind.SINGLE, "xp": 150, "icon": ICON_GEAR},
	{"id": "overclock", "stat": "banks_at_top", "threshold": 1, "kind": Kind.SINGLE, "xp": 150, "icon": ICON_GEAR},
	{"id": "firewall_up", "stat": "no_damage_levels", "threshold": 1, "kind": Kind.SINGLE, "xp": 150, "icon": ICON_GEAR},
	{"id": "pixel_perfect", "stat": "accuracy_100_levels", "threshold": 1, "kind": Kind.SINGLE, "xp": 150, "icon": ICON_GEAR},
	{"id": "sudo", "stat": "ranks_s", "threshold": 1, "kind": Kind.SINGLE, "xp": 150, "icon": ICON_POWER},
	{"id": "ring_0", "stat": "ranks_splus", "threshold": 1, "kind": Kind.SINGLE, "xp": 200, "icon": ICON_POWER},
	{"id": "system_shutdown", "stat": "campaign_clears", "threshold": 1, "kind": Kind.SINGLE, "xp": 300, "icon": ICON_POWER},
	# Sorpresas: un fallo o una mania tambien reciben su medalla.
	{"id": "segfault", "stat": "traps_hit", "threshold": 1, "kind": Kind.SURPRISE, "xp": 100, "icon": ICON_RECYCLE},
	{"id": "blue_screen", "stat": "runs_failed_health", "threshold": 1, "kind": Kind.SURPRISE, "xp": 100, "icon": ICON_COMPUTER},
	{"id": "not_responding", "stat": "runs_failed_time", "threshold": 1, "kind": Kind.SURPRISE, "xp": 100, "icon": ICON_COMPUTER},
	{"id": "ctrl_z", "stat": "retries", "threshold": 10, "kind": Kind.SURPRISE, "xp": 100, "icon": ICON_RECYCLE},
	{"id": "cron_job", "stat": "late_night_runs", "threshold": 1, "kind": Kind.SURPRISE, "xp": 100, "icon": ICON_GEAR},
]


## La tabla entera, en el orden en que se muestra en la vitrina.
static func all() -> Array[Dictionary]:
	return BADGES


static func find(badge_id: String) -> Dictionary:
	for badge in BADGES:
		if str(badge.id) == badge_id:
			return badge
	return {}


## Logros que dependen de una estadistica, para evaluarlos cuando cambia.
static func by_stat(stat: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for badge in BADGES:
		if str(badge.stat) == stat:
			result.append(badge)
	return result


static func is_hidden(badge: Dictionary) -> bool:
	return int(badge.get("kind", Kind.SINGLE)) == Kind.SURPRISE


static func name_key(badge_id: String) -> String:
	return "BADGE_%s_NAME" % badge_id.to_upper()


static func description_key(badge_id: String) -> String:
	return "BADGE_%s_DESC" % badge_id.to_upper()


static func display_name(badge: Dictionary) -> String:
	return TranslationServer.translate(name_key(str(badge.id)))


static func description(badge: Dictionary) -> String:
	return TranslationServer.translate(description_key(str(badge.id)))


## Revisa la tabla. Devuelve la lista de problemas; vacia si esta sana. Lo
## corre el smoke test, asi que una fila mal escrita no llega al juego.
static func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	var seen: Dictionary = {}
	var ladders: Dictionary = {}
	for badge in BADGES:
		var badge_id := str(badge.get("id", ""))
		if badge_id.is_empty():
			problems.append("A badge has no id.")
			continue
		if seen.has(badge_id):
			problems.append("Duplicate badge id: %s" % badge_id)
		seen[badge_id] = true
		if not ProfileData.DEFAULT_STATS.has(str(badge.get("stat", ""))):
			problems.append("%s depends on an unknown stat: %s" % [badge_id, str(badge.get("stat", ""))])
		if int(badge.get("threshold", 0)) <= 0:
			problems.append("%s needs a positive threshold." % badge_id)
		if int(badge.get("xp", 0)) <= 0:
			problems.append("%s should pay XP." % badge_id)
		if int(badge.get("kind", Kind.SINGLE)) == Kind.LADDER:
			var ladder := str(badge.get("ladder", ""))
			if ladder.is_empty():
				problems.append("%s is a ladder badge without a ladder name." % badge_id)
			else:
				var previous: Dictionary = ladders.get(ladder, {})
				if not previous.is_empty():
					if int(badge.tier) != int(previous.tier) + 1:
						problems.append("Ladder %s skips a tier at %s." % [ladder, badge_id])
					if int(badge.threshold) <= int(previous.threshold):
						problems.append("Ladder %s must raise its threshold at %s." % [ladder, badge_id])
					if str(badge.stat) != str(previous.stat):
						problems.append("Ladder %s changes stat at %s." % [ladder, badge_id])
				ladders[ladder] = badge
		for key in [name_key(badge_id), description_key(badge_id)]:
			if TranslationServer.translate(key) == key:
				problems.append("Missing translation: %s" % key)
	return problems

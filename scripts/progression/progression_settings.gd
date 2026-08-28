class_name ProgressionSettings
extends Resource

## Perillas de la progresion del jugador: XP por accion, niveles y perfil.
##
## Es la tabla que el libro de gamificacion llama "el minimo para lanzar": cada
## accion valiosa vale XP, la XP nunca baja y los niveles se ganan por umbrales
## acumulados. Todo vive aca para poder recalibrar sin recodear; el numero de
## version acompaña al perfil para saber con que tabla se calculo un nivel.
##
## El diseño esta en docs/gdd_atractivo_y_progresion_ANEXO_gamificacion.md.

@export_group("XP por accion")
## XP que paga cada motivo. Disparar, fallar, recargar y las trampas no figuran
## a proposito: lo que no aporta al juego no aporta XP.
@export var xp_values: Dictionary = {
	"welcome": 50,
	"zone_hit": 5,
	"window_closed": 10,
	"close_zone": 5,
	"ball": 5,
	"chain_step": 10,
	"room_cleared": 50,
	"room_clean": 25,
	"room_perfect": 100,
	"level_completed": 200,
	"level_failed": 50,
	"first_clear": 300,
	"no_damage": 100,
	"new_record": 100,
}
## XP por indice de rango (D, C, B, A, S, S+).
@export var rank_xp: PackedInt32Array = [0, 50, 100, 200, 400, 600]
## Puntos de puntaje que valen 1 XP al cerrar el nivel.
@export_range(10, 10000, 10) var score_points_per_xp := 100

@export_group("Niveles de jugador")
## XP acumulada necesaria para entrar a cada nivel, empezando por 0. Los
## saltos crecen: los primeros niveles llegan rapido y despues cuesta mas.
@export var level_thresholds: PackedInt32Array = [
	0, 200, 600, 1500, 3000, 5500, 9000, 14000, 21000, 30000, 42000, 58000, 80000, 110000, 150000,
]
## Nombre de cada nivel. No se traducen: son hardware, como los rangos son
## usuarios del sistema operativo.
@export var level_names: PackedStringArray = [
	"286", "386", "486", "PENTIUM", "PENTIUM II", "PENTIUM III", "PENTIUM 4", "CORE 2",
	"CORE i3", "CORE i5", "CORE i7", "CORE i9", "XEON", "THREADRIPPER", "QUANTUM",
]
## Cuanto crece cada salto mas alla de la tabla. La barra nunca llega al 100%:
## siempre hay un nivel siguiente.
@export_range(1.0, 3.0, 0.05) var elder_growth := 1.35

@export_group("Perfil")
## Entradas del historial de XP que se conservan.
@export_range(10, 1000, 10) var xp_log_limit := 100
## Segundos de espera antes de escribir el perfil en disco.
@export_range(0.5, 10.0, 0.5) var save_delay := 2.0
## Segundos que un globo de aviso queda en pantalla.
@export_range(1.0, 15.0, 0.5) var notice_seconds := 4.0
## Cambiar la tabla de niveles invalida el nivel guardado: al cargar un perfil
## de otra version se recalcula desde la XP, que nunca miente.
@export var progression_version := 1


func xp_for(reason: String, count := 1) -> int:
	return int(xp_values.get(reason, 0)) * maxi(count, 0)


func rank_xp_for(rank_index: int) -> int:
	if rank_xp.is_empty() or rank_index < 0:
		return 0
	return rank_xp[mini(rank_index, rank_xp.size() - 1)]


## XP que vale un puntaje de nivel.
func score_xp_for(score: int) -> int:
	if score <= 0 or score_points_per_xp <= 0:
		return 0
	return score / score_points_per_xp


## Nivel (desde 1) que corresponde a una XP acumulada. Nunca devuelve 0.
func level_for_xp(xp: int) -> int:
	var level := 1
	while threshold_for_level(level + 1) <= xp:
		level += 1
	return level


## XP acumulada para entrar a un nivel. Mas alla de la tabla el salto crece
## geometricamente, asi que siempre hay un umbral siguiente.
func threshold_for_level(level: int) -> int:
	if level <= 1 or level_thresholds.is_empty():
		return 0
	if level <= level_thresholds.size():
		return level_thresholds[level - 1]
	if level_thresholds.size() < 2:
		return int(level_thresholds[0] + (level - 1) * 1000)
	var previous := level_thresholds[level_thresholds.size() - 2]
	var last := level_thresholds[level_thresholds.size() - 1]
	var step := float(last - previous)
	var threshold := float(last)
	for _extra in level - level_thresholds.size():
		step *= elder_growth
		threshold += step
	return int(threshold)


## Nombre del nivel. Fuera de la tabla se sigue nombrando al ultimo con un
## sufijo de overclock, para que el nivel 40 no sea "Nivel 40".
func level_name(level: int) -> String:
	if level_names.is_empty():
		return str(level)
	if level <= level_names.size():
		return level_names[maxi(level, 1) - 1]
	return "%s OC+%d" % [level_names[level_names.size() - 1], level - level_names.size()]


## Todo lo que una barra de progreso necesita para dibujarse.
func progress(xp: int) -> Dictionary:
	var level := level_for_xp(xp)
	var floor_xp := threshold_for_level(level)
	var next_xp := threshold_for_level(level + 1)
	var span := maxi(next_xp - floor_xp, 1)
	return {
		"level": level,
		"name": level_name(level),
		"next_level": level + 1,
		"next_name": level_name(level + 1),
		"xp": xp,
		"current": xp - floor_xp,
		"needed": span,
		"remaining": next_xp - xp,
		"ratio": clampf(float(xp - floor_xp) / float(span), 0.0, 0.999),
	}

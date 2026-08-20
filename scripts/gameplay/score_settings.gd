class_name ScoreSettings
extends Resource

## Pesos y umbrales del sistema de puntuacion.
##
## Todo el ajuste del sistema vive aca: valor de cada zona, escalones de la
## cadena, castigos, bonos y rangos. El diseño esta en
## docs/gdd_atractivo_y_progresion_ANEXO_puntuación.md.

@export_group("Valor por accion")
## Puntos que aporta cada zona disparable, por zone_id. Un valor negativo
## marca una zona trampa: resta y cierra la cadena.
@export var zone_values: Dictionary = {
	"close": 100,
	"accept": 60,
	"cancel": 60,
	"finish": 60,
	"sign": 40,
	"next": 10,
	"trap": -150,
}
## Valor de una zona que no figura en la tabla.
@export var default_zone_value := 60
## Valor de una pelota, el objetivo generico de un impacto.
@export var ball_value := 50

@export_group("Cadena")
## Multiplicador de cada escalon. El primero es el piso y el ultimo, el techo.
@export var chain_multipliers: PackedFloat32Array = [1.0, 1.5, 2.0, 3.0, 4.0, 6.0, 8.0]
## Hits necesarios para entrar a cada escalon a partir del segundo.
@export var chain_thresholds: PackedInt32Array = [3, 6, 10, 14, 19, 25]
## Segundos sin acciones validas antes de que la cadena decaiga un escalon.
@export_range(0.5, 15.0, 0.1) var grace_seconds := 3.0
## Escalones que baja cada fallo. El ultimo valor se repite si se falla mas.
@export var miss_step_drops: PackedInt32Array = [2, 3, 4]
## Escalones que baja el vencimiento del temporizador.
@export_range(0, 4, 1) var timeout_step_drop := 1

@export_group("Bonos de sala")
@export var room_clean_bonus := 500
@export var room_single_chain_bonus := 800
@export var room_intact_chain_bonus := 300
@export var room_accuracy_thresholds: PackedFloat32Array = [0.6, 0.8, 1.0]
@export var room_accuracy_bonuses: PackedInt32Array = [100, 300, 600]
## Segundos de referencia por objetivo, para el par de tiempo de la sala.
@export_range(0.2, 10.0, 0.1) var par_seconds_per_target := 1.8
## Segundos de referencia por sala, para entrar y ubicarse.
@export_range(0.0, 20.0, 0.1) var par_transit_seconds := 2.5
@export var par_second_bonus := 10

@export_group("Bonos de nivel")
@export var ammo_bonus_per_round := 5
@export var time_bonus_per_second := 10
@export var level_no_damage_bonus := 2000
@export var level_all_rooms_clean_bonus := 1000
@export var level_perfect_bonus := 2500

@export_group("Rangos")
## Proporcion del techo necesaria para cada rango por encima del minimo.
@export var rank_thresholds: PackedFloat32Array = [0.35, 0.55, 0.75, 0.90, 1.00]
@export var rank_letters: PackedStringArray = ["D", "C", "B", "A", "S", "S+"]
@export var rank_labels: PackedStringArray = ["GUEST", "USER", "POWER USER", "ADMIN", "ROOT", "KERNEL"]

## Cambiar cualquier peso invalida los records viejos, asi que se guardan con la
## version con la que se lograron en vez de compararlos contra otra formula.
@export var formula_version := 1


## Puntos que aporta una zona. Devuelve el valor por defecto si no esta tabulada.
func value_for_zone(zone_id: String) -> int:
	return int(zone_values.get(zone_id, default_zone_value))


## Una zona que resta es una trampa: ademas de restar, cierra la cadena.
func is_trap_zone(zone_id: String) -> bool:
	return value_for_zone(zone_id) < 0


## Escalon que corresponde a una cantidad de hits. 0 es el piso.
func step_for_hits(hits: int) -> int:
	var step := 0
	for index in chain_thresholds.size():
		if hits >= chain_thresholds[index]:
			step = index + 1
	return mini(step, chain_multipliers.size() - 1)


## Hits minimos para estar parado en un escalon.
func hits_for_step(step: int) -> int:
	if step <= 0:
		return 0
	var index := mini(step, chain_thresholds.size()) - 1
	return chain_thresholds[index]


func multiplier_for_step(step: int) -> float:
	if chain_multipliers.is_empty():
		return 1.0
	return chain_multipliers[clampi(step, 0, chain_multipliers.size() - 1)]


func multiplier_for_hits(hits: int) -> float:
	return multiplier_for_step(step_for_hits(hits))


func top_step() -> int:
	return maxi(chain_multipliers.size() - 1, 0)


## Escalones que baja el enesimo fallo consecutivo, contando desde 1.
func miss_drop_for(consecutive_misses: int) -> int:
	if miss_step_drops.is_empty():
		return 1
	var index := clampi(consecutive_misses - 1, 0, miss_step_drops.size() - 1)
	return miss_step_drops[index]


## Zona mas cara de la tabla. Es lo que rinde un objetivo resuelto de la mejor
## manera posible, y con eso se calcula el techo de una sala.
func best_zone_value() -> int:
	var best := default_zone_value
	for zone_id in zone_values:
		best = maxi(best, int(zone_values[zone_id]))
	return best


func room_accuracy_bonus(accuracy: float) -> int:
	var bonus := 0
	for index in room_accuracy_thresholds.size():
		if index >= room_accuracy_bonuses.size():
			break
		if accuracy + 0.0001 >= room_accuracy_thresholds[index]:
			bonus = room_accuracy_bonuses[index]
	return bonus


func max_room_accuracy_bonus() -> int:
	var best := 0
	for bonus in room_accuracy_bonuses:
		best = maxi(best, bonus)
	return best


## Rango alcanzado con una proporcion del techo. Completar el nivel ya vale el
## rango mas bajo, asi que la tabla arranca por encima de eso.
func rank_for_ratio(ratio: float) -> Dictionary:
	var index := 0
	for threshold_index in rank_thresholds.size():
		if ratio + 0.0001 >= rank_thresholds[threshold_index]:
			index = threshold_index + 1
	index = clampi(index, 0, rank_letters.size() - 1)
	return {
		"letter": rank_letters[index],
		"label": rank_labels[clampi(index, 0, rank_labels.size() - 1)],
		"index": index,
	}

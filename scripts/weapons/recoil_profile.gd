extends Resource
class_name RecoilProfile

## Perfil de retroceso e imprecision al estilo Counter-Strike 1.6.
## Todos los angulos se expresan en grados, de modo que los valores son
## independientes de la resolucion y del FOV de la camara.

@export_group("Camera Kick")
## Grados que la vista sube con el primer disparo de una rafaga.
@export var vertical_kick: float = 1.1
## Grados extra que se suman por cada disparo consecutivo.
@export var vertical_kick_growth: float = 0.35
## Tope del retroceso vertical por disparo.
@export var max_vertical_kick: float = 3.5
## Grados que la vista se desvia lateralmente (el signo es aleatorio).
@export var horizontal_kick: float = 0.18
## Grados laterales extra por cada disparo consecutivo.
@export var horizontal_kick_growth: float = 0.15
## Tope del retroceso lateral por disparo.
@export var max_horizontal_kick: float = 1.2
## Velocidad con la que la vista alcanza el retroceso acumulado (1/s).
@export var kick_snappiness: float = 24.0
## Velocidad con la que la vista vuelve al punto original (1/s).
@export var recovery_speed: float = 4.5

@export_group("Spread")
## Dispersion en reposo. Con 0 el primer disparo quieto es perfecto.
@export var base_spread: float = 0.0
## Dispersion que agrega cada disparo.
@export var spread_per_shot: float = 0.75
## Tope de la dispersion acumulada por disparos.
@export var max_shot_spread: float = 3.0
## Grados por segundo que se recuperan al dejar de disparar.
@export var spread_recovery: float = 2.5
## Dispersion agregada al correr a maxima velocidad.
@export var move_spread: float = 1.8
## Dispersion agregada mientras se esta en el aire.
@export var air_spread: float = 3.0
## Multiplicador de toda la dispersion mientras se esta agachado.
@export var crouch_multiplier: float = 0.55
## Multiplicador de toda la dispersion mientras se apunta con la mira (ADS).
## Se combina con el de agachado: los dos se multiplican.
@export var ads_multiplier: float = 0.6
## Tope absoluto de la dispersion resultante.
@export var max_spread: float = 6.0

@export_group("Timing")
## Segundos sin disparar necesarios para reiniciar el contador de la rafaga.
@export var shot_reset_time: float = 0.35

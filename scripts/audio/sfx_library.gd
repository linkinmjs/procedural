class_name SfxLibrary
extends Resource

## Mapa evento -> AudioStream para Sfx, con un ajuste de volumen opcional por
## evento (los packs traen niveles muy dispares y conviene nivelarlos aca y no
## en cada llamada).
##
## Eventos que hoy llaman los sistemas del juego. Los marcados (3D) suenan
## posicionados en el mundo con Sfx.play_at(); el resto es Sfx.play(), sin
## posicion, porque son del jugador o del HUD y no deben atenuarse ni
## colorearse por la sala:
##   impact_wall (3D)       - bala contra superficie
##   target_destroyed (3D)  - bola destruida
##   window_button (3D)     - zona/boton de ventana presionado
##   window_close (3D)      - ventana resuelta
##   window_error (3D)      - trampa del error critico
##   shield_blocked (3D)    - disparo rebotado por firewall
##   ad_skip_ready (3D)     - el SKIP de la publicidad quedo disponible
##   hitmarker              - acierto confirmado en el HUD
##   player_hurt            - danio recibido
##   footstep               - paso del jugador
##   land                   - aterrizaje del jugador
##   combo_step_up          - subio el escalon del multiplicador (pitch por escalon)
##   combo_drop             - cayo un escalon de la cadena
##   chain_lost             - cadena cerrada a x1 (danio/trampa/timeout)
##   chain_saved            - acierto con el timer casi agotado
##   chain_tick             - tic de urgencia del timer de cadena
##   bank                   - pozo cobrado al limpiar la sala
##   ui_hover / ui_click / ui_back - botones de los menus
##
## El disparo del arma no pasa por aca: va por el SpatialAudio3D del arma.

@export var streams: Dictionary = {}
## Ajuste en dB por evento. Sin entrada, 0 dB.
@export var volumes_db: Dictionary = {}


func stream_for(event: String) -> AudioStream:
	return streams.get(event) as AudioStream


func volume_for(event: String) -> float:
	return float(volumes_db.get(event, 0.0))

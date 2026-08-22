class_name SfxLibrary
extends Resource

## Mapa evento -> AudioStream para el autoload Sfx.
##
## El juice visual ya deja cada evento cableado con su nombre; integrar el
## audio es asignar streams aca, sin tocar gameplay. Un evento sin stream
## no suena y no falla.
##
## Eventos esperados hoy (los llaman los sistemas de juice):
##   impact_wall        - bala contra superficie
##   target_destroyed   - bola destruida
##   hitmarker          - acierto confirmado en el HUD
##   player_hurt        - danio recibido
##   window_close       - ventana resuelta
##   window_button      - zona/boton de ventana presionado
##   window_error       - trampa del error critico
##   shield_blocked     - disparo rebotado por firewall
##   ad_skip_ready      - el SKIP de la publicidad quedo disponible
##   combo_step_up      - subio el escalon del multiplicador (pitch por escalon)
##   combo_drop         - cayo un escalon de la cadena
##   chain_lost         - cadena cerrada a x1 (danio/trampa/timeout)
##   chain_saved        - acierto con el timer casi agotado
##   chain_tick         - tic de urgencia del timer de cadena
##   bank               - pozo cobrado al limpiar la sala

@export var streams: Dictionary = {}

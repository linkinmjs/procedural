class_name PopupWindow
extends WindowPanel3D

## Publicidad: no se puede cerrar hasta que el contador la deje, y mientras
## tanto llama a otra.
##
## Es la familia que cobra la demora, y lo hace como cobra una publicidad de
## verdad: haciéndote esperar. El botón dice SKIP con una cuenta regresiva; al
## llegar a cero escupe **una** publicidad nueva y se queda con el SKIP
## disponible. No vuelve a empezar: cada una llama a una sola.
##
## El freno es por capa, no por ventana: hasta `MAX_LIVE_ADS` a la vez. La que
## aparece cuando ya no queda lugar nace con el SKIP listo, sin contador, porque
## no tendría a quién llamar.
##
## Errar el disparo y pegarle al cuerpo del aviso también abre otro. Es la única
## familia donde fallar cuesta algo más que la bala.

## Cuántas publicidades pueden convivir en una capa. Por encima de esto la sala
## se vuelve una pared de ventanas y deja de ser jugable.
const MAX_LIVE_ADS := 7
## Zona del cuerpo del aviso: acertarle no lo cierra, abre otro.
const AD_ZONE := "ad"
## Zona del botón que sí lo cierra, una vez que el contador lo permite.
const SKIP_ZONE := "accept"

## Segundos de espera antes de que el boton deje saltear. Las variantes de la
## escena cambian este valor: una de cinco segundos apura, una de diez ahoga.
##
## La espera nunca deja al jugador sin salida: la X cierra siempre. El boton
## grande es el premio por aguantar; la X, el chico que esta disponible ya.
@export_range(0.0, 30.0, 1.0) var skip_seconds := 5.0

var _remaining := 0.0
var _called_one := false
var _skip_button: Button
var _skip_zone: WindowHitZone


func _ready() -> void:
	super()
	window_label = "publicidad"
	# La publicidad muere como un monitor al que le cortan la corriente.
	close_style = CLOSE_STYLE_CRT
	# El nodo es un Button con el script de zona: el compilador no deja pasar de
	# uno al otro, pero desde Node se llega a los dos.
	var skip_node := content.find_child("SkipZone", true, false) if content != null else null
	_skip_zone = skip_node as WindowHitZone
	_skip_button = skip_node as Button
	_remaining = skip_seconds
	_refresh_skip()
	zone_hit.connect(_on_zone)


func _process(delta: float) -> void:
	if _remaining <= 0.0:
		set_process(false)
		return
	_remaining -= delta
	if _remaining > 0.0:
		_refresh_skip()
		return
	_remaining = 0.0
	_refresh_skip()
	_announce_skip_ready()
	# El contador llegó a cero: llama a una y se queda quieta esperando el SKIP.
	_open_another()


## Nace sin contador: ya se puede saltear y no llama a nadie. Es como aparece la
## que completa el cupo de la capa.
func arrive_without_countdown() -> void:
	_remaining = 0.0
	_called_one = true
	_refresh_skip()


## El botón dice qué se puede hacer, no sólo cuánto falta: mientras corre la
## espera pide esperar, y cuando termina invita a saltear. Un botón que dice
## SKIP pero no saltea se lee como que está roto.
func _refresh_skip() -> void:
	if _skip_button != null:
		var label := tr("AD_WAIT").format({"seconds": ceili(_remaining)}) if _remaining > 0.0 else tr("AD_SKIP")
		# El texto cambia una vez por segundo; solo entonces vale redibujar la
		# pantalla y reformar el boton.
		if label != _skip_button.text:
			_skip_button.text = label
			request_screen_redraw()
	if _skip_zone != null:
		_skip_zone.closes_window = _remaining <= 0.0
		_skip_zone.scores = _remaining <= 0.0
	for body in get_hit_bodies():
		if body.zone_id == SKIP_ZONE:
			body.closes_window = _remaining <= 0.0
			body.scores = _remaining <= 0.0
			body.rearm()


## El SKIP paso de pedir espera a estar disponible: el boton pulsa un par de
## veces para avisar sin que haga falta leerlo.
func _announce_skip_ready() -> void:
	request_screen_redraw(1.0)
	Sfx.play_at("ad_skip_ready", global_position)
	if _skip_button == null:
		return
	var tween := _skip_button.create_tween()
	for _i in 2:
		tween.tween_property(_skip_button, "modulate", Color(1.35, 1.35, 0.7), 0.12)
		tween.tween_property(_skip_button, "modulate", Color.WHITE, 0.16)


func _on_zone(zone_id: String, _window: WindowPanel3D) -> void:
	if zone_id == AD_ZONE:
		# Le pegó al aviso en vez de al botón: se abre otro, como en la vida.
		_open_another()
		return
	if zone_id == SKIP_ZONE and _remaining > 0.0:
		# Insistir con el botón antes de tiempo no hace nada, pero la zona tiene
		# que seguir viva para el disparo que sí va a servir.
		var body := find_hit_body(SKIP_ZONE)
		if body != null:
			body.rearm()


## Abre una publicidad más, si la capa todavía tiene lugar.
func _open_another() -> void:
	if _called_one:
		return
	_called_one = true
	var parent := get_parent()
	if parent == null:
		return
	var live := _live_ads(parent)
	if live >= MAX_LIVE_ADS:
		return
	# Se instancia la escena en vez de duplicar el nodo: el material y el quad de
	# la ventana son locales a la escena, y `duplicate()` no los reinstancia, asi
	# que la copia terminaba compartiendo la textura del original y quedaba en
	# blanco en cuanto el original se cerraba.
	var scene := load(scene_file_path) as PackedScene
	if scene == null:
		return
	var copy := scene.instantiate() as PopupWindow
	if copy == null:
		return
	copy.position = position
	copy.rotation = rotation
	parent.add_child(copy)
	# La que completa el cupo llega sin contador: no tendría a quién llamar.
	if live + 1 >= MAX_LIVE_ADS:
		copy.arrive_without_countdown()
	# El volumen lleva la cuenta de lo que queda vivo en la capa y ademas la
	# ubica adentro del bloque; sin el, la nueva se queda donde nacio.
	var volume := parent.get_parent() as TargetSpawnVolume3D
	if volume != null:
		volume.adopt_target(copy)
	else:
		copy.position = position + Vector3(0.9, -0.6, 0.02)


func _live_ads(parent: Node) -> int:
	var count := 0
	for child in parent.get_children():
		if child is PopupWindow and not child.is_queued_for_deletion():
			count += 1
	return count



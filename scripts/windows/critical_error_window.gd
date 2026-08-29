class_name CriticalErrorWindow
extends WindowPanel3D

## Error critico: tiene un solo control bueno y varios que castigan, y no se
## quedan quietos.
##
## Es la familia que cobra el disparo apurado. Los tres controles son iguales de
## grandes, asi que no pide mas punteria: pide leer antes de tirar. Nacen en
## orden aleatorio, y cada vez que el jugador le pega al equivocado se vuelven a
## barajar, para que memorizar la posicion no sirva de nada.
##
## El castigo sale del sistema de puntaje que ya existe: las zonas malas usan el
## identificador de trampa, que corta la cadena y resta.

## Identificador de las zonas que castigan. Es el que `score_settings.tres` ya
## puntua en negativo.
const TRAP_ZONE := "trap"

## Los controles se guardan como zonas y no como botones: un Button con el
## script de zona es, para el tipado, un Control con ese script.
## Lo que tardan los botones en deslizarse a su lugar nuevo, y cuanto mas se
## mantiene viva la pantalla para que el ultimo frame del deslizamiento se vea.
const SHUFFLE_SECONDS := 0.16
const SHUFFLE_REDRAW_MARGIN := 0.1

var _buttons: Array[WindowHitZone] = []
var _slots: Array[Vector2] = []


func _ready() -> void:
	super()
	window_label = "error critico"
	# El error critico muere como se apaga un monitor colgado.
	close_style = CLOSE_STYLE_CRT
	_collect_buttons()
	_shuffle()
	zone_hit.connect(_on_zone)


## Los tres controles y los lugares donde pueden estar. Los lugares salen de
## donde el layout ya los puso: barajar es repartir esas mismas posiciones.
func _collect_buttons() -> void:
	if content == null:
		return
	for child in content.get_children():
		var zone := child as WindowHitZone
		# La barra de titulo tambien es zona, pero no es un control del cuerpo:
		# no entra en el sorteo.
		if zone != null and zone.zone_id != RAISE_ZONE:
			_buttons.append(zone)
			_slots.append(Vector2(zone.offset_left, zone.offset_right))


func _on_zone(zone_id: String, _window: WindowPanel3D) -> void:
	if zone_id != TRAP_ZONE:
		return
	_flash_error()
	Sfx.play_at("window_error", global_position)
	_shuffle()


## Destello rojo de la ventana entera: el castigo del trap se ve, no solo se
## descuenta en el puntaje.
func _flash_error() -> void:
	request_screen_redraw(0.6)
	var material := _screen_material()
	if material == null or shielded:
		return
	material.albedo_color = Color(1.0, 0.45, 0.45)
	var tween := create_tween()
	tween.tween_property(material, "albedo_color", Color.WHITE, 0.3)


## Reparte los lugares entre los controles y vuelve a generar los cuerpos, que
## es lo que hace que el disparo siga la posicion nueva y no la vieja. Los
## botones se deslizan a su lugar en vez de teletransportarse: sin la
## transicion, el reordenamiento parecia un glitch y no un castigo.
func _shuffle() -> void:
	if _buttons.size() < 2:
		request_screen_redraw()
		return
	# La pantalla se dibuja una sola vez por pedido: durante el deslizamiento
	# hay que mantenerla viva, o queda congelada con los botones a mitad de
	# camino, superpuestos y sin coincidir con las zonas de impacto.
	request_screen_redraw(SHUFFLE_SECONDS + SHUFFLE_REDRAW_MARGIN)
	var order: Array[int] = []
	for index in _slots.size():
		order.append(index)
	order.shuffle()
	var tween := create_tween()
	tween.set_parallel(true)
	for index in _buttons.size():
		var slot := _slots[order[index]]
		tween.tween_property(_buttons[index], "offset_left", slot.x, SHUFFLE_SECONDS) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(_buttons[index], "offset_right", slot.y, SHUFFLE_SECONDS) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	# Un dibujado mas con los botones ya quietos, por si el pedido con duracion
	# se apago un frame antes de que el tween pusiera el valor final.
	request_screen_redraw()
	rebuild_hit_zones()

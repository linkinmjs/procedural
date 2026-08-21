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
var _buttons: Array[WindowHitZone] = []
var _slots: Array[Vector2] = []


func _ready() -> void:
	super()
	window_label = "error critico"
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
	_shuffle()


## Reparte los lugares entre los controles y vuelve a generar los cuerpos, que
## es lo que hace que el disparo siga la posicion nueva y no la vieja.
func _shuffle() -> void:
	if _buttons.size() < 2:
		return
	var order: Array[int] = []
	for index in _slots.size():
		order.append(index)
	order.shuffle()
	for index in _buttons.size():
		var slot := _slots[order[index]]
		_buttons[index].offset_left = slot.x
		_buttons[index].offset_right = slot.y
	await get_tree().process_frame
	rebuild_hit_zones()

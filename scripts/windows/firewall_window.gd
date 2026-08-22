class_name FirewallWindow
extends WindowPanel3D

## Firewall: mientras esta en pie, protege a las demas ventanas de su capa.
##
## Es la familia que impone un orden. No agrega dificultad de punteria: agrega
## una decision de prioridad, porque disparar a cualquier otra cosa antes de
## desactivarlo es tiempo perdido. Al caer, todo lo que cubria queda disponible.
##
## Cubre a sus hermanas de capa, no a la sala entera: dos bloques distintos son
## dos problemas distintos y mezclarlos volveria el encuentro ilegible.

var _shielded_windows: Array[WindowPanel3D] = []


func _ready() -> void:
	super()
	window_label = "firewall"
	# El firewall se apaga como un equipo al que le cortan la corriente; junto
	# con el tinte de las hermanas fundiendose, es el anuncio de que la capa
	# quedo abierta.
	close_style = CLOSE_STYLE_CRT
	# Un frame de espera: al nacer, las hermanas de la capa todavia se estan
	# repartiendo y la lista quedaria corta.
	await get_tree().process_frame
	_raise_shield()
	closed.connect(_on_closed)


func _exit_tree() -> void:
	_lower_shield()


## Protege a todas las ventanas hermanas que no sean firewalls. Dos firewalls en
## la misma capa se cubren entre si tan poco como se cubren a si mismos: cada uno
## se puede desactivar por separado.
func _raise_shield() -> void:
	for sibling in _siblings():
		sibling.shielded = true
		_shielded_windows.append(sibling)


func _lower_shield() -> void:
	for window in _shielded_windows:
		if is_instance_valid(window):
			window.shielded = false
	_shielded_windows.clear()


func _on_closed(_window: WindowPanel3D) -> void:
	_lower_shield()


func _siblings() -> Array[WindowPanel3D]:
	var windows: Array[WindowPanel3D] = []
	var parent := get_parent()
	if parent == null:
		return windows
	for child in parent.get_children():
		var window := child as WindowPanel3D
		if window != null and window != self and window is not FirewallWindow:
			windows.append(window)
	return windows

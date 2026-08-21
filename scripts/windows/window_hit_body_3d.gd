class_name WindowHitBody3D
extends StaticBody3D

## Cuerpo generado por WindowPanel3D para una zona disparable.
## Cumple el contrato de impacto del template FPS: grupo "Target" + Hit_Successful.

signal hit(body: WindowHitBody3D)

var zone_id := ""
var closes_window := true
var scores := true

var _resolved := false


func Hit_Successful(_damage: float, _direction := Vector3.ZERO, _hit_position := Vector3.ZERO) -> void:
	if _resolved:
		return
	_resolved = true
	hit.emit(self)


## Vuelve a dejar la zona disponible. Un disparo que no resolvio nada —el que
## rebota contra una ventana protegida— no puede gastarla para siempre: al caer
## el firewall el jugador tiene que poder volver a apuntarle al mismo lugar.
func rearm() -> void:
	_resolved = false

class_name WindowPanel3D
extends Node3D

## Ventana estilo Windows renderizada en 3D.
##
## El contenido se dibuja como UI normal dentro del SubViewport y se proyecta
## sobre un quad. Cada Control con el script WindowHitZone genera un cuerpo
## disparable en la misma posicion, para que el jugador pueda cerrarla apuntando
## a la X, a un boton o a un cartel.

signal zone_hit(zone_id: String, window: WindowPanel3D)
signal closed(window: WindowPanel3D)
## Le pegaron mientras estaba protegida: el disparo no le hizo nada.
signal blocked(window: WindowPanel3D)
## Paso al frente de sus hermanas.
signal raised(window: WindowPanel3D)
## La ventana infecto el sistema: quien la contenga decide que hacer. Va por
## señal y no buscando al bloque hacia arriba para no atar la ventana al bloque:
## el bloque conoce al catalogo de ventanas, asi que la ventana no puede conocer
## al bloque sin cerrar un ciclo.
signal system_crashed(window: WindowPanel3D)

const HIT_ZONE_DEPTH := 0.06
## Cuanto se adelanta cada zona respecto de la anterior. Las zonas se superponen
## —la X vive dentro de la barra de titulo, el boton dentro del aviso— y con
## todas en el mismo plano el disparo elegia cualquiera: apuntarle a la X podia
## pegarle a la barra. Se escalonan en el orden en que la interfaz las dibuja,
## asi que a lo que se le apunta es a lo que se ve encima.
const ZONE_STACK_STEP := 0.012
const TARGET_GROUP := "Target"
const TARGET_LAYER := 32
const TARGET_MASK := 16
## Tinte de la ventana protegida por un firewall.
const SHIELD_TINT := Color(0.45, 0.62, 0.95)
## Zona que trae la ventana al frente en vez de resolverla. Es la barra de
## titulo, como en cualquier escritorio.
const RAISE_ZONE := "raise"
## Cuanto se adelanta la ventana que pasa al frente respecto de la que estaba
## primera. Es chico: solo tiene que ganar el sorteo de profundidad, no salirse
## del bloque.
const RAISE_STEP := 0.02

## Cuantos pixeles del SubViewport equivalen a un metro del mundo.
## Nombre con el que la ventana aparece en el feed de la ronda.
@export var window_label := "ventana"

@export_range(40.0, 800.0, 1.0) var pixels_per_meter := 73.0:
	set(value):
		pixels_per_meter = maxf(value, 1.0)
		if is_node_ready():
			_update_screen_size()

@onready var sub_viewport: SubViewport = $SubViewport
@onready var screen: MeshInstance3D = $Screen
@onready var hit_zone_root: Node3D = $HitZones

var content: Control
## Mientras esta protegida los disparos rebotan: no la cierran ni suman. Es lo
## que hace el firewall con las ventanas que cubre.
var shielded := false:
	set(value):
		shielded = value
		_update_shield_tint()
var _closed := false


func _ready() -> void:
	content = _find_content()
	if content == null:
		push_error("WindowPanel3D requires a Control as the first SubViewport child.")
		return
	_update_screen_size()
	_update_shield_tint()
	await get_tree().process_frame
	rebuild_hit_zones()


## Vuelve a generar los cuerpos disparables a partir del layout actual.
func rebuild_hit_zones() -> void:
	for child in hit_zone_root.get_children():
		child.queue_free()
	var zones := _collect_zones(content)
	for index in zones.size():
		_add_hit_body(zones[index], index)


## Trae la ventana adelante de sus hermanas, como al hacer clic en la barra de
## titulo de un escritorio. Solo tiene sentido porque las ventanas de un bloque
## se superponen a proposito.
func bring_to_front() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var front := position.z
	for child in parent.get_children():
		var sibling := child as Node3D
		if sibling != null and sibling != self:
			front = maxf(front, sibling.position.z)
	if is_equal_approx(front, position.z):
		return
	position.z = front + RAISE_STEP
	raised.emit(self)


func close() -> void:
	if _closed:
		return
	_closed = true
	closed.emit(self)
	queue_free()


## Cuerpos disparables generados, en el orden en que aparecen en el layout.
func get_hit_bodies() -> Array[WindowHitBody3D]:
	var bodies: Array[WindowHitBody3D] = []
	for child in hit_zone_root.get_children():
		var body := child as WindowHitBody3D
		if body != null:
			bodies.append(body)
	return bodies


## Primer cuerpo con ese identificador. Varias zonas pueden compartir zone_id.
func find_hit_body(zone_id: String) -> WindowHitBody3D:
	for body in get_hit_bodies():
		if body.zone_id == zone_id:
			return body
	return null


func get_window_size() -> Vector2:
	return Vector2(sub_viewport.size) / pixels_per_meter


func _find_content() -> Control:
	for child in sub_viewport.get_children():
		if child is Control:
			return child
	return null


## Solo las zonas a la vista generan cuerpo. Una ventana puede tener controles
## escondidos —la confirmacion de la descarga, por ejemplo— y dispararle a algo
## que no esta en pantalla seria un acierto invisible.
func _collect_zones(node: Node) -> Array[WindowHitZone]:
	var zones: Array[WindowHitZone] = []
	var control := node as Control
	if control != null and not control.visible:
		return zones
	if node is WindowHitZone:
		zones.append(node)
	for child in node.get_children():
		zones.append_array(_collect_zones(child))
	return zones


## `order` es la posicion de la zona en el orden de dibujado: un hijo se dibuja
## sobre su padre y un hermano posterior sobre el anterior, asi que ese mismo
## orden es el que decide cual esta mas cerca del jugador.
func _add_hit_body(zone: WindowHitZone, order: int) -> void:
	var rect := zone.get_global_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		push_warning("WindowHitZone '%s' has no size; skipping it." % zone.zone_id)
		return
	var body := WindowHitBody3D.new()
	body.name = zone.name
	body.zone_id = zone.zone_id
	body.closes_window = zone.closes_window
	body.scores = zone.scores
	body.collision_layer = TARGET_LAYER
	body.collision_mask = TARGET_MASK
	body.add_to_group(TARGET_GROUP)
	body.position = _viewport_to_local(rect.get_center(), order)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(rect.size.x / pixels_per_meter, rect.size.y / pixels_per_meter, HIT_ZONE_DEPTH)
	collision.shape = box
	body.add_child(collision)
	hit_zone_root.add_child(body)
	body.hit.connect(_on_zone_hit)


func _get_round_controller() -> RoundController:
	var controllers := get_tree().get_nodes_in_group("round_controller")
	if controllers.is_empty():
		return null
	return controllers[0] as RoundController


func _viewport_to_local(point: Vector2, order := 0) -> Vector3:
	var size_px := Vector2(sub_viewport.size)
	return Vector3(
		(point.x - size_px.x * 0.5) / pixels_per_meter,
		(size_px.y * 0.5 - point.y) / pixels_per_meter,
		HIT_ZONE_DEPTH * 0.5 + order * ZONE_STACK_STEP
	)


## La ventana protegida se tiñe para que se lea de un vistazo cual no vale la
## pena atacar todavia.
func _update_shield_tint() -> void:
	if not is_node_ready() or screen == null:
		return
	var material := (screen.mesh as QuadMesh).material as StandardMaterial3D
	if material != null:
		material.albedo_color = SHIELD_TINT if shielded else Color.WHITE


func _update_screen_size() -> void:
	var quad := screen.mesh as QuadMesh
	if quad == null:
		return
	quad.size = get_window_size()


func _on_zone_hit(body: WindowHitBody3D) -> void:
	if _closed:
		return
	# Protegida no es invulnerable a la vista: el disparo se ve rebotar y se
	# informa, para que el jugador entienda que le falta desactivar algo.
	if shielded:
		var shield_controller := _get_round_controller()
		if shield_controller != null:
			# Se avisa en el registro y no como impacto: el tiro no resolvio
			# nada, asi que no puede sumar al pozo ni a la cadena.
			shield_controller.add_log(tr("LOG_WINDOW_SHIELDED").format({"window": window_label.to_upper()}), "miss")
		blocked.emit(self)
		# El tiro reboto: la zona sigue disponible para cuando caiga el firewall.
		body.rearm()
		return
	if body.zone_id == RAISE_ZONE:
		bring_to_front()
		# La barra sigue disponible: traer al frente se puede repetir.
		body.rearm()
		return
	var controller := _get_round_controller()
	if controller != null and body.scores:
		controller.report_zone_hit(window_label, body.zone_id, body.closes_window)
	zone_hit.emit(body.zone_id, self)
	if body.closes_window:
		close()

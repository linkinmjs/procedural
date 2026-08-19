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

const HIT_ZONE_DEPTH := 0.06
const TARGET_GROUP := "Target"
const TARGET_LAYER := 32
const TARGET_MASK := 16

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
var _closed := false


func _ready() -> void:
	content = _find_content()
	if content == null:
		push_error("WindowPanel3D requires a Control as the first SubViewport child.")
		return
	_update_screen_size()
	await get_tree().process_frame
	rebuild_hit_zones()


## Vuelve a generar los cuerpos disparables a partir del layout actual.
func rebuild_hit_zones() -> void:
	for child in hit_zone_root.get_children():
		child.queue_free()
	for zone in _collect_zones(content):
		_add_hit_body(zone)


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


func _collect_zones(node: Node) -> Array[WindowHitZone]:
	var zones: Array[WindowHitZone] = []
	if node is WindowHitZone:
		zones.append(node)
	for child in node.get_children():
		zones.append_array(_collect_zones(child))
	return zones


func _add_hit_body(zone: WindowHitZone) -> void:
	var rect := zone.get_global_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		push_warning("WindowHitZone '%s' has no size; skipping it." % zone.zone_id)
		return
	var body := WindowHitBody3D.new()
	body.name = zone.name
	body.zone_id = zone.zone_id
	body.closes_window = zone.closes_window
	body.collision_layer = TARGET_LAYER
	body.collision_mask = TARGET_MASK
	body.add_to_group(TARGET_GROUP)
	body.position = _viewport_to_local(rect.get_center())
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


func _viewport_to_local(point: Vector2) -> Vector3:
	var size_px := Vector2(sub_viewport.size)
	return Vector3(
		(point.x - size_px.x * 0.5) / pixels_per_meter,
		(size_px.y * 0.5 - point.y) / pixels_per_meter,
		HIT_ZONE_DEPTH * 0.5
	)


func _update_screen_size() -> void:
	var quad := screen.mesh as QuadMesh
	if quad == null:
		return
	quad.size = get_window_size()


func _on_zone_hit(body: WindowHitBody3D) -> void:
	if _closed:
		return
	var controller := _get_round_controller()
	if controller != null:
		controller.report_target_hit("%s // %s" % [window_label, body.zone_id])
	zone_hit.emit(body.zone_id, self)
	if body.closes_window:
		close()

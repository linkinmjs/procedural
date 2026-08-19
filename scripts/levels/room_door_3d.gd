class_name RoomDoor3D
extends StaticBody3D

## Tapa una abertura de la sala mientras su encuentro esta activo.
##
## Se dibuja como un panel translucido y emisivo, no como pared, para que se lea
## como barrera temporal: la sala se sella al entrar y se abre al limpiarla.
## La geometria se arma por codigo, igual que el resto del nivel.

signal closed_changed(door_closed: bool)

## Capa "World" de project.godot: frena al jugador y tambien a las balas.
const WORLD_LAYER := 1

@export var door_size := Vector3(3.5, 6.0, 0.35)
@export var barrier_color := Color(1.0, 0.28, 0.36, 1.0)
## Metros que el jugador tiene que alejarse del vano para que la puerta cierre
## detras suyo en vez de encima. Se mide sobre el plano del piso.
@export var safe_close_distance := 2.0
## Hacia donde queda el interior de la sala. La puerta solo cierra con el
## jugador de ese lado: si salio al pasillo se queda abierta, para no dejarlo
## encerrado afuera de la sala que tiene que limpiar.
@export var inward_direction := Vector3.ZERO

var is_closed := false

var _mesh_instance: MeshInstance3D
var _collision_shape: CollisionShape3D
var _closing_for: Node3D


func _ready() -> void:
	collision_layer = WORLD_LAYER
	collision_mask = 0
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "DoorMesh"
	var mesh := BoxMesh.new()
	mesh.size = door_size
	mesh.material = _make_material()
	_mesh_instance.mesh = mesh
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh_instance)
	_collision_shape = CollisionShape3D.new()
	_collision_shape.name = "DoorShape"
	var shape := BoxShape3D.new()
	shape.size = door_size
	_collision_shape.shape = shape
	add_child(_collision_shape)
	set_physics_process(false)
	_apply_state()


## Cierra la puerta apenas el cuerpo indicado se aleje del vano. Si ya esta
## lejos cierra en el acto.
func request_close(body: Node3D) -> void:
	if is_closed:
		return
	_closing_for = body
	if _can_close_now():
		close()
		return
	set_physics_process(true)


func close() -> void:
	if is_closed:
		return
	is_closed = true
	_closing_for = null
	set_physics_process(false)
	_apply_state()
	closed_changed.emit(true)


func open() -> void:
	_closing_for = null
	set_physics_process(false)
	if not is_closed:
		return
	is_closed = false
	_apply_state()
	closed_changed.emit(false)


func _physics_process(_delta: float) -> void:
	if _can_close_now():
		close()


func _can_close_now() -> bool:
	if not is_instance_valid(_closing_for):
		return true
	var offset := _closing_for.global_position - global_position
	offset.y = 0.0
	if offset.length() < safe_close_distance:
		return false
	return inward_direction.is_zero_approx() or offset.dot(inward_direction) > 0.0


func _apply_state() -> void:
	_mesh_instance.visible = is_closed
	# Puede llegar desde un callback de fisica (un impacto, un body_entered),
	# donde el estado de las formas no se puede tocar en caliente.
	_collision_shape.set_deferred("disabled", not is_closed)


func _make_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var panel_color := barrier_color
	panel_color.a = 0.42
	material.albedo_color = panel_color
	material.emission_enabled = true
	material.emission = barrier_color.darkened(0.35)
	material.emission_energy_multiplier = 0.7
	return material

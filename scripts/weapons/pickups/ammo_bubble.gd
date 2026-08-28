class_name AmmoBubble
extends StaticBody3D

## Recompensa de municion de una sala: una burbuja que flota en el centro con
## la cantidad escrita adentro. Se toma tocandola o disparandole; entrega solo
## lo que entra en la reserva y, si sobra, se queda con el resto. Al terminar
## el nivel las que quedaron revientan solas, sin entregar nada.
##
## Cumple el contrato de objetivo del template FPS (grupo "Target", capa 32 y
## Hit_Successful), asi que la bala la reconoce como a cualquier ventana. Se
## construye entera por codigo: no hay escena que mantener.

signal collected(bubble: AmmoBubble, taken: int)
signal popped(bubble: AmmoBubble)

const GROUP := "ammo_bubble"
const TARGET_LAYER := 32
const PLAYER_LAYER := 2
const RADIUS := 0.55
const TOUCH_RADIUS := 0.95
## Vaiven vertical y respiracion de la burbuja mientras espera.
const BOB_AMPLITUDE := 0.16
const BOB_HZ := 0.55
const BREATHE := 0.035
const INFLATE_SECONDS := 0.45
const POP_SECONDS := 0.16

@export var amount := 10
@export var tint := Color(0.96, 0.74, 0.35, 1.0)

var _time := randf() * TAU
var _base_y := 0.0
## Factor de inflado (0 recien nacida, 1 a tamaño): lo anima el tween de
## entrada y lo multiplica la respiracion.
var _inflate := 0.0
var _popping := false
var _shell: MeshInstance3D
var _label: Label3D
var _touch: Area3D


func _ready() -> void:
	add_to_group("Target")
	add_to_group(GROUP)
	collision_layer = TARGET_LAYER
	collision_mask = 0
	_base_y = position.y
	_build_body()
	_build_shell()
	_build_label()
	_build_touch()
	_refresh_label()
	_play_inflate()


func _process(delta: float) -> void:
	if _popping:
		return
	_time += delta
	position.y = _base_y + sin(_time * TAU * BOB_HZ) * BOB_AMPLITUDE
	var breathe := 1.0 + sin(_time * TAU * BOB_HZ * 2.0) * BREATHE
	_shell.scale = Vector3.ONE * maxf(breathe * _inflate, 0.001)


## Contrato del template FPS: una bala que la toca la toma.
func Hit_Successful(_damage: float, _direction := Vector3.ZERO, _hit_position := Vector3.ZERO) -> void:
	_collect()


## Revienta sin entregar nada. Es lo que pasa con las que quedaron flotando
## cuando el nivel termina.
func burst() -> void:
	_pop(false)


func _on_touch_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		_collect()


func _collect() -> void:
	if _popping or amount <= 0:
		return
	var manager := _find_weapons_manager()
	if manager == null:
		push_warning("AmmoBubble could not find the player's Weapons_Manager.")
		return
	var slot: WeaponSlot = manager.get("current_weapon_slot")
	if slot == null:
		return
	var remaining: int = manager.add_ammo(slot, amount)
	var taken := amount - remaining
	if taken <= 0:
		# Reserva llena: la burbuja rebota y sigue ahi para mas tarde.
		_wobble()
		return
	amount = remaining
	collected.emit(self, taken)
	if amount > 0:
		_refresh_label()
		_wobble()
		return
	_pop(true)


## El manager cuelga de la camara del jugador. Sin camara (tests, sandboxes)
## se busca por nombre en el arbol.
func _find_weapons_manager() -> Node:
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		var from_camera := camera.get_node_or_null("Weapons_Manager")
		if from_camera != null:
			return from_camera
	return get_tree().root.find_child("Weapons_Manager", true, false)


func _pop(rewarded: bool) -> void:
	if _popping:
		return
	_popping = true
	collision_layer = 0
	_touch.monitoring = false
	remove_from_group("Target")
	_spawn_droplets()
	Sfx.play_at("target_destroyed", global_position, 1.45 if rewarded else 1.15)
	popped.emit(self)
	var tween := create_tween()
	tween.tween_property(_shell, "scale", Vector3.ONE * 1.3, POP_SECONDS * 0.35)
	tween.parallel().tween_property(_label, "modulate:a", 0.0, POP_SECONDS * 0.35)
	tween.tween_property(_shell, "scale", Vector3.ONE * 0.01, POP_SECONDS * 0.65) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


func _wobble() -> void:
	Sfx.play_at("window_button", global_position, 1.3)
	var tween := create_tween()
	tween.tween_property(self, "_inflate", 1.18, 0.06)
	tween.tween_property(self, "_inflate", 1.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _play_inflate() -> void:
	_inflate = 0.0
	var tween := create_tween()
	tween.tween_property(self, "_inflate", 1.0, INFLATE_SECONDS) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _refresh_label() -> void:
	if _label != null:
		_label.text = "+%d" % amount


func _build_body() -> void:
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = RADIUS
	collision.shape = shape
	add_child(collision)


func _build_shell() -> void:
	_shell = MeshInstance3D.new()
	_shell.name = "Shell"
	var mesh := SphereMesh.new()
	mesh.radius = RADIUS
	mesh.height = RADIUS * 2.0
	mesh.radial_segments = 32
	mesh.rings = 16
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(tint.r, tint.g, tint.b, 0.2)
	material.metallic = 0.25
	material.roughness = 0.12
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = 0.45
	material.rim_enabled = true
	material.rim = 1.0
	material.rim_tint = 0.35
	mesh.material = material
	_shell.mesh = mesh
	_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shell.scale = Vector3.ONE * 0.001
	add_child(_shell)


func _build_label() -> void:
	_label = Label3D.new()
	_label.name = "Amount"
	_label.font_size = 96
	_label.outline_size = 14
	_label.modulate = tint
	_label.outline_modulate = Color(0.05, 0.03, 0.0, 0.9)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = false
	_label.render_priority = 1
	add_child(_label)


func _build_touch() -> void:
	_touch = Area3D.new()
	_touch.name = "Touch"
	_touch.collision_layer = 0
	_touch.collision_mask = PLAYER_LAYER
	_touch.monitorable = false
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = TOUCH_RADIUS
	collision.shape = shape
	_touch.add_child(collision)
	_touch.body_entered.connect(_on_touch_body_entered)
	add_child(_touch)


## Gotas del color de la burbuja. Se cuelgan del padre para sobrevivir al
## queue_free; el timer respalda a `finished` en el renderer dummy.
func _spawn_droplets() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var particles := GPUParticles3D.new()
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = RADIUS
	process.spread = 180.0
	process.initial_velocity_min = 1.2
	process.initial_velocity_max = 2.6
	process.gravity = Vector3(0.0, -4.5, 0.0)
	process.scale_min = 0.5
	process.scale_max = 1.0
	particles.process_material = process
	var droplet := SphereMesh.new()
	droplet.radius = 0.04
	droplet.height = 0.08
	droplet.radial_segments = 8
	droplet.rings = 4
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = tint
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = 2.0
	droplet.material = material
	particles.draw_pass_1 = droplet
	particles.amount = 18
	particles.lifetime = 0.6
	particles.one_shot = true
	particles.explosiveness = 1.0
	parent.add_child(particles)
	particles.global_position = global_position
	particles.finished.connect(particles.queue_free)
	particles.get_tree().create_timer(particles.lifetime + 0.5).timeout.connect(func() -> void:
		if is_instance_valid(particles):
			particles.queue_free()
	)
	particles.emitting = true

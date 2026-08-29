class_name AmmoBubble
extends StaticBody3D

## Recompensa de municion de una sala: una burbuja que flota en el centro con
## una bala y la cantidad adentro. Se toma tocandola o disparandole, y si el
## jugador pasa cerca ella misma se le acerca; entrega solo lo que entra en la
## reserva y, si sobra, se queda con el resto avisando por el registro. Al
## terminar el nivel las que quedaron revientan solas, sin entregar nada.
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
const TOUCH_RADIUS := 1.3
## Vaiven vertical y respiracion de la burbuja mientras espera.
const BOB_AMPLITUDE := 0.16
const BOB_HZ := 0.55
const BREATHE := 0.035
const INFLATE_SECONDS := 0.45
const POP_SECONDS := 0.16
## Desde que distancia la burbuja se deja atraer por el jugador y a que
## velocidad maxima se le acerca. Asi pasar al lado alcanza para tomarla.
const MAGNET_RADIUS := 3.2
const MAGNET_SPEED := 4.5
## Giro de la bala sobre su eje, para que se note que es un objeto y no un icono.
const BULLET_SPIN := 1.4
## Cuanto tarda en viajar desde el bloque que cayo hasta su punto de reposo.
## Mientras viaja no se puede tomar: el trayecto es lo que cuenta de donde salio.
const TRAVEL_SECONDS := 0.65
## Cuanto se sostiene inflada antes de reventar al tomarla, para que el pop se
## vea aunque el jugador la tenga encima.
const POP_HOLD_SECONDS := 0.18

@export var amount := 10
@export var tint := Color(0.96, 0.74, 0.35, 1.0)

var _time := randf() * TAU
var _base_y := 0.0
## Factor de inflado (0 recien nacida, 1 a tamaño): lo anima el tween de
## entrada y lo multiplica la respiracion.
var _inflate := 0.0
var _popping := false
var _warned_full := false
## Falso mientras viaja hacia su punto de reposo: ni se toma ni se deja atraer.
var settled := true
var _travel_tween: Tween
var _shell: MeshInstance3D
var _face: Node3D
var _label: Label3D
var _bullet: Node3D
var _touch: Area3D


func _ready() -> void:
	add_to_group("Target")
	add_to_group(GROUP)
	collision_layer = TARGET_LAYER
	collision_mask = 0
	_base_y = position.y
	_build_body()
	_build_shell()
	_build_face()
	_build_touch()
	_refresh_label()
	_play_inflate()


func _process(delta: float) -> void:
	if _popping:
		return
	_time += delta
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		if settled:
			_drift_towards(camera.global_position, delta)
		_face_camera(camera.global_position)
	if settled:
		position.y = _base_y + sin(_time * TAU * BOB_HZ) * BOB_AMPLITUDE
	var breathe := 1.0 + sin(_time * TAU * BOB_HZ * 2.0) * BREATHE
	_shell.scale = Vector3.ONE * maxf(breathe * _inflate, 0.001)
	_face.scale = Vector3.ONE * maxf(_inflate, 0.001)
	_bullet.rotate_object_local(Vector3.UP, BULLET_SPIN * delta)


## Sale del bloque que acaba de caer y viaja hasta donde va a quedarse. Hay que
## llamarlo con la burbuja ya en el arbol. Hasta llegar no se puede tomar.
func travel_from(origin: Vector3, rest: Vector3, duration := TRAVEL_SECONDS) -> void:
	settled = false
	global_position = origin
	_base_y = rest.y
	if _travel_tween != null and _travel_tween.is_valid():
		_travel_tween.kill()
	_travel_tween = create_tween()
	_travel_tween.tween_property(self, "global_position", rest, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_travel_tween.tween_callback(_settle)


func _settle() -> void:
	settled = true
	_time = 0.0
	_base_y = global_position.y


## Contrato del template FPS: una bala que la toca la toma.
func Hit_Successful(_damage: float, _direction := Vector3.ZERO, _hit_position := Vector3.ZERO) -> void:
	_collect()


## Revienta sin entregar nada. Es lo que pasa con las que quedaron flotando
## cuando el nivel termina.
func burst() -> void:
	_pop(false)


func _on_touch_body_entered(body: Node3D) -> void:
	if body is PhysicsBody3D:
		_collect()


func _collect() -> void:
	if _popping or not settled or amount <= 0:
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
		# Reserva llena: la burbuja rebota y sigue ahi para mas tarde, y lo
		# dice una vez para que no parezca rota.
		_warn_reserve_full()
		_wobble()
		return
	amount = remaining
	collected.emit(self, taken)
	var controllers := get_tree().get_nodes_in_group("round_controller")
	if not controllers.is_empty():
		(controllers[0] as RoundController).report_ammo_collected(taken)
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


func _warn_reserve_full() -> void:
	if _warned_full:
		return
	_warned_full = true
	var controllers := get_tree().get_nodes_in_group("round_controller")
	if not controllers.is_empty():
		(controllers[0] as RoundController).add_log(tr("LOG_AMMO_FULL").format({"amount": amount}), "info")


## Cerca del jugador la burbuja se le acerca sola, mas rapido cuanto mas cerca,
## para que alcance con pasar al lado. El jugador se representa por su camara,
## que esta a la altura de la burbuja.
func _drift_towards(target: Vector3, delta: float) -> void:
	var flat_target := Vector3(target.x, position.y, target.z)
	var distance := global_position.distance_to(flat_target)
	if distance > MAGNET_RADIUS or distance < 0.05:
		return
	var pull := 1.0 - distance / MAGNET_RADIUS
	var step := minf(MAGNET_SPEED * pull * delta, distance)
	global_position += (flat_target - global_position).normalized() * step
	_base_y = lerpf(_base_y, target.y - 0.1, minf(delta * 2.0, 1.0))


## La cara (bala y numero) mira siempre al jugador. look_at apunta -Z al
## objetivo, y la etiqueta esta girada para que su frente quede de ese lado.
func _face_camera(camera_position: Vector3) -> void:
	var to_camera := camera_position - _face.global_position
	to_camera.y = 0.0
	if to_camera.length_squared() < 0.0001:
		return
	_face.look_at(_face.global_position + to_camera, Vector3.UP)


func _pop(rewarded: bool) -> void:
	if _popping:
		return
	_popping = true
	collision_layer = 0
	_touch.set_deferred("monitoring", false)
	remove_from_group("Target")
	_spawn_droplets()
	Sfx.play_at("target_destroyed", global_position, 1.45 if rewarded else 1.15)
	popped.emit(self)
	if _travel_tween != null and _travel_tween.is_valid():
		_travel_tween.kill()
	var tween := create_tween()
	tween.tween_property(_shell, "scale", Vector3.ONE * 1.3, POP_SECONDS * 0.35)
	tween.parallel().tween_property(_face, "scale", Vector3.ONE * 0.01, POP_SECONDS * 0.35)
	if rewarded:
		tween.tween_interval(POP_HOLD_SECONDS)
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
		_label.text = "%d" % amount


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


## Lo que se ve adentro: una bala a la izquierda y la cantidad a la derecha,
## sobre un pivote que gira hacia el jugador.
func _build_face() -> void:
	_face = Node3D.new()
	_face.name = "Face"
	add_child(_face)
	_bullet = _build_bullet()
	# El pivote apunta -Z al jugador, asi que su +X queda a la izquierda de quien mira.
	_bullet.position = Vector3(0.3, 0.02, 0.0)
	_face.add_child(_bullet)
	_label = Label3D.new()
	_label.name = "Amount"
	_label.font_size = 88
	_label.outline_size = 14
	_label.modulate = tint
	_label.outline_modulate = Color(0.05, 0.03, 0.0, 0.9)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label.position = Vector3(-0.02, 0.0, 0.0)
	# El frente del Label3D mira a +Z; la cara apunta -Z al jugador.
	_label.rotation.y = PI
	_label.no_depth_test = false
	_label.render_priority = 1
	_face.add_child(_label)


## Cartucho de pistola: vaina de laton con pestaña y punta de cobre, inclinado
## para que se lea como bala y no como un cilindro.
func _build_bullet() -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "Bullet"
	var tilt := Node3D.new()
	# Inclinada hacia afuera, lejos del numero, vista desde -Z.
	tilt.rotation.z = 0.45
	pivot.add_child(tilt)
	var brass := _metal_material(Color(0.88, 0.68, 0.28), 0.32)
	var copper := _metal_material(Color(0.78, 0.44, 0.3), 0.28)
	tilt.add_child(_cylinder("Casing", 0.055, 0.055, 0.22, brass, 0.0))
	tilt.add_child(_cylinder("Rim", 0.062, 0.062, 0.03, brass, -0.115))
	tilt.add_child(_cylinder("Tip", 0.0, 0.052, 0.13, copper, 0.175))
	return pivot


func _cylinder(cylinder_name: String, top: float, bottom: float, height: float, material: Material, y: float) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = cylinder_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 16
	mesh.material = material
	instance.mesh = mesh
	instance.position.y = y
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


func _metal_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.85
	material.roughness = roughness
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.25
	return material


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

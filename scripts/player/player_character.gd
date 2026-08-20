extends CharacterBody3D

## Controlador de movimiento con la sensacion de Counter-Strike 1.6: se corre
## por defecto y sin estamina, la aceleracion y la friccion son las de Quake
## (arranque casi instantaneo y frenada corta) y en el aire se conserva el
## impulso, con el control justo para hacer strafe y encadenar saltos.

@onready var camera = %Camera
@export var subviewport_camera: Camera3D
@export var main_camera:Camera3D
@export var animation_tree: AnimationTree

var camera_rotation: Vector2 = Vector2(0.0,0.0)
var mouse_sensitivity = 0.001
var crouched: bool = false
var crouch_blocked: bool = false

# Retroceso de la vista. recoil_target acumula lo que empujan los disparos y
# recoil_offset es lo que se aplica de verdad, para que la patada entre rapido
# y la vista vuelva sola al punto original (x: yaw, y: pitch, en radianes).
var recoil_target: Vector2 = Vector2.ZERO
var recoil_offset: Vector2 = Vector2.ZERO
var recoil_snappiness: float = 24.0
var recoil_recovery: float = 7.5

@export_category("Crouch Parametres")
@export var enable_crouch: bool = true
@export var crouch_toggle: bool = false
@export var crouch_collision: ShapeCast3D
@export_range(0.0,0.50) var crouch_blend_speed = .2
enum {GROUND_CROUCH = -1, STANDING = 0, AIR_CROUCH = 1}

@export_category("Lean Parametres")
@export var enable_lean: bool = true
@export_range(0.0,1.0) var lean_speed: float = .2
@export var right_lean_collision: ShapeCast3D
@export var left_lean_collision: ShapeCast3D
var lean_tween
enum {LEFT = 1, CENTRE = 0, RIGHT = -1}

@export_category("Speed Parameters")
## Velocidad normal. Es el modo por defecto: aca no hay sprint ni estamina.
@export var run_speed: float = 6.4
## Velocidad con la tecla de caminar, para moverse despacio y apuntar mejor.
@export var walk_speed: float = 3.4
## Velocidad agachado.
@export var crouch_speed: float = 2.3

@export_category("Acceleration Parameters")
## Cuanto empuja el suelo hacia la velocidad deseada (sv_accelerate).
@export var ground_acceleration: float = 10.0
## Frenada del suelo al soltar las teclas (sv_friction).
@export var ground_friction: float = 6.0
## Piso de la frenada: por debajo de esta velocidad la friccion pega igual de
## fuerte, para no quedar patinando eternamente (sv_stopspeed).
@export var stop_speed: float = 3.0
## Empuje disponible en el aire (sv_airaccelerate). Es lo que permite el strafe.
@export var air_acceleration: float = 12.0
## Tope de la velocidad que se puede pedir en el aire cada frame. El valor bajo
## de Quake es justo lo que hace que el strafe gane velocidad al girar.
@export var air_speed_cap: float = 0.8
## Tope duro de la velocidad horizontal en el aire, para que encadenar saltos no
## se descontrole.
@export var max_air_speed: float = 9.6

@export_category("Jump Parameters")
## Altura del salto en metros.
@export var jump_height: float = 1.15
## Gravedad al subir.
@export var jump_gravity: float = 20.5
## La caida usa la gravedad multiplicada por este valor.
@export_range(1.0, 2.0) var fall_gravity_scale: float = 1.1
## Con esto activo, mantener el salto vuelve a saltar apenas se toca el suelo.
@export var auto_bhop: bool = true
## Margen para saltar despues de dejar el borde de una plataforma.
@export var coyote_time: float = 0.1
## Margen para que un salto pedido en el aire salga al aterrizar.
@export var jump_buffer_time: float = 0.15
## Grados que se hunde la vista al aterrizar de una caida fuerte.
@export var landing_dip: float = 1.8
## Velocidad de caida a partir de la cual el aterrizaje empieza a notarse.
@export var landing_dip_min_speed: float = 5.0
## Velocidad de caida que produce el hundimiento completo.
@export var landing_dip_max_speed: float = 14.0

var jump_velocity: float
var _time_since_grounded: float = INF
var _jump_buffer: float = 0.0
var _jumped_this_frame: bool = false

func _ready() -> void:
	update_camera_rotation()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	calculate_movement_parameters()

## Deja camera_rotation en linea con la pose actual. Tiene que ser la inversa
## exacta de apply_view_rotation(), que aplica los dos angulos negados: copiarlos
## con el signo tal cual espejaba la vista en cuanto algo volvia a aplicarla, asi
## que el jugador aparecia mirando hacia donde pedia el nivel y se daba vuelta al
## frame siguiente. El cabeceo vive en la camara, no en el cuerpo.
func update_camera_rotation() -> void:
	camera_rotation.x = -rotation.y
	camera_rotation.y = -camera.rotation.x


## El estado del mouse no se decide aca: lo decide MenuStack segun que menu
## este abierto. Alternarlo desde el jugador producia menus con el mouse
## capturado y partidas con el mouse suelto.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var MouseEvent = event.relative * mouse_sensitivity
		camera_look(MouseEvent)

	if enable_crouch:
		if event.is_action_pressed("crouch"):
			crouch()
		if event.is_action_released("crouch"):
			if !crouch_toggle and crouched:
				crouch()

	if enable_lean:
		if Input.is_action_just_released("lean_left") or Input.is_action_just_released("lean_right"):
			if !(Input.is_action_pressed("lean_right") or Input.is_action_pressed("lean_left")):
				lean(CENTRE)
		if Input.is_action_just_pressed("lean_left"):
			lean(LEFT)
		if Input.is_action_just_pressed("lean_right"):
			lean(RIGHT)

	if event.is_action_pressed("ui_accept"):
		_jump_buffer = jump_buffer_time

func calculate_movement_parameters() -> void:
	jump_velocity = sqrt(2.0 * jump_gravity * jump_height)

func lean(blend_amount: int) -> void:
	if is_on_floor():
		if lean_tween:
			lean_tween.kill()

		lean_tween = get_tree().create_tween()
		lean_tween.tween_property(animation_tree,"parameters/lean_blend/blend_amount", blend_amount, lean_speed)

func lean_collision() -> void:
	animation_tree["parameters/left_collision_blend/blend_amount"] = lerp(
		float(animation_tree["parameters/left_collision_blend/blend_amount"]),float(left_lean_collision.is_colliding()),lean_speed
	)
	animation_tree["parameters/right_collision_blend/blend_amount"] = lerp(
		float(animation_tree["parameters/right_collision_blend/blend_amount"]),float(right_lean_collision.is_colliding()),lean_speed
	)

func crouch() -> void:
	var Blend
	if !crouch_collision.is_colliding():
		if crouched:
			Blend = STANDING
		else:
			if is_on_floor():
				Blend = GROUND_CROUCH
			else:
				Blend = AIR_CROUCH
		var blend_tween = get_tree().create_tween()
		blend_tween.tween_property(animation_tree,"parameters/Crouch_Blend/blend_amount",Blend,crouch_blend_speed)
		crouched = !crouched
	else:
		crouch_blocked = true

func camera_look(Movement: Vector2) -> void:
	camera_rotation += Movement
	camera_rotation.y = clamp(camera_rotation.y,-1.5,1.2)
	apply_view_rotation()

func apply_view_rotation() -> void:
	transform.basis = Basis()
	camera.transform.basis = Basis()

	rotate_object_local(Vector3(0,1,0),-camera_rotation.x) # first rotate in Y
	camera.rotate_object_local(Vector3(0,1,0), recoil_offset.x) # el retroceso lateral no desvia el movimiento
	camera.rotate_object_local(Vector3(1,0,0), -camera_rotation.y + recoil_offset.y) # then rotate in X

## Empuja la vista hacia arriba y hacia un lado. Los angulos llegan en grados.
func add_recoil(pitch_degrees: float, yaw_degrees: float, profile: RecoilProfile = null) -> void:
	if profile:
		recoil_snappiness = profile.kick_snappiness
		recoil_recovery = profile.recovery_speed
	recoil_target += Vector2(deg_to_rad(yaw_degrees), deg_to_rad(pitch_degrees))

func update_recoil(delta: float) -> void:
	if recoil_target.is_zero_approx() and recoil_offset.is_zero_approx():
		return

	recoil_target = recoil_target.lerp(Vector2.ZERO, clampf(recoil_recovery * delta, 0.0, 1.0))
	recoil_offset = recoil_offset.lerp(recoil_target, clampf(recoil_snappiness * delta, 0.0, 1.0))

	if recoil_target.is_zero_approx() and recoil_offset.is_zero_approx():
		recoil_target = Vector2.ZERO
		recoil_offset = Vector2.ZERO

	apply_view_rotation()

func _process(_delta: float) -> void:
	update_recoil(_delta)
	if subviewport_camera:
		subviewport_camera.global_transform = main_camera.global_transform


func _physics_process(delta: float) -> void:
	lean_collision()
	update_crouch_block()
	update_jump_timers(delta)

	var wish_direction := wish_move_direction()
	var target_speed := current_target_speed()
	_jumped_this_frame = consume_jump()

	if is_on_floor() and not _jumped_this_frame:
		apply_friction(delta)
		accelerate(wish_direction, target_speed, ground_acceleration, delta)
	else:
		apply_gravity(delta)
		accelerate(wish_direction, minf(target_speed, air_speed_cap), air_acceleration, delta)
		clamp_air_speed()

	if _jumped_this_frame:
		velocity.y = jump_velocity

	var was_airborne := not is_on_floor()
	var fall_speed := -velocity.y

	move_and_slide()

	if was_airborne and is_on_floor():
		apply_landing_dip(fall_speed)

## Hunde la vista al aterrizar, en proporcion a lo fuerte que fue la caida.
func apply_landing_dip(fall_speed: float) -> void:
	if landing_dip <= 0.0 or fall_speed <= landing_dip_min_speed:
		return

	var weight := clampf(
		(fall_speed - landing_dip_min_speed) / maxf(landing_dip_max_speed - landing_dip_min_speed, 0.001),
		0.0, 1.0
	)
	add_recoil(-landing_dip * weight, 0.0)

## Direccion pedida por el jugador, sobre el plano del suelo.
func wish_move_direction() -> Vector3:
	var input_dir := Input.get_vector("left", "right", "up", "down")
	return (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

func current_target_speed() -> float:
	if crouched:
		return crouch_speed
	if Input.is_action_pressed("walk"):
		return walk_speed
	return run_speed

## Frena la velocidad horizontal como sv_friction: la caida es proporcional a la
## velocidad, pero nunca menor a la que corresponde a stop_speed.
func apply_friction(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed < 0.01:
		velocity.x = 0.0
		velocity.z = 0.0
		return

	var drop := maxf(speed, stop_speed) * ground_friction * delta
	var factor := maxf(speed - drop, 0.0) / speed
	velocity.x *= factor
	velocity.z *= factor

## Aceleracion vectorial de Quake: solo suma lo que falta para llegar a la
## velocidad deseada en la direccion pedida, asi que girar mientras se hace
## strafe en el aire agrega velocidad en lugar de reemplazarla.
func accelerate(wish_direction: Vector3, wish_speed: float, acceleration: float, delta: float) -> void:
	if wish_direction.is_zero_approx() or wish_speed <= 0.0:
		return

	var current_speed := Vector2(velocity.x, velocity.z).dot(Vector2(wish_direction.x, wish_direction.z))
	var add_speed := wish_speed - current_speed
	if add_speed <= 0.0:
		return

	var acceleration_step := minf(acceleration * wish_speed * delta, add_speed)
	velocity.x += wish_direction.x * acceleration_step
	velocity.z += wish_direction.z * acceleration_step

func apply_gravity(delta: float) -> void:
	var gravity := jump_gravity if velocity.y > 0.0 else jump_gravity * fall_gravity_scale
	velocity.y -= gravity * delta

func clamp_air_speed() -> void:
	var planar := Vector2(velocity.x, velocity.z)
	if planar.length() > max_air_speed:
		planar = planar.normalized() * max_air_speed
		velocity.x = planar.x
		velocity.z = planar.y

func update_jump_timers(delta: float) -> void:
	if is_on_floor():
		_time_since_grounded = 0.0
	else:
		_time_since_grounded += delta
	_jump_buffer = maxf(_jump_buffer - delta, 0.0)

## Decide si este frame sale un salto, gastando el buffer y el coyote time.
func consume_jump() -> bool:
	var wants_jump := _jump_buffer > 0.0 or (auto_bhop and Input.is_action_pressed("ui_accept"))
	if not wants_jump:
		return false
	if not is_on_floor() and _time_since_grounded > coyote_time:
		return false

	_jump_buffer = 0.0
	_time_since_grounded = INF
	lean(CENTRE)
	return true

func update_crouch_block() -> void:
	if crouched and crouch_blocked and !crouch_collision.is_colliding():
		crouch_blocked = false
		if !Input.is_action_pressed("crouch") and !crouch_toggle:
			crouch()

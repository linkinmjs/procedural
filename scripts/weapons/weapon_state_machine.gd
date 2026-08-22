extends Node3D

signal weapon_changed
signal update_ammo
signal update_weapon_stack
signal hit_successfull
signal add_signal_to_hud
signal attack_fired
signal target_hit

signal connect_weapon_to_hud
## Dispersion actual del arma expresada en pixeles de viewport. La usa la mira
## para abrirse cuando el jugador dispara o se mueve.
signal spread_changed(spread_pixels: float)
## Cuanto se esta apuntando con la mira, de 0 (cadera) a 1 (ADS completo).
## Lo usan la mira del HUD para desvanecerse y el jugador para frenar el mouse.
signal aim_changed(blend: float)

@export var animation_player: AnimationPlayer
@export var melee_hitbox: ShapeCast3D
@export var max_weapons: int
@export var enable_weapon_spread := true
## Reproductor del sonido de disparo del arma activa.
@export var fire_audio: AudioStreamPlayer3D
## Reproductor de los sonidos de manipulacion (cargador, corredera). Es un
## AudioStreamPlayer comun, sin posicion ni reverb: esos ruidos son del propio
## jugador y tienen que sonar pegados y secos.
@export var reload_audio: AudioStreamPlayer

@export_group("Aim Down Sights")
## Si esta apagado, el click derecho no hace nada.
@export var enable_ads := true
## FOV de la camara mientras se apunta. El FOV base se lee de la camara al
## nacer (75 por defecto), asi que el zoom es la relacion entre ambos.
@export var ads_fov: float = 55.0
## Velocidad del fundido entre cadera y mira (1/s). Mas alto = mas seco.
@export var ads_speed: float = 12.0
## Desplazamiento de todo el rig del arma (este nodo) al apuntar, relativo a la
## camara. La Glock descansa en (0.135, -0.165, -0.42): la x cancela ese
## corrimiento lateral y la y/z suben y acercan la mira al centro de la vista.
@export var ads_offset: Vector3 = Vector3(-0.155, 0.096, 0.1)
## Giro del rig al apuntar, en grados. El yaw cancela los 0.05 rad de escorzo
## de la pose de reposo para que el canion quede paralelo a la vista. Con pitch
## 0 se mira a lo largo de la corredera y el centro de pantalla apoya sobre la
## punta del poste delantero. Un pitch positivo baja la culata y muestra mas
## lomo del arma; como gira alrededor de la camara tambien la sube (~0.0055 de
## ads_offset.y por grado): compensar restando eso.
@export var ads_rotation_degrees: Vector3 = Vector3(0.0, -2.86, 0.0)
@export_group("")

@onready var bullet_point = get_node("%BulletPoint")
@onready var debug_bullet = preload("res://scenes/projectiles/hit_debug.tscn")

var next_weapon: WeaponSlot

# Estado del retroceso dinamico (ver RecoilProfile).
var _burst_shots: int = 0
var _shot_spread: float = 0.0
var _time_since_shot: float = 0.0
var _last_spread_pixels: float = -1.0

# Estado del apuntado (ADS). El rig interpola entre su pose de reposo y
# ads_offset/ads_rotation_degrees; la camara entre su FOV base y ads_fov.
var _camera: Camera3D
var _aim_blend: float = 0.0
var _base_fov: float = 75.0
var _rest_position: Vector3 = Vector3.ZERO
var _rest_rotation_degrees: Vector3 = Vector3.ZERO

#The List of All Available weapons in the game
var spray_profiles: Dictionary = {}
var _count = 0
var shot_tween
@export var weapon_stack:Array[WeaponSlot] #An Array of weapons currently in possesion by the player
var current_weapon_slot: WeaponSlot = null

func _ready() -> void:
	_camera = get_parent() as Camera3D
	if _camera:
		_base_fov = _camera.fov
	_rest_position = position
	_rest_rotation_degrees = rotation_degrees
	if weapon_stack.is_empty():
		push_error("Weapon Stack is empty, please populate with weapons")
	else:
		animation_player.animation_finished.connect(_on_animation_finished)
		for i in weapon_stack:
			initialize(i) #current starts on the first weapon in the stack
		current_weapon_slot = weapon_stack[0]
		if check_valid_weapon_slot():
			enter()
			update_weapon_stack.emit(weapon_stack)
		
func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed():
		return
		
	if range(KEY_1, KEY_4).has(event.keycode):
		var _slot_number = (event.keycode - KEY_1)
		if weapon_stack.size()-1>=_slot_number:
			exit(weapon_stack[_slot_number])
		
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("WeaponUp"):
		if check_valid_weapon_slot():
			var weapon_index = weapon_stack.find(current_weapon_slot)
			weapon_index = min(weapon_index+1,weapon_stack.size()-1)
			exit(weapon_stack[weapon_index])

	if event.is_action_pressed("WeaponDown"):
		if check_valid_weapon_slot():
			var weapon_index = weapon_stack.find(current_weapon_slot)
			weapon_index = max(weapon_index-1,0)
			exit(weapon_stack[weapon_index])
		
	if event.is_action_pressed("Shoot"):
		if check_valid_weapon_slot():
			shoot()
	
	if event.is_action_released("Shoot"):
		if check_valid_weapon_slot():
			shot_count_update()
	
	if event.is_action_pressed("Reload"):
		if check_valid_weapon_slot():
			reload()
		
	if event.is_action_pressed("Drop_Weapon"):
		if check_valid_weapon_slot():
			drop(current_weapon_slot)
		
	if event.is_action_pressed("Melee"):
		if check_valid_weapon_slot():
			melee()

func _process(delta: float) -> void:
	_time_since_shot += delta

	var profile := _recoil_profile()
	if profile:
		if _time_since_shot >= profile.shot_reset_time:
			_burst_shots = 0
		_shot_spread = maxf(_shot_spread - profile.spread_recovery * delta, 0.0)

	_update_aim(delta)

	var pixels := _spread_to_pixels(_current_spread_degrees())
	if not is_equal_approx(pixels, _last_spread_pixels):
		_last_spread_pixels = pixels
		spread_changed.emit(pixels)

## Cuanto se esta apuntando ahora mismo, de 0 a 1.
func aim_blend() -> float:
	return _aim_blend

## Se apunta mientras se mantiene Secondary_Fire (click derecho). Se consulta
## el estado de la accion por frame en vez de escuchar pressed/released: si el
## boton se suelta con la pausa abierta el released nunca llega y el jugador
## quedaria apuntando para siempre.
func _update_aim(delta: float) -> void:
	var wants_aim := enable_ads and Input.is_action_pressed("Secondary_Fire") \
		and current_weapon_slot != null and current_weapon_slot.weapon != null
	var target := 1.0 if wants_aim else 0.0
	if _aim_blend == target:
		return
	var blend := lerpf(_aim_blend, target, clampf(ads_speed * delta, 0.0, 1.0))
	# El lerp es asintotico: cerca del objetivo se encaja para dejar de
	# escribir FOV y transform cada frame.
	if absf(blend - target) < 0.001:
		blend = target
	_apply_aim(blend)

func _apply_aim(blend: float) -> void:
	_aim_blend = blend
	position = _rest_position.lerp(ads_offset, blend)
	rotation_degrees = _rest_rotation_degrees.lerp(ads_rotation_degrees, blend)
	if _camera:
		_camera.fov = lerpf(_base_fov, ads_fov, blend)
	aim_changed.emit(blend)

func check_valid_weapon_slot()->bool:
	if current_weapon_slot:
		if current_weapon_slot.weapon:
			return true
		else:
			push_warning("No Weapon Resource active on the weapon controler.")
	else:
		push_warning("No Current Weapon slot active on the weapon controler.")
	return false

func initialize(_weapon_slot: WeaponSlot):
	if !_weapon_slot or !_weapon_slot.weapon:
		return
	if _weapon_slot.weapon.weapon_spray:
		spray_profiles[_weapon_slot.weapon.weapon_name] = _weapon_slot.weapon.weapon_spray.instantiate()
	connect_weapon_to_hud.emit(_weapon_slot.weapon)

func enter() -> void:
	animation_player.queue(current_weapon_slot.weapon.pick_up_animation)
	weapon_changed.emit(current_weapon_slot.weapon.weapon_name)
	update_ammo.emit([current_weapon_slot.current_ammo, current_weapon_slot.reserve_ammo])

func exit(_next_weapon: WeaponSlot) -> void:
	if _next_weapon != current_weapon_slot:
		if animation_player.get_current_animation() != current_weapon_slot.weapon.change_animation:
			animation_player.queue(current_weapon_slot.weapon.change_animation)
			next_weapon = _next_weapon

func change_weapon(weapon_slot: WeaponSlot) -> void:
	current_weapon_slot = weapon_slot
	next_weapon = null
	enter()
	
func shot_count_update() -> void:
	shot_tween = get_tree().create_tween()
	shot_tween.tween_property(self,"_count",0,1)
	
func shoot() -> void:
	if current_weapon_slot.current_ammo != 0 or not current_weapon_slot.weapon.has_ammo:
		if current_weapon_slot.weapon.incremental_reload and animation_player.current_animation == current_weapon_slot.weapon.reload_animation:
			animation_player.stop()
			
		if not animation_player.is_playing():
			animation_player.play(current_weapon_slot.weapon.shoot_animation)
			if current_weapon_slot.weapon.has_ammo:
				current_weapon_slot.current_ammo -= 1
				
			update_ammo.emit([current_weapon_slot.current_ammo, current_weapon_slot.reserve_ammo])
			
			if shot_tween:
				shot_tween.kill()
			
			var Spread = Vector2.ZERO
			
			if enable_weapon_spread and current_weapon_slot.weapon.weapon_spray:
				_count = _count + 1
				Spread = spray_profiles[current_weapon_slot.weapon.weapon_name].Get_Spray(_count, current_weapon_slot.weapon.magazine)
			
			Spread += _dynamic_spread_offset()
			_apply_shot_recoil()
			_play_weapon_sound(current_weapon_slot.weapon.fire_sound)
			
			load_projectile(Spread)
	else:
		_play_weapon_sound(current_weapon_slot.weapon.empty_sound)
		reload()

## Dispersion del disparo actual, en pixeles de viewport y en una direccion
## aleatoria dentro del circulo de imprecision.
func _dynamic_spread_offset() -> Vector2:
	var profile := _recoil_profile()
	if profile == null:
		return Vector2.ZERO
	
	var radius := _spread_to_pixels(_current_spread_degrees())
	
	_burst_shots += 1
	_time_since_shot = 0.0
	_shot_spread = minf(_shot_spread + profile.spread_per_shot, profile.max_shot_spread)
	
	if radius <= 0.0:
		return Vector2.ZERO
	
	# sqrt() reparte los impactos de forma uniforme dentro del circulo.
	return Vector2.RIGHT.rotated(randf() * TAU) * radius * sqrt(randf())

## Patada de camara del disparo actual. Crece con la rafaga y siempre empuja la
## vista hacia arriba, como en Counter-Strike 1.6.
func _apply_shot_recoil() -> void:
	var profile := _recoil_profile()
	if profile == null or owner == null or not owner.has_method("add_recoil"):
		return
	
	# _burst_shots ya cuenta este disparo: el primero usa el retroceso base.
	var burst := float(maxi(_burst_shots - 1, 0))
	var pitch := minf(profile.vertical_kick + profile.vertical_kick_growth * burst, profile.max_vertical_kick)
	var yaw := minf(profile.horizontal_kick + profile.horizontal_kick_growth * burst, profile.max_horizontal_kick)
	
	owner.add_recoil(pitch, yaw * randf_range(-1.0, 1.0), profile)

## El reproductor del arma puede ser un SpatialAudio3D (reverb y oclusion
## calculados desde la sala): ese expone do_play()/do_set_stream() y no hay
## que llamar a play() directo, que saltearia sus reflejos.
func _play_weapon_sound(stream: AudioStream) -> void:
	if stream == null or fire_audio == null:
		return
	var spatial := fire_audio.has_method("do_play")
	if fire_audio.stream != stream:
		fire_audio.stream = stream
		if spatial:
			fire_audio.call("do_set_stream", stream)
	# Via call(): la variable esta tipada como AudioStreamPlayer3D y el analizador
	# no conoce los metodos del plugin.
	if spatial:
		fire_audio.call("do_play")
	else:
		fire_audio.play()

## Lo llama la animacion de recarga por method track, con el nombre de la
## etapa: "unload" (sale el cargador), "load" (entra el nuevo) o "recharge"
## (la corredera carga la recamara). El arma decide que stream corresponde.
func play_handling_sound(stage: String) -> void:
	if reload_audio == null or current_weapon_slot == null or current_weapon_slot.weapon == null:
		return
	var weapon := current_weapon_slot.weapon
	var stream: AudioStream = null
	match stage:
		"unload":
			stream = weapon.unload_sound
		"load":
			stream = weapon.load_sound
		"recharge":
			stream = weapon.recharge_sound
	if stream == null:
		return
	reload_audio.stream = stream
	reload_audio.pitch_scale = randf_range(0.97, 1.03)
	reload_audio.play()


func _recoil_profile() -> RecoilProfile:
	if current_weapon_slot and current_weapon_slot.weapon:
		return current_weapon_slot.weapon.recoil
	return null

## Imprecision total en grados: disparos recientes, movimiento, salto y postura.
func _current_spread_degrees() -> float:
	var profile := _recoil_profile()
	if profile == null:
		return 0.0
	
	var spread := profile.base_spread + _shot_spread
	var body := owner as CharacterBody3D
	
	if body:
		var declared_speed: Variant = body.get("run_speed")
		var reference_speed: float = maxf(float(declared_speed), 0.001) if declared_speed != null else 6.4
		var planar_speed := Vector2(body.velocity.x, body.velocity.z).length()
		spread += profile.move_spread * clampf(planar_speed / reference_speed, 0.0, 1.0)
		
		if not body.is_on_floor():
			spread += profile.air_spread
		elif body.get("crouched") == true:
			spread *= profile.crouch_multiplier
	
	spread *= lerpf(1.0, profile.ads_multiplier, _aim_blend)
	
	return minf(spread, profile.max_spread)

## Convierte un angulo de dispersion a pixeles sobre el plano de proyeccion.
func _spread_to_pixels(spread_degrees: float) -> float:
	if spread_degrees <= 0.0:
		return 0.0
	
	if _camera == null:
		return 0.0
	
	var viewport_height: float = _camera.get_viewport().get_visible_rect().size.y
	var pixels_per_radian := (viewport_height * 0.5) / tan(deg_to_rad(_camera.fov) * 0.5)
	return tan(deg_to_rad(spread_degrees)) * pixels_per_radian
		
func load_projectile(_spread):
	var _projectile:Projectile = current_weapon_slot.weapon.projectile_to_load.instantiate()
	_projectile.aim_camera = _camera
	
	_projectile.position = bullet_point.global_position
	_projectile.rotation = owner.rotation
	
	bullet_point.add_child(_projectile)
	add_signal_to_hud.emit(_projectile)
	if _projectile.has_signal("Hit_Successfull"):
		_projectile.Hit_Successfull.connect(_on_projectile_target_hit)
	attack_fired.emit()
	var bullet_point_origin = bullet_point.global_position
	_projectile._Set_Projectile(current_weapon_slot.weapon.damage,_spread,current_weapon_slot.weapon.fire_range, bullet_point_origin)

func reload() -> void:
	if current_weapon_slot.current_ammo == current_weapon_slot.weapon.magazine:
		return
	elif not animation_player.is_playing():
		if current_weapon_slot.reserve_ammo != 0:
			animation_player.queue(current_weapon_slot.weapon.reload_animation)
		else:
			animation_player.queue(current_weapon_slot.weapon.out_of_ammo_animation)

func calculate_reload() -> void:
	if current_weapon_slot.current_ammo == current_weapon_slot.weapon.magazine:
		var anim_legnth = animation_player.get_current_animation_length()
		animation_player.advance(anim_legnth)
		return
		
	var Mag_Amount = current_weapon_slot.weapon.magazine
	
	if current_weapon_slot.weapon.incremental_reload:
		Mag_Amount = current_weapon_slot.current_ammo+1
		
	var Reload_Amount = min(Mag_Amount-current_weapon_slot.current_ammo,Mag_Amount,current_weapon_slot.reserve_ammo)

	current_weapon_slot.current_ammo = current_weapon_slot.current_ammo+Reload_Amount
	current_weapon_slot.reserve_ammo = current_weapon_slot.reserve_ammo-Reload_Amount
	
	update_ammo.emit([current_weapon_slot.current_ammo, current_weapon_slot.reserve_ammo])
	shot_count_update()
	_burst_shots = 0
	_shot_spread = 0.0

func melee() -> void:
	var Current_Anim = animation_player.get_current_animation()
	
	if Current_Anim == current_weapon_slot.weapon.shoot_animation:
		return
		
	if Current_Anim != current_weapon_slot.weapon.melee_animation:
		animation_player.play(current_weapon_slot.weapon.melee_animation)
		attack_fired.emit()
		if melee_hitbox.is_colliding():
			var colliders = melee_hitbox.get_collision_count()
			for c in colliders:
				var Target = melee_hitbox.get_collider(c)
				if Target.is_in_group("Target") and Target.has_method("Hit_Successful"):
					hit_successfull.emit()
					target_hit.emit()
					var Direction = (Target.global_transform.origin - owner.global_transform.origin).normalized()
					var Position =  melee_hitbox.get_collision_point(c)
					Target.Hit_Successful(current_weapon_slot.weapon.melee_damage, Direction, Position)


func _on_projectile_target_hit() -> void:
	target_hit.emit()
			
func drop(_slot: WeaponSlot) -> void:
	if _slot.weapon.can_be_dropped and weapon_stack.size() != 1:
		var weapon_index = weapon_stack.find(_slot,0)
		if weapon_index != -1:
			weapon_stack.pop_at(weapon_index)
			update_weapon_stack.emit(weapon_stack)

			if _slot.weapon.weapon_drop:
				var weapon_dropped = _slot.weapon.weapon_drop.instantiate()
				weapon_dropped.weapon = _slot
				weapon_dropped.set_global_transform(bullet_point.get_global_transform())
				get_tree().get_root().add_child(weapon_dropped)
				
				animation_player.play(current_weapon_slot.weapon.drop_animation)
				weapon_index  = max(weapon_index-1,0)
				exit(weapon_stack[weapon_index])
	else:
		return
		
func _on_animation_finished(anim_name):
	if anim_name == current_weapon_slot.weapon.shoot_animation:
		if current_weapon_slot.weapon.auto_fire == true:
				if Input.is_action_pressed("Shoot"):
					shoot()

	if anim_name == current_weapon_slot.weapon.change_animation:
		change_weapon(next_weapon)
	
	if anim_name == current_weapon_slot.weapon.reload_animation:
		if !current_weapon_slot.weapon.incremental_reload:
			calculate_reload()

func _on_pick_up_detection_body_entered(body: RigidBody3D):
	var weapon_slot = body.weapon
	for slot in weapon_stack:
		if slot.weapon == weapon_slot.weapon:
			var remaining

			remaining = add_ammo(slot, weapon_slot.current_ammo+weapon_slot.reserve_ammo)
			weapon_slot.current_ammo = min(remaining, slot.weapon.magazine)
			weapon_slot.reserve_ammo = max(remaining - weapon_slot.current_ammo,0)

			if remaining == 0:
				body.queue_free()
			return
		
	if body.TYPE == "Weapon":
		if weapon_stack.size() == max_weapons:
				return
				
		if body.Pick_Up_Ready == true:
			var weapon_index = weapon_stack.find(current_weapon_slot)
			weapon_stack.insert(weapon_index,weapon_slot)
			update_weapon_stack.emit(weapon_stack)
			exit(weapon_slot)
			initialize(weapon_slot)
			body.queue_free()

func add_ammo(_weapon_slot: WeaponSlot, ammo: int)->int:
	var weapon = _weapon_slot.weapon
	var required = weapon.max_ammo - _weapon_slot.reserve_ammo
	var remaining = max(ammo - required,0)
	_weapon_slot.reserve_ammo += min(ammo, required)
	update_ammo.emit([current_weapon_slot.current_ammo, current_weapon_slot.reserve_ammo])
	return remaining

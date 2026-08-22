extends CanvasLayer

@onready var spread_sight: DynamicCrosshair = $SpreadSight
@onready var main_sight: TextureRect = $MainSight
@onready var current_weapon_label = $debug_hud/HBoxContainer/CurrentWeapon
@onready var current_ammo_label = $debug_hud/HBoxContainer2/CurrentAmmo
@onready var current_weapon_stack = $debug_hud/HBoxContainer3/WeaponStack
@onready var hit_sight = $HitSight
@onready var hit_sight_timer = $HitSight/HitSightTimer
@onready var overLay = $Overlay

var _hit_tween: Tween
var _damage_tween: Tween
var _damage_texture: GradientTexture2D


func _ready() -> void:
	_bind_round_controller.call_deferred()


## El flash de danio se engancha al RoundController por grupo, igual que los
## HUD de ronda: el controlador vive en el nivel, no en el jugador.
func _bind_round_controller() -> void:
	for node in get_tree().get_nodes_in_group("round_controller"):
		if is_instance_valid(node):
			node.damage_taken.connect(_on_damage_taken)
			return


func _on_weapons_manager_spread_changed(spread_pixels: float) -> void:
	spread_sight.set_spread(spread_pixels)


## Al apuntar la mira se apunta con el arma, no con el HUD: las dos cruces se
## funden. Se baja el alfa y no la visibilidad para que sigan en su lugar.
func _on_weapons_manager_aim_changed(blend: float) -> void:
	var alpha := 1.0 - blend
	main_sight.modulate.a = alpha
	spread_sight.modulate.a = alpha


func _on_weapons_manager_update_weapon_stack(WeaponStack):
	current_weapon_stack.text = ""
	for i in WeaponStack:
		current_weapon_stack.text += "\n"+i.weapon.weapon_name

func _on_weapons_manager_update_ammo(Ammo):
	current_ammo_label.set_text(str(Ammo[0])+" / "+str(Ammo[1]))

func _on_weapons_manager_weapon_changed(WeaponName):
	current_weapon_label.set_text(WeaponName)

func _on_hit_sight_timer_timeout():
	hit_sight.set_visible(false)

func _on_weapons_manager_add_signal_to_hud(_projectile):
	_projectile.Hit_Successfull.connect(_on_weapons_manager_hit_successfull)

## Hitmarker con cuerpo: entra grande, asienta y se funde. El timer de 0.05 s
## anterior era un parpadeo que no llegaba a leerse.
func _on_weapons_manager_hit_successfull():
	Sfx.play("hitmarker", randf_range(0.96, 1.05))
	if _hit_tween != null:
		_hit_tween.kill()
	hit_sight.visible = true
	hit_sight.pivot_offset = hit_sight.size * 0.5
	hit_sight.scale = Vector2.ONE * 1.6
	hit_sight.modulate = Color.WHITE
	_hit_tween = create_tween()
	_hit_tween.tween_property(hit_sight, "scale", Vector2.ONE, 0.07) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hit_tween.tween_property(hit_sight, "modulate:a", 0.0, 0.18)
	_hit_tween.tween_callback(func() -> void: hit_sight.visible = false)


## Vignette roja al recibir danio, sobre el Overlay que el template dejo
## cableado a una senial muerta. La textura es un gradiente radial generado
## aca: transparente al centro, rojo en los bordes.
func _on_damage_taken(_amount: float) -> void:
	Sfx.play("player_hurt")
	var player := get_parent()
	if player != null and player.has_method("add_trauma"):
		player.add_trauma(0.65)
	if _damage_texture == null:
		_damage_texture = _build_damage_texture()
	# La escena trae el Overlay en keep-aspect-centered, que dibuja la textura
	# como una columna centrada: la vignette tiene que estirarse a la pantalla.
	overLay.stretch_mode = TextureRect.STRETCH_SCALE
	overLay.texture = _damage_texture
	overLay.visible = true
	if _damage_tween != null:
		_damage_tween.kill()
	overLay.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_damage_tween = create_tween()
	_damage_tween.tween_property(overLay, "modulate:a", 0.0, 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _build_damage_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.45, 0.8, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.8, 0.05, 0.05, 0.0),
		Color(0.8, 0.05, 0.05, 0.35),
		Color(0.7, 0.02, 0.02, 0.75),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 256
	texture.height = 256
	return texture


func load_over_lay_texture(Active:bool, txtr: Texture2D = null):
		if _damage_tween != null:
			_damage_tween.kill()
		overLay.modulate = Color.WHITE
		overLay.set_texture(txtr)
		overLay.set_visible(Active)

func _on_weapons_manager_connect_weapon_to_hud(_weapon_resouce: WeaponResource):
	_weapon_resouce.update_overlay.connect(load_over_lay_texture)

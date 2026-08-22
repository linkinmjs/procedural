class_name TargetBall
extends StaticBody3D

signal destroyed(target: TargetBall)
signal left(target: TargetBall)

@export var target_label := "cyan ball"
@export_range(0.0, 120.0, 0.1) var lifetime_seconds := 0.0
@export_range(0.0, 100.0, 1.0) var damage_on_leave := 0.0
@export var display_color := Color(0.08, 0.78, 1.0, 1.0)

var _resolved := false
var use_custom_display_color := false


func _ready() -> void:
	if use_custom_display_color:
		_apply_display_color()
	if lifetime_seconds > 0.0:
		get_tree().create_timer(lifetime_seconds, false).timeout.connect(_on_lifetime_expired)


func Hit_Successful(_damage: float, _direction := Vector3.ZERO, _hit_position := Vector3.ZERO) -> void:
	if _resolved:
		return
	_resolved = true
	var round_controller := _get_round_controller()
	if round_controller != null:
		round_controller.report_ball_destroyed(target_label)
	destroyed.emit(self)
	_play_destruction()


## Pop de muerte: se infla un instante, colapsa y suelta esquirlas del color de
## la bola. La colision se apaga primero para que la bola muriendo no coma tiros.
func _play_destruction() -> void:
	collision_layer = 0
	_spawn_burst()
	Sfx.play_at("target_destroyed", global_position, randf_range(0.95, 1.1))
	var mesh_instance := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_instance == null:
		queue_free()
		return
	var tween := create_tween()
	tween.tween_property(mesh_instance, "scale", Vector3.ONE * 1.22, 0.05)
	tween.tween_property(mesh_instance, "scale", Vector3.ONE * 0.01, 0.11) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


## Las esquirlas se cuelgan del padre: tienen que sobrevivir al queue_free de
## la bola. Se construyen por codigo para heredar el color de cualquier variante.
func _spawn_burst() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var color := display_color if use_custom_display_color else Color(0.08, 0.78, 1.0)
	var particles := GPUParticles3D.new()
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.28
	process.spread = 180.0
	process.initial_velocity_min = 1.6
	process.initial_velocity_max = 3.2
	process.gravity = Vector3(0.0, -6.0, 0.0)
	process.scale_min = 0.4
	process.scale_max = 1.0
	particles.process_material = process
	var shard := BoxMesh.new()
	shard.size = Vector3(0.05, 0.05, 0.05)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.2
	shard.material = material
	particles.draw_pass_1 = shard
	particles.amount = 14
	particles.lifetime = 0.55
	particles.one_shot = true
	particles.explosiveness = 1.0
	parent.add_child(particles)
	particles.global_position = global_position
	# `finished` limpia en el juego real; el timer es el respaldo para el
	# renderer dummy (headless), donde las particulas no procesan y la senial
	# no llega nunca.
	particles.finished.connect(particles.queue_free)
	particles.get_tree().create_timer(particles.lifetime + 0.5).timeout.connect(func() -> void:
		if is_instance_valid(particles):
			particles.queue_free()
	)
	particles.emitting = true


func _on_lifetime_expired() -> void:
	if _resolved:
		return
	_resolved = true
	var round_controller := _get_round_controller()
	if round_controller != null:
		round_controller.report_target_left(target_label, damage_on_leave)
	left.emit(self)
	queue_free()


func _get_round_controller() -> RoundController:
	var controllers := get_tree().get_nodes_in_group("round_controller")
	if controllers.is_empty():
		return null
	return controllers[0] as RoundController


func _apply_display_color() -> void:
	var mesh_instance := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_instance == null or mesh_instance.mesh == null:
		return
	var colored_mesh := mesh_instance.mesh.duplicate() as PrimitiveMesh
	if colored_mesh == null or not colored_mesh.material is StandardMaterial3D:
		return
	var colored_material := colored_mesh.material.duplicate() as StandardMaterial3D
	colored_material.albedo_color = display_color
	colored_material.emission = display_color.darkened(0.58)
	colored_mesh.material = colored_material
	mesh_instance.mesh = colored_mesh

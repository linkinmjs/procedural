class_name BulletImpact
extends Node3D

## Marca de impacto de bala: decal orientado a la normal + chispas + sonido.
##
## Reemplaza al sprite de debug del template. Contra un objetivo no deja decal
## (el objetivo muere y la marca quedaria flotando): solo chispas.

## Cuanto vive la marca en la pared antes de desvanecerse.
@export_range(1.0, 30.0, 0.5) var decal_lifetime: float = 8.0
## Ultimo tramo del decal, en segundos, durante el que se funde a nada.
@export_range(0.1, 5.0, 0.1) var decal_fade: float = 1.5

@onready var decal: Decal = $Decal
@onready var sparks: GPUParticles3D = $Sparks


## Ubica y orienta la marca. El eje Y local queda alineado con la normal, que
## es hacia donde proyecta el Decal y hacia donde saltan las chispas.
func place(hit_position: Vector3, normal: Vector3, with_decal := true) -> void:
	var up := normal.normalized()
	if up.is_zero_approx():
		up = Vector3.UP
	var x_axis := up.cross(Vector3.UP)
	if x_axis.length_squared() < 0.001:
		x_axis = up.cross(Vector3.FORWARD)
	x_axis = x_axis.normalized()
	var z_axis := x_axis.cross(up)
	global_transform = Transform3D(Basis(x_axis, up, z_axis), hit_position + up * 0.01)

	decal.visible = with_decal
	sparks.emitting = true
	# El sample base es un paso sobre piedra: agudizado suena a esquirla seca.
	Sfx.play_at("impact_wall", hit_position, randf_range(1.45, 1.75))

	var lifetime := decal_lifetime if with_decal else 1.0
	if with_decal:
		var tween := create_tween()
		tween.tween_interval(lifetime - decal_fade)
		tween.tween_property(decal, "modulate:a", 0.0, decal_fade)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

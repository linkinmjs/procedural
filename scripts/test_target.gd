extends StaticBody3D

@export var max_health := 100.0
@export var reset_delay := 1.5

@onready var health_label: Label3D = $HealthLabel

var health: float


func _ready() -> void:
	health = max_health
	_update_label()


func Hit_Successful(damage: float, _direction := Vector3.ZERO, _position := Vector3.ZERO) -> void:
	health = maxf(health - damage, 0.0)
	_update_label()
	if is_zero_approx(health):
		$CollisionShape3D.set_deferred("disabled", true)
		$MeshInstance3D.visible = false
		await get_tree().create_timer(reset_delay).timeout
		health = max_health
		$CollisionShape3D.disabled = false
		$MeshInstance3D.visible = true
		_update_label()


func _update_label() -> void:
	health_label.text = "%d / %d" % [health, max_health]

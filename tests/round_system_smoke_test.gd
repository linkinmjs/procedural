extends SceneTree

const PENALTY_TARGET_SCENE := preload("res://scenes/targets/blue_penalty_ball.tscn")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var controller := RoundController.new()
	controller.auto_start = false
	controller.max_health = 100.0
	controller.round_duration = 30.0
	root.add_child(controller)
	controller.start_round()
	controller.report_attack_fired()
	controller.report_attack_fired()
	controller.report_attack_hit()
	if not is_equal_approx(controller.get_accuracy_percent(), 50.0):
		_fail("Expected 50 percent accuracy.")
		return
	controller.report_target_left("blue ball", 15.0)
	if not is_equal_approx(controller.current_health, 85.0):
		_fail("A missed penalty target should remove 15 HP.")
		return
	var penalty_target := PENALTY_TARGET_SCENE.instantiate() as TargetBall
	penalty_target.lifetime_seconds = 0.02
	root.add_child(penalty_target)
	await create_timer(0.05).timeout
	if not is_equal_approx(controller.current_health, 70.0):
		_fail("An expired penalty target should report its damage to the round controller.")
		return
	controller.report_target_hit("blue ball")
	print("Round system smoke test passed.")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)

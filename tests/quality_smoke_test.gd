extends SceneTree

## El perfil de calidad decide sombras y escala del render por plataforma, y
## las pruebas pueden forzarlo. Fuera de la Web el perfil es el alto.


func _initialize() -> void:
	if OS.has_feature("web"):
		_fail("This smoke test does not run on the web build.")
		return
	if Quality.profile() != Quality.Profile.HIGH or not Quality.shadows_enabled() or not is_equal_approx(Quality.render_scale(), 1.0):
		_fail("Desktop should default to the high profile: shadows on, full render scale.")
		return
	var sun := DirectionalLight3D.new()
	root.add_child(sun)
	Quality.override_profile = Quality.Profile.MEDIUM
	if Quality.shadows_enabled() or Quality.render_scale() >= 1.0:
		_fail("The medium profile should drop shadows and render below full scale.")
		return
	Quality.apply_to_sun(sun)
	if sun.shadow_enabled or sun.directional_shadow_mode != DirectionalLight3D.SHADOW_ORTHOGONAL:
		_fail("Applying the medium profile should disable the sun shadow and keep a single orthogonal split.")
		return
	Quality.apply_to_viewport(root)
	if not is_equal_approx(root.scaling_3d_scale, Quality.MEDIUM_RENDER_SCALE):
		_fail("Applying the medium profile should scale the 3D render down.")
		return
	Quality.override_profile = Quality.Profile.HIGH
	Quality.apply_to_sun(sun)
	Quality.apply_to_viewport(root)
	if not sun.shadow_enabled or not is_equal_approx(root.scaling_3d_scale, 1.0) or not is_equal_approx(sun.directional_shadow_max_distance, Quality.DIRECTIONAL_SHADOW_DISTANCE):
		_fail("The high profile should restore shadows at full scale, bounded to the level size.")
		return
	Quality.override_profile = -1
	print("Quality smoke test passed.")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)

extends SceneTree

## El SubViewport de cada ventana se dibuja una sola vez y queda quieto: con
## veinte ventanas vivas, redibujarlas todas cada frame era el mayor gasto de
## GPU en la build Web. Quien cambia el contenido pide el redibujo, y un pedido
## con duracion lo mantiene vivo lo que dure la animacion y despues lo apaga.


func _initialize() -> void:
	create_timer(15.0, true, false, true).timeout.connect(func() -> void: _fail("Window viewport mode smoke test timed out."))
	_run.call_deferred()


func _run() -> void:
	var scenes: Array[PackedScene] = []
	for family in WindowCatalog.BASE_SCENES:
		for scene in WindowCatalog.BASE_SCENES[family].values():
			scenes.append(scene)
	scenes.append(preload("res://scenes/targets/blue_screen.tscn"))
	if scenes.size() < 5:
		_fail("The window catalog should list several scenes.")
		return
	for scene in scenes:
		var instance := scene.instantiate()
		var viewport := instance.find_child("SubViewport", true, false) as SubViewport
		if viewport == null:
			instance.free()
			continue
		if viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS:
			_fail("%s should not redraw its screen every frame." % scene.resource_path)
			return
		instance.free()

	var window := WindowCatalog.BASE_SCENES["normal"].values()[0].instantiate() as WindowPanel3D
	root.add_child(window)
	await process_frame
	await process_frame
	if window.sub_viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS:
		_fail("A living window should sit still once drawn.")
		return
	window.request_screen_redraw()
	if window.sub_viewport.render_target_update_mode != SubViewport.UPDATE_ONCE:
		_fail("Requesting a redraw should draw the screen once more.")
		return
	window.request_screen_redraw(0.2)
	if window.sub_viewport.render_target_update_mode != SubViewport.UPDATE_ALWAYS:
		_fail("A timed redraw should keep the screen live while it lasts.")
		return
	await create_timer(0.45, true, false, true).timeout
	if window.sub_viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS:
		print("Window viewport mode smoke test passed.")
		quit()
		return
	_fail("A timed redraw should switch the screen off again when it ends.")


func _fail(message: String) -> void:
	push_error(message)
	quit(1)

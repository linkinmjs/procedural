extends SceneTree

const WINDOW_SCENE := preload("res://scenes/windows/shutdown_window.tscn")
const CLOSE_WINDOW_SCENE := preload("res://scenes/windows/close_window.tscn")
const DOWNLOAD_WINDOW_SCENE := preload("res://scenes/windows/download_window.tscn")
const TEMPLATE_SCENES: Array[String] = [
	"res://scenes/windows/templates/xp_window_template.tscn",
	"res://scenes/windows/templates/retro_window_template.tscn",
]


func _initialize() -> void:
	create_timer(6.0).timeout.connect(func() -> void: _fail("Window panel smoke test timed out."))
	_run.call_deferred()


func _run() -> void:
	var window := WINDOW_SCENE.instantiate() as WindowPanel3D
	root.add_child(window)
	await process_frame
	await process_frame
	var bodies := window.get_hit_bodies()
	# Dos controles mas la barra de titulo, que desde ahora tambien es zona: sirve
	# para traer la ventana al frente.
	if bodies.size() != 3:
		_fail("The shutdown window should build one hit body per zone, got %d." % bodies.size())
		return
	var zone_ids: Array[String] = []
	for hit_body in bodies:
		if not hit_body.is_in_group("Target") or not hit_body.has_method("Hit_Successful"):
			_fail("Hit bodies must honour the FPS template target contract.")
			return
		zone_ids.append(hit_body.zone_id)
	zone_ids.sort()
	var expected_ids: Array[String] = ["close", "finish", "raise"]
	if zone_ids != expected_ids:
		_fail("Unexpected zone ids: %s" % str(zone_ids))
		return
	var close_body := window.find_hit_body("close")
	var finish_body := window.find_hit_body("finish")
	if close_body.position.x <= 0.0 or close_body.position.y <= 0.0:
		_fail("The close zone should sit on the top right corner of the window.")
		return
	if absf(finish_body.position.x) > 0.05 or finish_body.position.y >= 0.0:
		_fail("The finish zone should sit near the bottom center of the window.")
		return
	var hits: Array[String] = []
	window.zone_hit.connect(func(zone_id: String, _window: WindowPanel3D) -> void: hits.append(zone_id))
	var closed_count := [0]
	window.closed.connect(func(_window: WindowPanel3D) -> void: closed_count[0] += 1)
	close_body.Hit_Successful(1.0)
	await process_frame
	var expected_hits: Array[String] = ["close"]
	if hits != expected_hits or closed_count[0] != 1:
		_fail("Shooting the close zone should report the hit and close the window.")
		return
	if is_instance_valid(window):
		_fail("A closed window should free itself.")
		return
	var second_window := WINDOW_SCENE.instantiate() as WindowPanel3D
	root.add_child(second_window)
	await process_frame
	await process_frame
	var second_finish := second_window.find_hit_body("finish")
	second_finish.Hit_Successful(1.0)
	await process_frame
	if is_instance_valid(second_window):
		_fail("The finish button should close the window as well.")
		return
	var close_window := CLOSE_WINDOW_SCENE.instantiate() as WindowPanel3D
	root.add_child(close_window)
	await process_frame
	await process_frame
	var close_zones := close_window.get_hit_bodies()
	if close_zones.is_empty():
		_fail("The close window should expose at least one zone.")
		return
	# Todo control de esta ventana cierra; la barra de titulo no es un control,
	# es la que la trae al frente.
	for zone in close_zones:
		if zone.zone_id != "close" and zone.zone_id != WindowPanel3D.RAISE_ZONE:
			_fail("Every close window zone should use the close id, got %s." % zone.zone_id)
			return
	close_zones.back().Hit_Successful(1.0)
	await process_frame
	if is_instance_valid(close_window):
		_fail("Shooting the Cerrar button should close the window.")
		return
	# La descarga no se cancela de un tiro: el primero abre la confirmacion y
	# recien el segundo la cierra. Ni la X ni el boton se saltean ese paso.
	var download_window := DOWNLOAD_WINDOW_SCENE.instantiate() as DownloadWindow
	root.add_child(download_window)
	await process_frame
	await process_frame
	if download_window.find_hit_body("cancel") == null:
		_fail("The download window should expose its cancel zones.")
		return
	if download_window.find_hit_body(DownloadWindow.CONFIRM_ZONE) != null:
		_fail("The confirmation should not be shootable before it is asked for.")
		return
	download_window.find_hit_body("cancel").Hit_Successful(1.0)
	await process_frame
	await process_frame
	if not is_instance_valid(download_window):
		_fail("Cancelling should ask for confirmation instead of closing the window.")
		return
	var confirm_body := download_window.find_hit_body(DownloadWindow.CONFIRM_ZONE)
	if confirm_body == null:
		_fail("Cancelling should open a confirmation the player can shoot.")
		return
	confirm_body.Hit_Successful(1.0)
	await process_frame
	if is_instance_valid(download_window):
		_fail("Confirming the cancellation should close the download window.")
		return
	for template_path in TEMPLATE_SCENES:
		var template := (load(template_path) as PackedScene).instantiate() as WindowPanel3D
		root.add_child(template)
		await process_frame
		await process_frame
		if template.find_hit_body("close") == null or template.find_hit_body("accept") == null:
			_fail("%s should ship a close and an accept zone." % template_path)
			return
		template.find_hit_body("accept").Hit_Successful(1.0)
		await process_frame
		if is_instance_valid(template):
			_fail("%s should close when its action zone is shot." % template_path)
			return
	print("Window panel smoke test passed.")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)

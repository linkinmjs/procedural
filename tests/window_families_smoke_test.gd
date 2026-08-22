extends SceneTree

## Prueba las familias de ventana que tienen comportamiento propio.
##
## Cada una existe para cobrar una cosa distinta: el popup cobra la demora, el
## firewall impone un orden, el error critico castiga el disparo apurado y la
## descarga cobra el apuro pidiendo dos tiros. Lo que se verifica es esa regla,
## no como se ven.

const POPUP := preload("res://scenes/windows/popup_window.tscn")
const FIREWALL := preload("res://scenes/windows/firewall_window.tscn")
const CRITICAL := preload("res://scenes/windows/critical_error_window.tscn")
const DOWNLOAD := preload("res://scenes/windows/download_window.tscn")
const NORMAL := preload("res://scenes/windows/close_window.tscn")
const INFECTED := preload("res://scenes/windows/infected_download_window.tscn")
const BLOCK := preload("res://scenes/targets/target_block_3d.tscn")


func _initialize() -> void:
	create_timer(30.0, true, false, true).timeout.connect(func() -> void: _fail("Window families smoke test timed out."))
	_run.call_deferred()


func _run() -> void:
	if not _check_catalog():
		return
	if not await _check_popup_multiplies():
		return
	if not await _check_firewall_shields():
		return
	if not await _check_critical_error_traps():
		return
	if not await _check_download_takes_two_shots():
		return
	if not await _check_shield_pays_nothing():
		return
	if not await _check_raise_to_front():
		return
	if not await _check_infected_download_crashes_block():
		return
	if not await _check_every_zone_is_reachable():
		return
	if not await _check_called_ads_have_their_own_screen():
		return
	print("Window families smoke test passed.")
	quit()


## El catalogo resuelve cada familia a su escena, y las que todavia no tienen
## comportamiento propio caen en normal en vez de romper el nivel.
func _check_catalog() -> bool:
	for family in ["normal", "popup", "firewall", "critical-error", "download"]:
		if not WindowCatalog.is_implemented(family):
			_fail("The family %s should have its own scene." % family)
			return false
		if WindowCatalog.scene_for(family) == null:
			_fail("The family %s should resolve to a scene." % family)
			return false
	if WindowCatalog.is_implemented("task-manager"):
		_fail("A family without a scene should not report itself as implemented.")
		return false
	if WindowCatalog.scene_for("task-manager") == null:
		_fail("A family without a scene should still fall back to a playable window.")
		return false
	# Una capa se resuelve a una escena por ventana, en el orden declarado. La
	# escena de cada una tiene que ser alguna de las variantes de su familia: no
	# se compara contra otra llamada al catalogo, porque una familia con varias
	# variantes elige al azar y dos llamadas pueden dar distinto a proposito.
	var scenes := WindowCatalog.scenes_for(PackedStringArray(["popup", "firewall"]))
	if scenes.size() != 2:
		_fail("A layer should resolve to one scene per window.")
		return false
	if not (WindowCatalog.VARIANTS["popup"] as Array).has(scenes[0]):
		_fail("The first window should be one of the popup variants.")
		return false
	if not (WindowCatalog.VARIANTS["firewall"] as Array).has(scenes[1]):
		_fail("The second window should be the firewall, in the declared order.")
		return false
	return true


## La publicidad no se puede saltear hasta que el contador la deje, llama a una
## sola, y errarle al cuerpo abre otra.
func _check_popup_multiplies() -> bool:
	var holder := Node3D.new()
	root.add_child(holder)
	var ad := POPUP.instantiate() as PopupWindow
	ad.skip_seconds = 20.0
	holder.add_child(ad)
	await _wait_frames(3)

	# Mientras corre la cuenta, el boton esta pero no resuelve nada.
	var skip := ad.find_hit_body(PopupWindow.SKIP_ZONE)
	if skip == null or skip.closes_window or skip.scores:
		_fail("SKIP should be present but inert while the countdown runs.")
		holder.queue_free()
		return false
	skip.Hit_Successful(1.0)
	await _wait_frames(2)
	if not is_instance_valid(ad):
		_fail("Skipping before the countdown ends should not close the ad.")
		holder.queue_free()
		return false

	# Errar y pegarle al cuerpo abre otra.
	var before := holder.get_child_count()
	ad.find_hit_body(PopupWindow.AD_ZONE).Hit_Successful(1.0)
	await _wait_frames(2)
	if holder.get_child_count() <= before:
		_fail("Hitting the ad body should open another one.")
		holder.queue_free()
		return false
	# Y llama a una sola: insistir no abre mas.
	var after_first := holder.get_child_count()
	ad.find_hit_body(PopupWindow.AD_ZONE).Hit_Successful(1.0)
	await _wait_frames(2)
	if holder.get_child_count() != after_first:
		_fail("Each ad should call exactly one other.")
		holder.queue_free()
		return false

	# La X cierra siempre, corra o no el contador: la espera empuja al boton
	# grande, pero nunca deja al jugador sin salida.
	var closer := NORMAL.instantiate()
	holder.add_child(closer)
	var trapped := POPUP.instantiate() as PopupWindow
	trapped.skip_seconds = 20.0
	holder.add_child(trapped)
	await _wait_frames(3)
	var cross := trapped.find_hit_body("close")
	if cross == null or not cross.closes_window:
		_fail("The ad should always offer its close button.")
		holder.queue_free()
		return false
	cross.Hit_Successful(1.0)
	# El cierre tiene animacion: la ventana se libera sola unos frames despues.
	if not await _wait_until_freed(trapped):
		_fail("The close button should close the ad even while it is counting down.")
		holder.queue_free()
		return false

	# Con el contador terminado el boton grande tambien resuelve, y dice que se
	# puede saltear en vez de pedir esperar.
	ad.arrive_without_countdown()
	await _wait_frames(2)
	var ready_skip := ad.find_hit_body(PopupWindow.SKIP_ZONE)
	if not ready_skip.closes_window:
		_fail("Once the countdown is done, the skip button should close the ad.")
		holder.queue_free()
		return false
	ready_skip.Hit_Successful(1.0)
	if not await _wait_until_freed(ad):
		_fail("The skip button should close the ad once it is available.")
		holder.queue_free()
		return false
	holder.queue_free()
	return true


## Una publicidad que llama a otra tiene que darle su propia pantalla. El
## material y el quad son locales a la escena, y duplicar el nodo no los
## reinstancia: la copia terminaba compartiendo la textura del original y quedaba
## en blanco en cuanto el original se cerraba.
func _check_called_ads_have_their_own_screen() -> bool:
	var block := BLOCK.instantiate() as TargetBlock3D
	block.block_size = Vector2(10.0, 5.0)
	block.layers.assign([PackedStringArray(["popup"])])
	root.add_child(block)
	await _wait_frames(4)
	var volume := block.spawn_volume
	for target in volume.active_targets:
		(target as PopupWindow)._remaining = 0.1
	await _wait_seconds(0.6)
	await _wait_frames(3)
	if volume.active_targets.size() < 2:
		_fail("An unattended ad should call another one.")
		block.queue_free()
		return false
	var half := Vector2(volume.size.x * 0.5, volume.size.y * 0.5)
	for target in volume.active_targets:
		var window := target as PopupWindow
		var material := ((window.get_node("Screen") as MeshInstance3D).mesh as QuadMesh).material as StandardMaterial3D
		if material == null or not material.albedo_texture is ViewportTexture:
			_fail("A called ad should get its own screen instead of sharing one.")
			block.queue_free()
			return false
		# Y tiene que caer dentro del bloque: encadenando desplazamientos las
		# ultimas terminaban fuera de la pared y debajo del piso.
		if absf(window.position.x) > half.x + 1.0 or absf(window.position.y) > half.y + 1.0:
			_fail("A called ad should land inside the block, got %s." % str(window.position))
			block.queue_free()
			return false
	block.queue_free()
	return true


## Traer al frente no resuelve nada, asi que no puede cerrar ni pagar; y se puede
## repetir, porque en un escritorio se hace todas las veces que haga falta.
func _check_raise_to_front() -> bool:
	var holder := Node3D.new()
	root.add_child(holder)
	var back := NORMAL.instantiate() as WindowPanel3D
	var front := NORMAL.instantiate() as WindowPanel3D
	holder.add_child(back)
	holder.add_child(front)
	back.position.z = 0.0
	front.position.z = 0.5
	await _wait_frames(2)
	var bar := back.find_hit_body(WindowPanel3D.RAISE_ZONE)
	if bar == null or bar.scores or bar.closes_window:
		_fail("The title bar should be a zone that neither closes nor pays.")
		holder.queue_free()
		return false
	bar.Hit_Successful(1.0)
	await _wait_frames(2)
	if back.position.z <= front.position.z:
		_fail("Shooting the title bar should bring the window forward.")
		holder.queue_free()
		return false
	if not is_instance_valid(back):
		_fail("Bringing a window forward should not close it.")
		holder.queue_free()
		return false
	holder.queue_free()
	return true


## La descarga infectada no se resuelve: al completarse cuelga el bloque. El
## bloque queda en pie —sigue estorbando— pero cuenta como resuelto, asi que la
## sala puede seguir.
func _check_infected_download_crashes_block() -> bool:
	var block := BLOCK.instantiate() as TargetBlock3D
	block.layers.assign([
		PackedStringArray(["infected-download"]),
		PackedStringArray(["normal", "normal"]),
	])
	var resolved := [false]
	block.closed.connect(func(_b: TargetBlock3D) -> void: resolved[0] = true)
	root.add_child(block)
	await _wait_frames(4)
	var infected: DownloadWindow = null
	for target in block.spawn_volume.active_targets:
		if target is DownloadWindow:
			infected = target
	if infected == null:
		_fail("The infected layer should spawn its download.")
		block.queue_free()
		return false
	infected.download_seconds = 0.2
	await _wait_seconds(0.6)
	await _wait_frames(3)

	if not bool(resolved[0]):
		_fail("A crashed block should count as resolved so the room can go on.")
		block.queue_free()
		return false
	if not is_instance_valid(block) or block.is_queued_for_deletion():
		_fail("A crashed block should stay in the room instead of vanishing.")
		return false
	# Nada de capa intermedia: el bloque queda inservible de una, sin dejar
	# objetivos que romper primero.
	if not block.spawn_volume.active_targets.is_empty():
		_fail("Crashing should leave nothing left to shoot, got %d targets." % block.spawn_volume.active_targets.size())
		block.queue_free()
		return false
	if block._current_layer_index != 0:
		_fail("Crashing should not advance to the next layer.")
		block.queue_free()
		return false
	# Y en su lugar queda la pantalla de error, encendida y sin nada que hacerle.
	var screen := block.get_node_or_null("BlueScreen")
	if screen == null:
		_fail("A crashed block should show its error screen.")
		block.queue_free()
		return false
	if block.block_mesh.visible or block.spawn_volume.visible:
		_fail("The error screen should replace the block panel, not sit on top of it.")
		block.queue_free()
		return false
	block.queue_free()
	return true


## El firewall protege a sus hermanas: mientras esta en pie, dispararles no las
## cierra. Al desactivarlo, quedan disponibles.
func _check_firewall_shields() -> bool:
	var holder := Node3D.new()
	root.add_child(holder)
	var victim := NORMAL.instantiate() as WindowPanel3D
	holder.add_child(victim)
	var firewall := FIREWALL.instantiate() as FirewallWindow
	holder.add_child(firewall)
	await _wait_frames(3)

	if not victim.shielded:
		_fail("A firewall should shield the other windows of its layer.")
		holder.queue_free()
		return false
	if firewall.shielded:
		_fail("A firewall should not shield itself.")
		holder.queue_free()
		return false
	victim.find_hit_body("close").Hit_Successful(1.0)
	await _wait_frames(2)
	if not is_instance_valid(victim):
		_fail("Shooting a shielded window should not close it.")
		holder.queue_free()
		return false

	firewall.find_hit_body("close").Hit_Successful(1.0)
	await _wait_frames(3)
	if victim.shielded:
		_fail("Disabling the firewall should release the windows it covered.")
		holder.queue_free()
		return false
	victim.find_hit_body("close").Hit_Successful(1.0)
	if not await _wait_until_freed(victim):
		_fail("An unshielded window should close when shot.")
		holder.queue_free()
		return false
	holder.queue_free()
	return true


## El error critico tiene un control que cierra y dos que castigan. Los que
## castigan usan el identificador de trampa, que es el que el puntaje ya resta.
func _check_critical_error_traps() -> bool:
	var window := CRITICAL.instantiate() as CriticalErrorWindow
	root.add_child(window)
	await _wait_frames(2)
	var traps := 0
	for body in window.get_hit_bodies():
		if body.zone_id == CriticalErrorWindow.TRAP_ZONE:
			traps += 1
			if body.closes_window:
				_fail("A trap zone should not close the window.")
				window.queue_free()
				return false
	if traps < 2:
		_fail("The critical error should offer more than one wrong control, got %d." % traps)
		window.queue_free()
		return false
	var trap_body := window.find_hit_body(CriticalErrorWindow.TRAP_ZONE)
	trap_body.Hit_Successful(1.0)
	await _wait_frames(2)
	if not is_instance_valid(window):
		_fail("Hitting a trap should punish the player, not solve the window.")
		return false
	window.find_hit_body("close").Hit_Successful(1.0)
	if not await _wait_until_freed(window):
		_fail("The right control should close the critical error.")
		return false
	return true


## Cancelar la descarga abre la confirmacion; recien el segundo disparo la
## cierra. Y si nadie la cancela, la barra llega al final y castiga.
func _check_download_takes_two_shots() -> bool:
	var window := DOWNLOAD.instantiate() as DownloadWindow
	window.download_seconds = 60.0
	root.add_child(window)
	await _wait_frames(2)
	window.find_hit_body(DownloadWindow.CANCEL_ZONE).Hit_Successful(1.0)
	await _wait_frames(2)
	if not is_instance_valid(window):
		_fail("The first shot should ask for confirmation, not close the download.")
		return false
	# La confirmacion cierra por la via rapida, que es la que mas paga.
	window.find_hit_body(DownloadWindow.CONFIRM_ZONE).Hit_Successful(1.0)
	if not await _wait_until_freed(window):
		_fail("The second shot should close the download.")
		return false

	# Abandonada, la descarga termina pero no se va sola: pide un ultimo disparo
	# en Finalizar, que paga menos que haberla cancelado a tiempo.
	var ignored := DOWNLOAD.instantiate() as DownloadWindow
	ignored.download_seconds = 0.2
	root.add_child(ignored)
	await _wait_seconds(0.6)
	await _wait_frames(3)
	if not is_instance_valid(ignored):
		_fail("A finished download should wait for the player instead of vanishing.")
		return false
	var finish := ignored.find_hit_body(DownloadWindow.FINISH_ZONE)
	if finish == null:
		_fail("A finished download should offer its finish control.")
		ignored.queue_free()
		return false
	if ignored.find_hit_body(DownloadWindow.CANCEL_ZONE) != null:
		_fail("Once finished there is nothing left to cancel.")
		ignored.queue_free()
		return false
	finish.Hit_Successful(1.0)
	if not await _wait_until_freed(ignored):
		_fail("Finishing should close the download.")
		return false
	return true


## Dispararle a una ventana protegida no resuelve nada, asi que no puede pagar.
## El puntaje cobra cualquier zona acertada y una zona desconocida cae en el
## valor por defecto, asi que sin esto el firewall era una fuente infinita de
## puntos: la zona se rearma al rebotar y se le puede seguir disparando.
func _check_shield_pays_nothing() -> bool:
	var hud := preload("res://scenes/ui/round_hud.tscn").instantiate()
	root.add_child(hud)
	await _wait_frames(1)
	var controller: RoundController = hud.get_node("RoundController")
	var score: ScoreController = hud.get_node("ScoreController")
	score.prepare_level("shield-test", {"rooms": [{"id": "r", "waves": []}]})
	controller.start_round()
	controller.report_room_entered("r", "Sala")

	var holder := Node3D.new()
	root.add_child(holder)
	var victim := NORMAL.instantiate() as WindowPanel3D
	holder.add_child(victim)
	var firewall := FIREWALL.instantiate() as FirewallWindow
	holder.add_child(firewall)
	await _wait_frames(3)
	if not victim.shielded:
		_fail("The victim should be shielded before measuring the score.")
		holder.queue_free()
		hud.queue_free()
		return false

	for _shot in 5:
		victim.find_hit_body("close").Hit_Successful(1.0)
		await _wait_frames(1)
	var paid := score.pot != 0 or score.chain_hits != 0
	holder.queue_free()
	hud.queue_free()
	if paid:
		_fail("Shooting a shielded window paid %d into the pot and %d chain hits." % [score.pot, score.chain_hits])
		return false
	return true


## Toda zona tiene que poder acertarse apuntandole. Las zonas se superponen —la
## X vive dentro de la barra, el boton dentro del aviso— y con todas en el mismo
## plano el disparo elegia cualquiera: apuntarle a la X pegaba en la barra y la
## ventana no cerraba. Se comprueba disparando de verdad, con un rayo, porque
## llamar al cuerpo directamente se saltea justo la parte que fallaba.
func _check_every_zone_is_reachable() -> bool:
	for path in [
		"res://scenes/windows/close_window.tscn",
		"res://scenes/windows/shutdown_window.tscn",
		"res://scenes/windows/popup_window.tscn",
		"res://scenes/windows/popup_slow_window.tscn",
		"res://scenes/windows/critical_error_window.tscn",
		"res://scenes/windows/download_window.tscn",
		"res://scenes/windows/infected_download_window.tscn",
		"res://scenes/windows/firewall_window.tscn",
	]:
		var window := (load(path) as PackedScene).instantiate() as WindowPanel3D
		root.add_child(window)
		await _wait_frames(4)
		var bodies := window.get_hit_bodies()
		if bodies.is_empty():
			_fail("%s should build its hit zones." % path.get_file())
			window.free()
			return false
		var has_raise := false
		var space: PhysicsDirectSpaceState3D = window.get_world_3d().direct_space_state
		for body in bodies:
			if body.zone_id == WindowPanel3D.RAISE_ZONE:
				has_raise = true
			var target: Vector3 = body.global_position
			var query := PhysicsRayQueryParameters3D.create(target + Vector3(0.0, 0.0, 3.0), target - Vector3(0.0, 0.0, 0.5))
			query.collision_mask = WindowPanel3D.TARGET_LAYER
			var hit: Dictionary = space.intersect_ray(query)
			var reached := ""
			if hit.has("collider") and "zone_id" in hit.collider:
				reached = str(hit.collider.zone_id)
			if reached != body.zone_id:
				_fail("%s: aiming at '%s' hits '%s' instead." % [path.get_file(), body.zone_id, reached])
				window.free()
				return false
		# Toda ventana se puede traer al frente: es la regla del escritorio.
		if not has_raise:
			_fail("%s should let the player bring it forward." % path.get_file())
			window.free()
			return false
		window.free()
	return true


func _wait_frames(count: int) -> void:
	for _frame in count:
		await physics_frame
		await process_frame


## Espera a que el nodo se libere solo, con margen para la animacion de cierre.
## El plazo es de tiempo real: los tweens corren con delta, no con frames.
func _wait_until_freed(node: Node, seconds := 1.5) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while is_instance_valid(node):
		if Time.get_ticks_msec() > deadline:
			return false
		await process_frame
	return true


func _wait_seconds(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout


func _fail(message: String) -> void:
	push_error(message)
	quit(1)

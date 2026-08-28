extends SceneTree

## Prueba las actividades musicales.
##
## Una actividad es una ventana que se cierra al completar una consigna de
## teoria: la escala en orden, las notas del acorde, el intervalo. Lo que se
## verifica es el contrato: la teoria da las notas correctas, el catalogo
## convierte una actividad de datos en una pregunta concreta, la ventana
## acepta lo que corresponde y castiga lo que no, y un bloque la reparte y la
## cuenta como cualquier otra ventana.

const ACTIVITY := preload("res://scenes/windows/music_activity_window.tscn")
const BLOCK := preload("res://scenes/targets/target_block_3d.tscn")

const C_MAJOR_UP := [0, 2, 4, 5, 7, 9, 11, 0]


func _initialize() -> void:
	create_timer(60.0, true, false, true).timeout.connect(func() -> void: _fail("Music activity smoke test timed out."))
	_run.call_deferred()


func _run() -> void:
	if not _check_theory():
		return
	if not _check_catalog():
		return
	if not _check_questions():
		return
	if not _check_spawn_plan():
		return
	if not await _check_ordered_sequence():
		return
	if not await _check_unordered_set():
		return
	if not await _check_restart_on_miss():
		return
	if not await _check_every_key_is_reachable():
		return
	if not await _check_scoring():
		return
	if not await _check_block_resolves_layer():
		return
	print("Music activity smoke test passed.")
	quit()


## Las notas se leen con sostenidos y bemoles, y las escalas, acordes e
## intervalos dan las notas que dice cualquier manual.
func _check_theory() -> bool:
	var expected_pitches := {"C": 0, "C#": 1, "Db": 1, "Bb": 10, "b": 11, "Cb": 11, "E#": 5, "H": -1, "": -1}
	for name in expected_pitches:
		if MusicTheory.pitch_class(name) != int(expected_pitches[name]):
			_fail("pitch_class(%s) should be %d, got %d." % [name, expected_pitches[name], MusicTheory.pitch_class(name)])
			return false
	if Array(MusicTheory.scale(0, "major")) != [0, 2, 4, 5, 7, 9, 11]:
		_fail("C major should be the white keys.")
		return false
	if _names(MusicTheory.scale(2, "major")) != "D E F# G A B C#":
		_fail("D major should carry F# and C#, got %s." % _names(MusicTheory.scale(2, "major")))
		return false
	if _names(MusicTheory.scale(9, "minor")) != "A B C D E F G":
		_fail("A minor should be all naturals, got %s." % _names(MusicTheory.scale(9, "minor")))
		return false
	if _names(MusicTheory.chord(7, "major")) != "G B D":
		_fail("G major should be G B D, got %s." % _names(MusicTheory.chord(7, "major")))
		return false
	if _names(MusicTheory.chord(9, "minor")) != "A C E":
		_fail("A minor should be A C E.")
		return false
	if _names(MusicTheory.chord(11, "diminished")) != "B D F":
		_fail("B diminished should be B D F.")
		return false
	if MusicTheory.interval(2, "M3") != 6 or MusicTheory.interval(11, "P5") != 6 or MusicTheory.interval(0, "P8") != 0:
		_fail("Intervals should wrap around the octave.")
		return false
	if not is_equal_approx(MusicTheory.frequency(9, 4), 440.0) or absf(MusicTheory.frequency(0, 4) - 261.63) > 0.01:
		_fail("A4 should be 440 Hz and C4 261.63 Hz.")
		return false
	if MusicTheory.display_name(1) != "C#/Db" or MusicTheory.display_name(0) != "C":
		_fail("Black keys should show both names.")
		return false
	if NoteSynth.get_stream() == null or not is_equal_approx(NoteSynth.pitch_scale_for(0, 5), 2.0) \
			or not is_equal_approx(NoteSynth.pitch_scale_for(0), 1.0):
		_fail("The note synth should build its stream and pitch by semitones.")
		return false
	return true


## El catalogo lee el archivo y conoce las actividades de fabrica.
func _check_catalog() -> bool:
	for id in ["nota-suelta", "escala-c-mayor-asc", "triadas-mayores", "intervalos-basicos"]:
		if not MusicActivityCatalog.has_activity(id):
			_fail("The catalog should bring the activity %s." % id)
			return false
		if MusicActivityCatalog.activity_name(id).is_empty():
			_fail("The activity %s should have a display name." % id)
			return false
	if not MusicActivityCatalog.get_ids().has("escala-c-mayor-asc"):
		_fail("get_ids should list the seed activities.")
		return false
	if not MusicActivityCatalog.get_activity("no-existe").is_empty():
		_fail("An unknown activity should be empty.")
		return false
	if MusicActivityCatalog.default_activity().is_empty():
		_fail("There should always be a default activity.")
		return false
	return true


## Cada actividad se convierte en una respuesta concreta: la escala en el
## orden pedido, el acorde con sus notas, el intervalo con la suya. Una
## respuesta con teclas negras pide el teclado completo aunque la actividad
## declare la paleta natural.
func _check_questions() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var up := MusicActivityCatalog.question_for(MusicActivityCatalog.get_activity("escala-c-mayor-asc"), rng)
	if Array(up.answer) != C_MAJOR_UP or not up.ordered or up.palette != "natural" or not up.hints:
		_fail("The C major scale should go C to C on the white keys, in order and guided: %s." % str(up))
		return false
	var down := MusicActivityCatalog.question_for({"question": "scale", "roots": ["C"], "direction": "down"}, rng)
	if Array(down.answer) != [0, 11, 9, 7, 5, 4, 2, 0]:
		_fail("The descending scale should start at the root and fall, got %s." % str(down.answer))
		return false
	var both := MusicActivityCatalog.question_for({"question": "scale", "roots": ["C"], "direction": "both", "octave": false}, rng)
	if Array(both.answer) != [0, 2, 4, 5, 7, 9, 11, 0, 11, 9, 7, 5, 4, 2]:
		_fail("Up and down should not repeat the top note, got %s." % str(both.answer))
		return false
	var sharp := MusicActivityCatalog.question_for({"question": "scale", "roots": ["D"], "palette": "natural"}, rng)
	if sharp.palette != "chromatic":
		_fail("An answer with black keys should upgrade the palette to chromatic.")
		return false
	var chord := MusicActivityCatalog.question_for(MusicActivityCatalog.get_activity("triadas-mayores"), rng)
	if chord.ordered or Array(chord.answer) != Array(MusicTheory.chord(int(chord.root), "major")):
		_fail("A major triad question should answer with the chord of its root, unordered.")
		return false
	var interval := MusicActivityCatalog.question_for(MusicActivityCatalog.get_activity("intervalos-basicos"), rng)
	if interval.answer.size() != 1 or interval.answer[0] != MusicTheory.interval(int(interval.root), str(interval.interval)):
		_fail("An interval question should answer with the note at that interval.")
		return false
	if not ["M3", "P4", "P5"].has(str(interval.interval)):
		_fail("The interval should be one the activity allows, got %s." % str(interval.interval))
		return false
	# Con varias tonicas posibles el azar tiene que alternarlas.
	var seen := {}
	for _index in 30:
		var question := MusicActivityCatalog.question_for(MusicActivityCatalog.get_activity("escala-mayor-asc"), rng)
		seen[int(question.root)] = true
		if not MusicTheory.is_natural(int(question.root)):
			_fail("Roots limited to naturals should never pick a black key.")
			return false
	if seen.size() < 2:
		_fail("Thirty questions over seven roots should show more than one root.")
		return false
	return true


## El plan de spawn resuelve `music:<id>` a la escena de actividad con la
## actividad como configuracion, y un id borrado cae en una ventana normal.
func _check_spawn_plan() -> bool:
	var plan := WindowCatalog.spawn_plan_for(PackedStringArray(["music:escala-c-mayor-asc", "music:no-existe", "normal"]))
	if plan.size() != 3:
		_fail("The plan should bring one entry per window.")
		return false
	if plan[0].scene != WindowCatalog.MUSIC_ACTIVITY_SCENE or str((plan[0].config as Dictionary).get("id", "")) != "escala-c-mayor-asc":
		_fail("A music type should spawn the activity scene with its activity as config.")
		return false
	if not (WindowCatalog.VARIANTS[WindowCatalog.NORMAL_TYPE] as Array).has(plan[1].scene) or not (plan[1].config as Dictionary).is_empty():
		_fail("A deleted activity should degrade to a normal window.")
		return false
	if not LevelDefinitionLoader._is_valid_custom_type("music:escala-c-mayor-asc") or LevelDefinitionLoader._is_valid_custom_type("music:Mal"):
		_fail("The loader should accept music types with a lowercase slug.")
		return false
	return true


## La escala hay que tocarla en orden: la nota equivocada no avanza ni cierra,
## la correcta avanza, y la ultima cierra la ventana.
func _check_ordered_sequence() -> bool:
	var window := await _spawn({"id": "t", "name": "Prueba", "question": "scale", "roots": ["C"], "mode": "major", "direction": "up"})
	if window.find_hit_body("note:C#") != null:
		_fail("A natural palette should hide the black keys.")
		window.free()
		return false
	var title := window.content.find_child("Title", true, false) as Label
	if title == null or title.text != "Prueba":
		_fail("The activity name should be the window title.")
		window.free()
		return false
	var prompt := window.content.find_child("Prompt", true, false) as Label
	if prompt == null or prompt.text.is_empty() or prompt.text.contains("MUSIC_"):
		_fail("The prompt should be a translated sentence, got '%s'." % (prompt.text if prompt != null else ""))
		window.free()
		return false
	await _hit(window, "D")
	if window.progress != 0 or not is_instance_valid(window):
		_fail("A wrong first note should not advance the scale.")
		window.free()
		return false
	await _hit(window, "C")
	if window.progress != 1:
		_fail("The root should be the first note of the scale.")
		window.free()
		return false
	await _hit(window, "C")
	if window.progress != 1:
		_fail("Repeating a note out of order should not advance.")
		window.free()
		return false
	for name in ["D", "E", "F", "G", "A", "B"]:
		await _hit(window, name)
	if window.progress != 7 or not is_instance_valid(window):
		_fail("Six right notes should leave only the octave, got progress %d." % window.progress)
		window.free()
		return false
	await _hit(window, "C")
	if not await _wait_until_freed(window):
		_fail("The last note of the scale should close the activity.")
		return false
	return true


## Las notas de un acorde valen en cualquier orden, pero cada una una sola
## vez: repetir una ya encontrada es un error.
func _check_unordered_set() -> bool:
	var window := await _spawn({"id": "t", "name": "T", "question": "chord", "roots": ["G"], "qualities": ["major"], "ordered": false, "palette": "chromatic"})
	if window.find_hit_body("note:F#") == null:
		_fail("A chromatic palette should show the black keys.")
		window.free()
		return false
	await _hit(window, "D")
	await _hit(window, "D")
	if window._found.size() != 1 or not is_instance_valid(window):
		_fail("A note already found should not count twice.")
		window.free()
		return false
	await _hit(window, "F")
	if window._found.size() != 1:
		_fail("A note outside the chord should not count.")
		window.free()
		return false
	await _hit(window, "G")
	await _hit(window, "B")
	if not await _wait_until_freed(window):
		_fail("The three notes of the chord, in any order, should close the activity.")
		return false
	return true


## Con onMiss = restart un error borra el progreso.
func _check_restart_on_miss() -> bool:
	var window := await _spawn({"id": "t", "name": "T", "question": "scale", "roots": ["C"], "onMiss": "restart"})
	await _hit(window, "C")
	await _hit(window, "D")
	if window.progress != 2:
		_fail("Two right notes should advance twice.")
		window.free()
		return false
	await _hit(window, "F")
	if window.progress != 0:
		_fail("A wrong note should restart the scale when the activity says so.")
		window.free()
		return false
	window.free()
	return true


## Toda tecla tiene que poder acertarse apuntandole, con las negras montadas
## sobre las blancas: se dispara de verdad, con un rayo.
func _check_every_key_is_reachable() -> bool:
	var window := await _spawn({"id": "t", "name": "T", "question": "interval", "roots": ["C"], "intervals": ["m2"]})
	var space: PhysicsDirectSpaceState3D = window.get_world_3d().direct_space_state
	var keys := 0
	for body in window.get_hit_bodies():
		if not body.zone_id.begins_with(MusicActivityWindow.NOTE_ZONE_PREFIX):
			continue
		keys += 1
		var target: Vector3 = body.global_position
		var query := PhysicsRayQueryParameters3D.create(target + Vector3(0.0, 0.0, 3.0), target - Vector3(0.0, 0.0, 0.5))
		query.collision_mask = WindowPanel3D.TARGET_LAYER
		var hit: Dictionary = space.intersect_ray(query)
		var reached := str(hit.collider.zone_id) if hit.has("collider") and "zone_id" in hit.collider else ""
		if reached != body.zone_id:
			_fail("Aiming at '%s' hits '%s' instead." % [body.zone_id, reached])
			window.free()
			return false
	if keys != 12:
		_fail("A chromatic keyboard should expose twelve keys, got %d." % keys)
		window.free()
		return false
	window.free()
	return true


## Cada acierto suma a la cadena; el error es una trampa: resta y la cierra.
func _check_scoring() -> bool:
	var hud := preload("res://scenes/ui/round_hud.tscn").instantiate()
	root.add_child(hud)
	await _wait_frames(1)
	var controller: RoundController = hud.get_node("RoundController")
	var score: ScoreController = hud.get_node("ScoreController")
	score.prepare_level("music-test", {"rooms": [{"id": "r", "waves": []}]})
	controller.start_round()
	controller.report_room_entered("r", "Sala")

	var window := await _spawn({"id": "t", "name": "T", "question": "scale", "roots": ["C"]})
	await _hit(window, "C")
	await _hit(window, "D")
	if score.chain_hits != 2 or score.pot <= 0:
		_fail("Right notes should build the chain, got %d hits and pot %d." % [score.chain_hits, score.pot])
		window.free()
		hud.queue_free()
		return false
	# El puntaje total nunca baja de cero, asi que el castigo se mira en el
	# cobro: la cadena tiene que cerrarse por trampa.
	var banked := [""]
	score.chain_banked.connect(func(_hits: int, _pot: int, _multiplier: float, _awarded: int, reason: String) -> void: banked[0] = reason)
	await _hit(window, "A")
	if score.chain_hits != 0 or str(banked[0]) != ScoreController.REASON_TRAP:
		_fail("A wrong note should bank the chain as a trap, got %d hits and reason '%s'." % [score.chain_hits, banked[0]])
		window.free()
		hud.queue_free()
		return false
	window.free()
	hud.queue_free()
	return true


## Dentro de un bloque la actividad es una ventana mas: al completarla la
## capa se limpia y llega la siguiente.
func _check_block_resolves_layer() -> bool:
	var block := BLOCK.instantiate() as TargetBlock3D
	block.block_size = Vector2(10.0, 5.0)
	block.layers.assign([
		PackedStringArray(["music:escala-c-mayor-asc"]),
		PackedStringArray(["normal"]),
	])
	root.add_child(block)
	await _wait_frames(4)
	var activity: MusicActivityWindow = null
	for target in block.spawn_volume.active_targets:
		if target is MusicActivityWindow:
			activity = target
	if activity == null:
		_fail("The block should spawn the music activity of its first layer.")
		block.queue_free()
		return false
	for name in ["C", "D", "E", "F", "G", "A", "B", "C"]:
		await _hit(activity, name)
	await _wait_until_freed(activity)
	await _wait_frames(3)
	if block._current_layer_index != 1:
		_fail("Completing the activity should clear the layer.")
		block.queue_free()
		return false
	block.queue_free()
	return true


func _spawn(activity: Dictionary) -> MusicActivityWindow:
	var window := ACTIVITY.instantiate() as MusicActivityWindow
	window.variant_config = activity
	root.add_child(window)
	await _wait_frames(3)
	return window


func _hit(window: MusicActivityWindow, note: String) -> void:
	var body := window.find_hit_body(MusicActivityWindow.NOTE_ZONE_PREFIX + note)
	if body == null:
		_fail("The keyboard should offer the key %s." % note)
		return
	body.Hit_Successful(1.0)
	await _wait_frames(1)


func _names(pitches: PackedInt32Array) -> String:
	var names := PackedStringArray()
	for pitch in pitches:
		names.append(MusicTheory.note_name(pitch))
	return " ".join(names)


func _wait_frames(count: int) -> void:
	for _frame in count:
		await physics_frame
		await process_frame


func _wait_until_freed(node: Node, seconds := 1.5) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while is_instance_valid(node):
		if Time.get_ticks_msec() > deadline:
			return false
		await process_frame
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)

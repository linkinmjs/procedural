extends SceneTree

## El zumbido de pantalla de los bloques: un loop sintetizado una sola vez,
## compartido, que suena desde que el bloque aparece y se corta al cerrarse o
## colgarse.

const BLOCK_SCENE := preload("res://scenes/targets/target_block_3d.tscn")


func _initialize() -> void:
	create_timer(15.0, true, false, true).timeout.connect(func() -> void: _fail("LED hum smoke test timed out."))
	_run.call_deferred()


func _run() -> void:
	var stream := LedHumSynth.get_stream()
	if stream == null or stream.loop_mode != AudioStreamWAV.LOOP_FORWARD:
		_fail("The hum should be a forward-looping WAV.")
		return
	var expected_samples := int(LedHumSynth.MIX_RATE * LedHumSynth.LOOP_SECONDS)
	if stream.data.size() != expected_samples * 2 or stream.loop_end != expected_samples:
		_fail("The hum loop should cover exactly %d 16-bit samples." % expected_samples)
		return
	if not is_equal_approx(stream.get_length(), LedHumSynth.LOOP_SECONDS):
		_fail("The hum loop should last %s s, got %s." % [LedHumSynth.LOOP_SECONDS, stream.get_length()])
		return
	if LedHumSynth.get_stream() != stream:
		_fail("The hum stream should be built once and shared.")
		return
	var growl := LedHumSynth.get_growl_stream()
	if growl == null or growl == stream or growl.loop_mode != AudioStreamWAV.LOOP_FORWARD or growl.data.size() != stream.data.size():
		_fail("The growl should be its own forward-looping loop of the same length.")
		return

	var block := BLOCK_SCENE.instantiate() as TargetBlock3D
	block.target_count = 0
	root.add_child(block)
	await process_frame
	if block.hum_player == null or block.hum_player.stream != stream:
		_fail("A block should carry the shared hum.")
		return
	if not block.hum_player.playing:
		_fail("The hum should play as soon as the block is up.")
		return
	if block.hum_player.bus != &"SFX":
		_fail("The hum should go through the SFX bus.")
		return
	if block.hum_player.max_distance <= 0.0 or block.hum_player.unit_size > 3.0:
		_fail("The hum must fade fast with distance: short unit_size and a max_distance cutoff.")
		return
	if block.growl_player == null or block.growl_player.stream != growl or not block.growl_player.playing:
		_fail("A block should carry the shared growl, already looping.")
		return
	if block.growl_player.max_distance > block.hum_player.max_distance or block.growl_player.volume_db > -40.0:
		_fail("The growl only lives near the block: shorter reach than the hum and silent until someone gets close.")
		return
	block.crash("test")
	await process_frame
	if block.hum_player.playing or block.growl_player.playing:
		_fail("A crashed block should cut its hum and its growl.")
		return
	block.queue_free()

	var closing := BLOCK_SCENE.instantiate() as TargetBlock3D
	closing.target_count = 0
	root.add_child(closing)
	await process_frame
	closing._close()
	if closing.hum_player.playing:
		_fail("A closed block should stop its hum before leaving.")
		return
	await process_frame
	print("LED hum smoke test passed.")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)

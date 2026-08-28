extends Node

## Vuelca a PNG tres actividades musicales: la escala guiada con dos notas ya
## tocadas, una triada en el teclado completo y un intervalo. Las actividades
## se configuran por codigo porque la configuracion tiene que estar cargada
## antes de add_child, igual que hace el volumen de spawn.

const ACTIVITY := preload("res://scenes/windows/music_activity_window.tscn")


func _ready() -> void:
	var scale := _spawn(MusicActivityCatalog.get_activity("escala-c-mayor-asc"), Vector3(0.0, 1.45, 0.0))
	var chord := _spawn(MusicActivityCatalog.get_activity("triadas-mayores"), Vector3(-2.85, -1.45, 0.0))
	var interval := _spawn(MusicActivityCatalog.get_activity("intervalos-basicos"), Vector3(2.85, -1.45, 0.0))
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	# Dos aciertos en la escala, para ver el progreso y la tecla que sigue.
	for note in ["C", "D"]:
		var body := scale.find_hit_body(MusicActivityWindow.NOTE_ZONE_PREFIX + note)
		if body != null:
			body.Hit_Successful(1.0)
			await get_tree().process_frame
	# Una nota del acorde y una equivocada, para ver los dos tintes.
	var chord_root := chord.find_hit_body(MusicActivityWindow.NOTE_ZONE_PREFIX + MusicTheory.note_name(int(chord.question.root)))
	if chord_root != null:
		chord_root.Hit_Successful(1.0)
	await get_tree().process_frame
	# Se espera a que terminen las animaciones de apertura antes de capturar.
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.save_png("res://.godot/music-activity.png") != OK:
		push_error("Could not save the music activity preview.")
		get_tree().quit(1)
		return
	print("Music activity visual smoke test passed: interval asks %s." % (interval.content.find_child("Prompt", true, false) as Label).text)
	get_tree().quit()


func _spawn(activity: Dictionary, at: Vector3) -> MusicActivityWindow:
	var window := ACTIVITY.instantiate() as MusicActivityWindow
	window.variant_config = activity
	window.position = at
	add_child(window)
	return window

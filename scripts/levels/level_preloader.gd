class_name LevelPreloader
extends RefCounted

## Precarga lo que un nivel va a pedir al construirse, repartido en frames para
## que el velo de carga avance y el navegador no se congele.
##
## Carga las escenas que PlayableLevel instancia, las texturas que sus salas
## declaran (asi TextureCatalog.get_material las encuentra en cache en vez de
## bloquear con load()) y sintetiza el zumbido de los bloques, que si no se
## calcula en el primer combate. Los recursos cargados se retienen en `held`
## mientras el que llamo conserve el precargador: la cache de recursos de Godot
## es debil y los soltaria antes de que el nivel los use.
##
## Sin hilos (la build Web no los tiene) load_threaded_request resuelve en el
## hilo que llama; por eso se trabaja por presupuesto de tiempo y no por
## cantidad: cuando un frame ya gasto su cuota se cede el siguiente. Lo que ya
## esta en cache no cuesta ni un frame.

const SCENES: Array[String] = [
	"res://scenes/levels/playable_level.tscn",
	"res://scenes/player/player_character.tscn",
	"res://scenes/props/radio.tscn",
	"res://scenes/environment/room_light.tscn",
]
## Milisegundos de carga por frame antes de ceder.
const FRAME_BUDGET_MSEC := 12

## Recursos ya cargados, retenidos hasta que se suelte el precargador.
var held: Array[Resource] = []


## Todo lo que un nivel necesita, escenas primero.
static func paths_for(level: Dictionary) -> PackedStringArray:
	var paths := PackedStringArray()
	for scene in SCENES:
		paths.append(scene)
	for path in TextureCatalog.paths_for_level(level):
		if not paths.has(path):
			paths.append(path)
	return paths


## Carga todo y avisa el progreso al velo, si hay uno.
func run(tree: SceneTree, level: Dictionary, veil: LoadingVeil = null) -> void:
	var paths := paths_for(level)
	var total := paths.size() + 1
	var frame_started := Time.get_ticks_msec()
	for index in paths.size():
		var path := paths[index]
		if not ResourceLoader.exists(path):
			continue
		if ResourceLoader.has_cached(path):
			held.append(load(path))
		else:
			ResourceLoader.load_threaded_request(path)
			while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				await tree.process_frame
				frame_started = Time.get_ticks_msec()
			var resource := ResourceLoader.load_threaded_get(path)
			if resource != null:
				held.append(resource)
		if veil != null and is_instance_valid(veil):
			veil.set_step(index + 1, total)
		if Time.get_ticks_msec() - frame_started >= FRAME_BUDGET_MSEC:
			await tree.process_frame
			frame_started = Time.get_ticks_msec()
	# El zumbido se sintetiza una sola vez por sesion: si ya esta, no cuesta.
	LedHumSynth.get_stream()
	LedHumSynth.get_growl_stream()
	if veil != null and is_instance_valid(veil):
		veil.set_step(total, total)

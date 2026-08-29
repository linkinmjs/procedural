class_name GameSettings
extends Node

## Ajustes del jugador: audio, idioma, pantalla, sensibilidad y el filtro de
## monitor del menu.
##
## El nodo se busca por su nombre de autoload, como el resto de los autoloads
## del proyecto; el `class_name` esta para poder leer sus constantes con tipado.
##
## Es el unico lugar que sabe donde se guardan y como se aplican. El menu de
## opciones solo pide cambios y lee valores; nadie mas toca AudioServer,
## TranslationServer ni DisplayServer.
##
## Cada cambio se aplica y se guarda en el momento. No hay boton de aceptar
## porque no hay nada que aceptar: el jugador escucha el volumen mientras lo
## mueve y ve el idioma cambiar mientras elige, asi que pedirle que confirme
## seria pedirle que confirme algo que ya vio.

signal locale_changed(locale: String)
signal sensitivity_changed(value: float)
signal crt_changed(enabled: bool)

const SETTINGS_PATH := "user://settings.cfg"

## Los buses de `default_bus_layout.tres`, en el orden en que se muestran.
const AUDIO_BUSES: Array[String] = ["Master", "Music", "SFX"]
## Los idiomas que el juego tiene traducidos, en el orden del selector.
const LOCALES: Array[String] = ["es", "pt", "en"]
## Resoluciones de ventana ofrecidas, de menor a mayor. En pantalla completa no
## se usan: ahi manda la del monitor.
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]

## Multiplicador crudo del movimiento del mouse. Los extremos son los que se
## sienten jugables: mas abajo la vista casi no responde y mas arriba se va.
const MIN_SENSITIVITY := 0.0002
const MAX_SENSITIVITY := 0.0030
const DEFAULT_SENSITIVITY := 0.0010
## De cuanto es cada paso de los controles del menu.
const SENSITIVITY_STEP := 0.0001
const VOLUME_STEP := 0.05
## Lo que se espera antes de escribir el archivo. Arrastrar un slider dispara un
## cambio por paso, y cada uno reescribia el archivo entero: veinte escrituras
## para mover el volumen de punta a punta, que en la exportacion web son veinte
## transacciones contra IndexedDB. Se guarda cuando el jugador deja de mover.
const SAVE_DELAY := 0.5

## Volumen lineal por bus, de 0.0 a 1.0.
var _volumes: Dictionary = {}
var _sensitivity := DEFAULT_SENSITIVITY
var _fullscreen := false
var _resolution := RESOLUTIONS[3]
## El monitor de tubo del menu principal (CrtOverlay). Se puede apagar: un
## filtro que cansa la vista no es un filtro que valga la pena.
var _crt := true
## Mientras se esta cargando no se guarda: si no, aplicar cada valor leido
## reescribiria el archivo una vez por linea.
var _loading := false
## Hay cambios aplicados que todavia no se escribieron.
var _dirty := false
var _save_timer: Timer


func _ready() -> void:
	_build_save_timer()
	for bus in AUDIO_BUSES:
		_volumes[bus] = 1.0
	_load()


## Cerrar el juego no puede perder lo ultimo que se toco. Al salir por la ventana
## el arbol se desarma y este nodo sale con el, asi que aca se escribe lo que
## quedo pendiente. En la web cerrar la pestania no avisa: para eso esta el
## retardo corto, que deja poco tiempo sin guardar.
func _exit_tree() -> void:
	flush()


func _build_save_timer() -> void:
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DELAY
	# Las opciones se abren desde la pausa, que detiene el arbol: sin esto el
	# guardado quedaria esperando a que el jugador vuelva al juego.
	_save_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_save_timer.timeout.connect(_write)
	add_child(_save_timer)


## Escribe ya lo que este pendiente, sin esperar el retardo.
func flush() -> void:
	if _dirty:
		_write()


## En el navegador el tamaño del lienzo lo decide la pagina que embebe el juego,
## asi que elegir una resolucion de ventana no tiene a donde aplicarse. Pantalla
## completa si funciona, porque el navegador la concede cuando sale de un clic.
func can_choose_resolution() -> bool:
	return not OS.has_feature("web")


# --- Audio -------------------------------------------------------------------

func get_volume(bus: String) -> float:
	return float(_volumes.get(bus, 1.0))


func set_volume(bus: String, value: float) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	_volumes[bus] = clamped
	var index := AudioServer.get_bus_index(bus)
	if index >= 0:
		# Silencio es mute y no -inf dB: a volumen cero el bus se apaga entero
		# en vez de quedar sonando por debajo de lo audible.
		AudioServer.set_bus_mute(index, is_zero_approx(clamped))
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(clamped, 0.0001)))
	_save()


# --- Idioma ------------------------------------------------------------------

func get_locale() -> String:
	return TranslationServer.get_locale().substr(0, 2)


## El idioma del sistema puede ser uno que el juego no habla. Ahi las traducciones
## caen al de respaldo y todo se lee bien, pero `get_locale()` seguiria diciendo
## el del sistema: el selector no sabria en que posicion esta parado y las dos
## flechas llevarian a idiomas distintos desde la misma pantalla.
func _normalize_locale() -> void:
	if not LOCALES.has(get_locale()):
		TranslationServer.set_locale(LOCALES[0])


func set_locale(locale: String) -> void:
	if not LOCALES.has(locale):
		return
	TranslationServer.set_locale(locale)
	_save()
	locale_changed.emit(locale)


# --- Sensibilidad ------------------------------------------------------------

func get_sensitivity() -> float:
	return _sensitivity


func set_sensitivity(value: float) -> void:
	_sensitivity = clampf(value, MIN_SENSITIVITY, MAX_SENSITIVITY)
	_save()
	sensitivity_changed.emit(_sensitivity)


## La sensibilidad se guarda cruda porque es lo que el jugador multiplica, pero
## se muestra de 0 a 100: nadie elige mirar 0.0012.
func get_sensitivity_percent() -> int:
	var span := MAX_SENSITIVITY - MIN_SENSITIVITY
	return roundi((_sensitivity - MIN_SENSITIVITY) / span * 100.0)


# --- Pantalla ----------------------------------------------------------------

func is_fullscreen() -> bool:
	return _fullscreen


func set_fullscreen(value: bool) -> void:
	_fullscreen = value
	_apply_screen()
	_save()


func get_resolution() -> Vector2i:
	return _resolution


func set_resolution(value: Vector2i) -> void:
	if not RESOLUTIONS.has(value):
		return
	_resolution = value
	_apply_screen()
	_save()


func _apply_screen() -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if _fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)
	if _fullscreen or not can_choose_resolution():
		return
	DisplayServer.window_set_size(_resolution)
	# Sin recentrar, agrandar la ventana la empuja fuera del monitor.
	var screen := DisplayServer.screen_get_size()
	DisplayServer.window_set_position((screen - _resolution) / 2)


# --- Monitor -----------------------------------------------------------------

func is_crt_enabled() -> bool:
	return _crt


func set_crt_enabled(value: bool) -> void:
	_crt = value
	_save()
	crt_changed.emit(_crt)


# --- Persistencia ------------------------------------------------------------

func _load() -> void:
	_loading = true
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		for bus in AUDIO_BUSES:
			set_volume(bus, float(config.get_value("audio", bus, 1.0)))
		var saved_locale := str(config.get_value("game", "locale", ""))
		if LOCALES.has(saved_locale):
			TranslationServer.set_locale(saved_locale)
		set_sensitivity(float(config.get_value("input", "sensitivity", DEFAULT_SENSITIVITY)))
		_fullscreen = bool(config.get_value("screen", "fullscreen", false))
		var saved_resolution: Variant = config.get_value("screen", "resolution", null)
		if saved_resolution is Vector2i and RESOLUTIONS.has(saved_resolution):
			_resolution = saved_resolution
		else:
			_resolution = _current_window_resolution()
		_crt = bool(config.get_value("screen", "crt", true))
		_apply_screen()
	else:
		# Primera partida: los volumenes ya estan al maximo y el idioma es el que
		# el sistema haya elegido. Solo la ventana necesita mirarse.
		_resolution = _current_window_resolution()
	# Va al final: tanto el idioma guardado como el del sistema pasan por aca, y
	# despues de esto `get_locale()` siempre devuelve uno que el juego habla.
	_normalize_locale()
	_loading = false


## La resolucion de arranque puede no estar en la lista, y forzar una de la lista
## al abrir el juego seria cambiarle la ventana a alguien que no pidio nada. Se
## elige la mas cercana solo para que el selector arranque en algo coherente.
func _current_window_resolution() -> Vector2i:
	var size := DisplayServer.window_get_size()
	var closest := RESOLUTIONS[0]
	for candidate in RESOLUTIONS:
		if absi(candidate.x - size.x) < absi(closest.x - size.x):
			closest = candidate
	return closest


## Marca que hay algo para guardar y reinicia la espera. Mientras el jugador
## sigue moviendo el slider la escritura se corre; se hace cuando para.
func _save() -> void:
	if _loading:
		return
	_dirty = true
	if _save_timer != null:
		_save_timer.start()


func _write() -> void:
	_dirty = false
	var config := ConfigFile.new()
	for bus in AUDIO_BUSES:
		config.set_value("audio", bus, get_volume(bus))
	config.set_value("game", "locale", get_locale())
	config.set_value("input", "sensitivity", _sensitivity)
	config.set_value("screen", "fullscreen", _fullscreen)
	config.set_value("screen", "resolution", _resolution)
	config.set_value("screen", "crt", _crt)
	config.save(SETTINGS_PATH)

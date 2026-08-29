class_name CrtOverlay
extends CanvasLayer

## El monitor de tubo del menu principal.
##
## Un ColorRect a pantalla completa con el shader crt_monitor, en una capa por
## encima de MenuStack: el escritorio y las ventanas que se abren sobre el se
## ven a traves del mismo vidrio. Al entrar al menu el tubo se enciende (una
## linea que se abre a lo ancho y se despliega a lo alto) y despues queda
## quieto con apenas lineas, viñeta y un parpadeo minimo.
##
## Es solo del menu: el nivel es el mundo de adentro de la PC, no la pantalla
## que lo muestra. Y se puede apagar desde las opciones, porque un filtro que
## cansa la vista no es un filtro que valga la pena.

signal powered_on

const GROUP := "crt_overlay"
## Por encima de MenuStack (128): las opciones y el selector de niveles se
## abren sobre el escritorio y tambien son parte del monitor.
const LAYER := 200
const SHADER := preload("res://assets/shaders/crt_monitor.gdshader")
## Tiempo que el tubo queda negro antes de que aparezca la linea, y lo que
## tarda en abrirse hasta la imagen completa.
const POWER_ON_DELAY := 0.15
const POWER_ON_SECONDS := 0.9
const PARAM_POWER_ON := &"power_on"

var _rect: ColorRect
var _material: ShaderMaterial
var _tween: Tween
var _powered_on := true
## Si el jugador apago el filtro en las opciones. Sin filtro no hay encendido:
## el escritorio aparece de una.
var _enabled := true


static func create() -> CrtOverlay:
	var overlay := CrtOverlay.new()
	overlay.name = "CrtOverlay"
	return overlay


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(GROUP)
	_build()
	var config := get_node_or_null("/root/Settings") as GameSettings
	if config != null:
		_enabled = config.is_crt_enabled()
		config.crt_changed.connect(set_enabled)
	_rect.visible = _enabled


## Enciende el tubo desde negro. Con el filtro apagado no hay nada que
## encender y el aviso llega en el acto.
func power_on() -> void:
	_stop()
	if not _enabled:
		_powered_on = true
		powered_on.emit()
		return
	_powered_on = false
	set_power_level(0.0)
	Sfx.play("desktop_boot")
	_tween = create_tween()
	_tween.set_ignore_time_scale(true)
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_interval(POWER_ON_DELAY)
	_tween.tween_method(set_power_level, 0.0, 1.0, POWER_ON_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_finish_power_on)


## Deja el tubo encendido del todo, sin animacion. Las pruebas visuales lo
## retratan asi.
func settle() -> void:
	_stop()
	_finish_power_on()


func is_powered_on() -> bool:
	return _powered_on


## Grado de encendido, de 0 (negro) a 1 (imagen completa).
func set_power_level(level: float) -> void:
	_material.set_shader_parameter(PARAM_POWER_ON, clampf(level, 0.0, 1.0))


func get_power_level() -> float:
	return float(_material.get_shader_parameter(PARAM_POWER_ON))


func is_enabled() -> bool:
	return _enabled


## Apagar el filtro oculta el rectangulo entero: sin el, el shader no corre y
## la pantalla no paga la copia del backbuffer.
func set_enabled(value: bool) -> void:
	_enabled = value
	_rect.visible = value
	if not value:
		settle()


func _finish_power_on() -> void:
	set_power_level(1.0)
	if _powered_on:
		return
	_powered_on = true
	powered_on.emit()


func _stop() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()


func _build() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_rect = ColorRect.new()
	_rect.name = "Screen"
	_rect.material = _material
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	# El vidrio no se interpone: los clics llegan al escritorio de abajo.
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
	set_power_level(1.0)

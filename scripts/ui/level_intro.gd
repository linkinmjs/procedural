class_name LevelIntro
extends CanvasLayer

## Presentacion del nivel: un velo oscuro con el titulo, que entra y se va.
##
## Existe para que empezar un nivel se sienta como empezar algo y no como un
## corte de escena. Dura poco a proposito: el modo es de puntaje y quien ya sabe
## a donde va no tiene que esperar a que una animacion termine, asi que
## cualquier tecla la saltea.
##
## Reintentar no la muestra. Esa decision vive en LevelSequence, que es quien
## sabe si se esta entrando al nivel o volviendo a empezar.

signal finished

## Sobre el HUD del nivel, que vive en capas bajas, y debajo de MenuStack, que
## esta en 128: si los resultados llegaran a solaparse, mandan ellos.
const LAYER := 64
## Poco mas de dos segundos en total. Alcanza para que el titulo se lea sin
## apuro y siga sin estorbarle a nadie, porque cualquier tecla lo saltea.
const FADE_IN := 0.5
const HOLD := 1.15
const FADE_OUT := 0.55
const VEIL_COLOR := Color(0.01, 0.02, 0.04, 1.0)
const TITLE_COLOR := Color(0.42, 0.9, 1, 1)
const SUBTITLE_COLOR := Color(0.55, 0.68, 0.78, 1)
const TITLE_FONT_SIZE := 52
const SUBTITLE_FONT_SIZE := 15
const RULE_SIZE := Vector2(160.0, 2.0)

var _veil: ColorRect
var _box: VBoxContainer
var _tween: Tween


static func create(title: String, subtitle := "") -> LevelIntro:
	var intro := LevelIntro.new()
	intro._build(title, subtitle)
	return intro


func _ready() -> void:
	layer = LAYER
	# Se ve aunque el arbol este detenido: si algo pausa el juego durante la
	# entrada, la presentacion no se queda congelada a medias en pantalla.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_play()


## Cualquier tecla o clic la saltea. El evento se consume: la tecla que saltea
## la presentacion no dispara ademas lo que sea que haga en el nivel.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventMouseButton) or not event.is_pressed():
		return
	get_viewport().set_input_as_handled()
	skip()


## Corta la presentacion y descubre el nivel de una vez.
func skip() -> void:
	_stop()
	_finish()


## Congela la presentacion con el titulo entero a la vista. Las pruebas
## visuales la retratan asi, sin depender de atinarle al reloj de la animacion.
func hold() -> void:
	_stop()
	_veil.color.a = VEIL_COLOR.a
	_box.modulate.a = 1.0


func _stop() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()


func _build(title: String, subtitle: String) -> void:
	_veil = ColorRect.new()
	_veil.color = VEIL_COLOR
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	# El velo tapa el nivel pero no lo bloquea: la presentacion es visual y no
	# se mete con lo que el jugador pueda estar haciendo debajo.
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.modulate = Color(1, 1, 1, 0)
	center.add_child(_box)

	var title_label := Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", TITLE_COLOR)
	title_label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	_box.add_child(title_label)

	# La misma raya cian que marca los paneles del HUD, para que la entrada al
	# nivel ya este hablando el idioma del juego.
	var rule := ColorRect.new()
	rule.color = TITLE_COLOR
	rule.custom_minimum_size = RULE_SIZE
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(rule)

	if subtitle.is_empty():
		return
	var subtitle_label := Label.new()
	subtitle_label.text = subtitle
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_color_override("font_color", SUBTITLE_COLOR)
	subtitle_label.add_theme_font_size_override("font_size", SUBTITLE_FONT_SIZE)
	_box.add_child(subtitle_label)


## El titulo entra sobre el velo, se sostiene, y despues se van los dos juntos:
## el nivel se descubre detras del texto en vez de aparecer de golpe.
func _play() -> void:
	_tween = create_tween()
	_tween.tween_property(_box, "modulate:a", 1.0, FADE_IN)
	_tween.tween_interval(HOLD)
	_tween.set_parallel(true)
	_tween.tween_property(_box, "modulate:a", 0.0, FADE_OUT)
	_tween.tween_property(_veil, "color:a", 0.0, FADE_OUT)
	_tween.set_parallel(false)
	_tween.tween_callback(_finish)


func _finish() -> void:
	finished.emit()
	queue_free()

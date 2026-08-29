class_name BootSequence
extends Control

## Arranque del juego: dos tarjetas y despues el escritorio.
##
## Es la escena con la que arranca el proyecto. La primera tarjeta es la misma
## imagen que el motor muestra como boot splash (project.godot la apunta), asi
## que del splash del motor a esta escena no hay corte: se sostiene un momento
## y se funde a negro. La segunda es la firma del estudio, tipeada en una
## terminal negra con el cursor titilando. Al terminar, la pantalla se corta a
## negro y el menu principal enciende el monitor.
##
## Cualquier tecla o clic saltea la tarjeta en curso; dos, el arranque entero.
## Volver al menu desde un nivel no pasa por aca: LevelSequence carga el menu
## directo.

signal card_changed(card: Card)
signal finished

enum Card { GODOT, STUDIO, DONE }

const MAIN_MENU_SCENE := "res://scenes/ui/menus/main_menu.tscn"
## Tambien es application/boot_splash/image en project.godot; el test de
## arranque lo verifica.
const GODOT_SPLASH_PATH := "res://assets/textures/ui/splash/godot_splash.png"
const GODOT_SPLASH := preload(GODOT_SPLASH_PATH)
## El fondo de la imagen (#242424), y application/boot_splash/bg_color: lo que
## la imagen no cubre en una ventana de otra proporcion se rellena con esto.
const GODOT_BACKGROUND := Color(0.141176, 0.141176, 0.141176, 1.0)
const GODOT_HOLD := 1.1
const GODOT_FADE := 0.3

const STUDIO_FONT := preload("res://assets/fonts/boot/Withheld Data.otf")
const STUDIO_FONT_SIZE := 64
const STUDIO_NAME := "OMINOSO"
const PROMPT := "C:\\>"
const CURSOR := "_"
const CURSOR_BLINK := 0.5
## Espera con el prompt solo antes de la primera letra, tiempo entre letras
## (mas un poco de azar, como alguien tipeando) y sostenido con el nombre
## completo antes del corte.
const STUDIO_PAUSE := 0.4
const TYPE_SECONDS := 0.075
const TYPE_JITTER := 0.035
const STUDIO_HOLD := 1.1
## Negro entre la terminal y el menu: el monitor se apaga antes de prenderse.
const CUT_SECONDS := 0.25

## Las pruebas visuales lo apagan para retratar cada tarjeta a mano.
@export var autoplay := true

var current_card := Card.GODOT

var _godot_card: Control
var _studio_card: Control
var _terminal: Label
var _typed := ""
var _cursor_visible := true
var _tween: Tween
var _cursor_tween: Tween
var _finished := false


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_build()
	if autoplay:
		show_card(Card.GODOT)


## Muestra una tarjeta y arranca su animacion. DONE corta a negro y carga el
## menu principal.
func show_card(card: Card) -> void:
	_stop()
	current_card = card
	_godot_card.visible = card == Card.GODOT
	_studio_card.visible = card == Card.STUDIO
	card_changed.emit(card)
	match card:
		Card.GODOT:
			_play_godot()
		Card.STUDIO:
			_play_studio()
		Card.DONE:
			_play_cut()


## Saltea la tarjeta en curso.
func skip() -> void:
	if _finished:
		return
	match current_card:
		Card.GODOT:
			show_card(Card.STUDIO)
		Card.STUDIO:
			show_card(Card.DONE)


## El nombre completo en la terminal, de una. Para las capturas.
func type_all() -> void:
	_stop()
	_typed = STUDIO_NAME
	_cursor_visible = true
	_refresh_terminal()


func is_typing_done() -> bool:
	return _typed == STUDIO_NAME


func terminal_text() -> String:
	return _terminal.text


## Cualquier tecla, boton del mando o clic. El evento se consume: la tecla
## que saltea el arranque no llega ademas al menu que viene despues.
func _unhandled_input(event: InputEvent) -> void:
	var is_press := event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton
	if not is_press or not event.is_pressed() or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	skip()


func _play_godot() -> void:
	_godot_card.modulate = Color.WHITE
	_tween = create_tween()
	_tween.tween_interval(GODOT_HOLD)
	_tween.tween_property(_godot_card, "modulate", Color.BLACK, GODOT_FADE)
	_tween.tween_callback(show_card.bind(Card.STUDIO))


func _play_studio() -> void:
	_typed = ""
	_cursor_visible = true
	_refresh_terminal()
	_start_cursor_blink()
	_tween = create_tween()
	_tween.tween_interval(STUDIO_PAUSE)
	for index in STUDIO_NAME.length():
		_tween.tween_callback(_type_next)
		_tween.tween_interval(TYPE_SECONDS + randf_range(-TYPE_JITTER, TYPE_JITTER))
	_tween.tween_callback(func() -> void: Sfx.play("boot_enter"))
	_tween.tween_interval(STUDIO_HOLD)
	_tween.tween_callback(show_card.bind(Card.DONE))


func _play_cut() -> void:
	_tween = create_tween()
	_tween.tween_interval(CUT_SECONDS)
	_tween.tween_callback(_finish)


func _type_next() -> void:
	if _typed.length() >= STUDIO_NAME.length():
		return
	_typed = STUDIO_NAME.substr(0, _typed.length() + 1)
	# Cada letra reinicia el cursor encendido, como en una terminal de verdad.
	_cursor_visible = true
	_start_cursor_blink()
	_refresh_terminal()
	Sfx.play("boot_key", randf_range(0.92, 1.08))


func _start_cursor_blink() -> void:
	if _cursor_tween != null and _cursor_tween.is_valid():
		_cursor_tween.kill()
	_cursor_tween = create_tween().set_loops()
	_cursor_tween.tween_interval(CURSOR_BLINK)
	_cursor_tween.tween_callback(_toggle_cursor)


func _toggle_cursor() -> void:
	_cursor_visible = not _cursor_visible
	_refresh_terminal()


## El espacio en lugar del cursor apagado mantiene el ancho: la linea no
## respira al titilar.
func _refresh_terminal() -> void:
	_terminal.text = PROMPT + _typed + (CURSOR if _cursor_visible else " ")


func _finish() -> void:
	if _finished:
		return
	_finished = true
	_stop()
	finished.emit()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _stop() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if _cursor_tween != null and _cursor_tween.is_valid():
		_cursor_tween.kill()


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Negro debajo de todo: las tarjetas se funden y se cortan sobre el.
	var black := ColorRect.new()
	black.name = "Black"
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)

	_godot_card = ColorRect.new()
	_godot_card.name = "GodotCard"
	(_godot_card as ColorRect).color = GODOT_BACKGROUND
	_godot_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_godot_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_godot_card.visible = false
	add_child(_godot_card)
	var splash := TextureRect.new()
	splash.name = "Splash"
	splash.texture = GODOT_SPLASH
	splash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	splash.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	splash.set_anchors_preset(Control.PRESET_FULL_RECT)
	splash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_godot_card.add_child(splash)

	_studio_card = CenterContainer.new()
	_studio_card.name = "StudioCard"
	_studio_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_studio_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_studio_card.visible = false
	add_child(_studio_card)
	_terminal = Label.new()
	_terminal.name = "Terminal"
	_terminal.add_theme_font_override("font", STUDIO_FONT)
	_terminal.add_theme_font_size_override("font_size", STUDIO_FONT_SIZE)
	_terminal.add_theme_color_override("font_color", Color.WHITE)
	_terminal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_studio_card.add_child(_terminal)
	_refresh_terminal()

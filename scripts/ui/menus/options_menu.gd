class_name OptionsMenu
extends MenuScreen

## Opciones: audio, idioma, pantalla, sensibilidad y el filtro de monitor.
##
## Se abre desde el escritorio y desde la pausa, asi que se dibuja con la piel
## que le pasen: de Windows en el menu principal, del juego durante la partida.
##
## Nada se aplica al aceptar porque no hay aceptar: cada cambio entra en el
## momento y `GameSettings` lo guarda. El jugador escucha el volumen mientras lo
## mueve y ve el idioma cambiar mientras elige; pedirle que confirme algo que ya
## vio pasar seria trabajo de mas para el y una pantalla mas para mantener.
##
## Los valores de lista se eligen con dos flechas y no con un desplegable: el
## desplegable arrastra un `PopupMenu` que habria que vestir en las dos pieles, y
## con botones el foco viaja con el teclado sin que haya que hacer nada.

const ROW_LABEL_WIDTH := 190.0
const SLIDER_WIDTH := 180.0
const VALUE_WIDTH := 120.0
const AMOUNT_WIDTH := 46.0
const ARROW_WIDTH := 34.0
const ROW_SEPARATION := 10

## Etiqueta de cada bus, en el orden de `GameSettings.AUDIO_BUSES`.
const BUS_LABELS := {
	"Master": "OPTIONS_VOLUME_MASTER",
	"Music": "OPTIONS_VOLUME_MUSIC",
	"SFX": "OPTIONS_VOLUME_SFX",
}
const LOCALE_LABELS := {
	"es": "OPTIONS_LOCALE_ES",
	"pt": "OPTIONS_LOCALE_PT",
	"en": "OPTIONS_LOCALE_EN",
}

## Resuelto una vez. Los sliders lo consultan en cada paso del arrastre, y
## `settings()` recorre el arbol desde la raiz en cada llamada.
var _config: GameSettings
var _sensitivity_value: Label
var _locale_value: Label
var _screen_value: Label
var _resolution_value: Label
var _crt_value: Label
var _resolution_arrows: Array[Button] = []
## El primer control que puede recibir foco, para que el teclado entre al menu
## por arriba y no por donde haya quedado.
var _first_control: Control


static func create(menu_skin: MenuSkin) -> OptionsMenu:
	var menu := OptionsMenu.new()
	menu.skin = menu_skin
	return menu


func _ready() -> void:
	_config = settings()
	build_window(tr("MENU_OPTIONS"))
	for bus_variant in GameSettings.AUDIO_BUSES:
		_add_volume_row(str(bus_variant))
	add_separator()
	_add_sensitivity_row()
	_add_locale_row()
	add_separator()
	_add_screen_rows()
	add_separator()
	add_button("MENU_BACK", close)
	set_default_focus(_first_control)


# --- Filas -------------------------------------------------------------------

func _add_volume_row(bus: String) -> void:
	var amount := _make_amount_label()
	amount.text = _percent(_config.get_volume(bus))

	var slider := _make_slider(0.0, 1.0, GameSettings.VOLUME_STEP, _config.get_volume(bus))
	slider.value_changed.connect(func(value: float) -> void:
		_config.set_volume(bus, value)
		amount.text = _percent(value)
	)
	var controls: Array[Control] = [slider, amount]
	_add_row(str(BUS_LABELS.get(bus, bus)), controls)


func _add_sensitivity_row() -> void:
	_sensitivity_value = _make_amount_label()
	_sensitivity_value.text = str(_config.get_sensitivity_percent())

	var slider := _make_slider(
		GameSettings.MIN_SENSITIVITY,
		GameSettings.MAX_SENSITIVITY,
		GameSettings.SENSITIVITY_STEP,
		_config.get_sensitivity(),
	)
	slider.value_changed.connect(func(value: float) -> void:
		_config.set_sensitivity(value)
		_sensitivity_value.text = str(_config.get_sensitivity_percent())
	)
	var controls: Array[Control] = [slider, _sensitivity_value]
	_add_row("OPTIONS_SENSITIVITY", controls)


func _add_locale_row() -> void:
	_locale_value = _make_value_label()
	_add_row("OPTIONS_LOCALE", _make_chooser(_locale_value, _cycle_locale))
	_refresh_locale()


func _add_screen_rows() -> void:
	_screen_value = _make_value_label()
	_add_row("OPTIONS_SCREEN", _make_chooser(_screen_value, _cycle_screen))
	_refresh_screen()

	_resolution_value = _make_value_label()
	var controls := _make_chooser(_resolution_value, _cycle_resolution)
	for control in controls:
		var arrow := control as Button
		if arrow != null:
			_resolution_arrows.append(arrow)
	_add_row("OPTIONS_RESOLUTION", controls)
	_refresh_resolution()

	_crt_value = _make_value_label()
	_add_row("OPTIONS_CRT", _make_chooser(_crt_value, _cycle_crt))
	_refresh_crt()


# --- Cambios -----------------------------------------------------------------

## Cambiar el idioma redibuja este mismo menu: los textos que son claves los
## retraduce Godot solo, pero los que se armaron con format() ya son frases
## hechas y hay que reescribirlos a mano.
func _cycle_locale(step: int) -> void:
	var locales: Array = GameSettings.LOCALES
	var index := locales.find(_config.get_locale())
	_config.set_locale(str(locales[wrapi(index + step, 0, locales.size())]))
	_refresh_locale()
	_refresh_screen()
	_refresh_resolution()
	_refresh_crt()
	set_window_title(tr("MENU_OPTIONS"))


func _cycle_screen(_step: int) -> void:
	_config.set_fullscreen(not _config.is_fullscreen())
	_refresh_screen()
	_refresh_resolution()


func _cycle_resolution(step: int) -> void:
	var resolutions: Array = GameSettings.RESOLUTIONS
	var index := resolutions.find(_config.get_resolution())
	_config.set_resolution(resolutions[wrapi(index + step, 0, resolutions.size())])
	_refresh_resolution()


func _refresh_locale() -> void:
	_locale_value.text = tr(str(LOCALE_LABELS.get(_config.get_locale(), "OPTIONS_LOCALE_ES")))


func _refresh_screen() -> void:
	_screen_value.text = tr("OPTIONS_SCREEN_FULL" if _config.is_fullscreen() else "OPTIONS_SCREEN_WINDOW")


## Encendido o apagado: las dos flechas hacen lo mismo. El monitor del menu
## esta detras de esta misma ventana, asi que el cambio se ve en el acto.
func _cycle_crt(_step: int) -> void:
	_config.set_crt_enabled(not _config.is_crt_enabled())
	_refresh_crt()


func _refresh_crt() -> void:
	_crt_value.text = tr("OPTIONS_ON" if _config.is_crt_enabled() else "OPTIONS_OFF")


## En el navegador el tamaño del lienzo lo decide la pagina, y en pantalla
## completa lo decide el monitor: en los dos casos la fila queda a la vista pero
## apagada, para que se vea que el ajuste existe y por que no se puede tocar.
func _refresh_resolution() -> void:
	var available := _config.can_choose_resolution() and not _config.is_fullscreen()
	for arrow in _resolution_arrows:
		arrow.disabled = not available
	if not _config.can_choose_resolution():
		_resolution_value.text = tr("OPTIONS_RESOLUTION_CANVAS")
	elif _config.is_fullscreen():
		_resolution_value.text = tr("OPTIONS_RESOLUTION_NATIVE")
	else:
		var size := _config.get_resolution()
		_resolution_value.text = tr("OPTIONS_RESOLUTION_VALUE").format({"width": size.x, "height": size.y})
	_resolution_value.add_theme_color_override("font_color", text_color() if available else muted_color())


# --- Piezas ------------------------------------------------------------------

## Etiqueta a la izquierda, controles a la derecha. Todas las filas comparten el
## ancho de la etiqueta para que los controles queden alineados en columna.
func _add_row(label_key: String, controls: Array[Control]) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ROW_SEPARATION)

	var label := Label.new()
	label.text = label_key
	label.custom_minimum_size = Vector2(ROW_LABEL_WIDTH, 0.0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", text_color())
	label.add_theme_font_size_override("font_size", 13)
	row.add_child(label)

	for control in controls:
		row.add_child(control)
		if _first_control == null and control.focus_mode != Control.FOCUS_NONE:
			_first_control = control
	content.add_child(row)


func _make_slider(minimum: float, maximum: float, step: float, value: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(SLIDER_WIDTH, 0.0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return slider


func _make_value_label() -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(VALUE_WIDTH, 0.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", text_color())
	return label


## El numero que acompaña a un slider: angosto, alineado a la derecha y apagado,
## porque lo que se mira es la barra y no la cifra.
func _make_amount_label() -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(AMOUNT_WIDTH, 0.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", muted_color())
	return label


## Un valor entre dos flechas. `on_step` recibe -1 o 1 y decide que significa
## moverse en esa direccion.
func _make_chooser(value: Label, on_step: Callable) -> Array[Control]:
	return [_make_arrow("<", on_step.bind(-1)), value, _make_arrow(">", on_step.bind(1))]


func _make_arrow(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(ARROW_WIDTH, 0.0)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(on_pressed)
	return button


func _percent(value: float) -> String:
	return tr("OPTIONS_PERCENT").format({"percent": roundi(value * 100.0)})

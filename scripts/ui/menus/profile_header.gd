class_name ProfileHeader
extends VBoxContainer

## Cabecera del perfil: nivel de jugador, barra de XP y cuanto falta.
##
## Es el marcador "siempre visible" del jugador: va arriba de la ventana del
## menu principal y abre la vitrina de Mi PC, y se repite dentro de la vitrina.
## Se redibuja sola cuando el perfil cambia.

const BAR_HEIGHT := 10.0
const DESKTOP_TRACK := Color(0.85, 0.85, 0.82)
const DESKTOP_TRACK_BORDER := Color(0.53, 0.53, 0.51)
const DESKTOP_FILL := Color(0.2, 0.4, 0.78)

var _profile: GameProfile
var _desktop := false
var _title: Control
var _bar: ProgressBar
var _detail: Label


static func create(profile: GameProfile, on_desktop: bool, text_color: Color, muted_color: Color, on_pressed := Callable()) -> ProfileHeader:
	var header := ProfileHeader.new()
	header._profile = profile
	header._desktop = on_desktop
	header._build(text_color, muted_color, on_pressed)
	return header


func _build(text_color: Color, muted_color: Color, on_pressed: Callable) -> void:
	add_theme_constant_override("separation", 3)
	if _profile == null:
		visible = false
		return
	if on_pressed.is_valid():
		var button := Button.new()
		button.flat = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 13)
		button.add_theme_color_override("font_color", text_color)
		button.add_theme_color_override("font_hover_color", text_color)
		button.add_theme_color_override("font_focus_color", text_color)
		button.add_theme_color_override("font_pressed_color", text_color)
		button.pressed.connect(on_pressed)
		_title = button
	else:
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", text_color)
		_title = label
	add_child(_title)

	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.max_value = 1.0
	_bar.step = 0.001
	_bar.custom_minimum_size = Vector2(0.0, BAR_HEIGHT)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_theme_stylebox_override("background", _track_style())
	_bar.add_theme_stylebox_override("fill", _fill_style())
	add_child(_bar)

	_detail = Label.new()
	_detail.add_theme_font_size_override("font_size", 11)
	_detail.add_theme_color_override("font_color", muted_color)
	add_child(_detail)

	refresh()
	_profile.xp_changed.connect(func(_total: int, _delta: int, _reason: String) -> void: refresh())
	_profile.profile_changed.connect(refresh)


func refresh() -> void:
	if _profile == null or not is_instance_valid(_profile):
		return
	var progress := _profile.get_progress()
	var title := tr("PROFILE_LEVEL_LINE").format({"level": int(progress.level), "name": str(progress.name)})
	if _title is Button:
		(_title as Button).text = title
	elif _title is Label:
		(_title as Label).text = title
	_bar.value = float(progress.ratio)
	_detail.text = "%s   %s" % [
		tr("PROFILE_XP_LINE").format({"current": ScoreBreakdown.thousands(int(progress.current)), "needed": ScoreBreakdown.thousands(int(progress.needed))}),
		tr("PROFILE_NEXT").format({"xp": ScoreBreakdown.thousands(int(progress.remaining)), "name": str(progress.next_name)}),
	]


func _track_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = DESKTOP_TRACK if _desktop else HudStyle.BAR_BG
	style.border_color = DESKTOP_TRACK_BORDER if _desktop else HudStyle.BAR_BORDER
	style.set_border_width_all(1)
	return style


func _fill_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = DESKTOP_FILL if _desktop else HudStyle.ACCENT
	return style

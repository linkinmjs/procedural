class_name BadgeTile
extends VBoxContainer

## Un logro en la vitrina: icono arriba, nombre abajo.
##
## Los no ganados se ven en gris y con su nombre, para que se sepa que existe
## algo por ganar; los sorpresa esconden ademas el nombre hasta caer. El
## tooltip cuenta que hay que hacer y, si ya se gano, cuando.
##
## Los iconos reusan los del pack de Windows XP por ahora: el arte propio de
## cada logro esta anotado como deuda.

const ICONS := {
	AchievementCatalog.ICON_STAR: preload("res://assets/textures/ui/xp/icons/star.png"),
	AchievementCatalog.ICON_FOLDER: preload("res://assets/textures/ui/xp/icons/folder.png"),
	AchievementCatalog.ICON_GEAR: preload("res://assets/textures/ui/xp/icons/gear.png"),
	AchievementCatalog.ICON_COMPUTER: preload("res://assets/textures/ui/xp/icons/computer.png"),
	AchievementCatalog.ICON_RECYCLE: preload("res://assets/textures/ui/xp/icons/recycle.png"),
	AchievementCatalog.ICON_POWER: preload("res://assets/textures/ui/xp/icons/power.png"),
}

const CELL_WIDTH := 86.0
const ICON_SIZE := Vector2(32.0, 32.0)
const LOCKED_MODULATE := Color(0.55, 0.55, 0.55, 1.0)
const NAME_FONT_SIZE := 10

var badge: Dictionary = {}
var earned := false


static func icon_for(icon_name: String) -> Texture2D:
	return ICONS.get(icon_name, ICONS[AchievementCatalog.ICON_STAR]) as Texture2D


static func create(entry: Dictionary, text_color: Color, muted_color: Color) -> BadgeTile:
	var tile := BadgeTile.new()
	tile.badge = entry
	tile.earned = bool(entry.get("earned", false))
	tile._build(text_color, muted_color)
	return tile


func _build(text_color: Color, muted_color: Color) -> void:
	custom_minimum_size = Vector2(CELL_WIDTH, 0.0)
	add_theme_constant_override("separation", 2)
	var hidden := AchievementCatalog.is_hidden(badge) and not earned

	var image := TextureRect.new()
	image.texture = icon_for(str(badge.get("icon", "")))
	image.custom_minimum_size = ICON_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(image)

	var label := Label.new()
	label.text = tr("PROFILE_HIDDEN_NAME") if hidden else AchievementCatalog.display_name(badge)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(CELL_WIDTH, 0.0)
	label.add_theme_font_size_override("font_size", NAME_FONT_SIZE)
	label.add_theme_color_override("font_color", text_color if earned else muted_color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

	if not earned:
		modulate = LOCKED_MODULATE
	tooltip_text = _tooltip(hidden)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _tooltip(hidden: bool) -> String:
	var description := tr("PROFILE_HIDDEN_DESC") if hidden else AchievementCatalog.description(badge)
	if earned:
		return "%s\n%s" % [description, tr("PROFILE_EARNED_AT").format({"date": format_date(int(badge.get("earned_at", 0)))})]
	return "%s\n%s" % [description, tr("PROFILE_LOCKED")]


static func format_date(unix: int) -> String:
	if unix <= 0:
		return ""
	var date := Time.get_datetime_dict_from_unix_time(unix)
	return "%02d/%02d %02d:%02d" % [int(date.day), int(date.month), int(date.hour), int(date.minute)]

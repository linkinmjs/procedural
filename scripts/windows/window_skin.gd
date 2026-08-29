class_name WindowSkin
extends RefCounted

## Re-viste el chrome de una ventana con otra skin: tema, marco, barra de
## titulo y boton de cerrar. La skin es estetica pura — los Controls, las zonas
## y el layout de la familia no se tocan — asi que cualquier familia puede
## verse Windows XP o Retro 97 sin duplicar su escena.
##
## Las escenas usan dos estructuras de chrome y las dos se entienden:
## - XP: `Body` (NinePatchRect de cuerpo) + `TitleBar` (NinePatchRect de barra).
## - Retro: `Frame` (un solo NinePatchRect con la barra horneada arriba).
## Al pasar a retro, el cuerpo y la barra salen de regiones de ese mismo marco;
## al pasar a XP sobre una escena retro, la barra que falta se crea.
##
## Las claves de SKINS tienen que coincidir con SKINS en
## tools/level-editor/window-format.js (hay un test de paridad).

## El marco retro es 48x48 con la barra horneada en los 25 px de arriba.
const RETRO_BAR_HEIGHT := 25.0

const SKINS := {
	"xp": {
		"theme": preload("res://resources/themes/xp_theme.tres"),
		"body_texture": preload("res://assets/textures/ui/xp/window_body.png"),
		"body_region": Rect2(),
		"body_margins": [5, 0, 5, 5],
		"titlebar_texture": preload("res://assets/textures/ui/xp/titlebar_active.png"),
		"titlebar_region": Rect2(),
		"titlebar_margins": [7, 8, 7, 2],
		"titlebar_height": 29.0,
		"close_texture": preload("res://assets/textures/ui/xp/close_button.png"),
		# La X de XP es un boton completo dibujado (rojo, con borde): sobre un
		# Button se muestra pelada, sin el estilo del theme abajo.
		"close_is_full_button": true,
	},
	"retro": {
		"theme": preload("res://resources/themes/retro_theme.tres"),
		"body_texture": preload("res://assets/textures/ui/retro/window_frame.png"),
		"body_region": Rect2(0.0, RETRO_BAR_HEIGHT, 48.0, 48.0 - RETRO_BAR_HEIGHT),
		"body_margins": [3, 3, 3, 3],
		"titlebar_texture": preload("res://assets/textures/ui/retro/window_frame.png"),
		"titlebar_region": Rect2(0.0, 0.0, 48.0, RETRO_BAR_HEIGHT),
		"titlebar_margins": [3, 3, 3, 2],
		"titlebar_height": RETRO_BAR_HEIGHT,
		# La X retro es solo el glifo: sobre un Button conserva el estilo gris
		# del theme abajo, como en las escenas retro de fabrica.
		"close_texture": preload("res://assets/textures/ui/retro/icon_close.png"),
		"close_is_full_button": false,
	},
}


static func has_skin(skin_id: String) -> bool:
	return SKINS.has(skin_id)


## Aplica la skin sobre el Control raiz de la ventana (el hijo del SubViewport).
## Se llama antes de generar las zonas, pero como no mueve ningun Control daria
## lo mismo despues.
static func apply(content: Control, skin_id: String) -> void:
	if not SKINS.has(skin_id):
		push_warning("Unknown window skin '%s'; keeping the scene skin." % skin_id)
		return
	var skin: Dictionary = SKINS[skin_id]
	content.theme = skin.theme
	var body := _find_first(content, ["Body", "Frame"]) as NinePatchRect
	if body != null:
		_restyle_patch(body, skin.body_texture, skin.body_region, skin.body_margins)
	var titlebar := content.get_node_or_null("TitleBar") as NinePatchRect
	if titlebar == null:
		titlebar = content.get_node_or_null("SkinTitleBar") as NinePatchRect
	# Una escena retro no trae barra propia: se crea sobre el cuerpo, y las
	# etiquetas y la X — que en esa estructura son hermanas posteriores — se
	# dibujan encima solas.
	if titlebar == null and body != null:
		titlebar = NinePatchRect.new()
		titlebar.name = "SkinTitleBar"
		titlebar.set_anchors_preset(Control.PRESET_TOP_WIDE)
		content.add_child(titlebar)
		content.move_child(titlebar, body.get_index() + 1)
	if titlebar != null:
		_restyle_patch(titlebar, skin.titlebar_texture, skin.titlebar_region, skin.titlebar_margins)
		titlebar.offset_bottom = float(skin.titlebar_height)
	for node in _close_controls(content):
		if node is TextureRect:
			var close_rect := node as TextureRect
			close_rect.texture = skin.close_texture
			_style_close_rect(close_rect, bool(skin.close_is_full_button))
		elif node is Button and (node as Button).icon != null:
			var button := node as Button
			button.icon = skin.close_texture
			# La X "boton completo" se dibuja a tamaño natural y sin estilo del
			# theme abajo. Nada de expand_icon: encoge el icono al area de
			# contenido del stylebox, que en un boton tan chico queda en cero.
			button.flat = bool(skin.close_is_full_button)
			if bool(skin.close_is_full_button):
				button.add_theme_constant_override("icon_max_width", 0)
				for style in ["normal", "hover", "pressed", "focus", "disabled"]:
					button.add_theme_stylebox_override(style, StyleBoxEmpty.new())


## La X de XP es un boton completo dibujado en la textura: llena su recuadro y
## no necesita nada detras. La retro es solo el glifo, que en las escenas
## retro de fabrica va sobre un boton gris del theme; sobre la barra azul
## oscura, el glifo negro pelado desaparecia y la X — que en casi todas las
## familias es la zona que mejor paga — parecia no existir. Aca se le dibuja
## ese mismo boton gris detras, y el glifo (10x11) queda centrado en vez de
## estirado al recuadro.
static func _style_close_rect(rect: TextureRect, full_button: bool) -> void:
	var parent := rect.get_parent() as Control
	if parent == null:
		return
	var backing := parent.get_node_or_null(NodePath(rect.name + "SkinBacking")) as NinePatchRect
	if full_button:
		rect.stretch_mode = TextureRect.STRETCH_SCALE
		if backing != null:
			backing.visible = false
		return
	rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	if backing == null:
		backing = NinePatchRect.new()
		backing.name = rect.name + "SkinBacking"
		backing.texture = preload("res://assets/textures/ui/retro/button_normal.png")
		backing.patch_margin_left = 3
		backing.patch_margin_top = 3
		backing.patch_margin_right = 3
		backing.patch_margin_bottom = 3
		backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(backing)
	backing.visible = true
	# Justo detras de la X, con su mismo recuadro (los offsets siguen a la
	# variante si esta redimensiono la ventana).
	parent.move_child(backing, rect.get_index())
	backing.anchor_left = rect.anchor_left
	backing.anchor_top = rect.anchor_top
	backing.anchor_right = rect.anchor_right
	backing.anchor_bottom = rect.anchor_bottom
	backing.offset_left = rect.offset_left
	backing.offset_top = rect.offset_top
	backing.offset_right = rect.offset_right
	backing.offset_bottom = rect.offset_bottom


## Los controles que dibujan la X. En las escenas XP la de la barra se llama
## CloseZone o TitleClose (en el error critico es una trampa, pero la X se ve
## igual); en las retro es un Button con icono.
static func _close_controls(content: Control) -> Array[Node]:
	var found: Array[Node] = []
	for node_name in ["CloseZone", "TitleClose"]:
		found.append_array(content.find_children(node_name, "", true, false))
	return found


static func _restyle_patch(patch: NinePatchRect, texture: Texture2D, region: Rect2, margins: Array) -> void:
	patch.texture = texture
	patch.region_rect = region
	patch.patch_margin_left = int(margins[0])
	patch.patch_margin_top = int(margins[1])
	patch.patch_margin_right = int(margins[2])
	patch.patch_margin_bottom = int(margins[3])


static func _find_first(content: Control, names: Array[String]) -> Node:
	for node_name in names:
		var found := content.get_node_or_null(NodePath(node_name))
		if found != null:
			return found
	return null

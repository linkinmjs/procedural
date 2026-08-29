class_name LoadingVeil
extends CanvasLayer

## Velo de carga entre "Jugar" y el nivel: una pantalla opaca con el texto
## "Preparando nivel" y una barra de progreso que cuelga de la raiz del arbol,
## asi sobrevive al cambio de escena y tapa tanto la precarga de recursos como
## la construccion del nivel y su primer frame (donde se evalua la geometria y
## se compilan los shaders, lo que en Web se sentia como un congelamiento).
##
## Lo crea LevelSequence antes de cargar y lo libera PlayableLevel cuando el
## nivel esta construido. Si ya hay uno en pantalla se reutiliza.

signal released

const GROUP := "loading_veil"
## Debajo de LevelIntro (64) y de MenuStack (128): la presentacion del nivel
## toma el relevo del velo sin que se vea el nivel entre uno y otra.
const LAYER := 63
const VEIL_COLOR := Color(HudStyle.VEIL, 1.0)
const TITLE_COLOR := HudStyle.ACCENT
const TITLE_FONT_SIZE := 22
const BAR_SIZE := Vector2(260.0, 6.0)
const FADE_OUT := 0.25

var _veil: ColorRect
var _box: VBoxContainer
var _label: Label
var _bar: ProgressBar
var _tween: Tween
var _finishing := false


## El velo que ya esta en pantalla, o uno nuevo colgado de la raiz.
static func acquire(tree: SceneTree) -> LoadingVeil:
	var existing := tree.get_first_node_in_group(GROUP) as LoadingVeil
	if existing != null:
		existing.reset()
		return existing
	var veil := LoadingVeil.new()
	tree.root.add_child(veil)
	return veil


## El velo en pantalla, si hay uno.
static func current(tree: SceneTree) -> LoadingVeil:
	return tree.get_first_node_in_group(GROUP) as LoadingVeil


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(GROUP)
	_build()


## Vuelve a dejarlo opaco y en cero, por si se lo reutiliza a mitad de un
## fundido de salida.
func reset() -> void:
	_stop()
	_finishing = false
	_veil.color = VEIL_COLOR
	_box.modulate.a = 1.0
	set_step(0, 1)


## Progreso visible: paso `index` de `total`, con el texto que corresponda.
func set_step(index: int, total: int, text_key := "LOADING_LEVEL") -> void:
	_label.text = tr(text_key)
	_bar.max_value = maxf(float(total), 1.0)
	_bar.value = clampf(float(index), 0.0, _bar.max_value)


## Se desvanece y se va. Con `fade` en cero desaparece al instante.
func finish(fade := FADE_OUT) -> void:
	if _finishing:
		return
	_finishing = true
	_stop()
	if fade <= 0.0:
		_release()
		return
	_tween = create_tween()
	_tween.set_ignore_time_scale(true)
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.set_parallel(true)
	_tween.tween_property(_veil, "color:a", 0.0, fade)
	_tween.tween_property(_box, "modulate:a", 0.0, fade)
	_tween.set_parallel(false)
	_tween.tween_callback(_release)


## Espera `frames` frames dibujados y recien entonces se desvanece: el nivel
## ya construido necesita un par de frames tapados para evaluar su geometria y
## compilar sus shaders sin que se vea el tiron.
func release_after_frames(frames: int, fade := FADE_OUT) -> void:
	for _index in frames:
		await get_tree().process_frame
		if not is_inside_tree():
			return
	finish(fade)


func _release() -> void:
	released.emit()
	queue_free()


func _stop() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()


func _build() -> void:
	_veil = ColorRect.new()
	_veil.color = VEIL_COLOR
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Mientras se carga no hay nada que clickear debajo: el velo se queda con
	# los eventos para que un click impaciente no llegue al nivel a medio armar.
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_veil)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 12)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_box)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_color", TITLE_COLOR)
	_label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	_box.add_child(_label)

	_bar = ProgressBar.new()
	_bar.custom_minimum_size = BAR_SIZE
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_bar.show_percentage = false
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = HudStyle.BAR_BG
	background.border_color = HudStyle.BAR_BORDER
	background.set_border_width_all(1)
	var fill := StyleBoxFlat.new()
	fill.bg_color = HudStyle.HEALTH_FILL
	_bar.add_theme_stylebox_override("background", background)
	_bar.add_theme_stylebox_override("fill", fill)
	_box.add_child(_bar)
	set_step(0, 1)

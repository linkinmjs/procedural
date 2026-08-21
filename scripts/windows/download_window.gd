class_name DownloadWindow
extends WindowPanel3D

## Descarga: una barra que avanza sola y no se cancela de un tiro.
##
## Es la familia que cobra el apuro, y lo cobra en las dos direcciones. Esperar
## a que termine sale barato en munición —un disparo a Finalizar— pero cuesta
## tiempo y paga poco. Cancelarla cuesta dos disparos, porque abre la
## confirmación, pero paga mucho más. La diferencia sale de `score_settings.tres`
## sin cablear nada: `finish` vale 60 y el `cancel` mas el `close` de la
## confirmación suman 160.
##
## La variante infectada no se puede dejar terminar: al completarse tumba el
## bloque entero. Ahí no hay negociación de puntos, hay que cancelarla.

## Zona que abre la confirmación en vez de cerrar.
const CANCEL_ZONE := "cancel"
## Zona de la confirmación. Es la que cierra por la via rapida y la que paga.
const CONFIRM_ZONE := "close"
## Zona que aparece cuando la descarga llego al final. Cierra, pero paga menos.
const FINISH_ZONE := "finish"

## Cuanto tarda la descarga en completarse, en segundos.
@export_range(2.0, 60.0, 0.5) var download_seconds := 12.0
## Si el archivo esta infectado. Al completarse no se cierra: tumba el bloque.
@export var infected := false

var _progress := 0.0
var _confirming := false
var _completed := false
var _progress_bar: ProgressBar
var _confirm_dialog: Control
var _finish_button: Control


func _ready() -> void:
	super()
	window_label = "descarga infectada" if infected else "descarga"
	# Se resuelven aca y no con @onready: `content` lo asigna el padre dentro de
	# su _ready(), y un @onready correria antes y encontraria nada.
	_progress_bar = _find_control("Progress") as ProgressBar
	_confirm_dialog = _find_control("ConfirmDialog")
	_finish_button = _find_control("FinishZone")
	if _confirm_dialog != null:
		_confirm_dialog.visible = false
	if _finish_button != null:
		_finish_button.visible = false
	zone_hit.connect(_on_zone)


func _process(delta: float) -> void:
	if _completed or _confirming:
		return
	_progress += delta / maxf(download_seconds, 0.1)
	if _progress_bar != null:
		_progress_bar.value = clampf(_progress, 0.0, 1.0) * _progress_bar.max_value
	if _progress >= 1.0:
		_complete()


## Cancelar no cierra: pregunta. La confirmacion detiene la barra, asi que el
## jugador que empezo a cancelar no pierde la ventana mientras decide.
func _on_zone(zone_id: String, _window: WindowPanel3D) -> void:
	if zone_id != CANCEL_ZONE or _confirming or _completed:
		return
	_confirming = true
	if _confirm_dialog != null:
		_confirm_dialog.visible = true
	# El dialogo aparecio recien: sus zonas todavia no tienen cuerpo disparable.
	await get_tree().process_frame
	rebuild_hit_zones()


## La descarga llego al final. La sana se queda pidiendo un ultimo disparo en
## Finalizar; la infectada ya no se puede resolver y tumba el bloque.
func _complete() -> void:
	if _completed:
		return
	_completed = true
	set_process(false)
	if infected:
		_crash_block()
		return
	_show_finish()


## Cambia los controles por el boton de finalizar: cancelar ya no tiene sentido
## cuando la descarga termino, y dejarlo seria ofrecer los puntos de la via
## rapida sin haberla tomado a tiempo.
func _show_finish() -> void:
	if _confirm_dialog != null:
		_confirm_dialog.visible = false
	for zone in _body_zones():
		zone.visible = zone == _finish_button
	if _finish_button != null:
		_finish_button.visible = true
	await get_tree().process_frame
	rebuild_hit_zones()


## Avisa que infecto el sistema. Quien la contenga —el bloque— decide que hacer.
## Sin nadie escuchando, se comporta como la variante sana: una ventana suelta no
## puede quedarse sin forma de resolverse.
func _crash_block() -> void:
	if system_crashed.get_connections().is_empty():
		infected = false
		_show_finish()
		return
	system_crashed.emit(self)


## Los controles del cuerpo de la ventana. La barra de titulo queda afuera: sigue
## sirviendo para traer la ventana al frente aunque la descarga haya terminado.
func _body_zones() -> Array[WindowHitZone]:
	var zones: Array[WindowHitZone] = []
	if content == null:
		return zones
	for child in content.get_children():
		var zone := child as WindowHitZone
		if zone != null and zone.zone_id != RAISE_ZONE:
			zones.append(zone)
	return zones


func _find_control(node_name: String) -> Control:
	if content == null:
		return null
	var found := content.find_child(node_name, true, false)
	return found as Control

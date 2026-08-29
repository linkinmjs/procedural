class_name WindowPanel3D
extends Node3D

## Ventana estilo Windows renderizada en 3D.
##
## El contenido se dibuja como UI normal dentro del SubViewport y se proyecta
## sobre un quad. Cada Control con el script WindowHitZone genera un cuerpo
## disparable en la misma posicion, para que el jugador pueda cerrarla apuntando
## a la X, a un boton o a un cartel.

signal zone_hit(zone_id: String, window: WindowPanel3D)
signal closed(window: WindowPanel3D)
## Le pegaron mientras estaba protegida: el disparo no le hizo nada.
signal blocked(window: WindowPanel3D)
## Paso al frente de sus hermanas.
signal raised(window: WindowPanel3D)
## La ventana infecto el sistema: quien la contenga decide que hacer. Va por
## señal y no buscando al bloque hacia arriba para no atar la ventana al bloque:
## el bloque conoce al catalogo de ventanas, asi que la ventana no puede conocer
## al bloque sin cerrar un ciclo.
signal system_crashed(window: WindowPanel3D)

const HIT_ZONE_DEPTH := 0.06
## Cuanto se adelanta cada zona respecto de la anterior. Las zonas se superponen
## —la X vive dentro de la barra de titulo, el boton dentro del aviso— y con
## todas en el mismo plano el disparo elegia cualquiera: apuntarle a la X podia
## pegarle a la barra. Se escalonan en el orden en que la interfaz las dibuja,
## asi que a lo que se le apunta es a lo que se ve encima.
const ZONE_STACK_STEP := 0.012
const TARGET_GROUP := "Target"
const TARGET_LAYER := 32
const TARGET_MASK := 16
## Tinte de la ventana protegida por un firewall.
const SHIELD_TINT := Color(0.45, 0.62, 0.95)
## Zona que trae la ventana al frente en vez de resolverla. Es la barra de
## titulo, como en cualquier escritorio.
const RAISE_ZONE := "raise"
## Cuanto se adelanta la ventana que pasa al frente respecto de la que estaba
## primera. Es chico: solo tiene que ganar el sorteo de profundidad, no salirse
## del bloque.
const RAISE_STEP := 0.02

## Cuantos pixeles del SubViewport equivalen a un metro del mundo.
## Nombre con el que la ventana aparece en el feed de la ronda.
@export var window_label := "ventana"

@export_range(40.0, 800.0, 1.0) var pixels_per_meter := 73.0:
	set(value):
		pixels_per_meter = maxf(value, 1.0)
		if is_node_ready():
			_update_screen_size()

@onready var sub_viewport: SubViewport = $SubViewport
@onready var screen: MeshInstance3D = $Screen
@onready var hit_zone_root: Node3D = $HitZones

## Tope del tamaño que puede pedir una variante, en pixeles del SubViewport.
## Coincide con SIZE_LIMITS en tools/level-editor/window-format.js.
const VARIANT_MIN_SIZE := Vector2i(200, 110)
const VARIANT_MAX_SIZE := Vector2i(560, 320)

var content: Control
## Variante estetica de un diseño del Window Workshop (titulo, mensaje,
## tamaño). La carga quien instancia, antes de add_child; vacia, la ventana se
## ve como su escena. Solo pisa lo declarado: la familia decide como se juega.
var variant_config: Dictionary = {}
## Mientras esta protegida los disparos rebotan: no la cierran ni suman. Es lo
## que hace el firewall con las ventanas que cubre.
var shielded := false:
	set(value):
		shielded = value
		_update_shield_tint()
## Estilos de muerte: el cierre generico estilo escritorio y el apagado de
## monitor viejo (colapsa a una linea y se apaga) para las que se sienten mas
## "de maquina".
const CLOSE_STYLE_MINIMIZE := "minimize"
const CLOSE_STYLE_CRT := "crt"

## Como muere la ventana. Las familias lo pisan en su _ready con una de las
## constantes CLOSE_STYLE_*.
var close_style := CLOSE_STYLE_MINIMIZE
var _closed := false
var _tint_tween: Tween
var _screen_shake_tween: Tween
var _open_tween: Tween
var _screen_base_position := Vector3.ZERO
## Redibujos con duracion en curso: la pantalla vuelve a quedarse quieta cuando
## termina el ultimo.
var _live_redraws := 0


func _ready() -> void:
	content = _find_content()
	if content == null:
		push_error("WindowPanel3D requires a Control as the first SubViewport child.")
		return
	# Antes de medir nada: el tamaño de la variante tiene que estar aplicado
	# cuando el volumen recorte la ventana contra el bloque y cuando las zonas
	# generen sus cuerpos, un frame despues.
	_apply_variant()
	_update_screen_size()
	_update_shield_tint()
	_screen_base_position = screen.position
	_play_open_animation()
	await get_tree().process_frame
	rebuild_hit_zones()
	request_screen_redraw()


## El SubViewport se dibuja una sola vez (UPDATE_ONCE) y despues queda quieto:
## el contenido de una ventana es estatico casi siempre, y redibujar veinte
## pantallas por frame era el mayor gasto de GPU en la Web. Quien cambie un
## texto, una barra o la visibilidad de un control pide el redibujo; con
## `seconds` la pantalla se queda viva ese tiempo, para una animacion, y
## despues se apaga sola.
func request_screen_redraw(seconds := 0.0) -> void:
	if sub_viewport == null or not is_instance_valid(sub_viewport):
		return
	if seconds <= 0.0:
		if sub_viewport.render_target_update_mode != SubViewport.UPDATE_ALWAYS:
			sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		return
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_live_redraws += 1
	get_tree().create_timer(seconds, false).timeout.connect(_on_live_redraw_over)


func _on_live_redraw_over() -> void:
	_live_redraws = maxi(_live_redraws - 1, 0)
	if _live_redraws == 0 and is_instance_valid(sub_viewport):
		sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


## Aparicion estilo XP: la ventana crece desde chica en un parpadeo. Es solo
## escala visual; los cuerpos disparables nacen un frame despues, ya casi al
## tamanio final.
func _play_open_animation() -> void:
	scale = Vector3(0.1, 0.1, 1.0)
	_open_tween = create_tween()
	_open_tween.tween_property(self, "scale", Vector3.ONE, 0.14) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Vuelve a generar los cuerpos disparables a partir del layout actual.
func rebuild_hit_zones() -> void:
	# Una ventana muriendo no regenera zonas: reviviria los cuerpos que el
	# cierre acaba de apagar.
	if _closed:
		return
	for child in hit_zone_root.get_children():
		child.queue_free()
	var zones := _collect_zones(content)
	for index in zones.size():
		_add_hit_body(zones[index], index)


## Trae la ventana adelante de sus hermanas, como al hacer clic en la barra de
## titulo de un escritorio. Solo tiene sentido porque las ventanas de un bloque
## se superponen a proposito.
func bring_to_front() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var front := position.z
	for child in parent.get_children():
		var sibling := child as Node3D
		if sibling != null and sibling != self:
			front = maxf(front, sibling.position.z)
	if is_equal_approx(front, position.z):
		return
	position.z = front + RAISE_STEP
	raised.emit(self)


func close() -> void:
	if _closed:
		return
	_closed = true
	# La logica se entera ya (puertas, firewall, conteo del bloque); solo la
	# despedida visual es diferida.
	closed.emit(self)
	_disable_hit_bodies()
	Sfx.play_at("window_close", global_position)
	_play_close_animation()


## Una ventana muriendo no puede seguir comiendo tiros ni trayendose al frente.
func _disable_hit_bodies() -> void:
	for body in get_hit_bodies():
		body.queue_free()


func _play_close_animation() -> void:
	if _screen_shake_tween != null:
		_screen_shake_tween.kill()
	# Una ventana cerrada recien nacida todavia tiene el tween de apertura
	# empujando la escala: sin matarlo, los dos pelean por la misma propiedad.
	if _open_tween != null:
		_open_tween.kill()
	match close_style:
		CLOSE_STYLE_CRT:
			_animate_crt_off()
		_:
			_animate_minimize()


## Cierre estilo escritorio: la ventana se encoge y cae, como minimizada hacia
## una barra de tareas que no existe. Corto y seco: en medio del combate una
## despedida lenta se siente como lag.
func _animate_minimize() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3(0.04, 0.04, 1.0), 0.1) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position:y", position.y - 0.45, 0.1) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)


## Apagado CRT: colapsa a una linea horizontal y la linea se apaga hacia el
## centro, como un monitor viejo al que le cortan la corriente.
func _animate_crt_off() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale:y", 0.02, 0.1) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale:x", 0.01, 0.09) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


## Cuerpos disparables generados, en el orden en que aparecen en el layout.
func get_hit_bodies() -> Array[WindowHitBody3D]:
	var bodies: Array[WindowHitBody3D] = []
	for child in hit_zone_root.get_children():
		var body := child as WindowHitBody3D
		if body != null:
			bodies.append(body)
	return bodies


## Primer cuerpo con ese identificador. Varias zonas pueden compartir zone_id.
func find_hit_body(zone_id: String) -> WindowHitBody3D:
	for body in get_hit_bodies():
		if body.zone_id == zone_id:
			return body
	return null


func get_window_size() -> Vector2:
	return Vector2(sub_viewport.size) / pixels_per_meter


func _find_content() -> Control:
	for child in sub_viewport.get_children():
		if child is Control:
			return child
	return null


## Pisa lo que la variante declare y nada mas. Cada texto busca su Label por
## nombre y tolera que no exista: no todas las escenas tienen mensaje, y una
## variante de una familia con layout propio no puede romperlo.
func _apply_variant() -> void:
	if variant_config.is_empty():
		return
	# La skin re-viste el chrome (tema, marco, barra, X) sin tocar el layout.
	var skin := str(variant_config.get("skin", ""))
	if not skin.is_empty():
		WindowSkin.apply(content, skin)
	var size_variant: Variant = variant_config.get("size", null)
	if size_variant is Dictionary:
		var requested := Vector2i(
			int((size_variant as Dictionary).get("width", sub_viewport.size.x)),
			int((size_variant as Dictionary).get("height", sub_viewport.size.y))
		)
		sub_viewport.size = requested.clamp(VARIANT_MIN_SIZE, VARIANT_MAX_SIZE)
	# En las escenas sin nodo Message el mensaje cae en el titular del anuncio,
	# que es el texto grande de los popups.
	_apply_variant_text("title", ["Title"])
	_apply_variant_text("message", ["Message", "Headline"])
	_apply_variant_text("subtitle", ["Subline"])


func _apply_variant_text(key: String, node_names: Array[String]) -> void:
	var text := str(variant_config.get(key, ""))
	if text.is_empty():
		return
	for node_name in node_names:
		var label := content.find_child(node_name, true, false) as Label
		if label != null:
			label.text = text
			return


## Solo las zonas a la vista generan cuerpo. Una ventana puede tener controles
## escondidos —la confirmacion de la descarga, por ejemplo— y dispararle a algo
## que no esta en pantalla seria un acierto invisible.
func _collect_zones(node: Node) -> Array[WindowHitZone]:
	var zones: Array[WindowHitZone] = []
	var control := node as Control
	if control != null and not control.visible:
		return zones
	if node is WindowHitZone:
		zones.append(node)
	for child in node.get_children():
		zones.append_array(_collect_zones(child))
	return zones


## `order` es la posicion de la zona en el orden de dibujado: un hijo se dibuja
## sobre su padre y un hermano posterior sobre el anterior, asi que ese mismo
## orden es el que decide cual esta mas cerca del jugador.
func _add_hit_body(zone: WindowHitZone, order: int) -> void:
	var rect := zone.get_global_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		push_warning("WindowHitZone '%s' has no size; skipping it." % zone.zone_id)
		return
	var body := WindowHitBody3D.new()
	body.name = zone.name
	body.zone_id = zone.zone_id
	body.closes_window = zone.closes_window
	body.scores = zone.scores
	body.collision_layer = TARGET_LAYER
	body.collision_mask = TARGET_MASK
	body.add_to_group(TARGET_GROUP)
	body.position = _viewport_to_local(rect.get_center(), order)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(rect.size.x / pixels_per_meter, rect.size.y / pixels_per_meter, HIT_ZONE_DEPTH)
	collision.shape = box
	body.add_child(collision)
	# El cuerpo recuerda a su Control para que el impacto pueda "presionar" el
	# boton de verdad, como un click en el escritorio.
	body.set_meta("zone_control", zone)
	hit_zone_root.add_child(body)
	body.hit.connect(_on_zone_hit)


## El controlador de ronda se busca una vez por escena: cada impacto lo pide y
## recorrer el grupo en caliente era gratis solo en escritorio.
static var _cached_round_controller: RoundController


func _get_round_controller() -> RoundController:
	if is_instance_valid(_cached_round_controller) and _cached_round_controller.is_inside_tree():
		return _cached_round_controller
	var controllers := get_tree().get_nodes_in_group("round_controller")
	_cached_round_controller = controllers[0] as RoundController if not controllers.is_empty() else null
	return _cached_round_controller


func _viewport_to_local(point: Vector2, order := 0) -> Vector3:
	var size_px := Vector2(sub_viewport.size)
	return Vector3(
		(point.x - size_px.x * 0.5) / pixels_per_meter,
		(size_px.y * 0.5 - point.y) / pixels_per_meter,
		HIT_ZONE_DEPTH * 0.5 + order * ZONE_STACK_STEP
	)


## La ventana protegida se tiñe para que se lea de un vistazo cual no vale la
## pena atacar todavia. La transicion es animada: al caer el firewall, ver el
## tinte fundirse es lo que anuncia que la ventana quedo disponible.
func _update_shield_tint() -> void:
	if not is_node_ready() or screen == null:
		return
	var material := _screen_material()
	if material == null:
		return
	var target := SHIELD_TINT if shielded else Color.WHITE
	if _tint_tween != null:
		_tint_tween.kill()
	_tint_tween = create_tween()
	_tint_tween.tween_property(material, "albedo_color", target, 0.35)


func _screen_material() -> StandardMaterial3D:
	if screen == null:
		return null
	var quad := screen.mesh as QuadMesh
	if quad == null:
		return null
	return quad.material as StandardMaterial3D


## Destello del escudo: el tinte azul sube un instante y vuelve. Es la version
## visible del "rebote" que hasta ahora solo contaba el log.
func _flash_shield() -> void:
	var material := _screen_material()
	if material == null:
		return
	if _tint_tween != null:
		_tint_tween.kill()
	material.albedo_color = SHIELD_TINT.lightened(0.4)
	_tint_tween = create_tween()
	_tint_tween.tween_property(material, "albedo_color", SHIELD_TINT, 0.25)


## Sacudida corta de la pantalla al recibir un tiro. Mueve solo el quad de la
## pantalla y no el nodo raiz: la posicion del raiz es estado del raise y del
## bloque, y el shake no puede ensuciarla.
func _shake_screen() -> void:
	if screen == null or _closed:
		return
	if _screen_shake_tween != null:
		_screen_shake_tween.kill()
	screen.position = _screen_base_position
	_screen_shake_tween = create_tween()
	for _i in 3:
		var offset := Vector3(randf_range(-0.025, 0.025), randf_range(-0.02, 0.02), 0.0)
		_screen_shake_tween.tween_property(screen, "position", _screen_base_position + offset, 0.035)
	_screen_shake_tween.tween_property(screen, "position", _screen_base_position, 0.05)


## Presiona el Control de la zona un instante, como el boton hundido de
## Windows: se desplaza un pixel y se oscurece, y despues vuelve. Es aditivo
## para convivir con zonas que se reacomodan (el error critico baraja offsets).
func _press_zone_control(body: WindowHitBody3D) -> void:
	if not body.has_meta("zone_control"):
		return
	var control := body.get_meta("zone_control") as Control
	if control == null or not is_instance_valid(control):
		return
	control.position += Vector2(1.0, 1.0)
	control.modulate = Color(0.8, 0.8, 0.8)
	var tween := control.create_tween()
	tween.tween_interval(0.08)
	tween.tween_callback(func() -> void:
		if is_instance_valid(control):
			control.position -= Vector2(1.0, 1.0)
			control.modulate = Color.WHITE
	)


func _update_screen_size() -> void:
	var quad := screen.mesh as QuadMesh
	if quad == null:
		return
	quad.size = get_window_size()


func _on_zone_hit(body: WindowHitBody3D) -> void:
	request_screen_redraw(0.3)
	if _closed:
		return
	_shake_screen()
	# Protegida no es invulnerable a la vista: el disparo se ve rebotar y se
	# informa, para que el jugador entienda que le falta desactivar algo.
	if shielded:
		var shield_controller := _get_round_controller()
		if shield_controller != null:
			# Se avisa en el registro y no como impacto: el tiro no resolvio
			# nada, asi que no puede sumar al pozo ni a la cadena.
			shield_controller.add_log(tr("LOG_WINDOW_SHIELDED").format({"window": window_label.to_upper()}), "miss")
		_flash_shield()
		Sfx.play_at("shield_blocked", global_position)
		blocked.emit(self)
		# El tiro reboto: la zona sigue disponible para cuando caiga el firewall.
		body.rearm()
		return
	_press_zone_control(body)
	Sfx.play_at("window_button", global_position)
	if body.zone_id == RAISE_ZONE:
		bring_to_front()
		# La barra sigue disponible: traer al frente se puede repetir.
		body.rearm()
		return
	var controller := _get_round_controller()
	if controller != null and body.scores:
		controller.report_zone_hit(window_label, body.zone_id, body.closes_window)
	zone_hit.emit(body.zone_id, self)
	if body.closes_window:
		close()

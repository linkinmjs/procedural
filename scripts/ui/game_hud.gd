class_name GameHUD
extends CanvasLayer

## Esquinas inferiores del HUD: vitales (HP, municion, tiempo) abajo a la
## izquierda y el log de eventos abajo a la derecha.
##
## Los vitales estan siempre a la vista pero atenuados mientras nada cambia:
## se encienden solos cuando un valor se mueve y vuelven a apagarse despues.
## El log no acumula: cada linea vive unos segundos y se desvanece, asi el
## borde de la pantalla queda limpio cuando no pasa nada.

const MAX_LOG_LINES := 5
## Recorrido y duracion del "+N" que flota al tomar municion.
const AMMO_GAIN_RISE := 22.0
const AMMO_GAIN_SECONDS := 0.9

## Los slots son columnas ancladas que abrazan a su panel contra el borde
## inferior; las animaciones de posicion (entrada, sacudida) mueven al slot,
## que no esta gobernado por ningun container, y no al panel, que si lo esta.
@onready var vitals_slot: Control = %VitalsSlot
@onready var log_slot: Control = %LogSlot
@onready var vitals_panel: Control = %VitalsPanel
@onready var log_panel: Control = %LogPanel
@onready var log_lines: VBoxContainer = %LogLines
@onready var health_value: Label = %HealthValue
@onready var health_bar: ProgressBar = %HealthBar
@onready var ammo_value: Label = %AmmoValue
@onready var time_value: Label = %TimeValue

var _controller: RoundController
var _health_critical := false
var _last_health := -1.0
var _last_seconds := -1
## Capacidad estimada del cargador: el maximo visto desde el bind. La senial de
## municion no trae la capacidad, pero recargar la restaura, asi que el maximo
## observado converge enseguida al valor real.
var _mag_capacity := 0
var _last_magazine := -1
var _vitals_dim_tween: Tween
var _health_bar_tween: Tween
var _health_pulse_tween: Tween
var _shake_tween: Tween
var _shake_base_x := 0.0
var _ammo_tween: Tween
var _time_tween: Tween
var _health_fill: StyleBoxFlat


func _ready() -> void:
	_health_fill = health_bar.get("theme_override_styles/fill") as StyleBoxFlat
	call_deferred("_bind_available_controller")


func bind(controller: RoundController) -> void:
	if controller == null or controller == _controller:
		return
	_controller = controller
	controller.health_changed.connect(_on_health_changed)
	controller.time_changed.connect(_on_time_changed)
	controller.ammo_changed.connect(_on_ammo_changed)
	controller.ammo_collected.connect(_on_ammo_collected)
	controller.log_added.connect(_on_log_added)
	_paint_health(controller.current_health, controller.max_health)
	_paint_time(controller.time_remaining)
	_paint_ammo(controller.magazine_ammo, controller.reserve_ammo)
	if log_lines.get_child_count() == 0:
		_on_log_added(tr("LOG_ROUND_STARTED" if controller.is_running else "LOG_ROUND_STANDBY"), "system")
	_play_entrance()


func _bind_available_controller() -> void:
	var controllers := get_tree().get_nodes_in_group("round_controller")
	if not controllers.is_empty():
		bind(controllers[0] as RoundController)


## Los paneles entran en cascada desde su borde y los vitales se asientan en su
## opacidad de reposo. La entrada arranca un frame despues del bind para que
## las anclas ya hayan resuelto las posiciones finales.
func _play_entrance() -> void:
	await get_tree().process_frame
	# Un reinicio del nivel puede liberar el HUD entre el bind y este frame; la
	# continuacion del await no debe tocar nodos muertos.
	if not is_instance_valid(self) or not is_inside_tree():
		return
	_enter_panel(vitals_slot, Vector2(-HudStyle.SLIDE_DISTANCE, 0.0), HudStyle.STAGGER * 2.0)
	_enter_panel(log_slot, Vector2(HudStyle.SLIDE_DISTANCE, 0.0), HudStyle.STAGGER * 3.0)
	var settle := create_tween()
	settle.tween_interval(HudStyle.STAGGER * 2.0 + HudStyle.DUR_SLIDE_IN)
	settle.tween_callback(_touch_vitals)


func _enter_panel(panel: Control, slide: Vector2, delay: float) -> void:
	var base := panel.position
	panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_interval(maxf(delay, 0.001))
	tween.tween_callback(func() -> void: panel.position = base + slide)
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, HudStyle.DUR_SLIDE_IN)
	tween.tween_property(panel, "position", base, HudStyle.DUR_SLIDE_IN) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Enciende los vitales y programa la vuelta al reposo. Con HP critico el panel
## no se apaga: esa alarma no es negociable.
func _touch_vitals() -> void:
	if _vitals_dim_tween != null:
		_vitals_dim_tween.kill()
	vitals_panel.modulate.a = 1.0
	if _health_critical:
		return
	_vitals_dim_tween = create_tween()
	_vitals_dim_tween.tween_interval(HudStyle.DIM_HOLD)
	_vitals_dim_tween.tween_property(vitals_panel, "modulate:a", HudStyle.DIM_ALPHA, HudStyle.DUR_SETTLE) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_health_changed(current: float, maximum: float) -> void:
	var took_damage := _last_health >= 0.0 and current < _last_health
	_paint_health(current, maximum)
	_touch_vitals()
	if took_damage:
		_flash_health_bar()
		_shake_vitals()


func _paint_health(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_value.text = "%d / %d" % [roundi(current), roundi(maximum)]
	if _health_bar_tween != null:
		_health_bar_tween.kill()
	_health_bar_tween = create_tween()
	_health_bar_tween.tween_property(health_bar, "value", current, HudStyle.DUR_FLASH) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_last_health = current
	_set_health_critical(current <= maximum * HudStyle.HEALTH_CRITICAL_RATIO)


## El estado critico pinta el numero, tine la barra y la deja latiendo hasta
## que la salud se recupere. Un tween en loop y no un calculo por frame: el
## pulso no le cuesta nada al resto del HUD.
func _set_health_critical(critical: bool) -> void:
	if critical == _health_critical:
		return
	_health_critical = critical
	if _health_pulse_tween != null:
		_health_pulse_tween.kill()
		_health_pulse_tween = null
	if critical:
		health_value.add_theme_color_override("font_color", HudStyle.DANGER)
		if _health_fill != null:
			_health_fill.bg_color = HudStyle.DANGER
		_health_pulse_tween = create_tween().set_loops()
		_health_pulse_tween.tween_property(health_bar, "modulate:a", 0.55, 0.4) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_health_pulse_tween.tween_property(health_bar, "modulate:a", 1.0, 0.4) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_touch_vitals()
	else:
		health_value.remove_theme_color_override("font_color")
		if _health_fill != null:
			_health_fill.bg_color = HudStyle.HEALTH_FILL
		health_bar.modulate.a = 1.0


## Destello del relleno: blanco en el impacto, fundido al color que toque.
func _flash_health_bar() -> void:
	if _health_fill == null:
		return
	var target := HudStyle.DANGER if _health_critical else HudStyle.HEALTH_FILL
	_health_fill.bg_color = Color.WHITE
	var tween := create_tween()
	tween.tween_method(
		func(weight: float) -> void: _health_fill.bg_color = Color.WHITE.lerp(target, weight),
		0.0, 1.0, HudStyle.DUR_SETTLE
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _shake_vitals() -> void:
	# La posicion base sale del layout: se captura solo si no hay una sacudida
	# en curso, para no tomar un offset a mitad de camino.
	if _shake_tween != null and _shake_tween.is_running():
		vitals_slot.position.x = _shake_base_x
		_shake_tween.kill()
	else:
		_shake_base_x = vitals_slot.position.x
	_shake_tween = create_tween()
	for offset in [4.0, -3.0, 2.0]:
		_shake_tween.tween_property(vitals_slot, "position:x", _shake_base_x + offset, 0.04)
	_shake_tween.tween_property(vitals_slot, "position:x", _shake_base_x, 0.04)


## La senial llega cada frame pero el valor cambia una vez por segundo: si el
## segundo no cambio, no hay nada que formatear ni redibujar.
func _on_time_changed(seconds_remaining: float) -> void:
	var previous := _last_seconds
	if ceili(seconds_remaining) == previous:
		return
	_paint_time(seconds_remaining)
	# El tick de urgencia marca cada segundo del tramo final: escala y color,
	# espejo del tic sonoro del chain timer. Los ticks normales no encienden
	# los vitales: si lo hicieran, el panel no se apagaria nunca.
	if _last_seconds <= HudStyle.TIME_URGENT_SECONDS and _last_seconds > 0:
		_touch_vitals()
		time_value.add_theme_color_override("font_color", HudStyle.DANGER)
		_punch_label(time_value, 1.15, _time_tween, func(tween: Tween) -> void: _time_tween = tween)
	elif previous <= HudStyle.TIME_URGENT_SECONDS:
		time_value.remove_theme_color_override("font_color")


func _paint_time(seconds_remaining: float) -> void:
	var total_seconds := ceili(seconds_remaining)
	time_value.text = "%02d:%02d" % [total_seconds / 60, total_seconds % 60]
	_last_seconds = total_seconds


func _on_ammo_changed(magazine: int, reserve: int) -> void:
	var fired := magazine < _last_magazine
	_paint_ammo(magazine, reserve)
	_touch_vitals()
	if fired:
		_punch_label(ammo_value, 1.08, _ammo_tween, func(tween: Tween) -> void: _ammo_tween = tween)


## Tomar municion merece un aviso propio, distinto del contador que cambia:
## el "+N" cuenta que la burbuja se tomo aunque no se la haya visto reventar.
func _on_ammo_collected(amount: int) -> void:
	if amount <= 0:
		return
	_float_ammo_gain(amount)
	_touch_vitals()
	_punch_label(ammo_value, 1.14, _ammo_tween, func(tween: Tween) -> void: _ammo_tween = tween)


## "+N" que nace pegado al contador, sube y se desvanece. Es lo que cuenta que
## la burbuja se tomo aunque el jugador no la haya visto reventar.
func _float_ammo_gain(amount: int) -> void:
	var gain := Label.new()
	gain.name = "AmmoGain"
	gain.text = "+%d" % amount
	gain.top_level = true
	gain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gain.add_theme_color_override("font_color", HudStyle.ACCENT_GOLD)
	gain.add_theme_font_size_override("font_size", ammo_value.get_theme_font_size("font_size"))
	ammo_value.add_child(gain)
	gain.global_position = ammo_value.global_position + Vector2(ammo_value.size.x + 10.0, 0.0)
	var tween := gain.create_tween()
	tween.set_parallel(true)
	tween.tween_property(gain, "position:y", gain.position.y - AMMO_GAIN_RISE, AMMO_GAIN_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(gain, "modulate:a", 0.0, AMMO_GAIN_SECONDS).set_delay(AMMO_GAIN_SECONDS * 0.4)
	tween.set_parallel(false)
	tween.tween_callback(gain.queue_free)


func _paint_ammo(magazine: int, reserve: int) -> void:
	_last_magazine = magazine
	_mag_capacity = maxi(_mag_capacity, magazine)
	ammo_value.text = "%02d / %02d" % [magazine, reserve]
	if magazine <= 0:
		ammo_value.add_theme_color_override("font_color", HudStyle.DANGER)
	elif _mag_capacity > 0 and magazine <= ceili(_mag_capacity * HudStyle.AMMO_LOW_RATIO):
		ammo_value.add_theme_color_override("font_color", HudStyle.WARNING)
	else:
		ammo_value.remove_theme_color_override("font_color")


## Punch chico de un Label: escala desde el centro y vuelve con TRANS_BACK.
func _punch_label(label: Label, peak: float, current: Tween, store: Callable) -> void:
	if current != null:
		current.kill()
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2.ONE * peak
	var tween := create_tween()
	tween.tween_property(label, "scale", Vector2.ONE, HudStyle.DUR_PUNCH) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	store.call(tween)


## Cada linea del log es un Label propio que entra con fade, vive unos segundos
## y se desvanece solo. El tween cuelga de la linea, asi muere con ella.
func _on_log_added(message: String, event_kind: String) -> void:
	var color: Color = HudStyle.LOG_COLORS.get(event_kind, HudStyle.LOG_COLORS.info)
	var line := Label.new()
	line.theme_type_variation = &"HudLog"
	line.text = "[%s] %s" % [Time.get_time_string_from_system(), message]
	line.add_theme_color_override("font_color", color)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_lines.add_child(line)
	while log_lines.get_child_count() > MAX_LOG_LINES:
		var oldest := log_lines.get_child(0)
		log_lines.remove_child(oldest)
		oldest.queue_free()
	line.modulate.a = 0.0
	var tween := line.create_tween()
	tween.tween_property(line, "modulate:a", 1.0, HudStyle.DUR_LOG_IN)
	tween.tween_interval(HudStyle.LOG_LIFE)
	tween.tween_property(line, "modulate:a", 0.0, HudStyle.LOG_FADE)
	tween.tween_callback(line.queue_free)

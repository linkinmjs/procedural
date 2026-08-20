class_name GameHUD
extends CanvasLayer

const MAX_LOG_LINES := 5
const LOG_COLORS := {
	"system": Color(0.3, 0.85, 1.0),
	"hit": Color(0.45, 1.0, 0.45),
	"miss": Color(1.0, 0.68, 0.2),
	"danger": Color(1.0, 0.22, 0.3),
	"score": Color(1.0, 0.82, 0.28),
	"info": Color(0.72, 0.82, 0.9),
}

@onready var log_feed: RichTextLabel = %LogFeed
@onready var accuracy_value: Label = %AccuracyValue
@onready var accuracy_detail: Label = %AccuracyDetail
@onready var health_value: Label = %HealthValue
@onready var health_bar: ProgressBar = %HealthBar
@onready var ammo_value: Label = %AmmoValue
@onready var time_value: Label = %TimeValue
@onready var status_value: Label = %StatusValue

var _controller: RoundController
var _logs: Array[String] = []


func _ready() -> void:
	call_deferred("_bind_available_controller")


func bind(controller: RoundController) -> void:
	if controller == null or controller == _controller:
		return
	_controller = controller
	controller.health_changed.connect(_on_health_changed)
	controller.time_changed.connect(_on_time_changed)
	controller.accuracy_changed.connect(_on_accuracy_changed)
	controller.ammo_changed.connect(_on_ammo_changed)
	controller.log_added.connect(_on_log_added)
	controller.round_armed.connect(_on_round_armed)
	controller.round_started.connect(_on_round_started)
	controller.round_ended.connect(_on_round_ended)
	_on_health_changed(controller.current_health, controller.max_health)
	_on_time_changed(controller.time_remaining)
	_on_accuracy_changed(controller.hits, controller.attacks, controller.get_accuracy_percent())
	_on_ammo_changed(controller.magazine_ammo, controller.reserve_ammo)
	status_value.text = "HUD_ROUND_ACTIVE" if controller.is_running else "HUD_ROUND_STANDBY"
	if _logs.is_empty():
		_on_log_added(tr("LOG_ROUND_STARTED" if controller.is_running else "LOG_ROUND_STANDBY"), "system")


func _bind_available_controller() -> void:
	var controllers := get_tree().get_nodes_in_group("round_controller")
	if not controllers.is_empty():
		bind(controllers[0] as RoundController)


func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_value.text = "%d / %d" % [roundi(current), roundi(maximum)]
	if current <= maximum * 0.25:
		health_value.modulate = Color(1.0, 0.22, 0.3)
	else:
		health_value.modulate = Color.WHITE


func _on_time_changed(seconds_remaining: float) -> void:
	var total_seconds := ceili(seconds_remaining)
	time_value.text = "%02d:%02d" % [total_seconds / 60, total_seconds % 60]


func _on_accuracy_changed(hit_count: int, attack_count: int, percent: float) -> void:
	accuracy_value.text = "%.1f%%" % percent
	accuracy_detail.text = tr("HUD_HIT_SHOT").format({
		"hits": "%02d" % hit_count,
		"shots": "%02d" % attack_count,
	})


func _on_ammo_changed(magazine: int, reserve: int) -> void:
	ammo_value.text = "%02d / %02d" % [magazine, reserve]
	ammo_value.modulate = Color(1.0, 0.22, 0.3) if magazine <= 0 else Color.WHITE


func _on_log_added(message: String, event_kind: String) -> void:
	var color: Color = LOG_COLORS.get(event_kind, LOG_COLORS.info)
	var timestamp := Time.get_time_string_from_system()
	_logs.append("[color=#%s][%s] %s[/color]" % [color.to_html(false), timestamp, message])
	while _logs.size() > MAX_LOG_LINES:
		_logs.pop_front()
	log_feed.text = "\n".join(_logs)


func _on_round_ended(reason: String) -> void:
	status_value.text = "HUD_ROUND_FAILED" if reason == "health_depleted" else "HUD_ROUND_COMPLETE"


func _on_round_armed() -> void:
	status_value.text = "HUD_ROUND_STANDBY"


func _on_round_started() -> void:
	status_value.text = "HUD_ROUND_ACTIVE"

extends Control
class_name DynamicCrosshair

const DIRECTIONS: Array[Vector2] = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]

## Mira de cuatro trazos que se abre con la imprecision del arma, al estilo de
## Counter-Strike 1.6. El hueco central marca la dispersion real del disparo.

@export var line_length: float = 9.0
@export var line_thickness: float = 2.0
@export var minimum_gap: float = 4.0
@export var color: Color = Color(1.0, 1.0, 1.0, 0.85)
@export var outline_color: Color = Color(0.0, 0.0, 0.0, 0.5)
## Velocidad con la que la mira sigue a la dispersion del arma.
@export var follow_speed: float = 14.0

var _gap: float = minimum_gap
var _target_gap: float = minimum_gap


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if is_equal_approx(_gap, _target_gap):
		return
	_gap = lerpf(_gap, _target_gap, clampf(follow_speed * delta, 0.0, 1.0))
	queue_redraw()


## Abre la mira segun la dispersion del arma, expresada en pixeles.
func set_spread(spread_pixels: float) -> void:
	_target_gap = minimum_gap + maxf(spread_pixels, 0.0)


func _draw() -> void:
	var center := size * 0.5
	for direction in DIRECTIONS:
		var from := center + direction * _gap
		var to := from + direction * line_length
		draw_line(from, to, outline_color, line_thickness + 2.0)
		draw_line(from, to, color, line_thickness)

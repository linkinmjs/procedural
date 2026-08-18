class_name CyberPanel
extends PanelContainer

@export var accent_color := Color(0.0, 0.85, 1.0, 1.0):
	set(value):
		accent_color = value
		queue_redraw()


func _ready() -> void:
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var corner := 11.0
	var thickness := 2.0
	var end := size
	for points in [
		[Vector2.ZERO, Vector2(corner, 0.0), Vector2(0.0, corner)],
		[Vector2(end.x, 0.0), Vector2(end.x - corner, 0.0), Vector2(end.x, corner)],
		[Vector2(0.0, end.y), Vector2(corner, end.y), Vector2(0.0, end.y - corner)],
		[Vector2(end.x, end.y), Vector2(end.x - corner, end.y), Vector2(end.x, end.y - corner)],
	]:
		draw_line(points[0], points[1], accent_color, thickness)
		draw_line(points[0], points[2], accent_color, thickness)
	draw_rect(Rect2(14.0, 5.0, minf(48.0, maxf(size.x - 28.0, 0.0)), 2.0), accent_color)

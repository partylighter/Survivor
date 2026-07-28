extends Control
class_name JaugeChauffe

var temperature: float = 0.0
var limite_basse: float = 0.0
var limite_haute: float = 0.0

func actualiser(nouvelle_temperature: float, nouvelle_limite_basse: float, nouvelle_limite_haute: float) -> void:
	temperature = clampf(nouvelle_temperature, 0.0, 100.0)
	limite_basse = clampf(nouvelle_limite_basse, 0.0, 100.0)
	limite_haute = clampf(nouvelle_limite_haute, 0.0, 100.0)
	queue_redraw()

func _draw() -> void:
	var rectangle := Rect2(Vector2.ZERO, size)
	draw_rect(rectangle, Color(0.08, 0.08, 0.1), true)
	var debut_zone: float = size.x * limite_basse / 100.0
	var fin_zone: float = size.x * limite_haute / 100.0
	draw_rect(Rect2(debut_zone, 0.0, fin_zone - debut_zone, size.y), Color(0.18, 0.55, 0.25, 0.85), true)
	var position_temperature: float = size.x * temperature / 100.0
	draw_rect(Rect2(position_temperature - 3.0, -4.0, 6.0, size.y + 8.0), Color(1.0, 0.48, 0.08), true)
	draw_rect(rectangle, Color(0.7, 0.7, 0.75), false, 2.0)

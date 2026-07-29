extends Control
class_name JaugeChauffe

var temperature: float = 0.0
var limite_parfaite_basse: float = 0.0
var limite_parfaite_haute: float = 0.0
var limite_correcte_basse: float = 0.0
var limite_correcte_haute: float = 0.0
var limite_tolerance_basse: float = 0.0
var limite_tolerance_haute: float = 0.0

func actualiser(nouvelle_temperature: float, nouvelle_limite_parfaite_basse: float, nouvelle_limite_parfaite_haute: float, nouvelle_limite_correcte_basse: float = -1.0, nouvelle_limite_correcte_haute: float = -1.0, nouvelle_limite_tolerance_basse: float = -1.0, nouvelle_limite_tolerance_haute: float = -1.0) -> void:
	temperature = clampf(nouvelle_temperature, 0.0, 100.0)
	limite_parfaite_basse = clampf(nouvelle_limite_parfaite_basse, 0.0, 100.0)
	limite_parfaite_haute = clampf(nouvelle_limite_parfaite_haute, 0.0, 100.0)
	limite_correcte_basse = limite_parfaite_basse if nouvelle_limite_correcte_basse < 0.0 else clampf(nouvelle_limite_correcte_basse, 0.0, 100.0)
	limite_correcte_haute = limite_parfaite_haute if nouvelle_limite_correcte_haute < 0.0 else clampf(nouvelle_limite_correcte_haute, 0.0, 100.0)
	limite_tolerance_basse = limite_correcte_basse if nouvelle_limite_tolerance_basse < 0.0 else clampf(nouvelle_limite_tolerance_basse, 0.0, 100.0)
	limite_tolerance_haute = limite_correcte_haute if nouvelle_limite_tolerance_haute < 0.0 else clampf(nouvelle_limite_tolerance_haute, 0.0, 100.0)
	queue_redraw()

func _draw() -> void:
	var rectangle := Rect2(Vector2.ZERO, size)
	draw_rect(rectangle, Color(0.08, 0.08, 0.1), true)
	_dessiner_zone(limite_tolerance_basse, limite_tolerance_haute, Color(0.16, 0.25, 0.18, 0.9))
	_dessiner_zone(limite_correcte_basse, limite_correcte_haute, Color(0.18, 0.42, 0.23, 0.9))
	_dessiner_zone(limite_parfaite_basse, limite_parfaite_haute, Color(0.22, 0.62, 0.3, 0.95))
	var position_temperature: float = size.x * temperature / 100.0
	draw_rect(Rect2(position_temperature - 3.0, -4.0, 6.0, size.y + 8.0), Color(1.0, 0.48, 0.08), true)
	draw_rect(rectangle, Color(0.7, 0.7, 0.75), false, 2.0)

func _dessiner_zone(limite_basse: float, limite_haute: float, couleur: Color) -> void:
	var debut: float = size.x * limite_basse / 100.0
	var fin: float = size.x * limite_haute / 100.0
	draw_rect(Rect2(debut, 0.0, fin - debut, size.y), couleur, true)

extends Control
class_name ZoneMoulage

var gestionnaire: GestionnaireMoulage

func definir_gestionnaire(nouveau_gestionnaire: GestionnaireMoulage) -> void:
	gestionnaire = nouveau_gestionnaire
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.07, 0.085), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.6, 0.6, 0.68), false, 2.0)
	if gestionnaire == null or gestionnaire.points.is_empty():
		return
	var positions: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in gestionnaire.points:
		positions.append(point * size)
	if positions.size() >= 2:
		draw_polyline(positions, Color(0.55, 0.55, 0.62), 4.0, true)
	var dimension: float = minf(size.x, size.y)
	var rayon: float = gestionnaire.rayon_point_actuel * dimension
	for index: int in positions.size():
		var couleur: Color = Color(0.34, 0.34, 0.4)
		if index < gestionnaire.index_point_actuel:
			couleur = Color(0.25, 0.72, 0.38)
		elif index == gestionnaire.index_point_actuel:
			couleur = Color(0.95, 0.58, 0.12)
		draw_circle(positions[index], rayon, couleur)
		draw_circle(positions[index], rayon, Color.WHITE, false, 2.0, true)
	var position_curseur: Vector2 = gestionnaire.position_curseur * size
	var couleur_curseur: Color = Color(0.3, 1.0, 0.5) if gestionnaire.curseur_dans_point() else Color(1.0, 0.28, 0.22)
	draw_circle(position_curseur, 10.0, couleur_curseur)
	draw_line(position_curseur - Vector2(16.0, 0.0), position_curseur + Vector2(16.0, 0.0), Color.WHITE, 2.0)
	draw_line(position_curseur - Vector2(0.0, 16.0), position_curseur + Vector2(0.0, 16.0), Color.WHITE, 2.0)

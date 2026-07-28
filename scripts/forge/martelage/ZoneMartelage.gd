extends Control
class_name ZoneMartelage

signal clic_demande(position_normalisee: Vector2)

var gestionnaire: GestionnaireMartelage

func definir_gestionnaire(nouveau_gestionnaire: GestionnaireMartelage) -> void:
	gestionnaire = nouveau_gestionnaire
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if gestionnaire == null or not gestionnaire.actif or not event is InputEventMouseButton:
		return
	var clic: InputEventMouseButton = event as InputEventMouseButton
	if clic.button_index != MOUSE_BUTTON_LEFT or not clic.pressed or size.x <= 0.0 or size.y <= 0.0:
		return
	clic_demande.emit(Vector2(clic.position.x / size.x, clic.position.y / size.y))
	accept_event()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.07, 0.085), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.6, 0.6, 0.68), false, 2.0)
	if gestionnaire == null:
		return
	var dimension: float = minf(size.x, size.y)
	var rayon: float = gestionnaire.rayon_point_actuel * dimension
	for point: Dictionary in gestionnaire.points_actifs:
		var position_point: Vector2 = (point["position"] as Vector2) * size
		var proportion_temps: float = clampf(float(point["age"]) / maxf(gestionnaire.duree_point_actuelle, 0.001), 0.0, 1.0)
		var rayon_rythme: float = rayon * lerpf(2.0, 0.65, proportion_temps)
		draw_circle(position_point, rayon, Color(0.82, 0.22, 0.12, 0.9))
		draw_circle(position_point, rayon * 0.45, Color(1.0, 0.68, 0.12, 0.95))
		draw_arc(position_point, rayon_rythme, 0.0, TAU, 48, Color.WHITE, 3.0, true)

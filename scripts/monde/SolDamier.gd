extends Node2D
class_name SolDamier
@export var taille_case_px: float = 256.0
@export var couleur_case_a: Color = Color(0.08, 0.12, 0.15, 1.0)
@export var couleur_case_b: Color = Color(0.12, 0.17, 0.20, 1.0)
@export var marge_cases: int = 3
@export var z_sol: int = -760
func _ready() -> void:
	z_index = z_sol
func _process(_delta: float) -> void:
	queue_redraw()
func _draw() -> void:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera == null:
		return
	var taille_vue: Vector2 = get_viewport_rect().size / camera.zoom
	var debut: Vector2 = camera.global_position - taille_vue * 0.5 - Vector2.ONE * taille_case_px * float(marge_cases)
	var fin: Vector2 = camera.global_position + taille_vue * 0.5 + Vector2.ONE * taille_case_px * float(marge_cases)
	var x_debut: int = floori(debut.x / taille_case_px)
	var y_debut: int = floori(debut.y / taille_case_px)
	var x_fin: int = ceili(fin.x / taille_case_px)
	var y_fin: int = ceili(fin.y / taille_case_px)
	for x in range(x_debut, x_fin):
		for y in range(y_debut, y_fin):
			var position_case: Vector2 = Vector2(float(x), float(y)) * taille_case_px
			var couleur_case: Color = couleur_case_a if (x + y) % 2 == 0 else couleur_case_b
			draw_rect(Rect2(to_local(position_case), Vector2.ONE * taille_case_px), couleur_case)

extends CanvasLayer
class_name MenuParametres

signal demande_perf
signal demande_touches
signal demande_graphique

@export_node_path("Button") var chemin_btn_perf: NodePath
@export_node_path("Button") var chemin_btn_touches: NodePath
@export_node_path("Button") var chemin_btn_graphique: NodePath

var btn_perf: Button
var btn_touches: Button
var btn_graphique: Button

func _ready() -> void:
	# Récupération des boutons via NodePath si dispo
	btn_perf = get_node_or_null(chemin_btn_perf) as Button
	btn_touches = get_node_or_null(chemin_btn_touches) as Button
	btn_graphique = get_node_or_null(chemin_btn_graphique) as Button

	# Fallback si NodePath pas assigné dans l'inspecteur
	if btn_perf == null:
		btn_perf = find_child("btn_param_perf", true, false) as Button
	if btn_touches == null:
		btn_touches = find_child("btn_param_touches", true, false) as Button
	if btn_graphique == null:
		btn_graphique = find_child("btn_param_Graphique", true, false) as Button

	# Connexion des signaux
	if btn_perf:
		btn_perf.pressed.connect(_on_perf)
	if btn_touches:
		btn_touches.pressed.connect(_on_touches)
	if btn_graphique:
		btn_graphique.pressed.connect(_on_graphique)

func _on_perf() -> void:
	demande_perf.emit()

func _on_touches() -> void:
	demande_touches.emit()

func _on_graphique() -> void:
	demande_graphique.emit()

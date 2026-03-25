extends Node
class_name GestionnaireMenuParametres

@export var scene_perf: PackedScene 
@export var scene_touches: PackedScene
@export var scene_graphique: PackedScene

var menu: MenuParametres

func _ready() -> void:
	if get_parent() is MenuParametres:
		menu = get_parent() as MenuParametres
	else:
		push_error("GestionnaireMenuParametres doit être enfant de MenuParametres.")
		return

	menu.demande_perf.connect(_sur_demande_perf)
	menu.demande_touches.connect(_sur_demande_touches)
	menu.demande_graphique.connect(_sur_demande_graphique)

func _sur_demande_perf() -> void:
	if scene_perf == null:
		push_error("Aucune scène Perf définie.")
		return
	GestionnaireRetour.aller_a_scene(scene_perf)

func _sur_demande_touches() -> void:
	if scene_touches == null:
		push_error("Aucune scène Touches définie.")
		return
	GestionnaireRetour.aller_a_scene(scene_touches)

func _sur_demande_graphique() -> void:
	if scene_graphique == null:
		push_error("Aucune scène Graphique définie.")
		return
	GestionnaireRetour.aller_a_scene(scene_graphique)

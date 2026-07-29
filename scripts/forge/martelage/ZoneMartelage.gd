extends Control
class_name ZoneMartelage

signal clic_demande(position_normalisee: Vector2, taille_zone: Vector2)

@export var scene_point_martelage: PackedScene = preload("res://scenes/ui/forge/point_martelage.tscn")
@onready var conteneur_points: Control = $ConteneurPoints
var gestionnaire: GestionnaireMartelage
var points_visuels: Dictionary = {}

func definir_gestionnaire(nouveau_gestionnaire: GestionnaireMartelage) -> void:
	gestionnaire = nouveau_gestionnaire
	actualiser_points()

func _gui_input(event: InputEvent) -> void:
	if gestionnaire == null or not gestionnaire.actif or not event is InputEventMouseButton:
		return
	var clic: InputEventMouseButton = event as InputEventMouseButton
	if clic.button_index != MOUSE_BUTTON_LEFT or not clic.pressed or size.x <= 0.0 or size.y <= 0.0:
		return
	clic_demande.emit(Vector2(clic.position.x / size.x, clic.position.y / size.y), size)
	accept_event()

func actualiser_points() -> void:
	if not is_node_ready() or gestionnaire == null or conteneur_points == null:
		return
	var identifiants_actifs: Dictionary = {}
	for donnees: Dictionary in gestionnaire.points_actifs:
		var identifiant: int = int(donnees.get("identifiant", -1))
		identifiants_actifs[identifiant] = true
		var point_visuel: PointMartelage = points_visuels.get(identifiant, null) as PointMartelage
		if point_visuel == null:
			point_visuel = scene_point_martelage.instantiate() as PointMartelage
			conteneur_points.add_child(point_visuel)
			points_visuels[identifiant] = point_visuel
		var donnees_visuelles: Dictionary = donnees.duplicate(true)
		donnees_visuelles["cliquable"] = gestionnaire.point_est_cliquable(donnees)
		point_visuel.actualiser(donnees_visuelles, size)
	for identifiant: Variant in points_visuels.keys():
		if identifiants_actifs.has(identifiant):
			continue
		var point_visuel: PointMartelage = points_visuels[identifiant] as PointMartelage
		points_visuels.erase(identifiant)
		point_visuel.queue_free()

func vider_points() -> void:
	for point_visuel: PointMartelage in points_visuels.values():
		if is_instance_valid(point_visuel):
			point_visuel.queue_free()
	points_visuels.clear()

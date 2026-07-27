extends Node2D

@export_node_path("CharacterBody2D") var chemin_joueur: NodePath
@export_category("Confort caméra")
@export var suivi_souris_actif: bool = true
@export_range(0.0, 500.0, 1.0) var distance_maximale_suivi_souris: float = 220.0
@export_range(0.0, 0.9, 0.01) var zone_morte_souris: float = 0.1
@export_range(0.0, 0.3, 0.01) var dezoom_maximal_souris: float = 0.03
@export_range(0.0, 0.95, 0.01) var seuil_activation_dezoom: float = 0.42
@export_range(0.0, 0.95, 0.01) var seuil_desactivation_dezoom: float = 0.28
@export_range(0.0, 1.0, 0.05) var suivi_horizontal_souris_couloir: float = 1.0
@export_range(0.0, 400.0, 1.0) var hauteur_zone_morte_couloir: float = 120.0
@export_range(0.0, 200.0, 1.0) var anticipation_maximale_couloir: float = 80.0
@export_range(0.0, 0.5, 0.01) var temps_anticipation_couloir: float = 0.18
@export_range(1.0, 20.0, 0.1) var vitesse_lissage_anticipation: float = 8.0
@export_range(1.0, 20.0, 0.1) var vitesse_lissage_position: float = 6.5
@export_range(1.0, 20.0, 0.1) var vitesse_lissage_souris: float = 7.0
@export_range(1.0, 20.0, 0.1) var vitesse_lissage_zoom: float = 5.0
@export_range(1.0, 30.0, 0.1) var vitesse_transition_lointaine: float = 12.0
@export_range(500.0, 5000.0, 10.0) var distance_transition_immediate: float = 1800.0
@onready var joueur: CharacterBody2D = get_node_or_null(chemin_joueur) as CharacterBody2D
var zones_occupees: Array[Area2D] = []
var zone_actuelle: Area2D
var camera_actuelle: Camera2D
var positions_repos_cameras: Dictionary = {}
var zooms_repos_cameras: Dictionary = {}
var dezoom_souris_en_cours: bool = false
var position_verticale_suivie: float = 0.0
var suivi_vertical_initialise: bool = false
var vitesse_verticale_lissee: float = 0.0
var transition_en_cours: bool = false
var vitesse_transition_actuelle: float = 6.5

func _ready() -> void:
	if joueur == null:
		push_error("Joueur introuvable pour les zones de caméra de la forge")
		return
	var parent_cameras: Node = get_node_or_null("../cameras")
	if parent_cameras == null:
		push_error("Nœud cameras introuvable dans la forge")
		return
	for enfant: Node in parent_cameras.get_children():
		if enfant is Camera2D:
			var camera: Camera2D = enfant as Camera2D
			positions_repos_cameras[camera] = camera.global_position
			zooms_repos_cameras[camera] = camera.zoom
	for enfant: Node in get_children():
		if enfant is Area2D:
			var zone: Area2D = enfant as Area2D
			zone.body_entered.connect(_quand_un_corps_entre.bind(zone))
			zone.body_exited.connect(_quand_un_corps_sort.bind(zone))
	await get_tree().physics_frame
	_synchroniser_zones_occupees()

func _process(delta: float) -> void:
	if camera_actuelle == null:
		return
	var position_cible: Vector2 = positions_repos_cameras[camera_actuelle]
	var zoom_cible: Vector2 = zooms_repos_cameras[camera_actuelle]
	var offset_cible: Vector2 = Vector2.ZERO
	var taille_vue: Vector2 = get_viewport_rect().size
	var suivi_vertical_actif: bool = zone_actuelle != null and bool(zone_actuelle.get_meta("suivi_vertical", false))
	if suivi_vertical_actif:
		if not suivi_vertical_initialise:
			position_verticale_suivie = camera_actuelle.global_position.y
			vitesse_verticale_lissee = 0.0
			suivi_vertical_initialise = true
		var poids_anticipation: float = 1.0 - exp(-vitesse_lissage_anticipation * delta)
		vitesse_verticale_lissee = lerpf(vitesse_verticale_lissee, joueur.velocity.y, poids_anticipation)
		var anticipation: float = clampf(vitesse_verticale_lissee * temps_anticipation_couloir, -anticipation_maximale_couloir, anticipation_maximale_couloir)
		var position_joueur_anticipee: float = joueur.global_position.y + anticipation
		var demi_zone_morte: float = hauteur_zone_morte_couloir * 0.5
		if position_joueur_anticipee < position_verticale_suivie - demi_zone_morte:
			position_verticale_suivie = position_joueur_anticipee + demi_zone_morte
		elif position_joueur_anticipee > position_verticale_suivie + demi_zone_morte:
			position_verticale_suivie = position_joueur_anticipee - demi_zone_morte
		position_cible.y = position_verticale_suivie
	var multiplicateur_suivi_souris: float = float(zone_actuelle.get_meta("multiplicateur_suivi_souris", 1.0)) if zone_actuelle != null else 1.0
	var dezoom_maximal_zone: float = float(zone_actuelle.get_meta("dezoom_maximal", dezoom_maximal_souris)) if zone_actuelle != null else dezoom_maximal_souris
	if suivi_souris_actif:
		var centre_vue: Vector2 = taille_vue * 0.5
		var position_relative: Vector2 = (get_viewport().get_mouse_position() - centre_vue) / centre_vue
		var distance_souris: float = clampf(position_relative.length(), 0.0, 1.0)
		if distance_souris > zone_morte_souris:
			var intensite_suivi: float = (distance_souris - zone_morte_souris) / (1.0 - zone_morte_souris)
			var decalage_souris: Vector2 = position_relative.normalized() * distance_maximale_suivi_souris * multiplicateur_suivi_souris * intensite_suivi
			if suivi_vertical_actif:
				decalage_souris.x *= suivi_horizontal_souris_couloir
			offset_cible = decalage_souris
		var intensite_dezoom: float = _calculer_intensite_dezoom(distance_souris)
		zoom_cible *= 1.0 - dezoom_maximal_zone * intensite_dezoom
	else:
		dezoom_souris_en_cours = false
	var limites_zone: Rect2 = _calculer_limites_zone(zone_actuelle, zoom_cible, taille_vue)
	if limites_zone.size.x >= 0.0 and limites_zone.size.y >= 0.0:
		position_cible.x = clampf(position_cible.x, limites_zone.position.x, limites_zone.end.x)
		position_cible.y = clampf(position_cible.y, limites_zone.position.y, limites_zone.end.y)
		if suivi_vertical_actif:
			position_verticale_suivie = clampf(position_verticale_suivie, limites_zone.position.y, limites_zone.end.y)
	var vitesse_position: float = vitesse_transition_actuelle if transition_en_cours else vitesse_lissage_position
	var poids_position: float = 1.0 - exp(-vitesse_position * delta)
	var poids_souris: float = 1.0 - exp(-vitesse_lissage_souris * delta)
	var poids_zoom: float = 1.0 - exp(-(vitesse_position if transition_en_cours else vitesse_lissage_zoom) * delta)
	camera_actuelle.global_position = camera_actuelle.global_position.lerp(position_cible, poids_position)
	camera_actuelle.offset = camera_actuelle.offset.lerp(offset_cible, poids_souris)
	camera_actuelle.zoom = camera_actuelle.zoom.lerp(zoom_cible, poids_zoom)
	if transition_en_cours and camera_actuelle.global_position.distance_to(position_cible) < 2.0 and camera_actuelle.zoom.distance_to(zoom_cible) < 0.01:
		transition_en_cours = false

func _calculer_limites_zone(zone: Area2D, zoom_camera: Vector2, taille_vue: Vector2) -> Rect2:
	if zone == null:
		return Rect2(Vector2.ZERO, Vector2(-1.0, -1.0))
	var collision: CollisionShape2D = zone.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null or not collision.shape is RectangleShape2D:
		return Rect2(Vector2.ZERO, Vector2(-1.0, -1.0))
	var rectangle: RectangleShape2D = collision.shape as RectangleShape2D
	var demi_taille_zone: Vector2 = rectangle.size * collision.global_scale.abs() * 0.5
	var demi_taille_vue: Vector2 = taille_vue * 0.5 / zoom_camera
	var position_minimale: Vector2 = collision.global_position - demi_taille_zone + demi_taille_vue
	var position_maximale: Vector2 = collision.global_position + demi_taille_zone - demi_taille_vue
	if position_minimale.x > position_maximale.x:
		position_minimale.x = collision.global_position.x
		position_maximale.x = collision.global_position.x
	if position_minimale.y > position_maximale.y:
		position_minimale.y = collision.global_position.y
		position_maximale.y = collision.global_position.y
	return Rect2(position_minimale, position_maximale - position_minimale)

func _calculer_intensite_dezoom(distance_souris: float) -> float:
	var seuil_activation: float = maxf(seuil_activation_dezoom, seuil_desactivation_dezoom)
	var seuil_desactivation: float = minf(seuil_activation_dezoom, seuil_desactivation_dezoom)
	if dezoom_souris_en_cours:
		if distance_souris <= seuil_desactivation:
			dezoom_souris_en_cours = false
	elif distance_souris >= seuil_activation:
		dezoom_souris_en_cours = true
	if not dezoom_souris_en_cours:
		return 0.0
	return clampf((distance_souris - seuil_desactivation) / (1.0 - seuil_desactivation), 0.0, 1.0)

func _quand_un_corps_entre(corps: Node2D, zone: Area2D) -> void:
	if corps != joueur:
		return
	if not zones_occupees.has(zone):
		zones_occupees.append(zone)
	_activer_zone(zone)

func _quand_un_corps_sort(corps: Node2D, zone: Area2D) -> void:
	if corps != joueur:
		return
	zones_occupees.erase(zone)
	if zone == zone_actuelle:
		zone_actuelle = null
		var nouvelle_zone: Area2D = _trouver_zone_la_plus_proche()
		if nouvelle_zone != null:
			_activer_zone(nouvelle_zone)

func _synchroniser_zones_occupees() -> void:
	zones_occupees.clear()
	for enfant: Node in get_children():
		if enfant is Area2D:
			var zone: Area2D = enfant as Area2D
			if zone.overlaps_body(joueur):
				zones_occupees.append(zone)
	var zone_initiale: Area2D = _trouver_zone_la_plus_proche()
	if zone_initiale != null:
		_activer_zone(zone_initiale)

func _trouver_zone_la_plus_proche() -> Area2D:
	var zone_la_plus_proche: Area2D
	var distance_la_plus_courte: float = INF
	for zone: Area2D in zones_occupees:
		var distance: float = joueur.global_position.distance_squared_to(zone.global_position)
		if distance < distance_la_plus_courte:
			distance_la_plus_courte = distance
			zone_la_plus_proche = zone
	return zone_la_plus_proche

func _activer_zone(zone: Area2D) -> void:
	var chemin_camera: NodePath = zone.get_meta("chemin_camera", NodePath(""))
	var camera: Camera2D = get_node_or_null(chemin_camera) as Camera2D
	if camera == null:
		push_warning("Caméra introuvable pour " + zone.name)
		return
	zone_actuelle = zone
	if camera != camera_actuelle:
		if camera_actuelle != null:
			camera.offset = camera_actuelle.offset
			var position_repos_actuelle: Vector2 = positions_repos_cameras[camera_actuelle]
			var position_repos_nouvelle: Vector2 = positions_repos_cameras[camera]
			var distance_transition: float = position_repos_actuelle.distance_to(position_repos_nouvelle)
			if distance_transition >= distance_transition_immediate:
				camera.global_position = position_repos_nouvelle
				camera.zoom = zooms_repos_cameras[camera]
				transition_en_cours = false
			else:
				camera.global_position = camera_actuelle.global_position
				camera.zoom = camera_actuelle.zoom
				var proportion_distance: float = clampf(distance_transition / distance_transition_immediate, 0.0, 1.0)
				vitesse_transition_actuelle = lerpf(vitesse_lissage_position, vitesse_transition_lointaine, proportion_distance)
				transition_en_cours = true
		camera_actuelle = camera
		suivi_vertical_initialise = false
	camera.make_current()

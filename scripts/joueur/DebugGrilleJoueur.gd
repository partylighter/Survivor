extends Node2D
class_name DebugGrilleJoueur

@export_group("Refs")
@export_node_path("GestionDeplacementJoueur") var chemin_gestion_deplacement: NodePath
@export_node_path("GestionDeplacementGrilleJoueur") var chemin_deplacement_grille: NodePath

@export_group("Debug grille")
@export var debug_actif: bool = true
@export_range(1, 30, 1) var rayon_cellules_debug: int = 8
@export var rayon_point_px: float = 2.5
@export var rayon_point_actif_px: float = 6.0
@export var rayon_point_cible_px: float = 5.0
@export_range(0.0, 1.0, 0.01) var opacite_proche: float = 0.85
@export_range(0.0, 1.0, 0.01) var opacite_lointaine: float = 0.05
@export var couleur_point: Color = Color(0.72, 0.78, 0.86, 1.0)
@export var couleur_cellule_actuelle: Color = Color(0.25, 1.0, 0.45, 1.0)
@export var couleur_cellule_cible: Color = Color(1.0, 0.9, 0.2, 1.0)
@export var couleur_buffer: Color = Color(0.2, 0.9, 1.0, 1.0)
@export var couleur_bloquee: Color = Color(1.0, 0.25, 0.25, 1.0)
@export var couleur_dash: Color = Color(1.0, 0.5, 0.12, 1.0)
@export_range(0.05, 1.0, 0.05) var duree_cellule_refusee_s: float = 0.20
@export_range(0.05, 1.0, 0.05) var duree_chemin_dash_s: float = 0.25

@export_group("Debug ennemis")
@export var afficher_slots_ennemis: bool = true
@export var afficher_occupations: bool = true
@export var afficher_reservations: bool = true
@export var afficher_destinations_ennemis: bool = true
@export var afficher_flow_field: bool = false
@export_range(1, 12, 1) var rayon_slots_ennemis: int = 4
@export var couleur_slot_libre: Color = Color(0.45, 0.7, 1.0, 0.45)
@export var couleur_slot_occupe: Color = Color(1.0, 0.2, 0.45, 0.9)
@export var couleur_slot_reserve: Color = Color(1.0, 0.75, 0.15, 0.9)

var _gestion_deplacement: GestionDeplacementJoueur
var _deplacement_grille: GestionDeplacementGrilleJoueur
var _joueur: CharacterBody2D
var _gestionnaire_grille: GestionnaireGrilleCombat
var _cellule_refusee: Vector2i = Vector2i.ZERO
var _temps_cellule_refusee_s: float = 0.0
var _chemin_dash_recent: Array[Vector2i] = []
var _temps_chemin_dash_s: float = 0.0

func _ready() -> void:
	_gestion_deplacement = get_node_or_null(chemin_gestion_deplacement) as GestionDeplacementJoueur
	_deplacement_grille = get_node_or_null(chemin_deplacement_grille) as GestionDeplacementGrilleJoueur
	_joueur = get_parent() as CharacterBody2D
	if _deplacement_grille != null:
		_deplacement_grille.deplacement_refuse.connect(_sur_deplacement_refuse)
		_deplacement_grille.dash_grille_termine.connect(_sur_dash_grille_termine)

func _process(dt: float) -> void:
	if _gestionnaire_grille == null and _deplacement_grille != null:
		_gestionnaire_grille = _deplacement_grille.obtenir_gestionnaire_grille()
	_temps_cellule_refusee_s = maxf(0.0, _temps_cellule_refusee_s - dt)
	_temps_chemin_dash_s = maxf(0.0, _temps_chemin_dash_s - dt)
	if _temps_chemin_dash_s <= 0.0:
		_chemin_dash_recent.clear()
	visible = debug_actif and _gestion_deplacement != null and _gestion_deplacement.est_type_grille_actif()
	if visible:
		queue_redraw()

func _draw() -> void:
	if not visible or _deplacement_grille == null or _joueur == null:
		return
	var cellule_centrale: Vector2i = _deplacement_grille.obtenir_cellule_actuelle()
	var rayon: int = maxi(rayon_cellules_debug, 1)
	var cellules_bloquees: Dictionary = _obtenir_cellules_bloquees(cellule_centrale)
	for y in range(-rayon, rayon + 1):
		for x in range(-rayon, rayon + 1):
			var cellule := cellule_centrale + Vector2i(x, y)
			var distance_normalisee: float = clampf(Vector2(x, y).length() / float(rayon), 0.0, 1.0)
			var opacite: float = lerpf(opacite_proche, opacite_lointaine, distance_normalisee)
			var couleur: Color = couleur_point
			if cellules_bloquees.has(cellule):
				couleur = couleur_bloquee
			couleur.a *= opacite
			draw_circle(to_local(_deplacement_grille.cellule_vers_monde(cellule)), rayon_point_px, couleur)
	_dessiner_chemin_dash()
	var cellule_actuelle: Vector2i = _deplacement_grille.obtenir_cellule_actuelle()
	var cellule_cible: Vector2i = _deplacement_grille.obtenir_cellule_cible()
	draw_circle(to_local(_deplacement_grille.cellule_vers_monde(cellule_actuelle)), rayon_point_actif_px, couleur_cellule_actuelle)
	if _deplacement_grille.est_en_deplacement():
		draw_circle(to_local(_deplacement_grille.cellule_vers_monde(cellule_cible)), rayon_point_cible_px, couleur_cellule_cible)
	var direction_buffer: Vector2i = _deplacement_grille.obtenir_direction_buffer()
	if direction_buffer != Vector2i.ZERO:
		var cellule_buffer: Vector2i = cellule_cible + direction_buffer
		draw_circle(to_local(_deplacement_grille.cellule_vers_monde(cellule_buffer)), rayon_point_cible_px, couleur_buffer)
	if _temps_cellule_refusee_s > 0.0:
		var couleur_refus: Color = couleur_bloquee
		couleur_refus.a *= _temps_cellule_refusee_s / maxf(duree_cellule_refusee_s, 0.001)
		draw_circle(to_local(_deplacement_grille.cellule_vers_monde(_cellule_refusee)), rayon_point_actif_px, couleur_refus, false, 2.0)
	_dessiner_debug_ennemis(cellule_centrale)

func _dessiner_chemin_dash() -> void:
	var chemin: Array[Vector2i] = _deplacement_grille.obtenir_chemin_dash_debug() if _deplacement_grille.est_en_dash() else _chemin_dash_recent
	if chemin.size() < 2:
		return
	var couleur: Color = couleur_dash
	if not _deplacement_grille.est_en_dash():
		couleur.a *= _temps_chemin_dash_s / maxf(duree_chemin_dash_s, 0.001)
	var points := PackedVector2Array()
	for cellule in chemin:
		points.append(to_local(_deplacement_grille.cellule_vers_monde(cellule)))
	draw_polyline(points, couleur, 2.0, true)
	for point in points:
		draw_circle(point, rayon_point_cible_px, couleur)

func _obtenir_cellules_bloquees(cellule_centrale: Vector2i) -> Dictionary:
	var cellules_a_verifier: Dictionary = {}
	for y in range(-1, 2):
		for x in range(-1, 2):
			if x != 0 or y != 0:
				cellules_a_verifier[cellule_centrale + Vector2i(x, y)] = true
	if _deplacement_grille.est_en_deplacement():
		cellules_a_verifier[_deplacement_grille.obtenir_cellule_cible()] = true
	for cellule in _deplacement_grille.obtenir_chemin_dash_debug():
		cellules_a_verifier[cellule] = true
	var cellules_bloquees: Dictionary = {}
	for cellule in cellules_a_verifier:
		if not _deplacement_grille.cellule_est_accessible(_joueur, cellule, false):
			cellules_bloquees[cellule] = true
	return cellules_bloquees

func _sur_deplacement_refuse(cellule: Vector2i) -> void:
	_cellule_refusee = cellule
	_temps_cellule_refusee_s = duree_cellule_refusee_s

func _sur_dash_grille_termine(_destination: Vector2i) -> void:
	_chemin_dash_recent = _deplacement_grille.obtenir_chemin_dash_debug()
	_temps_chemin_dash_s = duree_chemin_dash_s

func _dessiner_debug_ennemis(cellule_centrale: Vector2i) -> void:
	if _gestionnaire_grille == null:
		return
	if afficher_slots_ennemis:
		var rayon: int = mini(rayon_slots_ennemis, rayon_cellules_debug)
		for y in range(-rayon, rayon + 1):
			for x in range(-rayon, rayon + 1):
				var cellule := cellule_centrale + Vector2i(x, y)
				for index_slot in range(_gestionnaire_grille.offsets_slots.size()):
					var position: Vector2 = to_local(_gestionnaire_grille.position_slot(cellule, index_slot))
					var occupant: Enemy = _gestionnaire_grille.obtenir_occupant(cellule, index_slot)
					var reservataire: Enemy = _gestionnaire_grille.obtenir_reservataire(cellule, index_slot)
					if afficher_occupations and occupant != null:
						draw_circle(position, 3.0, couleur_slot_occupe)
					elif afficher_reservations and reservataire != null:
						draw_circle(position, 3.5, couleur_slot_reserve, false, 1.5)
					else:
						draw_circle(position, 2.0, couleur_slot_libre, false, 1.0)
	if afficher_destinations_ennemis:
		for noeud in get_tree().get_nodes_in_group("ennemi_grille"):
			var ennemi := noeud as Enemy
			if ennemi == null or not is_instance_valid(ennemi):
				continue
			var deplacement := ennemi.get_node_or_null("DeplacementGrilleEnnemi") as DeplacementGrilleEnnemi
			if deplacement != null and deplacement.est_en_deplacement():
				draw_line(to_local(ennemi.global_position), to_local(deplacement.obtenir_position_cible()), couleur_slot_reserve, 1.5)
	if afficher_flow_field:
		var rayon_flow: int = mini(rayon_slots_ennemis, _gestionnaire_grille.obtenir_rayon_champ())
		for y in range(-rayon_flow, rayon_flow + 1):
			for x in range(-rayon_flow, rayon_flow + 1):
				var cellule := cellule_centrale + Vector2i(x, y)
				var direction: Vector2i = _gestionnaire_grille.obtenir_direction_champ(cellule)
				if direction != Vector2i.ZERO:
					var centre: Vector2 = to_local(_gestionnaire_grille.cellule_vers_monde(cellule))
					draw_line(centre, centre + Vector2(direction) * 12.0, couleur_slot_libre, 1.0)

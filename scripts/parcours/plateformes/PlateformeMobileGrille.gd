extends ElementParcours
class_name PlateformeMobileGrille

enum ModeTrajet {
	BOUCLE,
	ALLER_RETOUR
}

@export_group("Trajet")
@export var points_trajet: Node2D
@export var mode_trajet: ModeTrajet = ModeTrajet.ALLER_RETOUR
@export_range(0.01, 3.0, 0.01) var duree_par_cellule_s: float = 0.10
@export_range(0.0, 10.0, 0.05) var attente_entre_deplacements_s: float = 0.75
@export var demarrer_automatiquement: bool = true
@export var transporter_joueur: bool = true

var _gestionnaire: GestionnaireParcoursGrille
var _deplacement_grille: GestionDeplacementGrilleJoueur
var _joueur: CharacterBody2D
var _cellules_trajet: Array[Vector2i] = []
var _index_trajet: int = 0
var _sens_trajet: int = 1
var _index_destination: int = 0
var _cellule_depart_segment: Vector2i = Vector2i.ZERO
var _cellule_destination: Vector2i = Vector2i.ZERO
var _position_depart: Vector2 = Vector2.ZERO
var _position_destination: Vector2 = Vector2.ZERO
var _duree_segment_s: float = 0.0
var _temps_segment_s: float = 0.0
var _attente_restant_s: float = 0.0
var _en_deplacement: bool = false

func initialiser_parcours(gestionnaire) -> void:
	_gestionnaire = gestionnaire as GestionnaireParcoursGrille
	if _gestionnaire == null:
		return
	_deplacement_grille = _gestionnaire.deplacement_grille
	_joueur = _gestionnaire.joueur
	if _deplacement_grille == null:
		return
	_construire_trajet()
	_gestionnaire.enregistrer_sol_dynamique(self, cellule)
	_attente_restant_s = maxf(attente_entre_deplacements_s, 0.0)
	set_process(demarrer_automatiquement and _cellules_trajet.size() > 1)

func _process(dt: float) -> void:
	if _en_deplacement:
		_avancer_segment(dt)
		return
	_attente_restant_s = maxf(_attente_restant_s - dt, 0.0)
	if _attente_restant_s > 0.0:
		return
	_demarrer_segment_suivant()

func _construire_trajet() -> void:
	_cellules_trajet.clear()
	_cellules_trajet.append(cellule)
	var conteneur: Node2D = points_trajet
	if conteneur == null:
		conteneur = get_node_or_null("PointsTrajet") as Node2D
	if conteneur == null:
		return
	for enfant in conteneur.get_children():
		var point := enfant as Node2D
		if point == null:
			continue
		var cellule_point: Vector2i = _deplacement_grille.monde_vers_cellule(point.global_position)
		if not _cellules_trajet.has(cellule_point):
			_cellules_trajet.append(cellule_point)

func _demarrer_segment_suivant() -> void:
	var prochain_index: int = _obtenir_prochain_index()
	if prochain_index < 0:
		set_process(false)
		return
	var destination: Vector2i = _cellules_trajet[prochain_index]
	var delta_cellules: Vector2i = destination - cellule
	if delta_cellules == Vector2i.ZERO:
		_index_trajet = prochain_index
		_attente_restant_s = maxf(attente_entre_deplacements_s, 0.0)
		return
	if delta_cellules.x != 0 and delta_cellules.y != 0:
		push_warning("PlateformeMobileGrille: un segment diagonal est ignoré. Utiliser des points alignés sur la grille.")
		_index_trajet = prochain_index
		_attente_restant_s = maxf(attente_entre_deplacements_s, 0.0)
		return
	var distance_cellules: int = maxi(abs(delta_cellules.x), abs(delta_cellules.y))
	var direction: Vector2i = Vector2i(signi(delta_cellules.x), signi(delta_cellules.y))
	var joueur_transporte: bool = false
	if transporter_joueur and _joueur != null and _deplacement_grille.obtenir_cellule_actuelle() == cellule and not _deplacement_grille.est_en_deplacement():
		joueur_transporte = _deplacement_grille.appliquer_recul_cellules(_joueur, direction, distance_cellules)
		if not joueur_transporte:
			_attente_restant_s = maxf(attente_entre_deplacements_s, 0.0)
			return
	_cellule_depart_segment = cellule
	_cellule_destination = destination
	_index_destination = prochain_index
	_position_depart = global_position
	_position_destination = _deplacement_grille.cellule_vers_monde(destination)
	_duree_segment_s = maxf(duree_par_cellule_s, 0.01) * float(distance_cellules)
	if joueur_transporte:
		_duree_segment_s = maxf(_deplacement_grille.duree_recul_cellule_s, 0.01) * float(distance_cellules)
	_temps_segment_s = 0.0
	_en_deplacement = true
	_gestionnaire.enregistrer_sol_dynamique(self, destination)

func _avancer_segment(dt: float) -> void:
	_temps_segment_s = minf(_temps_segment_s + dt, _duree_segment_s)
	var progression: float = _temps_segment_s / maxf(_duree_segment_s, 0.001)
	var progression_douce: float = progression * progression * (3.0 - 2.0 * progression)
	global_position = _position_depart.lerp(_position_destination, progression_douce)
	if _temps_segment_s < _duree_segment_s:
		return
	global_position = _position_destination
	var ancienne_cellule: Vector2i = _cellule_depart_segment
	cellule = _cellule_destination
	_index_trajet = _index_destination
	_en_deplacement = false
	_attente_restant_s = maxf(attente_entre_deplacements_s, 0.0)
	call_deferred("_retirer_ancienne_cellule", ancienne_cellule)

func _retirer_ancienne_cellule(ancienne_cellule: Vector2i) -> void:
	if _gestionnaire != null and is_instance_valid(_gestionnaire) and ancienne_cellule != cellule:
		_gestionnaire.retirer_sol_dynamique(self, ancienne_cellule)

func _obtenir_prochain_index() -> int:
	if _cellules_trajet.size() < 2:
		return -1
	if mode_trajet == ModeTrajet.BOUCLE:
		return (_index_trajet + 1) % _cellules_trajet.size()
	var prochain_index: int = _index_trajet + _sens_trajet
	if prochain_index < 0 or prochain_index >= _cellules_trajet.size():
		_sens_trajet *= -1
		prochain_index = _index_trajet + _sens_trajet
	return prochain_index

func _exit_tree() -> void:
	if _gestionnaire == null or not is_instance_valid(_gestionnaire):
		return
	_gestionnaire.retirer_sol_dynamique(self, cellule)
	if _en_deplacement and _cellule_destination != cellule:
		_gestionnaire.retirer_sol_dynamique(self, _cellule_destination)

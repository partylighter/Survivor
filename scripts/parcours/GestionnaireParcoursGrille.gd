extends Node
class_name GestionnaireParcoursGrille

signal joueur_tombe(cellule: Vector2i, reapparition: Vector2i)
signal joueur_reapparu(cellule: Vector2i)
signal checkpoint_change(cellule: Vector2i)

@export_group("Refs optionnelles")
@export var joueur: CharacterBody2D
@export var deplacement_grille: GestionDeplacementGrilleJoueur
@export var sol_parcours: TileMapLayer
@export var conteneur_elements: Node

var _elements_par_cellule: Dictionary = {}
var _cellule_depart: Vector2i = Vector2i.ZERO
var _checkpoint_actuel: Vector2i = Vector2i.ZERO
var _checkpoint_initialise: bool = false
var _derniere_cellule_sure: Vector2i = Vector2i.ZERO
var _cellule_reapparition_en_attente: Vector2i = Vector2i.ZERO
var _chute_en_cours: bool = false

func _ready() -> void:
	call_deferred("_initialiser")

func _initialiser() -> void:
	_resoudre_references()
	if not _configuration_valide():
		return
	deplacement_grille.synchroniser_sur_grille(joueur)
	var cellule_depart: Vector2i = deplacement_grille.obtenir_cellule_actuelle()
	if not cellule_est_sure(cellule_depart):
		push_error("GestionnaireParcoursGrille: la cellule de départ ne possède pas de sol.")
		return
	_cellule_depart = cellule_depart
	_checkpoint_actuel = cellule_depart
	_derniere_cellule_sure = cellule_depart
	_cellule_reapparition_en_attente = cellule_depart
	_checkpoint_initialise = true
	_recenser_elements(conteneur_elements)
	if not deplacement_grille.cellule_atteinte.is_connected(_quand_cellule_atteinte):
		deplacement_grille.cellule_atteinte.connect(_quand_cellule_atteinte)

func cellule_est_sure(cellule: Vector2i) -> bool:
	if sol_parcours == null or deplacement_grille == null:
		return false
	var position_monde: Vector2 = deplacement_grille.cellule_vers_monde(cellule)
	var cellule_sol: Vector2i = sol_parcours.local_to_map(sol_parcours.to_local(position_monde))
	return sol_parcours.get_cell_source_id(cellule_sol) >= 0

func definir_checkpoint(cellule: Vector2i) -> void:
	if not cellule_est_sure(cellule):
		push_warning("GestionnaireParcoursGrille: checkpoint ignoré car la cellule %s n'a pas de sol." % str(cellule))
		return
	if _checkpoint_initialise and _checkpoint_actuel == cellule:
		return
	_checkpoint_actuel = cellule
	_checkpoint_initialise = true
	checkpoint_change.emit(cellule)

func obtenir_checkpoint_actuel() -> Vector2i:
	return _checkpoint_actuel

func obtenir_derniere_cellule_sure() -> Vector2i:
	return _derniere_cellule_sure

func _quand_cellule_atteinte(cellule: Vector2i) -> void:
	if _chute_en_cours:
		return
	if not cellule_est_sure(cellule):
		_chute_en_cours = true
		_cellule_reapparition_en_attente = _obtenir_cellule_reapparition()
		joueur_tombe.emit(cellule, _cellule_reapparition_en_attente)
		call_deferred("_reapparaitre_checkpoint")
		return
	_derniere_cellule_sure = cellule
	_activer_elements(cellule)

func _obtenir_cellule_reapparition() -> Vector2i:
	if cellule_est_sure(_derniere_cellule_sure):
		return _derniere_cellule_sure
	if _checkpoint_initialise and cellule_est_sure(_checkpoint_actuel):
		return _checkpoint_actuel
	return _cellule_depart

func _reapparaitre_checkpoint() -> void:
	if joueur == null or deplacement_grille == null:
		_chute_en_cours = false
		return
	joueur.global_position = deplacement_grille.cellule_vers_monde(_cellule_reapparition_en_attente)
	deplacement_grille.synchroniser_sur_grille(joueur)
	_derniere_cellule_sure = _cellule_reapparition_en_attente
	_chute_en_cours = false
	joueur_reapparu.emit(_cellule_reapparition_en_attente)

func _activer_elements(cellule: Vector2i) -> void:
	var elements: Array = _elements_par_cellule.get(cellule, [])
	for valeur in elements:
		var element := valeur as ElementParcours
		if element != null and is_instance_valid(element):
			element.activer(joueur, self)

func _recenser_elements(noeud: Node) -> void:
	if noeud == null:
		return
	for enfant in noeud.get_children():
		var element := enfant as ElementParcours
		if element != null:
			element.initialiser(deplacement_grille)
			_enregistrer_element(element)
		_recenser_elements(enfant)

func _enregistrer_element(element: ElementParcours) -> void:
	if element == null or not element.est_initialise():
		return
	var elements: Array = _elements_par_cellule.get(element.cellule, [])
	elements.append(element)
	_elements_par_cellule[element.cellule] = elements

func _resoudre_references() -> void:
	if joueur == null or not is_instance_valid(joueur):
		joueur = get_tree().get_first_node_in_group("joueur_principal") as CharacterBody2D
	if deplacement_grille == null or not is_instance_valid(deplacement_grille):
		deplacement_grille = get_tree().get_first_node_in_group("deplacement_grille_joueur") as GestionDeplacementGrilleJoueur
	var racine_niveau: Node = get_parent()
	if sol_parcours == null and racine_niveau != null:
		sol_parcours = racine_niveau.get_node_or_null("Parcours/SolParcours") as TileMapLayer
	if conteneur_elements == null and racine_niveau != null:
		conteneur_elements = racine_niveau.get_node_or_null("Parcours/Elements")

func _configuration_valide() -> bool:
	var valide: bool = true
	if joueur == null:
		push_error("GestionnaireParcoursGrille: joueur introuvable.")
		valide = false
	if deplacement_grille == null:
		push_error("GestionnaireParcoursGrille: déplacement grille joueur introuvable.")
		valide = false
	if sol_parcours == null:
		push_error("GestionnaireParcoursGrille: Parcours/SolParcours introuvable.")
		valide = false
	if conteneur_elements == null:
		push_error("GestionnaireParcoursGrille: Parcours/Elements introuvable.")
		valide = false
	return valide

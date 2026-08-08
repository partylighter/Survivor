extends Node
class_name GestionnaireParcoursGrille

signal joueur_tombe(cellule: Vector2i, reapparition: Vector2i)
signal joueur_reapparu(cellule: Vector2i)
signal checkpoint_change(cellule: Vector2i)
signal occupant_entree(cellule: Vector2i, occupant: Node)
signal occupant_sortie(cellule: Vector2i, occupant: Node)
signal support_entree(cellule: Vector2i, support: Node)
signal support_sortie(cellule: Vector2i, support: Node)
signal reservations_changees

const MAX_HISTORIQUE_CELLULES_SURES: int = 32

@export_group("Refs optionnelles")
@export var joueur: CharacterBody2D
@export var deplacement_grille: GestionDeplacementGrilleJoueur
@export var sol_parcours: TileMapLayer
@export var conteneur_elements: Node

var _elements_par_cellule: Dictionary = {}
var _sol_dynamique_par_cellule: Dictionary = {}
var _occupants_par_cellule: Dictionary = {}
var _supports_par_cellule: Dictionary = {}
var _reservations_par_cellule: Dictionary = {}
var _reservations_par_occupant: Dictionary = {}
var _historique_cellules_sures: Array[Vector2i] = []
var _cellule_depart: Vector2i = Vector2i.ZERO
var _checkpoint_actuel: Vector2i = Vector2i.ZERO
var _checkpoint_initialise: bool = false
var _derniere_cellule_sure: Vector2i = Vector2i.ZERO
var _cellule_reapparition_en_attente: Vector2i = Vector2i.ZERO
var _chute_en_cours: bool = false

func _ready() -> void:
	add_to_group("gestionnaire_parcours_grille")
	call_deferred("_initialiser")

func _initialiser() -> void:
	_resoudre_references()
	if not _configuration_valide():
		return
	deplacement_grille.synchroniser_sur_grille(joueur)
	_recenser_elements(conteneur_elements)
	var cellule_depart: Vector2i = deplacement_grille.obtenir_cellule_actuelle()
	if not cellule_est_sure(cellule_depart):
		push_error("GestionnaireParcoursGrille: la cellule de départ ne possède pas de sol.")
		return
	_cellule_depart = cellule_depart
	_checkpoint_actuel = cellule_depart
	_cellule_reapparition_en_attente = cellule_depart
	_checkpoint_initialise = true
	_derniere_cellule_sure = cellule_depart
	_memoriser_cellule_sure(cellule_depart)
	if not deplacement_grille.cellule_atteinte.is_connected(_quand_cellule_atteinte):
		deplacement_grille.cellule_atteinte.connect(_quand_cellule_atteinte)

func cellule_est_sure(cellule: Vector2i) -> bool:
	if _cellule_a_sol_statique(cellule):
		return true
	return not _obtenir_sources_sol_dynamique_valides(cellule).is_empty()

func cellule_est_stable_pour_reapparition(cellule: Vector2i) -> bool:
	if _cellule_a_sol_statique(cellule):
		return true
	for source in _obtenir_sources_sol_dynamique_valides(cellule):
		if source.has_method("autorise_reapparition_sur_sol") and bool(source.call("autorise_reapparition_sur_sol")):
			return true
	return false

func enregistrer_sol_dynamique(source: Node, cellule: Vector2i) -> void:
	if source == null or not is_instance_valid(source):
		return
	var sources: Array = _sol_dynamique_par_cellule.get(cellule, [])
	if not sources.has(source):
		sources.append(source)
	_sol_dynamique_par_cellule[cellule] = sources

func retirer_sol_dynamique(source: Node, cellule: Vector2i) -> void:
	if not _sol_dynamique_par_cellule.has(cellule):
		return
	var sources: Array = _sol_dynamique_par_cellule.get(cellule, [])
	sources.erase(source)
	if sources.is_empty():
		_sol_dynamique_par_cellule.erase(cellule)
	else:
		_sol_dynamique_par_cellule[cellule] = sources
	if cellule_est_sure(cellule):
		return
	var occupant: Node = obtenir_occupant(cellule)
	if occupant != null and occupant.has_method("quand_sol_disparait"):
		occupant.call("quand_sol_disparait", cellule)
	if deplacement_grille != null and deplacement_grille.obtenir_cellule_actuelle() == cellule:
		if deplacement_grille.est_en_transport_plateforme():
			return
		faire_tomber_joueur(cellule)

func enregistrer_occupant(occupant: Node, cellule: Vector2i) -> bool:
	if occupant == null or not is_instance_valid(occupant):
		return false
	var occupant_existant: Node = obtenir_occupant(cellule)
	if occupant_existant != null and occupant_existant != occupant:
		push_warning("GestionnaireParcoursGrille: cellule %s déjà occupée." % str(cellule))
		return false
	var reservataire: Node = obtenir_reservataire(cellule)
	if reservataire != null and reservataire != occupant:
		return false
	if occupant_existant == occupant:
		return true
	_occupants_par_cellule[cellule] = occupant
	occupant_entree.emit(cellule, occupant)
	return true

func retirer_occupant(occupant: Node, cellule: Vector2i) -> void:
	if occupant == null:
		return
	if obtenir_occupant(cellule) == occupant:
		_occupants_par_cellule.erase(cellule)
		occupant_sortie.emit(cellule, occupant)
	liberer_reservations_occupant(occupant)

func obtenir_occupant(cellule: Vector2i) -> Node:
	if not _occupants_par_cellule.has(cellule):
		return null
	var valeur: Variant = _occupants_par_cellule.get(cellule)
	if not is_instance_valid(valeur):
		_occupants_par_cellule.erase(cellule)
		return null
	var occupant := valeur as Node
	if occupant == null:
		_occupants_par_cellule.erase(cellule)
		return null
	return occupant

func cellule_est_occupee(cellule: Vector2i, occupant_ignore: Node = null) -> bool:
	var occupant: Node = obtenir_occupant(cellule)
	return occupant != null and occupant != occupant_ignore

func enregistrer_support(support: Node, cellule: Vector2i) -> bool:
	if support == null or not is_instance_valid(support):
		return false
	var support_existant: Node = obtenir_support(cellule)
	if support_existant != null and support_existant != support:
		return false
	if cellule_est_occupee(cellule):
		return false
	var reservataire: Node = obtenir_reservataire(cellule)
	if reservataire != null and reservataire != support:
		return false
	if support_existant == support:
		return true
	_supports_par_cellule[cellule] = support
	support_entree.emit(cellule, support)
	return true

func retirer_support(support: Node, cellule: Vector2i) -> void:
	if support == null:
		return
	if obtenir_support(cellule) == support:
		_supports_par_cellule.erase(cellule)
		support_sortie.emit(cellule, support)
	liberer_reservations_occupant(support)

func obtenir_support(cellule: Vector2i) -> Node:
	if not _supports_par_cellule.has(cellule):
		return null
	var valeur: Variant = _supports_par_cellule.get(cellule)
	if not is_instance_valid(valeur):
		_supports_par_cellule.erase(cellule)
		return null
	var support := valeur as Node
	if support == null:
		_supports_par_cellule.erase(cellule)
		return null
	return support

func cellule_disponible_pour_support(cellule: Vector2i, support: Node) -> bool:
	var support_existant: Node = obtenir_support(cellule)
	if support_existant != null and support_existant != support:
		return false
	if cellule_est_occupee(cellule):
		return false
	return not cellule_est_reservee(cellule, support)

func obtenir_reservataire(cellule: Vector2i) -> Node:
	if not _reservations_par_cellule.has(cellule):
		return null
	var valeur: Variant = _reservations_par_cellule.get(cellule)
	if not is_instance_valid(valeur):
		_reservations_par_cellule.erase(cellule)
		return null
	var reservataire := valeur as Node
	if reservataire == null:
		_reservations_par_cellule.erase(cellule)
		return null
	return reservataire

func cellule_est_reservee(cellule: Vector2i, occupant_ignore: Node = null) -> bool:
	var reservataire: Node = obtenir_reservataire(cellule)
	return reservataire != null and reservataire != occupant_ignore

func cellule_disponible_pour_occupant(cellule: Vector2i, occupant: Node) -> bool:
	if cellule_est_occupee(cellule, occupant):
		return false
	return not cellule_est_reservee(cellule, occupant)

func reserver_cellules_occupant(occupant: Node, cellules: Array[Vector2i]) -> bool:
	if occupant == null or not is_instance_valid(occupant):
		return false
	var cellules_uniques: Array[Vector2i] = []
	for cellule in cellules:
		if not cellules_uniques.has(cellule):
			cellules_uniques.append(cellule)
	for cellule in cellules_uniques:
		if not cellule_disponible_pour_occupant(cellule, occupant):
			return false
	liberer_reservations_occupant(occupant)
	for cellule in cellules_uniques:
		_reservations_par_cellule[cellule] = occupant
	if cellules_uniques.is_empty():
		_reservations_par_occupant.erase(occupant)
	else:
		_reservations_par_occupant[occupant] = cellules_uniques
	reservations_changees.emit()
	return true

func reserver_poussee_chaine(reservataire: Node, occupants: Array, direction: Vector2i) -> bool:
	if reservataire == null or not is_instance_valid(reservataire) or occupants.is_empty():
		return false
	if abs(direction.x) + abs(direction.y) != 1:
		return false
	var cellules_sources: Array[Vector2i] = []
	var cellules_destinations: Array[Vector2i] = []
	for valeur in occupants:
		if not is_instance_valid(valeur):
			return false
		var element := valeur as ElementParcours
		if element == null or obtenir_occupant(element.cellule) != valeur:
			return false
		cellules_sources.append(element.cellule)
		cellules_destinations.append(element.cellule + direction)
	for index in range(cellules_destinations.size()):
		var destination: Vector2i = cellules_destinations[index]
		var occupant_destination: Node = obtenir_occupant(destination)
		if occupant_destination != null and not occupants.has(occupant_destination):
			return false
		var reservataire_existant: Node = obtenir_reservataire(destination)
		if reservataire_existant != null and reservataire_existant != reservataire:
			return false
	liberer_reservations_occupant(reservataire)
	for destination in cellules_destinations:
		_reservations_par_cellule[destination] = reservataire
	_reservations_par_occupant[reservataire] = cellules_destinations
	reservations_changees.emit()
	return true

func terminer_poussee_chaine(reservataire: Node, occupants: Array, direction: Vector2i) -> bool:
	if reservataire == null or occupants.is_empty() or abs(direction.x) + abs(direction.y) != 1:
		return false
	var cellules_sources: Array[Vector2i] = []
	var cellules_destinations: Array[Vector2i] = []
	for valeur in occupants:
		if not is_instance_valid(valeur):
			liberer_reservations_occupant(reservataire)
			return false
		var element := valeur as ElementParcours
		if element == null or obtenir_occupant(element.cellule) != valeur:
			liberer_reservations_occupant(reservataire)
			return false
		var destination: Vector2i = element.cellule + direction
		if obtenir_reservataire(destination) != reservataire:
			liberer_reservations_occupant(reservataire)
			return false
		cellules_sources.append(element.cellule)
		cellules_destinations.append(destination)
	for cellule_source in cellules_sources:
		var occupant_source: Node = obtenir_occupant(cellule_source)
		if occupant_source != null:
			_occupants_par_cellule.erase(cellule_source)
			occupant_sortie.emit(cellule_source, occupant_source)
	liberer_reservations_occupant(reservataire)
	for index in range(occupants.size()):
		var occupant: Node = occupants[index]
		var destination: Vector2i = cellules_destinations[index]
		_occupants_par_cellule[destination] = occupant
		occupant_entree.emit(destination, occupant)
	return true

func liberer_reservations_occupant(occupant: Node) -> void:
	if occupant == null or not _reservations_par_occupant.has(occupant):
		return
	var cellules: Array = _reservations_par_occupant.get(occupant, [])
	for valeur in cellules:
		var cellule: Vector2i = valeur
		if obtenir_reservataire(cellule) == occupant:
			_reservations_par_cellule.erase(cellule)
	_reservations_par_occupant.erase(occupant)
	reservations_changees.emit()

func terminer_deplacement_occupant(occupant: Node, ancienne_cellule: Vector2i, nouvelle_cellule: Vector2i, occuper_destination: bool = true) -> bool:
	if occupant == null or not is_instance_valid(occupant):
		return false
	var occupant_depart: Node = obtenir_occupant(ancienne_cellule)
	if occupant_depart != occupant:
		liberer_reservations_occupant(occupant)
		push_warning("GestionnaireParcoursGrille: occupation source perdue pendant un déplacement.")
		return false
	if obtenir_reservataire(nouvelle_cellule) != occupant:
		liberer_reservations_occupant(occupant)
		push_warning("GestionnaireParcoursGrille: réservation destination perdue pendant un déplacement.")
		return false
	if occuper_destination:
		var occupant_destination: Node = obtenir_occupant(nouvelle_cellule)
		if occupant_destination != null and occupant_destination != occupant:
			liberer_reservations_occupant(occupant)
			push_warning("GestionnaireParcoursGrille: destination occupée pendant un déplacement.")
			return false
	_occupants_par_cellule.erase(ancienne_cellule)
	occupant_sortie.emit(ancienne_cellule, occupant)
	liberer_reservations_occupant(occupant)
	if occuper_destination:
		_occupants_par_cellule[nouvelle_cellule] = occupant
		occupant_entree.emit(nouvelle_cellule, occupant)
	return true

func occupant_autorise_joueur(occupant: Node) -> bool:
	if occupant == null or not is_instance_valid(occupant):
		return true
	if not occupant.has_method("autorise_joueur_sur_cellule"):
		return false
	return bool(occupant.call("autorise_joueur_sur_cellule"))

func cellule_est_disponible_pour_joueur(cellule: Vector2i) -> bool:
	if cellule_est_reservee(cellule):
		return false
	return occupant_autorise_joueur(obtenir_occupant(cellule))

func faire_tomber_joueur(cellule: Vector2i) -> void:
	if _chute_en_cours:
		return
	_chute_en_cours = true
	_cellule_reapparition_en_attente = _obtenir_cellule_reapparition()
	joueur_tombe.emit(cellule, _cellule_reapparition_en_attente)
	call_deferred("_reapparaitre_checkpoint")

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
		faire_tomber_joueur(cellule)
		return
	_memoriser_cellule_sure(cellule)
	_activer_elements(cellule)

func _cellule_a_sol_statique(cellule: Vector2i) -> bool:
	if sol_parcours == null or deplacement_grille == null:
		return false
	var position_monde: Vector2 = deplacement_grille.cellule_vers_monde(cellule)
	var cellule_sol: Vector2i = sol_parcours.local_to_map(sol_parcours.to_local(position_monde))
	return sol_parcours.get_cell_source_id(cellule_sol) >= 0

func _obtenir_sources_sol_dynamique_valides(cellule: Vector2i) -> Array:
	if not _sol_dynamique_par_cellule.has(cellule):
		return []
	var sources: Array = _sol_dynamique_par_cellule.get(cellule, [])
	var sources_valides: Array = []
	for source in sources:
		if is_instance_valid(source):
			sources_valides.append(source)
	if sources_valides.is_empty():
		_sol_dynamique_par_cellule.erase(cellule)
	else:
		_sol_dynamique_par_cellule[cellule] = sources_valides
	return sources_valides

func _memoriser_cellule_sure(cellule: Vector2i) -> void:
	if not cellule_est_stable_pour_reapparition(cellule):
		return
	_derniere_cellule_sure = cellule
	if _historique_cellules_sures.is_empty() or _historique_cellules_sures.back() != cellule:
		_historique_cellules_sures.append(cellule)
	while _historique_cellules_sures.size() > MAX_HISTORIQUE_CELLULES_SURES:
		_historique_cellules_sures.pop_front()

func _cellule_reapparition_valide(cellule: Vector2i) -> bool:
	return cellule_est_stable_pour_reapparition(cellule) and cellule_est_disponible_pour_joueur(cellule)

func _cellule_checkpoint_reapparition_valide(cellule: Vector2i) -> bool:
	return cellule_est_sure(cellule) and cellule_est_disponible_pour_joueur(cellule)

func _obtenir_cellule_reapparition() -> Vector2i:
	if _cellule_reapparition_valide(_derniere_cellule_sure):
		return _derniere_cellule_sure
	for index in range(_historique_cellules_sures.size() - 1, -1, -1):
		var cellule: Vector2i = _historique_cellules_sures[index]
		if _cellule_reapparition_valide(cellule):
			return cellule
	if _checkpoint_initialise and _cellule_checkpoint_reapparition_valide(_checkpoint_actuel):
		return _checkpoint_actuel
	if _cellule_checkpoint_reapparition_valide(_cellule_depart):
		return _cellule_depart
	push_warning("GestionnaireParcoursGrille: aucune cellule de réapparition sûre et libre n'a été trouvée.")
	return _cellule_depart

func _reapparaitre_checkpoint() -> void:
	if joueur == null or deplacement_grille == null:
		_chute_en_cours = false
		return
	if not _cellule_checkpoint_reapparition_valide(_cellule_reapparition_en_attente):
		_cellule_reapparition_en_attente = _obtenir_cellule_reapparition()
	joueur.global_position = deplacement_grille.cellule_vers_monde(_cellule_reapparition_en_attente)
	deplacement_grille.synchroniser_sur_grille(joueur)
	_memoriser_cellule_sure(_cellule_reapparition_en_attente)
	_chute_en_cours = false
	joueur_reapparu.emit(_cellule_reapparition_en_attente)

func _activer_elements(cellule: Vector2i) -> void:
	var elements: Array = _elements_par_cellule.get(cellule, [])
	var elements_valides: Array = []
	for valeur in elements:
		if not is_instance_valid(valeur):
			continue
		var element := valeur as ElementParcours
		if element == null:
			continue
		element.activer(joueur, self)
		if is_instance_valid(element):
			elements_valides.append(element)
	if elements_valides.is_empty():
		_elements_par_cellule.erase(cellule)
	else:
		_elements_par_cellule[cellule] = elements_valides

func _recenser_elements(noeud: Node) -> void:
	if noeud == null:
		return
	for enfant in noeud.get_children():
		var element := enfant as ElementParcours
		if element != null:
			element.initialiser(deplacement_grille)
			_enregistrer_element(element)
			element.initialiser_parcours(self)
		_recenser_elements(enfant)

func _enregistrer_element(element: ElementParcours) -> void:
	if element == null or not element.est_initialise() or not element.doit_etre_active_par_arrivee_joueur():
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

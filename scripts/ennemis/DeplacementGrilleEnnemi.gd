extends Node
class_name DeplacementGrilleEnnemi

signal cellule_ennemi_quittee(ennemi: Enemy, cellule: Vector2i)
signal cellule_ennemi_atteinte(ennemi: Enemy, cellule: Vector2i)

const DIRECTIONS_CARDINALES: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
const DIRECTIONS_DIAGONALES: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]

@export var diagonales_autorisees: bool = false
@export_range(0.01, 1.0, 0.01) var duree_pas_min_s: float = 0.12
@export_range(0.01, 2.0, 0.01) var duree_pas_max_s: float = 0.60
@export_range(0.05, 2.0, 0.05) var multiplicateur_vitesse_grille: float = 0.35
@export_range(0.0, 0.5, 0.01) var decalage_initial_max_s: float = 0.10
@export_range(0, 8, 1) var distance_arret_cellules: int = 1
@export_range(0.01, 0.5, 0.01) var intervalle_decision_s: float = 0.05

var cellule_actuelle: Vector2i = Vector2i.ZERO
var cellule_cible: Vector2i = Vector2i.ZERO
var slot_actuel: int = -1
var slot_cible: int = -1
var position_depart: Vector2 = Vector2.ZERO
var position_cible: Vector2 = Vector2.ZERO
var en_deplacement: bool = false
var progression_deplacement: float = 0.0
var duree_deplacement_s: float = 0.0

var _gestionnaire_grille: GestionnaireGrilleCombat
var _gestionnaire_ennemis: GestionnaireEnnemis
var _ennemi: Enemy
var _temps_deplacement_s: float = 0.0
var _attente_decision_s: float = 0.0
var _initialise: bool = false

func _ready() -> void:
	add_to_group("deplacement_grille_ennemi")
	_resoudre_gestionnaires()

func est_actif_pour(ennemi: Enemy) -> bool:
	if not is_inside_tree():
		return false
	_resoudre_gestionnaires()
	return _gestionnaire_grille != null and _gestionnaire_ennemis != null and _gestionnaire_ennemis.ennemi_utilise_grille(ennemi)

func activer(ennemi: Enemy) -> void:
	_ennemi = ennemi
	_resoudre_gestionnaires()
	if not est_actif_pour(ennemi):
		return
	_desinscrire()
	var cellule_spawn: Vector2i = _gestionnaire_grille.monde_vers_cellule(ennemi.global_position)
	var choix: Dictionary = _trouver_slot_initial(cellule_spawn, ennemi.global_position)
	if choix.is_empty():
		_initialise = false
		return
	cellule_actuelle = choix["cellule"]
	slot_actuel = int(choix["slot"])
	cellule_cible = cellule_actuelle
	slot_cible = slot_actuel
	position_cible = _gestionnaire_grille.position_slot(cellule_actuelle, slot_actuel)
	position_depart = position_cible
	ennemi.global_position = position_cible
	ennemi.velocity = Vector2.ZERO
	_initialise = _gestionnaire_grille.enregistrer_occupation(cellule_actuelle, slot_actuel, ennemi)
	_attente_decision_s = randf_range(0.0, decalage_initial_max_s)
	if not ennemi.is_in_group("ennemi_grille"):
		ennemi.add_to_group("ennemi_grille")

func desactiver(ennemi: Enemy) -> void:
	if _ennemi == null:
		_ennemi = ennemi
	_desinscrire()
	if ennemi != null and ennemi.is_in_group("ennemi_grille"):
		ennemi.remove_from_group("ennemi_grille")

func traiter(ennemi: Enemy, cible: Player, dt: float, vitesse: float, autoriser_decision: bool) -> bool:
	if not est_actif_pour(ennemi):
		return false
	if not _initialise:
		activer(ennemi)
	if not _initialise:
		ennemi.velocity = Vector2.ZERO
		return true
	if en_deplacement:
		if autoriser_decision:
			_avancer_deplacement(ennemi, dt)
		else:
			ennemi.velocity = Vector2.ZERO
		return true
	ennemi.velocity = Vector2.ZERO
	_attente_decision_s = maxf(0.0, _attente_decision_s - dt)
	if not autoriser_decision or _attente_decision_s > 0.0 or cible == null or not is_instance_valid(cible):
		return true
	var cellule_joueur: Vector2i = _gestionnaire_grille.obtenir_cellule_joueur()
	var distance_joueur: int = _distance_cellules(cellule_actuelle, cellule_joueur)
	if distance_joueur > 0 and distance_joueur <= distance_arret_cellules:
		if _position_en_portee_contact(ennemi, ennemi.global_position):
			_attente_decision_s = intervalle_decision_s
			return true
		if _essayer_rejoindre_slot_contact(ennemi, vitesse):
			_attente_decision_s = intervalle_decision_s
			return true
	_choisir_et_demarrer_pas(ennemi, cellule_joueur, vitesse)
	_attente_decision_s = intervalle_decision_s
	return true

func obtenir_position_cible() -> Vector2:
	return position_cible

func obtenir_cellule_actuelle() -> Vector2i:
	return cellule_actuelle

func obtenir_cellule_cible() -> Vector2i:
	return cellule_cible

func est_en_deplacement() -> bool:
	return en_deplacement

func _choisir_et_demarrer_pas(ennemi: Enemy, cellule_joueur: Vector2i, vitesse: float) -> void:
	var candidats: Array[Dictionary] = []
	var directions: Array[Vector2i] = DIRECTIONS_CARDINALES.duplicate()
	if diagonales_autorisees:
		directions.append_array(DIRECTIONS_DIAGONALES)
	var dans_champ: bool = _gestionnaire_grille.champ_contient(cellule_actuelle)
	for direction in directions:
		var cellule: Vector2i = cellule_actuelle + direction
		if cellule == cellule_joueur:
			continue
		if _gestionnaire_grille.cellule_bloquee_ou_scanner(cellule):
			continue
		if abs(direction.x) == 1 and abs(direction.y) == 1 and not _diagonale_accessible(direction):
			continue
		var slots: Array[int] = _gestionnaire_grille.obtenir_slots_libres(cellule)
		if slots.is_empty():
			continue
		var cout_champ: int = _gestionnaire_grille.obtenir_cout_champ(cellule)
		if dans_champ and cout_champ < 0:
			continue
		var cout_direction: int = cout_champ if cout_champ >= 0 else _distance_cellules(cellule, cellule_joueur)
		var score: float = float(cout_direction + _gestionnaire_grille.obtenir_cout_congestion(cellule))
		candidats.append({"cellule": cellule, "slots": slots, "score": score + randf() * 0.01})
	candidats.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) < float(b["score"]))
	for candidat in candidats:
		var cellule: Vector2i = candidat["cellule"]
		var slots_tries: Array[int] = candidat["slots"]
		slots_tries.sort_custom(func(a: int, b: int) -> bool:
			return ennemi.global_position.distance_squared_to(_gestionnaire_grille.position_slot(cellule, a)) < ennemi.global_position.distance_squared_to(_gestionnaire_grille.position_slot(cellule, b)))
		for index_slot in slots_tries:
			if _gestionnaire_grille.reserver_slot(cellule, index_slot, ennemi):
				_demarrer_pas(ennemi, cellule, index_slot, vitesse)
				return

func _demarrer_pas(ennemi: Enemy, cellule: Vector2i, index_slot: int, vitesse: float) -> void:
	cellule_cible = cellule
	slot_cible = index_slot
	position_depart = ennemi.global_position
	position_cible = _gestionnaire_grille.position_slot(cellule_cible, slot_cible)
	var distance: float = position_depart.distance_to(position_cible)
	var vitesse_effective: float = maxf(vitesse * multiplicateur_vitesse_grille, 1.0)
	duree_deplacement_s = clampf(distance / vitesse_effective, minf(duree_pas_min_s, duree_pas_max_s), maxf(duree_pas_min_s, duree_pas_max_s))
	_temps_deplacement_s = 0.0
	progression_deplacement = 0.0
	en_deplacement = true
	cellule_ennemi_quittee.emit(ennemi, cellule_actuelle)

func _avancer_deplacement(ennemi: Enemy, dt: float) -> void:
	var ancienne_position: Vector2 = ennemi.global_position
	_temps_deplacement_s = minf(_temps_deplacement_s + dt, duree_deplacement_s)
	progression_deplacement = _temps_deplacement_s / maxf(duree_deplacement_s, 0.001)
	var progression_douce: float = progression_deplacement * progression_deplacement * (3.0 - 2.0 * progression_deplacement)
	ennemi.global_position = position_depart.lerp(position_cible, progression_douce)
	ennemi.velocity = (ennemi.global_position - ancienne_position) / maxf(dt, 0.0001)
	if progression_deplacement < 1.0:
		return
	ennemi.global_position = position_cible
	ennemi.velocity = Vector2.ZERO
	_gestionnaire_grille.confirmer_occupation(cellule_cible, slot_cible, ennemi)
	cellule_actuelle = cellule_cible
	slot_actuel = slot_cible
	en_deplacement = false
	progression_deplacement = 1.0
	cellule_ennemi_atteinte.emit(ennemi, cellule_actuelle)

func _trouver_slot_initial(cellule_depart: Vector2i, position_monde: Vector2) -> Dictionary:
	for rayon in range(0, 3):
		var choix: Dictionary = {}
		var meilleure_distance: float = INF
		for y in range(-rayon, rayon + 1):
			for x in range(-rayon, rayon + 1):
				if rayon > 0 and abs(x) < rayon and abs(y) < rayon:
					continue
				var cellule := cellule_depart + Vector2i(x, y)
				if _gestionnaire_grille.cellule_bloquee_ou_scanner(cellule):
					continue
				for index_slot in _gestionnaire_grille.obtenir_slots_libres(cellule):
					var distance: float = position_monde.distance_squared_to(_gestionnaire_grille.position_slot(cellule, index_slot))
					if distance < meilleure_distance:
						meilleure_distance = distance
						choix = {"cellule": cellule, "slot": index_slot}
		if not choix.is_empty():
			return choix
	return {}

func _essayer_rejoindre_slot_contact(ennemi: Enemy, vitesse: float) -> bool:
	var slots: Array[int] = _gestionnaire_grille.obtenir_slots_libres(cellule_actuelle)
	slots.sort_custom(func(a: int, b: int) -> bool:
		return ennemi.global_position.distance_squared_to(_gestionnaire_grille.position_slot(cellule_actuelle, a)) < ennemi.global_position.distance_squared_to(_gestionnaire_grille.position_slot(cellule_actuelle, b)))
	for index_slot in slots:
		var position: Vector2 = _gestionnaire_grille.position_slot(cellule_actuelle, index_slot)
		if not _position_en_portee_contact(ennemi, position):
			continue
		if _gestionnaire_grille.reserver_slot(cellule_actuelle, index_slot, ennemi):
			_demarrer_pas(ennemi, cellule_actuelle, index_slot, vitesse)
			return true
	return false

func _position_en_portee_contact(ennemi: Enemy, position: Vector2) -> bool:
	return ennemi.contact_damage != null and ennemi.contact_damage.position_en_portee_contact(position)

func _diagonale_accessible(direction: Vector2i) -> bool:
	return not _gestionnaire_grille.cellule_bloquee_ou_scanner(cellule_actuelle + Vector2i(direction.x, 0)) and not _gestionnaire_grille.cellule_bloquee_ou_scanner(cellule_actuelle + Vector2i(0, direction.y))

func _distance_cellules(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func _resoudre_gestionnaires() -> void:
	if not is_inside_tree():
		return
	if _gestionnaire_grille == null or not is_instance_valid(_gestionnaire_grille):
		_gestionnaire_grille = get_tree().get_first_node_in_group("grille_combat") as GestionnaireGrilleCombat
	if _gestionnaire_ennemis == null or not is_instance_valid(_gestionnaire_ennemis):
		_gestionnaire_ennemis = get_tree().get_first_node_in_group("gestion_ennemis") as GestionnaireEnnemis

func _desinscrire() -> void:
	if _gestionnaire_grille != null and _ennemi != null:
		_gestionnaire_grille.liberer_toutes_reservations_ennemi(_ennemi)
	en_deplacement = false
	progression_deplacement = 0.0
	slot_actuel = -1
	slot_cible = -1
	_initialise = false

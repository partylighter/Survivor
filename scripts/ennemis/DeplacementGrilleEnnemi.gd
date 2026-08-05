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
@export_range(0.0, 20.0, 0.5) var distance_snap_resynchronisation_px: float = 5.0
@export_range(0.01, 0.3, 0.01) var duree_retour_grille_min_s: float = 0.05
@export_range(1.0, 2000.0, 1.0) var vitesse_retour_grille_px_s: float = 500.0
@export_range(0.01, 0.5, 0.01) var duree_retour_grille_max_s: float = 0.35

@export_group("Attaque lunge")
@export_range(0.0, 200.0, 1.0) var attaque_lunge_distance_px: float = 80.0
@export_range(0.01, 0.5, 0.01) var attaque_lunge_duree_s: float = 0.10
@export_range(0.01, 0.5, 0.01) var attaque_retour_duree_s: float = 0.12

var cellule_actuelle: Vector2i = Vector2i.ZERO
var cellule_cible: Vector2i = Vector2i.ZERO
var slot_actuel: int = -1
var slot_cible: int = -1
var position_depart: Vector2 = Vector2.ZERO
var position_cible: Vector2 = Vector2.ZERO
var en_deplacement: bool = false
var progression_deplacement: float = 0.0
var duree_deplacement_s: float = 0.0
var en_recul: bool = false
var retour_grille_actif: bool = false

var _gestionnaire_grille: GestionnaireGrilleCombat
var _gestionnaire_ennemis: GestionnaireEnnemis
var _ennemi: Enemy
var _temps_deplacement_s: float = 0.0
var _attente_decision_s: float = 0.0
var _attente_resynchronisation_s: float = 0.0
var _initialise: bool = false
var _attaque_lunge_active: bool = false
var _attaque_retour_active: bool = false
var _temps_attaque_s: float = 0.0
var _attente_attaque_s: float = 0.0
var _position_slot_attaque: Vector2 = Vector2.ZERO
var _position_depart_attaque: Vector2 = Vector2.ZERO
var _position_cible_attaque: Vector2 = Vector2.ZERO

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
	var forces_recul_actives: bool = _forces_recul_actives(ennemi)
	if forces_recul_actives:
		if not en_recul or retour_grille_actif:
			interrompre_pas_pour_recul(ennemi)
		en_recul = true
		_appliquer_translation_recul(ennemi, dt)
		return true
	if en_recul:
		if retour_grille_actif:
			_avancer_retour_grille(ennemi, dt)
			return true
		ennemi.velocity = Vector2.ZERO
		_attente_resynchronisation_s = maxf(0.0, _attente_resynchronisation_s - dt)
		if _attente_resynchronisation_s <= 0.0:
			_essayer_resynchroniser_apres_recul(ennemi)
		return true
	if _attaque_lunge_active or _attaque_retour_active:
		if autoriser_decision:
			_avancer_attaque_lunge(ennemi, dt)
		else:
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
	_attente_attaque_s = maxf(0.0, _attente_attaque_s - dt)
	if not autoriser_decision or _attente_decision_s > 0.0 or cible == null or not is_instance_valid(cible):
		return true
	var cellule_joueur: Vector2i = _gestionnaire_grille.obtenir_cellule_joueur()
	var distance_joueur: int = _distance_cellules(cellule_actuelle, cellule_joueur)
	if distance_joueur == 0:
		_choisir_et_demarrer_pas(ennemi, cellule_joueur, vitesse, 1)
		_attente_decision_s = intervalle_decision_s
		return true
	if distance_joueur <= distance_arret_cellules:
		if _attente_attaque_s > 0.0:
			_attente_decision_s = intervalle_decision_s
			return true
		if _position_permet_lunge(ennemi, cible, ennemi.global_position):
			_demarrer_attaque_lunge(ennemi, cible)
			return true
		if _essayer_rejoindre_slot_attaque(ennemi, cible, vitesse):
			_attente_decision_s = intervalle_decision_s
			return true
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

func est_en_recul() -> bool:
	return en_recul

func interrompre_pas_pour_recul(ennemi: Enemy) -> void:
	if (en_deplacement or retour_grille_actif) and slot_cible >= 0 and _gestionnaire_grille.obtenir_reservataire(cellule_cible, slot_cible) == ennemi:
		_gestionnaire_grille.liberer_slot(cellule_cible, slot_cible, ennemi)
	en_deplacement = false
	retour_grille_actif = false
	progression_deplacement = 0.0
	_temps_deplacement_s = 0.0
	cellule_cible = cellule_actuelle
	slot_cible = -1
	position_depart = ennemi.global_position
	position_cible = ennemi.global_position
	ennemi.velocity = Vector2.ZERO
	_annuler_attaque_lunge()

func _choisir_et_demarrer_pas(ennemi: Enemy, cellule_joueur: Vector2i, vitesse: float, distance_minimale_joueur: int = -1) -> void:
	var candidats: Array[Dictionary] = []
	var directions: Array[Vector2i] = DIRECTIONS_CARDINALES.duplicate()
	if diagonales_autorisees:
		directions.append_array(DIRECTIONS_DIAGONALES)
	var dans_champ: bool = _gestionnaire_grille.champ_contient(cellule_actuelle)
	for direction in directions:
		var cellule: Vector2i = cellule_actuelle + direction
		if cellule == cellule_joueur:
			continue
		if distance_minimale_joueur >= 0 and _distance_cellules(cellule, cellule_joueur) < distance_minimale_joueur:
			continue
		if _gestionnaire_grille.cellule_bloquee_ou_scanner(cellule):
			continue
		if abs(direction.x) == 1 and abs(direction.y) == 1 and not _diagonale_accessible(direction):
			continue
		var slots: Array[int] = []
		for index_slot in _gestionnaire_grille.obtenir_slots_libres(cellule):
			if _slot_respecte_lane(direction, index_slot):
				slots.append(index_slot)
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
			var position_slot_candidat: Vector2 = _gestionnaire_grille.position_slot(cellule, index_slot)
			if _mouvement_est_bloque(ennemi, position_slot_candidat - ennemi.global_position):
				continue
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
	return _trouver_slot_plus_proche(cellule_depart, position_monde, null)

func _trouver_slot_plus_proche(cellule_depart: Vector2i, position_monde: Vector2, ennemi_autorise: Enemy, verifier_trajet: bool = false) -> Dictionary:
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
				for index_slot in range(_gestionnaire_grille.offsets_slots.size()):
					if _gestionnaire_grille.slot_bloque_cache(cellule, index_slot):
						continue
					var occupant: Enemy = _gestionnaire_grille.obtenir_occupant(cellule, index_slot)
					var reservataire: Enemy = _gestionnaire_grille.obtenir_reservataire(cellule, index_slot)
					if occupant != null and occupant != ennemi_autorise:
						continue
					if reservataire != null and reservataire != ennemi_autorise:
						continue
					var position_slot_candidat: Vector2 = _gestionnaire_grille.position_slot(cellule, index_slot)
					if verifier_trajet and ennemi_autorise != null and _mouvement_est_bloque(ennemi_autorise, position_slot_candidat - ennemi_autorise.global_position):
						continue
					var distance: float = position_monde.distance_squared_to(position_slot_candidat)
					if distance < meilleure_distance:
						meilleure_distance = distance
						choix = {"cellule": cellule, "slot": index_slot}
		if not choix.is_empty():
			return choix
	return {}

func _forces_recul_actives(ennemi: Enemy) -> bool:
	var seuil_recul: float = maxf(ennemi.recul_seuil_blocage_px, 1.0)
	var seuil_pousse: float = maxf(ennemi.pousse_seuil_blocage_px, 1.0)
	return ennemi.recul.length_squared() >= seuil_recul * seuil_recul or ennemi.pousse.length_squared() >= seuil_pousse * seuil_pousse

func _appliquer_translation_recul(ennemi: Enemy, dt: float) -> void:
	var mouvement: Vector2 = (ennemi.recul + ennemi.pousse) * dt
	ennemi.velocity = ennemi.recul + ennemi.pousse
	if mouvement.length_squared() <= 0.000001:
		return
	_deplacer_avec_collisions(ennemi, mouvement)

func _deplacer_avec_collisions(ennemi: Enemy, mouvement: Vector2) -> KinematicCollision2D:
	var masque_original: int = ennemi.collision_mask
	var joueur_exception: CollisionObject2D = ennemi.target as CollisionObject2D
	if joueur_exception != null:
		ennemi.add_collision_exception_with(joueur_exception)
	ennemi.collision_mask = _gestionnaire_grille.masque_obstacles
	var collision: KinematicCollision2D = ennemi.move_and_collide(mouvement)
	ennemi.collision_mask = masque_original
	if joueur_exception != null:
		ennemi.remove_collision_exception_with(joueur_exception)
	return collision

func _mouvement_est_bloque(ennemi: Enemy, mouvement: Vector2) -> bool:
	var masque_original: int = ennemi.collision_mask
	var joueur_exception: CollisionObject2D = ennemi.target as CollisionObject2D
	if joueur_exception != null:
		ennemi.add_collision_exception_with(joueur_exception)
	ennemi.collision_mask = _gestionnaire_grille.masque_obstacles
	var bloque: bool = ennemi.test_move(ennemi.global_transform, mouvement)
	ennemi.collision_mask = masque_original
	if joueur_exception != null:
		ennemi.remove_collision_exception_with(joueur_exception)
	return bloque

func _essayer_resynchroniser_apres_recul(ennemi: Enemy) -> void:
	var cellule_estimee: Vector2i = _gestionnaire_grille.monde_vers_cellule(ennemi.global_position)
	var choix: Dictionary = _trouver_slot_plus_proche(cellule_estimee, ennemi.global_position, ennemi, true)
	if choix.is_empty():
		_attente_resynchronisation_s = intervalle_decision_s
		return
	var nouvelle_cellule: Vector2i = choix["cellule"]
	var nouveau_slot: int = int(choix["slot"])
	var meme_slot: bool = nouvelle_cellule == cellule_actuelle and nouveau_slot == slot_actuel
	if not meme_slot and not _gestionnaire_grille.reserver_slot(nouvelle_cellule, nouveau_slot, ennemi):
		_attente_resynchronisation_s = intervalle_decision_s
		return
	cellule_cible = nouvelle_cellule
	slot_cible = nouveau_slot
	position_depart = ennemi.global_position
	position_cible = _gestionnaire_grille.position_slot(cellule_cible, slot_cible)
	var distance: float = position_depart.distance_to(position_cible)
	if distance < distance_snap_resynchronisation_px:
		ennemi.global_position = position_cible
		_terminer_retour_grille(ennemi, meme_slot)
		return
	duree_deplacement_s = clampf(distance / maxf(vitesse_retour_grille_px_s, 1.0), minf(duree_retour_grille_min_s, duree_retour_grille_max_s), maxf(duree_retour_grille_min_s, duree_retour_grille_max_s))
	_temps_deplacement_s = 0.0
	progression_deplacement = 0.0
	retour_grille_actif = true

func _avancer_retour_grille(ennemi: Enemy, dt: float) -> void:
	var ancienne_position: Vector2 = ennemi.global_position
	_temps_deplacement_s = minf(_temps_deplacement_s + dt, duree_deplacement_s)
	progression_deplacement = _temps_deplacement_s / maxf(duree_deplacement_s, 0.001)
	var progression_douce: float = progression_deplacement * progression_deplacement * (3.0 - 2.0 * progression_deplacement)
	var prochaine_position: Vector2 = position_depart.lerp(position_cible, progression_douce)
	var collision: KinematicCollision2D = _deplacer_avec_collisions(ennemi, prochaine_position - ennemi.global_position)
	ennemi.velocity = (ennemi.global_position - ancienne_position) / maxf(dt, 0.0001)
	if collision != null:
		_annuler_retour_apres_collision(ennemi)
		return
	if progression_deplacement >= 1.0:
		_terminer_retour_grille(ennemi, cellule_cible == cellule_actuelle and slot_cible == slot_actuel)

func _annuler_retour_apres_collision(ennemi: Enemy) -> void:
	if slot_cible >= 0 and _gestionnaire_grille.obtenir_reservataire(cellule_cible, slot_cible) == ennemi:
		_gestionnaire_grille.liberer_slot(cellule_cible, slot_cible, ennemi)
	cellule_cible = cellule_actuelle
	slot_cible = -1
	position_depart = ennemi.global_position
	position_cible = ennemi.global_position
	_temps_deplacement_s = 0.0
	progression_deplacement = 0.0
	retour_grille_actif = false
	_attente_resynchronisation_s = intervalle_decision_s

func _terminer_retour_grille(ennemi: Enemy, meme_slot: bool) -> void:
	ennemi.global_position = position_cible
	ennemi.velocity = Vector2.ZERO
	if not meme_slot:
		_gestionnaire_grille.confirmer_occupation(cellule_cible, slot_cible, ennemi)
	cellule_actuelle = cellule_cible
	slot_actuel = slot_cible
	en_deplacement = false
	en_recul = false
	retour_grille_actif = false
	progression_deplacement = 1.0
	_attente_decision_s = intervalle_decision_s
	cellule_ennemi_atteinte.emit(ennemi, cellule_actuelle)

func _essayer_rejoindre_slot_attaque(ennemi: Enemy, cible: Player, vitesse: float) -> bool:
	var slots: Array[int] = _gestionnaire_grille.obtenir_slots_libres(cellule_actuelle)
	slots.sort_custom(func(a: int, b: int) -> bool:
		return ennemi.global_position.distance_squared_to(_gestionnaire_grille.position_slot(cellule_actuelle, a)) < ennemi.global_position.distance_squared_to(_gestionnaire_grille.position_slot(cellule_actuelle, b)))
	for index_slot in slots:
		var position: Vector2 = _gestionnaire_grille.position_slot(cellule_actuelle, index_slot)
		if not _repositionnement_slot_est_cardinal(index_slot):
			continue
		if not _position_permet_lunge(ennemi, cible, position):
			continue
		if _mouvement_est_bloque(ennemi, position - ennemi.global_position):
			continue
		if _gestionnaire_grille.reserver_slot(cellule_actuelle, index_slot, ennemi):
			_demarrer_pas(ennemi, cellule_actuelle, index_slot, vitesse)
			return true
	return false

func _position_permet_lunge(ennemi: Enemy, cible: Player, position: Vector2) -> bool:
	if ennemi.contact_damage == null or cible == null:
		return false
	var direction: Vector2 = cible.global_position - position
	if direction.length_squared() <= 0.0001:
		return true
	var position_fin_lunge: Vector2 = position + direction.normalized() * attaque_lunge_distance_px
	return ennemi.contact_damage.position_en_portee_contact(position_fin_lunge)

func _repositionnement_slot_est_cardinal(index_slot_cible: int) -> bool:
	if slot_actuel < 0 or slot_actuel >= _gestionnaire_grille.offsets_slots.size():
		return false
	if index_slot_cible < 0 or index_slot_cible >= _gestionnaire_grille.offsets_slots.size():
		return false
	var difference: Vector2 = _gestionnaire_grille.offsets_slots[index_slot_cible] - _gestionnaire_grille.offsets_slots[slot_actuel]
	return is_zero_approx(difference.x) or is_zero_approx(difference.y)

func _demarrer_attaque_lunge(ennemi: Enemy, cible: Player) -> void:
	var direction: Vector2 = cible.global_position - ennemi.global_position
	if direction.length_squared() <= 0.0001:
		return
	_position_slot_attaque = _gestionnaire_grille.position_slot(cellule_actuelle, slot_actuel)
	_position_depart_attaque = ennemi.global_position
	_position_cible_attaque = ennemi.global_position + direction.normalized() * attaque_lunge_distance_px
	if _mouvement_est_bloque(ennemi, _position_cible_attaque - ennemi.global_position):
		_attente_attaque_s = intervalle_decision_s
		return
	_temps_attaque_s = 0.0
	_attaque_lunge_active = true
	_attaque_retour_active = false

func _avancer_attaque_lunge(ennemi: Enemy, dt: float) -> void:
	var duree_phase: float = attaque_retour_duree_s if _attaque_retour_active else attaque_lunge_duree_s
	var ancienne_position: Vector2 = ennemi.global_position
	_temps_attaque_s = minf(_temps_attaque_s + dt, maxf(duree_phase, 0.001))
	var progression: float = _temps_attaque_s / maxf(duree_phase, 0.001)
	var progression_douce: float = progression * progression * (3.0 - 2.0 * progression)
	var prochaine_position: Vector2 = _position_depart_attaque.lerp(_position_cible_attaque, progression_douce)
	var collision: KinematicCollision2D = _deplacer_avec_collisions(ennemi, prochaine_position - ennemi.global_position)
	ennemi.velocity = (ennemi.global_position - ancienne_position) / maxf(dt, 0.0001)
	if collision != null:
		if _attaque_lunge_active:
			_demarrer_retour_attaque(ennemi)
		else:
			_annuler_attaque_lunge()
			en_recul = true
			_attente_resynchronisation_s = 0.0
		return
	if progression < 1.0:
		return
	if _attaque_lunge_active:
		ennemi.contact_damage.essayer_contact_immediat()
		_demarrer_retour_attaque(ennemi)
		return
	ennemi.global_position = _position_slot_attaque
	ennemi.velocity = Vector2.ZERO
	_annuler_attaque_lunge()
	_attente_attaque_s = maxf(ennemi.contact_damage.delai_entre_hits_s, intervalle_decision_s)
	_attente_decision_s = intervalle_decision_s

func _demarrer_retour_attaque(ennemi: Enemy) -> void:
	_attaque_lunge_active = false
	_attaque_retour_active = true
	_temps_attaque_s = 0.0
	_position_depart_attaque = ennemi.global_position
	_position_cible_attaque = _position_slot_attaque

func _annuler_attaque_lunge() -> void:
	_attaque_lunge_active = false
	_attaque_retour_active = false
	_temps_attaque_s = 0.0
	_position_slot_attaque = Vector2.ZERO
	_position_depart_attaque = Vector2.ZERO
	_position_cible_attaque = Vector2.ZERO

func _slot_respecte_lane(direction: Vector2i, index_slot_cible: int) -> bool:
	if diagonales_autorisees or slot_actuel < 0 or slot_actuel >= _gestionnaire_grille.offsets_slots.size():
		return true
	if index_slot_cible < 0 or index_slot_cible >= _gestionnaire_grille.offsets_slots.size():
		return false
	if direction == Vector2i.ZERO or abs(direction.x) == 1 and abs(direction.y) == 1:
		return true
	var offset_actuel: Vector2 = _gestionnaire_grille.offsets_slots[slot_actuel]
	var offset_cible: Vector2 = _gestionnaire_grille.offsets_slots[index_slot_cible]
	if direction.x != 0:
		return is_equal_approx(offset_actuel.y, offset_cible.y)
	if direction.y != 0:
		return is_equal_approx(offset_actuel.x, offset_cible.x)
	return true

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
	en_recul = false
	retour_grille_actif = false
	progression_deplacement = 0.0
	_attente_resynchronisation_s = 0.0
	_attente_attaque_s = 0.0
	slot_actuel = -1
	slot_cible = -1
	_initialise = false
	_annuler_attaque_lunge()

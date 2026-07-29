extends Node
class_name GestionnaireMartelage

signal martelage_actualise
signal point_evalue(evaluation: StringName)
signal martelage_termine(resultat: StringName)

const EVALUATION_RATE: StringName = &"rate"
const EVALUATION_CORRECT: StringName = &"correct"
const EVALUATION_PARFAIT: StringName = &"parfait"
const RESULTAT_ECHEC: StringName = &"echec"
const RESULTAT_CORRECT: StringName = &"correct"
const RESULTAT_PARFAIT: StringName = &"parfait"

@export_group("Facile")
@export var nombre_points_facile: int = 5
@export var delai_apparition_minimum_facile: float = 0.72
@export var delai_apparition_maximum_facile: float = 1.0
@export var duree_vie_minimum_facile: float = 1.45
@export var duree_vie_maximum_facile: float = 1.8
@export var rayon_exterieur_minimum_facile: float = 0.075
@export var rayon_exterieur_maximum_facile: float = 0.095
@export var ratio_rayon_correct_facile: float = 0.76
@export var ratio_rayon_parfait_facile: float = 0.44
@export var nombre_points_simultanes_facile: int = 1
@export_range(0.0, 1.0) var chance_points_simultanes_facile: float = 0.0
@export_range(0.0, 1.0) var chance_sequence_ordonnee_facile: float = 0.0
@export_range(0.0, 1.0) var chance_frappes_multiples_facile: float = 0.12
@export var nombre_frappes_maximum_facile: int = 2
@export var delai_frappe_minimum_facile: float = 0.16
@export var delai_frappe_maximum_facile: float = 0.24
@export var amplitude_position_facile: float = 0.34

@export_group("Normale")
@export var nombre_points_normal: int = 7
@export var delai_apparition_minimum_normal: float = 0.48
@export var delai_apparition_maximum_normal: float = 0.72
@export var duree_vie_minimum_normale: float = 1.05
@export var duree_vie_maximum_normale: float = 1.4
@export var rayon_exterieur_minimum_normal: float = 0.06
@export var rayon_exterieur_maximum_normal: float = 0.08
@export var ratio_rayon_correct_normal: float = 0.7
@export var ratio_rayon_parfait_normal: float = 0.36
@export var nombre_points_simultanes_normal: int = 2
@export_range(0.0, 1.0) var chance_points_simultanes_normal: float = 0.35
@export_range(0.0, 1.0) var chance_sequence_ordonnee_normale: float = 0.55
@export_range(0.0, 1.0) var chance_frappes_multiples_normale: float = 0.28
@export var nombre_frappes_maximum_normal: int = 3
@export var delai_frappe_minimum_normal: float = 0.11
@export var delai_frappe_maximum_normal: float = 0.19
@export var amplitude_position_normale: float = 0.4

@export_group("Difficile")
@export var nombre_points_difficile: int = 9
@export var delai_apparition_minimum_difficile: float = 0.32
@export var delai_apparition_maximum_difficile: float = 0.54
@export var duree_vie_minimum_difficile: float = 0.78
@export var duree_vie_maximum_difficile: float = 1.08
@export var rayon_exterieur_minimum_difficile: float = 0.047
@export var rayon_exterieur_maximum_difficile: float = 0.065
@export var ratio_rayon_correct_difficile: float = 0.64
@export var ratio_rayon_parfait_difficile: float = 0.3
@export var nombre_points_simultanes_difficile: int = 3
@export_range(0.0, 1.0) var chance_points_simultanes_difficile: float = 0.58
@export_range(0.0, 1.0) var chance_sequence_ordonnee_difficile: float = 0.72
@export_range(0.0, 1.0) var chance_frappes_multiples_difficile: float = 0.42
@export var nombre_frappes_maximum_difficile: int = 3
@export var delai_frappe_minimum_difficile: float = 0.08
@export var delai_frappe_maximum_difficile: float = 0.14
@export var amplitude_position_difficile: float = 0.44

@export_group("Evaluation")
@export var moment_parfait: float = 0.72
@export var tolerance_moment_parfait: float = 0.11
@export var valeur_coup_parfait: float = 1.0
@export var valeur_coup_correct: float = 0.7
@export var penalite_clic_inutile: float = 0.04
@export var penalite_mauvais_ordre: float = 0.06
@export var seuil_qualite_correcte: float = 0.5
@export var seuil_qualite_parfaite: float = 0.9
@export var distance_minimum_entre_points: float = 0.025
@export var nombre_tentatives_position: int = 20
@export var bonus_duree_par_point_simultane: float = 0.18
@export var bonus_duree_par_frappe_supplementaire: float = 0.12
@export var bonus_duree_apres_frappe_multiple: float = 0.08
@export var duree_grace_point: float = 0.1
@export var multiplicateur_marge_detection_exterieure: float = 1.08
@export var fenetre_clic_anticipe: float = 0.1
@export var nombre_clics_rapides_toleres: int = 1
@export var delai_reinitialisation_spam: float = 0.35
@export var reduction_delai_par_point_simultane: float = 0.12
@export var reduction_delai_par_frappe_supplementaire: float = 0.08
@export var multiplicateur_delai_minimum: float = 0.55

var points_actifs: Array[Dictionary] = []
var nombre_points_actuel: int = 0
var intervalle_actuel: float = 0.0
var duree_point_actuelle: float = 0.0
var rayon_point_actuel: float = 0.0
var amplitude_position_actuelle: float = 0.0
var nombre_points_apparus: int = 0
var nombre_points_evalues: int = 0
var nombre_frappes_attendues: int = 0
var nombre_frappes_evaluees: int = 0
var nombre_parfaits: int = 0
var nombre_corrects: int = 0
var nombre_rates: int = 0
var penalites_clics_rates: int = 0
var score_coups: float = 0.0
var temps_avant_prochain_point: float = 0.0
var temps_avant_nouvelle_frappe: float = 0.0
var clic_anticipe_en_attente: bool = false
var position_clic_anticipe: Vector2 = Vector2.ZERO
var taille_zone_clic_anticipe: Vector2 = Vector2.ONE
var nombre_clics_trop_rapides: int = 0
var temps_depuis_clic_trop_rapide: float = 0.0
var actif: bool = false
var generateur := RandomNumberGenerator.new()
var prochain_identifiant_point: int = 0
var prochain_identifiant_groupe: int = 0
var delai_apparition_minimum_actuel: float = 0.0
var delai_apparition_maximum_actuel: float = 0.0
var duree_vie_minimum_actuelle: float = 0.0
var duree_vie_maximum_actuelle: float = 0.0
var rayon_exterieur_minimum_actuel: float = 0.0
var rayon_exterieur_maximum_actuel: float = 0.0
var ratio_rayon_correct_actuel: float = 0.0
var ratio_rayon_parfait_actuel: float = 0.0
var nombre_points_simultanes_actuel: int = 1
var chance_points_simultanes_actuelle: float = 0.0
var chance_sequence_ordonnee_actuelle: float = 0.0
var chance_frappes_multiples_actuelle: float = 0.0
var nombre_frappes_maximum_actuel: int = 1
var delai_frappe_minimum_actuel: float = 0.0
var delai_frappe_maximum_actuel: float = 0.0
var toutes_frappes_parfaites: bool = true

func demarrer(difficulte: DonneesCommandeForge.Difficulte) -> bool:
	generateur.randomize()
	_configurer_difficulte(difficulte)
	if nombre_points_actuel <= 0 or duree_vie_minimum_actuelle <= 0.0 or rayon_exterieur_minimum_actuel <= 0.0:
		return false
	points_actifs.clear()
	nombre_points_apparus = 0
	nombre_points_evalues = 0
	nombre_frappes_attendues = 0
	nombre_frappes_evaluees = 0
	nombre_parfaits = 0
	nombre_corrects = 0
	nombre_rates = 0
	penalites_clics_rates = 0
	score_coups = 0.0
	temps_avant_prochain_point = 0.0
	temps_avant_nouvelle_frappe = 0.0
	clic_anticipe_en_attente = false
	position_clic_anticipe = Vector2.ZERO
	taille_zone_clic_anticipe = Vector2.ONE
	nombre_clics_trop_rapides = 0
	temps_depuis_clic_trop_rapide = 0.0
	prochain_identifiant_point = 0
	prochain_identifiant_groupe = 0
	toutes_frappes_parfaites = true
	actif = true
	_faire_apparaitre_groupe()
	_planifier_prochaine_apparition()
	martelage_actualise.emit()
	return true

func mettre_a_jour(delta: float) -> void:
	if not actif or delta <= 0.0:
		return
	var delai_frappe_avant: float = temps_avant_nouvelle_frappe
	temps_avant_nouvelle_frappe = maxf(0.0, temps_avant_nouvelle_frappe - delta)
	temps_depuis_clic_trop_rapide += delta
	if temps_depuis_clic_trop_rapide >= delai_reinitialisation_spam:
		nombre_clics_trop_rapides = 0
	if delai_frappe_avant > 0.0 and temps_avant_nouvelle_frappe <= 0.0 and clic_anticipe_en_attente:
		var position_memorisee: Vector2 = position_clic_anticipe
		var taille_memorisee: Vector2 = taille_zone_clic_anticipe
		clic_anticipe_en_attente = false
		_traiter_clic(position_memorisee, taille_memorisee, true)
	for index: int in range(points_actifs.size() - 1, -1, -1):
		var point: Dictionary = points_actifs[index]
		if not point_est_cliquable(point):
			continue
		point["age"] = float(point.get("age", 0.0)) + delta
		if float(point["age"]) >= float(point.get("duree", 1.0)) + duree_grace_point:
			points_actifs.remove_at(index)
			var frappes_restantes: int = int(point.get("frappes_restantes", 1))
			for frappe: int in frappes_restantes:
				_enregistrer_evaluation(EVALUATION_RATE)
			nombre_points_evalues += 1
		else:
			points_actifs[index] = point
	if nombre_points_apparus < nombre_points_actuel:
		if not _sequence_ordonnee_active():
			temps_avant_prochain_point -= delta
			if temps_avant_prochain_point <= 0.0:
				_faire_apparaitre_groupe()
				_planifier_prochaine_apparition()
	_verifier_fin()
	martelage_actualise.emit()

func enregistrer_clic(position_normalisee: Vector2, taille_zone: Vector2 = Vector2.ONE) -> void:
	if not actif:
		return
	if temps_avant_nouvelle_frappe > 0.0:
		if temps_avant_nouvelle_frappe <= fenetre_clic_anticipe and not clic_anticipe_en_attente:
			clic_anticipe_en_attente = true
			position_clic_anticipe = position_normalisee
			taille_zone_clic_anticipe = taille_zone
			martelage_actualise.emit()
			return
		nombre_clics_trop_rapides += 1
		temps_depuis_clic_trop_rapide = 0.0
		if nombre_clics_trop_rapides > nombre_clics_rapides_toleres:
			_enregistrer_penalite(false)
		return
	_traiter_clic(position_normalisee, taille_zone, false)

func _traiter_clic(position_normalisee: Vector2, taille_zone: Vector2, clic_memorise: bool) -> void:
	var index_touche: int = _trouver_point_touche(position_normalisee, taille_zone)
	if index_touche < 0:
		if not clic_memorise:
			_enregistrer_penalite(false)
		return
	var point: Dictionary = points_actifs[index_touche]
	if not point_est_cliquable(point):
		_enregistrer_penalite(true)
		return
	var distance_normalisee: float = _calculer_distance_normalisee(position_normalisee, point.get("position", Vector2.ZERO) as Vector2, taille_zone)
	var rayon_exterieur: float = float(point.get("rayon_exterieur", 0.06))
	var proportion_temps: float = float(point.get("age", 0.0)) / maxf(float(point.get("duree", 1.0)), 0.001)
	var position_parfaite: bool = distance_normalisee <= rayon_exterieur * float(point.get("ratio_parfait", 0.35))
	var position_correcte: bool = distance_normalisee <= rayon_exterieur * float(point.get("ratio_correct", 0.7))
	var moment_est_parfait: bool = absf(proportion_temps - moment_parfait) <= tolerance_moment_parfait
	var point_en_grace: bool = float(point.get("age", 0.0)) >= float(point.get("duree", 1.0))
	var evaluation: StringName = EVALUATION_RATE
	if position_parfaite and moment_est_parfait and not point_en_grace:
		evaluation = EVALUATION_PARFAIT
	elif position_correcte:
		evaluation = EVALUATION_CORRECT
	_enregistrer_evaluation(evaluation)
	point["frappes_restantes"] = int(point.get("frappes_restantes", 1)) - 1
	if int(point["frappes_restantes"]) <= 0:
		points_actifs.remove_at(index_touche)
		nombre_points_evalues += 1
	else:
		point["age"] = 0.0
		point["duree"] = float(point.get("duree", 1.0)) + bonus_duree_apres_frappe_multiple
		points_actifs[index_touche] = point
	var multiplicateur_delai: float = _calculer_multiplicateur_delai(point)
	temps_avant_nouvelle_frappe = generateur.randf_range(delai_frappe_minimum_actuel, delai_frappe_maximum_actuel) * multiplicateur_delai
	nombre_clics_trop_rapides = 0
	temps_depuis_clic_trop_rapide = 0.0
	_verifier_fin()
	martelage_actualise.emit()

func point_est_cliquable(point: Dictionary) -> bool:
	var ordre: int = int(point.get("ordre", 0))
	if ordre <= 1:
		return true
	var identifiant_groupe: int = int(point.get("groupe", -1))
	for autre_point: Dictionary in points_actifs:
		if int(autre_point.get("groupe", -2)) == identifiant_groupe and int(autre_point.get("ordre", 0)) > 0 and int(autre_point.get("ordre", 0)) < ordre:
			return false
	return true

func obtenir_score_actuel() -> float:
	if nombre_frappes_attendues <= 0:
		return 0.0
	var score: float = score_coups / float(nombre_frappes_attendues)
	score -= float(penalites_clics_rates) * penalite_clic_inutile
	return clampf(score, 0.0, 1.0)

func obtenir_progression_frappe() -> float:
	if delai_frappe_maximum_actuel <= 0.0:
		return 1.0
	return 1.0 - clampf(temps_avant_nouvelle_frappe / delai_frappe_maximum_actuel, 0.0, 1.0)

func _trouver_point_touche(position_normalisee: Vector2, taille_zone: Vector2) -> int:
	var index_touche: int = -1
	var distance_plus_proche: float = INF
	for index: int in points_actifs.size():
		var point: Dictionary = points_actifs[index]
		var distance: float = _calculer_distance_normalisee(position_normalisee, point.get("position", Vector2.ZERO) as Vector2, taille_zone)
		if distance <= float(point.get("rayon_exterieur", 0.06)) * multiplicateur_marge_detection_exterieure and distance < distance_plus_proche:
			index_touche = index
			distance_plus_proche = distance
	return index_touche

func _sequence_ordonnee_active() -> bool:
	for point: Dictionary in points_actifs:
		if int(point.get("ordre", 0)) > 0:
			return true
	return false

func _calculer_multiplicateur_delai(point: Dictionary) -> float:
	var autres_points: int = maxi(points_actifs.size() - 1, 0)
	var frappes_supplementaires: int = maxi(int(point.get("frappes_initiales", 1)) - 1, 0)
	var multiplicateur: float = 1.0
	multiplicateur -= float(autres_points) * reduction_delai_par_point_simultane
	multiplicateur -= float(frappes_supplementaires) * reduction_delai_par_frappe_supplementaire
	return maxf(multiplicateur, multiplicateur_delai_minimum)

func _calculer_distance_normalisee(position_a: Vector2, position_b: Vector2, taille_zone: Vector2) -> float:
	var dimension: float = maxf(minf(taille_zone.x, taille_zone.y), 0.001)
	return ((position_a - position_b) * taille_zone).length() / dimension

func _faire_apparaitre_groupe() -> void:
	var places_disponibles: int = maxi(nombre_points_simultanes_actuel - points_actifs.size(), 0)
	var points_restants: int = nombre_points_actuel - nombre_points_apparus
	if places_disponibles <= 0 or points_restants <= 0:
		return
	var nombre_groupe: int = 1
	if places_disponibles > 1 and generateur.randf() <= chance_points_simultanes_actuelle:
		nombre_groupe = generateur.randi_range(2, mini(places_disponibles, points_restants))
	nombre_groupe = mini(nombre_groupe, points_restants)
	var groupe_ordonne: bool = nombre_groupe > 1 and generateur.randf() <= chance_sequence_ordonnee_actuelle
	var identifiant_groupe: int = prochain_identifiant_groupe
	prochain_identifiant_groupe += 1
	for index: int in nombre_groupe:
		_creer_point(identifiant_groupe, index + 1 if groupe_ordonne else 0, nombre_groupe)

func _creer_point(identifiant_groupe: int, ordre: int, nombre_points_groupe: int) -> void:
	var rayon_exterieur: float = generateur.randf_range(rayon_exterieur_minimum_actuel, rayon_exterieur_maximum_actuel)
	var duree: float = generateur.randf_range(duree_vie_minimum_actuelle, duree_vie_maximum_actuelle)
	var frappes: int = 1
	if nombre_frappes_maximum_actuel > 1 and generateur.randf() <= chance_frappes_multiples_actuelle:
		frappes = generateur.randi_range(2, nombre_frappes_maximum_actuel)
	duree += float(maxi(nombre_points_groupe - 1, 0)) * bonus_duree_par_point_simultane
	duree += float(maxi(frappes - 1, 0)) * bonus_duree_par_frappe_supplementaire
	var point: Dictionary = {
		"identifiant": prochain_identifiant_point,
		"groupe": identifiant_groupe,
		"ordre": ordre,
		"position": _generer_position(rayon_exterieur),
		"age": 0.0,
		"duree": duree,
		"rayon_exterieur": rayon_exterieur,
		"ratio_correct": ratio_rayon_correct_actuel,
		"ratio_parfait": ratio_rayon_parfait_actuel,
		"moment_parfait": moment_parfait,
		"duree_grace": duree_grace_point,
		"frappes_initiales": frappes,
		"frappes_restantes": frappes
	}
	points_actifs.append(point)
	prochain_identifiant_point += 1
	nombre_points_apparus += 1
	nombre_frappes_attendues += frappes
	duree_point_actuelle = duree
	rayon_point_actuel = rayon_exterieur

func _generer_position(rayon: float) -> Vector2:
	var minimum: float = maxf(0.5 - amplitude_position_actuelle, rayon)
	var maximum: float = minf(0.5 + amplitude_position_actuelle, 1.0 - rayon)
	var position_candidate := Vector2(0.5, 0.5)
	for tentative: int in maxi(nombre_tentatives_position, 1):
		position_candidate = Vector2(generateur.randf_range(minimum, maximum), generateur.randf_range(minimum, maximum))
		var position_valide: bool = true
		for point: Dictionary in points_actifs:
			var distance_requise: float = rayon + float(point.get("rayon_exterieur", 0.06)) + distance_minimum_entre_points
			if position_candidate.distance_to(point.get("position", Vector2.ZERO) as Vector2) < distance_requise:
				position_valide = false
				break
		if position_valide:
			return position_candidate
	return position_candidate

func _planifier_prochaine_apparition() -> void:
	intervalle_actuel = generateur.randf_range(delai_apparition_minimum_actuel, delai_apparition_maximum_actuel)
	temps_avant_prochain_point = intervalle_actuel

func _enregistrer_evaluation(evaluation: StringName) -> void:
	nombre_frappes_evaluees += 1
	match evaluation:
		EVALUATION_PARFAIT:
			nombre_parfaits += 1
			score_coups += valeur_coup_parfait
		EVALUATION_CORRECT:
			nombre_corrects += 1
			score_coups += valeur_coup_correct
			toutes_frappes_parfaites = false
		_:
			nombre_rates += 1
			toutes_frappes_parfaites = false
	point_evalue.emit(evaluation)

func _enregistrer_penalite(mauvais_ordre: bool) -> void:
	penalites_clics_rates += 1
	toutes_frappes_parfaites = false
	if mauvais_ordre and penalite_clic_inutile > 0.0:
		score_coups -= maxf(penalite_mauvais_ordre - penalite_clic_inutile, 0.0) * float(maxi(nombre_frappes_attendues, 1))
	point_evalue.emit(EVALUATION_RATE)
	martelage_actualise.emit()

func _verifier_fin() -> void:
	if not actif or nombre_points_apparus < nombre_points_actuel or not points_actifs.is_empty():
		return
	var score: float = obtenir_score_actuel()
	if toutes_frappes_parfaites and score >= seuil_qualite_parfaite:
		_terminer(RESULTAT_PARFAIT)
	elif score >= seuil_qualite_correcte:
		_terminer(RESULTAT_CORRECT)
	else:
		_terminer(RESULTAT_ECHEC)

func _terminer(resultat: StringName) -> void:
	actif = false
	martelage_termine.emit(resultat)

func _configurer_difficulte(difficulte: DonneesCommandeForge.Difficulte) -> void:
	match difficulte:
		DonneesCommandeForge.Difficulte.NORMALE:
			nombre_points_actuel = nombre_points_normal
			delai_apparition_minimum_actuel = delai_apparition_minimum_normal
			delai_apparition_maximum_actuel = delai_apparition_maximum_normal
			duree_vie_minimum_actuelle = duree_vie_minimum_normale
			duree_vie_maximum_actuelle = duree_vie_maximum_normale
			rayon_exterieur_minimum_actuel = rayon_exterieur_minimum_normal
			rayon_exterieur_maximum_actuel = rayon_exterieur_maximum_normal
			ratio_rayon_correct_actuel = ratio_rayon_correct_normal
			ratio_rayon_parfait_actuel = ratio_rayon_parfait_normal
			nombre_points_simultanes_actuel = nombre_points_simultanes_normal
			chance_points_simultanes_actuelle = chance_points_simultanes_normal
			chance_sequence_ordonnee_actuelle = chance_sequence_ordonnee_normale
			chance_frappes_multiples_actuelle = chance_frappes_multiples_normale
			nombre_frappes_maximum_actuel = nombre_frappes_maximum_normal
			delai_frappe_minimum_actuel = delai_frappe_minimum_normal
			delai_frappe_maximum_actuel = delai_frappe_maximum_normal
			amplitude_position_actuelle = amplitude_position_normale
		DonneesCommandeForge.Difficulte.DIFFICILE:
			nombre_points_actuel = nombre_points_difficile
			delai_apparition_minimum_actuel = delai_apparition_minimum_difficile
			delai_apparition_maximum_actuel = delai_apparition_maximum_difficile
			duree_vie_minimum_actuelle = duree_vie_minimum_difficile
			duree_vie_maximum_actuelle = duree_vie_maximum_difficile
			rayon_exterieur_minimum_actuel = rayon_exterieur_minimum_difficile
			rayon_exterieur_maximum_actuel = rayon_exterieur_maximum_difficile
			ratio_rayon_correct_actuel = ratio_rayon_correct_difficile
			ratio_rayon_parfait_actuel = ratio_rayon_parfait_difficile
			nombre_points_simultanes_actuel = nombre_points_simultanes_difficile
			chance_points_simultanes_actuelle = chance_points_simultanes_difficile
			chance_sequence_ordonnee_actuelle = chance_sequence_ordonnee_difficile
			chance_frappes_multiples_actuelle = chance_frappes_multiples_difficile
			nombre_frappes_maximum_actuel = nombre_frappes_maximum_difficile
			delai_frappe_minimum_actuel = delai_frappe_minimum_difficile
			delai_frappe_maximum_actuel = delai_frappe_maximum_difficile
			amplitude_position_actuelle = amplitude_position_difficile
		_:
			nombre_points_actuel = nombre_points_facile
			delai_apparition_minimum_actuel = delai_apparition_minimum_facile
			delai_apparition_maximum_actuel = delai_apparition_maximum_facile
			duree_vie_minimum_actuelle = duree_vie_minimum_facile
			duree_vie_maximum_actuelle = duree_vie_maximum_facile
			rayon_exterieur_minimum_actuel = rayon_exterieur_minimum_facile
			rayon_exterieur_maximum_actuel = rayon_exterieur_maximum_facile
			ratio_rayon_correct_actuel = ratio_rayon_correct_facile
			ratio_rayon_parfait_actuel = ratio_rayon_parfait_facile
			nombre_points_simultanes_actuel = nombre_points_simultanes_facile
			chance_points_simultanes_actuelle = chance_points_simultanes_facile
			chance_sequence_ordonnee_actuelle = chance_sequence_ordonnee_facile
			chance_frappes_multiples_actuelle = chance_frappes_multiples_facile
			nombre_frappes_maximum_actuel = nombre_frappes_maximum_facile
			delai_frappe_minimum_actuel = delai_frappe_minimum_facile
			delai_frappe_maximum_actuel = delai_frappe_maximum_facile
			amplitude_position_actuelle = amplitude_position_facile
	nombre_points_simultanes_actuel = maxi(nombre_points_simultanes_actuel, 1)
	nombre_frappes_maximum_actuel = maxi(nombre_frappes_maximum_actuel, 1)
	delai_apparition_maximum_actuel = maxf(delai_apparition_maximum_actuel, delai_apparition_minimum_actuel)
	duree_vie_maximum_actuelle = maxf(duree_vie_maximum_actuelle, duree_vie_minimum_actuelle)
	rayon_exterieur_maximum_actuel = maxf(rayon_exterieur_maximum_actuel, rayon_exterieur_minimum_actuel)
	ratio_rayon_correct_actuel = clampf(ratio_rayon_correct_actuel, 0.05, 1.0)
	ratio_rayon_parfait_actuel = clampf(ratio_rayon_parfait_actuel, 0.02, ratio_rayon_correct_actuel)
	delai_frappe_maximum_actuel = maxf(delai_frappe_maximum_actuel, delai_frappe_minimum_actuel)

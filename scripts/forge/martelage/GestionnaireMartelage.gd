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

@export var nombre_points_facile: int = 5
@export var nombre_points_normal: int = 7
@export var nombre_points_difficile: int = 9
@export var intervalle_facile: float = 0.75
@export var intervalle_normal: float = 0.58
@export var intervalle_difficile: float = 0.42
@export var duree_point_facile: float = 1.35
@export var duree_point_normale: float = 1.0
@export var duree_point_difficile: float = 0.72
@export var rayon_point_facile: float = 0.075
@export var rayon_point_normal: float = 0.06
@export var rayon_point_difficile: float = 0.045
@export var amplitude_position_facile: float = 0.25
@export var amplitude_position_normale: float = 0.36
@export var amplitude_position_difficile: float = 0.44
@export var alea_intervalle_facile: float = 0.12
@export var alea_intervalle_normal: float = 0.1
@export var alea_intervalle_difficile: float = 0.08
@export var alea_duree_point_facile: float = 0.18
@export var alea_duree_point_normale: float = 0.14
@export var alea_duree_point_difficile: float = 0.1
@export var moment_parfait: float = 0.74
@export var tolerance_moment_parfait: float = 0.14

var points_actifs: Array[Dictionary] = []
var nombre_points_actuel: int = 0
var intervalle_actuel: float = 0.0
var duree_point_actuelle: float = 0.0
var rayon_point_actuel: float = 0.0
var amplitude_position_actuelle: float = 0.0
var nombre_points_apparus: int = 0
var nombre_points_evalues: int = 0
var nombre_parfaits: int = 0
var nombre_corrects: int = 0
var nombre_rates: int = 0
var penalites_clics_rates: int = 0
var temps_avant_prochain_point: float = 0.0
var actif: bool = false
var generateur := RandomNumberGenerator.new()

func demarrer(difficulte: DonneesCommandeForge.Difficulte) -> bool:
	generateur.randomize()
	_configurer_difficulte(difficulte)
	if nombre_points_actuel <= 0 or duree_point_actuelle <= 0.0:
		return false
	points_actifs.clear()
	nombre_points_apparus = 0
	nombre_points_evalues = 0
	nombre_parfaits = 0
	nombre_corrects = 0
	nombre_rates = 0
	penalites_clics_rates = 0
	temps_avant_prochain_point = intervalle_actuel
	actif = true
	_faire_apparaitre_point()
	martelage_actualise.emit()
	return true

func mettre_a_jour(delta: float) -> void:
	if not actif or delta <= 0.0:
		return
	for index: int in range(points_actifs.size() - 1, -1, -1):
		var point: Dictionary = points_actifs[index]
		point["age"] = float(point["age"]) + delta
		if float(point["age"]) >= duree_point_actuelle:
			points_actifs.remove_at(index)
			_enregistrer_evaluation(EVALUATION_RATE)
		else:
			points_actifs[index] = point
	if nombre_points_apparus < nombre_points_actuel:
		temps_avant_prochain_point -= delta
		while temps_avant_prochain_point <= 0.0 and nombre_points_apparus < nombre_points_actuel:
			_faire_apparaitre_point()
			temps_avant_prochain_point += intervalle_actuel
	_verifier_fin()
	martelage_actualise.emit()

func enregistrer_clic(position_normalisee: Vector2) -> void:
	if not actif:
		return
	var index_touche: int = -1
	var distance_plus_proche: float = INF
	for index: int in points_actifs.size():
		var position_point: Vector2 = points_actifs[index]["position"] as Vector2
		var distance: float = position_normalisee.distance_to(position_point)
		if distance <= rayon_point_actuel and distance < distance_plus_proche:
			index_touche = index
			distance_plus_proche = distance
	if index_touche < 0:
		penalites_clics_rates += 1
		point_evalue.emit(EVALUATION_RATE)
		martelage_actualise.emit()
		return
	var point: Dictionary = points_actifs[index_touche]
	points_actifs.remove_at(index_touche)
	var proportion_temps: float = float(point["age"]) / maxf(duree_point_actuelle, 0.001)
	var position_parfaite: bool = distance_plus_proche <= rayon_point_actuel * 0.45
	var moment_est_parfait: bool = absf(proportion_temps - moment_parfait) <= tolerance_moment_parfait
	_enregistrer_evaluation(EVALUATION_PARFAIT if position_parfaite and moment_est_parfait else EVALUATION_CORRECT)
	_verifier_fin()
	martelage_actualise.emit()

func _faire_apparaitre_point() -> void:
	var minimum: float = 0.5 - amplitude_position_actuelle
	var maximum: float = 0.5 + amplitude_position_actuelle
	points_actifs.append({
		"position": Vector2(generateur.randf_range(minimum, maximum), generateur.randf_range(minimum, maximum)),
		"age": 0.0
	})
	nombre_points_apparus += 1

func _enregistrer_evaluation(evaluation: StringName) -> void:
	nombre_points_evalues += 1
	match evaluation:
		EVALUATION_PARFAIT:
			nombre_parfaits += 1
		EVALUATION_CORRECT:
			nombre_corrects += 1
		_:
			nombre_rates += 1
	point_evalue.emit(evaluation)

func _verifier_fin() -> void:
	if not actif or nombre_points_evalues < nombre_points_actuel or not points_actifs.is_empty():
		return
	var score: float = (float(nombre_parfaits) + float(nombre_corrects) * 0.6) / float(nombre_points_actuel)
	score -= float(penalites_clics_rates) * 0.12
	if score >= 0.85:
		_terminer(RESULTAT_PARFAIT)
	elif score >= 0.5:
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
			intervalle_actuel = intervalle_normal
			duree_point_actuelle = duree_point_normale
			_appliquer_alea(alea_intervalle_normal, alea_duree_point_normale)
			rayon_point_actuel = rayon_point_normal
			amplitude_position_actuelle = amplitude_position_normale
		DonneesCommandeForge.Difficulte.DIFFICILE:
			nombre_points_actuel = nombre_points_difficile
			intervalle_actuel = intervalle_difficile
			duree_point_actuelle = duree_point_difficile
			_appliquer_alea(alea_intervalle_difficile, alea_duree_point_difficile)
			rayon_point_actuel = rayon_point_difficile
			amplitude_position_actuelle = amplitude_position_difficile
		_:
			nombre_points_actuel = nombre_points_facile
			intervalle_actuel = intervalle_facile
			duree_point_actuelle = duree_point_facile
			_appliquer_alea(alea_intervalle_facile, alea_duree_point_facile)
			rayon_point_actuel = rayon_point_facile
			amplitude_position_actuelle = amplitude_position_facile

func _appliquer_alea(alea_intervalle: float, alea_duree: float) -> void:
	intervalle_actuel = maxf(0.05, intervalle_actuel + generateur.randf_range(-alea_intervalle, alea_intervalle))
	duree_point_actuelle = maxf(0.1, duree_point_actuelle + generateur.randf_range(-alea_duree, alea_duree))

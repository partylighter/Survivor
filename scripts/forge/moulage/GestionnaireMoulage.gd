extends Node
class_name GestionnaireMoulage

signal moulage_actualise
signal moulage_termine(resultat: StringName)

const RESULTAT_ECHEC: StringName = &"echec"
const RESULTAT_CORRECT: StringName = &"correct"
const RESULTAT_PARFAIT: StringName = &"parfait"

@export var nombre_points_facile: int = 4
@export var nombre_points_normal: int = 5
@export var nombre_points_difficile: int = 6
@export var rayon_point_facile: float = 0.09
@export var rayon_point_normal: float = 0.07
@export var rayon_point_difficile: float = 0.055
@export var duree_point_facile: float = 0.8
@export var duree_point_normale: float = 1.0
@export var duree_point_difficile: float = 1.2
@export var puissance_tremblement_facile: float = 0.035
@export var puissance_tremblement_normale: float = 0.055
@export var puissance_tremblement_difficile: float = 0.08
@export var frequence_tremblement_facile: float = 2.0
@export var frequence_tremblement_normale: float = 2.6
@export var frequence_tremblement_difficile: float = 3.2
@export var alea_duree_point_facile: float = 0.12
@export var alea_duree_point_normal: float = 0.1
@export var alea_duree_point_difficile: float = 0.08
@export var alea_tremblement_facile: float = 0.01
@export var alea_tremblement_normal: float = 0.015
@export var alea_tremblement_difficile: float = 0.02
@export var alea_position_x_facile: float = 0.03
@export var alea_position_x_normal: float = 0.05
@export var alea_position_x_difficile: float = 0.07
@export var alea_position_y_facile: float = 0.16
@export var alea_position_y_normal: float = 0.22
@export var alea_position_y_difficile: float = 0.28
@export var distance_minimale_entre_points: float = 0.06
@export var sensibilite_souris: float = 1.0
@export var seuil_parfait: float = 0.88
@export var seuil_correct: float = 0.6

var points: PackedVector2Array = PackedVector2Array()
var position_curseur: Vector2 = Vector2(0.5, 0.5)
var index_point_actuel: int = 0
var nombre_points_actuel: int = 0
var rayon_point_actuel: float = 0.0
var duree_point_actuelle: float = 0.0
var puissance_tremblement_actuelle: float = 0.0
var frequence_tremblement_actuelle: float = 0.0
var alea_position_x_actuel: float = 0.0
var alea_position_y_actuel: float = 0.0
var temps_sur_point: float = 0.0
var temps_dans_points: float = 0.0
var temps_total: float = 0.0
var temps_avant_tremblement: float = 0.0
var direction_tremblement: Vector2 = Vector2.ZERO
var actif: bool = false
var generateur := RandomNumberGenerator.new()

func demarrer(difficulte: DonneesCommandeForge.Difficulte) -> bool:
	generateur.randomize()
	_configurer_difficulte(difficulte)
	if nombre_points_actuel <= 0 or rayon_point_actuel <= 0.0 or duree_point_actuelle <= 0.0:
		return false
	_generer_points()
	position_curseur = points[0]
	index_point_actuel = 0
	temps_sur_point = 0.0
	temps_dans_points = 0.0
	temps_total = 0.0
	temps_avant_tremblement = 0.0
	direction_tremblement = Vector2.from_angle(generateur.randf_range(0.0, TAU))
	actif = true
	moulage_actualise.emit()
	return true

func deplacer_curseur(deplacement_normalise: Vector2) -> void:
	if not actif:
		return
	position_curseur += deplacement_normalise * sensibilite_souris
	position_curseur.x = clampf(position_curseur.x, 0.0, 1.0)
	position_curseur.y = clampf(position_curseur.y, 0.0, 1.0)
	moulage_actualise.emit()

func mettre_a_jour(delta: float) -> void:
	if not actif or delta <= 0.0:
		return
	temps_total += delta
	temps_avant_tremblement -= delta
	while temps_avant_tremblement <= 0.0:
		direction_tremblement = Vector2.from_angle(generateur.randf_range(0.0, TAU))
		temps_avant_tremblement += 1.0 / maxf(frequence_tremblement_actuelle, 0.001)
	position_curseur += direction_tremblement * puissance_tremblement_actuelle * delta
	position_curseur.x = clampf(position_curseur.x, 0.0, 1.0)
	position_curseur.y = clampf(position_curseur.y, 0.0, 1.0)
	if position_curseur.distance_to(obtenir_point_actuel()) <= rayon_point_actuel:
		temps_sur_point += delta
		temps_dans_points += delta
		if temps_sur_point >= duree_point_actuelle:
			_terminer_point()
	moulage_actualise.emit()

func obtenir_point_actuel() -> Vector2:
	if index_point_actuel < 0 or index_point_actuel >= points.size():
		return Vector2.ZERO
	return points[index_point_actuel]

func obtenir_progression() -> float:
	if nombre_points_actuel <= 0:
		return 0.0
	var progression_point: float = clampf(temps_sur_point / maxf(duree_point_actuelle, 0.001), 0.0, 1.0)
	return clampf((float(index_point_actuel) + progression_point) / float(nombre_points_actuel), 0.0, 1.0)

func curseur_dans_point() -> bool:
	return actif and position_curseur.distance_to(obtenir_point_actuel()) <= rayon_point_actuel

func _generer_points() -> void:
	points.clear()
	for index: int in nombre_points_actuel:
		var proportion: float = float(index) / float(maxi(nombre_points_actuel - 1, 1))
		var position_x: float = lerpf(0.16, 0.84, proportion) + generateur.randf_range(-alea_position_x_actuel, alea_position_x_actuel)
		var minimum_x: float = 0.1 + distance_minimale_entre_points * float(index)
		var maximum_x: float = 0.9 - distance_minimale_entre_points * float(nombre_points_actuel - index - 1)
		position_x = clampf(position_x, minimum_x, maximum_x)
		var position_y: float = clampf(0.5 + generateur.randf_range(-alea_position_y_actuel, alea_position_y_actuel), 0.1, 0.9)
		points.append(Vector2(position_x, position_y))

func _terminer_point() -> void:
	index_point_actuel += 1
	temps_sur_point = 0.0
	if index_point_actuel >= nombre_points_actuel:
		_terminer()

func _terminer() -> void:
	var precision: float = temps_dans_points / maxf(temps_total, 0.001)
	actif = false
	if precision >= seuil_parfait:
		moulage_termine.emit(RESULTAT_PARFAIT)
	elif precision >= seuil_correct:
		moulage_termine.emit(RESULTAT_CORRECT)
	else:
		moulage_termine.emit(RESULTAT_ECHEC)

func _configurer_difficulte(difficulte: DonneesCommandeForge.Difficulte) -> void:
	match difficulte:
		DonneesCommandeForge.Difficulte.NORMALE:
			nombre_points_actuel = nombre_points_normal
			rayon_point_actuel = rayon_point_normal
			duree_point_actuelle = duree_point_normale
			puissance_tremblement_actuelle = puissance_tremblement_normale
			_appliquer_alea(alea_duree_point_normal, alea_tremblement_normal)
			frequence_tremblement_actuelle = frequence_tremblement_normale
			alea_position_x_actuel = alea_position_x_normal
			alea_position_y_actuel = alea_position_y_normal
		DonneesCommandeForge.Difficulte.DIFFICILE:
			nombre_points_actuel = nombre_points_difficile
			rayon_point_actuel = rayon_point_difficile
			duree_point_actuelle = duree_point_difficile
			puissance_tremblement_actuelle = puissance_tremblement_difficile
			_appliquer_alea(alea_duree_point_difficile, alea_tremblement_difficile)
			frequence_tremblement_actuelle = frequence_tremblement_difficile
			alea_position_x_actuel = alea_position_x_difficile
			alea_position_y_actuel = alea_position_y_difficile
		_:
			nombre_points_actuel = nombre_points_facile
			rayon_point_actuel = rayon_point_facile
			duree_point_actuelle = duree_point_facile
			puissance_tremblement_actuelle = puissance_tremblement_facile
			_appliquer_alea(alea_duree_point_facile, alea_tremblement_facile)
			frequence_tremblement_actuelle = frequence_tremblement_facile
			alea_position_x_actuel = alea_position_x_facile
			alea_position_y_actuel = alea_position_y_facile

func _appliquer_alea(alea_duree: float, alea_tremblement: float) -> void:
	duree_point_actuelle = maxf(0.1, duree_point_actuelle + generateur.randf_range(-alea_duree, alea_duree))
	puissance_tremblement_actuelle = maxf(0.0, puissance_tremblement_actuelle + generateur.randf_range(-alea_tremblement, alea_tremblement))

extends Node
class_name GestionnaireMoulage

signal moulage_actualise
signal moulage_termine(resultat: StringName)

const RESULTAT_ECHEC: StringName = &"echec"
const RESULTAT_CORRECT: StringName = &"correct"
const RESULTAT_PARFAIT: StringName = &"parfait"

@export var nombre_points_facile: int = 10
@export var nombre_points_normal: int = 13
@export var nombre_points_difficile: int = 16
@export var rayon_point_facile: float = 0.058
@export var rayon_point_normal: float = 0.043
@export var rayon_point_difficile: float = 0.033
@export var duree_point_facile: float = 0.5
@export var duree_point_normale: float = 0.65
@export var duree_point_difficile: float = 0.8
@export var puissance_tremblement_facile: float = 0.035
@export var puissance_tremblement_normale: float = 0.055
@export var puissance_tremblement_difficile: float = 0.08
@export var frequence_tremblement_facile: float = 2.0
@export var frequence_tremblement_normale: float = 2.6
@export var frequence_tremblement_difficile: float = 3.2
@export var vitesse_defilement_points_facile: float = 0.045
@export var vitesse_defilement_points_normale: float = 0.06
@export var vitesse_defilement_points_difficile: float = 0.075
@export var position_reapparition_droite: float = 0.94
@export var position_depart_point_actif: float = 0.8
@export var alea_duree_point_facile: float = 0.12
@export var alea_duree_point_normal: float = 0.1
@export var alea_duree_point_difficile: float = 0.08
@export var alea_tremblement_facile: float = 0.01
@export var alea_tremblement_normal: float = 0.015
@export var alea_tremblement_difficile: float = 0.02
@export var alea_position_x_facile: float = 0.44
@export var alea_position_x_normal: float = 0.46
@export var alea_position_x_difficile: float = 0.47
@export var alea_position_y_facile: float = 0.4
@export var alea_position_y_normal: float = 0.44
@export var alea_position_y_difficile: float = 0.46
@export var distance_minimale_entre_points: float = 0.18
@export var duree_matiere_fondue_facile: float = 14.0
@export var duree_matiere_fondue_normale: float = 20.0
@export var duree_matiere_fondue_difficile: float = 26.0
@export var delai_tolerance_sortie: float = 0.15
@export var vitesse_perte_progression: float = 0.45
@export var palier_progression_securisee: float = 0.25
@export var duree_avertissement_secousse: float = 0.25
@export var duree_secousse: float = 0.14
@export var poids_precision: float = 0.6
@export var poids_matiere: float = 0.25
@export var poids_stabilite: float = 0.15
@export var penalite_par_sortie: float = 0.04
@export var penalite_duree_moyenne_sortie: float = 0.12
@export var seuil_parfait: float = 0.85

var points: PackedVector2Array = PackedVector2Array()
var position_curseur: Vector2 = Vector2(0.5, 0.5)
var index_point_actuel: int = 0
var nombre_points_actuel: int = 0
var rayon_point_actuel: float = 0.0
var duree_point_actuelle: float = 0.0
var puissance_tremblement_actuelle: float = 0.0
var frequence_tremblement_actuelle: float = 0.0
var vitesse_defilement_points_actuelle: float = 0.0
var alea_position_x_actuel: float = 0.0
var alea_position_y_actuel: float = 0.0
var temps_sur_point: float = 0.0
var temps_dans_points: float = 0.0
var temps_total: float = 0.0
var temps_avant_tremblement: float = 0.0
var temps_secousse_restant: float = 0.0
var direction_tremblement: Vector2 = Vector2.ZERO
var avertissement_secousse: bool = false
var temps_hors_point: float = 0.0
var temps_total_hors_points: float = 0.0
var nombre_sorties: int = 0
var curseur_etait_dans_point: bool = true
var sortie_en_cours: bool = false
var progression_securisee: float = 0.0
var duree_matiere_fondue_actuelle: float = 0.0
var matiere_fondue_restante: float = 0.0
var dernier_score_precision: float = 0.0
var dernier_score_matiere: float = 0.0
var dernier_score_stabilite: float = 0.0
var dernier_score_final: float = 0.0
var actif: bool = false
var generateur := RandomNumberGenerator.new()

func demarrer(difficulte: DonneesCommandeForge.Difficulte) -> bool:
	generateur.randomize()
	_configurer_difficulte(difficulte)
	if nombre_points_actuel <= 0 or rayon_point_actuel <= 0.0 or duree_point_actuelle <= 0.0 or duree_matiere_fondue_actuelle <= 0.0:
		return false
	_generer_points()
	_placer_premier_point()
	position_curseur = points[0]
	index_point_actuel = 0
	temps_sur_point = 0.0
	temps_dans_points = 0.0
	temps_total = 0.0
	temps_avant_tremblement = _obtenir_intervalle_calme() + duree_avertissement_secousse
	temps_secousse_restant = 0.0
	direction_tremblement = Vector2.ZERO
	avertissement_secousse = false
	temps_hors_point = 0.0
	temps_total_hors_points = 0.0
	nombre_sorties = 0
	curseur_etait_dans_point = false
	sortie_en_cours = false
	progression_securisee = 0.0
	matiere_fondue_restante = duree_matiere_fondue_actuelle
	dernier_score_precision = 0.0
	dernier_score_matiere = 0.0
	dernier_score_stabilite = 0.0
	dernier_score_final = 0.0
	actif = true
	moulage_actualise.emit()
	return true

func definir_position_curseur(nouvelle_position: Vector2) -> void:
	if not actif:
		return
	position_curseur = nouvelle_position
	moulage_actualise.emit()

func mettre_a_jour(delta: float) -> void:
	if not actif or delta <= 0.0:
		return
	matiere_fondue_restante = maxf(0.0, matiere_fondue_restante - delta)
	if matiere_fondue_restante <= 0.0:
		actif = false
		_calculer_score_final()
		moulage_actualise.emit()
		moulage_termine.emit(RESULTAT_ECHEC)
		return
	temps_total += delta
	_faire_defiler_points(delta)
	_mettre_a_jour_secousse(delta)
	var index_point_avant: int = index_point_actuel
	var dans_point: bool = position_curseur.distance_to(obtenir_point_actuel()) <= rayon_point_actuel
	if dans_point:
		temps_hors_point = 0.0
		sortie_en_cours = false
		temps_sur_point += delta
		temps_dans_points += delta
		_actualiser_progression_securisee()
		if temps_sur_point >= duree_point_actuelle:
			_terminer_point()
			if not actif:
				return
	else:
		if curseur_etait_dans_point:
			nombre_sorties += 1
			temps_hors_point = 0.0
			sortie_en_cours = true
		temps_hors_point += delta
		if sortie_en_cours:
			temps_total_hors_points += delta
		if temps_hors_point > delai_tolerance_sortie:
			var perte: float = vitesse_perte_progression * duree_point_actuelle * delta
			temps_sur_point = maxf(progression_securisee, temps_sur_point - perte)
	if index_point_actuel == index_point_avant:
		curseur_etait_dans_point = dans_point
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

func obtenir_matiere_fondue() -> float:
	if duree_matiere_fondue_actuelle <= 0.0:
		return 0.0
	return clampf(matiere_fondue_restante / duree_matiere_fondue_actuelle * 100.0, 0.0, 100.0)

func secousse_est_imminente() -> bool:
	return avertissement_secousse

func obtenir_score_final() -> float:
	return dernier_score_final

func _generer_points() -> void:
	points.clear()
	var nombre_lignes: int = ceili(sqrt(float(nombre_points_actuel)))
	var variation_x: float = minf(0.04, maxf(0.01, alea_position_x_actuel * 0.08))
	var variation_y: float = minf(0.04, maxf(0.01, alea_position_y_actuel * 0.08))
	var index_point: int = 0
	var position_x: float = position_depart_point_actif
	while index_point < nombre_points_actuel:
		var lignes_disponibles: Array[int] = []
		for ligne: int in nombre_lignes:
			lignes_disponibles.append(ligne)
		for index: int in range(lignes_disponibles.size() - 1, 0, -1):
			var autre_index: int = generateur.randi_range(0, index)
			var ligne_temporaire: int = lignes_disponibles[index]
			lignes_disponibles[index] = lignes_disponibles[autre_index]
			lignes_disponibles[autre_index] = ligne_temporaire
		for ligne: int in lignes_disponibles:
			if index_point >= nombre_points_actuel:
				break
			var proportion_y: float = float(ligne) / float(maxi(nombre_lignes - 1, 1))
			var position_y: float = clampf(lerpf(0.06, 0.94, proportion_y) + generateur.randf_range(-variation_y, variation_y), 0.04, 0.96)
			points.append(Vector2(position_x, position_y))
			index_point += 1
		position_x += distance_minimale_entre_points + generateur.randf_range(0.0, variation_x)

func _placer_premier_point() -> void:
	if points.is_empty():
		return
	var meilleur_index: int = 0
	var meilleur_ecart: float = absf(points[0].x - position_depart_point_actif)
	for index: int in range(1, points.size()):
		var ecart: float = absf(points[index].x - position_depart_point_actif)
		if ecart < meilleur_ecart:
			meilleur_index = index
			meilleur_ecart = ecart
	var point_temporaire: Vector2 = points[0]
	points[0] = points[meilleur_index]
	points[meilleur_index] = point_temporaire
	var meilleure_position := Vector2(clampf(position_depart_point_actif, 0.06, 0.94), points[0].y)
	var meilleure_distance: float = -1.0
	for tentative: int in 60:
		var position_candidate := Vector2(meilleure_position.x, lerpf(0.06, 0.94, float(tentative) / 59.0))
		var distance_plus_proche: float = 2.0
		for autre_index: int in range(1, points.size()):
			distance_plus_proche = minf(distance_plus_proche, position_candidate.distance_to(points[autre_index]))
		if distance_plus_proche > meilleure_distance:
			meilleure_distance = distance_plus_proche
			meilleure_position = position_candidate
	if meilleure_distance >= distance_minimale_entre_points:
		points[0] = meilleure_position

func _faire_defiler_points(delta: float) -> void:
	if vitesse_defilement_points_actuelle <= 0.0 or index_point_actuel < 0 or index_point_actuel >= points.size():
		return
	var marge_gauche: float = maxf(rayon_point_actuel, 0.02)
	var deplacement: float = minf(vitesse_defilement_points_actuelle * delta, maxf(points[index_point_actuel].x - marge_gauche, 0.0))
	for index: int in range(index_point_actuel, points.size()):
		points[index].x -= deplacement

func _terminer_point() -> void:
	index_point_actuel += 1
	temps_sur_point = 0.0
	temps_hors_point = 0.0
	progression_securisee = 0.0
	curseur_etait_dans_point = false
	sortie_en_cours = false
	if index_point_actuel < points.size() and points[index_point_actuel].x > position_reapparition_droite:
		var decalage_file: float = points[index_point_actuel].x - position_reapparition_droite
		for index: int in range(index_point_actuel, points.size()):
			points[index].x -= decalage_file
	if index_point_actuel >= nombre_points_actuel:
		_terminer()

func _terminer() -> void:
	_calculer_score_final()
	actif = false
	moulage_actualise.emit()
	if dernier_score_final >= seuil_parfait:
		moulage_termine.emit(RESULTAT_PARFAIT)
	else:
		moulage_termine.emit(RESULTAT_CORRECT)

func _actualiser_progression_securisee() -> void:
	if duree_point_actuelle <= 0.0 or palier_progression_securisee <= 0.0:
		return
	var progression: float = clampf(temps_sur_point / duree_point_actuelle, 0.0, 1.0)
	var palier: float = floorf(progression / palier_progression_securisee) * palier_progression_securisee
	progression_securisee = maxf(progression_securisee, minf(palier, 0.75) * duree_point_actuelle)

func _mettre_a_jour_secousse(delta: float) -> void:
	if temps_secousse_restant > 0.0:
		temps_secousse_restant = maxf(0.0, temps_secousse_restant - delta)
		if temps_secousse_restant <= 0.0:
			temps_avant_tremblement = _obtenir_intervalle_calme() + duree_avertissement_secousse
		return
	temps_avant_tremblement -= delta
	if not avertissement_secousse and temps_avant_tremblement <= duree_avertissement_secousse:
		avertissement_secousse = true
		direction_tremblement = Vector2.from_angle(generateur.randf_range(0.0, TAU))
	if temps_avant_tremblement <= 0.0:
		avertissement_secousse = false
		temps_secousse_restant = duree_secousse

func _obtenir_intervalle_calme() -> float:
	return 1.0 / maxf(frequence_tremblement_actuelle, 0.001)

func _calculer_score_final() -> void:
	dernier_score_precision = clampf(temps_dans_points / maxf(temps_total, 0.001), 0.0, 1.0)
	dernier_score_matiere = clampf(matiere_fondue_restante / maxf(duree_matiere_fondue_actuelle, 0.001), 0.0, 1.0)
	var duree_moyenne_sortie: float = 0.0
	if nombre_sorties > 0:
		duree_moyenne_sortie = temps_total_hors_points / float(nombre_sorties)
	dernier_score_stabilite = clampf(1.0 - float(nombre_sorties) * penalite_par_sortie - duree_moyenne_sortie * penalite_duree_moyenne_sortie, 0.0, 1.0)
	var total_poids: float = maxf(poids_precision + poids_matiere + poids_stabilite, 0.001)
	dernier_score_final = clampf((dernier_score_precision * poids_precision + dernier_score_matiere * poids_matiere + dernier_score_stabilite * poids_stabilite) / total_poids, 0.0, 1.0)

func _configurer_difficulte(difficulte: DonneesCommandeForge.Difficulte) -> void:
	match difficulte:
		DonneesCommandeForge.Difficulte.NORMALE:
			nombre_points_actuel = nombre_points_normal
			rayon_point_actuel = rayon_point_normal
			duree_point_actuelle = duree_point_normale
			puissance_tremblement_actuelle = puissance_tremblement_normale
			_appliquer_alea(alea_duree_point_normal, alea_tremblement_normal)
			frequence_tremblement_actuelle = frequence_tremblement_normale
			vitesse_defilement_points_actuelle = vitesse_defilement_points_normale
			alea_position_x_actuel = alea_position_x_normal
			alea_position_y_actuel = alea_position_y_normal
			duree_matiere_fondue_actuelle = duree_matiere_fondue_normale
		DonneesCommandeForge.Difficulte.DIFFICILE:
			nombre_points_actuel = nombre_points_difficile
			rayon_point_actuel = rayon_point_difficile
			duree_point_actuelle = duree_point_difficile
			puissance_tremblement_actuelle = puissance_tremblement_difficile
			_appliquer_alea(alea_duree_point_difficile, alea_tremblement_difficile)
			frequence_tremblement_actuelle = frequence_tremblement_difficile
			vitesse_defilement_points_actuelle = vitesse_defilement_points_difficile
			alea_position_x_actuel = alea_position_x_difficile
			alea_position_y_actuel = alea_position_y_difficile
			duree_matiere_fondue_actuelle = duree_matiere_fondue_difficile
		_:
			nombre_points_actuel = nombre_points_facile
			rayon_point_actuel = rayon_point_facile
			duree_point_actuelle = duree_point_facile
			puissance_tremblement_actuelle = puissance_tremblement_facile
			_appliquer_alea(alea_duree_point_facile, alea_tremblement_facile)
			frequence_tremblement_actuelle = frequence_tremblement_facile
			vitesse_defilement_points_actuelle = vitesse_defilement_points_facile
			alea_position_x_actuel = alea_position_x_facile
			alea_position_y_actuel = alea_position_y_facile
			duree_matiere_fondue_actuelle = duree_matiere_fondue_facile

func _appliquer_alea(alea_duree: float, alea_tremblement: float) -> void:
	duree_point_actuelle = maxf(0.1, duree_point_actuelle + generateur.randf_range(-alea_duree, alea_duree))
	puissance_tremblement_actuelle = maxf(0.0, puissance_tremblement_actuelle + generateur.randf_range(-alea_tremblement, alea_tremblement))

extends Node
class_name GestionnaireChauffe

signal chauffe_actualisee
signal chauffe_terminee(resultat: StringName)

const RESULTAT_ECHEC: StringName = &"echec"
const RESULTAT_CORRECT: StringName = &"correct"
const RESULTAT_PARFAIT: StringName = &"parfait"
const ETAT_PARFAIT: StringName = &"parfait"
const ETAT_CORRECT: StringName = &"correct"
const ETAT_TOLERANCE: StringName = &"tolerance"
const ETAT_HORS_ZONE: StringName = &"hors_zone"

var niveaux_defaut_facile: PackedFloat32Array = PackedFloat32Array([32.0, 60.0])
var niveaux_defaut_normal: PackedFloat32Array = PackedFloat32Array([28.0, 52.0, 72.0])
var niveaux_defaut_difficile: PackedFloat32Array = PackedFloat32Array([24.0, 44.0, 64.0, 84.0])

@export_group("Clics")
@export var impulsion_chauffe_par_clic: float = 9.0
@export var puissance_chauffe_maximum: float = 100.0
@export var delai_clic_rapide: float = 0.12
@export var delai_clic_lent: float = 0.45
@export var multiplicateur_clic_lent: float = 0.55
@export var multiplicateur_clic_rapide: float = 2.1
@export var distance_resistance_cible: float = 16.0
@export var resistance_proche_cible: float = 0.42
@export_group("Descente")
@export var dissipation_chauffe_par_seconde: float = 12.0
@export var acceleration_dissipation_haute_temperature: float = 2.6
@export var dissipation_chauffe_maximum: float = 48.0
@export var reactivite_temperature: float = 3.5
@export_group("Niveaux")
@export var niveaux_facile: PackedFloat32Array = PackedFloat32Array([32.0, 60.0])
@export var niveaux_normal: PackedFloat32Array = PackedFloat32Array([28.0, 52.0, 72.0])
@export var niveaux_difficile: PackedFloat32Array = PackedFloat32Array([24.0, 44.0, 64.0, 84.0])
@export var alea_niveaux_facile: float = 4.0
@export var alea_niveaux_normal: float = 3.0
@export var alea_niveaux_difficile: float = 2.0
@export_group("Zones facile")
@export var tolerance_facile: float = 1.9
@export var variation_tolerance_facile: float = 0.45
@export var multiplicateur_zone_correcte_facile: float = 3.68
@export var multiplicateur_zone_tolerance_facile: float = 5.99
@export_group("Zones normale")
@export var tolerance_normale: float = 1.5
@export var variation_tolerance_normale: float = 0.3
@export var multiplicateur_zone_correcte_normale: float = 3.48
@export var multiplicateur_zone_tolerance_normale: float = 5.32
@export_group("Zones difficile")
@export var tolerance_difficile: float = 1.1
@export var variation_tolerance_difficile: float = 0.2
@export var multiplicateur_zone_correcte_difficile: float = 3.18
@export var multiplicateur_zone_tolerance_difficile: float = 4.64
@export_group("Maintien facile")
@export var temps_maintien_base_facile: float = 1.25
@export var augmentation_maintien_par_niveau_facile: float = 0.25
@export var bonus_temps_par_niveau_facile: float = 2.0
@export var vitesse_temps_global_facile: float = 0.75
@export_group("Maintien normal")
@export var temps_maintien_base_normal: float = 1.45
@export var augmentation_maintien_par_niveau_normal: float = 0.3
@export var bonus_temps_par_niveau_normal: float = 1.8
@export var vitesse_temps_global_normale: float = 0.85
@export_group("Maintien difficile")
@export var temps_maintien_base_difficile: float = 1.65
@export var augmentation_maintien_par_niveau_difficile: float = 0.35
@export var bonus_temps_par_niveau_difficile: float = 1.5
@export var vitesse_temps_global_difficile: float = 0.95
@export_group("Temps et penalites")
@export var temps_maximum_facile: float = 15.0
@export var temps_maximum_normal: float = 13.0
@export var temps_maximum_difficile: float = 11.0
@export var multiplicateur_progression_parfaite: float = 1.5
@export var multiplicateur_progression_correcte: float = 1.0
@export var multiplicateur_progression_tolerance: float = 0.45
@export var score_precision_tolerance: float = 0.3
@export var perte_progression_hors_zone_par_seconde: float = 0.9
@export var temps_hors_zone_avant_reinitialisation: float = 1.1
@export var multiplicateur_temps_parfait: float = 0.8
@export var multiplicateur_temps_correct: float = 1.0
@export var multiplicateur_temps_tolerance: float = 1.0
@export var multiplicateur_temps_hors_zone: float = 1.1
@export var seuil_qualite_parfaite: float = 0.93
@export var seuil_qualite_correcte: float = 0.45

var temperature_actuelle: float = 0.0
var puissance_chauffe: float = 0.0
var niveaux_a_maintenir: PackedFloat32Array = PackedFloat32Array()
var index_niveau: int = 0
var tolerance_actuelle: float = 0.0
var tolerance_base_actuelle: float = 0.0
var variation_tolerance_actuelle: float = 0.0
var largeur_zone_correcte: float = 0.0
var largeur_zone_tolerance: float = 0.0
var temps_maximum_actuel: float = 0.0
var temps_global_restant: float = 0.0
var temps_maintien_requis: float = 0.0
var progression_maintien: float = 0.0
var temps_hors_zone: float = 0.0
var precision_cumulee: float = 0.0
var temps_maintien_total: float = 0.0
var chauffe_parfaite_sans_ecart: bool = true
var dernier_clic_ms: int = -1
var etat_temperature: StringName = ETAT_HORS_ZONE
var actif: bool = false
var multiplicateur_zone_correcte_actuel: float = 0.0
var multiplicateur_zone_tolerance_actuel: float = 0.0
var temps_maintien_base_actuel: float = 0.0
var augmentation_maintien_actuelle: float = 0.0
var bonus_temps_niveau_actuel: float = 0.0
var vitesse_temps_global_actuelle: float = 1.0
var generateur := RandomNumberGenerator.new()

func demarrer(difficulte: DonneesCommandeForge.Difficulte) -> bool:
	generateur.randomize()
	_configurer_difficulte(difficulte)
	if niveaux_a_maintenir.is_empty():
		return false
	temperature_actuelle = 0.0
	puissance_chauffe = 0.0
	index_niveau = 0
	progression_maintien = 0.0
	temps_hors_zone = 0.0
	precision_cumulee = 0.0
	temps_maintien_total = 0.0
	chauffe_parfaite_sans_ecart = true
	dernier_clic_ms = -1
	etat_temperature = ETAT_HORS_ZONE
	temps_global_restant = temps_maximum_actuel
	_configurer_maintien_niveau()
	actif = true
	chauffe_actualisee.emit()
	return true

func mettre_a_jour(delta: float) -> void:
	if not actif or delta <= 0.0:
		return
	var dissipation: float = _obtenir_dissipation_actuelle()
	puissance_chauffe = move_toward(puissance_chauffe, 0.0, dissipation * delta)
	var lissage: float = 1.0 - exp(-reactivite_temperature * delta)
	temperature_actuelle = lerpf(temperature_actuelle, puissance_chauffe, lissage)
	_mettre_a_jour_maintien(delta)
	if actif:
		_mettre_a_jour_temps_global(delta)
	chauffe_actualisee.emit()

func enregistrer_clic() -> void:
	if not actif:
		return
	var maintenant: int = Time.get_ticks_msec()
	var multiplicateur_rythme: float = _obtenir_multiplicateur_rythme(maintenant)
	dernier_clic_ms = maintenant
	var resistance: float = _obtenir_resistance_cible()
	puissance_chauffe = minf(puissance_chauffe_maximum, puissance_chauffe + impulsion_chauffe_par_clic * multiplicateur_rythme * resistance)
	chauffe_actualisee.emit()

func obtenir_niveau_cible() -> float:
	if index_niveau < 0 or index_niveau >= niveaux_a_maintenir.size():
		return 0.0
	return niveaux_a_maintenir[index_niveau]

func obtenir_limite_basse() -> float:
	return maxf(0.0, obtenir_niveau_cible() - tolerance_actuelle)

func obtenir_limite_haute() -> float:
	return minf(100.0, obtenir_niveau_cible() + tolerance_actuelle)

func obtenir_limite_correcte_basse() -> float:
	return maxf(0.0, obtenir_niveau_cible() - largeur_zone_correcte)

func obtenir_limite_correcte_haute() -> float:
	return minf(100.0, obtenir_niveau_cible() + largeur_zone_correcte)

func obtenir_limite_tolerance_basse() -> float:
	return maxf(0.0, obtenir_niveau_cible() - largeur_zone_tolerance)

func obtenir_limite_tolerance_haute() -> float:
	return minf(100.0, obtenir_niveau_cible() + largeur_zone_tolerance)

func obtenir_temps_restant() -> float:
	return maxf(0.0, temps_global_restant)

func obtenir_progression_temps() -> float:
	return obtenir_progression_maintien()

func obtenir_progression_maintien() -> float:
	if temps_maintien_requis <= 0.0:
		return 0.0
	return clampf(progression_maintien / temps_maintien_requis, 0.0, 1.0)

func obtenir_nom_etat_temperature() -> String:
	match etat_temperature:
		ETAT_PARFAIT:
			return "Parfait"
		ETAT_CORRECT:
			return "Correct"
		ETAT_TOLERANCE:
			return "Tolerance"
		_:
			return "Hors zone"

func _obtenir_multiplicateur_rythme(maintenant: int) -> float:
	if dernier_clic_ms < 0:
		return 1.0
	var delai: float = float(maintenant - dernier_clic_ms) / 1000.0
	if delai >= delai_clic_lent:
		return multiplicateur_clic_lent
	if delai <= delai_clic_rapide:
		return multiplicateur_clic_rapide
	var ratio: float = inverse_lerp(delai_clic_lent, delai_clic_rapide, delai)
	return lerpf(multiplicateur_clic_lent, multiplicateur_clic_rapide, ratio)

func _obtenir_resistance_cible() -> float:
	var cible: float = obtenir_niveau_cible()
	if temperature_actuelle >= cible or distance_resistance_cible <= 0.0:
		return 1.0
	var ratio: float = clampf((cible - temperature_actuelle) / distance_resistance_cible, 0.0, 1.0)
	return lerpf(resistance_proche_cible, 1.0, ratio)

func _obtenir_dissipation_actuelle() -> float:
	var ratio_temperature: float = clampf(temperature_actuelle / maxf(puissance_chauffe_maximum, 0.001), 0.0, 1.0)
	var multiplicateur: float = 1.0 + acceleration_dissipation_haute_temperature * ratio_temperature * ratio_temperature
	return minf(dissipation_chauffe_par_seconde * multiplicateur, dissipation_chauffe_maximum)

func _mettre_a_jour_maintien(delta: float) -> void:
	etat_temperature = _obtenir_etat_temperature()
	if progression_maintien > 0.0 and etat_temperature != ETAT_PARFAIT:
		chauffe_parfaite_sans_ecart = false
	match etat_temperature:
		ETAT_PARFAIT:
			var progression_parfaite: float = delta * multiplicateur_progression_parfaite
			progression_maintien += progression_parfaite
			precision_cumulee += progression_parfaite
			temps_maintien_total += progression_parfaite
			temps_hors_zone = 0.0
		ETAT_CORRECT:
			var progression_correcte: float = delta * multiplicateur_progression_correcte
			progression_maintien += progression_correcte
			precision_cumulee += progression_correcte * 0.65
			temps_maintien_total += progression_correcte
			temps_hors_zone = 0.0
		ETAT_TOLERANCE:
			var progression_tolerance: float = delta * multiplicateur_progression_tolerance
			progression_maintien += progression_tolerance
			precision_cumulee += progression_tolerance * score_precision_tolerance
			temps_maintien_total += progression_tolerance
			temps_hors_zone = 0.0
		_:
			progression_maintien = maxf(0.0, progression_maintien - perte_progression_hors_zone_par_seconde * delta)
			temps_hors_zone += delta
			if temps_hors_zone >= temps_hors_zone_avant_reinitialisation:
				progression_maintien = 0.0
	if progression_maintien >= temps_maintien_requis:
		_terminer_niveau()

func _obtenir_etat_temperature() -> StringName:
	var ecart: float = absf(temperature_actuelle - obtenir_niveau_cible())
	if ecart <= tolerance_actuelle:
		return ETAT_PARFAIT
	if ecart <= largeur_zone_correcte:
		return ETAT_CORRECT
	if ecart <= largeur_zone_tolerance:
		return ETAT_TOLERANCE
	return ETAT_HORS_ZONE

func _mettre_a_jour_temps_global(delta: float) -> void:
	var multiplicateur: float = vitesse_temps_global_actuelle
	if etat_temperature == ETAT_PARFAIT:
		multiplicateur *= multiplicateur_temps_parfait
	elif etat_temperature == ETAT_CORRECT:
		multiplicateur *= multiplicateur_temps_correct
	elif etat_temperature == ETAT_TOLERANCE:
		multiplicateur *= multiplicateur_temps_tolerance
	elif etat_temperature == ETAT_HORS_ZONE:
		multiplicateur *= multiplicateur_temps_hors_zone
	temps_global_restant = maxf(0.0, temps_global_restant - delta * multiplicateur)
	if temps_global_restant <= 0.0:
		_terminer(RESULTAT_ECHEC)

func _configurer_maintien_niveau() -> void:
	progression_maintien = 0.0
	temps_hors_zone = 0.0
	temps_maintien_requis = temps_maintien_base_actuel + augmentation_maintien_actuelle * float(index_niveau)
	tolerance_actuelle = maxf(0.25, tolerance_base_actuelle + generateur.randf_range(-variation_tolerance_actuelle, variation_tolerance_actuelle))
	largeur_zone_correcte = tolerance_actuelle * multiplicateur_zone_correcte_actuel
	largeur_zone_tolerance = tolerance_actuelle * multiplicateur_zone_tolerance_actuel

func _terminer_niveau() -> void:
	index_niveau += 1
	temps_global_restant = minf(temps_maximum_actuel, temps_global_restant + bonus_temps_niveau_actuel)
	if index_niveau >= niveaux_a_maintenir.size():
		var precision_moyenne: float = precision_cumulee / maxf(temps_maintien_total, 0.001)
		if precision_moyenne >= seuil_qualite_parfaite:
			_terminer(RESULTAT_PARFAIT)
		elif precision_moyenne >= seuil_qualite_correcte:
			_terminer(RESULTAT_CORRECT)
		else:
			_terminer(RESULTAT_ECHEC)
		return
	_configurer_maintien_niveau()

func _terminer(resultat: StringName) -> void:
	if not actif:
		return
	actif = false
	chauffe_terminee.emit(resultat)

func _configurer_difficulte(difficulte: DonneesCommandeForge.Difficulte) -> void:
	match difficulte:
		DonneesCommandeForge.Difficulte.NORMALE:
			niveaux_a_maintenir = _aleatoriser_niveaux(_obtenir_niveaux(niveaux_normal, niveaux_defaut_normal), alea_niveaux_normal)
			tolerance_base_actuelle = tolerance_normale
			variation_tolerance_actuelle = variation_tolerance_normale
			multiplicateur_zone_correcte_actuel = multiplicateur_zone_correcte_normale
			multiplicateur_zone_tolerance_actuel = multiplicateur_zone_tolerance_normale
			temps_maximum_actuel = temps_maximum_normal
			temps_maintien_base_actuel = temps_maintien_base_normal
			augmentation_maintien_actuelle = augmentation_maintien_par_niveau_normal
			bonus_temps_niveau_actuel = bonus_temps_par_niveau_normal
			vitesse_temps_global_actuelle = vitesse_temps_global_normale
		DonneesCommandeForge.Difficulte.DIFFICILE:
			niveaux_a_maintenir = _aleatoriser_niveaux(_obtenir_niveaux(niveaux_difficile, niveaux_defaut_difficile), alea_niveaux_difficile)
			tolerance_base_actuelle = tolerance_difficile
			variation_tolerance_actuelle = variation_tolerance_difficile
			multiplicateur_zone_correcte_actuel = multiplicateur_zone_correcte_difficile
			multiplicateur_zone_tolerance_actuel = multiplicateur_zone_tolerance_difficile
			temps_maximum_actuel = temps_maximum_difficile
			temps_maintien_base_actuel = temps_maintien_base_difficile
			augmentation_maintien_actuelle = augmentation_maintien_par_niveau_difficile
			bonus_temps_niveau_actuel = bonus_temps_par_niveau_difficile
			vitesse_temps_global_actuelle = vitesse_temps_global_difficile
		_:
			niveaux_a_maintenir = _aleatoriser_niveaux(_obtenir_niveaux(niveaux_facile, niveaux_defaut_facile), alea_niveaux_facile)
			tolerance_base_actuelle = tolerance_facile
			variation_tolerance_actuelle = variation_tolerance_facile
			multiplicateur_zone_correcte_actuel = multiplicateur_zone_correcte_facile
			multiplicateur_zone_tolerance_actuel = multiplicateur_zone_tolerance_facile
			temps_maximum_actuel = temps_maximum_facile
			temps_maintien_base_actuel = temps_maintien_base_facile
			augmentation_maintien_actuelle = augmentation_maintien_par_niveau_facile
			bonus_temps_niveau_actuel = bonus_temps_par_niveau_facile
			vitesse_temps_global_actuelle = vitesse_temps_global_facile

func _obtenir_niveaux(niveaux: PackedFloat32Array, niveaux_defaut: PackedFloat32Array) -> PackedFloat32Array:
	return niveaux.duplicate() if not niveaux.is_empty() else niveaux_defaut.duplicate()

func _aleatoriser_niveaux(niveaux: PackedFloat32Array, alea: float) -> PackedFloat32Array:
	var resultat := PackedFloat32Array()
	for niveau: float in niveaux:
		resultat.append(clampf(niveau + generateur.randf_range(-alea, alea), 0.0, 100.0))
	return resultat

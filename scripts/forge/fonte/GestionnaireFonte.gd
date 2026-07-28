extends Node
class_name GestionnaireFonte

signal fonte_actualisee
signal fonte_terminee(resultat: StringName)

const RESULTAT_ECHEC: StringName = &"echec"
const RESULTAT_CORRECT: StringName = &"correct"
const RESULTAT_PARFAIT: StringName = &"parfait"
var niveaux_defaut_facile: PackedFloat32Array = PackedFloat32Array([45.0, 78.0])
var niveaux_defaut_normal: PackedFloat32Array = PackedFloat32Array([35.0, 58.0, 82.0])
var niveaux_defaut_difficile: PackedFloat32Array = PackedFloat32Array([30.0, 50.0, 70.0, 88.0])

@export var vitesse_montee_puissance: float = 62.0
@export var vitesse_descente_puissance: float = 52.0
@export var reactivite_temperature: float = 4.0
@export var frequence_instabilite: float = 2.2
@export var niveaux_facile: PackedFloat32Array = PackedFloat32Array([45.0, 78.0])
@export var niveaux_normal: PackedFloat32Array = PackedFloat32Array([35.0, 58.0, 82.0])
@export var niveaux_difficile: PackedFloat32Array = PackedFloat32Array([30.0, 50.0, 70.0, 88.0])
@export var tolerance_facile: float = 7.0
@export var tolerance_normale: float = 5.0
@export var tolerance_difficile: float = 3.5
@export var duree_maintien_facile: float = 1.2
@export var duree_maintien_normale: float = 1.45
@export var duree_maintien_difficile: float = 1.7
@export var temps_maximum_facile: float = 8.0
@export var temps_maximum_normal: float = 7.0
@export var temps_maximum_difficile: float = 6.0
@export var instabilite_facile: float = 0.4
@export var instabilite_normale: float = 1.0
@export var instabilite_difficile: float = 1.8
@export var alea_niveaux_facile: float = 5.0
@export var alea_niveaux_normal: float = 4.0
@export var alea_niveaux_difficile: float = 3.0

var puissance_four: float = 0.0
var temperature_base: float = 0.0
var temperature_actuelle: float = 0.0
var niveaux_a_maintenir: PackedFloat32Array = PackedFloat32Array()
var index_niveau: int = 0
var tolerance_actuelle: float = 0.0
var duree_maintien_actuelle: float = 0.0
var temps_maximum_actuel: float = 0.0
var amplitude_instabilite: float = 0.0
var temps_maintien: float = 0.0
var temps_niveau: float = 0.0
var temps_instabilite: float = 0.0
var temps_total_dans_zone: float = 0.0
var temps_total_parfait: float = 0.0
var actif: bool = false
var generateur := RandomNumberGenerator.new()

func demarrer(difficulte: DonneesCommandeForge.Difficulte) -> bool:
	generateur.randomize()
	_configurer_difficulte(difficulte)
	if niveaux_a_maintenir.is_empty():
		return false
	puissance_four = 0.0
	temperature_base = 0.0
	temperature_actuelle = 0.0
	index_niveau = 0
	temps_maintien = 0.0
	temps_niveau = 0.0
	temps_instabilite = 0.0
	temps_total_dans_zone = 0.0
	temps_total_parfait = 0.0
	actif = true
	fonte_actualisee.emit()
	return true

func mettre_a_jour(delta: float, clic_maintenu: bool) -> void:
	if not actif or delta <= 0.0:
		return
	temps_niveau += delta
	temps_instabilite += delta
	var puissance_cible: float = 100.0 if clic_maintenu else 0.0
	var vitesse_puissance: float = vitesse_montee_puissance if clic_maintenu else vitesse_descente_puissance
	puissance_four = move_toward(puissance_four, puissance_cible, vitesse_puissance * delta)
	var lissage: float = 1.0 - exp(-reactivite_temperature * delta)
	temperature_base = lerpf(temperature_base, puissance_four, lissage)
	var variation: float = sin(temps_instabilite * frequence_instabilite) * amplitude_instabilite
	temperature_actuelle = clampf(temperature_base + variation, 0.0, 100.0)
	var ecart: float = absf(temperature_actuelle - obtenir_niveau_cible())
	if ecart <= tolerance_actuelle:
		temps_maintien += delta
		temps_total_dans_zone += delta
		if ecart <= tolerance_actuelle * 0.35:
			temps_total_parfait += delta
	else:
		temps_maintien = 0.0
	if temps_maintien >= duree_maintien_actuelle:
		_terminer_niveau()
	elif temps_niveau >= temps_maximum_actuel:
		_terminer(RESULTAT_ECHEC)
	fonte_actualisee.emit()

func obtenir_niveau_cible() -> float:
	if index_niveau < 0 or index_niveau >= niveaux_a_maintenir.size():
		return 0.0
	return niveaux_a_maintenir[index_niveau]

func obtenir_limite_basse() -> float:
	return maxf(0.0, obtenir_niveau_cible() - tolerance_actuelle)

func obtenir_limite_haute() -> float:
	return minf(100.0, obtenir_niveau_cible() + tolerance_actuelle)

func obtenir_progression_maintien() -> float:
	if duree_maintien_actuelle <= 0.0:
		return 0.0
	return clampf(temps_maintien / duree_maintien_actuelle, 0.0, 1.0)

func obtenir_temps_restant() -> float:
	return maxf(0.0, temps_maximum_actuel - temps_niveau)

func obtenir_progression_temps() -> float:
	if temps_maximum_actuel <= 0.0:
		return 0.0
	return clampf(obtenir_temps_restant() / temps_maximum_actuel, 0.0, 1.0)

func _terminer_niveau() -> void:
	index_niveau += 1
	temps_maintien = 0.0
	temps_niveau = 0.0
	if index_niveau >= niveaux_a_maintenir.size():
		var proportion_parfaite: float = temps_total_parfait / maxf(temps_total_dans_zone, 0.001)
		_terminer(RESULTAT_PARFAIT if proportion_parfaite >= 0.75 else RESULTAT_CORRECT)

func _terminer(resultat: StringName) -> void:
	actif = false
	fonte_terminee.emit(resultat)

func _configurer_difficulte(difficulte: DonneesCommandeForge.Difficulte) -> void:
	match difficulte:
		DonneesCommandeForge.Difficulte.NORMALE:
			niveaux_a_maintenir = _obtenir_niveaux(niveaux_normal, niveaux_defaut_normal)
			niveaux_a_maintenir = _aleatoriser_niveaux(niveaux_a_maintenir, alea_niveaux_normal)
			tolerance_actuelle = tolerance_normale
			duree_maintien_actuelle = duree_maintien_normale
			temps_maximum_actuel = temps_maximum_normal
			amplitude_instabilite = instabilite_normale
		DonneesCommandeForge.Difficulte.DIFFICILE:
			niveaux_a_maintenir = _obtenir_niveaux(niveaux_difficile, niveaux_defaut_difficile)
			niveaux_a_maintenir = _aleatoriser_niveaux(niveaux_a_maintenir, alea_niveaux_difficile)
			tolerance_actuelle = tolerance_difficile
			duree_maintien_actuelle = duree_maintien_difficile
			temps_maximum_actuel = temps_maximum_difficile
			amplitude_instabilite = instabilite_difficile
		_:
			niveaux_a_maintenir = _obtenir_niveaux(niveaux_facile, niveaux_defaut_facile)
			niveaux_a_maintenir = _aleatoriser_niveaux(niveaux_a_maintenir, alea_niveaux_facile)
			tolerance_actuelle = tolerance_facile
			duree_maintien_actuelle = duree_maintien_facile
			temps_maximum_actuel = temps_maximum_facile
			amplitude_instabilite = instabilite_facile

func _obtenir_niveaux(niveaux: PackedFloat32Array, niveaux_defaut: PackedFloat32Array) -> PackedFloat32Array:
	return niveaux.duplicate() if not niveaux.is_empty() else niveaux_defaut.duplicate()

func _aleatoriser_niveaux(niveaux: PackedFloat32Array, alea: float) -> PackedFloat32Array:
	var resultat := PackedFloat32Array()
	for niveau: float in niveaux:
		resultat.append(clampf(niveau + generateur.randf_range(-alea, alea), 0.0, 100.0))
	return resultat

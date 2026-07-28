extends Node
class_name GestionnaireChauffe

signal chauffe_actualisee
signal chauffe_terminee(resultat: StringName)

const RESULTAT_ECHEC: StringName = &"echec"
const RESULTAT_CORRECT: StringName = &"correct"
const RESULTAT_PARFAIT: StringName = &"parfait"
var niveaux_defaut_facile: PackedFloat32Array = PackedFloat32Array([32.0, 60.0])
var niveaux_defaut_normal: PackedFloat32Array = PackedFloat32Array([28.0, 52.0, 72.0])
var niveaux_defaut_difficile: PackedFloat32Array = PackedFloat32Array([24.0, 44.0, 64.0, 84.0])

@export var impulsion_chauffe_par_clic: float = 9.0
@export var puissance_chauffe_maximum: float = 100.0
@export var dissipation_chauffe_par_seconde: float = 12.0
@export var reactivite_temperature: float = 3.5
@export var marge_puissance_validation: float = 6.0
@export var niveaux_facile: PackedFloat32Array = PackedFloat32Array([32.0, 60.0])
@export var niveaux_normal: PackedFloat32Array = PackedFloat32Array([28.0, 52.0, 72.0])
@export var niveaux_difficile: PackedFloat32Array = PackedFloat32Array([24.0, 44.0, 64.0, 84.0])
@export var tolerance_facile: float = 3.5
@export var tolerance_normale: float = 2.75
@export var tolerance_difficile: float = 2.0
@export var temps_maximum_facile: float = 7.0
@export var temps_maximum_normal: float = 6.0
@export var temps_maximum_difficile: float = 5.0
@export var alea_niveaux_facile: float = 4.0
@export var alea_niveaux_normal: float = 3.0
@export var alea_niveaux_difficile: float = 2.0

var temperature_actuelle: float = 0.0
var puissance_chauffe: float = 0.0
var niveaux_a_maintenir: PackedFloat32Array = PackedFloat32Array()
var index_niveau: int = 0
var tolerance_actuelle: float = 0.0
var temps_maximum_actuel: float = 0.0
var temps_niveau: float = 0.0
var precision_cumulee: float = 0.0
var actif: bool = false
var generateur := RandomNumberGenerator.new()

func demarrer(difficulte: DonneesCommandeForge.Difficulte) -> bool:
	generateur.randomize()
	_configurer_difficulte(difficulte)
	if niveaux_a_maintenir.is_empty():
		return false
	temperature_actuelle = 0.0
	puissance_chauffe = 0.0
	index_niveau = 0
	temps_niveau = 0.0
	precision_cumulee = 0.0
	actif = true
	chauffe_actualisee.emit()
	return true

func mettre_a_jour(delta: float) -> void:
	if not actif or delta <= 0.0:
		return
	temps_niveau += delta
	puissance_chauffe = move_toward(puissance_chauffe, 0.0, dissipation_chauffe_par_seconde * delta)
	var lissage: float = 1.0 - exp(-reactivite_temperature * delta)
	temperature_actuelle = lerpf(temperature_actuelle, puissance_chauffe, lissage)
	_verifier_niveau()
	if actif and temps_niveau >= temps_maximum_actuel:
		_terminer(RESULTAT_ECHEC)
	chauffe_actualisee.emit()

func enregistrer_clic() -> void:
	if not actif:
		return
	puissance_chauffe = minf(puissance_chauffe_maximum, puissance_chauffe + impulsion_chauffe_par_clic)
	chauffe_actualisee.emit()

func _verifier_niveau() -> void:
	var cible: float = obtenir_niveau_cible()
	var ecart: float = absf(temperature_actuelle - cible)
	var puissance_maitrisee: bool = puissance_chauffe <= obtenir_limite_haute() + marge_puissance_validation
	if ecart <= tolerance_actuelle and puissance_maitrisee:
		precision_cumulee += 1.0 - ecart / maxf(tolerance_actuelle, 0.001)
		_terminer_niveau()

func obtenir_niveau_cible() -> float:
	if index_niveau < 0 or index_niveau >= niveaux_a_maintenir.size():
		return 0.0
	return niveaux_a_maintenir[index_niveau]

func obtenir_limite_basse() -> float:
	return maxf(0.0, obtenir_niveau_cible() - tolerance_actuelle)

func obtenir_limite_haute() -> float:
	return minf(100.0, obtenir_niveau_cible() + tolerance_actuelle)

func obtenir_temps_restant() -> float:
	return maxf(0.0, temps_maximum_actuel - temps_niveau)

func obtenir_progression_temps() -> float:
	if temps_maximum_actuel <= 0.0:
		return 0.0
	return clampf(obtenir_temps_restant() / temps_maximum_actuel, 0.0, 1.0)

func _terminer_niveau() -> void:
	index_niveau += 1
	temps_niveau = 0.0
	if index_niveau >= niveaux_a_maintenir.size():
		var precision_moyenne: float = precision_cumulee / float(niveaux_a_maintenir.size())
		_terminer(RESULTAT_PARFAIT if precision_moyenne >= 0.75 else RESULTAT_CORRECT)

func _terminer(resultat: StringName) -> void:
	actif = false
	chauffe_terminee.emit(resultat)

func _configurer_difficulte(difficulte: DonneesCommandeForge.Difficulte) -> void:
	match difficulte:
		DonneesCommandeForge.Difficulte.NORMALE:
			niveaux_a_maintenir = _obtenir_niveaux(niveaux_normal, niveaux_defaut_normal)
			niveaux_a_maintenir = _aleatoriser_niveaux(niveaux_a_maintenir, alea_niveaux_normal)
			tolerance_actuelle = tolerance_normale
			temps_maximum_actuel = temps_maximum_normal
		DonneesCommandeForge.Difficulte.DIFFICILE:
			niveaux_a_maintenir = _obtenir_niveaux(niveaux_difficile, niveaux_defaut_difficile)
			niveaux_a_maintenir = _aleatoriser_niveaux(niveaux_a_maintenir, alea_niveaux_difficile)
			tolerance_actuelle = tolerance_difficile
			temps_maximum_actuel = temps_maximum_difficile
		_:
			niveaux_a_maintenir = _obtenir_niveaux(niveaux_facile, niveaux_defaut_facile)
			niveaux_a_maintenir = _aleatoriser_niveaux(niveaux_a_maintenir, alea_niveaux_facile)
			tolerance_actuelle = tolerance_facile
			temps_maximum_actuel = temps_maximum_facile

func _obtenir_niveaux(niveaux: PackedFloat32Array, niveaux_defaut: PackedFloat32Array) -> PackedFloat32Array:
	return niveaux.duplicate() if not niveaux.is_empty() else niveaux_defaut.duplicate()

func _aleatoriser_niveaux(niveaux: PackedFloat32Array, alea: float) -> PackedFloat32Array:
	var resultat := PackedFloat32Array()
	for niveau: float in niveaux:
		resultat.append(clampf(niveau + generateur.randf_range(-alea, alea), 0.0, 100.0))
	return resultat

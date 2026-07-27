extends Node
class_name GestionDeplacementLibreJoueur

enum AllureLibre {
	MARCHE,
	COURSE,
	SNEAKY
}

@export_group("Allure")
@export var allure_par_defaut: AllureLibre = AllureLibre.MARCHE
@export var action_changer_allure: StringName = &"dash"

@export_group("Marche")
@export_range(0.1, 3.0, 0.01) var marche_multiplicateur_vitesse: float = 0.70
@export var marche_acceleration_px_s2: float = 30000.0
@export var marche_deceleration_px_s2: float = 45000.0
@export var marche_freinage_virage_mult: float = 2.5
@export var marche_seuil_arret_px_s: float = 35.0

@export_group("Course")
@export_range(0.1, 3.0, 0.01) var course_multiplicateur_vitesse: float = 1.0
@export var course_acceleration_px_s2: float = 40000.0
@export var course_deceleration_px_s2: float = 38000.0
@export var course_freinage_virage_mult: float = 3.0
@export var course_seuil_arret_px_s: float = 40.0

@export_group("Sneaky")
@export_range(0.1, 3.0, 0.01) var sneaky_multiplicateur_vitesse: float = 0.40
@export var sneaky_acceleration_px_s2: float = 25000.0
@export var sneaky_deceleration_px_s2: float = 55000.0
@export var sneaky_freinage_virage_mult: float = 3.5
@export var sneaky_seuil_arret_px_s: float = 20.0

var allure_actuelle: AllureLibre = AllureLibre.MARCHE

func _ready() -> void:
	allure_actuelle = allure_par_defaut

func traiter_changement_allure() -> void:
	if Input.is_action_just_pressed(action_changer_allure):
		passer_allure_suivante()

func passer_allure_suivante() -> void:
	match allure_actuelle:
		AllureLibre.MARCHE:
			allure_actuelle = AllureLibre.COURSE
		AllureLibre.COURSE:
			allure_actuelle = AllureLibre.SNEAKY
		AllureLibre.SNEAKY:
			allure_actuelle = AllureLibre.MARCHE

func definir_allure(nouvelle_allure: AllureLibre) -> void:
	allure_actuelle = nouvelle_allure

func obtenir_vitesse_max(vitesse_stats: float) -> float:
	return vitesse_stats * _obtenir_multiplicateur_vitesse()

func calculer_vitesse(vitesse_actuelle: Vector2, direction: Vector2, vitesse_stats: float, dt: float) -> Vector2:
	var vitesse_voulue: Vector2 = direction * obtenir_vitesse_max(vitesse_stats)
	var joueur_se_deplace: bool = direction.length_squared() > 0.0001
	var ralentissement: bool = not joueur_se_deplace or vitesse_actuelle.length() > vitesse_voulue.length()
	var taux: float = _obtenir_deceleration() if ralentissement else _obtenir_acceleration()
	if joueur_se_deplace and vitesse_actuelle.length_squared() > 0.0001:
		var opposition: float = maxf(0.0, -vitesse_actuelle.normalized().dot(direction.normalized()))
		taux *= lerpf(1.0, _obtenir_freinage_virage(), opposition)
	var nouvelle_vitesse: Vector2 = vitesse_actuelle.move_toward(vitesse_voulue, taux * dt)
	if not joueur_se_deplace and nouvelle_vitesse.length() < _obtenir_seuil_arret():
		return Vector2.ZERO
	return nouvelle_vitesse

func _obtenir_multiplicateur_vitesse() -> float:
	match allure_actuelle:
		AllureLibre.COURSE:
			return course_multiplicateur_vitesse
		AllureLibre.SNEAKY:
			return sneaky_multiplicateur_vitesse
		_:
			return marche_multiplicateur_vitesse

func _obtenir_acceleration() -> float:
	match allure_actuelle:
		AllureLibre.COURSE:
			return course_acceleration_px_s2
		AllureLibre.SNEAKY:
			return sneaky_acceleration_px_s2
		_:
			return marche_acceleration_px_s2

func _obtenir_deceleration() -> float:
	match allure_actuelle:
		AllureLibre.COURSE:
			return course_deceleration_px_s2
		AllureLibre.SNEAKY:
			return sneaky_deceleration_px_s2
		_:
			return marche_deceleration_px_s2

func _obtenir_freinage_virage() -> float:
	match allure_actuelle:
		AllureLibre.COURSE:
			return maxf(course_freinage_virage_mult, 1.0)
		AllureLibre.SNEAKY:
			return maxf(sneaky_freinage_virage_mult, 1.0)
		_:
			return maxf(marche_freinage_virage_mult, 1.0)

func _obtenir_seuil_arret() -> float:
	match allure_actuelle:
		AllureLibre.COURSE:
			return course_seuil_arret_px_s
		AllureLibre.SNEAKY:
			return sneaky_seuil_arret_px_s
		_:
			return marche_seuil_arret_px_s

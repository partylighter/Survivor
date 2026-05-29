extends Node
class_name GestionnaireOrientationCorps
signal visibilite_corps_modifiee
@export_group("Animation")
@export var animation_corps_active: bool = true
@export var debug_animation_corps: bool = false
@export var mains_visibles: bool = true:
	set(valeur):
		mains_visibles = valeur
		visibilite_corps_modifiee.emit()
@export_group("Direction")
@export var direction_jambes_defaut: Vector2 = Vector2.DOWN
@export var direction_visee_defaut: Vector2 = Vector2.DOWN
@export var jambes_face_visee_en_reculons: bool = true
@export var jambes_suivent_visee_a_l_arret: bool = true
@export_range(20.0, 120.0, 1.0, "degrees") var angle_debut_pivot_jambes_deg: float = 75.0
@export_range(0.0, 90.0, 1.0, "degrees") var angle_torsion_apres_pivot_jambes_deg: float = 35.0
@export_range(20.0, 120.0, 1.0, "degrees") var angle_torsion_max_buste_deg: float = 80.0
@export_range(0.0, 90.0, 1.0, "degrees") var angle_torsion_max_tete_deg: float = 35.0
@export_range(90.0, 180.0, 1.0, "degrees") var angle_debut_reculons_deg: float = 130.0
@export_range(90.0, 180.0, 1.0, "degrees") var angle_fin_reculons_deg: float = 105.0
@export_range(0.0, 1.0, 0.01) var vitesse_min_animation_deplacement: float = 0.04
@export_group("Demembrement visuel")
@export var tete_demembree: bool = false:
	set(valeur):
		tete_demembree = valeur
		visibilite_corps_modifiee.emit()
@export var torse_demembre: bool = false:
	set(valeur):
		torse_demembre = valeur
		visibilite_corps_modifiee.emit()
@export var jambe_gauche_demembree: bool = false:
	set(valeur):
		jambe_gauche_demembree = valeur
		visibilite_corps_modifiee.emit()
@export var jambe_droite_demembree: bool = false:
	set(valeur):
		jambe_droite_demembree = valeur
		visibilite_corps_modifiee.emit()
@export var main_gauche_demembree: bool = false:
	set(valeur):
		main_gauche_demembree = valeur
		visibilite_corps_modifiee.emit()
@export var main_droite_demembree: bool = false:
	set(valeur):
		main_droite_demembree = valeur
		visibilite_corps_modifiee.emit()
var direction_jambes: Vector2 = Vector2.DOWN
var direction_buste: Vector2 = Vector2.DOWN
var direction_tete: Vector2 = Vector2.DOWN
var direction_visee: Vector2 = Vector2.DOWN
var reculons_animation_actif: bool = false
func _ready() -> void:
	reinitialiser()
func reinitialiser() -> void:
	direction_jambes = _normaliser_direction_ou_bas(direction_jambes_defaut)
	direction_buste = direction_jambes
	direction_tete = direction_jambes
	direction_visee = _normaliser_direction_ou_bas(direction_visee_defaut)
func mettre_a_jour(vitesse: Vector2, vitesse_reference: float, nouvelle_direction_visee: Vector2) -> void:
	if nouvelle_direction_visee.length_squared() > 0.0001:
		direction_visee = nouvelle_direction_visee.normalized()
	var direction_deplacement: Vector2 = _get_direction_deplacement(vitesse, vitesse_reference)
	reculons_animation_actif = _doit_utiliser_animation_reculons(direction_deplacement, direction_visee)
	if direction_deplacement != Vector2.ZERO:
		if reculons_animation_actif:
			direction_jambes = direction_visee
		else:
			direction_jambes = direction_deplacement
	elif jambes_suivent_visee_a_l_arret:
		_mettre_a_jour_direction_jambes_a_l_arret(direction_visee)
	direction_buste = _limiter_direction_buste(direction_visee)
	direction_tete = _limiter_direction_tete(direction_visee, direction_buste)
func _get_direction_deplacement(vitesse: Vector2, vitesse_reference: float) -> Vector2:
	var vitesse_min: float = maxf(vitesse_reference, 1.0) * vitesse_min_animation_deplacement
	if vitesse.length_squared() > vitesse_min * vitesse_min:
		return vitesse.normalized()
	return Vector2.ZERO
func _mettre_a_jour_direction_jambes_a_l_arret(direction_cible: Vector2) -> void:
	if direction_cible.length_squared() <= 0.0001:
		return
	if direction_jambes.length_squared() <= 0.0001:
		direction_jambes = direction_cible
		return
	var angle_ecart: float = direction_jambes.normalized().angle_to(direction_cible.normalized())
	var angle_debut_pivot: float = deg_to_rad(angle_debut_pivot_jambes_deg)
	if absf(angle_ecart) <= angle_debut_pivot:
		return
	var angle_torsion: float = deg_to_rad(minf(angle_torsion_apres_pivot_jambes_deg, angle_debut_pivot_jambes_deg))
	direction_jambes = direction_cible.rotated(-signf(angle_ecart) * angle_torsion).normalized()
func _limiter_direction_buste(direction_cible: Vector2) -> Vector2:
	if direction_cible.length_squared() <= 0.0001 or direction_jambes.length_squared() <= 0.0001:
		return direction_cible
	var direction_jambes_normale: Vector2 = direction_jambes.normalized()
	var angle_ecart: float = direction_jambes_normale.angle_to(direction_cible.normalized())
	var angle_max: float = deg_to_rad(angle_torsion_max_buste_deg)
	if absf(angle_ecart) <= angle_max:
		return direction_cible
	return direction_jambes_normale.rotated(signf(angle_ecart) * angle_max).normalized()
func _limiter_direction_tete(direction_cible: Vector2, direction_buste_cible: Vector2) -> Vector2:
	if direction_cible.length_squared() <= 0.0001 or direction_buste_cible.length_squared() <= 0.0001:
		return direction_cible
	var direction_buste_normale: Vector2 = direction_buste_cible.normalized()
	var angle_ecart: float = direction_buste_normale.angle_to(direction_cible.normalized())
	var angle_max: float = deg_to_rad(angle_torsion_max_tete_deg)
	if absf(angle_ecart) <= angle_max:
		return direction_cible
	return direction_buste_normale.rotated(signf(angle_ecart) * angle_max).normalized()
func _doit_utiliser_animation_reculons(direction_deplacement: Vector2, direction_cible: Vector2) -> bool:
	if not jambes_face_visee_en_reculons:
		return false
	if direction_deplacement == Vector2.ZERO or direction_cible.length_squared() <= 0.0001:
		return false
	var angle_actuel: float = rad_to_deg(absf(direction_deplacement.angle_to(direction_cible.normalized())))
	if reculons_animation_actif:
		return angle_actuel > angle_fin_reculons_deg
	return angle_actuel >= angle_debut_reculons_deg
func _normaliser_direction_ou_bas(direction: Vector2) -> Vector2:
	if direction.length_squared() <= 0.0001:
		return Vector2.DOWN
	return direction.normalized()

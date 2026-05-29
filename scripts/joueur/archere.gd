extends Player
class_name Archere
const DIRECTIONS_ANIMATION: Dictionary = {
	&"bas": Vector2(0, 1),
	&"bas_droite": Vector2(1, 1),
	&"droite": Vector2(1, 0),
	&"haut_droite": Vector2(1, -1),
	&"haut": Vector2(0, -1),
	&"haut_gauche": Vector2(-1, -1),
	&"gauche": Vector2(-1, 0),
	&"bas_gauche": Vector2(-1, 1)
}
const ANIMATIONS_JAMBE_DROITE: Dictionary = {
	&"bas": &"jambe droite bas",
	&"bas_droite": &"jambe droite bas droite",
	&"droite": &"jambe droite droite",
	&"haut_droite": &"jambe droite haut droite",
	&"haut": &"jambe droite haute",
	&"haut_gauche": &"jambe droite haut gauche",
	&"gauche": &"jambe droite gauche",
	&"bas_gauche": &"jambe droite bas gauche"
}
const ANIMATIONS_JAMBE_GAUCHE: Dictionary = {
	&"bas": &"jambe gauche bas",
	&"bas_droite": &"jambe gauche droite bas",
	&"droite": &"jambe gauche droite",
	&"haut_droite": &"jambe gauche haut droite",
	&"haut": &"jambe gauche haut",
	&"haut_gauche": &"jambe gauche haut gauche",
	&"gauche": &"jambe gauche gauche",
	&"bas_gauche": &"jambe gauche bas gauche"
}
const ANIMATIONS_TORSE: Dictionary = {
	&"bas": &"torse nactif bas",
	&"bas_droite": &"torse inactif bas droite",
	&"droite": &"torse inactif droite",
	&"haut_droite": &"torse inactif haut droite",
	&"haut": &"torse inactif haut",
	&"haut_gauche": &"torse inactif haut gauche",
	&"gauche": &"torse inactif gauche",
	&"bas_gauche": &"torse inactif bas gauche"
}
const ANIMATIONS_TETE: Dictionary = {
	&"bas": &"tete inactif bas",
	&"bas_droite": &"tete inactif bas droite",
	&"droite": &"tete inactif droite",
	&"haut_droite": &"tete inactif haut droite",
	&"haut": &"tete inactif haut",
	&"haut_gauche": &"tete inactif haut gauche",
	&"gauche": &"tete inactif gauche",
	&"bas_gauche": &"tete inactif bas gauche"
}
const PISTE_JAMBE_GAUCHE: NodePath = NodePath("../squelette du corps/jambe gauche:frame")
const PISTE_TORSE: NodePath = NodePath("../squelette du corps/torse:frame")
const PISTE_TETE: NodePath = NodePath("../squelette du corps/tete:frame")
@export_group("Archere")
@export var identifiant_personnage: StringName = &"archere"
@export var animation_archere_active: bool = true
@export var debug_animation_archere: bool = false
@export var mains_visibles: bool = true:
	set(valeur):
		mains_visibles = valeur
		_appliquer_visibilite_mains()
@export_group("Demembrement visuel")
@export var tete_demembree: bool = false:
	set(valeur):
		tete_demembree = valeur
		_appliquer_demembrement_visuel()
@export var torse_demembre: bool = false:
	set(valeur):
		torse_demembre = valeur
		_appliquer_demembrement_visuel()
@export var jambe_gauche_demembree: bool = false:
	set(valeur):
		jambe_gauche_demembree = valeur
		_appliquer_demembrement_visuel()
@export var jambe_droite_demembree: bool = false:
	set(valeur):
		jambe_droite_demembree = valeur
		_appliquer_demembrement_visuel()
@export var main_gauche_demembree: bool = false:
	set(valeur):
		main_gauche_demembree = valeur
		_appliquer_demembrement_visuel()
@export var main_droite_demembree: bool = false:
	set(valeur):
		main_droite_demembree = valeur
		_appliquer_demembrement_visuel()
@export_group("Animation archere")
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
@onready var arbre_animation: AnimationTree = get_node_or_null("AnimationTree") as AnimationTree
@onready var tete_archere: CanvasItem = get_node_or_null("squelette du corps/tete") as CanvasItem
@onready var torse_archere: CanvasItem = get_node_or_null("squelette du corps/torse") as CanvasItem
@onready var jambe_gauche_archere: CanvasItem = get_node_or_null("squelette du corps/jambe gauche") as CanvasItem
@onready var jambe_droite_archere: CanvasItem = get_node_or_null("squelette du corps/jambe droite") as CanvasItem
@onready var main_gauche: CanvasItem = get_node_or_null("GestionnaireArme/SocketGauche/spritemaingauche") as CanvasItem
@onready var main_droite: CanvasItem = get_node_or_null("GestionnaireArme/SocketDroite/spritemaindroite") as CanvasItem
var _direction_jambes: Vector2 = Vector2.DOWN
var _direction_visee: Vector2 = Vector2.DOWN
var _reculons_animation_actif: bool = false
var _debug_nom_direction_jambes: StringName = &""
var _debug_nom_direction_visee: StringName = &""
func _ready() -> void:
	_direction_jambes = _normaliser_direction_ou_bas(direction_jambes_defaut)
	_direction_visee = _normaliser_direction_ou_bas(direction_visee_defaut)
	super()
	add_to_group("personnage_archere")
	_appliquer_visibilite_mains()
	_appliquer_demembrement_visuel()
	_configurer_arbre_animation()
func _physics_process(delta: float) -> void:
	super(delta)
	_mettre_a_jour_arbre_animation()
func get_identifiant_personnage() -> StringName:
	return identifiant_personnage
func _appliquer_visibilite_mains() -> void:
	if main_gauche != null:
		main_gauche.visible = mains_visibles and not main_gauche_demembree
	if main_droite != null:
		main_droite.visible = mains_visibles and not main_droite_demembree
func _appliquer_demembrement_visuel() -> void:
	_appliquer_visibilite_membre(tete_archere, tete_demembree)
	_appliquer_visibilite_membre(torse_archere, torse_demembre)
	_appliquer_visibilite_membre(jambe_gauche_archere, jambe_gauche_demembree)
	_appliquer_visibilite_membre(jambe_droite_archere, jambe_droite_demembree)
	_appliquer_visibilite_mains()
func _appliquer_visibilite_membre(membre: CanvasItem, est_demembre: bool) -> void:
	if membre == null:
		return
	membre.visible = not est_demembre
func demembrer_membre(nom_membre: StringName, demembre: bool = true) -> void:
	match nom_membre:
		&"tete":
			tete_demembree = demembre
		&"torse":
			torse_demembre = demembre
		&"jambe_gauche":
			jambe_gauche_demembree = demembre
		&"jambe_droite":
			jambe_droite_demembree = demembre
		&"main_gauche":
			main_gauche_demembree = demembre
		&"main_droite":
			main_droite_demembree = demembre
		_:
			push_warning("Membre archere inconnu: %s" % nom_membre)
func reinitialiser_demembrement() -> void:
	tete_demembree = false
	torse_demembre = false
	jambe_gauche_demembree = false
	jambe_droite_demembree = false
	main_gauche_demembree = false
	main_droite_demembree = false
func _configurer_arbre_animation() -> void:
	if arbre_animation == null or not animation_archere_active:
		return
	var racine_animation := AnimationNodeBlendTree.new()
	racine_animation.add_node(&"jambe_droite", _creer_espace_directionnel(ANIMATIONS_JAMBE_DROITE), Vector2(0, 0))
	racine_animation.add_node(&"jambe_gauche", _creer_espace_directionnel(ANIMATIONS_JAMBE_GAUCHE), Vector2(0, 140))
	racine_animation.add_node(&"torse", _creer_espace_directionnel(ANIMATIONS_TORSE), Vector2(0, 280))
	racine_animation.add_node(&"tete", _creer_espace_directionnel(ANIMATIONS_TETE), Vector2(0, 420))
	racine_animation.add_node(&"melange_jambe_gauche", _creer_melange_filtre(PISTE_JAMBE_GAUCHE), Vector2(300, 80))
	racine_animation.add_node(&"melange_torse", _creer_melange_filtre(PISTE_TORSE), Vector2(560, 180))
	racine_animation.add_node(&"melange_tete", _creer_melange_filtre(PISTE_TETE), Vector2(820, 280))
	racine_animation.connect_node(&"melange_jambe_gauche", 0, &"jambe_droite")
	racine_animation.connect_node(&"melange_jambe_gauche", 1, &"jambe_gauche")
	racine_animation.connect_node(&"melange_torse", 0, &"melange_jambe_gauche")
	racine_animation.connect_node(&"melange_torse", 1, &"torse")
	racine_animation.connect_node(&"melange_tete", 0, &"melange_torse")
	racine_animation.connect_node(&"melange_tete", 1, &"tete")
	racine_animation.connect_node(&"output", 0, &"melange_tete")
	arbre_animation.tree_root = racine_animation
	arbre_animation.active = true
	arbre_animation.set("parameters/melange_jambe_gauche/blend_amount", 1.0)
	arbre_animation.set("parameters/melange_torse/blend_amount", 1.0)
	arbre_animation.set("parameters/melange_tete/blend_amount", 1.0)
	_mettre_a_jour_arbre_animation()
func _creer_espace_directionnel(animations_par_direction: Dictionary) -> AnimationNodeBlendSpace2D:
	var espace := AnimationNodeBlendSpace2D.new()
	espace.blend_mode = AnimationNodeBlendSpace2D.BLEND_MODE_DISCRETE_CARRY
	espace.min_space = Vector2(-1, -1)
	espace.max_space = Vector2(1, 1)
	espace.snap = Vector2(1, 1)
	for nom_direction in DIRECTIONS_ANIMATION.keys():
		var animation := AnimationNodeAnimation.new()
		animation.animation = animations_par_direction[nom_direction]
		espace.add_blend_point(animation, DIRECTIONS_ANIMATION[nom_direction], -1, nom_direction)
	return espace
func _creer_melange_filtre(chemin_piste: NodePath) -> AnimationNodeBlend2:
	var melange := AnimationNodeBlend2.new()
	melange.filter_enabled = true
	melange.set_filter_path(chemin_piste, true)
	return melange
func _mettre_a_jour_arbre_animation() -> void:
	if arbre_animation == null or not arbre_animation.active:
		return
	var direction_deplacement := Vector2.ZERO
	var vitesse_reference := 1.0
	if stats != null:
		vitesse_reference = maxf(stats.get_vitesse_effective(), 1.0)
	var vitesse_min := vitesse_reference * vitesse_min_animation_deplacement
	if velocity.length_squared() > vitesse_min * vitesse_min:
		direction_deplacement = velocity.normalized()
	var direction_souris := get_global_mouse_position() - global_position
	if direction_souris.length_squared() > 1.0:
		_direction_visee = direction_souris.normalized()
	_reculons_animation_actif = _doit_utiliser_animation_reculons(direction_deplacement, _direction_visee)
	if direction_deplacement != Vector2.ZERO:
		if _reculons_animation_actif:
			_direction_jambes = _direction_visee
		else:
			_direction_jambes = direction_deplacement
	elif jambes_suivent_visee_a_l_arret:
		_mettre_a_jour_direction_jambes_a_l_arret(_direction_visee)
	var direction_buste: Vector2 = _limiter_direction_buste(_direction_visee)
	var direction_tete: Vector2 = _limiter_direction_tete(_direction_visee, direction_buste)
	arbre_animation.set("parameters/jambe_droite/blend_position", _direction_jambes)
	arbre_animation.set("parameters/jambe_gauche/blend_position", _direction_jambes)
	arbre_animation.set("parameters/torse/blend_position", direction_buste)
	arbre_animation.set("parameters/tete/blend_position", direction_tete)
	_debug_print_directions_animation()
func _mettre_a_jour_direction_jambes_a_l_arret(direction_visee: Vector2) -> void:
	if direction_visee.length_squared() <= 0.0001:
		return
	if _direction_jambes.length_squared() <= 0.0001:
		_direction_jambes = direction_visee
		return
	var angle_ecart: float = _direction_jambes.normalized().angle_to(direction_visee.normalized())
	var angle_debut_pivot: float = deg_to_rad(angle_debut_pivot_jambes_deg)
	if absf(angle_ecart) <= angle_debut_pivot:
		return
	var angle_torsion: float = deg_to_rad(minf(angle_torsion_apres_pivot_jambes_deg, angle_debut_pivot_jambes_deg))
	_direction_jambes = direction_visee.rotated(-signf(angle_ecart) * angle_torsion).normalized()
func _limiter_direction_buste(direction_visee: Vector2) -> Vector2:
	if direction_visee.length_squared() <= 0.0001 or _direction_jambes.length_squared() <= 0.0001:
		return direction_visee
	var direction_jambes: Vector2 = _direction_jambes.normalized()
	var angle_ecart: float = direction_jambes.angle_to(direction_visee.normalized())
	var angle_max: float = deg_to_rad(angle_torsion_max_buste_deg)
	if absf(angle_ecart) <= angle_max:
		return direction_visee
	return direction_jambes.rotated(signf(angle_ecart) * angle_max).normalized()
func _limiter_direction_tete(direction_visee: Vector2, direction_buste: Vector2) -> Vector2:
	if direction_visee.length_squared() <= 0.0001 or direction_buste.length_squared() <= 0.0001:
		return direction_visee
	var direction_buste_normale: Vector2 = direction_buste.normalized()
	var angle_ecart: float = direction_buste_normale.angle_to(direction_visee.normalized())
	var angle_max: float = deg_to_rad(angle_torsion_max_tete_deg)
	if absf(angle_ecart) <= angle_max:
		return direction_visee
	return direction_buste_normale.rotated(signf(angle_ecart) * angle_max).normalized()
func _debug_print_directions_animation() -> void:
	if not debug_animation_archere:
		return
	var nom_direction_jambes := _get_nom_direction_animation(_direction_jambes)
	var nom_direction_visee := _get_nom_direction_animation(_direction_visee)
	if nom_direction_jambes == _debug_nom_direction_jambes and nom_direction_visee == _debug_nom_direction_visee:
		return
	_debug_nom_direction_jambes = nom_direction_jambes
	_debug_nom_direction_visee = nom_direction_visee
	print("[archere animation] jambes=", nom_direction_jambes, " pos=", _direction_jambes, " | torse/tete=", nom_direction_visee, " pos=", _direction_visee, " | reculons=", _reculons_animation_actif)
func _doit_utiliser_animation_reculons(direction_deplacement: Vector2, direction_visee: Vector2) -> bool:
	if not jambes_face_visee_en_reculons:
		return false
	if direction_deplacement == Vector2.ZERO or direction_visee.length_squared() <= 0.0001:
		return false
	var angle_actuel := rad_to_deg(absf(direction_deplacement.angle_to(direction_visee.normalized())))
	if _reculons_animation_actif:
		return angle_actuel > angle_fin_reculons_deg
	return angle_actuel >= angle_debut_reculons_deg
func _normaliser_direction_ou_bas(direction: Vector2) -> Vector2:
	if direction.length_squared() <= 0.0001:
		return Vector2.DOWN
	return direction.normalized()
func _get_nom_direction_animation(direction: Vector2) -> StringName:
	if direction.length_squared() <= 0.0001:
		return &"aucune"
	var direction_normale := direction.normalized()
	var meilleur_nom: StringName = &"bas"
	var meilleur_score: float = -INF
	for nom_direction in DIRECTIONS_ANIMATION.keys():
		var score: float = direction_normale.dot(DIRECTIONS_ANIMATION[nom_direction].normalized())
		if score > meilleur_score:
			meilleur_score = score
			meilleur_nom = nom_direction
	return meilleur_nom

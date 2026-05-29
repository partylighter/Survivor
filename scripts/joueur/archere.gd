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
@export_node_path("GestionnaireOrientationCorps") var chemin_gestionnaire_orientation_corps: NodePath = NodePath("GestionnaireOrientationCorps")
@onready var arbre_animation: AnimationTree = get_node_or_null("AnimationTree") as AnimationTree
@onready var gestionnaire_orientation_corps: GestionnaireOrientationCorps = get_node_or_null(chemin_gestionnaire_orientation_corps) as GestionnaireOrientationCorps
@onready var tete_archere: CanvasItem = get_node_or_null("squelette du corps/tete") as CanvasItem
@onready var torse_archere: CanvasItem = get_node_or_null("squelette du corps/torse") as CanvasItem
@onready var jambe_gauche_archere: CanvasItem = get_node_or_null("squelette du corps/jambe gauche") as CanvasItem
@onready var jambe_droite_archere: CanvasItem = get_node_or_null("squelette du corps/jambe droite") as CanvasItem
@onready var main_gauche: CanvasItem = get_node_or_null("GestionnaireArme/SocketGauche/spritemaingauche") as CanvasItem
@onready var main_droite: CanvasItem = get_node_or_null("GestionnaireArme/SocketDroite/spritemaindroite") as CanvasItem
var _debug_nom_direction_jambes: StringName = &""
var _debug_nom_direction_visee: StringName = &""
func _ready() -> void:
	super()
	add_to_group("personnage_archere")
	if gestionnaire_orientation_corps != null and not gestionnaire_orientation_corps.visibilite_corps_modifiee.is_connected(_appliquer_demembrement_visuel):
		gestionnaire_orientation_corps.visibilite_corps_modifiee.connect(_appliquer_demembrement_visuel)
	_appliquer_visibilite_mains()
	_appliquer_demembrement_visuel()
	_configurer_arbre_animation()
func _physics_process(delta: float) -> void:
	super(delta)
	_mettre_a_jour_arbre_animation()
func get_identifiant_personnage() -> StringName:
	return identifiant_personnage
func _appliquer_visibilite_mains() -> void:
	if gestionnaire_orientation_corps == null:
		return
	if main_gauche != null:
		main_gauche.visible = gestionnaire_orientation_corps.mains_visibles and not gestionnaire_orientation_corps.main_gauche_demembree
	if main_droite != null:
		main_droite.visible = gestionnaire_orientation_corps.mains_visibles and not gestionnaire_orientation_corps.main_droite_demembree
func _appliquer_demembrement_visuel() -> void:
	if gestionnaire_orientation_corps == null:
		return
	_appliquer_visibilite_membre(tete_archere, gestionnaire_orientation_corps.tete_demembree)
	_appliquer_visibilite_membre(torse_archere, gestionnaire_orientation_corps.torse_demembre)
	_appliquer_visibilite_membre(jambe_gauche_archere, gestionnaire_orientation_corps.jambe_gauche_demembree)
	_appliquer_visibilite_membre(jambe_droite_archere, gestionnaire_orientation_corps.jambe_droite_demembree)
	_appliquer_visibilite_mains()
func _appliquer_visibilite_membre(membre: CanvasItem, est_demembre: bool) -> void:
	if membre == null:
		return
	membre.visible = not est_demembre
func demembrer_membre(nom_membre: StringName, demembre: bool = true) -> void:
	if gestionnaire_orientation_corps == null:
		return
	match nom_membre:
		&"tete":
			gestionnaire_orientation_corps.tete_demembree = demembre
		&"torse":
			gestionnaire_orientation_corps.torse_demembre = demembre
		&"jambe_gauche":
			gestionnaire_orientation_corps.jambe_gauche_demembree = demembre
		&"jambe_droite":
			gestionnaire_orientation_corps.jambe_droite_demembree = demembre
		&"main_gauche":
			gestionnaire_orientation_corps.main_gauche_demembree = demembre
		&"main_droite":
			gestionnaire_orientation_corps.main_droite_demembree = demembre
		_:
			push_warning("Membre archere inconnu: %s" % nom_membre)
			return
	_appliquer_demembrement_visuel()
func reinitialiser_demembrement() -> void:
	if gestionnaire_orientation_corps == null:
		return
	gestionnaire_orientation_corps.tete_demembree = false
	gestionnaire_orientation_corps.torse_demembre = false
	gestionnaire_orientation_corps.jambe_gauche_demembree = false
	gestionnaire_orientation_corps.jambe_droite_demembree = false
	gestionnaire_orientation_corps.main_gauche_demembree = false
	gestionnaire_orientation_corps.main_droite_demembree = false
	_appliquer_demembrement_visuel()
func _configurer_arbre_animation() -> void:
	if arbre_animation == null or gestionnaire_orientation_corps == null or not gestionnaire_orientation_corps.animation_corps_active:
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
	if gestionnaire_orientation_corps == null:
		return
	var vitesse_reference := 1.0
	if stats != null:
		vitesse_reference = maxf(stats.get_vitesse_effective(), 1.0)
	var direction_souris: Vector2 = get_global_mouse_position() - global_position
	if direction_souris.length_squared() > 1.0:
		gestionnaire_orientation_corps.mettre_a_jour(velocity, vitesse_reference, direction_souris.normalized())
	else:
		gestionnaire_orientation_corps.mettre_a_jour(velocity, vitesse_reference, Vector2.ZERO)
	arbre_animation.set("parameters/jambe_droite/blend_position", gestionnaire_orientation_corps.direction_jambes)
	arbre_animation.set("parameters/jambe_gauche/blend_position", gestionnaire_orientation_corps.direction_jambes)
	arbre_animation.set("parameters/torse/blend_position", gestionnaire_orientation_corps.direction_buste)
	arbre_animation.set("parameters/tete/blend_position", gestionnaire_orientation_corps.direction_tete)
	_debug_print_directions_animation()
func _debug_print_directions_animation() -> void:
	if gestionnaire_orientation_corps == null or not gestionnaire_orientation_corps.debug_animation_corps:
		return
	var nom_direction_jambes := _get_nom_direction_animation(gestionnaire_orientation_corps.direction_jambes)
	var nom_direction_visee := _get_nom_direction_animation(gestionnaire_orientation_corps.direction_visee)
	if nom_direction_jambes == _debug_nom_direction_jambes and nom_direction_visee == _debug_nom_direction_visee:
		return
	_debug_nom_direction_jambes = nom_direction_jambes
	_debug_nom_direction_visee = nom_direction_visee
	print("[archere animation] jambes=", nom_direction_jambes, " pos=", gestionnaire_orientation_corps.direction_jambes, " | visee=", nom_direction_visee, " pos=", gestionnaire_orientation_corps.direction_visee, " | reculons=", gestionnaire_orientation_corps.reculons_animation_actif)
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

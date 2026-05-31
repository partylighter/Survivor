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
const PISTE_JAMBE_GAUCHE: NodePath = NodePath("squelette du corps/inactif/inactif jambe gauche:frame")
const PISTE_TORSE: NodePath = NodePath("squelette du corps/inactif/inactif torse:frame")
const PISTE_TETE: NodePath = NodePath("squelette du corps/inactif/inactif tete:frame")
const ANIMATION_ROULADE_BAS: StringName = &"corps entier roulade bas"
const ANIMATION_ROULADE_HAUT: StringName = &"corps entier roulade haut"
const ANIMATION_DASH_AVANT_DROITE: StringName = &"corps entier dash avant droite"
const ANIMATION_DASH_AVANT_GAUCHE: StringName = &"corps entier dash avant gauche"
const ANIMATION_DASH_ARRIERE_DROITE: StringName = &"corps entier dash arriere droite"
const ANIMATION_DASH_ARRIERE_GAUCHE: StringName = &"corps entier dash arriere gauche"
@export_group("Archere")
@export var identifiant_personnage: StringName = &"archere"
@export_node_path("GestionnaireOrientationCorps") var chemin_gestionnaire_orientation_corps: NodePath = NodePath("GestionnaireOrientationCorps")
@onready var arbre_animation: AnimationTree = get_node_or_null("AnimationTree") as AnimationTree
@onready var lecteur_animation: AnimationPlayer = get_node_or_null("AnimationPlayer") as AnimationPlayer
@onready var gestionnaire_orientation_corps: GestionnaireOrientationCorps = get_node_or_null(chemin_gestionnaire_orientation_corps) as GestionnaireOrientationCorps
@onready var inactif_archere: CanvasItem = get_node_or_null("squelette du corps/inactif") as CanvasItem
@onready var animations_dash_archere: CanvasItem = get_node_or_null("squelette du corps/animations dash") as CanvasItem
@onready var tete_archere: CanvasItem = get_node_or_null("squelette du corps/inactif/inactif tete") as CanvasItem
@onready var torse_archere: CanvasItem = get_node_or_null("squelette du corps/inactif/inactif torse") as CanvasItem
@onready var jambe_gauche_archere: CanvasItem = get_node_or_null("squelette du corps/inactif/inactif jambe gauche") as CanvasItem
@onready var jambe_droite_archere: CanvasItem = get_node_or_null("squelette du corps/inactif/inactif jambe droite") as CanvasItem
@onready var corps_entier_roulade_bas: CanvasItem = get_node_or_null("squelette du corps/animations dash/corps entier roulade bas") as CanvasItem
@onready var corps_entier_roulade_haut: AnimatedSprite2D = get_node_or_null("squelette du corps/animations dash/corps entier roulade haut") as AnimatedSprite2D
@onready var corps_entier_dash_avant: AnimatedSprite2D = get_node_or_null("squelette du corps/animations dash/corps entier dash avant") as AnimatedSprite2D
@onready var corps_entier_dash_arriere: AnimatedSprite2D = get_node_or_null("squelette du corps/animations dash/corps entier dash arriere") as AnimatedSprite2D
@onready var main_gauche: CanvasItem = get_node_or_null("GestionnaireArme/SocketGauche/spritemaingauche") as CanvasItem
@onready var main_droite: CanvasItem = get_node_or_null("GestionnaireArme/SocketDroite/spritemaindroite") as CanvasItem
var _debug_nom_direction_jambes: StringName = &""
var _debug_nom_direction_visee: StringName = &""
var _dash_actif_avant: bool = false
var _animation_dash_animation_player_active: bool = false
var _animation_dash_sprite_active: bool = false
var _animation_dash_sprite_temps_restant_s: float = 0.0
func _ready() -> void:
	super()
	add_to_group("personnage_archere")
	if gestionnaire_orientation_corps != null and not gestionnaire_orientation_corps.visibilite_corps_modifiee.is_connected(_appliquer_demembrement_visuel):
		gestionnaire_orientation_corps.visibilite_corps_modifiee.connect(_appliquer_demembrement_visuel)
	if lecteur_animation != null and not lecteur_animation.animation_finished.is_connected(_on_animation_terminee):
		lecteur_animation.animation_finished.connect(_on_animation_terminee)
	_appliquer_visibilite_mains()
	_appliquer_demembrement_visuel()
	_appliquer_visibilite_roulade_bas(false)
	_configurer_arbre_animation()
func _physics_process(delta: float) -> void:
	super(delta)
	_mettre_a_jour_animation_dash(delta)
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
	if _animation_dash_animation_player_active:
		_appliquer_visibilite_roulade_bas(true)
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
func _mettre_a_jour_animation_dash(delta: float) -> void:
	var dash_actif: bool = dash_t_restant_s > 0.0
	if dash_actif and not _dash_actif_avant:
		_jouer_animation_dash_selon_direction()
	_dash_actif_avant = dash_actif
	if _animation_dash_sprite_active:
		_animation_dash_sprite_temps_restant_s = maxf(_animation_dash_sprite_temps_restant_s - delta, 0.0)
		if _animation_dash_sprite_temps_restant_s <= 0.0:
			_terminer_animation_dash_sprite()
func _jouer_animation_dash_selon_direction() -> void:
	if dash_direction.length_squared() <= 0.0001:
		return
	var direction_normale: Vector2 = dash_direction.normalized()
	if _doit_jouer_dash_arriere(direction_normale):
		_jouer_dash_arriere(direction_normale)
	elif direction_normale.dot(Vector2.DOWN) >= 0.7:
		_jouer_roulade_bas()
	elif direction_normale.dot(Vector2.UP) >= 0.7:
		_jouer_roulade_haut()
	elif direction_normale.dot(Vector2.RIGHT) >= 0.7:
		_jouer_dash_avant_lateral(true)
	elif direction_normale.dot(Vector2.LEFT) >= 0.7:
		_jouer_dash_avant_lateral(false)
func _doit_jouer_roulade_bas() -> bool:
	if dash_direction.length_squared() <= 0.0001:
		return false
	return dash_direction.normalized().dot(Vector2.DOWN) >= 0.7
func _jouer_roulade_bas() -> void:
	if lecteur_animation == null or not lecteur_animation.has_animation(ANIMATION_ROULADE_BAS):
		return
	_arreter_animation_dash_sprite_sans_reprise()
	_animation_dash_animation_player_active = true
	if arbre_animation != null:
		arbre_animation.active = false
	_appliquer_visibilite_roulade_bas(true)
	lecteur_animation.play(ANIMATION_ROULADE_BAS)
func _jouer_roulade_haut() -> void:
	_jouer_animation_dash_sprite(corps_entier_roulade_haut, ANIMATION_ROULADE_HAUT)
func _jouer_dash_avant_lateral(vers_droite: bool) -> void:
	var nom_animation: StringName = ANIMATION_DASH_AVANT_DROITE if vers_droite else ANIMATION_DASH_AVANT_GAUCHE
	_jouer_animation_dash_sprite(corps_entier_dash_avant, nom_animation)
func _jouer_dash_arriere(_direction_normale: Vector2) -> void:
	var nom_animation: StringName = ANIMATION_DASH_ARRIERE_DROITE if _get_direction_visee_normale().x > 0.0 else ANIMATION_DASH_ARRIERE_GAUCHE
	_jouer_animation_dash_sprite(corps_entier_dash_arriere, nom_animation)
func _jouer_animation_dash_sprite(sprite: AnimatedSprite2D, nom_animation: StringName) -> void:
	if not _animated_sprite_a_animation(sprite, nom_animation):
		return
	_animation_dash_animation_player_active = false
	if lecteur_animation != null:
		lecteur_animation.stop()
	_animation_dash_sprite_active = true
	_animation_dash_sprite_temps_restant_s = _calculer_duree_animation_sprite(sprite, nom_animation)
	if arbre_animation != null:
		arbre_animation.active = false
	_appliquer_visibilite_animation_dash_sprite()
	_jouer_animation_sprite(sprite, nom_animation)
func _doit_jouer_dash_arriere(direction_dash_normale: Vector2) -> bool:
	var direction_visee_normale: Vector2 = _get_direction_visee_normale()
	if direction_visee_normale.length_squared() <= 0.0001:
		return false
	if absf(direction_visee_normale.x) < 0.7 or absf(direction_visee_normale.y) > 0.45:
		return false
	return direction_dash_normale.dot(direction_visee_normale) <= -0.7
func _get_direction_visee_normale() -> Vector2:
	if gestionnaire_orientation_corps != null and gestionnaire_orientation_corps.direction_visee.length_squared() > 0.0001:
		return gestionnaire_orientation_corps.direction_visee.normalized()
	var direction_souris: Vector2 = get_global_mouse_position() - global_position
	if direction_souris.length_squared() > 1.0:
		return direction_souris.normalized()
	return Vector2.ZERO
func _animated_sprite_a_animation(sprite: AnimatedSprite2D, nom_animation: StringName) -> bool:
	return sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(nom_animation)
func _jouer_animation_sprite(sprite: AnimatedSprite2D, nom_animation: StringName) -> void:
	if sprite == null:
		return
	sprite.visible = true
	sprite.play(nom_animation)
func _calculer_duree_animation_sprite(sprite: AnimatedSprite2D, nom_animation: StringName) -> float:
	if not _animated_sprite_a_animation(sprite, nom_animation):
		return 0.0
	var images: int = sprite.sprite_frames.get_frame_count(nom_animation)
	var vitesse: float = maxf(sprite.sprite_frames.get_animation_speed(nom_animation), 0.001)
	return float(images) / vitesse
func _terminer_animation_dash_sprite() -> void:
	_animation_dash_sprite_active = false
	_arreter_animation_dash_sprite_sans_reprise()
	_appliquer_visibilite_animation_dash_sprite()
	if arbre_animation != null:
		arbre_animation.active = true
		_configurer_arbre_animation()
func _arreter_animation_dash_sprite_sans_reprise() -> void:
	_animation_dash_sprite_active = false
	_animation_dash_sprite_temps_restant_s = 0.0
	_arreter_animation_sprite(corps_entier_roulade_haut)
	_arreter_animation_sprite(corps_entier_dash_avant)
	_arreter_animation_sprite(corps_entier_dash_arriere)
func _arreter_animation_sprite(sprite: AnimatedSprite2D) -> void:
	if sprite == null:
		return
	sprite.stop()
	sprite.visible = false
func _on_animation_terminee(nom_animation: StringName) -> void:
	if nom_animation != ANIMATION_ROULADE_BAS:
		return
	if _animation_dash_sprite_active:
		return
	_animation_dash_animation_player_active = false
	_appliquer_visibilite_roulade_bas(false)
	if arbre_animation != null:
		arbre_animation.active = true
		_configurer_arbre_animation()
func _appliquer_visibilite_roulade_bas(actif: bool) -> void:
	if inactif_archere != null:
		inactif_archere.visible = not actif
	if animations_dash_archere != null:
		animations_dash_archere.visible = actif
	_appliquer_visibilite_membre(torse_archere, actif or (gestionnaire_orientation_corps != null and gestionnaire_orientation_corps.torse_demembre))
	_appliquer_visibilite_membre(tete_archere, actif or (gestionnaire_orientation_corps != null and gestionnaire_orientation_corps.tete_demembree))
	_appliquer_visibilite_membre(jambe_gauche_archere, actif or (gestionnaire_orientation_corps != null and gestionnaire_orientation_corps.jambe_gauche_demembree))
	_appliquer_visibilite_membre(jambe_droite_archere, actif or (gestionnaire_orientation_corps != null and gestionnaire_orientation_corps.jambe_droite_demembree))
	if main_gauche != null:
		main_gauche.visible = not actif and gestionnaire_orientation_corps != null and gestionnaire_orientation_corps.mains_visibles and not gestionnaire_orientation_corps.main_gauche_demembree
	if main_droite != null:
		main_droite.visible = not actif and gestionnaire_orientation_corps != null and gestionnaire_orientation_corps.mains_visibles and not gestionnaire_orientation_corps.main_droite_demembree
	if corps_entier_roulade_bas != null:
		corps_entier_roulade_bas.visible = actif
	if corps_entier_roulade_haut != null:
		corps_entier_roulade_haut.visible = false
	if corps_entier_dash_avant != null:
		corps_entier_dash_avant.visible = false
	if corps_entier_dash_arriere != null:
		corps_entier_dash_arriere.visible = false
func _appliquer_visibilite_animation_dash_sprite() -> void:
	if inactif_archere != null:
		inactif_archere.visible = not _animation_dash_sprite_active
	if animations_dash_archere != null:
		animations_dash_archere.visible = _animation_dash_sprite_active
	if corps_entier_roulade_bas != null:
		corps_entier_roulade_bas.visible = false
	if corps_entier_roulade_haut != null:
		corps_entier_roulade_haut.visible = false
	if corps_entier_dash_avant != null:
		corps_entier_dash_avant.visible = false
	if corps_entier_dash_arriere != null:
		corps_entier_dash_arriere.visible = false
func _configurer_arbre_animation() -> void:
	if arbre_animation == null or gestionnaire_orientation_corps == null or not gestionnaire_orientation_corps.animation_corps_active:
		return
	var racine_animation := AnimationNodeBlendTree.new()
	arbre_animation.root_node = NodePath("..")
	arbre_animation.anim_player = NodePath("../AnimationPlayer")
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
		var animation := _creer_animation_simple(animations_par_direction[nom_direction])
		espace.add_blend_point(animation, DIRECTIONS_ANIMATION[nom_direction], -1, nom_direction)
	return espace
func _creer_animation_simple(nom_animation: StringName) -> AnimationNodeAnimation:
	var animation := AnimationNodeAnimation.new()
	animation.animation = nom_animation
	return animation
func _creer_melange_filtre(chemin_piste: NodePath) -> AnimationNodeBlend2:
	var melange := AnimationNodeBlend2.new()
	melange.filter_enabled = true
	melange.set_filter_path(chemin_piste, true)
	return melange
func _mettre_a_jour_arbre_animation() -> void:
	if arbre_animation == null or not arbre_animation.active:
		return
	if _animation_dash_animation_player_active or _animation_dash_sprite_active:
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

extends EnemyBOSS
class_name BossZone1

signal combat_engage(cible: Node2D)
signal combat_desengage(cible: Node2D)

@export var nom_boss: String = "Gardien de zone 1"

@export_group("Territoire")
@export var rayon_activite_px: float = 900.0
@export var distance_arret_spawn_px: float = 12.0
@export var delai_retour_spawn_s: float = 0.7

@export_group("Attaques")
@export var attaque_base_degats: int = 12
@export var attaque_base_portee_px: float = 230.0
@export var attaque_base_recul: float = 320.0
@export var attaque_base_windup_s: float = 0.22
@export var attaque_base_recovery_s: float = 0.28
@export var attaque_base_cooldown_s: float = 1.1
@export var attaque_lourde_degats: int = 24
@export var attaque_lourde_rayon_px: float = 340.0
@export var attaque_lourde_recul: float = 850.0
@export var attaque_lourde_windup_s: float = 0.65
@export var attaque_lourde_recovery_s: float = 0.75
@export var attaque_lourde_cooldown_s: float = 5.0
@export var attaque_dash_degats: int = 18
@export var attaque_dash_recul: float = 640.0
@export var attaque_dash_declenche_min_px: float = 360.0
@export var attaque_dash_hit_radius_px: float = 210.0
@export var attaque_dash_vitesse_px_s: float = 1100.0
@export var attaque_dash_windup_s: float = 0.35
@export var attaque_dash_duree_s: float = 0.35
@export var attaque_dash_recovery_s: float = 0.45
@export var attaque_dash_cooldown_s: float = 4.0

var position_spawn: Vector2 = Vector2.ZERO
var _joueur_etait_dans_territoire: bool = false
var _retour_spawn_t: float = 0.0
var _combat_engage: bool = false
var _cible_position_deplacement: Vector2 = Vector2.ZERO
var _cible_est_joueur: bool = false
var _dash_deplacement_actif: bool = false

enum AttaqueBoss { AUCUNE, BASE, LOURDE, DASH }
enum PhaseAttaque { WINDUP, ACTIVE, RECOVERY }

var _attaque: int = AttaqueBoss.AUCUNE
var _phase_attaque: int = PhaseAttaque.WINDUP
var _attaque_t: float = 0.0
var _attaque_a_touche: bool = false
var _dash_dir: Vector2 = Vector2.RIGHT
var _cd_base: float = 0.0
var _cd_lourde: float = 1.0
var _cd_dash: float = 2.0

func _ready() -> void:
	super()
	position_spawn = global_position
	_cible_position_deplacement = position_spawn

func reactiver_apres_pool() -> void:
	super()
	position_spawn = global_position
	_joueur_etait_dans_territoire = false
	_retour_spawn_t = 0.0
	_combat_engage = false
	_cible_position_deplacement = position_spawn
	_cible_est_joueur = false
	_dash_deplacement_actif = false
	_attaque = AttaqueBoss.AUCUNE
	_attaque_t = 0.0
	_attaque_a_touche = false
	_cd_base = 0.0
	_cd_lourde = 1.0
	_cd_dash = 2.0

func get_boss_nom() -> String:
	return nom_boss

func _traiter_logique(dt: float) -> void:
	super(dt)
	_tick_cooldowns_attaques(dt)
	var rayon2: float = rayon_activite_px * rayon_activite_px
	var joueur_dans_territoire: bool = false
	if target != null and is_instance_valid(target):
		joueur_dans_territoire = position_spawn.distance_squared_to(target.global_position) <= rayon2
	_cible_position_deplacement = position_spawn
	_cible_est_joueur = false
	if joueur_dans_territoire and target != null and is_instance_valid(target):
		_retour_spawn_t = 0.0
		_cible_position_deplacement = target.global_position
		_cible_est_joueur = true
		_set_combat_engage(true)
	elif _joueur_etait_dans_territoire and _retour_spawn_t <= 0.0:
		_retour_spawn_t = maxf(delai_retour_spawn_s, 0.0)
	if _retour_spawn_t > 0.0:
		_retour_spawn_t = maxf(_retour_spawn_t - dt, 0.0)
		if _retour_spawn_t > 0.0:
			_cible_position_deplacement = global_position
		else:
			_cible_position_deplacement = position_spawn
			_set_combat_engage(false)
	elif not joueur_dans_territoire:
		_set_combat_engage(false)
	if _cible_est_joueur and _tick_attaques(dt):
		_joueur_etait_dans_territoire = joueur_dans_territoire
		return
	if not _cible_est_joueur and _attaque != AttaqueBoss.AUCUNE:
		_annuler_attaque()
	_joueur_etait_dans_territoire = joueur_dans_territoire

func _obtenir_position_cible_deplacement() -> Vector2:
	return _cible_position_deplacement

func _autoriser_decision_deplacement() -> bool:
	return _state == State.ALIVE and _attaque == AttaqueBoss.AUCUNE

func _cible_deplacement_est_joueur() -> bool:
	return _cible_est_joueur

func _set_combat_engage(v: bool) -> void:
	if _combat_engage == v:
		return
	_combat_engage = v
	if v:
		emit_signal("combat_engage", self)
	else:
		emit_signal("combat_desengage", self)

func _tick_physics_commun(dt: float) -> void:
	super(dt)
	_bloquer_sortie_territoire()

func _appliquer_deplacement(dt: float) -> void:
	if not _dash_deplacement_actif:
		super(dt)
		return
	velocity = _dash_dir * attaque_dash_vitesse_px_s
	var mouvement: Vector2 = velocity * dt
	var collision: KinematicCollision2D = null
	if deplacement_grille_ennemi != null:
		collision = deplacement_grille_ennemi.deplacer_force_avec_collisions(self, mouvement)
	else:
		collision = move_and_collide(mouvement)
	if collision != null:
		_terminer_dash_force()
		_phase_attaque = PhaseAttaque.RECOVERY
		_attaque_t = _duree_recovery_attaque(_attaque)
		velocity = Vector2.ZERO

func _tick_cooldowns_attaques(dt: float) -> void:
	_cd_base = maxf(_cd_base - dt, 0.0)
	_cd_lourde = maxf(_cd_lourde - dt, 0.0)
	_cd_dash = maxf(_cd_dash - dt, 0.0)

func _tick_attaques(dt: float) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if _attaque == AttaqueBoss.AUCUNE:
		_choisir_attaque()
		if _attaque == AttaqueBoss.AUCUNE:
			return false
	_traiter_attaque(dt)
	return true

func _choisir_attaque() -> void:
	var d2: float = global_position.distance_squared_to(target.global_position)
	var dist_dash2: float = attaque_dash_declenche_min_px * attaque_dash_declenche_min_px
	var heavy2: float = attaque_lourde_rayon_px * attaque_lourde_rayon_px
	var base2: float = attaque_base_portee_px * attaque_base_portee_px
	if _cd_lourde <= 0.0 and d2 <= heavy2:
		_demarrer_attaque(AttaqueBoss.LOURDE)
	elif _cd_dash <= 0.0 and d2 >= dist_dash2:
		_demarrer_attaque(AttaqueBoss.DASH)
	elif _cd_base <= 0.0 and d2 <= base2:
		_demarrer_attaque(AttaqueBoss.BASE)

func _demarrer_attaque(type_attaque: int) -> void:
	_attaque = type_attaque
	_phase_attaque = PhaseAttaque.WINDUP
	_attaque_t = _duree_windup_attaque(type_attaque)
	_attaque_a_touche = false
	if target != null and is_instance_valid(target):
		var vers: Vector2 = target.global_position - global_position
		if vers.length_squared() > 0.0001:
			_dash_dir = vers.normalized()

func _traiter_attaque(dt: float) -> void:
	_attaque_t -= dt
	match _phase_attaque:
		PhaseAttaque.WINDUP:
			if _attaque_t <= 0.0:
				_phase_attaque = PhaseAttaque.ACTIVE
				_attaque_t = _duree_active_attaque(_attaque)
				if _attaque == AttaqueBoss.DASH:
					_demarrer_dash_force()
				_resoudre_impact_attaque()
		PhaseAttaque.ACTIVE:
			_resoudre_impact_attaque()
			if _attaque_t <= 0.0:
				_terminer_dash_force()
				_phase_attaque = PhaseAttaque.RECOVERY
				_attaque_t = _duree_recovery_attaque(_attaque)
		PhaseAttaque.RECOVERY:
			if _attaque_t <= 0.0:
				_finir_attaque()

func _demarrer_dash_force() -> void:
	if _dash_deplacement_actif:
		return
	if deplacement_grille_ennemi != null:
		deplacement_grille_ennemi.preparer_deplacement_force(self)
	_dash_deplacement_actif = true

func _terminer_dash_force() -> void:
	if not _dash_deplacement_actif:
		return
	_dash_deplacement_actif = false
	velocity = Vector2.ZERO
	if deplacement_grille_ennemi != null:
		deplacement_grille_ennemi.demander_resynchronisation(self)

func _resoudre_impact_attaque() -> void:
	var hb: HurtBox = get_tree().get_first_node_in_group(&"player_hurtbox") as HurtBox
	if hb == null or not is_instance_valid(hb):
		return
	var centre: Vector2 = hb.hit_center()
	var rayon: float = hb.hit_radius()
	var portee: float = 0.0
	var degats: int = 0
	var force: float = 0.0
	match _attaque:
		AttaqueBoss.BASE:
			portee = attaque_base_portee_px
			degats = attaque_base_degats
			force = attaque_base_recul
		AttaqueBoss.LOURDE:
			portee = attaque_lourde_rayon_px
			degats = attaque_lourde_degats
			force = attaque_lourde_recul
		AttaqueBoss.DASH:
			portee = attaque_dash_hit_radius_px
			degats = attaque_dash_degats
			force = attaque_dash_recul
		_:
			return
	if _attaque_a_touche:
		return
	var rr: float = portee + rayon
	if global_position.distance_squared_to(centre) > rr * rr:
		return
	var hit_accepte: bool = hb.tek_it(degats, self)
	if not hit_accepte:
		return
	var joueur: Node = hb.get_parent()
	if joueur != null and joueur.has_method("appliquer_recul"):
		var dir: Vector2 = centre - global_position
		if dir.length_squared() <= 0.0001:
			dir = _dash_dir
		joueur.call("appliquer_recul", dir, force)
	_attaque_a_touche = true

func _finir_attaque() -> void:
	_terminer_dash_force()
	match _attaque:
		AttaqueBoss.BASE:
			_cd_base = attaque_base_cooldown_s
		AttaqueBoss.LOURDE:
			_cd_lourde = attaque_lourde_cooldown_s
		AttaqueBoss.DASH:
			_cd_dash = attaque_dash_cooldown_s
	_attaque = AttaqueBoss.AUCUNE
	_attaque_t = 0.0
	_attaque_a_touche = false

func _annuler_attaque() -> void:
	_terminer_dash_force()
	_attaque = AttaqueBoss.AUCUNE
	_phase_attaque = PhaseAttaque.WINDUP
	_attaque_t = 0.0
	_attaque_a_touche = false

func _duree_windup_attaque(type_attaque: int) -> float:
	match type_attaque:
		AttaqueBoss.BASE:
			return attaque_base_windup_s
		AttaqueBoss.LOURDE:
			return attaque_lourde_windup_s
		AttaqueBoss.DASH:
			return attaque_dash_windup_s
	return 0.0

func _duree_active_attaque(type_attaque: int) -> float:
	match type_attaque:
		AttaqueBoss.DASH:
			return attaque_dash_duree_s
	return 0.05

func _duree_recovery_attaque(type_attaque: int) -> float:
	match type_attaque:
		AttaqueBoss.BASE:
			return attaque_base_recovery_s
		AttaqueBoss.LOURDE:
			return attaque_lourde_recovery_s
		AttaqueBoss.DASH:
			return attaque_dash_recovery_s
	return 0.0

func _bloquer_sortie_territoire() -> void:
	var rayon: float = maxf(rayon_activite_px, 0.0)
	if rayon <= 0.0:
		return
	var depuis_spawn: Vector2 = global_position - position_spawn
	var d2: float = depuis_spawn.length_squared()
	var r2: float = rayon * rayon
	if d2 <= r2:
		return
	var direction_sortie: Vector2 = depuis_spawn.normalized()
	global_position = position_spawn + direction_sortie * rayon
	var recul_sortant: float = recul.dot(direction_sortie)
	if recul_sortant > 0.0:
		recul -= direction_sortie * recul_sortant
	var pousse_sortante: float = pousse.dot(direction_sortie)
	if pousse_sortante > 0.0:
		pousse -= direction_sortie * pousse_sortante
	if deplacement_grille_ennemi != null:
		deplacement_grille_ennemi.demander_resynchronisation(self)

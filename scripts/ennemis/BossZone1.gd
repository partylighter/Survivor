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

func reactiver_apres_pool() -> void:
	super()
	position_spawn = global_position
	_joueur_etait_dans_territoire = false
	_retour_spawn_t = 0.0
	_combat_engage = false
	_attaque = AttaqueBoss.AUCUNE
	_attaque_t = 0.0
	_attaque_a_touche = false
	_cd_base = 0.0
	_cd_lourde = 1.0
	_cd_dash = 2.0

func get_boss_nom() -> String:
	return nom_boss

func _tick_ia(dt: float) -> void:
	_tick_cooldowns_attaques(dt)

	var rayon2: float = rayon_activite_px * rayon_activite_px
	var joueur_dans_territoire: bool = false

	if target != null and is_instance_valid(target):
		joueur_dans_territoire = position_spawn.distance_squared_to(target.global_position) <= rayon2

	var cible_position: Vector2 = position_spawn
	var cible_est_joueur: bool = false

	if joueur_dans_territoire and target != null and is_instance_valid(target):
		_retour_spawn_t = 0.0
		cible_position = target.global_position
		cible_est_joueur = true
		_set_combat_engage(true)
	elif _joueur_etait_dans_territoire and _retour_spawn_t <= 0.0:
		_retour_spawn_t = max(delai_retour_spawn_s, 0.0)

	if _retour_spawn_t > 0.0:
		_retour_spawn_t = max(_retour_spawn_t - dt, 0.0)
		if _retour_spawn_t > 0.0:
			cible_position = global_position
		else:
			_set_combat_engage(false)
	elif not joueur_dans_territoire:
		_set_combat_engage(false)

	if cible_est_joueur and _tick_attaques(dt):
		_joueur_etait_dans_territoire = joueur_dans_territoire
		return
	elif not cible_est_joueur and _attaque != AttaqueBoss.AUCUNE:
		_annuler_attaque()

	_tick_ia_vers_cible(dt, cible_position, cible_est_joueur)
	_joueur_etait_dans_territoire = joueur_dans_territoire

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
	_vel_mouvement = Vector2.ZERO
	if target != null and is_instance_valid(target):
		var vers: Vector2 = target.global_position - global_position
		if vers.length_squared() > 0.0001:
			_dash_dir = vers.normalized()

func _traiter_attaque(dt: float) -> void:
	_attaque_t -= dt

	match _phase_attaque:
		PhaseAttaque.WINDUP:
			_vel_mouvement = Vector2.ZERO
			_regarder_joueur()
			if _attaque_t <= 0.0:
				_phase_attaque = PhaseAttaque.ACTIVE
				_attaque_t = _duree_active_attaque(_attaque)
				_resoudre_impact_attaque()

		PhaseAttaque.ACTIVE:
			if _attaque == AttaqueBoss.DASH:
				_vel_mouvement = _dash_dir * attaque_dash_vitesse_px_s
				_resoudre_impact_attaque()
			else:
				_vel_mouvement = Vector2.ZERO
			if _attaque_t <= 0.0:
				_phase_attaque = PhaseAttaque.RECOVERY
				_attaque_t = _duree_recovery_attaque(_attaque)
				_vel_mouvement = Vector2.ZERO

		PhaseAttaque.RECOVERY:
			_vel_mouvement = Vector2.ZERO
			if _attaque_t <= 0.0:
				_finir_attaque()

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

	hb.tek_it(degats, self)
	var joueur: Node = hb.get_parent()
	if joueur != null and joueur.has_method("appliquer_recul"):
		var dir: Vector2 = centre - global_position
		if dir.length_squared() <= 0.0001:
			dir = _dash_dir
		joueur.call("appliquer_recul", dir, force)
	_attaque_a_touche = true

func _finir_attaque() -> void:
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
	_attaque = AttaqueBoss.AUCUNE
	_phase_attaque = PhaseAttaque.WINDUP
	_attaque_t = 0.0
	_attaque_a_touche = false
	_vel_mouvement = Vector2.ZERO

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

func _regarder_joueur() -> void:
	if target == null or not is_instance_valid(target):
		return
	var vers: Vector2 = target.global_position - global_position
	if vers.length_squared() > 0.0001:
		_dir_mouvement_last = vers.normalized()

func _tick_ia_vers_cible(dt: float, cible_position: Vector2, cible_est_joueur: bool) -> void:
	var vers_cible: Vector2 = cible_position - global_position
	var dist_cible: float = 999999.0
	var dir_to_cible: Vector2 = _dir_to_player_last
	var d2c: float = vers_cible.length_squared()

	if d2c > 0.0001:
		var invc: float = 1.0 / sqrt(d2c)
		dist_cible = 1.0 / invc
		dir_to_cible = vers_cible * invc
		_dir_to_player_last = dir_to_cible

	_recul_lock_t = max(_recul_lock_t - dt, 0.0)
	_pousse_lock_t = max(_pousse_lock_t - dt, 0.0)

	var dist_arret: float = max(distance_arret_joueur_px if cible_est_joueur else distance_arret_spawn_px, 0.0)
	var dist_ralenti: float = max(distance_ralentir_joueur_px, dist_arret + 1.0)

	var recul_actif: bool = recul_bloque_chase and (
		_recul_lock_t > 0.0 or recul.length_squared() >= recul_seuil_blocage_px * recul_seuil_blocage_px)
	var pousse_actif: bool = (
		_pousse_lock_t > 0.0 or pousse.length_squared() >= pousse_seuil_blocage_px * pousse_seuil_blocage_px)
	var bloc_actif: bool = recul_actif or pousse_actif

	if bloc_actif and not _bloc_actif_prev and recul_reset_vitesse_mouvement:
		_vel_mouvement = Vector2.ZERO
	_bloc_actif_prev = bloc_actif

	if bloc_actif:
		if _state == State.ALIVE:
			_state = State.STUNNED
	else:
		if _state == State.STUNNED:
			_state = State.ALIVE

	var desired_speed: float = 0.0
	var desired_dir: Vector2 = _dir_mouvement_last

	if not bloc_actif:
		var cible_finale: Vector2 = cible_position
		if cible_est_joueur:
			_t_offset -= dt
			if _t_offset <= 0.0:
				_t_offset = max(offset_cible_refresh_s, 0.001)
				_regen_offset(dir_to_cible)
			var l: float = clamp(max(offset_cible_lissage, 0.0) * dt, 0.0, 1.0)
			_offset_cible = _offset_cible.lerp(_offset_cible_voulu, l)
			cible_finale += _offset_cible

		if dist_cible > dist_arret:
			var to: Vector2 = cible_finale - global_position
			var d2to: float = to.length_squared()
			desired_dir = (to * (1.0 / sqrt(d2to))) if d2to > 0.0001 else dir_to_cible

			var sp: float = speed
			if dist_cible < dist_ralenti:
				var t: float = (dist_cible - dist_arret) / (dist_ralenti - dist_arret)
				t = clamp(t, 0.0, 1.0)
				t = t * t * (3.0 - 2.0 * t)
				sp = max(sp * t, speed * clamp(facteur_vitesse_min_proche, 0.0, 1.0))
			desired_speed = sp

	_wobble_t += dt
	var wobble_rate: float = max(wobble_freq_hz, 0.0) * TAU
	var wobble_angle: float = sin(_wobble_phase + _wobble_t * wobble_rate) \
		* max(wobble_angle_rad, 0.0) * _wobble_sign
	if desired_speed > 0.001 and desired_dir.length_squared() > 0.0001:
		desired_dir = desired_dir.rotated(wobble_angle)

	if desired_dir.length_squared() > 0.0001:
		if vitesse_rotation_rad_s <= 0.0:
			_dir_mouvement_last = desired_dir.normalized()
		else:
			var cur_dir: Vector2 = _dir_mouvement_last
			if cur_dir.length_squared() < 0.0001:
				cur_dir = desired_dir
			var krot: float = 1.0 - exp(-max(vitesse_rotation_rad_s, 0.0) * dt)
			_dir_mouvement_last = cur_dir.lerp(desired_dir, krot)
			if _dir_mouvement_last.length_squared() > 0.0001:
				_dir_mouvement_last = _dir_mouvement_last.normalized()

	var desired_vel: Vector2 = _dir_mouvement_last * desired_speed
	var acc: float = max(acceleration_px_s2, 0.0)
	var dec: float = max(deceleration_px_s2, 0.0)
	var max_delta: float = (acc if desired_vel.length_squared() >= _vel_mouvement.length_squared() else dec) * dt

	if recul_actif:
		max_delta *= max(recul_deceleration_mult, 1.0)
	if pousse_actif:
		max_delta *= max(pousse_deceleration_mult, 1.0)

	_vel_mouvement = _vel_mouvement.move_toward(desired_vel, max_delta)

	if cible_est_joueur and dir_to_cible.length_squared() > 0.0001:
		if dist_cible <= dist_arret:
			var inward0: float = _vel_mouvement.dot(dir_to_cible)
			if inward0 > 0.0:
				_vel_mouvement -= dir_to_cible * inward0
		elif dist_cible < dist_ralenti:
			var t2: float = clamp((dist_cible - dist_arret) / (dist_ralenti - dist_arret), 0.0, 1.0)
			var inward: float = _vel_mouvement.dot(dir_to_cible)
			if inward > speed * t2:
				_vel_mouvement -= dir_to_cible * (inward - speed * t2)

func _bloquer_sortie_territoire() -> void:
	var rayon: float = max(rayon_activite_px, 0.0)
	if rayon <= 0.0:
		return

	var depuis_spawn: Vector2 = global_position - position_spawn
	var d2: float = depuis_spawn.length_squared()
	var r2: float = rayon * rayon
	if d2 <= r2:
		return

	var dir: Vector2 = depuis_spawn.normalized()
	global_position = position_spawn + dir * rayon
	var outward: float = _vel_mouvement.dot(dir)
	if outward > 0.0:
		_vel_mouvement -= dir * outward
	var outward_recul: float = recul.dot(dir)
	if outward_recul > 0.0:
		recul -= dir * outward_recul
	var outward_pousse: float = pousse.dot(dir)
	if outward_pousse > 0.0:
		pousse -= dir * outward_pousse

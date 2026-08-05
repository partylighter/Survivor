extends Enemy
class_name EnemyLibre

@export_group("Déplacement libre")
@export var speed: float = 120.0
@export var acceleration_px_s2: float = 1400.0
@export var deceleration_px_s2: float = 1800.0
@export var vitesse_rotation_rad_s: float = 10.0
@export var wobble_angle_rad: float = 0.12
@export var wobble_freq_hz: float = 1.3
@export_range(1, 8, 1) var intervalle_tick_ia_frames: int = 2

@export_group("Réaction déplacement libre")
@export var recul_reset_vitesse_mouvement: bool = true
@export var recul_deceleration_mult: float = 4.0
@export var pousse_deceleration_mult: float = 2.2

@export_group("Distance joueur")
@export var distance_arret_joueur_px: float = 70.0
@export var distance_ralentir_joueur_px: float = 120.0
@export var facteur_vitesse_min_proche: float = 0.12

@export_group("Cible dynamique")
@export var offset_cible_max_px: float = 45.0
@export var offset_cible_refresh_s: float = 0.35
@export var offset_cible_lissage: float = 12.0

@export_group("Base véhicule")
@export var base_actif: bool = true
@export var base_rayon_px: float = 220.0
@export var base_marge_px: float = 8.0

var _vel_mouvement: Vector2 = Vector2.ZERO
var _dir_to_player_last: Vector2 = Vector2.RIGHT
var _dir_mouvement_last: Vector2 = Vector2.RIGHT

var _offset_cible: Vector2 = Vector2.ZERO
var _offset_cible_voulu: Vector2 = Vector2.ZERO
var _t_offset: float = 0.0

var _wobble_t: float = 0.0
var _wobble_phase: float = 0.0
var _wobble_sign: float = 1.0
var _decalage_tick_ia: int = 0
var _dt_tick_ia_accumule: float = 0.0
var _bloc_actif_prev: bool = false

var base_refuge: Node2D = null
var _base_vel: Vector2 = Vector2.ZERO
var _base_r_cache: float = 0.0
var _base_r2_cache: float = 0.0

static var _base_cache: Node2D = null
static var _base_cache_prev_pos: Vector2 = Vector2.ZERO
static var _base_cache_vel: Vector2 = Vector2.ZERO
static var _base_cache_inited: bool = false
static var _base_cache_frame: int = -1

func _initialiser_comportement() -> void:
	_base_r_cache = maxf(base_rayon_px, 0.0) + maxf(base_marge_px, 0.0)
	_base_r2_cache = _base_r_cache * _base_r_cache
	_regen_offset(_dir_to_player_last)
	_offset_cible = _offset_cible_voulu
	_t_offset = randf_range(0.0, maxf(offset_cible_refresh_s, 0.001))
	_wobble_phase = randf() * TAU
	_wobble_sign = -1.0 if randf() < 0.5 else 1.0
	_wobble_t = randf() * 10.0
	_decalage_tick_ia = randi() % maxi(intervalle_tick_ia_frames, 1)

func _reinitialiser_comportement() -> void:
	_vel_mouvement = Vector2.ZERO
	_dt_tick_ia_accumule = 0.0
	_decalage_tick_ia = randi() % maxi(intervalle_tick_ia_frames, 1)
	_bloc_actif_prev = false
	_base_vel = Vector2.ZERO
	_regen_offset(_dir_to_player_last)
	_offset_cible = _offset_cible_voulu
	_t_offset = randf_range(0.0, maxf(offset_cible_refresh_s, 0.001))
	_wobble_phase = randf() * TAU
	_wobble_sign = -1.0 if randf() < 0.5 else 1.0
	_wobble_t = randf() * 10.0

func _sur_recul_applique() -> void:
	if recul_reset_vitesse_mouvement:
		_vel_mouvement = Vector2.ZERO

func _obtenir_vitesse_deplacement() -> Vector2:
	return _vel_mouvement

func _appliquer_contraintes_deplacement(dt: float) -> void:
	_maj_base_vel(dt)
	_bloquer_entree_base(dt)

func _traiter_logique(dt: float) -> void:
	_tick_ia_alterne(dt)

func _tick_ia_alterne(dt: float) -> void:
	var intervalle: int = maxi(intervalle_tick_ia_frames, 1)
	if intervalle <= 1:
		_tick_ia(dt)
		return
	_dt_tick_ia_accumule += dt
	var frame: int = Engine.get_physics_frames()
	if ((frame + _decalage_tick_ia) % intervalle) != 0:
		return
	_tick_ia(_dt_tick_ia_accumule)
	_dt_tick_ia_accumule = 0.0

func _tick_ia(dt: float) -> void:
	var distance_joueur: float = 999999.0
	var direction_joueur: Vector2 = _dir_to_player_last
	if target != null and is_instance_valid(target):
		var vers_joueur: Vector2 = target.global_position - global_position
		var distance_carree: float = vers_joueur.length_squared()
		if distance_carree > 0.0001:
			var inverse_distance: float = 1.0 / sqrt(distance_carree)
			distance_joueur = 1.0 / inverse_distance
			direction_joueur = vers_joueur * inverse_distance
			_dir_to_player_last = direction_joueur

	_recul_lock_t = maxf(_recul_lock_t - dt, 0.0)
	_pousse_lock_t = maxf(_pousse_lock_t - dt, 0.0)

	var distance_arret: float = maxf(distance_arret_joueur_px, 0.0)
	var distance_ralentissement: float = maxf(distance_ralentir_joueur_px, distance_arret + 1.0)
	var recul_actif: bool = recul_bloque_chase and (
		_recul_lock_t > 0.0 or recul.length_squared() >= recul_seuil_blocage_px * recul_seuil_blocage_px)
	var pousse_active: bool = _pousse_lock_t > 0.0 or pousse.length_squared() >= pousse_seuil_blocage_px * pousse_seuil_blocage_px
	var bloc_actif: bool = recul_actif or pousse_active

	if bloc_actif and not _bloc_actif_prev and recul_reset_vitesse_mouvement:
		_vel_mouvement = Vector2.ZERO
	_bloc_actif_prev = bloc_actif
	if bloc_actif:
		if _state == State.ALIVE:
			_state = State.STUNNED
	elif _state == State.STUNNED:
		_state = State.ALIVE

	var vitesse_voulue: float = 0.0
	var direction_voulue: Vector2 = _dir_mouvement_last
	if target != null and is_instance_valid(target) and not bloc_actif:
		_t_offset -= dt
		if _t_offset <= 0.0:
			_t_offset = maxf(offset_cible_refresh_s, 0.001)
			_regen_offset(direction_joueur)
		var lissage: float = clampf(maxf(offset_cible_lissage, 0.0) * dt, 0.0, 1.0)
		_offset_cible = _offset_cible.lerp(_offset_cible_voulu, lissage)
		if distance_joueur > distance_arret:
			var vers_cible: Vector2 = (target.global_position + _offset_cible) - global_position
			var distance_cible_carree: float = vers_cible.length_squared()
			direction_voulue = (vers_cible * (1.0 / sqrt(distance_cible_carree))) if distance_cible_carree > 0.0001 else direction_joueur
			var vitesse_calculee: float = speed
			if distance_joueur < distance_ralentissement:
				var progression: float = (distance_joueur - distance_arret) / (distance_ralentissement - distance_arret)
				progression = clampf(progression, 0.0, 1.0)
				progression = progression * progression * (3.0 - 2.0 * progression)
				vitesse_calculee = maxf(vitesse_calculee * progression, speed * clampf(facteur_vitesse_min_proche, 0.0, 1.0))
			vitesse_voulue = vitesse_calculee

	_wobble_t += dt
	var vitesse_wobble: float = maxf(wobble_freq_hz, 0.0) * TAU
	var angle_wobble: float = sin(_wobble_phase + _wobble_t * vitesse_wobble) * maxf(wobble_angle_rad, 0.0) * _wobble_sign
	if vitesse_voulue > 0.001 and direction_voulue.length_squared() > 0.0001:
		direction_voulue = direction_voulue.rotated(angle_wobble)

	if direction_voulue.length_squared() > 0.0001:
		if vitesse_rotation_rad_s <= 0.0:
			_dir_mouvement_last = direction_voulue.normalized()
		else:
			var direction_actuelle: Vector2 = _dir_mouvement_last
			if direction_actuelle.length_squared() < 0.0001:
				direction_actuelle = direction_voulue
			var facteur_rotation: float = 1.0 - exp(-maxf(vitesse_rotation_rad_s, 0.0) * dt)
			_dir_mouvement_last = direction_actuelle.lerp(direction_voulue, facteur_rotation)
			if _dir_mouvement_last.length_squared() > 0.0001:
				_dir_mouvement_last = _dir_mouvement_last.normalized()

	var velocite_voulue: Vector2 = _dir_mouvement_last * vitesse_voulue
	var acceleration: float = maxf(acceleration_px_s2, 0.0)
	var deceleration: float = maxf(deceleration_px_s2, 0.0)
	var variation_max: float = (acceleration if velocite_voulue.length_squared() >= _vel_mouvement.length_squared() else deceleration) * dt
	if recul_actif:
		variation_max *= maxf(recul_deceleration_mult, 1.0)
	if pousse_active:
		variation_max *= maxf(pousse_deceleration_mult, 1.0)
	_vel_mouvement = _vel_mouvement.move_toward(velocite_voulue, variation_max)

	if target != null and is_instance_valid(target) and direction_joueur.length_squared() > 0.0001:
		if distance_joueur <= distance_arret:
			var composante_entrante: float = _vel_mouvement.dot(direction_joueur)
			if composante_entrante > 0.0:
				_vel_mouvement -= direction_joueur * composante_entrante
		elif distance_joueur < distance_ralentissement:
			var progression_limite: float = clampf((distance_joueur - distance_arret) / (distance_ralentissement - distance_arret), 0.0, 1.0)
			var composante_limitee: float = _vel_mouvement.dot(direction_joueur)
			if composante_limitee > speed * progression_limite:
				_vel_mouvement -= direction_joueur * (composante_limitee - speed * progression_limite)

func _regen_offset(direction_joueur: Vector2) -> void:
	var amplitude: float = maxf(offset_cible_max_px, 0.0)
	if amplitude <= 0.0:
		_offset_cible_voulu = Vector2.ZERO
		return
	var direction_base: Vector2 = direction_joueur if direction_joueur.length_squared() >= 0.0001 else Vector2.RIGHT
	var tangente: Vector2 = Vector2(-direction_base.y, direction_base.x).normalized()
	_offset_cible_voulu = tangente * randf_range(-amplitude, amplitude)

func _update_base_shared(dt: float) -> void:
	var frame: int = Engine.get_physics_frames()
	if _base_cache_frame == frame:
		return
	_base_cache_frame = frame
	if not is_instance_valid(_base_cache):
		_base_cache = get_tree().get_first_node_in_group("base_vehicle") as Node2D
		_base_cache_inited = false
		_base_cache_prev_pos = Vector2.ZERO
		_base_cache_vel = Vector2.ZERO
	if _base_cache == null:
		_base_cache_inited = false
		_base_cache_vel = Vector2.ZERO
		return
	var position_base: Vector2 = _base_cache.global_position
	if not _base_cache_inited:
		_base_cache_inited = true
		_base_cache_prev_pos = position_base
		_base_cache_vel = Vector2.ZERO
		return
	_base_cache_vel = (position_base - _base_cache_prev_pos) / dt if dt > 0.0 else Vector2.ZERO
	_base_cache_prev_pos = position_base

func _maj_base_vel(dt: float) -> void:
	_update_base_shared(dt)
	base_refuge = _base_cache
	_base_vel = _base_cache_vel

func _bloquer_entree_base(dt: float) -> void:
	if not base_actif or base_refuge == null:
		return
	var centre: Vector2 = base_refuge.global_position
	var depuis_centre: Vector2 = global_position - centre
	var rayon_verification: float = _base_r_cache + 50.0
	if absf(depuis_centre.x) > rayon_verification or absf(depuis_centre.y) > rayon_verification:
		return
	if _base_r_cache <= 0.0:
		return
	var distance_carree: float = depuis_centre.length_squared()
	var inverse_distance: float = 1.0 / sqrt(maxf(distance_carree, 0.0001))
	var distance: float = 1.0 / inverse_distance
	var vitesse_relative: Vector2 = velocity - _base_vel
	if distance_carree < _base_r2_cache:
		var normale_sortie: Vector2 = depuis_centre * inverse_distance
		global_position = centre + normale_sortie * _base_r_cache
		var vers_centre: float = vitesse_relative.dot(-normale_sortie)
		if vers_centre > 0.0:
			vitesse_relative += normale_sortie * vers_centre
		velocity = vitesse_relative + _base_vel
		return
	var normale_entree: Vector2 = (-depuis_centre) * inverse_distance
	var composante_entrante: float = vitesse_relative.dot(normale_entree)
	if composante_entrante > 0.0 and (distance - composante_entrante * dt) < _base_r_cache:
		vitesse_relative -= normale_entree * composante_entrante
	velocity = vitesse_relative + _base_vel

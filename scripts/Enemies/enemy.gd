extends CharacterBody2D
class_name Enemy

signal mort
signal reapparu

enum TypeEnnemi { C, B, A, S, BOSS }

@export_group("Type")
@export_enum("C","B","A","S","BOSS") var type_ennemi: int = TypeEnnemi.C
@export var valeur_score: int = 10

@export_group("Refs")
@export_node_path("Node") var chemin_sante: NodePath
@export_node_path("Sprite2D") var chemin_sprite: NodePath = NodePath()

@export_group("Collision math")
@export var rayon_collision_px: float = 14.0
@export var poids_collision: float = 1.0

@export_group("Déplacement")
@export var speed: float = 120.0
@export var acceleration_px_s2: float = 1400.0
@export var deceleration_px_s2: float = 1800.0
@export var vitesse_rotation_rad_s: float = 10.0
@export var wobble_angle_rad: float = 0.12
@export var wobble_freq_hz: float = 1.3

@export_group("Recul")
@export var recul_force_par_degats: float = 18.0
@export var recul_force_min: float = 0.0
@export var recul_force_max: float = 220.0
@export var recul_amorti: float = 18.0
@export var recul_max: float = 500.0
@export var recul_bloque_chase: bool = true
@export var recul_bloque_chase_duree_s: float = 0.12
@export var recul_seuil_blocage_px: float = 8.0
@export var recul_reset_vitesse_mouvement: bool = true
@export var recul_deceleration_mult: float = 4.0

@export_group("Bousculade (foule / collisions)")
@export var pousse_amorti: float = 26.0
@export var pousse_max: float = 260.0
@export var pousse_bloque_chase_duree_s: float = 0.07
@export var pousse_seuil_blocage_px: float = 14.0
@export var pousse_deceleration_mult: float = 2.2

@export_group("Secousse visuelle")
@export var secousse_force_px: float = 4.0
@export var secousse_duree_s: float = 0.12
@export var secousse_scale_impulse: Vector2 = Vector2(0.22, -0.18)
@export var secousse_scale_spring: float = 120.0
@export var secousse_scale_damping: float = 18.0
@export var secousse_scale_max: float = 0.35

@export_group("Distances joueur")
@export var distance_arret_joueur_px: float = 70.0
@export var distance_ralentir_joueur_px: float = 120.0
@export var facteur_vitesse_min_proche: float = 0.12

@export_group("Cible dynamique")
@export var offset_cible_max_px: float = 45.0
@export var offset_cible_refresh_s: float = 0.35
@export var offset_cible_lissage: float = 12.0

@export_group("Base véhicule (anti-entrée)")
@export var base_actif: bool = true
@export var base_rayon_px: float = 220.0
@export var base_marge_px: float = 8.0

static var _base_cache: Node2D = null
static var _base_cache_prev_pos: Vector2 = Vector2.ZERO
static var _base_cache_vel: Vector2 = Vector2.ZERO
static var _base_cache_inited: bool = false
static var _base_cache_frame: int = -1

var base_refuge: Node2D = null
var _base_vel: Vector2 = Vector2.ZERO

var _recul_lock_t: float = 0.0
var recul: Vector2 = Vector2.ZERO

var _pousse_lock_t: float = 0.0
var pousse: Vector2 = Vector2.ZERO

var _dir_to_player_last: Vector2 = Vector2.RIGHT
var _dir_mouvement_last: Vector2 = Vector2.RIGHT
var _vel_mouvement: Vector2 = Vector2.ZERO

var _offset_cible: Vector2 = Vector2.ZERO
var _offset_cible_voulu: Vector2 = Vector2.ZERO
var _t_offset: float = 0.0

var _wobble_t: float = 0.0
var _wobble_phase: float = 0.0
var _wobble_sign: float = 1.0

var _bloc_actif_prev: bool = false

var _secousse_t: float = 0.0
var _sprite_pos_neutre: Vector2 = Vector2.ZERO

var deja_mort: bool = false
var _doit_emit_reapparu_next_frame: bool = false

var _layer_orig: int = -1
var _mask_orig: int = -1

var _sprite_scale_neutre: Vector2 = Vector2.ONE
var _scale_offset: Vector2 = Vector2.ZERO
var _scale_vel: Vector2 = Vector2.ZERO

var _ai_enabled: bool = true

@onready var sante: Sante = get_node_or_null(chemin_sante) as Sante
@onready var target: Player = _find_player(get_tree().current_scene)
@onready var sprite: Sprite2D = get_node_or_null(chemin_sprite) as Sprite2D
@onready var hurtbox: HurtBox = get_node_or_null("HurtBox") as HurtBox
@onready var contact_damage: ContactDamage = get_node_or_null("ContactDamage") as ContactDamage

func _ready() -> void:
	add_to_group("enemy")

	if sprite != null:
		_sprite_pos_neutre = sprite.position
		_sprite_scale_neutre = sprite.scale

	if sante != null:
		sante.died.connect(_on_mort)
		sante.damaged.connect(_on_damaged)

	_layer_orig = collision_layer
	_mask_orig = collision_mask

	_regen_offset(_dir_to_player_last)
	_offset_cible = _offset_cible_voulu
	_t_offset = randf_range(0.0, max(offset_cible_refresh_s, 0.001))

	_wobble_phase = randf() * TAU
	_wobble_sign = -1.0 if randf() < 0.5 else 1.0
	_wobble_t = randf() * 10.0

func get_type_id() -> int:
	return type_ennemi

func get_type_nom() -> StringName:
	return StringName(TypeEnnemi.find_key(type_ennemi))

func get_score() -> int:
	return valeur_score

func set_poussee_foule(v: Vector2) -> void:
	appliquer_pousse(v, 0.0)

func appliquer_pousse(v: Vector2, lock_s: float = -1.0) -> void:
	pousse += v
	var m: float = pousse.length()
	if m > pousse_max:
		pousse = pousse * (pousse_max / m)

	var ls: float = pousse_bloque_chase_duree_s
	if lock_s >= 0.0:
		ls = lock_s
	_pousse_lock_t = max(_pousse_lock_t, max(ls, 0.0))

func appliquer_recul(direction: Vector2, force: float) -> void:
	recul += direction.normalized() * max(force, 0.0)
	var m: float = recul.length()
	if m > recul_max:
		recul = recul * (recul_max / m)

	_recul_lock_t = max(_recul_lock_t, max(recul_bloque_chase_duree_s, 0.0))

	if recul_reset_vitesse_mouvement:
		_vel_mouvement = Vector2.ZERO

	_prendre_coup_visuel()

func appliquer_recul_depuis(source: Node2D, force: float) -> void:
	var dir: Vector2 = global_position - source.global_position
	appliquer_recul(dir, force)

func _prendre_coup_visuel() -> void:
	_secousse_t = secousse_duree_s
	_scale_vel += secousse_scale_impulse

func _on_damaged(amount: int, source: Node) -> void:
	if not (source is Node2D):
		return
	var f: float = clamp(float(amount) * max(recul_force_par_degats, 0.0), recul_force_min, recul_force_max)
	if f <= 0.0:
		return
	appliquer_recul_depuis(source as Node2D, f)

func _regen_offset(dir_to_player: Vector2) -> void:
	var s: float = max(offset_cible_max_px, 0.0)
	if s <= 0.0:
		_offset_cible_voulu = Vector2.ZERO
		return

	var d0: Vector2 = dir_to_player
	if d0.length_squared() < 0.0001:
		d0 = Vector2.RIGHT

	var tangent: Vector2 = Vector2(-d0.y, d0.x)
	if tangent.length_squared() < 0.0001:
		tangent = Vector2.RIGHT
	tangent = tangent.normalized()

	_offset_cible_voulu = tangent * randf_range(-s, s)

func _tick_scale_impact(dt: float) -> void:
	if sprite == null:
		return

	var k: float = max(secousse_scale_spring, 0.0)
	if k <= 0.0:
		if sprite.scale != _sprite_scale_neutre:
			sprite.scale = _sprite_scale_neutre
		return

	var d: float = max(secousse_scale_damping, 0.0)

	_scale_vel += (-_scale_offset * k - _scale_vel * d) * dt
	_scale_offset += _scale_vel * dt

	var m: float = max(secousse_scale_max, 0.0)
	if m > 0.0:
		_scale_offset.x = clamp(_scale_offset.x, -m, m)
		_scale_offset.y = clamp(_scale_offset.y, -m, m)

	if _scale_offset.length_squared() < 0.000001 and _scale_vel.length_squared() < 0.000001:
		_scale_offset = Vector2.ZERO
		_scale_vel = Vector2.ZERO
		if sprite.scale != _sprite_scale_neutre:
			sprite.scale = _sprite_scale_neutre
		return

	var s: Vector2 = _sprite_scale_neutre + _scale_offset
	s.x = max(s.x, 0.05)
	s.y = max(s.y, 0.05)
	sprite.scale = s

func _update_base_shared(dt: float) -> void:
	var frame: int = Engine.get_physics_frames()
	if _base_cache_frame == frame:
		return
	_base_cache_frame = frame

	if not is_instance_valid(_base_cache):
		var n := get_tree().get_first_node_in_group("base_vehicle")
		_base_cache = n as Node2D
		_base_cache_inited = false
		_base_cache_prev_pos = Vector2.ZERO
		_base_cache_vel = Vector2.ZERO

	if _base_cache == null:
		_base_cache_inited = false
		_base_cache_vel = Vector2.ZERO
		return

	var pos: Vector2 = _base_cache.global_position
	if not _base_cache_inited:
		_base_cache_inited = true
		_base_cache_prev_pos = pos
		_base_cache_vel = Vector2.ZERO
		return

	if dt > 0.0:
		_base_cache_vel = (pos - _base_cache_prev_pos) / dt
	else:
		_base_cache_vel = Vector2.ZERO
	_base_cache_prev_pos = pos

func _maj_base_vel(dt: float) -> void:
	_update_base_shared(dt)
	base_refuge = _base_cache
	_base_vel = _base_cache_vel

func _bloquer_entree_base(dt: float) -> void:
	if not base_actif or base_refuge == null:
		return

	var c: Vector2 = base_refuge.global_position
	var from_center: Vector2 = global_position - c

	var r: float = max(base_rayon_px, 0.0) + max(base_marge_px, 0.0)
	if r <= 0.0:
		return

	var r2: float = r * r
	var d2: float = from_center.length_squared()
	var inv_dist: float = 1.0 / sqrt(max(d2, 0.0001))
	var dist: float = 1.0 / inv_dist

	var v_rel: Vector2 = velocity - _base_vel

	if d2 < r2:
		var n_out: Vector2 = from_center * inv_dist
		global_position = c + n_out * r

		var toward_center: float = v_rel.dot(-n_out)
		if toward_center > 0.0:
			v_rel += n_out * toward_center

		velocity = v_rel + _base_vel
		return

	var n_in: Vector2 = (-from_center) * inv_dist
	var inward: float = v_rel.dot(n_in)
	if inward > 0.0 and (dist - inward * dt) < r:
		v_rel -= n_in * inward

	velocity = v_rel + _base_vel

func _physics_process(dt: float) -> void:
	if _doit_emit_reapparu_next_frame:
		_doit_emit_reapparu_next_frame = false
		emit_signal("reapparu")

	if deja_mort or not _ai_enabled:
		return

	var dist_player: float = 999999.0
	var dir_to_player: Vector2 = _dir_to_player_last

	if target != null and is_instance_valid(target):
		var tp: Vector2 = target.global_position - global_position
		var d2p: float = tp.length_squared()
		if d2p > 0.0001:
			var invp: float = 1.0 / sqrt(d2p)
			dist_player = 1.0 / invp
			dir_to_player = tp * invp
			_dir_to_player_last = dir_to_player

	_recul_lock_t = max(_recul_lock_t - dt, 0.0)
	_pousse_lock_t = max(_pousse_lock_t - dt, 0.0)

	var dist_arret: float = max(distance_arret_joueur_px, 0.0)
	var dist_ralenti: float = max(distance_ralentir_joueur_px, dist_arret + 1.0)

	var seuil_r: float = max(recul_seuil_blocage_px, 0.0)
	var recul_actif: bool = recul_bloque_chase and (_recul_lock_t > 0.0 or recul.length_squared() >= (seuil_r * seuil_r))

	var seuil_p: float = max(pousse_seuil_blocage_px, 0.0)
	var pousse_actif: bool = (_pousse_lock_t > 0.0 or pousse.length_squared() >= (seuil_p * seuil_p))

	var bloc_actif: bool = recul_actif or pousse_actif

	if bloc_actif and not _bloc_actif_prev and recul_reset_vitesse_mouvement:
		_vel_mouvement = Vector2.ZERO
	_bloc_actif_prev = bloc_actif

	var desired_speed: float = 0.0
	var desired_dir: Vector2 = _dir_mouvement_last

	if target != null and is_instance_valid(target) and not bloc_actif:
		_t_offset -= dt
		if _t_offset <= 0.0:
			_t_offset = max(offset_cible_refresh_s, 0.001)
			_regen_offset(dir_to_player)

		var l: float = clamp(max(offset_cible_lissage, 0.0) * dt, 0.0, 1.0)
		_offset_cible = _offset_cible.lerp(_offset_cible_voulu, l)

		if dist_player <= dist_arret:
			desired_speed = 0.0
			desired_dir = _dir_mouvement_last
		else:
			var to: Vector2 = (target.global_position + _offset_cible) - global_position
			var d2to: float = to.length_squared()

			if d2to > 0.0001:
				desired_dir = to * (1.0 / sqrt(d2to))
			else:
				desired_dir = dir_to_player

			var sp: float = speed
			if dist_player < dist_ralenti:
				var t: float = (dist_player - dist_arret) / (dist_ralenti - dist_arret)
				t = clamp(t, 0.0, 1.0)
				t = t * t * (3.0 - 2.0 * t)
				sp *= t
				sp = max(sp, speed * clamp(facteur_vitesse_min_proche, 0.0, 1.0))

			desired_speed = sp

	_wobble_t += dt
	var wobble_rate: float = max(wobble_freq_hz, 0.0) * TAU
	var wobble_angle: float = sin(_wobble_phase + _wobble_t * wobble_rate) * max(wobble_angle_rad, 0.0) * _wobble_sign
	if desired_speed > 0.001 and desired_dir.length_squared() > 0.0001:
		desired_dir = desired_dir.rotated(wobble_angle)

	if desired_dir.length_squared() > 0.0001:
		if vitesse_rotation_rad_s <= 0.0:
			_dir_mouvement_last = desired_dir.normalized()
		else:
			var cur_dir: Vector2 = _dir_mouvement_last
			if cur_dir.length_squared() < 0.0001:
				cur_dir = desired_dir
			var krot: float = clamp(max(vitesse_rotation_rad_s, 0.0) * dt, 0.0, 1.0)
			_dir_mouvement_last = cur_dir.lerp(desired_dir, krot)
			if _dir_mouvement_last.length_squared() > 0.0001:
				_dir_mouvement_last = _dir_mouvement_last.normalized()

	var desired_vel: Vector2 = _dir_mouvement_last * desired_speed

	var acc: float = max(acceleration_px_s2, 0.0)
	var dec: float = max(deceleration_px_s2, 0.0)
	var max_delta: float = acc * dt
	if desired_vel.length_squared() < _vel_mouvement.length_squared():
		max_delta = dec * dt

	var decel_mult: float = 1.0
	if recul_actif:
		decel_mult = max(decel_mult, max(recul_deceleration_mult, 1.0))
	if pousse_actif:
		decel_mult = max(decel_mult, max(pousse_deceleration_mult, 1.0))
	max_delta *= decel_mult

	_vel_mouvement = _vel_mouvement.move_toward(desired_vel, max_delta)
	velocity = _vel_mouvement

	velocity += recul
	var alpha_r: float = clamp(recul_amorti * dt, 0.0, 0.95)
	recul = recul.lerp(Vector2.ZERO, alpha_r)
	if recul.length_squared() < 1.0:
		recul = Vector2.ZERO

	velocity += pousse
	var alpha_p: float = clamp(pousse_amorti * dt, 0.0, 0.95)
	pousse = pousse.lerp(Vector2.ZERO, alpha_p)
	if pousse.length_squared() < 1.0:
		pousse = Vector2.ZERO

	if target != null and is_instance_valid(target) and dir_to_player.length_squared() > 0.0001:
		if dist_player <= dist_arret:
			var inward0: float = velocity.dot(dir_to_player)
			if inward0 > 0.0:
				velocity -= dir_to_player * inward0
		elif dist_player < dist_ralenti:
			var t2: float = (dist_player - dist_arret) / (dist_ralenti - dist_arret)
			t2 = clamp(t2, 0.0, 1.0)
			var max_in: float = speed * t2
			var inward: float = velocity.dot(dir_to_player)
			if inward > max_in:
				velocity -= dir_to_player * (inward - max_in)

	if sprite != null:
		if _secousse_t > 0.0:
			_secousse_t -= dt
			var ratio: float = 0.0
			if secousse_duree_s > 0.0001:
				ratio = _secousse_t / secousse_duree_s
			ratio = clamp(ratio, 0.0, 1.0)
			var ox: float = randf_range(-1.0, 1.0)
			var oy: float = randf_range(-1.0, 1.0)
			var offset: Vector2 = Vector2(ox, oy) * secousse_force_px * ratio
			sprite.position = _sprite_pos_neutre + offset
		else:
			if sprite.position != _sprite_pos_neutre:
				sprite.position = _sprite_pos_neutre

		if _scale_offset.length_squared() > 0.000001 or _scale_vel.length_squared() > 0.000001:
			_tick_scale_impact(dt)
		else:
			if sprite.scale != _sprite_scale_neutre:
				sprite.scale = _sprite_scale_neutre

	_maj_base_vel(dt)
	_bloquer_entree_base(dt)

	move_and_slide()

func _find_player(n: Node) -> Player:
	if n is Player:
		return n
	for c: Node in n.get_children():
		var p: Player = _find_player(c)
		if p:
			return p
	return null

func _on_mort() -> void:
	if deja_mort:
		return
	deja_mort = true

	if is_in_group("enemy"):
		remove_from_group("enemy")

	if _layer_orig < 0:
		_layer_orig = collision_layer
	if _mask_orig < 0:
		_mask_orig = collision_mask

	if not has_meta("sl"):
		set_meta("sl", _layer_orig)
	if not has_meta("sm"):
		set_meta("sm", _mask_orig)

	if hurtbox != null:
		hurtbox.set_actif(false)

	if contact_damage != null:
		contact_damage.set_physics_process(false)

	collision_layer = 0
	collision_mask = 0

	_scale_offset = Vector2.ZERO
	_scale_vel = Vector2.ZERO

	if sprite != null:
		sprite.scale = _sprite_scale_neutre
		sprite.position = _sprite_pos_neutre

	visible = false
	velocity = Vector2.ZERO
	_vel_mouvement = Vector2.ZERO
	recul = Vector2.ZERO
	pousse = Vector2.ZERO

	set_physics_process(false)
	set_process(false)

	_ai_enabled = false

	emit_signal("mort")

func reactiver_apres_pool() -> void:
	deja_mort = false

	if not is_in_group("enemy"):
		add_to_group("enemy")

	if sante != null:
		sante.pv = float(sante.max_pv)

	visible = true
	velocity = Vector2.ZERO
	_vel_mouvement = Vector2.ZERO
	recul = Vector2.ZERO
	pousse = Vector2.ZERO

	if hurtbox != null:
		hurtbox.set_actif(true)

	if contact_damage != null:
		contact_damage.set_physics_process(true)

	set_physics_process(true)
	set_process(true)

	_ai_enabled = true

	_doit_emit_reapparu_next_frame = true
	_secousse_t = 0.0

	_scale_offset = Vector2.ZERO
	_scale_vel = Vector2.ZERO

	if sprite != null:
		sprite.scale = _sprite_scale_neutre
		sprite.position = _sprite_pos_neutre

	_regen_offset(_dir_to_player_last)
	_offset_cible = _offset_cible_voulu
	_t_offset = randf_range(0.0, max(offset_cible_refresh_s, 0.001))

	_wobble_phase = randf() * TAU
	_wobble_sign = -1.0 if randf() < 0.5 else 1.0
	_wobble_t = randf() * 10.0

	_bloc_actif_prev = false
	_base_vel = Vector2.ZERO

func set_combat_state(actif_moteur: bool, _collision_joueur: bool) -> void:
	if deja_mort:
		return

	_ai_enabled = actif_moteur
	set_physics_process(actif_moteur)
	set_process(actif_moteur)

	if hurtbox != null:
		hurtbox.set_actif(actif_moteur)

	if contact_damage != null:
		contact_damage.set_physics_process(actif_moteur)

	if actif_moteur:
		if has_meta("sl"):
			collision_layer = int(get_meta("sl"))
		elif _layer_orig >= 0:
			collision_layer = _layer_orig

		if has_meta("sm"):
			collision_mask = int(get_meta("sm"))
		elif _mask_orig >= 0:
			collision_mask = _mask_orig

func hit_radius() -> float:
	return max(rayon_collision_px, 0.0)

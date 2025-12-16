extends CharacterBody2D
class_name Enemy

signal mort
signal reapparu

enum TypeEnnemi {C, B, A, S, BOSS}

@export_group("Type")
@export_enum("C","B","A","S","BOSS") var type_ennemi: int = TypeEnnemi.C

@export var valeur_score: int = 10
@export var speed: float = 120.0
@export_node_path("Node") var chemin_sante: NodePath

@export var recul_amorti: float = 18.0
@export var recul_max: float = 500.0
@export var recul_bloque_chase_duree_s: float = 0.12

@export_group("Mouvement")
@export var acceleration_px_s2: float = 1400.0
@export var deceleration_px_s2: float = 1800.0
@export var vitesse_rotation_rad_s: float = 10.0
@export var wobble_angle_rad: float = 0.12
@export var wobble_freq_hz: float = 1.3

@export_group("Recul - priorité")
@export var recul_bloque_chase: bool = true
@export var recul_seuil_blocage_px: float = 8.0
@export var recul_reset_vitesse_mouvement: bool = true
@export var recul_deceleration_mult: float = 4.0

@export_group("Secousse")
@export var secousse_force_px: float = 4.0
@export var secousse_duree_s: float = 0.12

@export_group("Distances joueur")
@export var distance_arret_joueur_px: float = 70.0
@export var distance_ralentir_joueur_px: float = 120.0
@export var facteur_vitesse_min_proche: float = 0.12

@export_group("Cible dynamique")
@export var offset_cible_max_px: float = 45.0
@export var offset_cible_refresh_s: float = 0.35
@export var offset_cible_lissage: float = 12.0

var _recul_lock_t: float = 0.0
var _dir_to_player_last: Vector2 = Vector2.RIGHT
var _offset_cible: Vector2 = Vector2.ZERO
var _offset_cible_voulu: Vector2 = Vector2.ZERO
var _t_offset: float = 0.0

var _vel_mouvement: Vector2 = Vector2.ZERO
var _dir_mouvement_last: Vector2 = Vector2.RIGHT

var _wobble_t: float = 0.0
var _wobble_phase: float = 0.0
var _wobble_sign: float = 1.0

var _recul_actif_prev: bool = false

var recul: Vector2 = Vector2.ZERO
var deja_mort: bool = false
var _doit_emit_reapparu_next_frame: bool = false

var _layer_orig: int = -1
var _mask_orig: int = -1

var _ai_enabled: bool = true

var _secousse_t: float = 0.0
var _sprite_pos_neutre: Vector2 = Vector2.ZERO

var poussee_foule: Vector2 = Vector2.ZERO

@onready var sante: Sante = get_node_or_null(chemin_sante) as Sante
@onready var target: Player = _find_player(get_tree().current_scene)
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	_sprite_pos_neutre = sprite.position

	if sante:
		sante.died.connect(_on_mort)

	_layer_orig = collision_layer
	_mask_orig = collision_mask

	_regen_offset(_dir_to_player_last)
	_offset_cible = _offset_cible_voulu
	_t_offset = randf_range(0.0, max(offset_cible_refresh_s, 0.001))

	_wobble_phase = randf() * TAU
	_wobble_sign = -1.0 if randf() < 0.5 else 1.0
	_wobble_t = randf() * 10.0

func _regen_offset(dir_to_player: Vector2) -> void:
	var s: float = max(offset_cible_max_px, 0.0)
	if s <= 0.0:
		_offset_cible_voulu = Vector2.ZERO
		return

	var d: Vector2 = dir_to_player
	if d.length_squared() < 0.0001:
		d = Vector2.RIGHT

	var tangent: Vector2 = Vector2(-d.y, d.x)
	if tangent.length_squared() < 0.0001:
		tangent = Vector2.RIGHT
	tangent = tangent.normalized()

	_offset_cible_voulu = tangent * randf_range(-s, s)

func set_poussee_foule(v: Vector2) -> void:
	poussee_foule = v

func get_type_id() -> int:
	return type_ennemi

func get_type_nom() -> StringName:
	return StringName(TypeEnnemi.find_key(type_ennemi))

func get_score() -> int:
	return valeur_score

func appliquer_recul(direction: Vector2, force: float) -> void:
	recul += direction.normalized() * max(force, 0.0)
	var m: float = recul.length()
	if m > recul_max:
		recul = recul * (recul_max / m)

	_recul_lock_t = max(_recul_lock_t, max(recul_bloque_chase_duree_s, 0.0))

	if recul_reset_vitesse_mouvement:
		_vel_mouvement = Vector2.ZERO

	_prendre_coup_visuel()

func _prendre_coup_visuel() -> void:
	_secousse_t = secousse_duree_s

func appliquer_recul_depuis(source: Node2D, force: float) -> void:
	var dir: Vector2 = global_position - source.global_position
	appliquer_recul(dir, force)

func _physics_process(dt: float) -> void:
	if _doit_emit_reapparu_next_frame:
		_doit_emit_reapparu_next_frame = false
		emit_signal("reapparu")

	if deja_mort or not _ai_enabled:
		return

	var dist_player: float = 999999.0
	var dir_to_player: Vector2 = _dir_to_player_last

	if target != null:
		var tp: Vector2 = target.global_position - global_position
		dist_player = tp.length()
		if dist_player > 0.0001:
			dir_to_player = tp / dist_player
			_dir_to_player_last = dir_to_player

	_recul_lock_t = max(_recul_lock_t - dt, 0.0)

	var dist_arret: float = max(distance_arret_joueur_px, 0.0)
	var dist_ralenti: float = max(distance_ralentir_joueur_px, dist_arret + 1.0)

	var seuil_px: float = max(recul_seuil_blocage_px, 0.0)
	var recul_actif: bool = recul_bloque_chase and (_recul_lock_t > 0.0 or recul.length_squared() >= (seuil_px * seuil_px))

	if recul_actif and not _recul_actif_prev and recul_reset_vitesse_mouvement:
		_vel_mouvement = Vector2.ZERO
	_recul_actif_prev = recul_actif

	var desired_speed: float = 0.0
	var desired_dir: Vector2 = _dir_mouvement_last

	if target != null and not recul_actif:
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
			var dist_to: float = to.length()

			if dist_to > 0.0001:
				desired_dir = to / dist_to
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
		desired_dir = desired_dir.rotated(wobble_angle).normalized()

	if desired_dir.length_squared() > 0.0001:
		if vitesse_rotation_rad_s <= 0.0:
			_dir_mouvement_last = desired_dir.normalized()
		else:
			var cur_dir: Vector2 = _dir_mouvement_last
			if cur_dir.length_squared() < 0.0001:
				cur_dir = desired_dir

			var a_cur: float = atan2(cur_dir.y, cur_dir.x)
			var a_des: float = atan2(desired_dir.y, desired_dir.x)
			var da: float = wrapf(a_des - a_cur, -PI, PI)
			var max_step: float = max(vitesse_rotation_rad_s, 0.0) * dt
			da = clamp(da, -max_step, max_step)

			var a_new: float = a_cur + da
			_dir_mouvement_last = Vector2(cos(a_new), sin(a_new))

	var desired_vel: Vector2 = _dir_mouvement_last * desired_speed

	var a: float = max(acceleration_px_s2, 0.0)
	var d: float = max(deceleration_px_s2, 0.0)
	var max_delta: float = a * dt
	if desired_vel.length_squared() < _vel_mouvement.length_squared():
		max_delta = d * dt
	if recul_actif:
		max_delta *= max(recul_deceleration_mult, 1.0)

	_vel_mouvement = _vel_mouvement.move_toward(desired_vel, max_delta)
	velocity = _vel_mouvement

	velocity += recul
	var alpha: float = clamp(recul_amorti * dt, 0.0, 0.95)
	recul = recul.lerp(Vector2.ZERO, alpha)
	if recul.length_squared() < 1.0:
		recul = Vector2.ZERO

	if poussee_foule != Vector2.ZERO:
		velocity += poussee_foule
		poussee_foule = Vector2.ZERO

	if target != null and dir_to_player.length_squared() > 0.0001:
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

	if _secousse_t > 0.0:
		_secousse_t -= dt
		var ratio: float = _secousse_t / secousse_duree_s
		if ratio < 0.0:
			ratio = 0.0
		var offset: Vector2 = Vector2(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0)
		) * secousse_force_px * ratio
		sprite.position = _sprite_pos_neutre + offset
	else:
		sprite.position = _sprite_pos_neutre

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

	if _layer_orig < 0:
		_layer_orig = collision_layer
	if _mask_orig < 0:
		_mask_orig = collision_mask

	if not has_meta("sl"):
		set_meta("sl", _layer_orig)
	if not has_meta("sm"):
		set_meta("sm", _mask_orig)

	collision_layer = 0
	collision_mask = 0

	visible = false
	velocity = Vector2.ZERO
	_vel_mouvement = Vector2.ZERO
	recul = Vector2.ZERO
	poussee_foule = Vector2.ZERO

	set_physics_process(false)
	set_process(false)

	_ai_enabled = false

	emit_signal("mort")

func reactiver_apres_pool() -> void:
	deja_mort = false

	if sante:
		var max_pv_now: float = float(sante.max_pv)
		sante.pv = max_pv_now

	visible = true
	velocity = Vector2.ZERO
	_vel_mouvement = Vector2.ZERO
	recul = Vector2.ZERO
	poussee_foule = Vector2.ZERO

	set_physics_process(true)
	set_process(true)

	_ai_enabled = true

	_doit_emit_reapparu_next_frame = true
	_secousse_t = 0.0
	sprite.position = _sprite_pos_neutre

	_regen_offset(_dir_to_player_last)
	_offset_cible = _offset_cible_voulu
	_t_offset = randf_range(0.0, max(offset_cible_refresh_s, 0.001))

	_wobble_phase = randf() * TAU
	_wobble_sign = -1.0 if randf() < 0.5 else 1.0
	_wobble_t = randf() * 10.0

	_recul_actif_prev = false

func set_combat_state(actif_moteur: bool, _collision_joueur: bool) -> void:
	if deja_mort:
		return

	_ai_enabled = actif_moteur

	set_physics_process(actif_moteur)
	set_process(actif_moteur)

	if actif_moteur:
		if has_meta("sl"):
			collision_layer = int(get_meta("sl"))
		elif _layer_orig >= 0:
			collision_layer = _layer_orig

		if has_meta("sm"):
			collision_mask = int(get_meta("sm"))
		elif _mask_orig >= 0:
			collision_mask = _mask_orig

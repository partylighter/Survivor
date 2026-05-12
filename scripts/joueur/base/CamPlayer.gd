extends Camera2D
class_name CamPlayer

@export_group("Cible")
@export var chemin_joueur: NodePath

@export_group("Follow")
@export_range(0.1, 30.0, 0.1) var follow_speed: float = 8.0

@export_group("Limites Y")
@export var limites_y_actives: bool = false:
	set(v):
		limites_y_actives = v
		_appliquer_limites_y()
@export var limite_haute_y: int = -10000:
	set(v):
		limite_haute_y = v
		_appliquer_limites_y()
@export var limite_basse_y: int = 10000:
	set(v):
		limite_basse_y = v
		_appliquer_limites_y()

@export_group("Offset / Look")
@export_range(0.0, 2000.0, 1.0) var look_ahead_sol_px: float = 140.0
@export_range(0.0, 2000.0, 1.0) var look_ahead_conduite_px: float = 220.0
@export_range(0.0, 2000.0, 1.0) var mouse_look_sol_px: float = 130.0
@export_range(0.0, 2000.0, 1.0) var mouse_look_conduite_px: float = 170.0
@export_range(0.0, 1.0, 0.01) var mouse_deadzone: float = 0.08
@export_range(0.0, 2.0, 0.01) var mouse_influence_y: float = 0.85
@export_range(0.0, 2000.0, 1.0) var max_offset_px: float = 260.0
@export_range(0.1, 30.0, 0.1) var offset_speed: float = 18.0

@export_group("Zoom")
@export_range(0.05, 4.0, 0.01) var zoom_sol: float = 1.0
@export_range(0.05, 4.0, 0.01) var zoom_conduite: float = 0.92
@export_range(0.05, 4.0, 0.01) var zoom_move_sol: float = 0.86
@export_range(0.05, 4.0, 0.01) var zoom_move_conduite: float = 0.80
@export_range(0.1, 30.0, 0.1) var zoom_speed: float = 7.5

@export_group("Zoom Delay")
@export_range(0.0, 2.0, 0.01) var zoom_out_delay_s: float = 0.20
@export_range(0.0, 10.0, 0.01) var zoom_in_delay_s: float = 0.45
@export_range(0.0, 2000.0, 1.0) var zoom_out_speed_threshold: float = 30.0
@export_range(0.0, 2000.0, 1.0) var zoom_in_speed_threshold: float = 12.0
@export_range(0.0, 10.0, 0.1) var zoom_delay_release_mul: float = 3.0

@export_group("Camera deplacement")
@export_range(0.0, 1.0, 0.01) var intensite_camera_deplacement: float = 0.65
@export_range(0.0, 120.0, 1.0) var balancement_lateral_px: float = 34.0
@export_range(0.0, 120.0, 1.0) var balancement_vertical_px: float = 22.0
@export_range(0.0, 80.0, 1.0) var secousse_deplacement_px: float = 18.0
@export_range(0.0, 20.0, 0.1) var frequence_balancement_hz: float = 4.2
@export_range(0.0, 40.0, 0.1) var frequence_secousse_hz: float = 13.0
@export_range(0.0, 260.0, 1.0) var recul_dash_camera_px: float = 135.0
@export_range(0.01, 1.0, 0.01) var duree_recul_dash_s: float = 0.16

@export_group("Shake")
@export var shake_force_px: float = 10.0
@export var shake_duree_s: float = 0.14
@export var shake_freq_hz: float = 28.0
@export_range(0.0, 2.0, 0.01) var shake_per_damage_px: float = 0.35
@export_range(0.0, 200.0, 1.0) var shake_max_force_px: float = 22.0
@export_range(0.0, 200.0, 1.0) var shake_min_damage_for_full: float = 30.0

var _joueur: Player = null
var _last_target: Node2D = null
var _last_target_pos: Vector2 = Vector2.ZERO
var _has_last: bool = false

var _vp: Viewport
var _vp_center: Vector2 = Vector2.ZERO
var _vp_inv_center: Vector2 = Vector2.ZERO

var _offset_base: Vector2 = Vector2.ZERO

var _zoom_out_t: float = 0.0
var _zoom_in_t: float = 0.0
var _zoom_moving: bool = false

var _shake_t: float = 0.0
var _shake_seed: float = 0.0
var _shake_amp_now: float = 0.0
var _temps_balancement: float = 0.0
var _temps_secousse_deplacement: float = 0.0
var _offset_balancement: Vector2 = Vector2.ZERO
var _offset_recul_dash: Vector2 = Vector2.ZERO
var _dash_etait_actif: bool = false
var _recul_dash_t: float = 0.0
var _direction_recul_dash: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group(&"cam_player")
	_appliquer_limites_y()
	if not Engine.is_editor_hint():
		make_current()
	_joueur = get_node_or_null(chemin_joueur) as Player
	_vp = get_viewport()
	if _vp:
		_vp.size_changed.connect(_maj_viewport_cache)
	_maj_viewport_cache()

func _ts() -> float:
	return Time.get_ticks_msec() * 0.001

func _appliquer_limites_y() -> void:
	limit_enabled = limites_y_actives
	if not limites_y_actives:
		return
	limit_left = -100000000
	limit_right = 100000000
	limit_top = min(limite_haute_y, limite_basse_y)
	limit_bottom = max(limite_haute_y, limite_basse_y)

func kick_shake_from_damage(damage: int) -> void:
	var d: float = maxf(float(damage), 0.0)
	var amp_by_damage: float = d * shake_per_damage_px
	var amp_scaled: float = 0.0
	if shake_min_damage_for_full > 0.0:
		amp_scaled = lerpf(0.0, shake_max_force_px, clampf(d / shake_min_damage_for_full, 0.0, 1.0))
	_shake_amp_now = minf(shake_max_force_px, maxf(amp_by_damage, amp_scaled))
	_shake_t = shake_duree_s
	_shake_seed = float(Time.get_ticks_msec()) * 0.001 + d * 0.017

func kick_shake(force_mul: float = 1.0) -> void:
	_shake_amp_now = minf(shake_max_force_px, shake_force_px * maxf(force_mul, 0.0))
	_shake_t = shake_duree_s
	_shake_seed = float(Time.get_ticks_msec()) * 0.001 + force_mul * 0.37

func _process(dt: float) -> void:
	if dt <= 0.0:
		return
	if Engine.is_editor_hint():
		return
	if _joueur == null or not is_instance_valid(_joueur):
		return

	var target: Node2D = _joueur.get_camera_target()
	if target == null or not is_instance_valid(target):
		return

	if target != _last_target:
		_last_target = target
		_has_last = false
		_offset_balancement = Vector2.ZERO

	var in_drive: bool = _joueur.est_en_conduite()

	var a_pos: float = 1.0 - exp(-follow_speed * dt)
	global_position = global_position.lerp(target.global_position, a_pos)

	var vel: Vector2 = _get_target_velocity(target, dt)
	var speed: float = vel.length()
	var vitesse_ref: float = _get_vitesse_reference(in_drive)
	var intensite_vitesse: float = clampf(speed / maxf(vitesse_ref, 1.0), 0.0, 1.45)

	var dir: Vector2 = Vector2.ZERO
	if speed > 0.001:
		dir = vel / speed

	var mouse_norm: Vector2 = _get_mouse_norm()
	var mouse_len: float = mouse_norm.length()
	if mouse_len < mouse_deadzone:
		mouse_norm = Vector2.ZERO
		mouse_len = 0.0
	else:
		mouse_norm = mouse_norm.limit_length(1.0)
		mouse_norm.y *= mouse_influence_y
		mouse_len = clampf(mouse_len, 0.0, 1.0)

	var look_ahead: float = look_ahead_conduite_px if in_drive else look_ahead_sol_px
	var mouse_look: float = mouse_look_conduite_px if in_drive else mouse_look_sol_px

	var desired_offset: Vector2 = dir * look_ahead + mouse_norm * mouse_look
	desired_offset += _calculer_offset_balancement(dir, intensite_vitesse, dt)
	desired_offset += _calculer_recul_dash(dt)
	desired_offset = desired_offset.limit_length(max_offset_px)

	var a_off: float = 1.0 - exp(-offset_speed * dt)
	_offset_base = _offset_base.lerp(desired_offset, a_off)

	var shake_off: Vector2 = Vector2.ZERO
	if _shake_t > 0.0:
		_shake_t = maxf(_shake_t - dt, 0.0)
		var k: float = _shake_t / maxf(shake_duree_s, 0.0001)
		var amp: float = _shake_amp_now * k
		var tt: float = _ts()
		shake_off = Vector2(
			sin((tt + _shake_seed) * TAU * shake_freq_hz) * amp,
			cos((tt + _shake_seed) * TAU * shake_freq_hz * 0.93) * amp
		)

	offset = _offset_base + shake_off

	if speed > zoom_out_speed_threshold:
		_zoom_out_t = minf(_zoom_out_t + dt, zoom_out_delay_s)
	else:
		_zoom_out_t = maxf(_zoom_out_t - dt * zoom_delay_release_mul, 0.0)

	if speed < zoom_in_speed_threshold:
		_zoom_in_t = minf(_zoom_in_t + dt, zoom_in_delay_s)
	else:
		_zoom_in_t = maxf(_zoom_in_t - dt * zoom_delay_release_mul, 0.0)

	if not _zoom_moving:
		if zoom_out_delay_s <= 0.0 or _zoom_out_t >= zoom_out_delay_s:
			_zoom_moving = true
			_zoom_in_t = 0.0
	else:
		if zoom_in_delay_s <= 0.0 or _zoom_in_t >= zoom_in_delay_s:
			_zoom_moving = false
			_zoom_out_t = 0.0

	var z_target_f: float
	if _zoom_moving:
		z_target_f = zoom_move_conduite if in_drive else zoom_move_sol
	else:
		z_target_f = zoom_conduite if in_drive else zoom_sol

	var target_zoom: Vector2 = Vector2(z_target_f, z_target_f)
	var a_zoom: float = 1.0 - exp(-zoom_speed * dt)
	zoom = zoom.lerp(target_zoom, a_zoom)

func _maj_viewport_cache() -> void:
	if _vp == null:
		return
	var size: Vector2 = _vp.get_visible_rect().size
	if size.x <= 1.0 or size.y <= 1.0:
		_vp_center = Vector2.ZERO
		_vp_inv_center = Vector2.ZERO
		return
	_vp_center = size * 0.5
	_vp_inv_center = Vector2(1.0 / maxf(_vp_center.x, 1.0), 1.0 / maxf(_vp_center.y, 1.0))

func _get_target_velocity(target: Node2D, dt: float) -> Vector2:
	if target is CharacterBody2D:
		return (target as CharacterBody2D).velocity

	var p: Vector2 = target.global_position
	if not _has_last:
		_last_target_pos = p
		_has_last = true
		return Vector2.ZERO

	var inv_dt: float = 1.0 / maxf(dt, 0.00001)
	var v: Vector2 = (p - _last_target_pos) * inv_dt
	_last_target_pos = p
	return v

func _get_mouse_norm() -> Vector2:
	if _vp == null or _vp_center == Vector2.ZERO:
		return Vector2.ZERO
	var d: Vector2 = _vp.get_mouse_position() - _vp_center
	return Vector2(
		clampf(d.x * _vp_inv_center.x, -1.0, 1.0),
		clampf(d.y * _vp_inv_center.y, -1.0, 1.0)
	)

func _get_vitesse_reference(in_drive: bool) -> float:
	if in_drive:
		return 900.0
	if _joueur != null and _joueur.stats != null:
		return maxf(_joueur.stats.get_vitesse_effective(), 1.0)
	return 450.0

func _calculer_offset_balancement(direction_vitesse: Vector2, intensite_vitesse: float, dt: float) -> Vector2:
	var cible: Vector2 = Vector2.ZERO
	var force: float = clampf(intensite_vitesse, 0.0, 1.0) * intensite_camera_deplacement
	if force > 0.02 and direction_vitesse.length_squared() > 0.0001:
		_temps_balancement += dt * frequence_balancement_hz * TAU * lerpf(0.55, 1.35, force)
		_temps_secousse_deplacement += dt * frequence_secousse_hz * TAU * lerpf(0.75, 1.65, force)
		var cote: Vector2 = Vector2(-direction_vitesse.y, direction_vitesse.x)
		var battement_lateral: float = sin(_temps_balancement)
		var battement_vertical: float = sin(_temps_balancement * 2.0)
		var secousse_x: float = sin(_temps_secousse_deplacement * 1.13)
		var secousse_y: float = cos(_temps_secousse_deplacement * 0.91)
		cible = cote * battement_lateral * balancement_lateral_px * force
		cible.y += -abs(battement_vertical) * balancement_vertical_px * force
		cible += Vector2(secousse_x, secousse_y) * secousse_deplacement_px * force
	else:
		_temps_balancement = 0.0
		_temps_secousse_deplacement = 0.0

	var lissage: float = 1.0 - exp(-12.0 * dt)
	_offset_balancement = _offset_balancement.lerp(cible, lissage)
	return _offset_balancement

func _calculer_recul_dash(dt: float) -> Vector2:
	var dash_actif: bool = _joueur != null and _joueur.dash_t_restant_s > 0.0
	if dash_actif and not _dash_etait_actif:
		_recul_dash_t = duree_recul_dash_s
		_direction_recul_dash = _joueur.dash_direction

	_dash_etait_actif = dash_actif
	if _recul_dash_t <= 0.0:
		_offset_recul_dash = _offset_recul_dash.lerp(Vector2.ZERO, 1.0 - exp(-16.0 * dt))
		return _offset_recul_dash

	_recul_dash_t = maxf(_recul_dash_t - dt, 0.0)
	var k: float = _recul_dash_t / maxf(duree_recul_dash_s, 0.001)
	var direction: Vector2 = _direction_recul_dash
	if direction.length_squared() <= 0.0001:
		direction = Vector2.RIGHT
	else:
		direction = direction.normalized()
	var cible: Vector2 = -direction * recul_dash_camera_px * k
	_offset_recul_dash = _offset_recul_dash.lerp(cible, 1.0 - exp(-28.0 * dt))
	return _offset_recul_dash

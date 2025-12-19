extends Camera2D
class_name CamPlayer

@export_group("Cible")
@export var chemin_joueur: NodePath

var _joueur: Player = null

var _last_target: Node2D = null
var _last_target_pos: Vector2 = Vector2.ZERO
var _has_last: bool = false

var _vp: Viewport
var _vp_center: Vector2 = Vector2.ZERO
var _vp_inv_center: Vector2 = Vector2.ZERO

func _ready() -> void:
	make_current()
	_joueur = get_node_or_null(chemin_joueur) as Player

	_vp = get_viewport()
	if _vp:
		_vp.size_changed.connect(_maj_viewport_cache)
	_maj_viewport_cache()

func _process(dt: float) -> void:
	if dt <= 0.0:
		return
	if _joueur == null or not is_instance_valid(_joueur):
		return

	var target: Node2D = _joueur.get_camera_target()
	if target == null or not is_instance_valid(target):
		return

	if target != _last_target:
		_last_target = target
		_has_last = false

	var in_drive: bool = _joueur.est_en_conduite()

	var a_pos: float = 1.0 - exp(-_joueur.cam_follow_speed * dt)
	global_position = global_position.lerp(target.global_position, a_pos)

	var vel: Vector2 = _get_target_velocity(target, dt)
	var speed: float = vel.length()
	var dir: Vector2 = vel / speed if speed > 0.001 else Vector2.ZERO

	var mouse_norm: Vector2 = _get_mouse_norm()
	var mouse_len: float = mouse_norm.length()
	if mouse_len < _joueur.cam_mouse_deadzone:
		mouse_norm = Vector2.ZERO
		mouse_len = 0.0
	else:
		mouse_norm = mouse_norm.limit_length(1.0)
		mouse_norm.y *= _joueur.cam_mouse_influence_y
		mouse_len = clampf(mouse_len, 0.0, 1.0)

	var look_ahead: float = _joueur.cam_look_ahead_conduite_px if in_drive else _joueur.cam_look_ahead_sol_px
	var mouse_look: float = _joueur.cam_mouse_look_conduite_px if in_drive else _joueur.cam_mouse_look_sol_px

	var desired_offset: Vector2 = dir * look_ahead + mouse_norm * mouse_look
	desired_offset = desired_offset.limit_length(_joueur.cam_max_offset_px)

	var a_off: float = 1.0 - exp(-_joueur.cam_offset_speed * dt)
	offset = offset.lerp(desired_offset, a_off)

	var z_base: float = _joueur.cam_zoom_conduite if in_drive else _joueur.cam_zoom_sol
	var t_speed: float = clampf(speed / maxf(_joueur.cam_speed_for_max_zoom, 1.0), 0.0, 1.0)
	var mult_speed: float = lerpf(1.0, _joueur.cam_zoom_out_mult_at_max_speed, t_speed)
	var mult_mouse: float = lerpf(1.0, _joueur.cam_zoom_mouse_out_mult_at_edge, mouse_len)

	var z_target: float = z_base * mult_speed * mult_mouse
	var target_zoom: Vector2 = Vector2(z_target, z_target)

	var a_zoom: float = 1.0 - exp(-_joueur.cam_zoom_speed * dt)
	zoom = zoom.lerp(target_zoom, a_zoom)

func _maj_viewport_cache() -> void:
	if _vp == null:
		return
	var size := _vp.get_visible_rect().size
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

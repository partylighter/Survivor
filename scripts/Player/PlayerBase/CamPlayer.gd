extends Camera2D
class_name CamPlayer

@export_group("Groupes")
@export var groupe_joueur: StringName = &"joueur_principal"
@export var groupe_base: StringName = &"base_vehicle"

@export_group("Follow")
@export var follow_speed: float = 14.0
@export var offset_speed: float = 10.0
@export var zoom_speed: float = 8.0

@export_group("Zoom")
@export var zoom_sol: float = 1.15
@export var zoom_conduite: float = 0.85
@export var speed_for_max_zoom: float = 900.0
@export var zoom_out_mult_at_max_speed: float = 0.78
@export var zoom_mouse_out_mult_at_edge: float = 0.92

@export_group("Offset")
@export var look_ahead_sol_px: float = 90.0
@export var look_ahead_conduite_px: float = 170.0
@export var mouse_look_sol_px: float = 110.0
@export var mouse_look_conduite_px: float = 210.0
@export var mouse_deadzone: float = 0.06
@export var max_offset_px: float = 260.0
@export var mouse_influence_y: float = 0.85

@export_group("Refresh")
@export var refresh_interval_s: float = 0.4

var _joueur: Node2D = null
var _base_active: Node2D = null
var _refresh_t: float = 0.0

var _last_target: Node2D = null
var _last_target_pos: Vector2 = Vector2.ZERO
var _has_last: bool = false

func _ready() -> void:
	make_current()
	_refresh_targets(true)

func _physics_process(dt: float) -> void:
	if dt <= 0.0:
		return

	_refresh_t -= dt
	if _refresh_t <= 0.0:
		_refresh_targets(false)

	var target: Node2D = _get_target()
	if target == null:
		return

	if target != _last_target:
		_last_target = target
		_has_last = false

	var in_drive: bool = (target == _base_active and _is_driving(_base_active))

	var a_pos: float = 1.0 - exp(-follow_speed * dt)
	global_position = global_position.lerp(target.global_position, a_pos)

	var vel: Vector2 = _get_target_velocity(target, dt)
	var speed: float = vel.length()
	var inv_speed: float = 1.0 / speed if speed > 0.001 else 0.0
	var dir: Vector2 = vel * inv_speed

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
	desired_offset = desired_offset.limit_length(max_offset_px)

	var a_off: float = 1.0 - exp(-offset_speed * dt)
	offset = offset.lerp(desired_offset, a_off)

	var z_base: float = zoom_conduite if in_drive else zoom_sol

	var t_speed: float = clampf(speed / maxf(speed_for_max_zoom, 1.0), 0.0, 1.0)
	var mult_speed: float = lerpf(1.0, zoom_out_mult_at_max_speed, t_speed)

	var mult_mouse: float = lerpf(1.0, zoom_mouse_out_mult_at_edge, mouse_len)

	var z_target: float = z_base * mult_speed * mult_mouse
	var target_zoom: Vector2 = Vector2(z_target, z_target)

	var a_zoom: float = 1.0 - exp(-zoom_speed * dt)
	zoom = zoom.lerp(target_zoom, a_zoom)

func _refresh_targets(force: bool) -> void:
	_refresh_t = maxf(refresh_interval_s, 0.05)

	if force or _joueur == null or not is_instance_valid(_joueur):
		_joueur = get_tree().get_first_node_in_group(groupe_joueur) as Node2D

	_base_active = _find_active_base()

func _find_active_base() -> Node2D:
	var arr: Array = get_tree().get_nodes_in_group(groupe_base)
	var fallback: Node2D = null

	for n in arr:
		if not (n is Node2D) or not is_instance_valid(n):
			continue
		var nn: Node2D = n as Node2D
		if fallback == null:
			fallback = nn
		if _is_driving(nn):
			return nn

	return fallback

func _is_driving(n: Node) -> bool:
	if n == null or not is_instance_valid(n):
		return false
	var v = n.get("controle_actif")
	return typeof(v) == TYPE_BOOL and v

func _get_target() -> Node2D:
	if _base_active != null and is_instance_valid(_base_active) and _is_driving(_base_active):
		return _base_active
	if _joueur != null and is_instance_valid(_joueur):
		return _joueur
	if _base_active != null and is_instance_valid(_base_active):
		return _base_active
	return null

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
	var vp := get_viewport()
	if vp == null:
		return Vector2.ZERO

	var rect := vp.get_visible_rect()
	var size: Vector2 = rect.size
	if size.x <= 1.0 or size.y <= 1.0:
		return Vector2.ZERO

	var center: Vector2 = size * 0.5
	var d: Vector2 = vp.get_mouse_position() - center

	return Vector2(
		clampf(d.x / maxf(center.x, 1.0), -1.0, 1.0),
		clampf(d.y / maxf(center.y, 1.0), -1.0, 1.0)
	)

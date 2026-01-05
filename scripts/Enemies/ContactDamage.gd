extends Node
class_name ContactDamage

@export var degats_contact: int = 10
@export var delai_entre_hits_s: float = 0.45

@export var activation_radius_px: float = 900.0
@export var activation_hysteresis_px: float = 120.0

@export var check_interval_s: float = 0.08

@export var enemy_hit_offset_px: Vector2 = Vector2.ZERO
@export var enemy_hit_radius_px: float = 14.0

@export var groupe_hurtbox_joueur: StringName = &"player_hurtbox"
@export_node_path("Node2D") var chemin_enemy: NodePath = NodePath("..")

@export var debug_contact: bool = false
@export var debug_max_prints: int = 6

static var _prints_left: int = 0

var enemy: Node2D
var player_hurtbox: HurtBox

var _active: bool = false
var _r_on2: float = 0.0
var _r_off2: float = 0.0

var _bucket: int = 0
var _scan_frames: int = 1
var _next_hit_ms: int = 0
var _next_hb_retry_ms: int = 0
var _next_dbg_ms: int = 0

func _ready() -> void:
	if _prints_left <= 0:
		_prints_left = debug_max_prints

	enemy = get_node_or_null(chemin_enemy) as Node2D
	_recalc_radii()

	_scan_frames = _compute_scan_frames(check_interval_s)
	_bucket = randi() % _scan_frames

	player_hurtbox = _get_player_hurtbox()
	set_physics_process(false)

	if debug_contact:
		_dbg("ready enemy=" + str(enemy) + " scan_frames=" + str(_scan_frames) + " bucket=" + str(_bucket) + " group=" + String(groupe_hurtbox_joueur) + " hb=" + str(player_hurtbox))

func _compute_scan_frames(ci: float) -> int:
	var hz: int = max(Engine.physics_ticks_per_second, 1)
	var s: float = max(ci, 0.0)
	if s <= 0.0:
		return 1
	return maxi(1, int(round(s * float(hz))))

func _dbg(msg: String) -> void:
	if not debug_contact:
		return
	if _prints_left <= 0:
		return
	_prints_left -= 1
	print("[ContactDamage] ", msg)

func _recalc_radii() -> void:
	var r_on: float = max(activation_radius_px, 0.0)
	var r_off: float = r_on + max(activation_hysteresis_px, 0.0)
	_r_on2 = r_on * r_on
	_r_off2 = r_off * r_off

func _physics_process(_dt: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return

	if _scan_frames > 1:
		if ((Engine.get_physics_frames() + _bucket) % _scan_frames) != 0:
			return

	var now_ms: int = Time.get_ticks_msec()

	if player_hurtbox == null or not is_instance_valid(player_hurtbox):
		if now_ms >= _next_hb_retry_ms:
			_next_hb_retry_ms = now_ms + 250
			player_hurtbox = _get_player_hurtbox()

		if player_hurtbox == null:
			_active = false
			if debug_contact and now_ms >= _next_dbg_ms:
				_next_dbg_ms = now_ms + 1000
				_dbg("NO HURTBOX FOUND in group='" + String(groupe_hurtbox_joueur) + "'")
			return

	var ec: Vector2 = enemy.global_position + enemy_hit_offset_px
	var pc: Vector2 = player_hurtbox.hit_center()
	var d2: float = ec.distance_squared_to(pc)

	if _active:
		_active = d2 <= _r_off2
	else:
		_active = d2 <= _r_on2

	if not _active:
		return

	if now_ms < _next_hit_ms:
		return

	var rr: float = max(enemy_hit_radius_px, 0.0) + player_hurtbox.hit_radius()
	if d2 <= rr * rr:
		player_hurtbox.tek_it(degats_contact, enemy)
		_next_hit_ms = now_ms + int(max(delai_entre_hits_s, 0.0) * 1000.0)
		if debug_contact:
			_dbg("HIT dmg=" + str(degats_contact))

func _get_player_hurtbox() -> HurtBox:
	if groupe_hurtbox_joueur == &"":
		return null
	return get_tree().get_first_node_in_group(groupe_hurtbox_joueur) as HurtBox

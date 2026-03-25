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

# Cache statique partagé — un seul scan d'arbre par frame physique
# pour toutes les instances, au lieu d'un scan par ennemi
static var _hurtbox_cache: HurtBox = null
static var _hurtbox_cache_frame: int = -1
static var _prints_left: int = 0

var enemy: Node2D
var player_hurtbox: HurtBox

var _active: bool  = false
var _r_on2:  float = 0.0
var _r_off2: float = 0.0
var _r_off:  float = 0.0  # rayon désactivation non au carré — pour early exit AABB

var _bucket:      int = 0
var _scan_frames: int = 1

# Compteur frames au lieu de Time.get_ticks_msec() —
# évite un appel natif cross-language sur 4000 instances à chaque frame
var _frames_since_hit:   int = 0
var _hit_cooldown_frames: int = 0

# Retry hurtbox en frames
var _hb_retry_frames:   int = 0
var _hb_retry_cooldown: int = 15  # ~0.25s à 60hz

var _next_dbg_ms: int = 0

# ===========================================================================
# Initialisation
# ===========================================================================

func _ready() -> void:
	if _prints_left <= 0:
		_prints_left = debug_max_prints

	enemy        = get_node_or_null(chemin_enemy) as Node2D
	_recalc_radii()
	_scan_frames = _compute_scan_frames(check_interval_s)
	_bucket      = randi() % _scan_frames

	var hz: int = max(Engine.physics_ticks_per_second, 1)
	_hit_cooldown_frames = int(round(max(delai_entre_hits_s, 0.0) * float(hz)))
	_frames_since_hit    = _hit_cooldown_frames  # prêt à frapper dès le départ

	player_hurtbox = _get_player_hurtbox()
	set_physics_process(false)

	if debug_contact:
		_dbg("ready enemy=" + str(enemy)
			+ " scan_frames=" + str(_scan_frames)
			+ " bucket=" + str(_bucket)
			+ " group=" + String(groupe_hurtbox_joueur)
			+ " hb=" + str(player_hurtbox))

# ===========================================================================
# Boucle physique
# ===========================================================================

func _physics_process(_dt: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return

	# Bucket — n'exécute la logique qu'une frame sur _scan_frames
	if _scan_frames > 1:
		if ((Engine.get_physics_frames() + _bucket) % _scan_frames) != 0:
			return

	# Tick cooldown hit en frames
	if _frames_since_hit < _hit_cooldown_frames:
		_frames_since_hit += 1

	# Retry hurtbox si nécessaire
	if player_hurtbox == null or not is_instance_valid(player_hurtbox):
		_hb_retry_frames += 1
		if _hb_retry_frames >= _hb_retry_cooldown:
			_hb_retry_frames = 0
			player_hurtbox   = _get_player_hurtbox()
		if player_hurtbox == null:
			_active = false
			if debug_contact:
				var now_ms: int = Time.get_ticks_msec()
				if now_ms >= _next_dbg_ms:
					_next_dbg_ms = now_ms + 1000
					_dbg("NO HURTBOX FOUND in group='" + String(groupe_hurtbox_joueur) + "'")
			return

	var ec: Vector2 = enemy.global_position + enemy_hit_offset_px
	var pc: Vector2 = player_hurtbox.hit_center()

	# Early exit AABB — deux comparaisons scalaires avant distance_squared_to
	# Élimine la majorité des calculs quand le joueur est loin
	if abs(ec.x - pc.x) > _r_off or abs(ec.y - pc.y) > _r_off:
		_active = false
		return

	var d2: float = ec.distance_squared_to(pc)

	if _active:
		_active = d2 <= _r_off2
	else:
		_active = d2 <= _r_on2

	if not _active:
		return

	if _frames_since_hit < _hit_cooldown_frames:
		return

	var rr: float = max(enemy_hit_radius_px, 0.0) + player_hurtbox.hit_radius()
	if d2 <= rr * rr:
		player_hurtbox.tek_it(degats_contact, enemy)
		_frames_since_hit = 0
		if debug_contact:
			_dbg("HIT dmg=" + str(degats_contact))

# ===========================================================================
# Utilitaires
# ===========================================================================

func _compute_scan_frames(ci: float) -> int:
	var hz: int = max(Engine.physics_ticks_per_second, 1)
	var s: float = max(ci, 0.0)
	if s <= 0.0:
		return 1
	return maxi(1, int(round(s * float(hz))))

func _recalc_radii() -> void:
	var r_on: float = max(activation_radius_px, 0.0)
	_r_off          = r_on + max(activation_hysteresis_px, 0.0)
	_r_on2          = r_on * r_on
	_r_off2         = _r_off * _r_off

func _get_player_hurtbox() -> HurtBox:
	if groupe_hurtbox_joueur == &"":
		return null

	# Cache statique — un seul get_first_node_in_group par frame physique
	# partagé entre toutes les instances de ContactDamage
	var frame: int = Engine.get_physics_frames()
	if _hurtbox_cache_frame == frame:
		return _hurtbox_cache

	_hurtbox_cache_frame = frame
	if is_instance_valid(_hurtbox_cache):
		return _hurtbox_cache

	_hurtbox_cache = get_tree().get_first_node_in_group(groupe_hurtbox_joueur) as HurtBox
	return _hurtbox_cache

func _dbg(msg: String) -> void:
	if not debug_contact:
		return
	if _prints_left <= 0:
		return
	_prints_left -= 1
	print("[ContactDamage] ", msg)

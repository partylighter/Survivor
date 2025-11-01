extends ArmeBase
class_name ArmeContact

@export_node_path("HitBoxContact") var chemin_hitbox: NodePath
@export var flottement_amp_px: float = 6.0
@export var flottement_freq_hz: float = 1.0
@export var flottement_rot_deg: float = 3.0
@export var drop_distance_px: float = 36.0
@export var drop_duree_s: float = 0.28
@export var drop_arc_hauteur_px: float = 18.0
@export_enum("vertical","perp_dir") var drop_arc_mode: int = 0
@export var drop_amp_px: float = 12.0
@export var drop_freq_hz: float = 6.0
@export var drop_rot_deg: float = 6.0
@export var drop_scale_amp: float = 0.05
@export var rebond_nb: int = 2
@export var rebond_hauteur_px: float = 14.0
@export var rebond_duree_s: float = 0.18
@export var rebond_coef_hauteur: float = 0.55
@export var rebond_coef_duree: float = 0.8
@export var rebond_rot_deg: float = 4.0
@export var rebond_scale_amp: float = 0.035

var _hitbox: HitBoxContact
var _au_sol_prec: bool = false
var _flottement_actif: bool = false
var _base_y: float = 0.0

enum {ETAT_IDLE, ETAT_DROP, ETAT_REBOND}
var _etat: int = ETAT_IDLE

var _drop_t0: float = -1.0
var _drop_from: Vector2 = Vector2.ZERO
var _drop_to: Vector2 = Vector2.ZERO
var _drop_dir: Vector2 = Vector2.RIGHT

var _rebond_i: int = 0
var _rebond_t0: float = -1.0
var _rebond_duree: float = 0.0
var _rebond_haut: float = 0.0
var _rebond_base: Vector2 = Vector2.ZERO

func _ready() -> void:
	_hitbox = get_node(chemin_hitbox) as HitBoxContact
	_base_y = position.y
	_au_sol_prec = est_au_sol

func _process(_dt: float) -> void:
	if est_au_sol and not _au_sol_prec:
		var d: Vector2 = get_global_mouse_position() - global_position
		_drop_dir = (d.normalized() if d.length() > 0.001 else Vector2.RIGHT)
		_drop_from = global_position
		_drop_to = _drop_from + _drop_dir * drop_distance_px
		_drop_t0 = Time.get_ticks_msec() * 0.001
		_etat = ETAT_DROP
		_flottement_actif = false

	if _etat == ETAT_DROP:
		var now: float = Time.get_ticks_msec() * 0.001
		var t: float = clamp((now - _drop_t0) / drop_duree_s, 0.0, 1.0)
		var s: float = t * t * (3.0 - 2.0 * t)
		var base: Vector2 = _drop_from.lerp(_drop_to, s)
		var hump: float = sin(PI * s) * drop_arc_hauteur_px
		var offset_arc: Vector2 = Vector2(0, -hump) if drop_arc_mode == 0 else Vector2(-_drop_dir.y, _drop_dir.x) * hump
		var w: float = TAU * drop_freq_hz
		var damp: float = exp(-6.0 * t)
		var bounce_y: float = -sin(w * (now - _drop_t0)) * drop_amp_px * damp
		var rot: float = sin(w * (now - _drop_t0)) * drop_rot_deg * damp
		var pop: float = 1.0 + max(0.0, -sin(w * (now - _drop_t0))) * drop_scale_amp * damp
		global_position = base + offset_arc + Vector2(0, bounce_y)
		rotation_degrees = rot
		scale = Vector2(pop, pop)
		if t >= 1.0:
			_rebond_i = 0
			_rebond_duree = rebond_duree_s
			_rebond_haut = rebond_hauteur_px
			_rebond_base = _drop_to
			_rebond_t0 = now
			scale = Vector2.ONE
			_etat = ETAT_REBOND

	if _etat == ETAT_REBOND:
		var now2: float = Time.get_ticks_msec() * 0.001
		var u: float = clamp((now2 - _rebond_t0) / _rebond_duree, 0.0, 1.0)
		var su: float = u * u * (3.0 - 2.0 * u)
		var y_arc: float = sin(PI * su) * _rebond_haut
		global_position = _rebond_base + Vector2(0, -y_arc)
		var env: float = 1.0 - u
		rotation_degrees = sin(PI * u) * rebond_rot_deg * env
		var popu: float = 1.0 + sin(PI * su) * rebond_scale_amp * env
		scale = Vector2(popu, popu)
		if u >= 1.0:
			_rebond_i += 1
			if _rebond_i >= rebond_nb:
				rotation_degrees = 0.0
				scale = Vector2.ONE
				_base_y = position.y
				_flottement_actif = true
				_etat = ETAT_IDLE
			else:
				_rebond_haut *= rebond_coef_hauteur
				_rebond_duree *= rebond_coef_duree
				_rebond_t0 = now2

	if est_au_sol and _etat == ETAT_IDLE and _flottement_actif:
		var phase: float = Time.get_ticks_msec() * 0.001 * flottement_freq_hz * TAU
		position.y = _base_y + sin(phase) * flottement_amp_px
		rotation_degrees = sin(phase) * flottement_rot_deg
	elif not est_au_sol:
		_etat = ETAT_IDLE
		_flottement_actif = false
		rotation_degrees = 0.0
		scale = Vector2.ONE

	_au_sol_prec = est_au_sol

func attaquer() -> void:
	if not peut_attaquer():
		return
	if _hitbox == null:
		return
	_pret = false
	_hitbox.configurer(degats, recul_force, porteur)
	_hitbox.activer_pendant(duree_active_s)
	await get_tree().create_timer(cooldown_s).timeout
	_pret = true

func _maj_etat_pickup() -> void:
	if _pickup:
		_pickup.set_deferred("monitoring", est_au_sol)
		_pickup.set_deferred("monitorable", est_au_sol)
		_pickup.process_mode = (Node.PROCESS_MODE_INHERIT if not est_au_sol else Node.PROCESS_MODE_DISABLED)

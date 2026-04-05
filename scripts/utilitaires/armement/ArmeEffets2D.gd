extends Node
class_name ArmeEffets2D

class EffetsRuntime:
	var tir_recul_px: float = 10.0
	var tir_lift_px: float = 2.0
	var tir_rot_deg: float = 4.0
	var tir_kick_reactivite: float = 38.0
	var tir_retour: float = 22.0
	var tir_stack_max: float = 1.2
	var tir_shake_pos_px: float = 2.4
	var tir_shake_rot_deg: float = 1.2
	var tir_shake_fade: float = 18.0

@export_group("Flottement au sol")
@export var flottement_amp_px: float = 6.0
@export var flottement_freq_hz: float = 1.0
@export var flottement_rot_deg: float = 3.0

@export_group("Drop automatique")
@export var drop_distance_px: float = 36.0
@export var drop_duree_s: float = 0.28
@export var drop_arc_hauteur_px: float = 18.0
@export_enum("vertical","perp_dir") var drop_arc_mode: int = 0

@export_group("Drop: micro-oscillation")
@export var drop_amp_px: float = 12.0
@export var drop_freq_hz: float = 6.0
@export var drop_rot_deg: float = 6.0
@export var drop_scale_amp: float = 0.05

@export_group("Drop: rebonds")
@export var rebond_nb: int = 2
@export var rebond_hauteur_px: float = 14.0
@export var rebond_duree_s: float = 0.18
@export var rebond_coef_hauteur: float = 0.55
@export var rebond_coef_duree: float = 0.8
@export var rebond_rot_deg: float = 4.0
@export var rebond_scale_amp: float = 0.035

@export_group("Jet manuel")
@export var jet_distance_px: float = 80.0
@export var jet_duree_s: float = 0.22
@export var jet_arc_hauteur_px: float = 24.0
@export_enum("vertical","perp_dir") var jet_arc_mode: int = 0
@export var jet_amp_px: float = 10.0
@export var jet_freq_hz: float = 6.0
@export var jet_rot_deg: float = 8.0
@export var jet_scale_amp: float = 0.06

@export_group("Jet: rebonds")
@export var jet_rebond_nb: int = 2
@export var jet_rebond_hauteur_px: float = 12.0
@export var jet_rebond_duree_s: float = 0.16
@export var jet_rebond_coef_hauteur: float = 0.55
@export var jet_rebond_coef_duree: float = 0.8
@export var jet_rebond_rot_deg: float = 4.0
@export var jet_rebond_scale_amp: float = 0.03

@export_group("Tir: recoil + shake")
@export var tir_actif: bool = true
@export var tir_recul_px: float = 10.0
@export var tir_lift_px: float = 2.0
@export var tir_rot_deg: float = 4.0
@export var tir_kick_reactivite: float = 38.0
@export var tir_retour: float = 22.0
@export var tir_stack_max: float = 1.2
@export var tir_shake_pos_px: float = 2.4
@export var tir_shake_rot_deg: float = 1.2
@export var tir_shake_fade: float = 18.0

var cible: Node2D
var est_au_sol_prec: bool = false
var flottement_actif: bool = false
var base_y: float = 0.0

enum { ETAT_IDLE, ETAT_DROP, ETAT_REBOND, ETAT_JET }
var etat: int = ETAT_IDLE

var drop_t0: float = -1.0
var drop_de: Vector2 = Vector2.ZERO
var drop_vers: Vector2 = Vector2.ZERO
var drop_dir: Vector2 = Vector2.RIGHT

var jet_t0: float = -1.0
var jet_de: Vector2 = Vector2.ZERO
var jet_vers: Vector2 = Vector2.ZERO
var jet_dir: Vector2 = Vector2.RIGHT

var rebond_i: int = 0
var rebond_t0: float = -1.0
var rebond_duree_cur: float = 0.0
var rebond_hauteur_cur: float = 0.0
var rebond_base: Vector2 = Vector2.ZERO
var rebond_rot_cur: float = 0.0
var rebond_scale_cur: float = 0.0
var rebond_total: int = 0
var _rebond_coef_h_actif: float = 0.55
var _rebond_coef_t_actif: float = 0.8

var _tir_dir: Vector2 = Vector2.RIGHT
var _tir_t: float = 0.0
var _tir_shake: float = 0.0

var _tir_pos_off: Vector2 = Vector2.ZERO
var _tir_rot_off: float = 0.0
var _base_tir_recul_px: float = 10.0
var _base_tir_lift_px: float = 2.0
var _base_tir_rot_deg: float = 4.0
var _base_tir_kick_reactivite: float = 38.0
var _base_tir_retour: float = 22.0
var _base_tir_stack_max: float = 1.2
var _base_tir_shake_pos_px: float = 2.4
var _base_tir_shake_rot_deg: float = 1.2
var _base_tir_shake_fade: float = 18.0
var _rt_tir_recul_px: float = 10.0
var _rt_tir_lift_px: float = 2.0
var _rt_tir_rot_deg: float = 4.0
var _rt_tir_kick_reactivite: float = 38.0
var _rt_tir_retour: float = 22.0
var _rt_tir_stack_max: float = 1.2
var _rt_tir_shake_pos_px: float = 2.4
var _rt_tir_shake_rot_deg: float = 1.2
var _rt_tir_shake_fade: float = 18.0

func set_cible(n: Node2D) -> void:
	cible = n
	if cible:
		_snapshot_tir_authoring()
		reset_runtime()
		base_y       = cible.position.y
		_tir_pos_off = Vector2.ZERO
		_tir_rot_off = 0.0

func _snapshot_tir_authoring() -> void:
	_base_tir_recul_px = tir_recul_px
	_base_tir_lift_px = tir_lift_px
	_base_tir_rot_deg = tir_rot_deg
	_base_tir_kick_reactivite = tir_kick_reactivite
	_base_tir_retour = tir_retour
	_base_tir_stack_max = tir_stack_max
	_base_tir_shake_pos_px = tir_shake_pos_px
	_base_tir_shake_rot_deg = tir_shake_rot_deg
	_base_tir_shake_fade = tir_shake_fade

func refresh_authoring_snapshot() -> void:
	_snapshot_tir_authoring()

func get_authoring_signature() -> Array:
	return [
		tir_recul_px,
		tir_lift_px,
		tir_rot_deg,
		tir_kick_reactivite,
		tir_retour,
		tir_stack_max,
		tir_shake_pos_px,
		tir_shake_rot_deg,
		tir_shake_fade,
	]

func creer_runtime() -> EffetsRuntime:
	var rt := EffetsRuntime.new()
	rt.tir_recul_px = _base_tir_recul_px
	rt.tir_lift_px = _base_tir_lift_px
	rt.tir_rot_deg = _base_tir_rot_deg
	rt.tir_kick_reactivite = _base_tir_kick_reactivite
	rt.tir_retour = _base_tir_retour
	rt.tir_stack_max = _base_tir_stack_max
	rt.tir_shake_pos_px = _base_tir_shake_pos_px
	rt.tir_shake_rot_deg = _base_tir_shake_rot_deg
	rt.tir_shake_fade = _base_tir_shake_fade
	return rt

func appliquer_runtime(rt: EffetsRuntime) -> void:
	if rt == null:
		reset_runtime()
		return
	_rt_tir_recul_px = rt.tir_recul_px
	_rt_tir_lift_px = rt.tir_lift_px
	_rt_tir_rot_deg = rt.tir_rot_deg
	_rt_tir_kick_reactivite = rt.tir_kick_reactivite
	_rt_tir_retour = rt.tir_retour
	_rt_tir_stack_max = rt.tir_stack_max
	_rt_tir_shake_pos_px = rt.tir_shake_pos_px
	_rt_tir_shake_rot_deg = rt.tir_shake_rot_deg
	_rt_tir_shake_fade = rt.tir_shake_fade

func reset_runtime() -> void:
	_rt_tir_recul_px = _base_tir_recul_px
	_rt_tir_lift_px = _base_tir_lift_px
	_rt_tir_rot_deg = _base_tir_rot_deg
	_rt_tir_kick_reactivite = _base_tir_kick_reactivite
	_rt_tir_retour = _base_tir_retour
	_rt_tir_stack_max = _base_tir_stack_max
	_rt_tir_shake_pos_px = _base_tir_shake_pos_px
	_rt_tir_shake_rot_deg = _base_tir_shake_rot_deg
	_rt_tir_shake_fade = _base_tir_shake_fade


func stop_drop() -> void:
	if cible == null:
		return
	etat = ETAT_IDLE
	flottement_actif = false
	est_au_sol_prec = false
	_tir_t = 0.0
	_tir_shake = 0.0
	_tir_pos_off = Vector2.ZERO
	_tir_rot_off = 0.0
	if cible:
		cible.rotation_degrees = 0.0
		cible.scale = Vector2.ONE

func tick(now: float, est_au_sol: bool, dt: float) -> void:
	if cible == null:
		return

	# retirer l'overlay du frame précédent pour éviter la dérive
	if tir_actif:
		cible.position -= _tir_pos_off
		cible.rotation_degrees -= _tir_rot_off

	if etat == ETAT_IDLE and est_au_sol and not est_au_sol_prec:
		var d0: Vector2 = cible.get_global_mouse_position() - cible.global_position
		var dir: Vector2 = (d0.normalized() if d0.length() > 0.001 else Vector2.RIGHT)
		entrer_drop(dir)

	match etat:
		ETAT_DROP:
			maj_drop(now)
		ETAT_JET:
			maj_jet(now)
		ETAT_REBOND:
			maj_rebond(now)
		_:
			maj_idle(now, est_au_sol)

	_appliquer_tir_overlay(now, dt)
	est_au_sol_prec = est_au_sol

func entrer_drop(dir: Vector2) -> void:
	if cible == null:
		return
	drop_dir = dir
	drop_de = cible.global_position
	drop_vers = drop_de + drop_dir * drop_distance_px
	drop_t0 = Time.get_ticks_msec() * 0.001
	etat = ETAT_DROP
	flottement_actif = false

func maj_drop(now: float) -> void:
	if cible == null:
		return
	var t: float = clamp((now - drop_t0) / drop_duree_s, 0.0, 1.0)
	var s: float = t * t * (3.0 - 2.0 * t)
	var base_pos: Vector2 = drop_de.lerp(drop_vers, s)
	var bosse: float = sin(PI * s) * drop_arc_hauteur_px
	var offset: Vector2 = Vector2(0.0, -bosse) if drop_arc_mode == 0 else Vector2(-drop_dir.y, drop_dir.x) * bosse
	var w: float = TAU * drop_freq_hz
	var phase: float = w * (now - drop_t0)
	var amorti: float = exp(-6.0 * t)
	var reb: float = -sin(phase) * drop_amp_px * amorti
	var rot_val: float = sin(phase) * drop_rot_deg * amorti
	var pop_val: float = 1.0 + max(0.0, -sin(phase)) * drop_scale_amp * amorti
	cible.global_position = base_pos + offset + Vector2(0.0, reb)
	cible.rotation_degrees = rot_val
	cible.scale = Vector2(pop_val, pop_val)
	if t >= 1.0:
		entrer_rebond(drop_vers, rebond_nb, rebond_hauteur_px, rebond_duree_s, rebond_rot_deg, rebond_scale_amp, rebond_coef_hauteur, rebond_coef_duree)

func entrer_jet(dir: Vector2, dist_px: float = jet_distance_px) -> void:
	if cible == null:
		return
	var d: Vector2 = dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
	jet_dir = d
	jet_de = cible.global_position
	jet_vers = jet_de + d * dist_px
	jet_t0 = Time.get_ticks_msec() * 0.001
	etat = ETAT_JET
	flottement_actif = false
	est_au_sol_prec = false

func maj_jet(now: float) -> void:
	if cible == null:
		return
	var t: float = clamp((now - jet_t0) / jet_duree_s, 0.0, 1.0)
	var s: float = t * t * (3.0 - 2.0 * t)
	var base_pos: Vector2 = jet_de.lerp(jet_vers, s)
	var bosse: float = sin(PI * s) * jet_arc_hauteur_px
	var offset: Vector2 = Vector2(0.0, -bosse) if jet_arc_mode == 0 else Vector2(-jet_dir.y, jet_dir.x) * bosse
	var phase: float = TAU * 2.0 * s
	var amorti: float = exp(-6.0 * t)
	var reb: float = -sin(phase) * jet_amp_px * amorti
	var rot_val: float = sin(phase) * jet_rot_deg * amorti
	var pop_val: float = 1.0 + max(0.0, -sin(phase)) * jet_scale_amp * amorti
	cible.global_position = base_pos + offset + Vector2(0.0, reb)
	cible.rotation_degrees = rot_val
	cible.scale = Vector2(pop_val, pop_val)
	if t >= 1.0:
		cible.global_position = jet_vers
		entrer_rebond(jet_vers, jet_rebond_nb, jet_rebond_hauteur_px, jet_rebond_duree_s, jet_rebond_rot_deg, jet_rebond_scale_amp, jet_rebond_coef_hauteur, jet_rebond_coef_duree)

func entrer_rebond(base: Vector2, nb: int, haut_px: float, duree_s: float, rot_deg: float, scale_amp: float, coef_h: float, coef_t: float) -> void:
	if cible == null:
		return
	rebond_i = 0
	rebond_duree_cur = duree_s
	rebond_hauteur_cur = haut_px
	rebond_base = base
	rebond_rot_cur = rot_deg
	rebond_scale_cur = scale_amp
	rebond_total = nb
	_rebond_coef_h_actif = coef_h
	_rebond_coef_t_actif = coef_t
	rebond_t0 = Time.get_ticks_msec() * 0.001
	cible.scale = Vector2.ONE
	etat = ETAT_REBOND

func maj_rebond(now: float) -> void:
	if cible == null:
		return
	var u: float = clamp((now - rebond_t0) / rebond_duree_cur, 0.0, 1.0)
	var s: float = u * u * (3.0 - 2.0 * u)
	var y: float = sin(PI * s) * rebond_hauteur_cur
	cible.global_position = rebond_base + Vector2(0.0, -y)
	var env: float = 1.0 - u
	cible.rotation_degrees = sin(PI * u) * rebond_rot_cur * env
	var pop_val: float = 1.0 + sin(PI * s) * rebond_scale_cur * env
	cible.scale = Vector2(pop_val, pop_val)
	if u >= 1.0:
		rebond_i += 1
		if rebond_i >= rebond_total:
			cible.rotation_degrees = 0.0
			cible.scale = Vector2.ONE
			base_y = cible.position.y
			flottement_actif = true
			etat = ETAT_IDLE
		else:
			rebond_hauteur_cur *= _rebond_coef_h_actif
			rebond_duree_cur   *= _rebond_coef_t_actif
			rebond_t0 = now

func maj_idle(now: float, est_au_sol: bool) -> void:
	if cible == null:
		return
	if est_au_sol and flottement_actif:
		var phase: float = now * flottement_freq_hz * TAU
		cible.position.y = base_y + sin(phase) * flottement_amp_px
		cible.rotation_degrees = sin(phase) * flottement_rot_deg
	elif not est_au_sol:
		flottement_actif = false
		cible.rotation_degrees = 0.0
		cible.scale = Vector2.ONE

func jeter(direction: Vector2, distance_px: float = 80.0) -> void:
	entrer_jet(direction, distance_px)

func jeter_vers_souris() -> void:
	if cible == null:
		return
	var d: Vector2 = cible.get_global_mouse_position() - cible.global_position
	entrer_jet(d, jet_distance_px)

func kick_tir(dir: Vector2, intensite: float = 1.0) -> void:
	if cible == null or not tir_actif:
		return
	var d := dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
	_tir_dir = d
	intensite = clamp(intensite, 0.0, 3.0)
	_tir_t = min(_tir_t + intensite, _rt_tir_stack_max)
	_tir_shake = min(_tir_shake + intensite, 3.0)

func _appliquer_tir_overlay(now: float, dt: float) -> void:
	if cible == null or not tir_actif:
		return

	dt = max(dt, 0.000001)

	var a_kick: float = 1.0 - exp(-_rt_tir_kick_reactivite * dt)
	var a_ret: float  = 1.0 - exp(-_rt_tir_retour * dt)

	if _tir_t > 0.0001:
		_tir_t = lerp(_tir_t, 0.0, a_ret)
	else:
		_tir_t = 0.0

	if _tir_shake > 0.0001:
		_tir_shake = lerp(_tir_shake, 0.0, 1.0 - exp(-_rt_tir_shake_fade * dt))
	else:
		_tir_shake = 0.0

	# Calcul en espace monde, converti en local ensuite
	var cible_off_pos: Vector2 = Vector2.ZERO
	var cible_off_rot: float   = 0.0

	if _tir_t > 0.0:
		var recul: Vector2 = (-_tir_dir * _rt_tir_recul_px) + (Vector2.UP * _rt_tir_lift_px)
		cible_off_pos += recul * _tir_t
		cible_off_rot += _rt_tir_rot_deg * _tir_t

	if _tir_shake > 0.0:
		var n1: float = sin(now * 47.3) + sin(now * 91.7) * 0.5
		var n2: float = cos(now * 53.1) + cos(now * 79.9) * 0.5
		var v := Vector2(n1, n2)
		if v.length() > 0.0001:
			v = v.normalized()
		cible_off_pos += v * _rt_tir_shake_pos_px * _tir_shake
		cible_off_rot += sin(now * 63.2) * _rt_tir_shake_rot_deg * _tir_shake

	# _tir_dir vient de _forward_dir() (espace monde) → convertir en espace local du parent
	# pour que cible.position += offset soit cohérent avec l'orientation du porteur.
	var parent := cible.get_parent() as Node2D
	if parent:
		cible_off_pos = parent.get_global_transform().basis_xform_inv(cible_off_pos)

	# Un seul lerp selon l'état : actif → suit la cible rapidement, inactif → retour lent
	if _tir_t > 0.0 or _tir_shake > 0.0:
		_tir_pos_off = _tir_pos_off.lerp(cible_off_pos, a_kick)
		_tir_rot_off = lerp(_tir_rot_off, cible_off_rot, a_kick)
	else:
		_tir_pos_off = _tir_pos_off.lerp(Vector2.ZERO, a_ret)
		_tir_rot_off = lerp(_tir_rot_off, 0.0, a_ret)

	cible.position += _tir_pos_off
	cible.rotation_degrees += _tir_rot_off

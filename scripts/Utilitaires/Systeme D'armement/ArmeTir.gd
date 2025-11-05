extends ArmeBase
class_name ArmeTir

@export var scene_projectile: PackedScene
@export var vitesse_projectile: float = 1400.0

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

var au_sol_prec: bool = false
var flottement_actif: bool = false
var base_y: float = 0.0

enum { ETAT_IDLE, ETAT_DROP, ETAT_REBOND }
var etat: int = ETAT_IDLE

var drop_t0: float = -1.0
var drop_de: Vector2 = Vector2.ZERO
var drop_vers: Vector2 = Vector2.ZERO
var drop_dir: Vector2 = Vector2.RIGHT

var rebond_i: int = 0
var rebond_t0: float = -1.0
var rebond_duree: float = 0.0
var rebond_hauteur: float = 0.0
var rebond_base: Vector2 = Vector2.ZERO
var rebond_total: int = 0

func _ready() -> void:
	base_y = position.y
	au_sol_prec = est_au_sol

func _process(_dt: float) -> void:
	var maintenant: float = Time.get_ticks_msec() * 0.001
	if etat == ETAT_IDLE and est_au_sol and not au_sol_prec:
		var d: Vector2 = get_global_mouse_position() - global_position
		var dir: Vector2 = d.normalized() if d.length() > 0.001 else Vector2.RIGHT
		entrer_drop(dir)
	match etat:
		ETAT_DROP:
			maj_drop(maintenant)
		ETAT_REBOND:
			maj_rebond(maintenant)
		_:
			maj_idle(maintenant)
	au_sol_prec = est_au_sol

func entrer_drop(dir: Vector2) -> void:
	drop_dir = dir
	drop_de = global_position
	drop_vers = drop_de + drop_dir * drop_distance_px
	drop_t0 = Time.get_ticks_msec() * 0.001
	etat = ETAT_DROP
	flottement_actif = false

func maj_drop(now: float) -> void:
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
	global_position = base_pos + offset + Vector2(0.0, reb)
	rotation_degrees = rot_val
	scale = Vector2(pop_val, pop_val)
	if t >= 1.0:
		entrer_rebond(drop_vers, rebond_nb, rebond_hauteur_px, rebond_duree_s)

func entrer_rebond(base: Vector2, nb: int, hauteur_px: float, duree_s: float) -> void:
	rebond_i = 0
	rebond_total = nb
	rebond_duree = duree_s
	rebond_hauteur = hauteur_px
	rebond_base = base
	rebond_t0 = Time.get_ticks_msec() * 0.001
	scale = Vector2.ONE
	etat = ETAT_REBOND

func maj_rebond(now: float) -> void:
	var u: float = clamp((now - rebond_t0) / rebond_duree, 0.0, 1.0)
	var s: float = u * u * (3.0 - 2.0 * u)
	var y: float = sin(PI * s) * rebond_hauteur
	global_position = rebond_base + Vector2(0.0, -y)
	var env: float = 1.0 - u
	rotation_degrees = sin(PI * u) * rebond_rot_deg * env
	var pop_val: float = 1.0 + sin(PI * s) * rebond_scale_amp * env
	scale = Vector2(pop_val, pop_val)
	if u >= 1.0:
		rebond_i += 1
		if rebond_i >= rebond_total:
			rotation_degrees = 0.0
			scale = Vector2.ONE
			base_y = position.y
			flottement_actif = true
			etat = ETAT_IDLE
		else:
			rebond_hauteur *= rebond_coef_hauteur
			rebond_duree *= rebond_coef_duree
			rebond_t0 = now

func maj_idle(now: float) -> void:
	if est_au_sol and flottement_actif:
		var phase: float = now * flottement_freq_hz * TAU
		position.y = base_y + sin(phase) * flottement_amp_px
		rotation_degrees = sin(phase) * flottement_rot_deg
	elif not est_au_sol:
		etat = ETAT_IDLE
		flottement_actif = false
		rotation_degrees = 0.0
		scale = Vector2.ONE

func attaquer() -> void:
	if not peut_attaquer():
		return
	if scene_projectile == null:
		return
	_pret = false
	var p: Projectile = scene_projectile.instantiate() as Projectile
	if p == null:
		_pret = true
		return
	var pos_depart: Vector2 = global_position
	var pos_cible: Vector2 = get_global_mouse_position()
	var dir: Vector2 = (pos_cible - pos_depart).normalized()
	p.configurer(degats, dir, vitesse_projectile, recul_force, porteur)
	get_tree().current_scene.add_child(p)
	p.global_position = pos_depart
	await get_tree().create_timer(cooldown_s).timeout
	_pret = true

func _maj_etat_pickup() -> void:
	if _pickup:
		_pickup.set_deferred("monitoring", est_au_sol)
		_pickup.set_deferred("monitorable", est_au_sol)
		_pickup.process_mode = (Node.PROCESS_MODE_INHERIT if not est_au_sol else Node.PROCESS_MODE_DISABLED)

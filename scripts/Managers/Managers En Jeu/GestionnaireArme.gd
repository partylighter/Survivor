extends Node2D
class_name GestionnaireArme

enum PivotMode { SELF, PIVOT_NODE, MILIEU_SOCKETS }

@export_group("Refs")
@export_node_path("Node2D") var chemin_socket_principale: NodePath
@export_node_path("Node2D") var chemin_socket_secondaire: NodePath
@export_node_path("ZoneRamassage") var chemin_zone: NodePath
@export_node_path("Node2D") var chemin_pivot: NodePath
@export var pivot_mode: PivotMode = PivotMode.SELF

@export_group("Distances")
@export_range(0.0, 2000.0, 0.1) var distance_min: float = 300.0
@export_range(0.0, 2000.0, 0.1) var distance_max: float = 500.0
@export_range(0.0, 4000.0, 0.1) var distance_fusion_debut: float = 500.0
@export_range(0.0, 4000.0, 0.1) var distance_fusion_range: float = 200.0

@export_group("Stabilité FPS bas")
@export_range(0.002, 0.05, 0.001) var max_substep_s: float = 0.012

@export_group("Lissage adaptatif")
@export_range(0.1, 60.0, 0.1) var lissage_hz_proche: float = 8.0
@export_range(0.1, 60.0, 0.1) var lissage_hz_loin: float = 22.0
@export_range(0.01, 10.0, 0.01) var reactivite_main_secondaire: float = 1.35
@export_range(0.0, 40.0, 0.1) var vitesse_offset_max_rad_s: float = 10.0

@export_group("Filtre souris adaptatif")
@export_range(0.1, 60.0, 0.1) var souris_filtre_hz_proche: float = 10.0
@export_range(0.1, 60.0, 0.1) var souris_filtre_hz_loin: float = 35.0
@export_range(0.0, 12.0, 0.1) var souris_epsilon_px: float = 0.8

@export_group("Stabilité angle")
@export_range(0.0, 300.0, 1.0) var angle_lock_in_px: float = 22.0
@export_range(0.0, 450.0, 1.0) var angle_lock_out_px: float = 32.0

@export_group("Formation / Offset")
@export_range(0.0, TAU, 0.01) var avance_max: float = PI
@export_range(0.0, 64.0, 0.1) var ecart_lateral: float = 6.0
@export_range(0.1, 1.0, 0.01) var portee_main_principale: float = 1.0
@export_range(0.1, 1.0, 0.01) var portee_main_secondaire: float = 0.7
@export var auto_flip_visuel: bool = true

@export_group("Switch armes")
@export var switch_actif: bool = true
@export var action_switch_mains: StringName = &"switch_mains"

var zone: ZoneRamassage = null

var arme_principale: ArmeBase = null
var arme_secondaire: ArmeBase = null

var _socket_principale: Node2D = null
var _socket_secondaire: Node2D = null
var _pivot_node: Node2D = null
var _joueur: Player = null

var _dist_principale: float = 0.0
var _dist_secondaire: float = 0.0
var _angle_main_affiche: float = 0.0
var _angle_secondaire_affiche: float = 0.0
var _fusion_t: float = 0.0
var _offset_secondaire_affiche: float = PI

var _souris_filtre: Vector2 = Vector2.ZERO
var _has_souris: bool = false
var _angle_locked: bool = false

var _pivot_filtre: Vector2 = Vector2.ZERO
var _has_pivot: bool = false

var _main_principale_active: bool = true
var _main_secondaire_active: bool = true

const GROUPE_EQUIPEE := "__arme_equipee__"

func _ready() -> void:
	_socket_principale = get_node_or_null(chemin_socket_principale) as Node2D
	_socket_secondaire = get_node_or_null(chemin_socket_secondaire) as Node2D
	zone = get_node_or_null(chemin_zone) as ZoneRamassage
	_pivot_node = get_node_or_null(chemin_pivot) as Node2D
	_joueur = get_parent() as Player

	if _socket_principale == null or _socket_secondaire == null or zone == null or _joueur == null:
		set_physics_process(false)
		set_process(false)
		return

	_dist_principale = distance_max
	_dist_secondaire = distance_max
	_angle_main_affiche = 0.0
	_angle_secondaire_affiche = 0.0
	_fusion_t = 0.0
	_offset_secondaire_affiche = PI

	set_process(false)
	set_physics_process(true)

	_maj_main_vide_visu_et_process(true)

func _physics_process(dt: float) -> void:
	if dt <= 0.0:
		return

	_handle_inputs()

	var mouse_raw: Vector2 = get_global_mouse_position()

	var step: float = maxf(max_substep_s, 0.002)
	var n: int = int(ceil(dt / step))
	n = maxi(n, 1)
	var sdt: float = dt / float(n)

	for _i in range(n):
		_mettre_a_jour_sockets_step(sdt, mouse_raw)

func _alpha_from_hz(hz: float, dt: float) -> float:
	return 1.0 - exp(-maxf(hz, 0.001) * dt)

func _t_distance(dist: float) -> float:
	return clampf(dist / maxf(distance_max, 1.0), 0.0, 1.0)

func _hz_lissage(dist: float) -> float:
	return lerpf(lissage_hz_proche, lissage_hz_loin, _t_distance(dist))

func _hz_souris(dist: float) -> float:
	return lerpf(souris_filtre_hz_proche, souris_filtre_hz_loin, _t_distance(dist))

func _get_world_node() -> Node:
	return get_tree().current_scene

func _get_pivot_guess() -> Vector2:
	if pivot_mode == PivotMode.PIVOT_NODE:
		if _pivot_node != null and is_instance_valid(_pivot_node):
			return _pivot_node.global_position
		return global_position

	if pivot_mode == PivotMode.MILIEU_SOCKETS:
		if _socket_principale != null and _socket_secondaire != null:
			return (_socket_principale.global_position + _socket_secondaire.global_position) * 0.5
		return global_position

	return global_position

func _get_pivot_global(dt: float, dist_ref: float) -> Vector2:
	var raw: Vector2 = _get_pivot_guess()
	var a: float = _alpha_from_hz(_hz_souris(dist_ref), dt)

	if not _has_pivot:
		_pivot_filtre = raw
		_has_pivot = true
	else:
		_pivot_filtre = _pivot_filtre.lerp(raw, a)

	return _pivot_filtre

func _mettre_a_jour_sockets_step(dt: float, mouse_raw: Vector2) -> void:
	var pivot_guess: Vector2 = _get_pivot_guess()
	var dist_raw: float = (mouse_raw - pivot_guess).length()
	var pivot: Vector2 = _get_pivot_global(dt, dist_raw)

	if not _has_souris:
		_souris_filtre = mouse_raw
		_has_souris = true
	else:
		if mouse_raw.distance_to(_souris_filtre) > souris_epsilon_px:
			var am: float = _alpha_from_hz(_hz_souris(dist_raw), dt)
			_souris_filtre = _souris_filtre.lerp(mouse_raw, am)

	var cible: Vector2 = _souris_filtre
	var diff: Vector2 = cible - pivot
	var dist: float = diff.length()

	if _angle_locked:
		if dist > angle_lock_out_px:
			_angle_locked = false
	else:
		if dist < angle_lock_in_px:
			_angle_locked = true

	var angle_main_cible: float = _angle_main_affiche
	if not _angle_locked and dist > 0.0001:
		angle_main_cible = diff.angle()

	var a: float = _alpha_from_hz(_hz_lissage(dist), dt)

	var fusion_cible: float = _calculer_fusion_depuis_distance(dist)
	_fusion_t = lerp(_fusion_t, fusion_cible, a)

	var offset_target_raw: float = _calculer_offset_continu(dist)
	var max_step: float = vitesse_offset_max_rad_s * dt
	var delta_off: float = wrapf(offset_target_raw - _offset_secondaire_affiche, -PI, PI)
	delta_off = clampf(delta_off, -max_step, max_step)
	_offset_secondaire_affiche += delta_off

	_angle_main_affiche = lerp_angle(_angle_main_affiche, angle_main_cible, a)
	_angle_secondaire_affiche = wrapf(_angle_main_affiche + _offset_secondaire_affiche, -PI, PI)

	var distance_cible: float = clampf(dist, distance_min, distance_max)
	var cible_dist_main: float = distance_cible * portee_main_principale
	var cible_dist_secondaire: float = distance_cible * portee_main_secondaire

	_dist_principale = lerpf(_dist_principale, cible_dist_main, a)
	_dist_secondaire = lerpf(_dist_secondaire, cible_dist_secondaire, clampf(a * reactivite_main_secondaire, 0.0, 1.0))

	var dir_main: Vector2 = Vector2(cos(_angle_main_affiche), sin(_angle_main_affiche))
	var dir_secondaire: Vector2 = Vector2(cos(_angle_secondaire_affiche), sin(_angle_secondaire_affiche))
	var dir_perp: Vector2 = Vector2(-dir_main.y, dir_main.x)
	var offset_vec: Vector2 = dir_perp * ecart_lateral * _fusion_t

	_socket_principale.position = dir_main * _dist_principale + offset_vec
	_socket_secondaire.position = dir_secondaire * _dist_secondaire - offset_vec
	_socket_principale.rotation = _angle_main_affiche
	_socket_secondaire.rotation = _angle_secondaire_affiche

	if auto_flip_visuel:
		_appliquer_flip_visuel(_socket_principale, _angle_main_affiche)
		_appliquer_flip_visuel(_socket_secondaire, _angle_secondaire_affiche)

func _fusion_r1() -> float:
	return maxf(distance_fusion_debut, 0.0)

func _fusion_r2() -> float:
	return maxf(_fusion_r1() + maxf(distance_fusion_range, 0.0), _fusion_r1() + 0.001)

func _calculer_fusion_depuis_distance(dist: float) -> float:
	var r1: float = _fusion_r1()
	var r2: float = _fusion_r2()

	if dist <= r1:
		return 0.0
	if dist >= r2:
		return 1.0

	return clampf((dist - r1) / (r2 - r1), 0.0, 1.0)

func _calculer_offset_continu(dist: float) -> float:
	var r1: float = _fusion_r1()
	var r2: float = _fusion_r2()

	var t: float
	if dist <= r1:
		t = 0.0
	elif dist >= r2:
		t = 1.0
	else:
		t = (dist - r1) / (r2 - r1)

	t = clampf(t, 0.0, 1.0)
	return lerpf(PI, -avance_max, t)

func _set_pickup_enabled(a: Node, enabled: bool) -> void:
	if a == null or not is_instance_valid(a):
		return
	if a.has_method("set_pickup_enabled"):
		a.set_pickup_enabled(enabled)
		return
	if a.has_node("Pickup"):
		var p: Node = a.get_node("Pickup")
		if p is Area2D:
			var area := p as Area2D
			area.set_deferred("monitoring", enabled)
			area.set_deferred("monitorable", enabled)

func _apply_pickup_lockout(a: Node, ms: int) -> void:
	if a == null or not is_instance_valid(a):
		return
	var id: int = 1
	if a.has_meta("lockout_id"):
		id = int(a.get_meta("lockout_id")) + 1
	a.set_meta("lockout_id", id)
	_set_pickup_enabled(a, false)
	await get_tree().create_timer(float(ms) * 0.001).timeout
	if a == null or not is_instance_valid(a):
		return
	if not a.has_meta("lockout_id") or int(a.get_meta("lockout_id")) != id:
		return
	_set_pickup_enabled(a, true)

func _marquer_equipee(a: Node, etat: bool) -> void:
	if a == null or not is_instance_valid(a):
		return
	if etat:
		if not a.is_in_group(GROUPE_EQUIPEE):
			a.add_to_group(GROUPE_EQUIPEE)
		a.set_meta("equipped", true)
	else:
		if a.is_in_group(GROUPE_EQUIPEE):
			a.remove_from_group(GROUPE_EQUIPEE)
		a.set_meta("equipped", false)

func _est_equipee(n: Node) -> bool:
	if n == null or not is_instance_valid(n):
		return false
	if n == arme_principale or n == arme_secondaire:
		return true
	var parent := n.get_parent()
	if parent == _socket_principale or parent == _socket_secondaire:
		return true
	var meta_bool: bool = false
	if n.has_meta("equipped"):
		meta_bool = bool(n.get_meta("equipped"))
	return n.is_in_group(GROUPE_EQUIPEE) or meta_bool

func _essayer_ramasser() -> void:
	if zone == null or not is_instance_valid(zone):
		return

	if arme_principale != null and arme_secondaire != null:
		return

	var ref_pos: Vector2 = global_position
	if _joueur != null and is_instance_valid(_joueur):
		ref_pos = _joueur.global_position

	var cible: Node2D = null
	if zone.has_method("get_pickable_le_plus_proche"):
		cible = zone.get_pickable_le_plus_proche(ref_pos)
	elif zone.has_method("get_loot_le_plus_proche"):
		cible = zone.get_loot_le_plus_proche(ref_pos)

	if cible == null or not is_instance_valid(cible):
		return

	if _est_equipee(cible):
		return

	if cible.has_method("prendre_scene"):
		var ps: PackedScene = cible.prendre_scene()
		if ps == null:
			return
		var n: Node = ps.instantiate()
		if n is ArmeBase:
			var arme: ArmeBase = n as ArmeBase
			arme.scene_source = ps
			if arme_principale == null:
				equiper_arme_principale(arme)
			else:
				equiper_arme_secondaire(arme)
			cible.queue_free()
		else:
			n.queue_free()
		return

	if cible is ArmeBase:
		var arme_sol: ArmeBase = cible as ArmeBase
		if arme_sol == arme_principale or arme_sol == arme_secondaire:
			return
		var parent: Node = arme_sol.get_parent()
		if parent:
			parent.remove_child(arme_sol)
		if arme_principale == null:
			equiper_arme_principale(arme_sol)
		else:
			equiper_arme_secondaire(arme_sol)
		_set_pickup_enabled(arme_sol, false)

func equiper_arme_principale(a: ArmeBase) -> void:
	if a == null or a == arme_secondaire:
		return
	_stopper_drop_si_effets(a)
	arme_principale = a
	a.equipe_par(_joueur)
	_socket_principale.add_child(a)
	a.top_level = false
	a.position = Vector2.ZERO
	a.rotation = 0.0
	a.scale = Vector2.ONE
	_angle_main_affiche = _socket_principale.rotation
	_set_pickup_enabled(a, false)
	_marquer_equipee(a, true)
	_maj_main_vide_visu_et_process()

func equiper_arme_secondaire(a: ArmeBase) -> void:
	if a == null or a == arme_principale:
		return
	_stopper_drop_si_effets(a)
	arme_secondaire = a
	a.equipe_par(_joueur)
	_socket_secondaire.add_child(a)
	a.top_level = false
	a.position = Vector2.ZERO
	a.rotation = 0.0
	a.scale = Vector2.ONE
	_angle_secondaire_affiche = _socket_secondaire.rotation
	_offset_secondaire_affiche = PI
	_set_pickup_enabled(a, false)
	_marquer_equipee(a, true)
	_maj_main_vide_visu_et_process()

func _liberer_interne(main_droite: bool, mode_jet: bool, lockout_ms: int) -> void:
	var a: ArmeBase = arme_principale if main_droite else arme_secondaire
	var s: Node2D = _socket_principale if main_droite else _socket_secondaire
	if a == null or s == null:
		return
	if not is_instance_valid(a):
		if main_droite:
			arme_principale = null
		else:
			arme_secondaire = null
		_maj_main_vide_visu_et_process()
		return

	_detach_to_world(a, s)
	a.liberer_au_sol()
	_marquer_equipee(a, false)
	_apply_pickup_lockout(a, lockout_ms)

	if mode_jet:
		var gp: Vector2 = s.global_position
		var d: Vector2 = get_global_mouse_position() - gp
		var dir: Vector2 = d.normalized() if d.length() > 0.0001 else Vector2.RIGHT
		if a.has_method("jeter"):
			a.call("jeter", dir)
		elif a.has_method("jeter_vers_souris"):
			a.call("jeter_vers_souris")

	if a == arme_principale:
		arme_principale = null
	else:
		arme_secondaire = null

	_maj_main_vide_visu_et_process()

func _lacher(main_droite: bool) -> void:
	_liberer_interne(main_droite, false, 250)

func _jeter(main_droite: bool) -> void:
	_liberer_interne(main_droite, true, 250)

func _detach_to_world(a: Node2D, s: Node2D) -> void:
	var world: Node = _get_world_node()
	var gp: Vector2 = s.global_position
	var gr: float = s.global_rotation
	var parent := a.get_parent()
	if parent:
		parent.remove_child(a)
	world.add_child(a)
	a.global_position = gp
	a.global_rotation = gr

func _stopper_drop_si_effets(a: ArmeBase) -> void:
	if a == null:
		return
	if a is ArmeContact:
		var ac := a as ArmeContact
		if ac.effets:
			ac.stop_drop()
	elif a is ArmeTir:
		var at := a as ArmeTir
		if at.effets:
			at.stop_drop()

func _handle_inputs() -> void:
	if Input.is_action_just_pressed("ramasser"):
		_essayer_ramasser()
	if Input.is_action_just_pressed("lacher_main_droite"):
		_lacher(true)
	if Input.is_action_just_pressed("lacher_main_gauche"):
		_lacher(false)
	if Input.is_action_just_pressed("jeter_main_droite"):
		_jeter(true)
	if Input.is_action_just_pressed("jeter_main_gauche"):
		_jeter(false)
	if switch_actif and Input.is_action_just_pressed(action_switch_mains):
		_switch_mains()

func _switch_mains() -> void:
	if _socket_principale == null or _socket_secondaire == null:
		return

	if arme_principale == null and arme_secondaire == null:
		return

	var a1: ArmeBase = arme_principale
	var a2: ArmeBase = arme_secondaire

	arme_principale = a2
	arme_secondaire = a1

	if is_instance_valid(a1):
		var p := a1.get_parent()
		if p:
			p.remove_child(a1)
		_socket_secondaire.add_child(a1)
		a1.top_level = false
		a1.position = Vector2.ZERO
		a1.rotation = 0.0
		a1.scale = Vector2.ONE

	if is_instance_valid(a2):
		var p2 := a2.get_parent()
		if p2:
			p2.remove_child(a2)
		_socket_principale.add_child(a2)
		a2.top_level = false
		a2.position = Vector2.ZERO
		a2.rotation = 0.0
		a2.scale = Vector2.ONE

	_offset_secondaire_affiche = PI
	_maj_main_vide_visu_et_process()

func _appliquer_flip_visuel(n: Node2D, angle: float) -> void:
	var ang: float = wrapf(angle, -PI, PI)
	var deg: float = abs(rad_to_deg(ang))
	var etat: bool = (n.get_meta("flip_v") if n.has_meta("flip_v") else false)
	var doit_flip: bool = etat
	if not etat and deg > 100.0:
		doit_flip = true
	elif etat and deg < 80.0:
		doit_flip = false
	n.set_meta("flip_v", doit_flip)
	var vis: Node2D = n.get_node_or_null("Sprite") as Node2D
	if vis == null:
		vis = n
	var sc: Vector2 = vis.scale
	sc.y = -1.0 if doit_flip else 1.0
	vis.scale = sc

func _trouver_visuel_main(socket: Node) -> CanvasItem:
	if socket == null:
		return null

	var n_sprite := socket.get_node_or_null("Sprite")
	if n_sprite != null and n_sprite is CanvasItem and not (n_sprite is ArmeBase):
		return n_sprite as CanvasItem

	var stack: Array = [socket]
	while not stack.is_empty():
		var n: Node = stack.pop_back()

		if n is ArmeBase:
			continue

		if n != socket and n is CanvasItem:
			return n as CanvasItem

		for c in n.get_children():
			if c is ArmeBase:
				continue
			stack.append(c)

	return null

func _set_process_tree_main(n: Node, enabled: bool) -> void:
	if n == null:
		return
	if n is ArmeBase:
		return
	n.set_process(enabled)
	n.set_physics_process(enabled)
	for c in n.get_children():
		if c is ArmeBase:
			continue
		_set_process_tree_main(c, enabled)

func _set_hand_state(socket: Node2D, active: bool) -> void:
	if socket == null:
		return

	var vis: CanvasItem = _trouver_visuel_main(socket)

	if vis != null:
		vis.visible = active
		_set_process_tree_main(vis, active)
		return

	if socket is CanvasItem:
		(socket as CanvasItem).visible = active
		_set_process_tree_main(socket, active)

func _maj_main_vide_visu_et_process(force: bool = false) -> void:
	var active_p: bool = (arme_principale != null)
	var active_s: bool = (arme_secondaire != null)

	if force or active_p != _main_principale_active:
		_main_principale_active = active_p
		_set_hand_state(_socket_principale, active_p)

	if force or active_s != _main_secondaire_active:
		_main_secondaire_active = active_s
		_set_hand_state(_socket_secondaire, active_s)

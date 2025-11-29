extends Node2D
class_name GestionnaireArme

@export_node_path("Node2D") var chemin_socket_principale: NodePath
@export_node_path("Node2D") var chemin_socket_secondaire: NodePath
@export_node_path("ZoneRamassage") var chemin_zone: NodePath
var zone: ZoneRamassage

@export_range(0.0, 1000.0, 0.1) var distance_min: float = 300.0
@export_range(0.0, 1000.0, 0.1) var distance_max: float = 500.0
@export_range(0.0, 5.0, 0.01) var vitesse_lissage: float = 0.05
@export_range(0.01, 10.0, 0.01) var reactivite_main_secondaire: float = 1.0
@export_range(0.1, 30.0, 0.1) var raideur_hz: float = 10.0
@export_range(0.0, 6.283, 0.01) var vitesse_offset_max_rad_s: float = 3.0
@export_range(0.0, 5000.0, 0.1) var rayon_proche: float = 800.0
@export_range(0.0, 5000.0, 0.1) var rayon_loin: float = 1500.0
@export_range(0.0, 3.14159, 0.01) var avance_max: float = PI * 3.14
@export_range(0.0, 64.0, 0.1) var ecart_lateral: float = 6.0
@export_range(0.1, 1.0, 0.01) var portee_main_principale: float = 1.0
@export_range(0.1, 1.0, 0.01) var portee_main_secondaire: float = 0.7
@export var auto_flip_visuel: bool = true

var arme_principale: ArmeBase = null
var arme_secondaire: ArmeBase = null

var _socket_principale: Node2D
var _socket_secondaire: Node2D
var _joueur: Player

var _dist_principale: float
var _dist_secondaire: float
var _angle_main_affiche: float
var _angle_secondaire_affiche: float
var _fusion_t: float = 0.0
var _offset_secondaire_affiche: float = PI

const GROUPE_EQUIPEE := "__arme_equipee__"

func _ready() -> void:
	_socket_principale = get_node_or_null(chemin_socket_principale) as Node2D
	_socket_secondaire = get_node_or_null(chemin_socket_secondaire) as Node2D
	zone = get_node_or_null(chemin_zone) as ZoneRamassage
	_joueur = get_parent() as Player
	if _socket_principale == null or _socket_secondaire == null or zone == null or _joueur == null:
		set_process(false)
		return
	_dist_principale = distance_max
	_dist_secondaire = distance_max
	_angle_main_affiche = 0.0
	_angle_secondaire_affiche = 0.0
	_fusion_t = 0.0
	_offset_secondaire_affiche = PI

func _process(dt: float) -> void:
	_handle_inputs()
	_mettre_a_jour_sockets(dt)

func _alpha(dt: float) -> float:
	return 1.0 - exp(-dt * raideur_hz)

func _get_world_node() -> Node:
	return get_tree().current_scene

func _set_pickup_enabled(a: Node, enabled: bool) -> void:
	if a == null:
		return
	if a.has_method("set_pickup_enabled"):
		a.set_pickup_enabled(enabled)
	elif a.has_node("Pickup"):
		var p: Node = a.get_node("Pickup")
		if p is Area2D:
			var area := p as Area2D
			area.monitoring = enabled
			area.monitorable = enabled

func _apply_pickup_lockout(a: Node, ms: int) -> void:
	_set_pickup_enabled(a, false)
	await get_tree().create_timer(float(ms) * 0.001).timeout
	_set_pickup_enabled(a, true)

func _marquer_equipee(a: Node, etat: bool) -> void:
	if a == null:
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
	if n == null:
		return false
	if n == arme_principale or n == arme_secondaire:
		return true
	if n.get_parent() == _socket_principale or n.get_parent() == _socket_secondaire:
		return true
	var meta_bool: bool = (bool(n.get_meta("equipped")) if n.has_meta("equipped") else false)
	return n.is_in_group(GROUPE_EQUIPEE) or meta_bool

func _mettre_a_jour_sockets(dt: float) -> void:
	var cible: Vector2 = get_global_mouse_position()
	var diff: Vector2 = cible - global_position
	var dist: float = diff.length()
	if dist < 0.001:
		diff = Vector2.RIGHT * 0.001
		dist = 0.001
	var angle_main_cible: float = diff.angle()
	var fusion_cible: float = _calculer_fusion_depuis_distance(dist)
	var a: float = clamp(_alpha(dt) * clamp(vitesse_lissage, 0.0, 1.0), 0.0, 1.0)
	_fusion_t = lerp(_fusion_t, fusion_cible, a)
	var offset_target_raw: float = _calculer_offset_continu(dist)
	var max_step: float = vitesse_offset_max_rad_s * dt
	var delta_off: float = wrapf(offset_target_raw - _offset_secondaire_affiche, -PI, PI)
	delta_off = clamp(delta_off, -max_step, max_step)
	_offset_secondaire_affiche += delta_off
	_angle_main_affiche = lerp_angle(_angle_main_affiche, angle_main_cible, a)
	_angle_secondaire_affiche = wrapf(_angle_main_affiche + _offset_secondaire_affiche, -PI, PI)
	var distance_cible: float = clamp(dist, distance_min, distance_max)
	var cible_dist_main: float = distance_cible * portee_main_principale
	var cible_dist_secondaire: float = distance_cible * portee_main_secondaire
	_dist_principale = lerp(_dist_principale, cible_dist_main, a)
	_dist_secondaire = lerp(_dist_secondaire, cible_dist_secondaire, a * reactivite_main_secondaire)
	var dir_main: Vector2 = Vector2(cos(_angle_main_affiche), sin(_angle_main_affiche))
	var dir_secondaire: Vector2 = Vector2(cos(_angle_secondaire_affiche), sin(_angle_secondaire_affiche))
	var dir_perp: Vector2 = Vector2(-dir_main.y, dir_main.x)
	var offset_vec: Vector2 = dir_perp * ecart_lateral * _fusion_t
	_socket_principale.position  = dir_main       * _dist_principale  + offset_vec
	_socket_secondaire.position = dir_secondaire * _dist_secondaire - offset_vec
	_socket_principale.rotation = _angle_main_affiche
	_socket_secondaire.rotation = _angle_secondaire_affiche
#	if is_instance_valid(arme_principale):
#		arme_principale.rotation = _angle_main_affiche
#	if is_instance_valid(arme_secondaire):
#		arme_secondaire.rotation = _angle_secondaire_affiche
	if auto_flip_visuel:
		_appliquer_flip_visuel(_socket_principale, _angle_main_affiche)
		_appliquer_flip_visuel(_socket_secondaire, _angle_secondaire_affiche)

func _essayer_ramasser() -> void:
	if not is_instance_valid(zone):
		return
	var main_libre: bool = (arme_principale == null) or (arme_secondaire == null)
	var ref_pos: Vector2 = (_joueur.global_position if is_instance_valid(_joueur) else global_position)
	var cible: Node2D = null
	if zone.has_method("get_pickable_le_plus_proche"):
		cible = zone.get_pickable_le_plus_proche(ref_pos)
	elif zone.has_method("get_loot_le_plus_proche"):
		cible = zone.get_loot_le_plus_proche(ref_pos)
	if cible == null:
		return
	if _est_equipee(cible):
		return
	if cible.has_method("prendre_scene"):
		if not main_libre:
			return
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
		if not main_libre:
			return
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
		return


#pas touche ou je te defonce
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

func _calculer_fusion_depuis_distance(dist: float) -> float:
	var r1: float = rayon_proche
	var r2: float = max(rayon_loin, r1 + 0.001)
	if dist <= r1:
		return 0.0
	if dist >= r2:
		return 1.0
	var ratio: float = (dist - r1) / (r2 - r1)
	return clamp(ratio, 0.0, 1.0)

func _calculer_offset_continu(dist: float) -> float:
	var r_start: float = rayon_proche
	var r_end: float = max(max(distance_max, rayon_loin), r_start + 0.001)
	var t_global: float = clamp((dist - r_start) / (r_end - r_start), 0.0, 1.0)
	return lerp(PI, -avance_max, t_global)

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

func _liberer_interne(main_droite: bool, mode_jet: bool, _force: float, _ang_vel: float, lockout_ms: int) -> void:
	var a: ArmeBase = (arme_principale if main_droite else arme_secondaire)
	var s: Node2D = (_socket_principale if main_droite else _socket_secondaire)
	if a == null or s == null:
		return
	if not is_instance_valid(a):
		if main_droite:
			arme_principale = null
		else:
			arme_secondaire = null
		return
	_detach_to_world(a, s)
	a.liberer_au_sol()
	_marquer_equipee(a, false)
	_apply_pickup_lockout(a, lockout_ms)
	if mode_jet:
		var gp: Vector2 = s.global_position
		var d: Vector2 = get_global_mouse_position() - gp
		var dir: Vector2 = (d.normalized() if d.length() > 0.0001 else Vector2.RIGHT)
		if a.has_method("jeter"):
			a.call("jeter", dir)
		elif a.has_method("jeter_vers_souris"):
			a.call("jeter_vers_souris")
	if a == arme_principale:
		arme_principale = null
	else:
		arme_secondaire = null

func _lacher(main_droite: bool) -> void:
	_liberer_interne(main_droite, false, 0.0, 0.0, 250)

func _jeter(main_droite: bool) -> void:
	_liberer_interne(main_droite, true, 1.0, 0.0, 250)

func _detach_to_world(a: Node2D, s: Node2D) -> void:
	var world: Node = _get_world_node()
	var gp: Vector2 = s.global_position
	var gr: float = s.global_rotation
	if a.get_parent():
		a.get_parent().remove_child(a)
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

func _spawn_item(s: Node2D, scene_src: PackedScene) -> Node2D:
	if scene_src == null:
		return null
	var item: Node2D = scene_src.instantiate() as Node2D
	if item == null:
		return null
	item.global_position = s.global_position
	_get_world_node().add_child(item)
	return item

extends ArmeBase
class_name ArmeTir

@export var scene_projectile: PackedScene
@export_node_path("ArmeEffets2D") var chemin_effets: NodePath
@export_node_path("Node2D") var chemin_socket_muzzle: NodePath
@export_node_path("Node") var chemin_racine_projectiles: NodePath
@export_range(1, 10000, 1) var nb_balles: int = 1
@export_range(0.0, 60.0, 0.1) var dispersion_deg: float = 0.0  
@export var debug_tir: bool = false
@export var hitscan: bool = false
@export var tir_max_par_frame: int = 20
@export var portee_hitscan_px: float = 2000.0
@export var mask_tir: int = 0

var effets: ArmeEffets2D
var _muzzle: Node2D
var _root_proj: Node
var _pool: Array[Projectile] = []
var _cooldown_fin_s: float = 0.0

func _ready() -> void:
	if chemin_effets != NodePath():
		effets = get_node(chemin_effets) as ArmeEffets2D
	if effets:
		effets.set_cible(self)

	if chemin_socket_muzzle != NodePath():
		_muzzle = get_node(chemin_socket_muzzle) as Node2D

	_root_proj = null

	if chemin_racine_projectiles != NodePath():
		_root_proj = get_node_or_null(chemin_racine_projectiles)

	if _root_proj == null:
		_root_proj = get_node_or_null("/root/ProjectileHub")

	if _root_proj == null:
		var cs: Node = get_tree().current_scene
		_root_proj = cs.get_node_or_null("Projectiles")

	if _root_proj == null:
		var p: Node2D = Node2D.new()
		p.name = "Projectiles"
		p.top_level = true  # ignore la transform du parent
		get_tree().current_scene.add_child(p)
		_root_proj = p

func _offset_eventail(i: int, n: int, spread_rad: float) -> float:
	if n <= 1 or spread_rad <= 0.0:
		return 0.0
	return lerp(-spread_rad * 0.5, spread_rad * 0.5, float(i) / float(n - 1))


func _process(_dt: float) -> void:
	if effets:
		effets.tick(Time.get_ticks_msec() * 0.001, est_au_sol)
	if not _pret and Time.get_ticks_msec() * 0.001 >= _cooldown_fin_s:
		_pret = true

func jeter(direction: Vector2, distance_px: float = 80.0) -> void:
	if effets:
		effets.jeter(direction, distance_px)

func jeter_vers_souris(distance_px: float = 80.0) -> void:
	if effets:
		effets.jet_distance_px = distance_px
		effets.jeter_vers_souris()

func _muzzle_pos() -> Vector2:
	if is_instance_valid(_muzzle):
		return _muzzle.global_position
	return global_position

func _forward_dir() -> Vector2:
	var ang: float
	if is_instance_valid(_muzzle):
		ang = _muzzle.global_rotation
	else:
		ang = global_rotation
	return Vector2.RIGHT.rotated(ang)

func attaquer() -> void:
	var now: float = Time.get_ticks_msec() * 0.001
	if not peut_attaquer():
		return
	if not hitscan and scene_projectile == null:
		return
	if now < _cooldown_fin_s:
		return

	_pret = false
	_cooldown_fin_s = now + cooldown_s

	var from: Vector2 = _muzzle_pos()
	var dir0: Vector2 = _forward_dir()
	var n: int = min(nb_balles, tir_max_par_frame)
	var spread_rad: float = deg_to_rad(dispersion_deg)

	if debug_tir:
		print_debug("[ArmeTir#", get_instance_id(), "] n=", n, " hitscan=", hitscan, " spread=", dispersion_deg, "°")

	for i: int in range(n):
		var dir_i: Vector2 = dir0.rotated(_offset_eventail(i, n, spread_rad))
		if hitscan:
			_tir_hitscan(from, dir_i)
		else:
			var p: Projectile = _prendre_projectile()
			if p != null:
				var src: Node2D = (porteur as Node2D) if porteur is Node2D else self
				p.activer(from + dir_i * 8.0, dir_i, degats, recul_force, src)

func _tir_hitscan(from: Vector2, dir: Vector2) -> void:
	var to: Vector2 = from + dir * portee_hitscan_px
	var q: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to)
	q.exclude = [self, porteur]
	q.collide_with_bodies = true
	q.collide_with_areas = true
	if mask_tir != 0:
		q.collision_mask = mask_tir

	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var collider: Object = hit.get("collider")
	_appliquer_impact_commum(collider, degats, recul_force)

func _appliquer_impact_commum(collider: Object, dmg: int, force: float) -> void:
	var hb: HurtBox = _resolve_hurtbox_commune(collider)
	var src: Node2D = (porteur as Node2D) if porteur is Node2D else self

	if hb != null:
		hb.tek_it(dmg, src)
		_appliquer_recul_commune(hb.get_parent(), src, force)
	elif collider != null and collider.has_method("tek_it"):
		collider.call("tek_it", dmg, src)
		_appliquer_recul_commune(collider, src, force)

func _resolve_hurtbox_commune(o: Object) -> HurtBox:
	var n: Node = o as Node
	if n == null:
		return null
	if n is HurtBox:
		return n as HurtBox
	var direct: Node = n.get_node_or_null("HurtBox")
	if direct is HurtBox:
		return direct as HurtBox
	for c in n.get_children():
		if c is HurtBox:
			return c as HurtBox
	var p: Node = n.get_parent()
	if p is HurtBox:
		return p as HurtBox
	return null

func _appliquer_recul_commune(target: Object, origine: Node2D, force: float) -> void:
	var n: Node = target as Node
	while n != null:
		if n.has_method("appliquer_recul_depuis"):
			n.call("appliquer_recul_depuis", origine, force)
			return
		n = n.get_parent()


func _prendre_projectile() -> Projectile:
	var p: Projectile = null
	while not _pool.is_empty() and p == null:
		var cand: Projectile = _pool.pop_back()
		if is_instance_valid(cand):
			p = cand
	if p == null and scene_projectile != null:
		p = scene_projectile.instantiate() as Projectile
		if p != null:
			p.visible = false
			p.set_process(false)
			p.set_physics_process(false)
			p.connect("expired", Callable(self, "_recycler_projectile"))
			_root_proj.add_child(p)
	return p

func _recycler_projectile(p: Projectile) -> void:
	if is_instance_valid(p):
		_pool.append(p)

func _maj_etat_pickup() -> void:
	if _pickup:
		_pickup.set_deferred("monitoring", est_au_sol)
		_pickup.set_deferred("monitorable", est_au_sol)
		_pickup.process_mode = (Node.PROCESS_MODE_INHERIT if not est_au_sol else Node.PROCESS_MODE_DISABLED)

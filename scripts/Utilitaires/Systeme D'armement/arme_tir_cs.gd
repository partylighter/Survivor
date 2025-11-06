extends ArmeBase
class_name ArmeTirCS

@export_node_path("ArmeEffets2D") var chemin_effets: NodePath
@export_node_path("Node2D") var chemin_socket_muzzle: NodePath
@export_node_path("Node") var chemin_systeme: NodePath

@export_range(1, 10000, 1) var nb_balles: int = 1
@export_range(0.0, 60.0, 0.1) var dispersion_deg: float = 0.0
@export var hitscan: bool = false
@export var tir_max_par_frame: int = 20
@export var portee_hitscan_px: float = 2000.0
@export var mask_tir: int = 0
@export var vitesse_px_s: float = 1400.0
@export var duree_vie_s: float = 1.2
@export var pierce: int = 0
@export var debug_tir: bool = false

var effets: ArmeEffets2D
var _muzzle: Node2D
var _sys
var _cooldown_fin_s: float = 0.0

func _ready() -> void:
	if chemin_effets != NodePath():
		effets = get_node(chemin_effets) as ArmeEffets2D
	if effets:
		effets.set_cible(self)
	if chemin_socket_muzzle != NodePath():
		_muzzle = get_node(chemin_socket_muzzle) as Node2D
	if chemin_systeme != NodePath():
		_sys = get_node(chemin_systeme)
	if _sys == null:
		_sys = get_tree().current_scene.get_node_or_null("ProjectileSystem2D")

func _process(_dt: float) -> void:
	if effets:
		effets.tick(Time.get_ticks_msec() * 0.001, est_au_sol)
	if not _pret and Time.get_ticks_msec() * 0.001 >= _cooldown_fin_s:
		_pret = true

func _muzzle_pos() -> Vector2:
	return _muzzle.global_position if is_instance_valid(_muzzle) else global_position

func _forward_dir() -> Vector2:
	var ang: float = _muzzle.global_rotation if is_instance_valid(_muzzle) else global_rotation
	return Vector2.RIGHT.rotated(ang)

func _offset_eventail(i: int, n: int, spread_rad: float) -> float:
	if n <= 1 or spread_rad <= 0.0: return 0.0
	return lerp(-spread_rad * 0.5, spread_rad * 0.5, float(i) / float(n - 1))

func attaquer() -> void:
	var now: float = Time.get_ticks_msec() * 0.001
	if not peut_attaquer(): return
	if now < _cooldown_fin_s: return
	if _sys == null: return

	_pret = false
	_cooldown_fin_s = now + cooldown_s

	var from: Vector2 = _muzzle_pos()
	var dir0: Vector2 = _forward_dir() # ou (get_global_mouse_position() - from).normalized()
	var n: int = min(nb_balles, tir_max_par_frame)
	var spread_rad: float = deg_to_rad(dispersion_deg)

	for i in range(n):
		var dir_i: Vector2 = dir0.rotated(_offset_eventail(i, n, spread_rad))
		if hitscan:
			_tir_hitscan(from, dir_i)
		else:
			var src: Node = (porteur as Node) if porteur is Node else self
			if _sys and _sys.has_method("Spawn"):
				_sys.call("Spawn", from + dir_i * 8.0, dir_i, vitesse_px_s, duree_vie_s, degats, recul_force, mask_tir, pierce, src)

	await get_tree().create_timer(cooldown_s).timeout
	_pret = true

func _tir_hitscan(from: Vector2, dir: Vector2) -> void:
	var to: Vector2 = from + dir * portee_hitscan_px
	var q := PhysicsRayQueryParameters2D.create(from, to)
	q.exclude = [self, porteur]
	q.collide_with_bodies = true
	q.collide_with_areas = true
	if mask_tir != 0: q.collision_mask = mask_tir
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if hit.is_empty(): return
	var collider: Object = hit.get("collider")
	if collider == null: return
	var src: Node = (porteur as Node) if porteur is Node else self
	if collider.has_method("tek_it"):
		collider.call("tek_it", degats, src)
		_appliquer_recul_commune(collider, (porteur as Node2D) if porteur is Node2D else self, recul_force)
	else:
		var hb: Node = (collider as Node).get_node_or_null("HurtBox")
		if hb and hb.has_method("tek_it"):
			hb.call("tek_it", degats, src)
			_appliquer_recul_commune(hb.get_parent(), (porteur as Node2D) if porteur is Node2D else self, recul_force)

func _appliquer_recul_commune(target: Object, origine: Node2D, force: float) -> void:
	var n := target as Node
	while n:
		if n.has_method("appliquer_recul_depuis"):
			n.call("appliquer_recul_depuis", origine, force)
			return
		n = n.get_parent()

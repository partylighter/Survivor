extends ArmeBase
class_name ArmeTir

@export var scene_projectile: PackedScene
@export_node_path("ArmeEffets2D") var chemin_effets: NodePath
@export_node_path("Node2D") var chemin_socket_muzzle: NodePath
@export_range(1, 64, 1) var nb_balles: int = 1

var effets: ArmeEffets2D
var _muzzle: Node2D

func _ready() -> void:
	if chemin_effets != NodePath():
		effets = get_node(chemin_effets) as ArmeEffets2D
	if effets:
		effets.set_cible(self)
	if chemin_socket_muzzle != NodePath():
		_muzzle = get_node(chemin_socket_muzzle) as Node2D
		_muzzle.top_level = false

func _process(_dt: float) -> void:
	if effets:
		effets.tick(Time.get_ticks_msec() * 0.001, est_au_sol)

func jeter(direction: Vector2, distance_px: float = 80.0) -> void:
	if effets:
		effets.jeter(direction, distance_px)

func jeter_vers_souris(distance_px: float = 80.0) -> void:
	if effets:
		effets.jet_distance_px = distance_px
		effets.jeter_vers_souris()

func _muzzle_pos() -> Vector2:
	return (_muzzle.global_position if is_instance_valid(_muzzle) else global_position)

func _forward_dir() -> Vector2:
	var ang: float = (_muzzle.global_rotation if is_instance_valid(_muzzle) else global_rotation)
	return Vector2.RIGHT.rotated(ang)

func attaquer() -> void:
	if not peut_attaquer(): return
	if scene_projectile == null: return
	_pret = false

	var from: Vector2 = _muzzle_pos()
	var dir: Vector2 = _forward_dir()

	for _i in range(nb_balles):
		var p: Projectile = scene_projectile.instantiate() as Projectile
		if p == null:
			continue
		p.configurer(degats, dir, recul_force, porteur)
		p.global_position = from + dir * 8.0
		get_tree().current_scene.add_child(p)

	await get_tree().create_timer(cooldown_s).timeout
	_pret = true

func _maj_etat_pickup() -> void:
	if _pickup:
		_pickup.set_deferred("monitoring", est_au_sol)
		_pickup.set_deferred("monitorable", est_au_sol)
		_pickup.process_mode = (Node.PROCESS_MODE_INHERIT if not est_au_sol else Node.PROCESS_MODE_DISABLED)

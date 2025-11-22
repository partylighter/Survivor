extends Node2D
class_name Projectile

signal expired(p: Projectile)

@export var duree_vie_s: float = 1.5
@export var vitesse_px_s: float = 1400.0
@export var collision_mask: int = 0

var _degats: int = 0
var _dir: Vector2 = Vector2.ZERO
var _recul_force: float = 0.0
var _source: Node2D
var _t: float = 0.0
var _active: bool = false

func activer(pos: Vector2, dir: Vector2, dmg: int, recul: float, src: Node2D) -> void:
	visible = true
	set_physics_process(true)
	global_position = pos
	_dir = dir.normalized()
	_degats = dmg
	_recul_force = recul
	_source = src
	_t = 0.0
	_active = true

func desactiver() -> void:
	_active = false
	visible = false
	set_physics_process(false)
	_source = null
	emit_signal("expired", self)


func _physics_process(dt: float) -> void:
	if not _active:
		return

	if _source != null and not is_instance_valid(_source):
		_source = null

	var from: Vector2 = global_position
	var to: Vector2 = from + _dir * vitesse_px_s * dt

	var exclude: Array = [self]
	if _source != null:
		exclude.append(_source)

	var q: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to)
	q.exclude = exclude
	q.collide_with_bodies = true
	q.collide_with_areas = true
	if collision_mask != 0:
		q.collision_mask = collision_mask

	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(q)

	if not hit.is_empty():
		var collider: Object = hit.get("collider")
		_appliquer_impact(collider)
		desactiver()
		return

	global_position = to
	_t += dt
	if _t >= duree_vie_s:
		desactiver()

func _appliquer_impact(collider: Object) -> void:
	var hb: HurtBox = _resolve_hurtbox(collider)
	var src: Node2D = _source if is_instance_valid(_source) else self

	if hb != null:
		hb.tek_it(_degats, src)
		_appliquer_recul_sur_chaine(hb.get_parent(), src, _recul_force)
	elif collider != null and collider.has_method("tek_it"):
		collider.call("tek_it", _degats, src)
		_appliquer_recul_sur_chaine(collider, src, _recul_force)

func _resolve_hurtbox(o: Object) -> HurtBox:
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

func _appliquer_recul_sur_chaine(target: Object, origine: Node2D, force: float) -> void:
	var n: Node = target as Node
	while n != null:
		if n.has_method("appliquer_recul_depuis"):
			n.call("appliquer_recul_depuis", origine, force)
			return
		n = n.get_parent()

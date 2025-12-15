extends Node2D
class_name Projectile

signal expired(p: Projectile)

@export var duree_vie_s: float = 1.5
@export var vitesse_px_s: float = 1400.0
@export var collision_mask: int = 0
@export var marge_raycast_px: float = 1.0
@export var largeur_zone_scane: float = 0.0
@export_range(1, 9, 1) var nombre_de_rayon_dans_zone_scane: int = 2

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

	var from := global_position
	var step := _dir * vitesse_px_s * dt
	var move_to := from + step
	var ray_to := move_to + _dir * marge_raycast_px

	var exclude: Array = [self]
	if _source != null:
		exclude.append(_source)

	var hit := _intersect_large(from, ray_to, exclude)
	if not hit.is_empty():
		_appliquer_impact(hit.get("collider"))
		desactiver()
		return

	global_position = move_to
	_t += dt
	if _t >= duree_vie_s:
		desactiver()

func _intersect_large(from: Vector2, to: Vector2, exclude: Array) -> Dictionary:
	var space := get_world_2d().direct_space_state

	var best: Dictionary = {}
	var best_d2: float = 1e20

	var w: float = max(largeur_zone_scane, 0.0)
	var samples: int = max(nombre_de_rayon_dans_zone_scane, 1)
	if w <= 0.0:
		samples = 1

	var perp := Vector2(-_dir.y, _dir.x)
	if perp.length_squared() < 0.000001:
		perp = Vector2(0.0, 1.0)

	var half: float = w * 0.5

	for i in range(samples):
		var offset: float = 0.0
		if samples > 1:
			var t := float(i) / float(samples - 1)
			offset = lerp(-half, half, t)

		var f := from + perp * offset
		var tt := to + perp * offset

		var q := PhysicsRayQueryParameters2D.create(f, tt)
		q.exclude = exclude
		q.collide_with_bodies = true
		q.collide_with_areas = true
		if collision_mask != 0:
			q.collision_mask = collision_mask

		var h := space.intersect_ray(q)
		if not h.is_empty():
			var p: Vector2 = h.get("position", f)
			var d2 := f.distance_squared_to(p)
			if d2 < best_d2:
				best = h
				best_d2 = d2

	return best

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

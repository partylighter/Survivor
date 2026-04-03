extends Node2D
class_name Projectile

signal expired(p: Projectile)

@export var duree_vie_s: float = 1.5
@export var vitesse_px_s: float = 1400.0
@export var collision_mask: int = 0
@export var marge_raycast_px: float = 1.0
@export var largeur_zone_scane: float = 0.0
@export_range(1, 9, 1) var nombre_de_rayon_dans_zone_scane: int = 2
@export_node_path("Sprite2D") var chemin_sprite_visuel: NodePath = NodePath("Sprite2D")
@export_node_path("GPUParticles2D") var chemin_trail_particules: NodePath = NodePath("TrailParticles")

@export_group("Piercing")
@export_range(1, 50, 1) var contacts_avant_destruction: int = 1
@export var ignorer_meme_cible: bool = true

var _degats: int = 0
var _dir: Vector2 = Vector2.ZERO
var _recul_force: float = 0.0
var _source: Node2D = null
var _t: float = 0.0
var _active: bool = false

var _contacts_restants: int = 1
var _cibles_deja_touchees: Dictionary = {}
var _visual_ctrl: ProjectileVisualController = null
var _visual_runtime_courant: ProjectileVisualRuntime = null

# Cache query — réutilisé à chaque frame, jamais réalloué
var _query: PhysicsRayQueryParameters2D = null

func _ready() -> void:
	_visual_ctrl = ProjectileVisualController.new(self, chemin_sprite_visuel, chemin_trail_particules)
	if _visual_ctrl != null:
		_visual_ctrl.reset()

func activer(pos: Vector2, dir: Vector2, dmg: int, recul: float, src: Node2D, visual_runtime: ProjectileVisualRuntime = null) -> void:
	visible = true
	set_physics_process(true)
	global_position = pos
	_dir = dir.normalized()
	rotation = _dir.angle()
	_degats = dmg
	_recul_force = recul
	_source = src
	_t = 0.0
	_active = true

	_contacts_restants = max(contacts_avant_destruction, 1)
	_cibles_deja_touchees.clear()

	# Initialise le query une seule fois sur la durée de vie du nœud
	if _query == null:
		_query = PhysicsRayQueryParameters2D.new()
		_query.collide_with_bodies = true
		_query.collide_with_areas  = true

	# Toujours réassigner à chaque activation — évite les valeurs
	# résiduelles d'une activation précédente (bug principal)
	# 0 = détecter tous les layers (pas de filtre), toute autre valeur = filtre explicite
	_query.collision_mask = collision_mask if collision_mask != 0 else 0xFFFFFFFF
	_query.exclude        = [self, src] if src != null else [self]
	if _visual_runtime_courant == null:
		_visual_runtime_courant = ProjectileVisualRuntime.new()
	_visual_runtime_courant.copy_from(visual_runtime)
	if _visual_ctrl != null:
		_visual_ctrl.reset()
		_visual_ctrl.appliquer(_visual_runtime_courant)

func desactiver() -> void:
	_active = false
	visible = false
	set_physics_process(false)
	_source = null
	if _visual_runtime_courant != null:
		_visual_runtime_courant.reset_to_defaults()
	if _visual_ctrl != null:
		_visual_ctrl.reset()
	emit_signal("expired", self)

func _physics_process(dt: float) -> void:
	if not _active:
		return

	if _source != null and not is_instance_valid(_source):
		_source = null

	var from: Vector2    = global_position
	var step: Vector2    = _dir * vitesse_px_s * dt
	var move_to: Vector2 = from + step
	var ray_to: Vector2  = move_to + _dir * marge_raycast_px

	var hit: Dictionary = _intersect_large(from, ray_to)
	if not hit.is_empty():
		var collider: Object = hit.get("collider", null)
		var hit_pos: Vector2 = hit.get("position", move_to)
		if _gerer_impact(collider, hit_pos):
			if _contacts_restants <= 0:
				desactiver()
				return

	global_position = move_to

	_t += dt
	if _t >= duree_vie_s:
		desactiver()

func _gerer_impact(collider: Object, _hit_pos: Vector2) -> bool:
	if collider == null:
		return false

	var hb: HurtBox = _resolve_hurtbox(collider)
	var target_obj: Object = hb if hb != null else collider

	if ignorer_meme_cible:
		var id: int = target_obj.get_instance_id()
		if _cibles_deja_touchees.has(id):
			return false
		_cibles_deja_touchees[id] = true

	_appliquer_impact(collider)

	_contacts_restants -= 1
	return true

func _intersect_large(from: Vector2, to: Vector2) -> Dictionary:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state

	var best: Dictionary = {}
	var best_d2: float = 1e20

	var w: float = max(largeur_zone_scane, 0.0)
	var samples: int = max(nombre_de_rayon_dans_zone_scane, 1)
	if w <= 0.0:
		samples = 1

	var perp: Vector2 = Vector2(-_dir.y, _dir.x)
	if perp.length_squared() < 0.000001:
		perp = Vector2(0.0, 1.0)

	var half: float = w * 0.5

	for i: int in range(samples):
		var offset: float = 0.0
		if samples > 1:
			var t: float = float(i) / float(samples - 1)
			offset = lerp(-half, half, t)

		var f: Vector2  = from + perp * offset
		var tt: Vector2 = to   + perp * offset

		_query.from = f
		_query.to   = tt

		var h: Dictionary = space.intersect_ray(_query)
		if not h.is_empty():
			var p: Vector2 = h.get("position", f)
			var d2: float  = f.distance_squared_to(p)
			if d2 < best_d2:
				best    = h
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

	if _visual_ctrl != null and _visual_runtime_courant != null:
		_visual_ctrl.jouer_impact(global_position, _dir, _visual_runtime_courant)

func _resolve_hurtbox(o: Object) -> HurtBox:
	var n: Node = o as Node
	if n == null:
		return null
	# Remonte jusqu'à 3 niveaux pour couvrir les hiérarchies profondes
	for _i: int in range(3):
		if n is HurtBox:
			return n as HurtBox
		var direct: Node = n.get_node_or_null("HurtBox")
		if direct is HurtBox:
			return direct as HurtBox
		for c in n.get_children():
			if c is HurtBox:
				return c as HurtBox
		if n.get_parent() == null:
			break
		n = n.get_parent()
	return null

func _appliquer_recul_sur_chaine(target: Object, origine: Node2D, force: float) -> void:
	var n: Node = target as Node
	while n != null:
		if n.has_method("appliquer_recul_depuis"):
			n.call("appliquer_recul_depuis", origine, force)
			return
		n = n.get_parent()

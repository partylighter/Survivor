extends RefCounted
class_name ProjectileVisualController

var _owner: Projectile
var _sprite: Sprite2D = null
var _trail: GPUParticles2D = null

var _sprite_modulate_base: Color = Color.WHITE
var _sprite_scale_base: Vector2 = Vector2.ONE
var _sprite_rotation_base: float = 0.0

var _trail_modulate_base: Color = Color.WHITE
var _trail_scale_base: Vector2 = Vector2.ONE
var _trail_amount_base: int = 1
var _trail_lifetime_base: float = 0.1

func _init(owner: Projectile, sprite_path: NodePath, trail_path: NodePath) -> void:
	_owner = owner
	if _owner != null:
		_sprite = _owner.get_node_or_null(sprite_path) as Sprite2D
		_trail = _owner.get_node_or_null(trail_path) as GPUParticles2D
	_capture_bases()

func _capture_bases() -> void:
	if _sprite != null:
		_sprite_modulate_base = _sprite.modulate
		_sprite_scale_base = _sprite.scale
		_sprite_rotation_base = _sprite.rotation

	if _trail != null:
		_trail_modulate_base = _trail.modulate
		_trail_scale_base = _trail.scale
		_trail_amount_base = max(_trail.amount, 1)
		_trail_lifetime_base = _trail.lifetime

func reset() -> void:
	if _sprite != null:
		_sprite.modulate = _sprite_modulate_base
		_sprite.scale = _sprite_scale_base
		_sprite.rotation = _sprite_rotation_base
		_sprite.self_modulate = Color(1.0, 1.0, 1.0, 1.0)

	if _trail != null:
		_trail.emitting = false
		_trail.restart()
		_trail.amount = _trail_amount_base
		_trail.lifetime = _trail_lifetime_base
		_trail.scale = _trail_scale_base
		_trail.modulate = _trail_modulate_base

func appliquer(rt: ProjectileVisualRuntime) -> void:
	if rt == null:
		reset()
		return

	if _sprite != null:
		_sprite.modulate = rt.couleur_principale
		_sprite.scale = Vector2(
			_sprite_scale_base.x * rt.longueur_visuelle * rt.echelle_sprite,
			_sprite_scale_base.y * rt.epaisseur_visuelle * rt.echelle_sprite
		)
		var alpha_glow: float = clampf(1.0 + rt.glow_intensite * 0.15, 1.0, 2.0)
		_sprite.self_modulate = Color(alpha_glow, alpha_glow, alpha_glow, 1.0)
		if not rt.rotation_suivre_direction:
			_sprite.rotation = _sprite_rotation_base

	if _trail != null:
		_trail.modulate = rt.couleur_secondaire
		_trail.scale = _trail_scale_base * rt.trainee_scale
		_trail.amount = max(1, int(round(float(_trail_amount_base) * rt.trainee_amount_mult)))
		_trail.emitting = rt.trainee_active
		if rt.trainee_active:
			_trail.restart()

func jouer_impact(pos: Vector2, dir: Vector2, rt: ProjectileVisualRuntime) -> void:
	if _owner == null or rt == null or rt.impact_scene_resolue == null:
		return

	var n: Node = rt.impact_scene_resolue.instantiate()
	if n == null:
		return

	var parent: Node = _owner.get_tree().current_scene
	if parent == null:
		parent = _owner.get_parent()
	if parent == null:
		n.queue_free()
		return

	parent.add_child(n)
	if n is Node2D:
		var n2d := n as Node2D
		n2d.global_position = pos
		n2d.global_rotation = dir.angle()

	if n is GPUParticles2D:
		var gp := n as GPUParticles2D
		gp.modulate = rt.couleur_secondaire
		gp.restart()
		gp.emitting = true

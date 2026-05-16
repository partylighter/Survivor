extends Area2D
class_name HurtBox

signal hit_received(amount: int, source: Node) # <-- AJOUT

@export_node_path("Sante") var chemin_sante: NodePath
@export var invincibilite_s: float = 0.25
@export var hit_offset_px: Vector2 = Vector2.ZERO
@export var hit_radius_px: float = 16.0
@export var groupe_hurtbox: StringName = &""
@export var debug_hurtbox: bool = false

var sante: Sante
var _i_t: float = 0.0

func _ready() -> void:
	sante = get_node_or_null(chemin_sante) as Sante
	set_deferred("monitoring", false)
	set_deferred("monitorable", true)

	if groupe_hurtbox != &"":
		add_to_group(groupe_hurtbox)

	set_physics_process(false)

func _physics_process(dt: float) -> void:
	_i_t -= dt
	if _i_t <= 0.0:
		_i_t = 0.0
		set_physics_process(false)

func hit_center() -> Vector2:
	return global_position + hit_offset_px

func hit_radius() -> float:
	return max(hit_radius_px, 0.0)

func get_invulnerabilite_restant_s() -> float:
	return maxf(_i_t, 0.0)

func tek_it(damage: int, source: Node) -> bool:
	if damage <= 0:
		return false
	if _i_t > 0.0:
		return false
	if _hote_est_invulnerable():
		return false
	if sante == null:
		return false
	sante.apply_damage(damage, source)
	emit_signal("hit_received", damage, source)
	_i_t = maxf(invincibilite_s, 0.0)
	if _i_t > 0.0:
		set_physics_process(true)
	if groupe_hurtbox == &"player_hurtbox":
		var cam := get_tree().get_first_node_in_group(&"cam_player") as CamPlayer
		if cam != null:
			cam.kick_shake_from_damage(damage)
	return true

func _hote_est_invulnerable() -> bool:
	var hote: Node = get_parent()
	if hote != null and hote.has_method("est_invulnerable_aux_degats"):
		return bool(hote.call("est_invulnerable_aux_degats"))
	return false


func set_actif(v: bool) -> void:
	set_deferred("monitoring", v)
	set_deferred("monitorable", v)
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs:
		cs.set_deferred("disabled", not v)

extends ArmeBase
class_name ArmeContact

@export_node_path("HitBoxContact") var chemin_hitbox: NodePath

var _hitbox: HitBoxContact

func _ready() -> void:
	_hitbox = get_node(chemin_hitbox) as HitBoxContact

func attaquer() -> void:
	if not peut_attaquer():
		return
	if _hitbox == null:
		return

	_pret = false

	_hitbox.configurer(degats, recul_force, porteur)
	_hitbox.activer_pendant(duree_active_s)

	await get_tree().create_timer(cooldown_s).timeout
	_pret = true

func _maj_etat_pickup() -> void:
	if _pickup:
		_pickup.set_deferred("monitoring", est_au_sol)
		_pickup.set_deferred("monitorable", est_au_sol)
		_pickup.process_mode = (Node.PROCESS_MODE_INHERIT if not est_au_sol else Node.PROCESS_MODE_DISABLED)

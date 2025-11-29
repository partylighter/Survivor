extends ArmeBase
class_name ArmeContact

@export_node_path("HitBoxContact") var chemin_hitbox: NodePath = NodePath("HitBoxContact")
@export_node_path("ArmeEffets2D") var chemin_effets: NodePath

var hitbox: HitBoxContact
var effets: ArmeEffets2D

func _ready() -> void:
	hitbox = get_node_or_null(chemin_hitbox) as HitBoxContact
	if chemin_effets != NodePath():
		effets = get_node(chemin_effets) as ArmeEffets2D
	if effets:
		effets.set_cible(self)

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

func attaquer() -> void:
	if not peut_attaquer():
		return
	if hitbox == null:
		return
	_pret = false
	hitbox.configurer(degats, recul_force, porteur)
	hitbox.activer_pendant(duree_active_s)
	await get_tree().create_timer(cooldown_s).timeout
	_pret = true

func _maj_etat_pickup() -> void:
	if _pickup:
		_pickup.set_deferred("monitoring", est_au_sol)
		_pickup.set_deferred("monitorable", est_au_sol)
		_pickup.process_mode = (Node.PROCESS_MODE_INHERIT if not est_au_sol else Node.PROCESS_MODE_DISABLED)

func stop_drop() -> void:
	if effets:
		effets.stop_drop()

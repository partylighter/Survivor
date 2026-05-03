extends ArmeBase
class_name ArmeContact

@export_node_path("HitBoxContact") var chemin_hitbox: NodePath = NodePath("HitBoxContact"):
	set(v):
		chemin_hitbox = v
		if is_inside_tree():
			hitbox = get_node_or_null(v) as HitBoxContact
@export_node_path("ArmeEffets2D") var chemin_effets: NodePath:
	set(v):
		chemin_effets = v
		if is_inside_tree():
			effets = get_node_or_null(v) as ArmeEffets2D
			if effets:
				effets.set_cible(self)

@export_group("Animation contact")
@export var anim_contact_intensite_base: float = 0.9
@export var anim_contact_degats_mult: float = 0.03
@export var anim_contact_recul_mult: float = 0.00008
@export_range(0.1, 3.0, 0.01) var anim_contact_intensite_min: float = 0.9
@export_range(0.1, 3.0, 0.01) var anim_contact_intensite_max: float = 1.6

var hitbox: HitBoxContact
var effets: ArmeEffets2D
var upgrades: GestionnaireUpgradesArmeContact = null

func _ready() -> void:
	add_to_group("armes_contact")

	hitbox = get_node_or_null(chemin_hitbox) as HitBoxContact

	if chemin_effets != NodePath():
		effets = get_node_or_null(chemin_effets) as ArmeEffets2D
	if effets:
		effets.set_cible(self)

	_trouver_upgrades()
	if upgrades and upgrades.actif:
		upgrades.appliquer_sur(self)

func _trouver_upgrades() -> void:
	if upgrades != null and is_instance_valid(upgrades):
		return
	var arr := get_tree().get_nodes_in_group("upg_arme_contact")
	if not arr.is_empty():
		upgrades = arr[0] as GestionnaireUpgradesArmeContact

func _process(_dt: float) -> void:
	if effets:
		effets.tick(Time.get_ticks_msec() * 0.001, est_au_sol, _dt)

func jeter(direction: Vector2, distance_px: float = 80.0) -> void:
	if effets:
		effets.jeter(direction, distance_px)

func jeter_vers_souris(distance_px: float = 80.0) -> void:
	if effets:
		effets.jet_distance_px = distance_px
		effets.jeter_vers_souris()

func _forward_dir() -> Vector2:
	return Vector2.RIGHT.rotated(global_rotation)

func attaquer() -> void:
	if not peut_attaquer():
		return

	_trouver_upgrades()
	if upgrades and upgrades.actif:
		upgrades.appliquer_sur(self)

	if hitbox == null:
		hitbox = get_node_or_null(chemin_hitbox) as HitBoxContact
		if hitbox == null:
			return

	_pret = false
	if effets:
		var intensite: float = anim_contact_intensite_base
		intensite += float(degats) * anim_contact_degats_mult
		intensite += recul_force * anim_contact_recul_mult
		intensite = clampf(intensite, anim_contact_intensite_min, anim_contact_intensite_max)
		effets.frappe_contact(_forward_dir(), intensite, duree_active_s)
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

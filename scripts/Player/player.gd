extends CharacterBody2D
class_name Player

@export_group("Refs")
@export_node_path("StatsJoueur") var chemin_stats: NodePath
@export_node_path("Sante") var chemin_sante: NodePath
@export_node_path("GestionnaireLoot") var chemin_GestionnaireLoot: NodePath
@export_node_path("GestionDeplacementJoueur") var chemin_GestionDeplacementJoueur: NodePath

@export_group("Vehicule")
@export var chemin_base_vehicle: NodePath

@export_group("Collision math - ennemis")
@export var collision_ennemis_actif: bool = true
@export var rayon_collision_px: float = 14.0
@export var poids_collision: float = 6.0
@export var collision_range_px: float = 70.0
@export var collision_budget_par_frame: int = 100
@export var collision_iterations: int = 2
@export var collision_push_mult: float = 0.8

@export_group("Dash state")
var dash_charges_actuelles: int = 0
var dash_cooldown_s: float = 1.0
var dash_timer_recup_s: float = 0.0
var dash_multi_vitesse: float = 3.0
var dash_duree_s: float = 0.15
var dash_t_restant_s: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO
var dash_infini_actif: bool = false
var dash_autorise: bool = true

@onready var stats: StatsJoueur = get_node_or_null(chemin_stats) as StatsJoueur
@onready var sante: Sante = get_node_or_null(chemin_sante) as Sante
@onready var gestionnaire_loot: GestionnaireLoot = get_node_or_null(chemin_GestionnaireLoot) as GestionnaireLoot
@onready var gestion_deplacement: GestionDeplacementJoueur = get_node_or_null(chemin_GestionDeplacementJoueur) as GestionDeplacementJoueur

var base_vehicle: Node2D = null
var _col_idx: int = 0

var _mort: bool = false

func _ready() -> void:
	add_to_group("joueur_principal")
	if stats != null and sante != null:
		stats.set_sante_ref(sante)
	base_vehicle = get_node_or_null(chemin_base_vehicle) as Node2D

	if sante != null and not sante.died.is_connected(_on_sante_died):
		sante.died.connect(_on_sante_died)

func _on_sante_died() -> void:
	mourir()

func mourir() -> void:
	if _mort:
		return
	_mort = true
	get_tree().call_group("gestion_ennemis", "set_player_dead", true)

	collision_ennemis_actif = false
	velocity = Vector2.ZERO
	set_physics_process(false)
	set_process(false)
	set_process_input(false)
	set_process_unhandled_input(false)

	for n in get_tree().get_nodes_in_group(&"inputs_jeu"):
		if n != null and is_instance_valid(n):
			n.set_process(false)
			n.set_physics_process(false)
			n.set_process_input(false)
			n.set_process_unhandled_input(false)

	var ds := get_tree().get_first_node_in_group("death_screen")
	if ds != null and ds.has_method("show_auto"):
		ds.call("show_auto")
	else:
		push_warning("DeathScreen introuvable ou pas de show_auto() (groupe 'death_screen')")

func _physics_process(dt: float) -> void:
	if gestion_deplacement:
		gestion_deplacement.traiter(self, stats, dt)

func set_base_vehicle(n: Node2D) -> void:
	base_vehicle = n

func est_en_conduite() -> bool:
	if base_vehicle == null or not is_instance_valid(base_vehicle):
		return false
	var v = base_vehicle.get("controle_actif")
	return typeof(v) == TYPE_BOOL and v

func get_camera_target() -> Node2D:
	if est_en_conduite():
		return base_vehicle
	return self

func set_dash_infini(actif: bool) -> void:
	dash_infini_actif = actif
	if actif and stats != null:
		dash_charges_actuelles = stats.get_dash_max_effectif()

func set_dash_autorise(actif: bool) -> void:
	dash_autorise = actif
	if not actif:
		dash_t_restant_s = 0.0
		dash_direction = Vector2.ZERO

func on_loot_collected(payload: Dictionary) -> void:
	if gestionnaire_loot:
		gestionnaire_loot.on_loot_collecte(payload)

func soigner(amount: int) -> void:
	if sante:
		sante.heal(amount)

func get_luck() -> float:
	if stats:
		return stats.get_chance()
	return 0.0

func collision_ennemis_pre(dt: float) -> void:
	if not collision_ennemis_actif or dt <= 0.0:
		return
	var p0: Vector2 = global_position
	var p: Vector2 = p0 + velocity * dt
	p = _resoudre_collisions_ennemis(p, dt, false)
	velocity = (p - p0) / dt

func collision_ennemis_post(dt: float) -> void:
	if not collision_ennemis_actif:
		return
	global_position = _resoudre_collisions_ennemis(global_position, dt, true)

func _resoudre_collisions_ennemis(p: Vector2, dt: float, pousser_ennemi: bool) -> Vector2:
	var enemies: Array = _get_enemies_for_collision()
	var nE: int = enemies.size()
	if nE <= 0:
		return p

	var checks: int = collision_budget_par_frame
	if checks <= 0 or checks > nE:
		checks = nE

	var start: int = _col_idx % nE
	_col_idx = (start + checks) % nE

	var wp: float = max(poids_collision, 0.001)
	var invp: float = 1.0 / wp

	for _it in range(max(collision_iterations, 1)):
		var changed: bool = false

		for i in range(checks):
			var e := enemies[(start + i) % nE] as Enemy
			if e == null or not is_instance_valid(e) or e.deja_mort:
				continue

			var er: float = max(e.rayon_collision_px, 0.0)
			var r: float = max(rayon_collision_px + er, 0.0)
			if r <= 0.0:
				continue

			var rr: float = r + max(collision_range_px, 0.0)
			var delta: Vector2 = p - e.global_position
			if delta.length_squared() > rr * rr:
				continue

			var d2: float = delta.length_squared()
			var r2: float = r * r
			if d2 >= r2:
				continue

			var dist: float = sqrt(max(d2, 0.0001))
			var n: Vector2 = delta / dist
			var pen: float = r - dist

			var we: float = max(e.poids_collision, 0.001)
			var inve: float = 1.0 / we
			var invsum: float = invp + inve
			var share_p: float = invp / invsum
			var share_e: float = inve / invsum

			p += n * pen * share_p

			if pousser_ennemi:
				e.global_position -= n * pen * share_e
				var push_v: float = (pen / max(dt, 0.016)) * max(collision_push_mult, 0.0) * share_e
				e.appliquer_pousse(-n * push_v)

			changed = true

		if not changed:
			break

	return p

func _get_enemies_for_collision() -> Array:
	var gm := get_node_or_null("/root/GestionnaireEnnemis")
	if gm != null and gm.has_method("get_ennemis_actifs"):
		return gm.get_ennemis_actifs()
	return get_tree().get_nodes_in_group("enemy")

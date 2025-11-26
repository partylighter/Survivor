extends CharacterBody2D
class_name Player

@export_node_path("StatsJoueur") var chemin_stats: NodePath
@export_node_path("Sante") var chemin_sante: NodePath

@onready var stats: StatsJoueur = get_node_or_null(chemin_stats) as StatsJoueur
@onready var sante: Sante = get_node_or_null(chemin_sante) as Sante
@onready var gestionnaire_loot: GestionnaireLoot = $GestionnaireLoot

var dash_charges_actuelles: int = 0
var dash_cooldown_s: float = 1.0
var dash_timer_recup_s: float = 0.0
var dash_multi_vitesse: float = 3.0
var dash_duree_s: float = 0.15
var dash_t_restant_s: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO
var dash_infini_actif: bool = false


func _ready() -> void:
	add_to_group("joueur_principal")
	if stats != null and sante != null:
		stats.set_sante_ref(sante)

	if stats != null:
		dash_charges_actuelles = stats.get_dash_max_effectif()
		dash_cooldown_s = stats.get_dash_cooldown_effectif()


func _physics_process(dt: float) -> void:
	var dir := Input.get_vector("gauche","droite","haut","bas")

	if Input.is_action_just_pressed("dash") and dir.length() > 0.0 and dash_t_restant_s <= 0.0:
		if dash_infini_actif or dash_charges_actuelles > 0:
			if not dash_infini_actif:
				dash_charges_actuelles -= 1
			dash_t_restant_s = dash_duree_s
			dash_direction = dir.normalized()
			dash_timer_recup_s = 0.0

	if dash_t_restant_s > 0.0:
		dash_t_restant_s -= dt
		var v_dash: float = (stats.get_vitesse_effective() if stats != null else 500.0) * dash_multi_vitesse
		velocity = dash_direction * v_dash
	else:
		var v_normale: float = (stats.get_vitesse_effective() if stats != null else 500.0)
		velocity = dir.normalized() * v_normale

	if stats != null:
		dash_cooldown_s = stats.get_dash_cooldown_effectif()
	var dash_max: int = (stats.get_dash_max_effectif() if stats != null else 1)

	if dash_charges_actuelles > dash_max:
		dash_charges_actuelles = dash_max

	if not dash_infini_actif and dash_charges_actuelles < dash_max:
		dash_timer_recup_s += dt
		if dash_timer_recup_s >= dash_cooldown_s:
			dash_timer_recup_s -= dash_cooldown_s
			dash_charges_actuelles += 1
			if dash_charges_actuelles > dash_max:
				dash_charges_actuelles = dash_max
	if Input.is_action_just_pressed("dash") and dir.length() > 0.0 and dash_t_restant_s <= 0.0:
		if dash_infini_actif or dash_charges_actuelles > 0:
			print("DASH -> charges=%d / max=%d  infini=%s" % [
				dash_charges_actuelles,
				(stats.get_dash_max_effectif() if stats != null else -1),
				str(dash_infini_actif)
			])

	move_and_slide()


func set_dash_infini(actif: bool) -> void:
	dash_infini_actif = actif
	if actif and stats != null:
		dash_charges_actuelles = stats.get_dash_max_effectif()


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

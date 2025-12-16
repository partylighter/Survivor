extends CharacterBody2D
class_name Player

@export_node_path("StatsJoueur") var chemin_stats: NodePath
@export_node_path("Sante") var chemin_sante: NodePath
@export_node_path("GestionnaireLoot") var chemin_GestionnaireLoot: NodePath
@export_node_path("GestionDeplacementJoueur") var chemin_GestionDeplacementJoueur: NodePath

@onready var stats: StatsJoueur = get_node_or_null(chemin_stats) as StatsJoueur
@onready var sante: Sante = get_node_or_null(chemin_sante) as Sante
@onready var gestionnaire_loot: GestionnaireLoot = get_node_or_null(chemin_GestionnaireLoot) as GestionnaireLoot
@onready var gestion_deplacement: GestionDeplacementJoueur = get_node_or_null(chemin_GestionDeplacementJoueur) as GestionDeplacementJoueur


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


func _physics_process(dt: float) -> void:
	if gestion_deplacement:
		gestion_deplacement.traiter(self, stats, dt)


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

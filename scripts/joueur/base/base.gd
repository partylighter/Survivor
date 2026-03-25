extends CharacterBody2D
class_name PlayerBase

@export_node_path("DeplacementBase") var chemin_deplacement: NodePath
@export_node_path("SanteBase") var chemin_sante_base: NodePath
@export_node_path("CarburantBase") var chemin_carburant_base: NodePath

@export_group("Stats")
@export var stats_base: StatsBase

@onready var deplacement: DeplacementBase = get_node_or_null(chemin_deplacement) as DeplacementBase
@onready var sante_base: SanteBase = get_node_or_null(chemin_sante_base) as SanteBase
@onready var carburant_base: CarburantBase = get_node_or_null(chemin_carburant_base) as CarburantBase

var controle_actif: bool = false

func _ready() -> void:
	add_to_group("base_vehicle")

	if stats_base == null:
		stats_base = StatsBase.new()

	if sante_base:
		sante_base.stats = stats_base
	if carburant_base:
		carburant_base.stats = stats_base

func set_controle_actif(actif: bool) -> void:
	controle_actif = actif

func _physics_process(dt: float) -> void:
	var en_mouvement := false
	if controle_actif:
		en_mouvement = absf(Input.get_action_strength("haut") - Input.get_action_strength("bas")) > 0.01 \
			or absf(Input.get_action_strength("droite") - Input.get_action_strength("gauche")) > 0.01

	if carburant_base:
		carburant_base.tick(dt, en_mouvement, false)

	var autorise := true
	if carburant_base and carburant_base.reserve <= 0.0:
		autorise = false

	if deplacement:
		deplacement.traiter(self, dt, controle_actif and autorise)

extends CharacterBody2D
class_name PlayerBase

@export_node_path("DeplacementBase") var chemin_deplacement: NodePath
@onready var deplacement: DeplacementBase = get_node_or_null(chemin_deplacement) as DeplacementBase

var controle_actif: bool = false

func _ready() -> void:
	add_to_group("base_vehicle")

func set_controle_actif(actif: bool) -> void:
	controle_actif = actif

func _physics_process(dt: float) -> void:
	if deplacement:
		deplacement.traiter(self, dt, controle_actif)

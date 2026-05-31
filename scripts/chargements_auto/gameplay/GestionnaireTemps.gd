extends Node
@export_range(0.05, 1.0, 0.01) var echelle_temps_ralenti: float = 0.25
@export var action_ralentir_temps: StringName = &"ralentir_temps"
var ralenti_actif: bool = false
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.time_scale = 1.0
func _unhandled_input(evenement: InputEvent) -> void:
	if evenement.is_action_pressed(action_ralentir_temps):
		basculer_ralenti()
func basculer_ralenti() -> void:
	set_ralenti_actif(not ralenti_actif)
func set_ralenti_actif(actif: bool) -> void:
	ralenti_actif = actif
	Engine.time_scale = echelle_temps_ralenti if ralenti_actif else 1.0
func desactiver_ralenti() -> void:
	set_ralenti_actif(false)

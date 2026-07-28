extends Resource
class_name AmeliorationForge

@export var identifiant: StringName = &""
@export var nom: String = ""
@export_range(1.0, 3.0, 0.01) var multiplicateur_cadence: float = 1.0

extends ElementParcours
class_name CheckpointParcours

signal checkpoint_active(cellule: Vector2i)

func activer(_joueur: CharacterBody2D, gestionnaire) -> void:
	if gestionnaire == null or not gestionnaire.has_method("definir_checkpoint"):
		return
	if not bool(gestionnaire.call("definir_checkpoint", cellule)):
		return
	checkpoint_active.emit(cellule)

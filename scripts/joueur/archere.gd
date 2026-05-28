extends Player
class_name Archere
@export_group("Archere")
@export var identifiant_personnage: StringName = &"archere"

func _ready() -> void:
	super()
	add_to_group("personnage_archere")
func get_identifiant_personnage() -> StringName:
	return identifiant_personnage

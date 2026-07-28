extends Button
class_name SlotAssemblageForge

@export_range(0, 8, 1) var index_slot: int = 0

func _can_drop_data(_position: Vector2, donnees: Variant) -> bool:
	return donnees is Dictionary and donnees.get("type", &"") == &"composant_assemblage"

func _drop_data(_position: Vector2, donnees: Variant) -> void:
	var interface_assemblage: InterfaceAssemblageForge = get_tree().get_first_node_in_group(&"interface_assemblage_forge") as InterfaceAssemblageForge
	if interface_assemblage != null:
		interface_assemblage.deposer_objet_depuis_glisser(index_slot, donnees)

extends Button
class_name SlotCuisine

@export_range(0, 2, 1) var index_slot: int = 0

var interface_cuisine: InterfaceCuisine

func configurer(nouvelle_interface: InterfaceCuisine) -> void:
	interface_cuisine = nouvelle_interface

func _can_drop_data(_position: Vector2, donnees: Variant) -> bool:
	return interface_cuisine != null and donnees is Dictionary and donnees.get("type", &"") == &"ingredient_cuisine"

func _drop_data(_position: Vector2, donnees: Variant) -> void:
	if interface_cuisine != null:
		interface_cuisine.deposer_ingredient_depuis_glisser(index_slot, donnees)

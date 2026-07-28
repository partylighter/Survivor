extends Button
class_name BoutonComposantAssemblageForge

var objet: Dictionary = {}

func configurer(nouvel_objet: Dictionary) -> void:
	objet = nouvel_objet.duplicate(true)
	text = "%s x%d" % [objet.get("nom", objet.get("identifiant", "")), int(objet.get("quantite", 0))]

func _get_drag_data(_position: Vector2) -> Variant:
	if objet.is_empty() or int(objet.get("type_item", -1)) != Loot.TypeItem.COMPOSANT:
		return null
	var apercu := Label.new()
	apercu.text = String(objet.get("nom", objet.get("identifiant", "")))
	set_drag_preview(apercu)
	return {"type": &"composant_assemblage", "objet": objet.duplicate(true)}

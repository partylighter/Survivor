extends Button
class_name BoutonIngredientCuisine

var objet: Dictionary = {}

func configurer(nouvel_objet: Dictionary) -> void:
	objet = nouvel_objet.duplicate(true)
	text = "%s x%d" % [objet.get("nom", objet.get("identifiant", "")), int(objet.get("quantite", 0))]
	icon = objet.get("icone", null) as Texture2D
	tooltip_text = "Glisser cet ingredient vers un emplacement."

func _get_drag_data(_position: Vector2) -> Variant:
	if objet.is_empty() or int(objet.get("quantite", 0)) <= 0:
		return null
	var apercu := Label.new()
	apercu.text = String(objet.get("nom", objet.get("identifiant", "")))
	set_drag_preview(apercu)
	return {"type": &"ingredient_cuisine", "objet": objet.duplicate(true)}

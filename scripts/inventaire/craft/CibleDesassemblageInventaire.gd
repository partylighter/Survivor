extends PanelContainer
class_name CibleDesassemblageInventaire

signal objet_depose(objet: Dictionary)

var etiquette: Label

func _ready() -> void:
	custom_minimum_size = Vector2(0.0, 82.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.05, 0.065, 1.0)
	style.border_color = Color(0.28, 0.31, 0.4, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	add_theme_stylebox_override("panel", style)
	etiquette = Label.new()
	etiquette.text = "Glissez un equipement ici"
	etiquette.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiquette.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	etiquette.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	etiquette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(etiquette)

func afficher(objet: Dictionary) -> void:
	if etiquette != null:
		etiquette.text = "Glissez un equipement ici" if objet.is_empty() else String(objet.get("nom", "Equipement"))

func _can_drop_data(_position: Vector2, donnees: Variant) -> bool:
	if not donnees is Dictionary:
		return false
	var dictionnaire: Dictionary = donnees
	var objet: Dictionary = dictionnaire.get("objet", {})
	return dictionnaire.get("origine", &"") == &"inventaire" and int(objet.get("type_item", -1)) == Loot.TypeItem.EQUIPEMENT

func _drop_data(_position: Vector2, donnees: Variant) -> void:
	var dictionnaire: Dictionary = donnees
	objet_depose.emit(dictionnaire.get("objet", {}))

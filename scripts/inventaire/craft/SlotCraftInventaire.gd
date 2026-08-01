extends PanelContainer
class_name SlotCraftInventaire

signal depot_demande(index_slot: int, objet: Dictionary)
signal retrait_demande(index_slot: int)

var index_slot: int = -1
var objet: Dictionary = {}
var icone: TextureRect
var etiquette: Label

func _ready() -> void:
	custom_minimum_size = Vector2(92.0, 92.0)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.05, 0.065, 1.0)
	style.border_color = Color(0.28, 0.31, 0.4, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	add_theme_stylebox_override("panel", style)
	var marge := MarginContainer.new()
	marge.add_theme_constant_override("margin_left", 6)
	marge.add_theme_constant_override("margin_top", 6)
	marge.add_theme_constant_override("margin_right", 6)
	marge.add_theme_constant_override("margin_bottom", 6)
	marge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(marge)
	var colonne := VBoxContainer.new()
	colonne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marge.add_child(colonne)
	icone = TextureRect.new()
	icone.custom_minimum_size = Vector2(0.0, 54.0)
	icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonne.add_child(icone)
	etiquette = Label.new()
	etiquette.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiquette.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	etiquette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonne.add_child(etiquette)
	_actualiser()

func configurer(nouvel_index: int, nouvel_objet: Dictionary) -> void:
	index_slot = nouvel_index
	objet = nouvel_objet.duplicate(true)
	if is_node_ready():
		_actualiser()

func _can_drop_data(_position: Vector2, donnees: Variant) -> bool:
	if not donnees is Dictionary or not objet.is_empty():
		return false
	var dictionnaire: Dictionary = donnees
	var objet_glisse: Dictionary = dictionnaire.get("objet", {})
	return dictionnaire.get("origine", &"") == &"inventaire" and int(objet_glisse.get("type_item", -1)) == Loot.TypeItem.COMPOSANT

func _drop_data(_position: Vector2, donnees: Variant) -> void:
	var dictionnaire: Dictionary = donnees
	depot_demande.emit(index_slot, dictionnaire.get("objet", {}))

func _gui_input(evenement: InputEvent) -> void:
	if evenement is InputEventMouseButton and evenement.pressed and evenement.button_index == MOUSE_BUTTON_LEFT and not objet.is_empty():
		retrait_demande.emit(index_slot)
		accept_event()

func _actualiser() -> void:
	if icone == null or etiquette == null:
		return
	icone.texture = objet.get("icone", null) as Texture2D
	etiquette.text = "Vide" if objet.is_empty() else String(objet.get("nom", objet.get("identifiant", "Objet")))
	tooltip_text = "Glissez un composant ici." if objet.is_empty() else "Cliquez pour rendre ce composant a l'inventaire."

extends PanelContainer
class_name CelluleInventaire

signal objet_selectionne(objet: Dictionary)
signal objet_double_clique(objet: Dictionary)
signal survol_objet(objet: Dictionary)
signal fin_survol_objet

var objet: Dictionary = {}
var selectionnee: bool = false
var est_equipee: bool = false
var texture_icone: TextureRect
var etiquette_quantite: Label
var etiquette_equipe: Label

func _ready() -> void:
	custom_minimum_size = Vector2(92.0, 104.0)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_quand_souris_entre)
	mouse_exited.connect(_quand_souris_sort)
	_creer_contenu()
	_actualiser()

func configurer(nouvel_objet: Dictionary, est_equipe: bool = false) -> void:
	objet = nouvel_objet.duplicate(true)
	est_equipee = est_equipe
	if is_node_ready():
		_actualiser()

func definir_selectionnee(est_selectionnee: bool) -> void:
	selectionnee = est_selectionnee
	modulate = Color(1.12, 1.12, 1.18, 1.0) if selectionnee else Color.WHITE

func _gui_input(evenement: InputEvent) -> void:
	if evenement is InputEventMouseButton and evenement.button_index == MOUSE_BUTTON_LEFT and evenement.pressed:
		if evenement.double_click:
			objet_double_clique.emit(objet)
		else:
			objet_selectionne.emit(objet)
		accept_event()

func _get_drag_data(_position: Vector2) -> Variant:
	if objet.is_empty():
		return null
	var apercu := TextureRect.new()
	apercu.custom_minimum_size = Vector2(64.0, 64.0)
	apercu.texture = objet.get("icone", null) as Texture2D
	apercu.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	apercu.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	set_drag_preview(apercu)
	return {"origine": &"inventaire", "objet": objet.duplicate(true)}

func _creer_contenu() -> void:
	var marge := MarginContainer.new()
	marge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marge.add_theme_constant_override("margin_left", 8)
	marge.add_theme_constant_override("margin_top", 8)
	marge.add_theme_constant_override("margin_right", 8)
	marge.add_theme_constant_override("margin_bottom", 8)
	add_child(marge)
	var superposition := Control.new()
	superposition.mouse_filter = Control.MOUSE_FILTER_IGNORE
	superposition.custom_minimum_size = Vector2(76.0, 88.0)
	marge.add_child(superposition)
	texture_icone = TextureRect.new()
	texture_icone.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	superposition.add_child(texture_icone)
	etiquette_quantite = Label.new()
	etiquette_quantite.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	etiquette_quantite.offset_left = -46.0
	etiquette_quantite.offset_top = -24.0
	etiquette_quantite.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	etiquette_quantite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	superposition.add_child(etiquette_quantite)
	etiquette_equipe = Label.new()
	etiquette_equipe.text = "ÉQUIPÉ"
	etiquette_equipe.add_theme_font_size_override("font_size", 10)
	etiquette_equipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	superposition.add_child(etiquette_equipe)

func _actualiser() -> void:
	if texture_icone == null:
		return
	texture_icone.texture = objet.get("icone", null) as Texture2D
	var nom: String = String(objet.get("nom", objet.get("identifiant", "Objet")))
	tooltip_text = "%s\nQuantité : %d" % [nom, int(objet.get("quantite", 1))]
	etiquette_quantite.text = "x%d" % int(objet.get("quantite", 1))
	etiquette_quantite.visible = int(objet.get("quantite", 1)) > 1
	etiquette_equipe.visible = est_equipee

func _quand_souris_entre() -> void:
	survol_objet.emit(objet)

func _quand_souris_sort() -> void:
	fin_survol_objet.emit()

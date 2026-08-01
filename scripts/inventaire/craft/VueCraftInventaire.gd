extends VBoxContainer
class_name VueCraftInventaire

enum Mode {
	ASSEMBLAGE,
	DESASSEMBLAGE
}

var vue_assemblage: VueAssemblageInventaire
var vue_desassemblage: VueDesassemblageInventaire
var pile: TabContainer
var bouton_assemblage: Button
var bouton_desassemblage: Button

func _ready() -> void:
	add_theme_constant_override("separation", 10)
	var ancien_titre: Control = get_node_or_null("Titre") as Control
	var ancienne_information: Control = get_node_or_null("Information") as Control
	if ancien_titre != null:
		ancien_titre.hide()
	if ancienne_information != null:
		ancienne_information.hide()
	var barre := HBoxContainer.new()
	add_child(barre)
	var groupe := ButtonGroup.new()
	bouton_assemblage = Button.new()
	bouton_assemblage.text = "Assemblage"
	bouton_assemblage.toggle_mode = true
	bouton_assemblage.button_group = groupe
	bouton_assemblage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bouton_assemblage.pressed.connect(afficher_assemblage)
	barre.add_child(bouton_assemblage)
	bouton_desassemblage = Button.new()
	bouton_desassemblage.text = "Desassemblage"
	bouton_desassemblage.toggle_mode = true
	bouton_desassemblage.button_group = groupe
	bouton_desassemblage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bouton_desassemblage.pressed.connect(afficher_desassemblage)
	barre.add_child(bouton_desassemblage)
	pile = TabContainer.new()
	pile.tabs_visible = false
	pile.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(pile)
	vue_assemblage = VueAssemblageInventaire.new()
	vue_assemblage.name = "Assemblage"
	pile.add_child(vue_assemblage)
	vue_desassemblage = VueDesassemblageInventaire.new()
	vue_desassemblage.name = "Desassemblage"
	pile.add_child(vue_desassemblage)
	bouton_assemblage.button_pressed = true
	afficher_assemblage()

func configurer(gestionnaire: GestionnaireCraftInventaire) -> void:
	vue_assemblage.configurer(gestionnaire)
	vue_desassemblage.configurer(gestionnaire)

func utiliser_pour_assemblage(objet: Dictionary) -> void:
	afficher_assemblage()
	vue_assemblage.utiliser_objet(objet)

func utiliser_pour_desassemblage(objet: Dictionary) -> void:
	afficher_desassemblage()
	vue_desassemblage.selectionner_objet(objet)

func afficher_assemblage() -> void:
	if pile != null:
		pile.current_tab = Mode.ASSEMBLAGE
	if bouton_assemblage != null:
		bouton_assemblage.button_pressed = true

func afficher_desassemblage() -> void:
	if pile != null:
		pile.current_tab = Mode.DESASSEMBLAGE
	if bouton_desassemblage != null:
		bouton_desassemblage.button_pressed = true

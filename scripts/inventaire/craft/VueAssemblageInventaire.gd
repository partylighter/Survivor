extends VBoxContainer
class_name VueAssemblageInventaire

var gestionnaire: GestionnaireCraftInventaire
var slots: Array[SlotCraftInventaire] = []
var icone_resultat: TextureRect
var nom_resultat: Label
var etat: Label
var bouton_assembler: Button

func _ready() -> void:
	add_theme_constant_override("separation", 10)
	var titre := Label.new()
	titre.text = "ASSEMBLAGE"
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titre.add_theme_font_size_override("font_size", 18)
	add_child(titre)
	var aide := Label.new()
	aide.text = "Glissez jusqu'a 3 composants. L'ordre n'a pas d'importance."
	aide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(aide)
	var ligne_slots := HBoxContainer.new()
	ligne_slots.alignment = BoxContainer.ALIGNMENT_CENTER
	ligne_slots.add_theme_constant_override("separation", 8)
	add_child(ligne_slots)
	for index: int in TableCraftInventaire.NOMBRE_SLOTS:
		var slot := SlotCraftInventaire.new()
		slot.configurer(index, {})
		slot.depot_demande.connect(_deposer)
		slot.retrait_demande.connect(_retirer)
		ligne_slots.add_child(slot)
		slots.append(slot)
	var separation := HSeparator.new()
	add_child(separation)
	icone_resultat = TextureRect.new()
	icone_resultat.custom_minimum_size = Vector2(0.0, 110.0)
	icone_resultat.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icone_resultat.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(icone_resultat)
	nom_resultat = Label.new()
	nom_resultat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nom_resultat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(nom_resultat)
	bouton_assembler = Button.new()
	bouton_assembler.text = "Assembler"
	bouton_assembler.pressed.connect(_assembler)
	add_child(bouton_assembler)
	etat = Label.new()
	etat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(etat)
	_rafraichir()

func configurer(nouveau_gestionnaire: GestionnaireCraftInventaire) -> void:
	gestionnaire = nouveau_gestionnaire
	if gestionnaire != null:
		gestionnaire.table_changee.connect(_rafraichir)
		gestionnaire.recette_changee.connect(_quand_recette_changee)
		gestionnaire.assemblage_reussi.connect(_quand_assemblage_reussi)
	if is_node_ready():
		_rafraichir()

func utiliser_objet(objet: Dictionary) -> bool:
	if gestionnaire == null or not gestionnaire.deposer_dans_premier_slot(objet):
		_afficher_erreur()
		return false
	etat.text = "Composant depose."
	return true

func _deposer(index_slot: int, objet: Dictionary) -> void:
	if gestionnaire != null and gestionnaire.deposer_objet(index_slot, objet):
		etat.text = "Composant depose."
	else:
		_afficher_erreur()

func _retirer(index_slot: int) -> void:
	if gestionnaire != null and gestionnaire.retirer_objet(index_slot):
		etat.text = "Composant rendu a l'inventaire."
	else:
		_afficher_erreur()

func _assembler() -> void:
	if gestionnaire == null or gestionnaire.assembler().is_empty():
		_afficher_erreur()

func _rafraichir() -> void:
	if not is_node_ready():
		return
	for index: int in slots.size():
		slots[index].configurer(index, gestionnaire.table.obtenir(index) if gestionnaire != null else {})
	var recette: RecetteEquipement = gestionnaire.recette_detectee if gestionnaire != null else null
	icone_resultat.texture = recette.resultat.icone if recette != null else null
	nom_resultat.text = "Resultat : %s" % recette.resultat.nom_affiche if recette != null else "Aucune recette reconnue"
	bouton_assembler.disabled = recette == null

func _quand_recette_changee(_recette: RecetteEquipement) -> void:
	_rafraichir()

func _quand_assemblage_reussi(resultat: Dictionary) -> void:
	etat.text = "%s a ete ajoute a l'inventaire." % String(resultat.get("nom", "Equipement"))

func _afficher_erreur() -> void:
	etat.text = gestionnaire.derniere_erreur if gestionnaire != null else "Gestionnaire de craft introuvable."

extends VBoxContainer
class_name VueDesassemblageInventaire

var gestionnaire: GestionnaireCraftInventaire
var cible: CibleDesassemblageInventaire
var liste_composants: VBoxContainer
var bouton_desassembler: Button
var etat: Label

func _ready() -> void:
	add_theme_constant_override("separation", 10)
	var titre := Label.new()
	titre.text = "DESASSEMBLAGE"
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titre.add_theme_font_size_override("font_size", 18)
	add_child(titre)
	var aide := Label.new()
	aide.text = "L'equipement reste dans l'inventaire jusqu'a confirmation."
	aide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(aide)
	cible = CibleDesassemblageInventaire.new()
	cible.objet_depose.connect(selectionner_objet)
	add_child(cible)
	var libelle := Label.new()
	libelle.text = "Composants recuperes :"
	add_child(libelle)
	liste_composants = VBoxContainer.new()
	add_child(liste_composants)
	bouton_desassembler = Button.new()
	bouton_desassembler.text = "Desassembler"
	bouton_desassembler.pressed.connect(_desassembler)
	add_child(bouton_desassembler)
	etat = Label.new()
	etat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(etat)
	_rafraichir()

func configurer(nouveau_gestionnaire: GestionnaireCraftInventaire) -> void:
	gestionnaire = nouveau_gestionnaire
	if gestionnaire != null:
		gestionnaire.cible_desassemblage_changee.connect(_quand_cible_changee)
		gestionnaire.desassemblage_reussi.connect(_quand_desassemblage_reussi)
	if is_node_ready():
		_rafraichir()

func selectionner_objet(objet: Dictionary) -> bool:
	if gestionnaire == null or not gestionnaire.selectionner_pour_desassemblage(objet):
		etat.text = gestionnaire.derniere_erreur if gestionnaire != null else "Gestionnaire de craft introuvable."
		return false
	etat.text = "Confirmez pour recuperer les composants affiches."
	return true

func _desassembler() -> void:
	if gestionnaire == null or not gestionnaire.desassembler():
		etat.text = gestionnaire.derniere_erreur if gestionnaire != null else "Gestionnaire de craft introuvable."

func _rafraichir() -> void:
	if not is_node_ready():
		return
	for enfant: Node in liste_composants.get_children():
		liste_composants.remove_child(enfant)
		enfant.queue_free()
	var objet: Dictionary = gestionnaire.cible_desassemblage if gestionnaire != null else {}
	cible.afficher(objet)
	var composants: Array[Dictionary] = []
	if gestionnaire != null:
		composants = gestionnaire.obtenir_composants_desassemblage()
	for composant: Dictionary in composants:
		var ligne := Label.new()
		ligne.text = "%s x%d" % [String(composant.get("nom", composant.get("identifiant", "Composant"))), int(composant.get("quantite", 0))]
		liste_composants.add_child(ligne)
	if composants.is_empty():
		var vide := Label.new()
		vide.text = "Aucun"
		liste_composants.add_child(vide)
	bouton_desassembler.disabled = objet.is_empty() or composants.is_empty()

func _quand_cible_changee(_objet: Dictionary) -> void:
	_rafraichir()

func _quand_desassemblage_reussi(objet: Dictionary) -> void:
	etat.text = "%s a ete desassemble." % String(objet.get("nom", "L'equipement"))
	_rafraichir()

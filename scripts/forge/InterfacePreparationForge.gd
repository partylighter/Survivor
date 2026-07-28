extends CanvasLayer
class_name InterfacePreparationForge

@export_node_path("GestionnaireForge") var chemin_gestionnaire: NodePath

@onready var gestionnaire: GestionnaireForge = get_node_or_null(chemin_gestionnaire) as GestionnaireForge
@onready var interface: Control = $Interface
@onready var commande: Label = $Interface/Panneau/Marge/Colonne/Commande
@onready var liste_materiaux: VBoxContainer = $Interface/Panneau/Marge/Colonne/ListeMateriaux
@onready var prochaine_etape: Label = $Interface/Panneau/Marge/Colonne/ProchaineEtape
@onready var message: Label = $Interface/Panneau/Marge/Colonne/Message
@onready var bouton_preparer: Button = $Interface/Panneau/Marge/Colonne/Boutons/Preparer
@onready var bouton_fermer: Button = $Interface/Panneau/Marge/Colonne/Boutons/Fermer

var selection: Dictionary = {}
var type_poste_actuel: int = -1
var inventaire_actuel: GestionnaireInventaire

func _ready() -> void:
	interface.hide()
	bouton_preparer.pressed.connect(_preparer)
	bouton_fermer.pressed.connect(_fermer)
	if gestionnaire != null:
		gestionnaire.fabrication_changee.connect(_quand_fabrication_changee)
	else:
		push_error("GestionnaireForge introuvable. Verifie chemin_gestionnaire dans InterfacePreparationForge.")

func ouvrir(type_poste: int = -1) -> void:
	type_poste_actuel = type_poste
	inventaire_actuel = gestionnaire.obtenir_inventaire_joueur_preparation() if gestionnaire != null else null
	if inventaire_actuel != null and not inventaire_actuel.inventaire_change.is_connected(_quand_inventaire_change):
		inventaire_actuel.inventaire_change.connect(_quand_inventaire_change)
	interface.show()
	_rafraichir()

func fermer() -> void:
	if inventaire_actuel != null and inventaire_actuel.inventaire_change.is_connected(_quand_inventaire_change):
		inventaire_actuel.inventaire_change.disconnect(_quand_inventaire_change)
	inventaire_actuel = null
	interface.hide()

func _fermer() -> void:
	if gestionnaire != null:
		gestionnaire.fermer_interfaces_forge()
	else:
		fermer()

func _preparer() -> void:
	if gestionnaire == null:
		message.text = "Gestionnaire de forge introuvable."
		return
	if gestionnaire.fabrication_active != null:
		if gestionnaire.fabrication_active.est_prete_assemblage():
			message.text = "Va à la table de finition pour commencer l'assemblage."
			_rafraichir(false)
			return
		var etape_active: EtapeFabrication = gestionnaire.fabrication_active.obtenir_etape_actuelle()
		if etape_active != null and etape_active.type_etape == EtapeFabrication.TypeEtape.CHAUFFE:
			message.text = "Etape demarree." if gestionnaire.demarrer_chauffe() else "Impossible de demarrer cette etape."
		elif etape_active != null and etape_active.type_etape == EtapeFabrication.TypeEtape.FONTE:
			message.text = "Etape demarree." if gestionnaire.demarrer_fonte() else "Impossible de demarrer cette etape."
		elif etape_active != null and etape_active.type_etape == EtapeFabrication.TypeEtape.MARTELAGE:
			message.text = "Va à l'enclume pour commencer le martelage."
		elif etape_active != null and etape_active.type_etape == EtapeFabrication.TypeEtape.MOULAGE:
			message.text = "Va à la zone de moulage."
		else:
			message.text = "Fabrication terminée."
		_rafraichir(false)
		return
	if gestionnaire.preparer_fabrication(selection):
		if type_poste_actuel == EtapeFabrication.TypeEtape.CHAUFFE:
			message.text = "Chauffe démarrée." if gestionnaire.demarrer_chauffe() else "Fabrication préparée, mais la chauffe ne peut pas démarrer."
		elif type_poste_actuel == EtapeFabrication.TypeEtape.FONTE:
			message.text = "Fonte démarrée." if gestionnaire.demarrer_fonte() else "Fabrication préparée, mais la fonte ne peut pas démarrer."
		else:
			message.text = "Fabrication préparée."
	else:
		message.text = gestionnaire.derniere_erreur_preparation
	_rafraichir(false)

func _rafraichir(effacer_message: bool = true) -> void:
	for enfant: Node in liste_materiaux.get_children():
		liste_materiaux.remove_child(enfant)
		enfant.queue_free()
	selection.clear()
	if effacer_message:
		message.text = ""
	if gestionnaire == null:
		commande.text = "Aucun gestionnaire de forge."
		prochaine_etape.text = ""
		bouton_preparer.disabled = true
		return
	var recette: RecetteComposant = gestionnaire.obtenir_recette_commande_active()
	if recette == null:
		commande.text = "Aucune commande active."
		prochaine_etape.text = ""
		message.text = "Accepte d'abord une commande dans la boutique."
		bouton_preparer.disabled = true
		return
	if not recette.est_valide():
		commande.text = "Recette invalide."
		prochaine_etape.text = ""
		message.text = " ".join(recette.obtenir_erreurs())
		bouton_preparer.disabled = true
		return
	commande.text = "Composant : %s" % recette.resultat.nom_affiche
	var inventaire: GestionnaireInventaire = inventaire_actuel
	for ingredient: IngredientRecette in recette.ingredients:
		if ingredient != null and ingredient.objet != null:
			_ajouter_ligne_materiau(ingredient, inventaire)
	var etape: EtapeFabrication = recette.etapes[0] if not recette.etapes.is_empty() else null
	prochaine_etape.text = "Première étape : %s" % _nom_etape(etape)
	if gestionnaire.fabrication_active == null:
		bouton_preparer.text = "Préparer et commencer"
		var poste_correct: bool = etape != null and etape.type_etape == type_poste_actuel
		var materiaux_suffisants: bool = inventaire != null and recette.peut_fabriquer(inventaire)
		bouton_preparer.disabled = not poste_correct or not materiaux_suffisants
		if inventaire == null:
			message.text = "Inventaire introuvable."
		elif not materiaux_suffisants:
			message.text = "Matériaux insuffisants. Récupère-les dans la réserve."
	else:
		var etape_active: EtapeFabrication = gestionnaire.fabrication_active.obtenir_etape_actuelle()
		var chauffe_disponible: bool = etape_active != null and etape_active.type_etape == EtapeFabrication.TypeEtape.CHAUFFE
		var fonte_disponible: bool = etape_active != null and etape_active.type_etape == EtapeFabrication.TypeEtape.FONTE
		var martelage_disponible: bool = etape_active != null and etape_active.type_etape == EtapeFabrication.TypeEtape.MARTELAGE
		var moulage_disponible: bool = etape_active != null and etape_active.type_etape == EtapeFabrication.TypeEtape.MOULAGE
		if chauffe_disponible:
			bouton_preparer.text = "Commencer la chauffe"
		elif fonte_disponible:
			bouton_preparer.text = "Commencer la fonte"
		elif martelage_disponible:
			bouton_preparer.text = "Martelage : va a l'enclume"
		elif moulage_disponible:
			bouton_preparer.text = "Moulage : va au moule"
		elif gestionnaire.fabrication_active.est_prete_assemblage():
			bouton_preparer.text = "Assemblage : va a la table de finition"
		else:
			bouton_preparer.text = "Fabrication terminée"
		bouton_preparer.disabled = not chauffe_disponible and not fonte_disponible
		if message.text == "":
			message.text = "Fabrication déjà préparée."

func _ajouter_ligne_materiau(ingredient: IngredientRecette, inventaire: GestionnaireInventaire) -> void:
	var identifiant: StringName = ingredient.objet.item_id
	var quantite_possedee: int = inventaire.obtenir_quantite(identifiant) if inventaire != null else 0
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 12)
	liste_materiaux.add_child(ligne)
	var nom_materiau := Label.new()
	nom_materiau.text = ingredient.objet.nom_affiche
	nom_materiau.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ligne.add_child(nom_materiau)
	var quantites := Label.new()
	quantites.text = "Possédé : %d | Nécessaire : %d" % [quantite_possedee, ingredient.quantite]
	quantites.custom_minimum_size.x = 260.0
	ligne.add_child(quantites)
	var choix := SpinBox.new()
	choix.min_value = 0.0
	choix.max_value = float(quantite_possedee)
	choix.step = 1.0
	choix.value = float(mini(quantite_possedee, ingredient.quantite))
	choix.custom_minimum_size.x = 90.0
	choix.value_changed.connect(_changer_quantite.bind(identifiant))
	ligne.add_child(choix)
	selection[identifiant] = int(choix.value)

func _changer_quantite(valeur: float, identifiant: StringName) -> void:
	selection[identifiant] = int(valeur)
	_actualiser_etat_bouton_selection()

func _quand_fabrication_changee() -> void:
	if interface.visible:
		_rafraichir()

func _quand_inventaire_change() -> void:
	if interface.visible:
		_rafraichir(false)

func _actualiser_etat_bouton_selection() -> void:
	if gestionnaire == null or gestionnaire.fabrication_active != null:
		return
	var recette: RecetteComposant = gestionnaire.obtenir_recette_commande_active()
	if recette == null or not recette.est_valide() or recette.etapes.is_empty():
		bouton_preparer.disabled = true
		return
	var inventaire: GestionnaireInventaire = inventaire_actuel
	var selection_valide: bool = inventaire != null and recette.etapes[0].type_etape == type_poste_actuel
	for ingredient: IngredientRecette in recette.ingredients:
		if ingredient == null or ingredient.objet == null or int(selection.get(ingredient.objet.item_id, 0)) != ingredient.quantite:
			selection_valide = false
			break
	bouton_preparer.disabled = not selection_valide

func _nom_etape(etape: EtapeFabrication) -> String:
	if etape == null:
		return "Aucune"
	match etape.type_etape:
		EtapeFabrication.TypeEtape.CHAUFFE:
			return "Chauffe"
		EtapeFabrication.TypeEtape.FONTE:
			return "Fonte"
		EtapeFabrication.TypeEtape.MOULAGE:
			return "Moulage"
		EtapeFabrication.TypeEtape.MARTELAGE:
			return "Martelage"
	return "Inconnue"

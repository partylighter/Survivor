extends CanvasLayer
class_name InterfaceCoffreReserve

@export_node_path("GestionnaireForge") var chemin_gestionnaire_forge: NodePath

@onready var gestionnaire_forge: GestionnaireForge = get_node_or_null(chemin_gestionnaire_forge) as GestionnaireForge
@onready var coffre: GestionnaireCoffreReserve = $GestionnaireCoffreReserve
@onready var interface: Control = $Interface
@onready var commande: Label = $Interface/Panneau/Marge/Colonne/Commande
@onready var liste_stock: VBoxContainer = $Interface/Panneau/Marge/Colonne/ListeStock
@onready var message: Label = $Interface/Panneau/Marge/Colonne/Message
@onready var bouton_recuperer: Button = $Interface/Panneau/Marge/Colonne/Boutons/Recuperer
@onready var bouton_fermer: Button = $Interface/Panneau/Marge/Colonne/Boutons/Fermer

var inventaire_actuel: GestionnaireInventaire

func _ready() -> void:
	interface.hide()
	bouton_recuperer.pressed.connect(_recuperer_manquants)
	bouton_fermer.pressed.connect(fermer)
	coffre.stock_change.connect(_rafraichir)
	if gestionnaire_forge == null:
		push_error("GestionnaireForge introuvable. Verifie chemin_gestionnaire_forge dans InterfaceCoffreReserve.")

func ouvrir() -> void:
	inventaire_actuel = gestionnaire_forge.obtenir_inventaire_joueur_reserve() if gestionnaire_forge != null else null
	if inventaire_actuel != null and not inventaire_actuel.inventaire_change.is_connected(_quand_inventaire_change):
		inventaire_actuel.inventaire_change.connect(_quand_inventaire_change)
	interface.show()
	message.text = ""
	_rafraichir()

func fermer() -> void:
	if inventaire_actuel != null and inventaire_actuel.inventaire_change.is_connected(_quand_inventaire_change):
		inventaire_actuel.inventaire_change.disconnect(_quand_inventaire_change)
	inventaire_actuel = null
	interface.hide()

func _recuperer_manquants() -> void:
	if gestionnaire_forge == null:
		message.text = "Gestionnaire de forge introuvable."
		return
	var recette: RecetteComposant = gestionnaire_forge.obtenir_recette_commande_active()
	var inventaire: GestionnaireInventaire = inventaire_actuel
	if recette == null:
		message.text = "Accepte d'abord une commande dans la boutique."
		return
	if inventaire == null:
		message.text = "Inventaire du joueur introuvable."
		return
	var resultat: Dictionary = coffre.recuperer_ingredients_manquants(recette, inventaire)
	var quantite_totale: int = int(resultat.get("quantite_totale", 0))
	var stock_insuffisant: Array = resultat.get("stock_insuffisant", [])
	if not stock_insuffisant.is_empty():
		message.text = "Stock insuffisant : %s." % ", ".join(stock_insuffisant)
	elif quantite_totale > 0:
		message.text = "%d ingrédient(s) ajouté(s) à l'inventaire." % quantite_totale
	else:
		message.text = "Tu possèdes déjà tous les ingrédients nécessaires."
	_rafraichir(false)

func _rafraichir(effacer_message: bool = true) -> void:
	for enfant: Node in liste_stock.get_children():
		liste_stock.remove_child(enfant)
		enfant.queue_free()
	if effacer_message:
		message.text = ""
	var recette: RecetteComposant = gestionnaire_forge.obtenir_recette_commande_active() if gestionnaire_forge != null else null
	var inventaire: GestionnaireInventaire = inventaire_actuel
	if recette == null:
		commande.text = "Aucune commande active."
		bouton_recuperer.disabled = true
	elif not recette.est_valide():
		commande.text = "Recette invalide."
		bouton_recuperer.disabled = true
	else:
		commande.text = "Commande : %s" % recette.resultat.nom_affiche
		bouton_recuperer.disabled = inventaire == null or not _ingredients_manquants(recette, inventaire)
	for objet: LootItemEntry in coffre.objets_disponibles:
		if objet != null:
			_ajouter_ligne_stock(objet, recette, inventaire)

func _ajouter_ligne_stock(objet: LootItemEntry, recette: RecetteComposant, inventaire: GestionnaireInventaire) -> void:
	var necessaire: int = 0
	if recette != null:
		for ingredient: IngredientRecette in recette.ingredients:
			if ingredient != null and ingredient.objet != null and ingredient.objet.item_id == objet.item_id:
				necessaire = ingredient.quantite
	var possede: int = inventaire.obtenir_quantite(objet.item_id) if inventaire != null else 0
	var ligne := Label.new()
	ligne.text = "%s | Coffre : %d | Inventaire : %d | Nécessaire : %d" % [objet.nom_affiche, coffre.obtenir_stock(objet.item_id), possede, necessaire]
	liste_stock.add_child(ligne)

func _ingredients_manquants(recette: RecetteComposant, inventaire: GestionnaireInventaire) -> bool:
	for ingredient: IngredientRecette in recette.ingredients:
		if ingredient != null and ingredient.objet != null and inventaire.obtenir_quantite(ingredient.objet.item_id) < ingredient.quantite:
			return true
	return false

func _quand_inventaire_change() -> void:
	if interface.visible:
		_rafraichir(false)

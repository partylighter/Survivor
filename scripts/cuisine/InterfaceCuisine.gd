extends Control
class_name InterfaceCuisine

signal interface_fermee

@onready var panneau: PanelContainer = $Panneau
@onready var liste_ingredients: VBoxContainer = $Panneau/Marge/Colonne/Corps/Inventaire/Defilement/ListeIngredients
@onready var etiquette_inventaire_vide: Label = $Panneau/Marge/Colonne/Corps/Inventaire/InventaireVide
@onready var resultat: Label = $Panneau/Marge/Colonne/Resultat
@onready var message: Label = $Panneau/Marge/Colonne/Message
@onready var bouton_cuisiner: Button = $Panneau/Marge/Colonne/Actions/BoutonCuisiner
@onready var bouton_fermer: Button = $Panneau/Marge/Colonne/Actions/BoutonFermer
@onready var slots: Array[SlotCuisine] = [
	$Panneau/Marge/Colonne/Corps/Preparation/Slots/Slot0,
	$Panneau/Marge/Colonne/Corps/Preparation/Slots/Slot1,
	$Panneau/Marge/Colonne/Corps/Preparation/Slots/Slot2
]

var gestionnaire_cuisine: GestionnaireCuisine
var inventaire_connecte: GestionnaireInventaire

func _ready() -> void:
	for slot: SlotCuisine in slots:
		slot.configurer(self)
		slot.pressed.connect(_retirer_ingredient.bind(slot.index_slot))
	bouton_cuisiner.pressed.connect(_cuisiner)
	bouton_fermer.pressed.connect(fermer)
	hide()

func configurer(nouveau_gestionnaire: GestionnaireCuisine) -> void:
	gestionnaire_cuisine = nouveau_gestionnaire
	if gestionnaire_cuisine != null and not gestionnaire_cuisine.recette_changee.is_connected(_quand_recette_changee):
		gestionnaire_cuisine.recette_changee.connect(_quand_recette_changee)

func ouvrir() -> void:
	if gestionnaire_cuisine == null:
		return
	_connecter_inventaire(gestionnaire_cuisine.inventaire)
	message.text = ""
	_rafraichir()
	show()

func fermer() -> void:
	if gestionnaire_cuisine != null:
		gestionnaire_cuisine.rendre_tous_les_ingredients()
	_connecter_inventaire(null)
	hide()
	interface_fermee.emit()

func deposer_ingredient_depuis_glisser(index_slot: int, donnees: Dictionary) -> void:
	if gestionnaire_cuisine == null or donnees.get("type", &"") != &"ingredient_cuisine":
		return
	var objet: Dictionary = donnees.get("objet", {})
	if gestionnaire_cuisine.deposer_ingredient(index_slot, objet):
		message.text = "Ingredient depose."
	else:
		message.text = "Depot impossible dans cet emplacement."
	_rafraichir()

func _retirer_ingredient(index_slot: int) -> void:
	if gestionnaire_cuisine != null and gestionnaire_cuisine.retirer_ingredient(index_slot):
		message.text = "Ingredient rendu a l'inventaire."
	_rafraichir()

func _cuisiner() -> void:
	if gestionnaire_cuisine == null:
		return
	if gestionnaire_cuisine.cuisiner():
		message.text = "Recette cuisinee."
	else:
		message.text = "La recette ne peut pas etre cuisinee."
	_rafraichir()

func _rafraichir() -> void:
	_rafraichir_slots()
	_rafraichir_inventaire()
	var recette: RecetteCuisine = gestionnaire_cuisine.trouver_recette() if gestionnaire_cuisine != null else null
	_quand_recette_changee(recette)

func _rafraichir_slots() -> void:
	for slot: SlotCuisine in slots:
		var objet: Dictionary = gestionnaire_cuisine.table_cuisine.obtenir_objet(slot.index_slot) if gestionnaire_cuisine != null and gestionnaire_cuisine.table_cuisine != null else {}
		if objet.is_empty():
			slot.text = "Slot %d\nVide" % (slot.index_slot + 1)
			slot.tooltip_text = "Deposer un ingredient ici."
		else:
			slot.text = "%s\nx1" % objet.get("nom", objet.get("identifiant", ""))
			slot.tooltip_text = "Cliquer pour rendre cet ingredient."

func _rafraichir_inventaire() -> void:
	for enfant: Node in liste_ingredients.get_children():
		liste_ingredients.remove_child(enfant)
		enfant.queue_free()
	var nombre_ingredients: int = 0
	if gestionnaire_cuisine != null and gestionnaire_cuisine.inventaire != null:
		for objet: Dictionary in gestionnaire_cuisine.inventaire.obtenir_objets():
			var identifiant: StringName = objet.get("identifiant", &"")
			if not gestionnaire_cuisine.est_ingredient_autorise(identifiant):
				continue
			var bouton := BoutonIngredientCuisine.new()
			bouton.configurer(objet)
			liste_ingredients.add_child(bouton)
			nombre_ingredients += 1
	etiquette_inventaire_vide.visible = nombre_ingredients == 0

func _quand_recette_changee(recette: RecetteCuisine) -> void:
	if recette == null:
		resultat.text = "Recette inconnue"
		bouton_cuisiner.disabled = true
	else:
		resultat.text = "Resultat : %s x%d" % [recette.resultat.nom_affiche, recette.quantite_resultat]
		bouton_cuisiner.disabled = false

func _connecter_inventaire(nouvel_inventaire: GestionnaireInventaire) -> void:
	if inventaire_connecte != null and inventaire_connecte.inventaire_change.is_connected(_quand_inventaire_change):
		inventaire_connecte.inventaire_change.disconnect(_quand_inventaire_change)
	inventaire_connecte = nouvel_inventaire
	if inventaire_connecte != null and not inventaire_connecte.inventaire_change.is_connected(_quand_inventaire_change):
		inventaire_connecte.inventaire_change.connect(_quand_inventaire_change)

func _quand_inventaire_change() -> void:
	if visible:
		_rafraichir_inventaire()
		_rafraichir_slots()

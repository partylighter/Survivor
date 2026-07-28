extends CanvasLayer
class_name InterfaceAssemblageForge

@export_node_path("GestionnaireForge") var chemin_gestionnaire_forge: NodePath

@onready var gestionnaire_forge: GestionnaireForge = get_node_or_null(chemin_gestionnaire_forge) as GestionnaireForge
@onready var table_forge: TableForge = $TableForge
@onready var gestionnaire_assemblage: GestionnaireAssemblage = $GestionnaireAssemblage
@onready var gestionnaire_recettes: GestionnaireRecettesAssemblage = $GestionnaireRecettesAssemblage
@onready var interface: Control = $Interface
@onready var recette: Label = $Interface/Panneau/Marge/Colonne/Recette
@onready var qualite: Label = $Interface/Panneau/Marge/Colonne/Qualite
@onready var detection: Label = $Interface/Panneau/Marge/Colonne/Detection
@onready var liste_inventaire: VBoxContainer = $Interface/Panneau/Marge/Colonne/Corps/Inventaire/ListeInventaire
@onready var message: Label = $Interface/Panneau/Marge/Colonne/Message
@onready var resultat: Label = $Interface/Panneau/Marge/Colonne/Resultat
@onready var bouton_retirer: Button = $Interface/Panneau/Marge/Colonne/Actions/Retirer
@onready var bouton_assembler: Button = $Interface/Panneau/Marge/Colonne/Actions/Assembler
@onready var bouton_fermer: Button = $Interface/Panneau/Marge/Colonne/Actions/Fermer
@onready var bouton_recommencer: Button = $Interface/Panneau/Marge/Colonne/Recommencer
@onready var boutons_slots: Array[Button] = [
	$Interface/Panneau/Marge/Colonne/Corps/Table/Slots/Slot0,
	$Interface/Panneau/Marge/Colonne/Corps/Table/Slots/Slot1,
	$Interface/Panneau/Marge/Colonne/Corps/Table/Slots/Slot2,
	$Interface/Panneau/Marge/Colonne/Corps/Table/Slots/Slot3,
	$Interface/Panneau/Marge/Colonne/Corps/Table/Slots/Slot4,
	$Interface/Panneau/Marge/Colonne/Corps/Table/Slots/Slot5,
	$Interface/Panneau/Marge/Colonne/Corps/Table/Slots/Slot6,
	$Interface/Panneau/Marge/Colonne/Corps/Table/Slots/Slot7,
	$Interface/Panneau/Marge/Colonne/Corps/Table/Slots/Slot8
]

var inventaire: GestionnaireInventaire
var index_slot_selectionne: int = -1
var objet_inventaire_selectionne: Dictionary = {}
var recette_detectee: RecetteEquipement
var dernier_resultat_assemblage: Dictionary = {}

func _ready() -> void:
	add_to_group(&"interface_assemblage_forge")
	interface.hide()
	table_forge.table_changee.connect(_quand_table_changee)
	for index: int in boutons_slots.size():
		boutons_slots[index].pressed.connect(_cliquer_slot.bind(index))
	bouton_retirer.pressed.connect(_retirer_selection)
	bouton_assembler.pressed.connect(_assembler)
	bouton_fermer.pressed.connect(_fermer)
	bouton_recommencer.pressed.connect(_recommencer)
	if gestionnaire_forge == null:
		push_error("GestionnaireForge introuvable. Verifie chemin_gestionnaire_forge dans InterfaceAssemblageForge.")

func ouvrir() -> bool:
	if gestionnaire_forge == null or not gestionnaire_forge.assemblage_est_disponible():
		return false
	inventaire = gestionnaire_forge.obtenir_inventaire_joueur_assemblage()
	if inventaire == null:
		return false
	if not inventaire.inventaire_change.is_connected(_quand_inventaire_change):
		inventaire.inventaire_change.connect(_quand_inventaire_change)
	table_forge.reinitialiser()
	index_slot_selectionne = -1
	objet_inventaire_selectionne.clear()
	recette_detectee = null
	dernier_resultat_assemblage.clear()
	message.text = ""
	resultat.text = ""
	bouton_recommencer.show()
	bouton_assembler.disabled = true
	bouton_retirer.disabled = false
	_rafraichir()
	interface.show()
	return true

func fermer() -> void:
	if inventaire != null and inventaire.inventaire_change.is_connected(_quand_inventaire_change):
		inventaire.inventaire_change.disconnect(_quand_inventaire_change)
	_rendre_toute_la_grille()
	inventaire = null
	interface.hide()

func _selectionner_objet_inventaire(objet: Dictionary) -> void:
	if inventaire == null or inventaire.obtenir_quantite(objet.get("identifiant", &"")) <= 0:
		return
	objet_inventaire_selectionne = objet.duplicate(true)
	index_slot_selectionne = -1
	message.text = "Clique sur une case de la grille pour deposer ce composant."
	_rafraichir()

func _deposer_objet_selectionne(index_slot: int) -> void:
	if inventaire == null or objet_inventaire_selectionne.is_empty():
		return
	var identifiant: StringName = objet_inventaire_selectionne.get("identifiant", &"")
	if inventaire.obtenir_quantite(identifiant) <= 0:
		objet_inventaire_selectionne.clear()
		message.text = "Cet objet n'est plus disponible."
		return
	var objet_slot: Dictionary = objet_inventaire_selectionne.duplicate(true)
	objet_slot["quantite"] = 1
	if not table_forge.ajouter_objet_dans_slot(index_slot, objet_slot):
		message.text = "Cette case contient deja un autre composant."
		return
	inventaire.retirer_objet(identifiant, 1)
	if inventaire.obtenir_quantite(identifiant) <= 0:
		objet_inventaire_selectionne.clear()
	if objet_inventaire_selectionne.is_empty():
		message.text = ""
	else:
		message.text = "Composant selectionne : %s. Clique une case de la grille." % objet_inventaire_selectionne.get("nom", identifiant)

func deposer_objet_depuis_glisser(index_slot: int, donnees: Dictionary) -> void:
	var objet: Dictionary = donnees.get("objet", {})
	if objet.is_empty() or int(objet.get("type_item", -1)) != Loot.TypeItem.COMPOSANT:
		return
	objet_inventaire_selectionne = objet.duplicate(true)
	_deposer_objet_selectionne(index_slot)
	objet_inventaire_selectionne.clear()
	if message.text == "":
		message.text = "Composant depose dans la grille."
	_rafraichir()

func _cliquer_slot(index_slot: int) -> void:
	if not objet_inventaire_selectionne.is_empty():
		_deposer_objet_selectionne(index_slot)
		return
	if index_slot_selectionne >= 0 and index_slot_selectionne != index_slot:
		if table_forge.obtenir_objet_du_slot(index_slot).is_empty():
			table_forge.deplacer_objet(index_slot_selectionne, index_slot)
			index_slot_selectionne = -1
		else:
			index_slot_selectionne = index_slot
	elif table_forge.obtenir_objet_du_slot(index_slot).is_empty():
		index_slot_selectionne = -1
	else:
		index_slot_selectionne = index_slot
	_rafraichir_table()

func _retirer_selection() -> void:
	if index_slot_selectionne < 0:
		message.text = "Selectionne d'abord un emplacement."
		return
	var objet: Dictionary = table_forge.retirer_objet_du_slot(index_slot_selectionne)
	_rendre_objet_inventaire(objet)
	index_slot_selectionne = -1
	message.text = ""
	_rafraichir()

func _assembler() -> void:
	recette_detectee = gestionnaire_recettes.trouver_recette(table_forge) if gestionnaire_recettes != null else null
	if recette_detectee == null:
		message.text = "Aucun motif de fabrication reconnu."
		return
	var nouveau_resultat: Dictionary = gestionnaire_assemblage.assembler_objet(recette_detectee, table_forge, inventaire, gestionnaire_recettes)
	if nouveau_resultat.is_empty():
		message.text = gestionnaire_assemblage.derniere_erreur
		return
	gestionnaire_forge.terminer_assemblage(nouveau_resultat)
	message.text = "Assemblage termine."
	dernier_resultat_assemblage = nouveau_resultat.duplicate(true)
	resultat.text = "%s x%d - Qualite : %s" % [nouveau_resultat.get("nom", ""), int(nouveau_resultat.get("quantite", 0)), String(nouveau_resultat.get("qualite", &"")).capitalize()]
	_rafraichir_table()
	_rafraichir_inventaire()

func _fermer() -> void:
	if gestionnaire_forge != null:
		gestionnaire_forge.fermer_interfaces_forge()
	else:
		fermer()

func _recommencer() -> void:
	_rendre_toute_la_grille()
	index_slot_selectionne = -1
	objet_inventaire_selectionne.clear()
	message.text = ""
	resultat.text = ""
	dernier_resultat_assemblage.clear()
	_rafraichir()

func _rafraichir() -> void:
	recette.text = "Choisis un composant dans l'inventaire, puis clique une case de la grille."
	qualite.text = "Qualité finale prévue : %s" % String(_obtenir_qualite_prevue()).capitalize()
	_rafraichir_table()
	_rafraichir_inventaire()

func _rafraichir_table() -> void:
	for index: int in boutons_slots.size():
		var objet: Dictionary = table_forge.obtenir_objet_du_slot(index)
		if objet.is_empty():
			boutons_slots[index].text = "Emplacement %d\nVide" % (index + 1)
		else:
			var donnees: Dictionary = objet.get("donnees", {})
			boutons_slots[index].text = "%s\nx%d\nQualité : %s" % [objet.get("nom", objet.get("identifiant", "")), int(objet.get("quantite", 1)), String(donnees.get("qualite", "correcte")).capitalize()]
		boutons_slots[index].modulate = Color(1.0, 1.0, 1.0, 0.7) if index == index_slot_selectionne else Color.WHITE
	recette_detectee = gestionnaire_recettes.trouver_recette(table_forge) if gestionnaire_recettes != null else null
	if recette_detectee != null:
		detection.text = "Motif reconnu : %s" % recette_detectee.nom
		recette.text = "Recette detectee independamment de la commande."
		if dernier_resultat_assemblage.is_empty():
			resultat.text = "Resultat disponible : %s x%d" % [recette_detectee.resultat.nom_affiche, recette_detectee.quantite_resultat]
		bouton_assembler.disabled = false
	else:
		detection.text = "Aucun motif reconnu."
		recette.text = "Choisis un composant dans l'inventaire, puis clique une case de la grille."
		if dernier_resultat_assemblage.is_empty():
			resultat.text = ""
		bouton_assembler.disabled = true

func _obtenir_qualite_prevue() -> StringName:
	var tous_parfaits: bool = true
	var au_moins_un_composant: bool = false
	for index: int in TableForge.NOMBRE_SLOTS:
		var objet: Dictionary = table_forge.obtenir_objet_du_slot(index)
		if objet.is_empty():
			continue
		au_moins_un_composant = true
		var qualite_composant: StringName = objet.get("donnees", {}).get("qualite", &"correcte")
		if qualite_composant == &"mauvaise":
			return &"mauvaise"
		if qualite_composant != &"parfaite":
			tous_parfaits = false
	return &"parfaite" if au_moins_un_composant and tous_parfaits else &"correcte"

func _rafraichir_inventaire() -> void:
	for enfant: Node in liste_inventaire.get_children():
		liste_inventaire.remove_child(enfant)
		enfant.queue_free()
	if inventaire == null:
		return
	for objet: Dictionary in inventaire.obtenir_objets():
		if int(objet.get("type_item", -1)) != Loot.TypeItem.COMPOSANT:
			continue
		var bouton := BoutonComposantAssemblageForge.new()
		var identifiant: StringName = objet.get("identifiant", &"")
		bouton.configurer(objet)
		bouton.modulate = Color(1.0, 1.0, 1.0, 0.7) if not objet_inventaire_selectionne.is_empty() and objet_inventaire_selectionne.get("identifiant", &"") == identifiant else Color.WHITE
		bouton.pressed.connect(_selectionner_objet_inventaire.bind(objet))
		liste_inventaire.add_child(bouton)

func _rendre_objet_inventaire(objet: Dictionary) -> void:
	if inventaire == null or objet.is_empty():
		return
	inventaire.ajouter_objet(objet.get("identifiant", &""), objet.get("nom", ""), int(objet.get("quantite", 0)), objet.get("icone", null), int(objet.get("type_item", -1)), objet.get("donnees", {}))

func _rendre_toute_la_grille() -> void:
	if inventaire == null:
		table_forge.reinitialiser()
		return
	for objet: Dictionary in table_forge.extraire_tous_les_objets():
		_rendre_objet_inventaire(objet)

func _quand_table_changee() -> void:
	_rafraichir_table()
	_rafraichir_inventaire()

func _quand_inventaire_change() -> void:
	if interface.visible:
		_rafraichir_inventaire()
		_rafraichir_table()

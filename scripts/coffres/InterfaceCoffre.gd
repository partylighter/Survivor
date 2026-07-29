extends CanvasLayer
class_name InterfaceCoffre

const SCENE_EMPLACEMENT: PackedScene = preload("res://scenes/ui/emplacement_coffre.tscn")

@onready var interface: Control = $Interface
@onready var grille_coffre: GridContainer = $Interface/Fond/Marge/Colonne/DefilementCoffre/GrilleCoffre
@onready var grille_inventaire: GridContainer = $Interface/Fond/Marge/Colonne/DefilementInventaire/GrilleInventaire
@onready var inventaire_vide: Label = $Interface/Fond/Marge/Colonne/InventaireVide
@onready var depot_inventaire: EmplacementCoffre = $Interface/Fond/Marge/Colonne/DepotInventaire
@onready var message: Label = $Interface/Fond/Marge/Colonne/Message
@onready var bouton_fermer: Button = $Interface/Fond/Marge/Colonne/Fermer
@onready var invite: Label = $Invite

var coffre_actuel: CoffreMonde
var inventaire_actuel: GestionnaireInventaire

func _ready() -> void:
	interface.hide()
	invite.hide()
	bouton_fermer.pressed.connect(fermer)
	depot_inventaire.configurer(EmplacementCoffre.TYPE_INVENTAIRE, -1, {}, "Déposer dans l'inventaire")
	depot_inventaire.depot_demande.connect(_quand_depot_demande)

func _input(event: InputEvent) -> void:
	if not interface.visible or not event.is_action_pressed(&"fermer_interface"):
		return
	fermer()
	get_viewport().set_input_as_handled()

func ouvrir(nouveau_coffre: CoffreMonde, nouvel_inventaire: GestionnaireInventaire) -> void:
	if nouveau_coffre == null or nouveau_coffre.gestionnaire_coffre == null or nouvel_inventaire == null:
		push_error("Impossible d'ouvrir le coffre : coffre ou inventaire introuvable.")
		return
	_deconnecter_signaux()
	coffre_actuel = nouveau_coffre
	inventaire_actuel = nouvel_inventaire
	coffre_actuel.gestionnaire_coffre.contenu_change.connect(_rafraichir)
	inventaire_actuel.inventaire_change.connect(_rafraichir)
	message.text = ""
	invite.hide()
	interface.show()
	_rafraichir()

func fermer() -> void:
	if not interface.visible:
		return
	var coffre_ferme: CoffreMonde = coffre_actuel
	_deconnecter_signaux()
	interface.hide()
	coffre_actuel = null
	inventaire_actuel = null
	invite.visible = coffre_ferme != null and coffre_ferme.joueur_proche != null

func afficher_invite(doit_afficher: bool) -> void:
	invite.visible = doit_afficher and not interface.visible

func _deconnecter_signaux() -> void:
	if coffre_actuel != null and coffre_actuel.gestionnaire_coffre != null and coffre_actuel.gestionnaire_coffre.contenu_change.is_connected(_rafraichir):
		coffre_actuel.gestionnaire_coffre.contenu_change.disconnect(_rafraichir)
	if inventaire_actuel != null and inventaire_actuel.inventaire_change.is_connected(_rafraichir):
		inventaire_actuel.inventaire_change.disconnect(_rafraichir)

func _rafraichir() -> void:
	if coffre_actuel == null or inventaire_actuel == null:
		return
	_vider_conteneur(grille_coffre)
	var emplacements: Array[Dictionary] = coffre_actuel.gestionnaire_coffre.obtenir_emplacements()
	for index: int in emplacements.size():
		_ajouter_emplacement(grille_coffre, EmplacementCoffre.TYPE_COFFRE, index, emplacements[index], "")
	_vider_conteneur(grille_inventaire)
	var objets: Array[Dictionary] = inventaire_actuel.obtenir_objets()
	inventaire_vide.visible = objets.is_empty()
	for index: int in objets.size():
		_ajouter_emplacement(grille_inventaire, EmplacementCoffre.TYPE_INVENTAIRE, index, objets[index])

func _vider_conteneur(conteneur: Control) -> void:
	for enfant: Node in conteneur.get_children():
		conteneur.remove_child(enfant)
		enfant.queue_free()

func _ajouter_emplacement(conteneur: Control, type_source: int, index_source: int, objet: Dictionary, texte_vide: String = "Vide") -> void:
	var emplacement: EmplacementCoffre = SCENE_EMPLACEMENT.instantiate() as EmplacementCoffre
	conteneur.add_child(emplacement)
	emplacement.configurer(type_source, index_source, objet, texte_vide)
	emplacement.depot_demande.connect(_quand_depot_demande)
	emplacement.transfert_rapide_demande.connect(_quand_transfert_rapide_demande)

func _quand_depot_demande(donnees: Dictionary, type_destination: int, index_destination: int) -> void:
	var type_source: int = int(donnees.get("origine", -1))
	var index_source: int = int(donnees.get("index_source", -1))
	var objet: Dictionary = donnees.get("objet", {})
	if type_source == EmplacementCoffre.TYPE_COFFRE and type_destination == EmplacementCoffre.TYPE_COFFRE:
		if coffre_actuel.gestionnaire_coffre.deplacer_emplacement(index_source, index_destination):
			message.text = "Objet déplacé dans le coffre."
		return
	if type_source == EmplacementCoffre.TYPE_INVENTAIRE and type_destination == EmplacementCoffre.TYPE_COFFRE:
		_transferer_inventaire_vers_coffre(objet, -1, index_destination)
	elif type_source == EmplacementCoffre.TYPE_COFFRE and type_destination == EmplacementCoffre.TYPE_INVENTAIRE:
		_transferer_coffre_vers_inventaire(index_source, -1)

func _quand_transfert_rapide_demande(type_source: int, index_source: int, objet: Dictionary, quantite: int) -> void:
	if type_source == EmplacementCoffre.TYPE_COFFRE:
		_transferer_coffre_vers_inventaire(index_source, quantite)
	elif type_source == EmplacementCoffre.TYPE_INVENTAIRE:
		_transferer_inventaire_vers_coffre(objet, quantite)

func _transferer_coffre_vers_inventaire(index_source: int, quantite: int) -> void:
	if coffre_actuel == null or inventaire_actuel == null:
		return
	var objet_retire: Dictionary = coffre_actuel.gestionnaire_coffre.retirer_emplacement(index_source, quantite)
	if objet_retire.is_empty():
		message.text = "Aucun objet à récupérer."
		return
	inventaire_actuel.ajouter_depuis_payload(_convertir_vers_payload_inventaire(objet_retire))
	message.text = "%s récupéré." % String(objet_retire.get("nom", objet_retire.get("identifiant", "")))

func _transferer_inventaire_vers_coffre(objet: Dictionary, quantite: int, index_destination: int = -1) -> void:
	if coffre_actuel == null or inventaire_actuel == null or objet.is_empty():
		return
	var gestionnaire: GestionnaireCoffre = coffre_actuel.gestionnaire_coffre
	var quantite_demandee: int = int(objet.get("quantite", 0)) if quantite < 0 else mini(quantite, int(objet.get("quantite", 0)))
	var capacite: int = gestionnaire.obtenir_capacite_totale(objet) if index_destination < 0 else gestionnaire.obtenir_capacite_emplacement(index_destination, objet)
	var quantite_a_deplacer: int = mini(quantite_demandee, capacite)
	if quantite_a_deplacer <= 0:
		message.text = "Aucune place compatible dans le coffre."
		return
	var objet_retire: Dictionary = _retirer_de_inventaire(objet, quantite_a_deplacer)
	if objet_retire.is_empty():
		message.text = "Impossible de retirer cet objet de l'inventaire."
		return
	var quantite_ajoutee: int = gestionnaire.ajouter_automatiquement(objet_retire, quantite_a_deplacer) if index_destination < 0 else gestionnaire.ajouter_dans_emplacement(index_destination, objet_retire, quantite_a_deplacer)
	if quantite_ajoutee < int(objet_retire.get("quantite", 0)):
		var reste: Dictionary = objet_retire.duplicate(true)
		reste["quantite"] = int(objet_retire.get("quantite", 0)) - quantite_ajoutee
		inventaire_actuel.ajouter_depuis_payload(_convertir_vers_payload_inventaire(reste))
	if quantite_ajoutee <= 0:
		message.text = "Le coffre a refusé cet objet."
	else:
		message.text = "%s déposé." % String(objet_retire.get("nom", objet_retire.get("identifiant", "")))

func _retirer_de_inventaire(objet: Dictionary, quantite: int) -> Dictionary:
	var copie: Dictionary = objet.duplicate(true)
	var donnees: Dictionary = objet.get("donnees", {})
	var identifiant_instance: StringName = donnees.get("identifiant_instance", &"")
	if String(identifiant_instance) != "":
		return inventaire_actuel.retirer_equipement_instance(identifiant_instance)
	var quantite_retiree: int = inventaire_actuel.retirer_objet(objet.get("identifiant", &""), quantite)
	if quantite_retiree <= 0:
		return {}
	copie["quantite"] = quantite_retiree
	return copie

func _convertir_vers_payload_inventaire(objet: Dictionary) -> Dictionary:
	return {
		"id": objet.get("identifiant", &""),
		"nom_affiche": String(objet.get("nom", objet.get("identifiant", ""))),
		"icone": objet.get("icone", null),
		"quantite": int(objet.get("quantite", 1)),
		"type_item": int(objet.get("type_item", -1)),
		"type_loot": int(objet.get("type_loot", -1)),
		"scene": objet.get("scene", null),
		"donnees": Dictionary(objet.get("donnees", {})).duplicate(true)
	}

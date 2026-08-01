extends VBoxContainer
class_name VueDetailsObjet

signal manger_demande(objet: Dictionary)
signal equiper_demande(objet: Dictionary)

@onready var nom_objet: Label = $NomObjet
@onready var icone_objet: TextureRect = $IconeObjet
@onready var type_objet: Label = $TypeObjet
@onready var informations: RichTextLabel = $Informations
@onready var bouton_equiper: Button = $Actions/Equiper
@onready var bouton_manger: Button = $Actions/Manger

var objet: Dictionary = {}

func _ready() -> void:
	bouton_equiper.pressed.connect(_demander_equipement)
	bouton_manger.pressed.connect(_demander_consommation)
	afficher_objet({})

func afficher_objet(nouvel_objet: Dictionary) -> void:
	objet = nouvel_objet.duplicate(true)
	if not is_node_ready():
		return
	if objet.is_empty():
		nom_objet.text = "Sélectionnez un objet"
		icone_objet.texture = null
		type_objet.text = ""
		informations.text = "Cliquez sur une cellule pour consulter ses détails."
		bouton_equiper.visible = false
		bouton_manger.visible = false
		return
	nom_objet.text = String(objet.get("nom", objet.get("identifiant", "Objet"))).to_upper()
	icone_objet.texture = objet.get("icone", null) as Texture2D
	var type_item: int = int(objet.get("type_item", -1))
	type_objet.text = _nom_type(type_item)
	informations.text = _construire_informations(type_item)
	var definition: LootItemEntry = _obtenir_definition()
	bouton_equiper.visible = definition != null and definition.donnees_equipement != null
	bouton_manger.visible = type_item == Loot.TypeItem.CONSO and definition != null and definition.effet_nourriture != null

func _construire_informations(type_item: int) -> String:
	var lignes: PackedStringArray = PackedStringArray(["Quantité : %d" % int(objet.get("quantite", 1))])
	var donnees: Dictionary = objet.get("donnees", {})
	if type_item == Loot.TypeItem.EQUIPEMENT:
		lignes.append("Qualité : %s" % String(donnees.get("qualite", "correcte")).capitalize())
		var composants: Dictionary = donnees.get("composants_installes", {})
		if not composants.is_empty():
			lignes.append("\nComposants :")
			for identifiant: Variant in composants:
				if String(identifiant) != GestionnaireAmeliorationsEquipement.CLE_AMELIORATIONS:
					lignes.append("• %s x%d" % [String(identifiant).capitalize(), int(composants[identifiant])])
	var definition: LootItemEntry = _obtenir_definition()
	if definition != null:
		lignes.append("Poids : %.1f" % definition.poids)
		if definition.effet_nourriture != null:
			var effet: EffetNourriture = definition.effet_nourriture
			lignes.append("Soin : +%d" % effet.soin)
			lignes.append("Soif : +%.0f" % effet.restauration_soif)
			if effet.duree > 0.0:
				lignes.append("Durée : %.0f s" % effet.duree)
	return "\n".join(lignes)

func _obtenir_definition() -> LootItemEntry:
	var donnees: Dictionary = objet.get("donnees", {})
	var chemin: String = String(donnees.get("chemin_definition", ""))
	return load(chemin) as LootItemEntry if not chemin.is_empty() else null

func _nom_type(type_item: int) -> String:
	match type_item:
		Loot.TypeItem.CONSO:
			return "Consommable"
		Loot.TypeItem.UPGRADE:
			return "Amélioration"
		Loot.TypeItem.ARME:
			return "Arme"
		Loot.TypeItem.MATERIAU:
			return "Matériau"
		Loot.TypeItem.COMPOSANT:
			return "Composant"
		Loot.TypeItem.EQUIPEMENT:
			return "Équipement"
	return "Objet"

func _demander_equipement() -> void:
	equiper_demande.emit(objet)

func _demander_consommation() -> void:
	manger_demande.emit(objet)

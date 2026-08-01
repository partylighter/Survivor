extends Resource
class_name LootItemEntry

@export var item_id: StringName = &""
@export var poids: float = 1.0

@export_group("Inventaire")
@export_enum("CONSO", "UPGRADE", "ARME", "MATERIAU", "COMPOSANT", "EQUIPEMENT") var type_item: int = Loot.TypeItem.MATERIAU

@export_group("Visuel")
@export var nom_affiche: String = ""
@export var icone: Texture2D
@export var couleur: Color = Color.WHITE
@export_range(0.1, 8.0, 0.05) var echelle: float = 1.0
@export var skin_id: StringName = &""

@export_group("Affichage collecte")
@export var afficher_sprite_loot: bool = true
@export var afficher_notification_collecte: bool = false

@export_group("Forge")
@export var profil_qualite_forge: ProfilQualiteForge
@export var scene_arme_equipee: PackedScene
@export var ameliorations_compatibles: PackedStringArray = PackedStringArray()
@export var ameliorations_forge: Array[AmeliorationForge] = []

@export_group("Cuisine")
@export var effet_nourriture: EffetNourriture

func obtenir_amelioration_forge(identifiant_amelioration: StringName) -> AmeliorationForge:
	for amelioration: AmeliorationForge in ameliorations_forge:
		if amelioration != null and amelioration.identifiant == identifiant_amelioration:
			return amelioration
	return null

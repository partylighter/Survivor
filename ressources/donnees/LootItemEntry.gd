extends Resource
class_name LootItemEntry

@export var item_id: StringName = &""
@export var poids: float = 1.0

@export_group("Visuel")
@export var nom_affiche: String = ""
@export var icone: Texture2D
@export var couleur: Color = Color.WHITE
@export_range(0.1, 8.0, 0.05) var echelle: float = 1.0
@export var skin_id: StringName = &""

@export_group("Affichage collecte")
@export var afficher_sprite_loot: bool = true
@export var afficher_notification_collecte: bool = false

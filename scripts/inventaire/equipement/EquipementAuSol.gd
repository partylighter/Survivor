extends Node2D
class_name EquipementAuSol

@export var definition: LootItemEntry
@export_enum("C", "B", "A", "S") var type_loot: int = Loot.TypeLoot.C

var donnees_instance: Dictionary = {}
var _collecte_en_cours: bool = false
var _ramassage_verrouille: bool = false
var _duree_verrouillage_restante: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var pickup: Area2D = $Pickup
@onready var etiquette: Label = $Label

func _ready() -> void:
	if not pickup.area_entered.is_connected(_quand_zone_entree):
		pickup.area_entered.connect(_quand_zone_entree)
	_appliquer_visuel()

func configurer_nouvel_equipement(definition_objet: LootItemEntry, nouveau_type_loot: int = Loot.TypeLoot.C) -> void:
	definition = definition_objet
	donnees_instance.clear()
	type_loot = nouveau_type_loot
	_appliquer_visuel()

func configurer_depuis_instance(definition_objet: LootItemEntry, donnees: Dictionary, nouveau_type_loot: int = Loot.TypeLoot.C) -> void:
	definition = definition_objet
	donnees_instance = donnees.duplicate(true)
	type_loot = nouveau_type_loot
	_appliquer_visuel()

func verrouiller_ramassage(duree_secondes: float) -> void:
	_ramassage_verrouille = true
	_duree_verrouillage_restante = maxf(duree_secondes, 0.0)
	if is_inside_tree():
		_demarrer_deverrouillage()
	elif not tree_entered.is_connected(_demarrer_deverrouillage):
		tree_entered.connect(_demarrer_deverrouillage, CONNECT_ONE_SHOT)

func _demarrer_deverrouillage() -> void:
	if _duree_verrouillage_restante <= 0.0:
		_deverrouiller_ramassage()
		return
	get_tree().create_timer(_duree_verrouillage_restante).timeout.connect(_deverrouiller_ramassage)

func _deverrouiller_ramassage() -> void:
	_ramassage_verrouille = false
	_duree_verrouillage_restante = 0.0
	for zone_entree: Area2D in pickup.get_overlapping_areas():
		if zone_entree is ZoneRamassage:
			_quand_zone_entree(zone_entree)
			break

func obtenir_payload_ramassage() -> Dictionary:
	if definition == null or definition.type_item != Loot.TypeItem.EQUIPEMENT or definition.donnees_equipement == null:
		return {}
	if definition.resource_path.is_empty():
		return {}
	var identifiant_instance: StringName = donnees_instance.get("identifiant_instance", &"")
	if String(identifiant_instance).is_empty():
		donnees_instance = DonneesInstanceEquipement.creer(definition.item_id, definition.resource_path, &"correcte", {})
	elif not DonneesInstanceEquipement.est_valide_pour(donnees_instance, definition):
		return {}
	return {
		"id": definition.item_id,
		"item_id": definition.item_id,
		"identifiant": definition.item_id,
		"nom_affiche": definition.nom_affiche,
		"icone": definition.icone,
		"quantite": 1,
		"type_item": Loot.TypeItem.EQUIPEMENT,
		"type_loot": type_loot,
		"chemin_definition": definition.resource_path,
		"donnees": donnees_instance.duplicate(true)
	}

func est_ramassable() -> bool:
	return not _collecte_en_cours and not _ramassage_verrouille and definition != null and definition.type_item == Loot.TypeItem.EQUIPEMENT

func collecter_par(joueur: Node) -> bool:
	if not est_ramassable() or joueur == null or not joueur.has_method("on_loot_collected"):
		return false
	var payload: Dictionary = obtenir_payload_ramassage()
	if payload.is_empty():
		return false
	_collecte_en_cours = true
	var reussi: bool = bool(joueur.call("on_loot_collected", payload))
	if reussi:
		queue_free()
	else:
		_collecte_en_cours = false
	return reussi

func _quand_zone_entree(zone_entree: Area2D) -> void:
	if not zone_entree is ZoneRamassage:
		return
	var joueur: Node = zone_entree.get_parent()
	call_deferred("collecter_par", joueur)

func _appliquer_visuel() -> void:
	if not is_node_ready():
		return
	sprite.texture = definition.icone if definition != null else null
	etiquette.text = definition.nom_affiche if definition != null else "Equipement"

extends Node
class_name GestionnaireLoot

@export var debug_loot: bool = false

var joueur: Player
var stats_loot: Dictionary = {}

func _ready() -> void:
	joueur = get_parent() as Player


func _d_loot(msg: String) -> void:
	if debug_loot:
		print(msg)


func _enregistrer_loot(identifiant: StringName, quantite: int) -> void:
	if String(identifiant) == "":
		return
	var actuel: int = stats_loot.get(identifiant, 0)
	stats_loot[identifiant] = actuel + quantite


func get_stats_loot() -> Dictionary:
	return stats_loot.duplicate()


func on_loot_collecte(payload: Dictionary) -> void:
	if joueur == null:
		return

	var type_item: int = payload.get("type_item", Loot.TypeItem.CONSO)
	var rarete: int = payload.get("type_loot", Loot.TypeLoot.C)
	var identifiant: StringName = payload.get("id", &"")
	var quantite: int = payload.get("quantite", 1)
	var scene_contenu: PackedScene = payload.get("scene", null)

	_enregistrer_loot(identifiant, quantite)

	match type_item:
		Loot.TypeItem.CONSO:
			_appliquer_consommable(identifiant, quantite)
		Loot.TypeItem.UPGRADE:
			_appliquer_amelioration(identifiant, quantite)
		Loot.TypeItem.ARME:
			if scene_contenu != null:
				_generer_arme_au_sol(scene_contenu)
			else:
				_debloquer_arme_par_id(identifiant, rarete, quantite)


func _generer_arme_au_sol(scene_src: PackedScene) -> void:
	var arme := scene_src.instantiate() as ArmeBase
	if arme == null:
		return
	arme.global_position = joueur.global_position + Vector2(24, 0)
	get_tree().current_scene.add_child(arme)


func _appliquer_consommable(identifiant: StringName, quantite: int) -> void:
	match String(identifiant):
		"heal_petit":
			if joueur.has_method("soigner"):
				joueur.soigner(10 * quantite)
		"heal_gros":
			if joueur.has_method("soigner"):
				joueur.soigner(40 * quantite)
		_:
			_d_loot("[Loot] consommable inconnu : %s x%d" % [str(identifiant), quantite])


func _appliquer_amelioration(identifiant: StringName, quantite: int) -> void:
	_d_loot("[Loot] amélioration : %s x%d" % [str(identifiant), quantite])


func _debloquer_arme_par_id(identifiant: StringName, rarete: int, quantite: int) -> void:
	_d_loot("[Loot] arme logique : %s rarete : %d x%d" % [str(identifiant), rarete, quantite])

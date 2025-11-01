extends Area2D
class_name Loot

enum TypeLoot { C, B, A, S }

@export_enum("C","B","A","S") var type_loot: int = TypeLoot.C
@export var scene_contenu: PackedScene
@export var quantite: int = 1

func a_un_contenu() -> bool:
	return scene_contenu != null

func est_vide() -> bool:
	return not a_un_contenu()

func prendre_scene() -> PackedScene:
	var s: PackedScene = scene_contenu
	scene_contenu = null
	return s

func prendre_payload() -> Dictionary:
	var d := {
		"type": type_loot,
		"scene": scene_contenu,
		"quantite": quantite
	}
	vider()
	return d

func vider() -> void:
	scene_contenu = null
	quantite = 0
	type_loot = TypeLoot.C

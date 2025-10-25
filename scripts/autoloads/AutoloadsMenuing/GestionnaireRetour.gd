# res://Scripts/GestionnaireRetour.gd
extends Node

signal historique_modifie
@export var debug_enabled: bool = false

var histo: Array[String] = []

func _d(msg: String) -> void:
	if debug_enabled:
		print("[RetourMgr]", Time.get_ticks_msec(), msg)

func aller_a_scene(packed: PackedScene) -> void:
	var cs := get_tree().current_scene
	if cs:
		var p: String = cs.scene_file_path
		_d("aller_a_scene current=" + str(p))
		if p != "" and (histo.is_empty() or histo.back() != p):
			histo.append(p)
			_d("aller_a_scene push -> size=" + str(histo.size()))
			historique_modifie.emit()
	get_tree().paused = false
	var target := ""
	if packed:
		target = packed.resource_path
	_d("aller_a_scene change_scene_to_packed target=" + str(target))
	get_tree().change_scene_to_packed(packed)

func aller_a_fichier(path: String) -> void:
	var cs := get_tree().current_scene
	if cs:
		var p: String = cs.scene_file_path
		_d("aller_a_fichier current=" + str(p))
		if p != "" and (histo.is_empty() or histo.back() != p):
			histo.append(p)
			_d("aller_a_fichier push -> size=" + str(histo.size()))
			historique_modifie.emit()
	get_tree().paused = false
	_d("aller_a_fichier change_scene_to_file path=" + path)
	get_tree().change_scene_to_file(path)

func retour() -> void:
	if histo.is_empty():
		_d("retour historique vide")
		push_warning("Historique vide.")
		return
	var chemin_prec: String = histo.pop_back()
	_d("retour pop=" + chemin_prec + " size=" + str(histo.size()))
	historique_modifie.emit()
	_d("retour change_scene_to_file path=" + chemin_prec)
	get_tree().change_scene_to_file(chemin_prec)
	get_tree().paused = false
	_d("retour paused=false")

func purge() -> void:
	if histo.is_empty():
		_d("purge noop (déjà vide)")
		return
	_d("purge clear size_before=" + str(histo.size()))
	histo.clear()
	historique_modifie.emit()

func retour_possible() -> bool:
	var possible := not histo.is_empty()
	_d("retour_possible=" + str(possible) + " size=" + str(histo.size()))
	return possible

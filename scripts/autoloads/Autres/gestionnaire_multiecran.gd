extends Node

@export_group("Affichage multi-écran")
@export var activer_multi_ecran: bool = true
@export_range(0, 7, 1) var ecran_cible: int = 0
@export var plein_ecran: bool = true
@export var debug_multi_ecran: bool = false

func _ready() -> void:
	if not activer_multi_ecran:
		return
	call_deferred("_appliquer_multi_ecran")


func _appliquer_multi_ecran() -> void:
	var fenetre: Window = get_window()
	var nb: int = DisplayServer.get_screen_count()
	if nb <= 1:
		return

	var cible: int = clampi(ecran_cible, 0, nb - 1)

	fenetre.mode = Window.MODE_WINDOWED
	await get_tree().process_frame

	fenetre.current_screen = cible
	await get_tree().process_frame

	fenetre.move_to_center()
	await get_tree().process_frame

	if plein_ecran:
		if OS.has_feature("editor"):
			fenetre.mode = Window.MODE_FULLSCREEN
		else:
			fenetre.mode = Window.MODE_EXCLUSIVE_FULLSCREEN

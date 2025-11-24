extends Node

@export_group("Affichage multi-écran")
@export var activer_multi_ecran: bool = false
@export_range(0, 7, 1) var ecran_cible: int = 1
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
		if debug_multi_ecran:
			print("[MultiÉcran] Un seul écran détecté, annulation.")
		return

	if ecran_cible < 0 or ecran_cible >= nb:
		if debug_multi_ecran:
			print("[MultiÉcran] Index cible", ecran_cible, "hors limites [0..", nb - 1, "].")
		return

	if debug_multi_ecran:
		print("\n[MultiÉcran] Nombre d'écrans :", nb)
		print("[MultiÉcran] Fenêtre AVANT → écran", fenetre.current_screen, "| mode", fenetre.mode)

	
	fenetre.mode = Window.MODE_WINDOWED
	fenetre.current_screen = ecran_cible
	fenetre.move_to_center()

	
	if plein_ecran:
		fenetre.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		

	if debug_multi_ecran:
		print("[MultiÉcran] Fenêtre APRÈS → écran", fenetre.current_screen, "| mode", fenetre.mode)

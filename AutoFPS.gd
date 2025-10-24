extends Node

@export var fps_cible: int = 60
@export var vsync_mode: int = 1 # 0 = Off, 1 = On, 2 = Adaptive

func _ready():
	charger_parametres()
	_appliquer_framerate(fps_cible, vsync_mode)

func _appliquer_framerate(fps: int, vsync: int) -> void:
	fps_cible = fps
	vsync_mode = vsync

	Engine.max_fps = fps
	ProjectSettings.set_setting("time/physics_ticks_per_second", fps)
	ProjectSettings.set_setting("debug/settings/fixed_fps", fps)
	ProjectSettings.set_setting("debug/settings/force_fps", true)
	ProjectSettings.set_setting("display/window/fps_max", fps)
	ProjectSettings.set_setting("display/window/vsync/vsync_mode", vsync)

	print("FPS : %s | VSync mode : %s" % [fps, vsync])

func sauvegarder_parametres() -> void:
	var config := ConfigFile.new()
	config.set_value("affichage", "fps", fps_cible)
	config.set_value("affichage", "vsync", vsync_mode)
	config.save("user://settings.cfg")

func charger_parametres() -> void:
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		fps_cible = config.get_value("affichage", "fps", fps_cible)
		vsync_mode = config.get_value("affichage", "vsync", vsync_mode)

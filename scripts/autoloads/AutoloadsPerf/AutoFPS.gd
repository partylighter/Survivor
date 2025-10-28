extends Node

@export var fps_cible: int = 60
@export var vsync_mode: int = 1        # 0 = Off, 1 = On, 2 = Adaptatif
@export var ticks_physique_cible: int = 120   # ticks physique par seconde

func _ready() -> void:
	charger_parametres()
	_appliquer_framerate(fps_cible, vsync_mode)
	_appliquer_ticks_physique(ticks_physique_cible)

func _appliquer_framerate(fps: int, vsync: int) -> void:
	fps_cible = fps
	vsync_mode = vsync

	Engine.max_fps = fps
	ProjectSettings.set_setting("display/window/fps_max", fps)

	ProjectSettings.set_setting("display/window/vsync/vsync_mode", vsync)
	DisplayServer.window_set_vsync_mode(vsync)

	print("FPS : %s | VSync : %s" % [fps, vsync])

func _appliquer_ticks_physique(ticks: int) -> void:
	ticks_physique_cible = ticks

	Engine.physics_ticks_per_second = ticks
	ProjectSettings.set_setting("time/physics_ticks_per_second", ticks)

	print("Ticks physique : %s TPS" % [ticks])

func sauvegarder_parametres() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("affichage", "fps", fps_cible)
	cfg.set_value("affichage", "vsync", vsync_mode)
	cfg.set_value("affichage", "ticks_physique", ticks_physique_cible)
	cfg.save("user://settings.cfg")

func charger_parametres() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		fps_cible = cfg.get_value("affichage", "fps", fps_cible)
		vsync_mode = cfg.get_value("affichage", "vsync", vsync_mode)
		ticks_physique_cible = cfg.get_value("affichage", "ticks_physique", ticks_physique_cible)

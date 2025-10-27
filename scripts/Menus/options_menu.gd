extends CanvasLayer
class_name MenuOptions

@export var fps_possibles: Array[int] = [30, 60, 120, 144, 240]
@export var ticks_physique_possibles: Array[int] = [30, 60, 120]

@onready var bouton_fps: Button = %btn_FPS
@onready var bouton_vsync: Button = %btn_VSync
@onready var bouton_ticks: Button = %btn_Thicks
@onready var bouton_appliquer: Button = %btn_appliquer

var index_fps: int = 0
var index_vsync: int = 0
var index_ticks: int = 0

var index_fps_initial: int = 0
var index_vsync_initial: int = 0
var index_ticks_initial: int = 0

func _ready() -> void:
	_initialiser_depuis_parametres()
	_mettre_a_jour_affichage()
	_mettre_visibilite_bouton_appliquer()

	bouton_fps.pressed.connect(_quand_bouton_fps)
	bouton_vsync.pressed.connect(_quand_bouton_vsync)
	bouton_ticks.pressed.connect(_quand_bouton_ticks)
	bouton_appliquer.pressed.connect(_quand_bouton_appliquer)

func _initialiser_depuis_parametres() -> void:
	index_fps = fps_possibles.find(AutoFps.fps_cible)
	if index_fps == -1:
		index_fps = 0

	index_vsync = clamp(AutoFps.vsync_mode, 0, 2)

	index_ticks = ticks_physique_possibles.find(AutoFps.ticks_physique_cible)
	if index_ticks == -1:
		index_ticks = 0

	index_fps_initial = index_fps
	index_vsync_initial = index_vsync
	index_ticks_initial = index_ticks

func _quand_bouton_fps() -> void:
	index_fps = (index_fps + 1) % fps_possibles.size()
	_mettre_a_jour_affichage()
	_mettre_visibilite_bouton_appliquer()

func _quand_bouton_vsync() -> void:
	index_vsync = (index_vsync + 1) % 3
	_mettre_a_jour_affichage()
	_mettre_visibilite_bouton_appliquer()

func _quand_bouton_ticks() -> void:
	index_ticks = (index_ticks + 1) % ticks_physique_possibles.size()
	_mettre_a_jour_affichage()
	_mettre_visibilite_bouton_appliquer()

func _quand_bouton_appliquer() -> void:
	_appliquer_changements()

	index_fps_initial = index_fps
	index_vsync_initial = index_vsync
	index_ticks_initial = index_ticks

	_mettre_visibilite_bouton_appliquer()

func _appliquer_changements() -> void:
	var nouveau_fps: int = fps_possibles[index_fps]
	var nouveau_vsync: int = index_vsync
	var nouveau_ticks: int = ticks_physique_possibles[index_ticks]

	AutoFps._appliquer_framerate(nouveau_fps, nouveau_vsync)
	AutoFps._appliquer_ticks_physique(nouveau_ticks)
	AutoFps.sauvegarder_parametres()

func _mettre_visibilite_bouton_appliquer() -> void:
	var modif_fps: bool = (index_fps != index_fps_initial)
	var modif_vsync: bool = (index_vsync != index_vsync_initial)
	var modif_ticks: bool = (index_ticks != index_ticks_initial)

	var il_y_a_modif: bool = modif_fps or modif_vsync or modif_ticks

	bouton_appliquer.visible = il_y_a_modif
	bouton_appliquer.disabled = not il_y_a_modif

func _mettre_a_jour_affichage() -> void:
	bouton_fps.text = "FPS : %d" % fps_possibles[index_fps]
	bouton_vsync.text = _texte_vsync(index_vsync)
	bouton_ticks.text = "Physique : %d TPS" % ticks_physique_possibles[index_ticks]

func _texte_vsync(mode: int) -> String:
	match mode:
		0:
			return "VSync : Désactivé"
		1:
			return "VSync : Activé"
		2:
			return "VSync : Adaptatif"
		_:
			return "VSync : " + str(mode)

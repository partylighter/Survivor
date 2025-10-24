extends CanvasLayer
class_name PauseMenu

signal request_restart
signal request_quit

@export var gestionnaire: PauseManagerClass
@export var layer_index: int = 1000
@export var debug_enabled: bool = false

@onready var btn_reprendre: Button  = %BtnResume
@onready var btn_parametres: Button = %BtnSettings
@onready var btn_redemarrer: Button = %BtnRestart
@onready var btn_quitter: Button    = %BtnQuit

func _d(m:String)->void:
	if debug_enabled: print("[PauseMenu]", Time.get_ticks_msec(), m)

func _enter_tree() -> void:
	add_to_group("g_pause_menu")
	_d("ENTER_TREE path=" + str(get_path()))

func _ready() -> void:
	self.layer = layer_index
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	hide()
	_d("READY layer=" + str(self.layer) + " refs=" + str(is_instance_valid(btn_reprendre)))
	if is_instance_valid(btn_reprendre) and not btn_reprendre.pressed.is_connected(_on_reprendre):
		btn_reprendre.pressed.connect(_on_reprendre)
	if is_instance_valid(btn_parametres) and not btn_parametres.pressed.is_connected(_on_parametres):
		btn_parametres.pressed.connect(_on_parametres)
	if is_instance_valid(btn_redemarrer) and not btn_redemarrer.pressed.is_connected(_on_redemarrer):
		btn_redemarrer.pressed.connect(_on_redemarrer)
	if is_instance_valid(btn_quitter) and not btn_quitter.pressed.is_connected(_on_quitter):
		btn_quitter.pressed.connect(_on_quitter)
	_d("READY connections set")

func ouvrir() -> void:
	self.layer = layer_index
	_d("OUVRIR layer=" + str(self.layer))
	_d("OUVRIR before show visible=" + str(is_visible()))
	show()
	await get_tree().process_frame
	_d("OUVRIR after show visible=" + str(is_visible()) + " btn_ok=" + str(is_instance_valid(btn_reprendre)))
	if is_instance_valid(btn_reprendre):
		btn_reprendre.show()
		btn_reprendre.grab_focus()
		_d("OUVRIR focus ok")
	else:
		_d("OUVRIR focus skipped")

func fermer() -> void:
	_d("FERMER before hide visible=" + str(is_visible()))
	hide()
	_d("FERMER after hide visible=" + str(is_visible()))

func _on_reprendre() -> void:
	_d("SIGNAL reprendre"); if gestionnaire: gestionnaire.reprendre()

func _on_parametres() -> void:
	_d("SIGNAL options")
	var s := preload("res://scenes/Menus/options_menu.tscn").instantiate()
	add_child(s)
	if "open" in s: s.call("open")

func _on_redemarrer() -> void:
	_d("SIGNAL restart"); request_restart.emit()

func _on_quitter() -> void:
	_d("SIGNAL quit"); request_quit.emit()

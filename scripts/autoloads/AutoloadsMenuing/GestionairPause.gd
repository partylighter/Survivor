extends Node
class_name PauseManagerClass

@export var pause_scene: PackedScene = preload("res://scenes/Menus/pause_menu.tscn")
@export var debug_enabled: bool = false

var menu: PauseMenu
var _anti_rebond_ms := 200
var _dernier_basculement_ms := 0

func _d(m:String)->void:
	if debug_enabled:
		print("[PauseMgr]", Time.get_ticks_msec(), m)

func _ready() -> void:
	_d("READY paused=" + str(get_tree().paused))
	_instancier_menu()
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_input(true)
	_d("READY done menu=" + str(menu) + " inside=" + str(menu and menu.is_inside_tree()))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		var echo: bool = (event is InputEventKey) and (event as InputEventKey).echo
		_d("INPUT pause echo=" + str(echo) + " paused=" + str(get_tree().paused))
		var t := Time.get_ticks_msec()
		if t - _dernier_basculement_ms < _anti_rebond_ms:
			_d("INPUT debounced")
			return
		_dernier_basculement_ms = t
		if get_tree().paused:
			reprendre()
		else:
			mettre_en_pause()
		get_viewport().set_input_as_handled()

func _instancier_menu() -> void:
	_d("INSTANCIER check existing")
	var menus := get_tree().get_nodes_in_group("g_pause_menu")
	if menus.size() > 0:
		menu = menus[0] as PauseMenu
		_d("INSTANCIER reuse " + str(menu.get_path()))
		if not menu.is_inside_tree():
			get_tree().root.add_child(menu)
		_dedupe_menus()
		_connect_menu_signals()
		return

	if pause_scene == null:
		_d("ERR no pause_scene")
		push_error("Aucune scène de pause assignée.")
		return

	_d("INSTANCIER create")
	menu = pause_scene.instantiate() as PauseMenu
	menu.gestionnaire = self
	menu.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	menu.hide()
	_connect_menu_signals()
	get_tree().root.add_child(menu)

func _connect_menu_signals() -> void:
	if menu == null or not is_instance_valid(menu):
		return
	if not menu.request_restart.is_connected(_on_menu_request_restart):
		menu.request_restart.connect(_on_menu_request_restart)
	if not menu.request_quit.is_connected(_on_menu_request_quit):
		menu.request_quit.connect(_on_menu_request_quit)

func _dedupe_menus() -> void:
	var menus := get_tree().get_nodes_in_group("g_pause_menu")
	if menus.size() <= 1:
		return
	_d("DEDUPE found " + str(menus.size()))
	if menu == null or not is_instance_valid(menu):
		menu = menus[0] as PauseMenu
	for m in menus:
		if m != menu and is_instance_valid(m):
			_d("DEDUPE free " + str((m as Node).get_path()))
			(m as Node).queue_free()

func _assurer_menu() -> bool:
	if menu == null or not is_instance_valid(menu):
		_d("ASSURER create")
		_instancier_menu()

	if menu and not menu.is_inside_tree():
		_d("ASSURER add to root")
		get_tree().root.add_child(menu)

	_dedupe_menus()
	_connect_menu_signals()

	return menu != null and is_instance_valid(menu) and menu.is_inside_tree()

func mettre_en_pause() -> void:
	if get_tree().paused:
		_d("PAUSE already paused")
		return

	if not _assurer_menu():
		_d("PAUSE no menu")
		return

	_d("PAUSE ouvrir()")
	menu.ouvrir()
	await get_tree().process_frame
	get_tree().paused = true
	_d("PAUSE set paused=" + str(get_tree().paused))

func reprendre() -> void:
	if not get_tree().paused:
		_d("RESUME already running")
		return

	_d("RESUME clear paused")
	get_tree().paused = false

	if menu and is_instance_valid(menu):
		menu.fermer()

	_dernier_basculement_ms = Time.get_ticks_msec()
	_d("RESUME done paused=" + str(get_tree().paused))

func _on_menu_request_restart() -> void:
	_d("RESTART requested")
	get_tree().paused = false

	if menu and is_instance_valid(menu):
		menu.fermer()

	var err := get_tree().reload_current_scene()
	if err != OK:
		var curr := get_tree().current_scene
		if curr and curr.scene_file_path != "":
			get_tree().change_scene_to_file(curr.scene_file_path)
		else:
			_d("RESTART fallback failed")

func _on_menu_request_quit() -> void:
	_d("QUIT requested")
	get_tree().paused = false

	if menu and is_instance_valid(menu):
		menu.fermer()

	get_tree().quit()

func _exit_tree() -> void:
	_d("EXIT_TREE clean pause")
	get_tree().paused = false

	if menu and is_instance_valid(menu):
		menu.fermer()
		menu.queue_free()
		menu = null

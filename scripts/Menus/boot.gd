extends Node

@export_file("*.tscn") var next_scene_path: String = "res://scenes/Menus/menu_titre.tscn"

@export var timer_actif: bool = true
@export var duree_s: float = 5.0

@export var bouton_demarrer: TextureButton

var _busy: bool = false
var _next_packed: PackedScene = null

func _ready() -> void:
	if next_scene_path.is_empty():
		push_error("Boot: next_scene_path vide")
		return

	_next_packed = load(next_scene_path) as PackedScene
	if _next_packed == null:
		push_error("Boot: impossible de charger la scène: " + next_scene_path)
		return

	if bouton_demarrer != null and not bouton_demarrer.pressed.is_connected(_go):
		bouton_demarrer.pressed.connect(_go, Object.CONNECT_DEFERRED)

	if timer_actif:
		await get_tree().create_timer(max(duree_s, 0.0)).timeout
		_go()

func _go() -> void:
	if _busy:
		return
	_busy = true
	get_tree().change_scene_to_packed(_next_packed)

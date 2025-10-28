extends Node

@export var debug_enabled: bool = true

var chemin_fichier: String = "user://input.cfg"

const ACTIONS_JEU := [
	"droite",
	"gauche",
	"haut",
	"bas",
	"attaque",
	"pause",
	"attaque_main_gauche",
	"attaque_main_droite",
	"ramasser",
	"lacher_main_gauche",
	"lacher_main_droite",
	"jeter_main_gauche",
	"jeter_main_droite"
]

func _ready() -> void:
	charger()
	_debug_afficher_binds()

func definir_touche(nom_action: StringName, nouvelle_entree: InputEvent) -> void:
	InputMap.action_erase_events(nom_action)
	InputMap.action_add_event(nom_action, nouvelle_entree)

func effacer_touche(nom_action: StringName) -> void:
	InputMap.action_erase_events(nom_action)

func get_texte_touche(nom_action: StringName) -> String:
	var evenements: Array[InputEvent] = InputMap.action_get_events(nom_action)
	if evenements.size() > 0:
		return evenements[0].as_text()
	return "Non assignée"

func sauvegarder() -> void:
	var cfg: ConfigFile = ConfigFile.new()

	for nom_action: StringName in InputMap.get_actions():
		var evenements: Array[InputEvent] = InputMap.action_get_events(nom_action)

		if evenements.size() == 0:
			cfg.set_value("bind", nom_action, {"type": "none"})
			continue

		var e: InputEvent = evenements[0]

		if e is InputEventKey:
			cfg.set_value("bind", nom_action, {
				"type": "key",
				"phys": (e as InputEventKey).physical_keycode
			})
		elif e is InputEventMouseButton:
			cfg.set_value("bind", nom_action, {
				"type": "mouse",
				"btn": (e as InputEventMouseButton).button_index
			})
		elif e is InputEventJoypadButton:
			cfg.set_value("bind", nom_action, {
				"type": "joy",
				"btn": (e as InputEventJoypadButton).button_index
			})

	cfg.save(chemin_fichier)

func charger() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(chemin_fichier) != OK:
		return

	for nom_action: StringName in InputMap.get_actions():
		var infos: Variant = cfg.get_value("bind", nom_action, {"type": "none"})
		if infos == null:
			continue

		InputMap.action_erase_events(nom_action)

		var dict_infos: Dictionary = infos as Dictionary
		var type_entree: String = str(dict_infos.get("type", ""))

		if type_entree == "key":
			var k: InputEventKey = InputEventKey.new()
			var phys_code: int = int(dict_infos.get("phys", 0))
			k.physical_keycode = phys_code as Key
			InputMap.action_add_event(nom_action, k)
		elif type_entree == "mouse":
			var m: InputEventMouseButton = InputEventMouseButton.new()
			var mouse_btn_code: int = int(dict_infos.get("btn", 1))
			m.button_index = mouse_btn_code as MouseButton
			InputMap.action_add_event(nom_action, m)
		elif type_entree == "joy":
			var j: InputEventJoypadButton = InputEventJoypadButton.new()
			var joy_btn_code: int = int(dict_infos.get("btn", 0))
			j.button_index = joy_btn_code as JoyButton
			InputMap.action_add_event(nom_action, j)
		elif type_entree == "none":
			pass

func _debug_afficher_binds() -> void:
	if not debug_enabled:
		return
	print("------ Binds actifs ------")
	for nom_action in ACTIONS_JEU:
		if not InputMap.has_action(nom_action):
			continue
		var txt := get_texte_touche(nom_action)
		print("- ", str(nom_action), " = ", txt)

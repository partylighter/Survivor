extends Node

@export var debug_enabled: bool = true

var chemin_fichier: String = "user://input.cfg"

const ACTIONS_JEU: Array[StringName] = [
	"droite",
	"gauche",
	"haut",
	"bas",
	"attaque",
	"pause",
	"attaque_main_droite",
	"attaque_main_gauche",
	"ramasser",
	"lacher_main_gauche",
	"lacher_main_droite",
	"jeter_main_gauche",
	"jeter_main_droite"
]

const DEFAULT_BINDS: Dictionary = {
	"droite":               {"type": "key",   "key": Key.KEY_D},
	"gauche":               {"type": "key",   "key": Key.KEY_Q},
	"haut":                 {"type": "key",   "key": Key.KEY_Z},
	"bas":                  {"type": "key",   "key": Key.KEY_S},

	"attaque":              {"type": "mouse", "btn": MouseButton.MOUSE_BUTTON_LEFT,  "dbl": false},
	"pause":                {"type": "key",   "key": Key.KEY_ESCAPE},

	"attaque_main_droite":  {"type": "mouse", "btn": MouseButton.MOUSE_BUTTON_RIGHT, "dbl": false},
	"attaque_main_gauche":  {"type": "mouse", "btn": MouseButton.MOUSE_BUTTON_LEFT,  "dbl": true},

	"ramasser":             {"type": "key",   "key": Key.KEY_E},

	"lacher_main_gauche":   {"type": "key",   "key": Key.KEY_F},
	"lacher_main_droite":   {"type": "key",   "key": Key.KEY_C},

	"jeter_main_gauche":    {"type": "key",   "key": Key.KEY_G},
	"jeter_main_droite":    {"type": "key",   "key": Key.KEY_V}
}


func _ready() -> void:
	# 1. s'assurer que toutes les actions existent
	_initialiser_actions()

	# 2. charger ce qu'il y a dans user://input.cfg si ça existe
	charger()

	# 3. si une action est vide après le chargement, on lui remet son bind par défaut
	_restaurer_actions_vides_depuis_defaut()

	# 4. debug
	_debug_afficher_binds()


# --- setup interne ----------------------------------------------------------

func _initialiser_actions() -> void:
	for action_name: StringName in ACTIONS_JEU:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)


func _restaurer_actions_vides_depuis_defaut() -> void:
	for action_name: StringName in ACTIONS_JEU:
		var evts: Array[InputEvent] = InputMap.action_get_events(action_name)
		if evts.is_empty() and DEFAULT_BINDS.has(action_name):
			var def: Dictionary = DEFAULT_BINDS[action_name]
			_appliquer_bind_dictionnaire(action_name, def)


func _appliquer_bind_dictionnaire(nom_action: StringName, data: Dictionary) -> void:
	if not InputMap.has_action(nom_action):
		InputMap.add_action(nom_action)

	InputMap.action_erase_events(nom_action)

	var t: String = String(data.get("type", "none"))

	match t:
		"key":
			var k: InputEventKey = InputEventKey.new()
			var key_code: int = int(data.get("key", 0))
			k.keycode = key_code as Key
			InputMap.action_add_event(nom_action, k)

		"mouse":
			var m: InputEventMouseButton = InputEventMouseButton.new()
			var btn_code: int = int(data.get("btn", 1))
			m.button_index = btn_code as MouseButton
			m.double_click = bool(data.get("dbl", false))
			InputMap.action_add_event(nom_action, m)

		"joy":
			var j: InputEventJoypadButton = InputEventJoypadButton.new()
			var joy_code: int = int(data.get("btn", 0))
			j.button_index = joy_code as JoyButton
			InputMap.action_add_event(nom_action, j)

		_:
			# "none" ou inconnu -> rien
			pass


# --- API appelée par le menu ------------------------------------------------

func definir_touche(nom_action: StringName, nouvelle_entree: InputEvent) -> void:
	# utilisé par MenuTouches pour binder une nouvelle touche
	if not InputMap.has_action(nom_action):
		InputMap.add_action(nom_action)

	InputMap.action_erase_events(nom_action)
	InputMap.action_add_event(nom_action, nouvelle_entree)


func effacer_touche(nom_action: StringName) -> void:
	# utilisé par MenuTouches bouton "Effacer"
	if InputMap.has_action(nom_action):
		InputMap.action_erase_events(nom_action)


func sauvegarder() -> void:
	# utilisé par MenuTouches bouton "Appliquer"
	var cfg: ConfigFile = ConfigFile.new()

	for nom_action: StringName in ACTIONS_JEU:
		if not InputMap.has_action(nom_action):
			continue

		var evts: Array[InputEvent] = InputMap.action_get_events(nom_action)

		if evts.is_empty():
			cfg.set_value("bind", nom_action, {"type": "none"})
			continue

		var e: InputEvent = evts[0]

		if e is InputEventKey:
			var ek: InputEventKey = e as InputEventKey
			cfg.set_value("bind", nom_action, {
				"type": "key",
				"key": ek.keycode
			})

		elif e is InputEventMouseButton:
			var em: InputEventMouseButton = e as InputEventMouseButton
			cfg.set_value("bind", nom_action, {
				"type": "mouse",
				"btn": em.button_index,
				"dbl": em.double_click
			})

		elif e is InputEventJoypadButton:
			var ej: InputEventJoypadButton = e as InputEventJoypadButton
			cfg.set_value("bind", nom_action, {
				"type": "joy",
				"btn": ej.button_index
			})

	cfg.save(chemin_fichier)


func charger() -> void:
	# lit user://input.cfg et applique ce qui est dedans
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(chemin_fichier) != OK:
		return

	for nom_action: StringName in ACTIONS_JEU:
		if not InputMap.has_action(nom_action):
			InputMap.add_action(nom_action)

		var infos: Variant = cfg.get_value("bind", nom_action, null)
		if infos == null:
			continue

		InputMap.action_erase_events(nom_action)

		var dict_infos: Dictionary = infos as Dictionary
		var type_entree: String = String(dict_infos.get("type", ""))

		match type_entree:
			"key":
				var k: InputEventKey = InputEventKey.new()

				# format nouveau "key"
				if dict_infos.has("key"):
					var code_key: int = int(dict_infos.get("key", 0))
					k.keycode = code_key as Key
					InputMap.action_add_event(nom_action, k)

				# fallback ancien format "phys"
				elif dict_infos.has("phys"):
					var code_phys: int = int(dict_infos.get("phys", 0))
					k.keycode = code_phys as Key
					InputMap.action_add_event(nom_action, k)

			"mouse":
				var m: InputEventMouseButton = InputEventMouseButton.new()
				var btn_code: int = int(dict_infos.get("btn", 1))
				m.button_index = btn_code as MouseButton
				m.double_click = bool(dict_infos.get("dbl", false))
				InputMap.action_add_event(nom_action, m)

			"joy":
				var j: InputEventJoypadButton = InputEventJoypadButton.new()
				var joy_code: int = int(dict_infos.get("btn", 0))
				j.button_index = joy_code as JoyButton
				InputMap.action_add_event(nom_action, j)

			"none":
				# utilisateur avait explicitement vidé cette action
				pass

			_:
				# inconnu -> on laisse vide
				pass


# --- debug ------------------------------------------------------------------

func _debug_afficher_binds() -> void:
	if not debug_enabled:
		return

	print("------ Binds actifs ------")
	for nom_action: StringName in ACTIONS_JEU:
		if not InputMap.has_action(nom_action):
			continue

		var evts: Array[InputEvent] = InputMap.action_get_events(nom_action)
		if evts.is_empty():
			print("- ", nom_action, " = (Unset)")
		else:
			print("- ", nom_action, " = ", evts[0].as_text())
func retablir_touches_defaut() -> void:
	for nom_action: StringName in ACTIONS_JEU:
		if DEFAULT_BINDS.has(nom_action):
			var def: Dictionary = DEFAULT_BINDS[nom_action]
			_appliquer_bind_dictionnaire(nom_action, def)

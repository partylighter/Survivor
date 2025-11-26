extends CanvasLayer
class_name MenuTouches

@export var actions_configurables: Array[Dictionary] = [
	{"action": "droite", "label": "Aller à droite"},
	{"action": "gauche", "label": "Aller à gauche"},
	{"action": "haut", "label": "Haut / Saut / Monter"},
	{"action": "bas", "label": "Bas / Descendre"},
	{"action": "dash", "label": "Dash / Esquive"},
	{"action": "attaque", "label": "Attaque"},
	{"action": "pause", "label": "Pause / Menu"},
	{"action": "attaque_main_droite", "label": "Attaque main droite"},
	{"action": "attaque_main_gauche", "label": "Attaque main gauche"},
	{"action": "ramasser", "label": "Ramasser"},
	{"action": "lacher_main_gauche", "label": "Lâcher main gauche"},
	{"action": "lacher_main_droite", "label": "Lâcher main droite"},
	{"action": "jeter_main_gauche", "label": "Jeter main gauche"},
	{"action": "jeter_main_droite", "label": "Jeter main droite"}
]

@onready var conteneur_liste: VBoxContainer = %ListeActions
@onready var bouton_appliquer: Button = %btn_appliquer
@onready var bouton_reinitialiser: Button = %btn_reinitialiser

var boutons_changer: Dictionary = {}
var en_attente_de_rebind: bool = false
var action_cible: StringName
var modif_en_attente: bool = false

var _mouse_filters_backup: Dictionary = {}

func _ready() -> void:
	creer_interface()

	bouton_appliquer.pressed.connect(_appliquer_modifs)
	bouton_reinitialiser.pressed.connect(_reinitialiser_touches)

	_set_modifie(false)
	set_process_unhandled_input(true)

func _get_action_text(nom_action: StringName) -> String:
	if not InputMap.has_action(nom_action):
		return "Non assignée"
	var evts: Array[InputEvent] = InputMap.action_get_events(nom_action)
	if evts.size() == 0:
		return "Non assignée"
	return evts[0].as_text()

func creer_interface() -> void:
	for enfant in conteneur_liste.get_children():
		conteneur_liste.remove_child(enfant)
		enfant.queue_free()

	boutons_changer.clear()

	for entree in actions_configurables:
		var nom_action: StringName = StringName(entree.get("action", ""))
		var texte_affiche: String = String(entree.get("label", nom_action))

		var ligne := HBoxContainer.new()

		var label_action := Label.new()
		label_action.text = texte_affiche
		label_action.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label_action.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var bouton_modifier := Button.new()
		bouton_modifier.text = _get_action_text(nom_action)
		bouton_modifier.focus_mode = Control.FOCUS_NONE
		bouton_modifier.pressed.connect(_demarrer_rebind.bind(nom_action))

		var bouton_effacer := Button.new()
		bouton_effacer.text = "Effacer"
		bouton_effacer.focus_mode = Control.FOCUS_NONE
		bouton_effacer.pressed.connect(_effacer_touche.bind(nom_action))

		ligne.add_child(label_action)
		ligne.add_child(bouton_modifier)
		ligne.add_child(bouton_effacer)

		conteneur_liste.add_child(ligne)

		boutons_changer[nom_action] = bouton_modifier

func _demarrer_rebind(nom_action: StringName) -> void:
	en_attente_de_rebind = true
	action_cible = nom_action
	_set_ui_capture_mouse(true)
	_get_bouton(action_cible).text = "Appuie sur une touche"

func _effacer_touche(nom_action: StringName) -> void:
	AutoInput.effacer_touche(nom_action)
	_get_bouton(nom_action).text = "Non assignée"
	_set_modifie(true)

func _unhandled_input(e: InputEvent) -> void:
	if not en_attente_de_rebind:
		return

	if e is InputEventKey and e.pressed and not e.echo:
		var touche := InputEventKey.new()
		touche.keycode = (e as InputEventKey).keycode
		_valider_rebind(action_cible, touche)
		return

	if e is InputEventMouseButton and e.pressed:
		var souris := InputEventMouseButton.new()
		souris.button_index = (e as InputEventMouseButton).button_index
		souris.double_click = (e as InputEventMouseButton).double_click
		_valider_rebind(action_cible, souris)
		return

	if e is InputEventJoypadButton and e.pressed:
		var manette := InputEventJoypadButton.new()
		manette.button_index = (e as InputEventJoypadButton).button_index
		_valider_rebind(action_cible, manette)
		return

func _valider_rebind(nom_action: StringName, nouvelle_entree: InputEvent) -> void:
	AutoInput.definir_touche(nom_action, nouvelle_entree)
	_get_bouton(nom_action).text = _get_action_text(nom_action)

	en_attente_de_rebind = false
	_set_ui_capture_mouse(false)
	_set_modifie(true)

func _reinitialiser_touches() -> void:
	AutoInput.retablir_touches_defaut()

	for entree in actions_configurables:
		var nom_action: StringName = StringName(entree.get("action", ""))
		_get_bouton(nom_action).text = _get_action_text(nom_action)

	en_attente_de_rebind = false
	_set_ui_capture_mouse(false)
	_set_modifie(true)

func _appliquer_modifs() -> void:
	AutoInput.sauvegarder()
	_set_modifie(false)

func _set_modifie(val: bool) -> void:
	modif_en_attente = val
	bouton_appliquer.visible = modif_en_attente

func _get_bouton(nom_action: StringName) -> Button:
	return boutons_changer[nom_action] as Button

func _set_ui_capture_mouse(active: bool) -> void:
	if active:
		_mouse_filters_backup.clear()
		_recursive_set_ignore(self)
	else:
		for n in _mouse_filters_backup.keys():
			if is_instance_valid(n):
				var c := n as Control
				c.mouse_filter = _mouse_filters_backup[n] as Control.MouseFilter
				
		_mouse_filters_backup.clear()

func _recursive_set_ignore(node: Node) -> void:
	if node is Control:
		var c := node as Control
		_mouse_filters_backup[c] = c.mouse_filter
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE

	for child in node.get_children():
		_recursive_set_ignore(child)

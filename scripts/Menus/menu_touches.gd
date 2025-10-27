extends CanvasLayer
class_name MenuTouches

@export var actions_configurables: Array[Dictionary] = [
	{"action": "droite",  "label": "Aller à droite"},
	{"action": "gauche",  "label": "Aller à gauche"},
	{"action": "haut",    "label": "Haut / Saut / Monter"},
	{"action": "bas",     "label": "Bas / Descendre"},
	{"action": "attaque", "label": "Attaque"},
	{"action": "pause",   "label": "Pause / Menu"}
]

@onready var conteneur_liste: VBoxContainer = %ListeActions
@onready var bouton_appliquer: Button = %btn_appliquer
@onready var bouton_reinitialiser: Button = %btn_reinitialiser

var boutons_changer: Dictionary = {}
var en_attente_de_rebind: bool = false
var action_cible: StringName
var ignorer_click_souris: bool = false
var modif_en_attente: bool = false

var binds_init: Dictionary = {} # {StringName: InputEvent or null}

func _ready() -> void:
	_snapshot_bind_initial()
	creer_interface()

	bouton_appliquer.pressed.connect(_appliquer_modifs)
	bouton_reinitialiser.pressed.connect(_reinitialiser_touches)

	_set_modifie(false)
	set_process_unhandled_input(true)

func _snapshot_bind_initial() -> void:
	binds_init.clear()
	for entree in actions_configurables:
		var nom_action: StringName = StringName(entree.get("action", ""))
		var evts: Array[InputEvent] = InputMap.action_get_events(nom_action)
		if evts.size() > 0:
			binds_init[nom_action] = evts[0].duplicate()
		else:
			binds_init[nom_action] = null

func creer_interface() -> void:
	for enfant in conteneur_liste.get_children():
		conteneur_liste.remove_child(enfant)
		enfant.queue_free()

	boutons_changer.clear()

	for entree in actions_configurables:
		var nom_action: StringName = StringName(entree.get("action", ""))
		var texte_affiche: String = String(entree.get("label", nom_action))

		var ligne: HBoxContainer = HBoxContainer.new()

		var label_action: Label = Label.new()
		label_action.text = texte_affiche
		label_action.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label_action.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var bouton_modifier: Button = Button.new()
		bouton_modifier.text = AutoInput.get_texte_touche(nom_action)
		bouton_modifier.focus_mode = Control.FOCUS_NONE
		bouton_modifier.pressed.connect(_demarrer_rebind.bind(nom_action))

		var bouton_effacer: Button = Button.new()
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
	ignorer_click_souris = true
	_get_bouton(action_cible).text = "Appuie sur une touche"

func _effacer_touche(nom_action: StringName) -> void:
	AutoInput.effacer_touche(nom_action)
	_get_bouton(nom_action).text = "Non assignée"
	_set_modifie(true)

func _unhandled_input(e: InputEvent) -> void:
	if not en_attente_de_rebind:
		return

	if e is InputEventKey and e.pressed and not e.echo:
		var touche: InputEventKey = InputEventKey.new()
		touche.physical_keycode = e.physical_keycode
		_valider_rebind(action_cible, touche)
		return

	if e is InputEventMouseButton and e.pressed:
		if ignorer_click_souris:
			ignorer_click_souris = false
			return
		var souris: InputEventMouseButton = InputEventMouseButton.new()
		souris.button_index = e.button_index
		_valider_rebind(action_cible, souris)
		return

	if e is InputEventJoypadButton and e.pressed:
		var manette: InputEventJoypadButton = InputEventJoypadButton.new()
		manette.button_index = e.button_index
		_valider_rebind(action_cible, manette)
		return

func _valider_rebind(nom_action: StringName, nouvelle_entree: InputEvent) -> void:
	AutoInput.definir_touche(nom_action, nouvelle_entree)
	_get_bouton(nom_action).text = AutoInput.get_texte_touche(nom_action)

	en_attente_de_rebind = false
	_set_modifie(true)

func _reinitialiser_touches() -> void:
	for entree in actions_configurables:
		var nom_action: StringName = StringName(entree.get("action", ""))

		AutoInput.effacer_touche(nom_action)

		var evt_init: Variant = binds_init.get(nom_action, null)
		if evt_init != null:
			var evt_dup: InputEvent = (evt_init as InputEvent).duplicate()
			AutoInput.definir_touche(nom_action, evt_dup)

		_get_bouton(nom_action).text = AutoInput.get_texte_touche(nom_action)

	en_attente_de_rebind = false
	_set_modifie(true)

func _appliquer_modifs() -> void:
	AutoInput.sauvegarder()
	_set_modifie(false)

func _set_modifie(val: bool) -> void:
	modif_en_attente = val
	bouton_appliquer.visible = modif_en_attente

func _get_bouton(nom_action: StringName) -> Button:
	return boutons_changer[nom_action] as Button

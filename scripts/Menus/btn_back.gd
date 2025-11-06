extends Button
class_name BtnBack

@export var use_cancel_action: bool = false
@export var cancel_action: StringName = "ui_cancel"
@export var debug_enabled: bool = false

func _d(msg: String) -> void:
	if debug_enabled:
		print("[BtnBack]", Time.get_ticks_msec(), msg)

func _ready() -> void:
	_d("READY use_cancel_action=" + str(use_cancel_action) + " cancel_action=" + str(cancel_action))
	pressed.connect(_on_back)
	GestionnaireRetour.historique_modifie.connect(_refresh_enabled)
	set_process_unhandled_input(use_cancel_action)
	_refresh_enabled()

func _unhandled_input(event: InputEvent) -> void:
	if use_cancel_action and event.is_action_pressed(cancel_action):
		var echo := false
		if event is InputEventKey:
			echo = (event as InputEventKey).echo
		_d("_unhandled_input action=" + str(cancel_action) + " pressed echo=" + str(echo))
		_on_back()
		get_viewport().set_input_as_handled()

func _on_back() -> void:
	var node: Node = self
	while node:
		if node is PauseMenu:
			var pm := node as PauseMenu
			if pm.gestionnaire:
				pm.gestionnaire.reprendre()
			GestionnaireRetour.retour()
			_refresh_enabled()
			return
		var parent := node.get_parent()
		if parent is PauseMenu:
			var pm := parent as PauseMenu
			var root := pm.get_node_or_null("Root")
			if node != root:
				if node.has_method("fermer"):
					node.call("fermer")
				else:
					node.queue_free()
			if pm.gestionnaire:
				pm.gestionnaire.reprendre()
			GestionnaireRetour.retour()
			_refresh_enabled()
			return
		node = parent
	GestionnaireRetour.retour()
	_refresh_enabled()

func _refresh_enabled() -> void:
	var possible := GestionnaireRetour.retour_possible()
	disabled = not possible
	_d("_refresh_enabled disabled=" + str(disabled) + " possible=" + str(possible))

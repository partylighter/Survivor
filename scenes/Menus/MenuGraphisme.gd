extends Control
class_name MenuGraphisme

@export_node_path("Button") var chemin_btn_resolution: NodePath
@export_node_path("Button") var chemin_btn_mode: NodePath
@export_node_path("Button") var chemin_btn_appliquer: NodePath
@export_node_path("Button") var chemin_btn_reinitialiser: NodePath

var btn_resolution: Button
var btn_mode: Button
var btn_appliquer: Button
var btn_reinitialiser: Button

func _ready() -> void:
	btn_resolution = get_node_or_null(chemin_btn_resolution) as Button
	btn_mode = get_node_or_null(chemin_btn_mode) as Button
	btn_appliquer = get_node_or_null(chemin_btn_appliquer) as Button
	btn_reinitialiser = get_node_or_null(chemin_btn_reinitialiser) as Button

	if btn_resolution == null or btn_mode == null or btn_appliquer == null or btn_reinitialiser == null:
		push_error("[MenuGraphisme] NodePaths invalides (Button manquants).")
		return

	btn_resolution.pressed.connect(_on_resolution_pressed)
	btn_mode.pressed.connect(_on_mode_pressed)
	btn_appliquer.pressed.connect(_on_appliquer_pressed)
	btn_reinitialiser.pressed.connect(_on_reinitialiser_pressed)

	_refresh()

func _on_resolution_pressed() -> void:
	GestionnaireGraphisme.cycle_resolution_preview(1)
	_refresh()

func _on_mode_pressed() -> void:
	GestionnaireGraphisme.toggle_fullscreen_preview()
	_refresh()

func _on_appliquer_pressed() -> void:
	GestionnaireGraphisme.apply_and_save()
	_refresh()

func _on_reinitialiser_pressed() -> void:
	GestionnaireGraphisme.reset_defaults()
	_refresh()

func _refresh() -> void:
	var r := GestionnaireGraphisme.get_preview_resolution()
	btn_resolution.text = "Résolution: " + str(r.x) + " x " + str(r.y)

	var mode_txt := "Fullscreen" if GestionnaireGraphisme.get_preview_fullscreen() else "Fenêtré"
	btn_mode.text = "Mode: " + mode_txt

	var pending := GestionnaireGraphisme.has_pending_changes()
	btn_appliquer.visible = pending
	btn_reinitialiser.disabled = not pending

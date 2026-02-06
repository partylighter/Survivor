extends CanvasLayer
class_name ArmContactStatsDisplayer

@export var actif: bool = true
@export var debug_enabled: bool = false

var _ui_visible: bool = true
@export var ui_visible: bool = true:
	set(v):
		_ui_visible = v
		_apply_ui_visible()
	get:
		return _ui_visible

@export_node_path("GestionnaireUpgradesArmeContact") var chemin_upgrades: NodePath

@export_group("Affichage")
@export var ui_position: Vector2 = Vector2(16, 420)
@export_range(8, 64, 1) var ui_taille_police: int = 14
@export var ui_largeur_min_px: float = 320.0
@export var ui_couleur_fond: Color = Color(0, 0, 0, 0.5)
@export var ui_couleur_texte: Color = Color(1, 1, 1, 0.9)
@export_range(0, 32, 1) var ui_espace_lignes: int = 2

@export_group("Raccourci")
@export var toggle_key: Key = KEY_F4

var arme: ArmeContact
var upgrades: GestionnaireUpgradesArmeContact

var _panel: Panel
var _vbox: VBoxContainer
var _stylebox: StyleBoxFlat

var lbl_nom: Label
var lbl_degats: Label
var lbl_cooldown: Label
var lbl_duree_active: Label
var lbl_recul: Label

var lbl_hitbox_exists: Label
var lbl_hitbox_disabled: Label
var lbl_hitbox_monitoring: Label
var lbl_hitbox_mask: Label
var lbl_hitbox_layer: Label

var _dbg_last_arme_id: int = 0
var _dbg_last_upg_id: int = 0
var _dbg_last_ui: bool = true
var _dbg_missing_arme_printed: bool = false
var _dbg_missing_upg_printed: bool = false

func _ready() -> void:
	_ui_visible = ui_visible
	_creer_ui()
	_appliquer_style()
	_apply_ui_visible()
	_dbg("ready ui=%s actif=%s" % [str(_ui_visible), str(actif)])

func _dbg(msg: String) -> void:
	if debug_enabled:
		print("[ArmContactStatsDisplayer] ", msg)

func _apply_ui_visible() -> void:
	if _panel != null:
		_panel.visible = _ui_visible
	set_process(_ui_visible and actif)

	if _dbg_last_ui != _ui_visible:
		_dbg_last_ui = _ui_visible
		_dbg("ui_visible=%s" % str(_ui_visible))

func _creer_ui() -> void:
	_panel = Panel.new()
	add_child(_panel)
	_panel.position = ui_position
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_vbox = VBoxContainer.new()
	_panel.add_child(_vbox)
	_vbox.anchor_left = 0.0
	_vbox.anchor_top = 0.0
	_vbox.anchor_right = 1.0
	_vbox.anchor_bottom = 1.0
	_vbox.offset_left = 8
	_vbox.offset_top = 8
	_vbox.offset_right = -8
	_vbox.offset_bottom = -8
	_vbox.add_theme_constant_override("separation", ui_espace_lignes)

	lbl_nom = Label.new()
	lbl_degats = Label.new()
	lbl_cooldown = Label.new()
	lbl_duree_active = Label.new()
	lbl_recul = Label.new()

	lbl_hitbox_exists = Label.new()
	lbl_hitbox_disabled = Label.new()
	lbl_hitbox_monitoring = Label.new()
	lbl_hitbox_mask = Label.new()
	lbl_hitbox_layer = Label.new()

	_vbox.add_child(lbl_nom)
	_vbox.add_child(lbl_degats)
	_vbox.add_child(lbl_duree_active)
	_vbox.add_child(lbl_cooldown)
	_vbox.add_child(lbl_recul)

	_vbox.add_child(HSeparator.new())

	_vbox.add_child(lbl_hitbox_exists)
	_vbox.add_child(lbl_hitbox_disabled)
	_vbox.add_child(lbl_hitbox_monitoring)
	_vbox.add_child(lbl_hitbox_mask)
	_vbox.add_child(lbl_hitbox_layer)

func _appliquer_style() -> void:
	if _stylebox == null:
		_stylebox = StyleBoxFlat.new()

	_stylebox.bg_color = ui_couleur_fond
	_stylebox.border_color = Color(1, 1, 1, 0.3)
	_stylebox.border_width_top = 1
	_stylebox.border_width_bottom = 1
	_stylebox.border_width_left = 1
	_stylebox.border_width_right = 1
	_stylebox.corner_radius_top_left = 4
	_stylebox.corner_radius_top_right = 4
	_stylebox.corner_radius_bottom_left = 4
	_stylebox.corner_radius_bottom_right = 4

	_panel.add_theme_stylebox_override("panel", _stylebox)
	_panel.custom_minimum_size = Vector2(ui_largeur_min_px, 0.0)
	_panel.position = ui_position

	var labels := [
		lbl_nom, lbl_degats, lbl_cooldown, lbl_duree_active, lbl_recul,
		lbl_hitbox_exists, lbl_hitbox_disabled, lbl_hitbox_monitoring, lbl_hitbox_mask, lbl_hitbox_layer
	]
	for l in labels:
		if l == null:
			continue
		l.add_theme_font_size_override("font_size", ui_taille_police)
		l.add_theme_color_override("font_color", ui_couleur_texte)

func _process(_dt: float) -> void:
	if not actif:
		return
	if _panel == null or not _panel.visible:
		return
	_panel.position = ui_position

	if arme == null or not is_instance_valid(arme):
		var a := get_tree().get_nodes_in_group("armes_contact")
		if not a.is_empty():
			arme = a[0] as ArmeContact
			_dbg_missing_arme_printed = false
		elif not _dbg_missing_arme_printed:
			_dbg_missing_arme_printed = true
			_dbg("aucune arme dans groupe 'armes_contact'")

	if upgrades == null or not is_instance_valid(upgrades):
		upgrades = get_node_or_null(chemin_upgrades) as GestionnaireUpgradesArmeContact
		if upgrades == null:
			var u := get_tree().get_nodes_in_group("upg_arme_contact")
			if not u.is_empty():
				upgrades = u[0] as GestionnaireUpgradesArmeContact
				_dbg_missing_upg_printed = false
			elif not _dbg_missing_upg_printed:
				_dbg_missing_upg_printed = true
				_dbg("aucun upgrades dans groupe 'upg_arme_contact'")

	var aid := arme.get_instance_id() if arme != null and is_instance_valid(arme) else 0
	if aid != _dbg_last_arme_id:
		_dbg_last_arme_id = aid
		if aid == 0:
			_dbg("arme=null")
		else:
			_dbg("arme trouvée id=%d nom=%s" % [aid, String(arme.nom_arme)])

	var uid := upgrades.get_instance_id() if upgrades != null and is_instance_valid(upgrades) else 0
	if uid != _dbg_last_upg_id:
		_dbg_last_upg_id = uid
		if uid == 0:
			_dbg("upgrades=null")
		else:
			_dbg("upgrades trouvés id=%d" % uid)

	if arme == null:
		lbl_nom.text = "ARME : (aucune)"
		lbl_degats.text = ""
		lbl_duree_active.text = ""
		lbl_cooldown.text = ""
		lbl_recul.text = ""
		lbl_hitbox_exists.text = "Hitbox : (aucune)"
		lbl_hitbox_disabled.text = ""
		lbl_hitbox_monitoring.text = ""
		lbl_hitbox_mask.text = ""
		lbl_hitbox_layer.text = ""
		return

	lbl_nom.text = "ARME : %s" % String(arme.nom_arme)
	lbl_degats.text = "Dégâts : %d" % int(arme.degats)
	lbl_duree_active.text = "Durée active : %.3fs" % float(arme.duree_active_s)
	lbl_cooldown.text = "Cooldown : %.3fs" % float(arme.cooldown_s)
	lbl_recul.text = "Recul : %.1f" % float(arme.recul_force)

	var hb: HitBoxContact = arme.hitbox
	if hb == null or not is_instance_valid(hb):
		hb = arme.get_node_or_null(arme.chemin_hitbox) as HitBoxContact
		arme.hitbox = hb

	var hb_ok := (hb != null and is_instance_valid(hb))
	lbl_hitbox_exists.text = "Hitbox : %s" % ("OK" if hb_ok else "ABSENTE")

	if not hb_ok:
		lbl_hitbox_disabled.text = ""
		lbl_hitbox_monitoring.text = ""
		lbl_hitbox_mask.text = ""
		lbl_hitbox_layer.text = ""
		return

	var disabled_val := false
	if "disabled" in hb:
		disabled_val = bool(hb.get("disabled"))

	var monitoring_val := true
	if "monitoring" in hb:
		monitoring_val = bool(hb.get("monitoring"))

	var mask_val := 0
	if "collision_mask" in hb:
		mask_val = int(hb.get("collision_mask"))

	var layer_val := 0
	if "collision_layer" in hb:
		layer_val = int(hb.get("collision_layer"))

	lbl_hitbox_disabled.text = "Hitbox disabled : %s" % ("Oui" if disabled_val else "Non")
	lbl_hitbox_monitoring.text = "Hitbox monitoring : %s" % ("Oui" if monitoring_val else "Non")
	lbl_hitbox_mask.text = "Hitbox mask : %d" % mask_val
	lbl_hitbox_layer.text = "Hitbox layer : %d" % layer_val

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == toggle_key:
			ui_visible = not ui_visible
			_dbg("toggle key=%s -> ui=%s" % [str(toggle_key), str(_ui_visible)])

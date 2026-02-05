extends CanvasLayer
class_name ArmTirStatsDisplayer

@export var actif: bool = true
@export var debug_enabled: bool = false

var _ui_visible: bool = true
@export var ui_visible: bool = true:
	set(v):
		_ui_visible = v
		_apply_ui_visible()
	get:
		return _ui_visible

@export_node_path("GestionnaireUpgradesArmeTir") var chemin_upgrades: NodePath

@export_group("Affichage")
@export var ui_position: Vector2 = Vector2(16, 140)
@export_range(8, 64, 1) var ui_taille_police: int = 14
@export var ui_largeur_min_px: float = 320.0
@export var ui_couleur_fond: Color = Color(0, 0, 0, 0.5)
@export var ui_couleur_texte: Color = Color(1, 1, 1, 0.9)
@export_range(0, 32, 1) var ui_espace_lignes: int = 2

@export_group("Raccourci")
@export var toggle_key: Key = KEY_F3

var arme: ArmeTir
var upgrades: GestionnaireUpgradesArmeTir

var _panel: Panel
var _vbox: VBoxContainer
var _stylebox: StyleBoxFlat

var lbl_nom: Label
var lbl_degats: Label
var lbl_nb_balles: Label
var lbl_dispersion: Label
var lbl_cooldown: Label
var lbl_duree_active: Label
var lbl_recul: Label
var lbl_hitscan: Label
var lbl_tir_max: Label
var lbl_portee: Label
var lbl_mask: Label

var lbl_proj_vitesse: Label
var lbl_proj_vie: Label
var lbl_proj_mask: Label
var lbl_proj_marge: Label
var lbl_proj_largeur: Label
var lbl_proj_rays: Label
var lbl_proj_contacts: Label
var lbl_proj_ignore: Label

var _dbg_last_arme_id: int = 0
var _dbg_last_upg_id: int = 0
var _dbg_last_ui: bool = true
var _dbg_missing_armed_printed: bool = false
var _dbg_missing_upg_printed: bool = false

func _ready() -> void:
	_ui_visible = ui_visible
	_creer_ui()
	_appliquer_style()
	_apply_ui_visible()
	_dbg("ready ui=%s actif=%s" % [str(_ui_visible), str(actif)])

func _dbg(msg: String) -> void:
	if debug_enabled:
		print("[ArmTirStatsDisplayer] ", msg)

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
	lbl_nb_balles = Label.new()
	lbl_dispersion = Label.new()
	lbl_cooldown = Label.new()
	lbl_duree_active = Label.new()
	lbl_recul = Label.new()
	lbl_hitscan = Label.new()
	lbl_tir_max = Label.new()
	lbl_portee = Label.new()
	lbl_mask = Label.new()

	lbl_proj_vitesse = Label.new()
	lbl_proj_vie = Label.new()
	lbl_proj_mask = Label.new()
	lbl_proj_marge = Label.new()
	lbl_proj_largeur = Label.new()
	lbl_proj_rays = Label.new()
	lbl_proj_contacts = Label.new()
	lbl_proj_ignore = Label.new()

	_vbox.add_child(lbl_nom)
	_vbox.add_child(lbl_degats)
	_vbox.add_child(lbl_nb_balles)
	_vbox.add_child(lbl_dispersion)
	_vbox.add_child(lbl_cooldown)
	_vbox.add_child(lbl_duree_active)
	_vbox.add_child(lbl_recul)
	_vbox.add_child(lbl_hitscan)
	_vbox.add_child(lbl_tir_max)
	_vbox.add_child(lbl_portee)
	_vbox.add_child(lbl_mask)

	_vbox.add_child(HSeparator.new())

	_vbox.add_child(lbl_proj_vitesse)
	_vbox.add_child(lbl_proj_vie)
	_vbox.add_child(lbl_proj_mask)
	_vbox.add_child(lbl_proj_marge)
	_vbox.add_child(lbl_proj_largeur)
	_vbox.add_child(lbl_proj_rays)
	_vbox.add_child(lbl_proj_contacts)
	_vbox.add_child(lbl_proj_ignore)

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
		lbl_nom, lbl_degats, lbl_nb_balles, lbl_dispersion, lbl_cooldown, lbl_duree_active,
		lbl_recul, lbl_hitscan, lbl_tir_max, lbl_portee, lbl_mask,
		lbl_proj_vitesse, lbl_proj_vie, lbl_proj_mask, lbl_proj_marge, lbl_proj_largeur,
		lbl_proj_rays, lbl_proj_contacts, lbl_proj_ignore
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

	if arme == null or not is_instance_valid(arme):
		var a := get_tree().get_nodes_in_group("armes_tir")
		if not a.is_empty():
			arme = a[0] as ArmeTir
			_dbg_missing_armed_printed = false
		elif not _dbg_missing_armed_printed:
			_dbg_missing_armed_printed = true
			_dbg("aucune arme dans groupe 'armes_tir'")

	if upgrades == null or not is_instance_valid(upgrades):
		upgrades = get_node_or_null(chemin_upgrades) as GestionnaireUpgradesArmeTir
		if upgrades == null:
			var u := get_tree().get_nodes_in_group("upg_arme_tir")
			if not u.is_empty():
				upgrades = u[0] as GestionnaireUpgradesArmeTir
				_dbg_missing_upg_printed = false
			elif not _dbg_missing_upg_printed:
				_dbg_missing_upg_printed = true
				_dbg("aucun upgrades dans groupe 'upg_arme_tir'")

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
		return

	lbl_nom.text = "ARME : %s" % String(arme.nom_arme)
	lbl_degats.text = "Dégâts : %d" % int(arme.degats)
	lbl_nb_balles.text = "Nb balles : %d" % int(arme.nb_balles)
	lbl_dispersion.text = "Dispersion : %.1f°" % float(arme.dispersion_deg)
	lbl_cooldown.text = "Cooldown : %.3fs" % float(arme.cooldown_s)
	lbl_duree_active.text = "Durée active : %.3fs" % float(arme.duree_active_s)
	lbl_recul.text = "Recul : %.1f" % float(arme.recul_force)
	lbl_hitscan.text = "Hitscan : %s" % ("Oui" if arme.hitscan else "Non")
	lbl_tir_max.text = "Tir max/frame : %d" % int(arme.tir_max_par_frame)
	lbl_portee.text = "Portée hitscan : %.0fpx" % float(arme.portee_hitscan_px)
	lbl_mask.text = "Mask tir : %d" % int(arme.mask_tir)

	var pv: float = 0.0
	var vie: float = 0.0
	var pmask: int = 0
	var marge: float = 0.0
	var largeur: float = 0.0
	var rays: int = 0
	var contacts: int = 0
	var ign: bool = false

	if upgrades != null and is_instance_valid(upgrades):
		pv = float(upgrades.vitesse_px_s)
		vie = float(upgrades.duree_vie_s)
		pmask = int(upgrades.collision_mask)
		marge = float(upgrades.marge_raycast_px)
		largeur = float(upgrades.largeur_zone_scane)
		rays = int(upgrades.nombre_de_rayon_dans_zone_scane)
		contacts = int(upgrades.contacts_avant_destruction)
		ign = bool(upgrades.ignorer_meme_cible)

	lbl_proj_vitesse.text = "Projectile vitesse : %.0f px/s" % pv
	lbl_proj_vie.text = "Projectile vie : %.2fs" % vie
	lbl_proj_mask.text = "Projectile mask : %d" % pmask
	lbl_proj_marge.text = "Projectile marge ray : %.2fpx" % marge
	lbl_proj_largeur.text = "Zone scan largeur : %.1fpx" % largeur
	lbl_proj_rays.text = "Rays dans zone : %d" % rays
	lbl_proj_contacts.text = "Contacts avant destroy : %d" % contacts
	lbl_proj_ignore.text = "Ignore même cible : %s" % ("Oui" if ign else "Non")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == toggle_key:
			ui_visible = not ui_visible
			_dbg("toggle key=%s -> ui=%s" % [str(toggle_key), str(_ui_visible)])

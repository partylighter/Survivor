extends CanvasLayer
class_name BaseStatsDisplayer

@export var ui_visible: bool = true : set = set_ui_visible, get = get_ui_visible
@export var actif: bool = true

@export_node_path("PlayerBase") var chemin_base: NodePath
@export_node_path("SanteBase") var chemin_sante_base: NodePath
@export_node_path("CarburantBase") var chemin_carburant_base: NodePath
@export_node_path("DeplacementBase") var chemin_deplacement_base: NodePath

@export_group("Affichage")
@export var ui_position: Vector2 = Vector2(16, 140)
@export_range(8, 64, 1) var ui_taille_police: int = 14
@export var ui_largeur_min_px: float = 320.0
@export var ui_couleur_fond: Color = Color(0, 0, 0, 0.5)
@export var ui_couleur_texte: Color = Color(1, 1, 1, 0.9)
@export_range(0, 32, 1) var ui_espace_lignes: int = 2

@onready var base: PlayerBase = get_node_or_null(chemin_base) as PlayerBase
@onready var sante_base: SanteBase = get_node_or_null(chemin_sante_base) as SanteBase
@onready var carburant_base: CarburantBase = get_node_or_null(chemin_carburant_base) as CarburantBase
@onready var dep_base: DeplacementBase = get_node_or_null(chemin_deplacement_base) as DeplacementBase

var _panel: Panel
var _vbox: VBoxContainer

var lbl_zone: Label
var lbl_controle: Label
var lbl_pv: Label
var lbl_reserve: Label
var lbl_vitesse: Label
var lbl_infos: Label

var _stylebox: StyleBoxFlat

func _ready() -> void:
	_creer_ui()
	_appliquer_style()
	set_ui_visible(ui_visible)

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

	lbl_zone = Label.new()
	lbl_controle = Label.new()
	lbl_pv = Label.new()
	lbl_reserve = Label.new()
	lbl_vitesse = Label.new()
	lbl_infos = Label.new()

	_vbox.add_child(lbl_zone)
	_vbox.add_child(lbl_controle)
	_vbox.add_child(lbl_pv)
	_vbox.add_child(lbl_reserve)
	_vbox.add_child(lbl_vitesse)
	_vbox.add_child(lbl_infos)

func _appliquer_style() -> void:
	if _panel != null:
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

	var labels := [lbl_zone, lbl_controle, lbl_pv, lbl_reserve, lbl_vitesse, lbl_infos]
	for l in labels:
		if l == null:
			continue
		l.add_theme_font_size_override("font_size", ui_taille_police)
		l.add_theme_color_override("font_color", ui_couleur_texte)

func _process(_dt: float) -> void:
	if not actif:
		return
	if _panel == null:
		return
	if base == null and sante_base == null and carburant_base == null:
		return

	var zone_txt := "Zone : ?"
	if Engine.has_singleton("EtatJeu") or true:
		if typeof(EtatJeu.zone_actuelle) == TYPE_INT:
			zone_txt = "Zone : %s" % ("MONDE" if EtatJeu.zone_actuelle == EtatJeu.Zone.MONDE else "BASE")
	lbl_zone.text = zone_txt

	var controle := false
	if base != null and is_instance_valid(base):
		controle = base.controle_actif
	lbl_controle.text = "Contrôle : %s" % ("ON" if controle else "OFF")

	var pv_now := 0
	var pv_max := 0
	if sante_base != null and is_instance_valid(sante_base) and sante_base.stats != null:
		pv_now = sante_base.sante
		pv_max = sante_base.stats.sante_max
	lbl_pv.text = "PV base : %d / %d" % [pv_now, pv_max]

	var r_now := 0.0
	var r_max := 0.0
	if carburant_base != null and is_instance_valid(carburant_base) and carburant_base.stats != null:
		r_now = carburant_base.reserve
		r_max = carburant_base.stats.reserve_energie_max
	lbl_reserve.text = "Réserve : %.1f / %.1f" % [r_now, r_max]

	var speed := 0.0
	if base != null and is_instance_valid(base):
		speed = base.velocity.length()

	var vmax := 0.0
	if dep_base != null and is_instance_valid(dep_base):
		vmax = dep_base.vitesse_max_avant_px_s

	var pct := 0.0
	if vmax > 1.0:
		pct = clampf(speed / vmax, 0.0, 2.0) * 100.0

	lbl_vitesse.text = "Vitesse : %.0f px/s (%.0f%%)" % [speed, pct]

	var infos := ""
	if dep_base == null or not is_instance_valid(dep_base):
		infos = "Infos : deplacement manquant"
	else:
		infos = "Infos : vmax %.0f / frein %.0f / grip %.0f" % [
			dep_base.vitesse_max_avant_px_s,
			dep_base.frein_px_s2,
			dep_base.grip_lateral_low_px_s2
		]
	lbl_infos.text = infos

func set_ui_visible(v: bool) -> void:
	ui_visible = v
	visible = v

func get_ui_visible() -> bool:
	return ui_visible

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:
			set_ui_visible(!ui_visible)

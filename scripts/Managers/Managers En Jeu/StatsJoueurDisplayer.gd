extends CanvasLayer
class_name PlayerStatsDisplayer

@export var ui_visible: bool = true : set = set_ui_visible, get = get_ui_visible
@export var actif: bool = true

@export_node_path("StatsJoueur") var chemin_stats: NodePath
@export_node_path("Sante") var chemin_sante: NodePath
@export_node_path("Player") var chemin_player: NodePath

@export_group("Affichage")
@export var ui_position: Vector2 = Vector2(16, 16)
@export_range(8, 64, 1) var ui_taille_police: int = 14
@export var ui_largeur_min_px: float = 260.0
@export var ui_couleur_fond: Color = Color(0, 0, 0, 0.5)
@export var ui_couleur_texte: Color = Color(1, 1, 1, 0.9)
@export_range(0, 32, 1) var ui_espace_lignes: int = 2

@onready var stats: StatsJoueur = get_node_or_null(chemin_stats) as StatsJoueur
@onready var sante: Sante = get_node_or_null(chemin_sante) as Sante
@onready var joueur: Player = get_node_or_null(chemin_player) as Player

var _panel: Panel
var _vbox: VBoxContainer

var lbl_pv: Label
var lbl_vitesse: Label
var lbl_chance: Label
var lbl_dash: Label

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

	lbl_pv = Label.new()
	lbl_vitesse = Label.new()
	lbl_chance = Label.new()
	lbl_dash = Label.new()

	_vbox.add_child(lbl_pv)
	_vbox.add_child(lbl_vitesse)
	_vbox.add_child(lbl_chance)
	_vbox.add_child(lbl_dash)


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

	var labels := [lbl_pv, lbl_vitesse, lbl_chance, lbl_dash]
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
	if stats == null and sante == null and joueur == null:
		return

	var pv_now: int = 0
	var pv_max: int = 0
	var overheal_now: float = 0.0

	if sante != null:
		pv_now = int(sante.pv)
		pv_max = sante.max_pv
		if sante.has_method("get_overheal"):
			overheal_now = sante.get_overheal()

	var vitesse_now: float = 0.0
	var chance_now: float = 0.0
	var dash_actuel: int = 0
	var dash_max: int = 0

	if stats != null:
		if stats.has_method("get_vitesse_effective"):
			vitesse_now = stats.get_vitesse_effective()
		if stats.has_method("get_chance"):
			chance_now = stats.get_chance()
		if stats.has_method("get_dash_max_effectif"):
			dash_max = stats.get_dash_max_effectif()

	if joueur != null:
		dash_actuel = joueur.dash_charges_actuelles

	var txt_pv := "PV : %d / %d" % [pv_now, pv_max]
	if overheal_now > 0.0:
		txt_pv += "  (+%.0f)" % overheal_now
	lbl_pv.text = txt_pv

	lbl_vitesse.text = "Vitesse : %.0f" % vitesse_now
	lbl_chance.text = "Chance : %.1f%%" % chance_now
	lbl_dash.text = "Dash : %d / %d" % [dash_actuel, dash_max]


func set_ui_visible(v: bool) -> void:
	ui_visible = v
	visible = v


func get_ui_visible() -> bool:
	return ui_visible


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F2:
			set_ui_visible(!ui_visible)

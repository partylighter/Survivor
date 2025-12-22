extends CanvasLayer
class_name StatsDisplayer

@export var ui_visible: bool = true : set = set_ui_visible, get = get_ui_visible
@export var actif: bool = true

@export_node_path("Node") var chemin_stats: NodePath
@export_node_path("GestionnaireEnnemis") var chemin_ennemis: NodePath

@export_node_path("Label") var chemin_lbl_vague: NodePath
@export_node_path("Label") var chemin_lbl_temps: NodePath
@export_node_path("Label") var chemin_lbl_vivants: NodePath
@export_node_path("Label") var chemin_lbl_kills_total: NodePath
@export_node_path("Label") var chemin_lbl_score_total: NodePath
@export_node_path("Label") var chemin_lbl_kills_vague: NodePath
@export_node_path("Label") var chemin_lbl_score_vague: NodePath

@onready var stats_ref: StatsVagues = get_node_or_null(chemin_stats) as StatsVagues
@onready var ennemis_ref: GestionnaireEnnemis = get_node_or_null(chemin_ennemis) as GestionnaireEnnemis

@onready var lbl_vague: Label = get_node(chemin_lbl_vague) as Label
@onready var lbl_temps: Label = get_node(chemin_lbl_temps) as Label
@onready var lbl_vivants: Label = get_node(chemin_lbl_vivants) as Label
@onready var lbl_kills_total: Label = get_node(chemin_lbl_kills_total) as Label
@onready var lbl_score_total: Label = get_node(chemin_lbl_score_total) as Label
@onready var lbl_kills_vague: Label = get_node(chemin_lbl_kills_vague) as Label
@onready var lbl_score_vague: Label = get_node(chemin_lbl_score_vague) as Label

func _ready() -> void:
	set_ui_visible(ui_visible)

func _process(_dt: float) -> void:
	if not actif:
		return

	var vivants_now: int = 0
	var kills_tot_now: int = 0
	var score_tot_now: int = 0
	var vague_id: int = -1
	var cycle: int = 0
	var kills_vague_now: int = 0
	var score_vague_now: int = 0
	var temps_total_s: float = 0.0
	var temps_vague_s: float = 0.0

	if is_instance_valid(ennemis_ref):
		vivants_now = ennemis_ref.ennemis.size()
		kills_tot_now = ennemis_ref.ennemis_tues_total
		vague_id = ennemis_ref.i_vague
		cycle = ennemis_ref.cycle_vagues
		kills_vague_now = ennemis_ref.tues_vague
		temps_total_s = ennemis_ref.temps_total_s
		temps_vague_s = ennemis_ref.t_vague

	if is_instance_valid(stats_ref):
		var sv: Dictionary = stats_ref.get_stats_vague()
		score_tot_now = stats_ref.get_score_total()
		score_vague_now = sv.get("score", score_vague_now)

	lbl_vague.text = "Vague : " + str(vague_id) + " | Cycle : " + str(cycle)
	lbl_temps.text = "Temps : " + _format_secs(temps_total_s) + " | Vague : " + _format_secs(temps_vague_s)
	lbl_vivants.text = "Ennemis vivants : " + str(vivants_now)

	lbl_kills_total.text = "Kills total : " + str(kills_tot_now)
	lbl_score_total.text = "Score total : " + str(score_tot_now)

	lbl_kills_vague.text = "Kills vague : " + str(kills_vague_now)
	lbl_score_vague.text = "Score vague : " + str(score_vague_now)

func _format_secs(t: float) -> String:
	var total_sec: int = int(max(t, 0.0))
	var minutes: int = int(total_sec / 60.0)
	var secondes: int = total_sec % 60
	return str(minutes) + "m " + str(secondes) + "s"

func set_ui_visible(v: bool) -> void:
	ui_visible = v
	visible = v

func get_ui_visible() -> bool:
	return ui_visible

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			set_ui_visible(!ui_visible)

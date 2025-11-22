extends CanvasLayer
class_name StatsDisplayer

@export var ui_visible: bool = true : set = set_ui_visible, get = get_ui_visible
@export var actif: bool = true

@export_node_path("Node") var chemin_stats: NodePath

@export_node_path("Label") var chemin_lbl_vague: NodePath
@export_node_path("Label") var chemin_lbl_temps: NodePath
@export_node_path("Label") var chemin_lbl_vivants: NodePath
@export_node_path("Label") var chemin_lbl_kills_total: NodePath
@export_node_path("Label") var chemin_lbl_score_total: NodePath
@export_node_path("Label") var chemin_lbl_kills_vague: NodePath
@export_node_path("Label") var chemin_lbl_score_vague: NodePath

@onready var stats_ref: StatsVagues = get_node(chemin_stats) as StatsVagues

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
	if not is_instance_valid(stats_ref):
		return

	var sv: Dictionary = stats_ref.get_stats_vague()

	# infos globales
	var vivants_now: int = stats_ref.get_vivants()
	var kills_tot_now: int = stats_ref.get_kills_total()
	var score_tot_now: int = stats_ref.get_score_total()

	# infos de vague
	var vague_id: int = sv.get("index", -1)
	var kills_vague_now: int = sv.get("kills", 0)
	var score_vague_now: int = sv.get("score", 0)

	# durée vague courante
	var duree_s: float = 0.0
	if sv.size() > 0:
		var active: bool = sv.get("active", false)
		var t_debut: float = sv.get("t_debut", 0.0)
		if active:
			# vague en cours
			var t_now: float = float(Time.get_ticks_msec()) * 0.001
			duree_s = max(0.0, t_now - t_debut)
		else:
			# vague finie
			duree_s = sv.get("duree", 0.0)

	# affichage
	lbl_vague.text = "Vague : " + str(vague_id)
	lbl_temps.text = "Temps vague : " + _format_secs(duree_s)
	lbl_vivants.text = "Ennemis vivants : " + str(vivants_now)

	lbl_kills_total.text = "Kills total : " + str(kills_tot_now)
	lbl_score_total.text = "Score total : " + str(score_tot_now)

	lbl_kills_vague.text = "Kills vague : " + str(kills_vague_now)
	lbl_score_vague.text = "Score vague : " + str(score_vague_now)

func _format_secs(t: float) -> String:
	var total_sec: int = int(t)
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

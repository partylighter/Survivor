extends CanvasLayer
class_name DeathScreen

@export var debug_death: bool = false

@export_group("Refs")
@export_node_path("StatsVagues") var chemin_stats_vagues: NodePath
@export_node_path("GestionnaireEnnemis") var chemin_gestionnaire_ennemis: NodePath

var stats_ref: StatsVagues
var ennemis_ref: GestionnaireEnnemis

var rt: RichTextLabel
var _shown: bool = false

func _d(m: String) -> void:
	if debug_death:
		print("[DeathScreen] ", Time.get_ticks_msec(), " ", m)

func _enter_tree() -> void:
	add_to_group("death_screen")

func _ready() -> void:
	hide()
	_resolve_refs(true)
	_ensure_rt()

func _resolve_refs(force: bool=false) -> void:
	if force or stats_ref == null or not is_instance_valid(stats_ref):
		stats_ref = get_node_or_null(chemin_stats_vagues) as StatsVagues
		if stats_ref == null:
			stats_ref = get_tree().get_first_node_in_group("stats_vagues") as StatsVagues

	if force or ennemis_ref == null or not is_instance_valid(ennemis_ref):
		ennemis_ref = get_node_or_null(chemin_gestionnaire_ennemis) as GestionnaireEnnemis
		if ennemis_ref == null:
			ennemis_ref = get_tree().get_first_node_in_group("gestion_ennemis") as GestionnaireEnnemis

	_d("refs stats=" + str(stats_ref) + " valid=" + str(is_instance_valid(stats_ref)) +
		" | ennemis=" + str(ennemis_ref) + " valid=" + str(is_instance_valid(ennemis_ref)))

func _ensure_rt() -> void:
	if rt != null and is_instance_valid(rt):
		return

	rt = RichTextLabel.new()
	rt.name = "DeathRT"
	rt.bbcode_enabled = true
	rt.scroll_active = false
	rt.fit_content = true

	# centré + taille fixe lisible
	rt.anchor_left = 0.5
	rt.anchor_top = 0.5
	rt.anchor_right = 0.5
	rt.anchor_bottom = 0.5
	rt.offset_left = -360
	rt.offset_top = -220
	rt.offset_right = 360
	rt.offset_bottom = 220

	rt.text = "[center][b]GAME OVER[/b][/center]\n\nChargement..."
	add_child(rt)

func show_auto() -> void:
	_d("show_auto called shown=" + str(_shown))
	if _shown:
		return
	_shown = true

	_resolve_refs(false)
	_ensure_rt()
	_remplir_stats()
	show()
	rt.show()

func _remplir_stats() -> void:
	if rt == null or not is_instance_valid(rt):
		_d("ERR rt null")
		return

	var vivants := 0
	var kills_tot := 0
	var score_tot := 0
	var vague_id := -1
	var cycle := 0
	var kills_vague := 0
	var score_vague := 0
	var t_total := 0.0
	var t_vague := 0.0

	if is_instance_valid(stats_ref):
		vivants = stats_ref.get_vivants()
		kills_tot = stats_ref.get_kills_total()
		score_tot = stats_ref.get_score_total()

		var sv: Dictionary = stats_ref.get_stats_vague()
		if not sv.is_empty():
			vague_id = int(sv.get("index", vague_id))
			cycle = int(sv.get("cycle", cycle))
			kills_vague = int(sv.get("kills", kills_vague))
			score_vague = int(sv.get("score", score_vague))

	if is_instance_valid(ennemis_ref):
		t_total = float(ennemis_ref.temps_total_s)
		t_vague = float(ennemis_ref.t_vague)

	_d("VALUES vivants=" + str(vivants) + " kills_tot=" + str(kills_tot) + " score_tot=" + str(score_tot) +
		" vague=" + str(vague_id) + " cycle=" + str(cycle) + " kills_vague=" + str(kills_vague) +
		" score_vague=" + str(score_vague) + " t_total=" + str(t_total) + " t_vague=" + str(t_vague))

	rt.text = ""
	rt.text += "[center][b]GAME OVER[/b][/center]\n\n"
	rt.text += "[b]Vague:[/b] " + str(vague_id) + "   [b]Cycle:[/b] " + str(cycle) + "\n"
	rt.text += "[b]Temps total:[/b] " + _fmt(t_total) + "   [b]Temps vague:[/b] " + _fmt(t_vague) + "\n"
	rt.text += "[b]Ennemis vivants:[/b] " + str(vivants) + "\n\n"
	rt.text += "[b]Kills total:[/b] " + str(kills_tot) + "\n"
	rt.text += "[b]Score total:[/b] " + str(score_tot) + "\n\n"
	rt.text += "[b]Kills vague:[/b] " + str(kills_vague) + "\n"
	rt.text += "[b]Score vague:[/b] " + str(score_vague) + "\n"

func _fmt(t: float) -> String:
	var total: float = max(t, 0.0)
	var m: int = int(total / 60.0)
	var sec: int = int(fmod(total, 60.0))
	return "%dm %02ds" % [m, sec]

func reset_for_restart() -> void:
	_shown = false
	hide()
	if rt and is_instance_valid(rt):
		rt.hide()

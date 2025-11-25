extends CanvasLayer
class_name LootDisplayer

@export var ui_visible: bool = true : set = set_ui_visible, get = get_ui_visible
@export var actif: bool = true

@export_node_path("GestionnaireLoot") var chemin_loot: NodePath
@export var position_loot_ui: Vector2 = Vector2(16, 16)

var loot_ref: GestionnaireLoot
var lbl_loot: Label

func _ready() -> void:
	set_ui_visible(ui_visible)

	loot_ref = get_node_or_null(chemin_loot) as GestionnaireLoot

	lbl_loot = Label.new()
	lbl_loot.name = "LblLoot"
	lbl_loot.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbl_loot.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	lbl_loot.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl_loot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_loot.size_flags_vertical = Control.SIZE_FILL
	lbl_loot.custom_minimum_size = Vector2(260, 150)

	add_child(lbl_loot)

	var c := lbl_loot as Control
	c.set_anchors_preset(Control.PRESET_TOP_LEFT)
	c.position = position_loot_ui


func _process(_dt: float) -> void:
	if not actif:
		return
	if loot_ref == null or not is_instance_valid(loot_ref):
		return
	if lbl_loot == null or not is_instance_valid(lbl_loot):
		return

	var stats: Dictionary = loot_ref.get_stats_loot()
	var lignes: Array[String] = []

	for id in stats.keys():
		var q: int = stats[id]
		lignes.append("%s : %d" % [String(id), q])

	if lignes.is_empty():
		lbl_loot.text = "Aucun loot récupéré"
	else:
		lbl_loot.text = "\n".join(lignes)


func set_ui_visible(v: bool) -> void:
	ui_visible = v
	visible = v

func get_ui_visible() -> bool:
	return ui_visible

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F12:
			set_ui_visible(!ui_visible)

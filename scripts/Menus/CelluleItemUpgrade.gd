extends PanelContainer
class_name CelluleItemUpgrade

@export var id_item: StringName = &""
@export var nom_item: String = ""
@export var quantite: int = 1

@export var debug_drag: bool = false

@onready var lbl_nom: Label = $Colonne/Nom
@onready var lbl_qte: Label = $Colonne/Quantite

func _ready() -> void:
	_rafraichir()

func set_donnees(id: StringName, nom: String, q: int) -> void:
	id_item = id
	nom_item = nom
	quantite = q
	_rafraichir()

func _rafraichir() -> void:
	if lbl_nom:
		lbl_nom.text = nom_item if nom_item != "" else String(id_item)
	if lbl_qte:
		lbl_qte.text = "x" + str(max(quantite, 0))

func _get_drag_data(_pos: Vector2):
	if quantite <= 0 or String(id_item) == "":
		if debug_drag:
			print("[CelluleUpg] drag REFUSE id=", id_item, " q=", quantite)
		return null

	var payload := {
		"id_item": id_item,
		"quantite": quantite,
		"nom_item": nom_item
	}

	var preview := duplicate() as Control
	preview.modulate.a = 0.85
	set_drag_preview(preview)

	if debug_drag:
		print("[CelluleUpg] drag OK ", _resume(payload))

	return payload

func _resume(d: Dictionary) -> String:
	return "{id_item=%s, quantite=%d, nom_item=%s}" % [
		String(d.get("id_item", &"")),
		int(d.get("quantite", -1)),
		String(d.get("nom_item", ""))
	]

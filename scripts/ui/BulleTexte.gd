extends Node2D
class_name BulleTexte

enum TypeBulle { PAROLE, PENSEE }

@export var type_bulle: TypeBulle = TypeBulle.PAROLE
@export_multiline var texte: String = "..."

@onready var panneau: PanelContainer = $Panneau
@onready var label: Label = $Panneau/Marge/Texte
@onready var pointe_parole: Polygon2D = $PointeParole
@onready var points_pensee: Node2D = $PointsPensee

func _ready() -> void:
	actualiser()

func configurer(nouveau_texte: String, nouveau_type: TypeBulle = TypeBulle.PAROLE) -> void:
	texte = nouveau_texte
	type_bulle = nouveau_type
	if is_node_ready():
		actualiser()

func actualiser() -> void:
	label.text = texte
	pointe_parole.visible = type_bulle == TypeBulle.PAROLE
	points_pensee.visible = type_bulle == TypeBulle.PENSEE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, 0.95)
	style.border_color = Color(0.12, 0.12, 0.12, 1.0)
	style.set_border_width_all(2)
	var rayon: int = 18 if type_bulle == TypeBulle.PENSEE else 6
	style.set_corner_radius_all(rayon)
	panneau.add_theme_stylebox_override(&"panel", style)

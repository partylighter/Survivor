extends Node2D
class_name PNJBase

signal dialogue_demande(pnj: PNJBase)

@export var nom_pnj: String = "PNJ"
@export_multiline var texte_proximite: String = "Bonjour."
@export var type_bulle: BulleTexte.TypeBulle = BulleTexte.TypeBulle.PAROLE
@export var action_interagir: StringName = &"interagir"
@export_range(1.0, 2000.0, 1.0) var rayon_interaction_px: float = 220.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var bulle: BulleTexte = $BulleTexte

var joueur: Player = null
var joueur_proche: bool = false
var _rayon_interaction_carre: float = 0.0

func _ready() -> void:
	_rayon_interaction_carre = rayon_interaction_px * rayon_interaction_px
	_trouver_joueur()
	bulle.configurer(texte_proximite, type_bulle)
	bulle.visible = false

func _process(_delta: float) -> void:
	if joueur == null or not is_instance_valid(joueur):
		_trouver_joueur()
		_set_joueur_proche(false)
		return

	var distance_carree: float = global_position.distance_squared_to(joueur.global_position)
	_set_joueur_proche(distance_carree <= _rayon_interaction_carre)

func _unhandled_input(event: InputEvent) -> void:
	if joueur_proche and event.is_action_pressed(action_interagir):
		dialogue_demande.emit(self)
		get_viewport().set_input_as_handled()

func _trouver_joueur() -> void:
	joueur = get_tree().get_first_node_in_group(&"joueur_principal") as Player

func _set_joueur_proche(proche: bool) -> void:
	if joueur_proche == proche:
		return
	joueur_proche = proche
	if proche:
		bulle.configurer(texte_proximite, type_bulle)
	bulle.visible = proche

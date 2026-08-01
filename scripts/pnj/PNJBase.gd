extends Node2D
class_name PNJBase

@export var nom_pnj: String = "PNJ"
@export var identifiant_pnj: StringName = &""
@export var portrait_dialogue: Texture2D
@export var donnee_dialogue: DonneeDialogue
@export_multiline var texte_proximite: String = "Bonjour."
@export var type_bulle: BulleTexte.TypeBulle = BulleTexte.TypeBulle.PAROLE
@export var action_interagir: StringName = &"interagir"

@onready var zone_interaction: Area2D = %ZoneInteraction
@onready var bulle: BulleTexte = %BulleTexte
@onready var anime : AnimatedSprite2D = $AnimatedSprite2D

var joueur_proche: Player = null
var systeme_dialogue: SystemeDialogue = null

func _ready() -> void:
	zone_interaction.body_entered.connect(_quand_corps_entre)
	zone_interaction.body_exited.connect(_quand_corps_sort)
	bulle.configurer(texte_proximite, type_bulle)
	bulle.visible = false
	anime.play("default")

func _unhandled_input(event: InputEvent) -> void:
	if joueur_proche == null:
		return
	if not is_instance_valid(joueur_proche):
		joueur_proche = null
		return
	if not event.is_action_pressed(action_interagir):
		return
	var gestionnaire: SystemeDialogue = _obtenir_systeme_dialogue()
	if gestionnaire == null:
		push_warning("Aucun système de dialogue trouvé.")
		return
	if gestionnaire.est_dialogue_ouvert():
		return
	if donnee_dialogue == null:
		push_warning("Le PNJ %s ne possède aucune donnée de dialogue." % name)
		return
	bulle.visible = false
	gestionnaire.dialogue_ferme.connect(_quand_dialogue_ferme, CONNECT_ONE_SHOT)
	gestionnaire.ouvrir_dialogue(self)
	get_viewport().set_input_as_handled()

func _quand_corps_entre(corps: Node2D) -> void:
	if not corps.is_in_group(&"joueur_principal"):
		return
	var joueur_detecte: Player = corps as Player
	if joueur_detecte == null:
		return
	joueur_proche = joueur_detecte
	bulle.configurer(texte_proximite, type_bulle)
	bulle.visible = true

func _quand_corps_sort(corps: Node2D) -> void:
	if corps != joueur_proche:
		return
	joueur_proche = null
	bulle.visible = false

func _quand_dialogue_ferme() -> void:
	bulle.visible = joueur_proche != null and is_instance_valid(joueur_proche)

func _obtenir_systeme_dialogue() -> SystemeDialogue:
	if systeme_dialogue == null or not is_instance_valid(systeme_dialogue):
		systeme_dialogue = get_tree().get_first_node_in_group(&"systeme_dialogue") as SystemeDialogue
	return systeme_dialogue

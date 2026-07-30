extends Node2D

@onready var systeme_dialogue: SystemeDialogue = $SystemeDialogue

var derniere_action_demandee: StringName = &""
var dernier_resultat_action: ResultatActionDialogue = null

func _ready() -> void:
	systeme_dialogue.action_dialogue_resolue.connect(_quand_action_dialogue_resolue)

func _quand_action_dialogue_resolue(identifiant_action: StringName, _pnj: PNJBase, resultat: ResultatActionDialogue) -> void:
	derniere_action_demandee = identifiant_action
	dernier_resultat_action = resultat

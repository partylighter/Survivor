extends Node
class_name GestionnaireActionsDialogue

var actions_consommees: Dictionary = {}

func _ready() -> void:
	add_to_group(&"gestionnaire_actions_dialogue")

func executer_action(identifiant_action: StringName, pnj_source: PNJBase, joueur_cible: Player) -> ResultatActionDialogue:
	match identifiant_action:
		&"donner_potion":
			return _essayer_donner_potion(pnj_source, joueur_cible)
		_:
			return ResultatActionDialogue.creer(ResultatActionDialogue.Statut.INCONNUE, "Cette action n'est pas disponible.", false)

func _essayer_donner_potion(pnj_source: PNJBase, joueur_cible: Player) -> ResultatActionDialogue:
	if pnj_source == null or not is_instance_valid(pnj_source):
		return ResultatActionDialogue.creer(ResultatActionDialogue.Statut.REFUSEE, "Le PNJ n'est plus disponible.", false)
	if joueur_cible == null or not is_instance_valid(joueur_cible) or joueur_cible.inventaire == null:
		return ResultatActionDialogue.creer(ResultatActionDialogue.Statut.REFUSEE, "L'inventaire du joueur est introuvable.", false)
	if String(pnj_source.identifiant_pnj).is_empty():
		return ResultatActionDialogue.creer(ResultatActionDialogue.Statut.REFUSEE, "Ce PNJ ne possède pas d'identifiant stable.", false)
	var cle_action: StringName = StringName("%s_%s" % [identifiant_action_potion(), pnj_source.identifiant_pnj])
	if actions_consommees.has(cle_action):
		return ResultatActionDialogue.creer(ResultatActionDialogue.Statut.REFUSEE, "Je ne peux rien te donner pour le moment.", false)
	joueur_cible.inventaire.ajouter_objet(&"potion", "Potion", 1)
	actions_consommees[cle_action] = true
	return ResultatActionDialogue.creer(ResultatActionDialogue.Statut.REUSSIE, "Potion reçue.", true)

func identifiant_action_potion() -> StringName:
	return &"donner_potion"

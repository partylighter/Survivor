extends Resource
class_name ChoixDialogue

enum TypeChoix {
	REPONSE,
	ACTION,
	FERMER
}

@export var texte_bouton: String = "Répondre"
@export_multiline var replique_joueur: String = ""
@export_multiline var replique_pnj: String = ""
@export var type_choix: TypeChoix = TypeChoix.REPONSE
@export var identifiant_action: StringName = &""

extends Resource
class_name ChoixDialogue

enum TypeChoix {
	REPONSE,
	ACTION,
	FERMER
}

@export var texte_bouton: String = "Choix"
@export var type_choix: TypeChoix = TypeChoix.REPONSE
@export_multiline var texte_resultat: String = ""
@export var identifiant_action: StringName = &""

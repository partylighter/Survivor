extends Node2D
class_name CoffreMonde

@export_node_path("Area2D") var chemin_zone_interaction: NodePath = NodePath("ZoneInteraction")
@export_node_path("GestionnaireCoffre") var chemin_gestionnaire_coffre: NodePath = NodePath("GestionnaireCoffre")
@export_node_path("InterfaceCoffre") var chemin_interface_coffre: NodePath
@export var action_interagir: StringName = &"interagir"

@onready var zone_interaction: Area2D = get_node_or_null(chemin_zone_interaction) as Area2D
@onready var gestionnaire_coffre: GestionnaireCoffre = get_node_or_null(chemin_gestionnaire_coffre) as GestionnaireCoffre
@onready var interface_coffre: InterfaceCoffre = get_node_or_null(chemin_interface_coffre) as InterfaceCoffre

var joueur_proche: Player

func _ready() -> void:
	if zone_interaction == null:
		push_error("ZoneInteraction introuvable dans CoffreMonde.")
		return
	if gestionnaire_coffre == null:
		push_error("GestionnaireCoffre introuvable dans CoffreMonde.")
		return
	var collision: CollisionShape2D = zone_interaction.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null or collision.shape == null or collision.disabled:
		push_error("La zone du coffre doit posseder une CollisionShape2D active.")
		return
	zone_interaction.body_entered.connect(_quand_corps_entre)
	zone_interaction.body_exited.connect(_quand_corps_sort)
	if not InputMap.has_action(action_interagir):
		push_error("L'action '%s' du coffre n'existe pas." % String(action_interagir))

func _unhandled_input(event: InputEvent) -> void:
	if _dialogue_est_ouvert():
		return
	if joueur_proche == null or not event.is_action_pressed(action_interagir):
		return
	if interface_coffre == null:
		push_error("InterfaceCoffre introuvable. Verifie chemin_interface_coffre.")
		return
	var inventaire: GestionnaireInventaire = joueur_proche.inventaire
	if inventaire == null:
		push_error("Le joueur proche du coffre ne possede pas de GestionnaireInventaire.")
		return
	interface_coffre.ouvrir(self, inventaire)
	get_viewport().set_input_as_handled()

func _dialogue_est_ouvert() -> bool:
	var dialogue: SystemeDialogue = get_tree().get_first_node_in_group(&"systeme_dialogue") as SystemeDialogue
	return dialogue != null and dialogue.est_dialogue_ouvert()

func _quand_corps_entre(corps: Node) -> void:
	if not corps is Player or not corps.is_in_group(&"joueur_principal"):
		return
	joueur_proche = corps as Player
	if interface_coffre != null:
		interface_coffre.afficher_invite(true)

func _quand_corps_sort(corps: Node) -> void:
	if corps != joueur_proche:
		return
	joueur_proche = null
	if interface_coffre != null:
		interface_coffre.afficher_invite(false)
		if interface_coffre.coffre_actuel == self:
			interface_coffre.fermer()

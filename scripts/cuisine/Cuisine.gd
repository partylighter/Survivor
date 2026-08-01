extends Node2D
class_name Cuisine

@export_node_path("Area2D") var chemin_zone_interaction: NodePath = NodePath("ZoneInteraction")
@export_node_path("TableCuisine") var chemin_table_cuisine: NodePath = NodePath("TableCuisine")
@export_node_path("GestionnaireCuisine") var chemin_gestionnaire_cuisine: NodePath = NodePath("GestionnaireCuisine")
@export_node_path("InterfaceCuisine") var chemin_interface_cuisine: NodePath = NodePath("InterfaceCuisine")
@export_node_path("Label") var chemin_invite_interaction: NodePath = NodePath("InviteInteraction")
@export var action_interagir: StringName = &"interagir"

@onready var zone_interaction: Area2D = get_node_or_null(chemin_zone_interaction) as Area2D
@onready var table_cuisine: TableCuisine = get_node_or_null(chemin_table_cuisine) as TableCuisine
@onready var gestionnaire_cuisine: GestionnaireCuisine = get_node_or_null(chemin_gestionnaire_cuisine) as GestionnaireCuisine
@onready var interface_cuisine: InterfaceCuisine = get_node_or_null(chemin_interface_cuisine) as InterfaceCuisine
@onready var invite_interaction: Label = get_node_or_null(chemin_invite_interaction) as Label

var joueur_present: Player

func _ready() -> void:
	if not _configuration_est_valide():
		return
	gestionnaire_cuisine.table_cuisine = table_cuisine
	interface_cuisine.configurer(gestionnaire_cuisine)
	interface_cuisine.interface_fermee.connect(_quand_interface_fermee)
	invite_interaction.hide()
	zone_interaction.body_entered.connect(_quand_corps_entre)
	zone_interaction.body_exited.connect(_quand_corps_sort)

func _unhandled_input(event: InputEvent) -> void:
	if joueur_present == null or interface_cuisine.visible or not event.is_action_pressed(action_interagir):
		return
	interface_cuisine.ouvrir()
	invite_interaction.hide()
	get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	if gestionnaire_cuisine != null and joueur_present != null:
		gestionnaire_cuisine.rendre_tous_les_ingredients()

func _quand_corps_entre(corps: Node) -> void:
	if not corps is Player or joueur_present != null:
		return
	joueur_present = corps as Player
	gestionnaire_cuisine.definir_joueur(joueur_present)
	invite_interaction.show()

func _quand_corps_sort(corps: Node) -> void:
	if corps != joueur_present:
		return
	gestionnaire_cuisine.rendre_tous_les_ingredients()
	invite_interaction.hide()
	gestionnaire_cuisine.retirer_joueur()
	joueur_present = null
	interface_cuisine.fermer()

func _quand_interface_fermee() -> void:
	if joueur_present != null:
		gestionnaire_cuisine.rendre_tous_les_ingredients()
		invite_interaction.show()

func _configuration_est_valide() -> bool:
	if zone_interaction == null:
		push_error("ZoneInteraction introuvable dans Cuisine.")
		return false
	var collision: CollisionShape2D = zone_interaction.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null or collision.shape == null or collision.disabled:
		push_error("ZoneInteraction doit posseder une CollisionShape2D active.")
		return false
	if table_cuisine == null or gestionnaire_cuisine == null or interface_cuisine == null or invite_interaction == null:
		push_error("Un noeud interne de Cuisine est introuvable.")
		return false
	if not InputMap.has_action(action_interagir):
		push_error("L'action '%s' de la cuisine n'existe pas." % String(action_interagir))
		return false
	return true

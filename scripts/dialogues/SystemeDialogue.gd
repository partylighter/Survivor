extends CanvasLayer
class_name SystemeDialogue

signal dialogue_ouvert(pnj: PNJBase)
signal dialogue_ferme
signal action_dialogue_resolue(identifiant_action: StringName, pnj: PNJBase, resultat: ResultatActionDialogue)

@export var scene_bouton_choix: PackedScene

@onready var boite_dialogue: Control = %BoiteDialogue
@onready var boite_choix: Control = %BoiteChoix
@onready var affichage_pnj: Control = %AffichagePNJ
@onready var nom_interlocuteur: Label = %NomInterlocuteur
@onready var texte_dialogue: RichTextLabel = %TexteDialogue
@onready var image_pnj: TextureRect = %ImagePNJ
@onready var bouton_continuer: Button = %BoutonContinuer
@onready var bouton_sortir: Button = %BoutonSortir
@onready var liste_choix: VBoxContainer = %ListeChoix

var pnj_actuel: PNJBase = null
var joueur_actuel: Player = null
var gestionnaire_actions: GestionnaireActionsDialogue = null
var continuer_ferme_dialogue: bool = false
var etats_entrees_bloquees: Array[Dictionary] = []

func _ready() -> void:
	add_to_group(&"systeme_dialogue")
	bouton_continuer.pressed.connect(_quand_bouton_continuer_presse)
	bouton_sortir.pressed.connect(fermer_dialogue)
	_masquer_interface()

func _exit_tree() -> void:
	_deconnecter_pnj_actuel()
	_restaurer_joueur_et_entrees()

func _unhandled_input(event: InputEvent) -> void:
	if not est_dialogue_ouvert():
		return
	if event.is_action_pressed(&"ui_cancel"):
		fermer_dialogue()
		get_viewport().set_input_as_handled()

func est_dialogue_ouvert() -> bool:
	return pnj_actuel != null and is_instance_valid(pnj_actuel)

func ouvrir_dialogue(nouveau_pnj: PNJBase) -> void:
	if nouveau_pnj == null:
		return
	if est_dialogue_ouvert():
		return
	if nouveau_pnj.donnee_dialogue == null:
		push_warning("Le PNJ %s ne possède aucune donnée de dialogue." % nouveau_pnj.name)
		return
	pnj_actuel = nouveau_pnj
	joueur_actuel = pnj_actuel.joueur_proche
	if joueur_actuel == null or not is_instance_valid(joueur_actuel):
		joueur_actuel = get_tree().get_first_node_in_group(&"joueur_principal") as Player
	continuer_ferme_dialogue = false
	pnj_actuel.tree_exiting.connect(_quand_pnj_quitte_arbre, CONNECT_ONE_SHOT)
	_bloquer_joueur_et_entrees()
	nom_interlocuteur.text = pnj_actuel.nom_pnj
	image_pnj.texture = pnj_actuel.portrait_dialogue
	texte_dialogue.text = pnj_actuel.donnee_dialogue.texte_initial
	bouton_continuer.text = "Continuer"
	bouton_continuer.visible = true
	boite_dialogue.visible = true
	boite_choix.visible = false
	affichage_pnj.visible = true
	bouton_continuer.call_deferred(&"grab_focus")
	dialogue_ouvert.emit(pnj_actuel)

func _quand_bouton_continuer_presse() -> void:
	if not est_dialogue_ouvert():
		return
	if continuer_ferme_dialogue:
		fermer_dialogue()
		return
	_afficher_choix()

func _afficher_choix() -> void:
	if not est_dialogue_ouvert():
		return
	_nettoyer_choix()
	var premier_bouton: Button = null
	for choix: ChoixDialogue in pnj_actuel.donnee_dialogue.choix:
		if choix == null:
			continue
		var bouton_choix: Button = _creer_bouton_choix()
		if bouton_choix == null:
			continue
		bouton_choix.text = choix.texte_bouton
		bouton_choix.pressed.connect(_selectionner_choix.bind(choix))
		liste_choix.add_child(bouton_choix)
		if premier_bouton == null:
			premier_bouton = bouton_choix
	bouton_continuer.visible = false
	boite_choix.visible = true
	if premier_bouton != null:
		premier_bouton.call_deferred(&"grab_focus")

func _creer_bouton_choix() -> Button:
	if scene_bouton_choix != null:
		var bouton_instance: Button = scene_bouton_choix.instantiate() as Button
		if bouton_instance == null:
			push_error("La scène de bouton doit avoir un Button comme racine.")
		return bouton_instance
	var bouton: Button = Button.new()
	bouton.custom_minimum_size.y = 42.0
	return bouton

func _selectionner_choix(choix: ChoixDialogue) -> void:
	if choix == null or not est_dialogue_ouvert():
		return
	boite_choix.visible = false
	match choix.type_choix:
		ChoixDialogue.TypeChoix.REPONSE:
			_afficher_resultat(choix.texte_resultat, "Retour aux choix", false)
		ChoixDialogue.TypeChoix.ACTION:
			var resultat: ResultatActionDialogue = _executer_action(choix.identifiant_action)
			action_dialogue_resolue.emit(choix.identifiant_action, pnj_actuel, resultat)
			var texte_bouton: String = "Fermer" if resultat.fermer_ensuite else "Retour aux choix"
			_afficher_resultat(resultat.texte_resultat, texte_bouton, resultat.fermer_ensuite)
		ChoixDialogue.TypeChoix.FERMER:
			fermer_dialogue()

func _afficher_resultat(nouveau_texte: String, texte_bouton: String, fermer_ensuite: bool) -> void:
	texte_dialogue.text = nouveau_texte
	bouton_continuer.text = texte_bouton
	bouton_continuer.visible = true
	continuer_ferme_dialogue = fermer_ensuite
	bouton_continuer.call_deferred(&"grab_focus")

func fermer_dialogue() -> void:
	var dialogue_etait_ouvert: bool = pnj_actuel != null
	if not dialogue_etait_ouvert:
		_masquer_interface()
		_restaurer_joueur_et_entrees()
		return
	_deconnecter_pnj_actuel()
	pnj_actuel = null
	continuer_ferme_dialogue = false
	_nettoyer_choix()
	_masquer_interface()
	_restaurer_joueur_et_entrees()
	dialogue_ferme.emit()

func _nettoyer_choix() -> void:
	for enfant: Node in liste_choix.get_children():
		liste_choix.remove_child(enfant)
		enfant.queue_free()

func _masquer_interface() -> void:
	boite_dialogue.visible = false
	boite_choix.visible = false
	affichage_pnj.visible = false
	bouton_continuer.text = "Continuer"
	bouton_continuer.visible = true

func _executer_action(identifiant_action: StringName) -> ResultatActionDialogue:
	if gestionnaire_actions == null or not is_instance_valid(gestionnaire_actions):
		gestionnaire_actions = get_tree().get_first_node_in_group(&"gestionnaire_actions_dialogue") as GestionnaireActionsDialogue
	if gestionnaire_actions == null:
		return ResultatActionDialogue.creer(ResultatActionDialogue.Statut.INCONNUE, "Aucun gestionnaire d'actions n'est disponible.", false)
	return gestionnaire_actions.executer_action(identifiant_action, pnj_actuel, joueur_actuel)

func _quand_pnj_quitte_arbre() -> void:
	fermer_dialogue()

func _deconnecter_pnj_actuel() -> void:
	if pnj_actuel == null or not is_instance_valid(pnj_actuel):
		return
	if pnj_actuel.tree_exiting.is_connected(_quand_pnj_quitte_arbre):
		pnj_actuel.tree_exiting.disconnect(_quand_pnj_quitte_arbre)

func _bloquer_joueur_et_entrees() -> void:
	etats_entrees_bloquees.clear()
	if joueur_actuel != null and is_instance_valid(joueur_actuel):
		joueur_actuel.definir_dialogue_actif(true)
	for noeud: Node in get_tree().get_nodes_in_group(&"inputs_jeu"):
		if noeud == null or not is_instance_valid(noeud):
			continue
		etats_entrees_bloquees.append({
			"noeud": noeud,
			"processus": noeud.is_processing(),
			"physique": noeud.is_physics_processing(),
			"entree": noeud.is_processing_input(),
			"entree_non_geree": noeud.is_processing_unhandled_input()
		})
		noeud.set_process(false)
		noeud.set_physics_process(false)
		noeud.set_process_input(false)
		noeud.set_process_unhandled_input(false)

func _restaurer_joueur_et_entrees() -> void:
	if joueur_actuel != null and is_instance_valid(joueur_actuel):
		joueur_actuel.definir_dialogue_actif(false)
	joueur_actuel = null
	for etat: Dictionary in etats_entrees_bloquees:
		var noeud: Node = etat.get("noeud") as Node
		if noeud == null or not is_instance_valid(noeud):
			continue
		noeud.set_process(bool(etat.get("processus", false)))
		noeud.set_physics_process(bool(etat.get("physique", false)))
		noeud.set_process_input(bool(etat.get("entree", false)))
		noeud.set_process_unhandled_input(bool(etat.get("entree_non_geree", false)))
	etats_entrees_bloquees.clear()

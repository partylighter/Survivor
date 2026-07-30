extends CanvasLayer
class_name SystemeDialogue

signal dialogue_ouvert(pnj: PNJBase)
signal dialogue_ferme
signal dialogue_commence
signal dialogue_termine
signal action_dialogue_resolue(identifiant_action: StringName, pnj: PNJBase, resultat: ResultatActionDialogue)

enum EtatDialogue {
	FERME,
	PAROLE_PNJ,
	CHOIX,
	PAROLE_JOUEUR,
	RESULTAT_PNJ,
	ATTENTE_FERMETURE
}

@export var scene_bouton_choix: PackedScene

@onready var boite_dialogue_joueur: Control = %BoiteDialogueJoueur
@onready var texte_dialogue_joueur: RichTextLabel = %TexteDialogueJoueur
@onready var nom_joueur: Label = %NomJoueur
@onready var portrait_joueur: TextureRect = %PortraitJoueur
@onready var boite_dialogue_pnj: Control = %BoiteDialoguePNJ
@onready var texte_dialogue_pnj: RichTextLabel = %TexteDialoguePNJ
@onready var nom_pnj: Label = %NomPNJ
@onready var portrait_pnj: TextureRect = %PortraitPNJ
@onready var boite_choix: Control = %BoiteChoix
@onready var liste_choix: VBoxContainer = %ListeChoix
@onready var commandes_dialogue: Control = %CommandesDialogue
@onready var bouton_continuer: Button = %BoutonContinuer
@onready var bouton_sortir: Button = %BoutonSortir

var pnj_actuel: PNJBase = null
var joueur_actuel: Player = null
var gestionnaire_actions: GestionnaireActionsDialogue = null
var etat_dialogue: EtatDialogue = EtatDialogue.FERME
var choix_actuel: ChoixDialogue = null
var etats_entrees_bloquees: Array[Dictionary] = []

func _ready() -> void:
	add_to_group(&"systeme_dialogue")
	bouton_continuer.pressed.connect(_quand_bouton_continuer_presse)
	bouton_sortir.pressed.connect(fermer_dialogue)
	_masquer_interface()

func _exit_tree() -> void:
	if est_dialogue_ouvert():
		dialogue_termine.emit()
	_deconnecter_pnj_actuel()
	_restaurer_joueur_et_entrees()

func _unhandled_input(event: InputEvent) -> void:
	if not est_dialogue_ouvert():
		return
	if event.is_action_pressed(&"ui_cancel"):
		fermer_dialogue()
		get_viewport().set_input_as_handled()

func est_dialogue_ouvert() -> bool:
	return etat_dialogue != EtatDialogue.FERME and pnj_actuel != null and is_instance_valid(pnj_actuel)

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
	choix_actuel = null
	pnj_actuel.tree_exiting.connect(_quand_pnj_quitte_arbre, CONNECT_ONE_SHOT)
	_bloquer_joueur_et_entrees()
	nom_pnj.text = pnj_actuel.nom_pnj
	portrait_pnj.texture = pnj_actuel.portrait_dialogue
	if joueur_actuel != null and is_instance_valid(joueur_actuel):
		nom_joueur.text = joueur_actuel.nom_dialogue
		portrait_joueur.texture = joueur_actuel.portrait_dialogue
	else:
		nom_joueur.text = "Joueur"
		portrait_joueur.texture = null
	_afficher_parole_pnj_initiale()
	dialogue_commence.emit()
	dialogue_ouvert.emit(pnj_actuel)

func _quand_bouton_continuer_presse() -> void:
	match etat_dialogue:
		EtatDialogue.PAROLE_PNJ:
			_afficher_choix()
		EtatDialogue.PAROLE_JOUEUR:
			_traiter_choix_apres_replique_joueur()
		EtatDialogue.RESULTAT_PNJ:
			_afficher_choix()
		EtatDialogue.ATTENTE_FERMETURE:
			fermer_dialogue()
		_:
			pass

func _afficher_parole_pnj_initiale() -> void:
	_masquer_toutes_les_boites()
	texte_dialogue_pnj.text = pnj_actuel.donnee_dialogue.texte_initial
	boite_dialogue_pnj.visible = true
	commandes_dialogue.visible = true
	bouton_continuer.text = "Continuer"
	bouton_continuer.visible = true
	bouton_sortir.visible = true
	etat_dialogue = EtatDialogue.PAROLE_PNJ
	bouton_continuer.call_deferred(&"grab_focus")

func _afficher_choix() -> void:
	if not est_dialogue_ouvert():
		return
	choix_actuel = null
	_nettoyer_choix()
	_masquer_toutes_les_boites()
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
	boite_choix.visible = true
	commandes_dialogue.visible = true
	bouton_continuer.visible = false
	bouton_sortir.visible = true
	etat_dialogue = EtatDialogue.CHOIX
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
	choix_actuel = choix
	boite_choix.visible = false
	if choix.type_choix == ChoixDialogue.TypeChoix.FERMER:
		fermer_dialogue()
		return
	if choix.replique_joueur.is_empty():
		_traiter_choix_apres_replique_joueur()
		return
	_afficher_replique_joueur(choix.replique_joueur)

func _afficher_replique_joueur(texte: String) -> void:
	_masquer_toutes_les_boites()
	texte_dialogue_joueur.text = texte
	boite_dialogue_joueur.visible = true
	commandes_dialogue.visible = true
	bouton_continuer.text = "Continuer"
	bouton_continuer.visible = true
	bouton_sortir.visible = true
	etat_dialogue = EtatDialogue.PAROLE_JOUEUR
	bouton_continuer.call_deferred(&"grab_focus")

func _traiter_choix_apres_replique_joueur() -> void:
	if choix_actuel == null:
		fermer_dialogue()
		return
	var choix_traite: ChoixDialogue = choix_actuel
	choix_actuel = null
	match choix_traite.type_choix:
		ChoixDialogue.TypeChoix.REPONSE:
			_afficher_resultat_pnj(choix_traite.replique_pnj, false)
		ChoixDialogue.TypeChoix.ACTION:
			var resultat: ResultatActionDialogue = _executer_action(choix_traite.identifiant_action)
			action_dialogue_resolue.emit(choix_traite.identifiant_action, pnj_actuel, resultat)
			_afficher_resultat_pnj(resultat.texte_resultat, resultat.fermer_ensuite)
		ChoixDialogue.TypeChoix.FERMER:
			fermer_dialogue()

func _afficher_resultat_pnj(texte: String, fermer_ensuite: bool) -> void:
	_masquer_toutes_les_boites()
	texte_dialogue_pnj.text = texte
	boite_dialogue_pnj.visible = true
	commandes_dialogue.visible = true
	bouton_continuer.visible = true
	bouton_sortir.visible = true
	if fermer_ensuite:
		bouton_continuer.text = "Fermer"
		etat_dialogue = EtatDialogue.ATTENTE_FERMETURE
	else:
		bouton_continuer.text = "Retour aux choix"
		etat_dialogue = EtatDialogue.RESULTAT_PNJ
	bouton_continuer.call_deferred(&"grab_focus")

func fermer_dialogue() -> void:
	var dialogue_etait_ouvert: bool = pnj_actuel != null
	if not dialogue_etait_ouvert:
		_masquer_interface()
		_restaurer_joueur_et_entrees()
		return
	_deconnecter_pnj_actuel()
	pnj_actuel = null
	choix_actuel = null
	etat_dialogue = EtatDialogue.FERME
	_nettoyer_choix()
	_masquer_interface()
	_restaurer_joueur_et_entrees()
	dialogue_termine.emit()
	dialogue_ferme.emit()

func _nettoyer_choix() -> void:
	for enfant: Node in liste_choix.get_children():
		liste_choix.remove_child(enfant)
		enfant.queue_free()

func _masquer_toutes_les_boites() -> void:
	boite_dialogue_joueur.visible = false
	boite_dialogue_pnj.visible = false
	boite_choix.visible = false

func _masquer_interface() -> void:
	_masquer_toutes_les_boites()
	commandes_dialogue.visible = false
	bouton_continuer.text = "Continuer"
	bouton_continuer.visible = true
	bouton_sortir.visible = true
	etat_dialogue = EtatDialogue.FERME

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

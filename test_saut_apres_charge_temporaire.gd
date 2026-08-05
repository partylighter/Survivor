extends SceneTree

const SCENE_JOUEUR: PackedScene = preload("res://scenes/joueur/archere/archere.tscn")
const SCENE_ENNEMI_C: PackedScene = preload("res://scenes/ennemis/enemy_c_test_heritage_de_script.tscn")

var _nombre_deplacements_multicellules: int = 0

func _initialize() -> void:
	call_deferred("_executer_test")

func _executer_test() -> void:
	var joueur := SCENE_JOUEUR.instantiate() as Player
	joueur.global_position = Vector2.ZERO
	root.add_child(joueur)
	await process_frame
	var gestionnaire := joueur.get_node("GestionnaireGrilleCombat") as GestionnaireGrilleCombat
	var deplacement_joueur := joueur.get_node("GestionDeplacementGrilleJoueur") as GestionDeplacementGrilleJoueur
	var ennemi := SCENE_ENNEMI_C.instantiate() as Enemy
	var deplacement_ennemi := ennemi.get_node("DeplacementGrilleEnnemi") as DeplacementGrilleEnnemi
	deplacement_ennemi.cellule_ennemi_quittee.connect(_sur_cellule_ennemi_quittee.bind(deplacement_ennemi))
	ennemi.global_position = gestionnaire.cellule_vers_monde(Vector2i(-5, 0))
	ennemi.definir_cible_joueur(joueur)
	root.add_child(ennemi)
	await process_frame
	var recul_joueur_demarre: bool = false
	var pousse_ennemi_max: float = 0.0
	var ecart_cellules_max: int = 0
	var reprise_pas_normaux: bool = false
	for _index in range(500):
		await physics_frame
		if deplacement_joueur.est_en_deplacement() and not recul_joueur_demarre:
			recul_joueur_demarre = true
			print("DEBUT_RECUL image=", _index, " position_ennemi=", ennemi.global_position, " cellule_logique=", deplacement_ennemi.obtenir_cellule_actuelle())
		if recul_joueur_demarre:
			pousse_ennemi_max = maxf(pousse_ennemi_max, ennemi.pousse.length())
			var cellule_reelle: Vector2i = gestionnaire.monde_vers_cellule(ennemi.global_position)
			var cellule_logique: Vector2i = deplacement_ennemi.obtenir_cellule_actuelle()
			reprise_pas_normaux = reprise_pas_normaux or cellule_logique != Vector2i.ZERO
			var ecart_cellules: int = absi(cellule_reelle.x - cellule_logique.x) + absi(cellule_reelle.y - cellule_logique.y)
			if ecart_cellules > ecart_cellules_max:
				ecart_cellules_max = ecart_cellules
				print("ECART image=", _index, " reel=", cellule_reelle, " logique=", cellule_logique, " position=", ennemi.global_position, " pousse=", ennemi.pousse.length(), " en_deplacement=", deplacement_ennemi.est_en_deplacement())
	var test_reussi: bool = recul_joueur_demarre and reprise_pas_normaux and _nombre_deplacements_multicellules == 1 and ecart_cellules_max <= 1
	print("TEST_REPRISE_APRES_CHARGE recul_joueur=", recul_joueur_demarre, " pas_normaux=", reprise_pas_normaux, " charges=", _nombre_deplacements_multicellules, " ecart_cellules_max=", ecart_cellules_max)
	quit(0 if test_reussi else 1)

func _sur_cellule_ennemi_quittee(_ennemi: Enemy, cellule_depart: Vector2i, deplacement: DeplacementGrilleEnnemi) -> void:
	var destination: Vector2i = deplacement.obtenir_cellule_cible()
	var distance: int = absi(destination.x - cellule_depart.x) + absi(destination.y - cellule_depart.y)
	if distance > 1:
		_nombre_deplacements_multicellules += 1

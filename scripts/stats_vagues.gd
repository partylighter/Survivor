extends Node
class_name StatsVagues

@export var debug_actif: bool = false
@export_node_path("Node") var chemin_manager: NodePath
@onready var manager: GestionnaireEnnemis = get_node(chemin_manager) as GestionnaireEnnemis

var historique: Array = []                   # liste des vagues finies

var stats_vague: Dictionary = {}             # stats de la vague en cours
var kills_total: int = 0                     # ennemis tués au total
var score_total: int = 0                     # score total cumulé
var vivants: int = 0                         # ennemis encore en vie

var par_type_global: Dictionary = {}         # { "C": {"kills": X, "score": Y}, ... }
var morts_joueur_global: Dictionary = {}     # { "C": nb de fois joueur tué par type }

func _d(msg: String) -> void:
	if debug_actif:
		print("[StatsVagues]", Time.get_ticks_msec(), msg)

func _ready() -> void:
	if not is_instance_valid(manager):
		push_warning("chemin_manager invalide")
		return

	manager.ennemi_cree.connect(_on_ennemi_cree)
	manager.ennemi_tue.connect(_on_ennemi_tue)

	_start_vague_si_besoin()

func _process(_dt: float) -> void:
	if not is_instance_valid(manager):
		return

	# début de nouvelle vague détecté
	if not manager.en_interlude:
		if stats_vague.is_empty() \
		or stats_vague.get("index", -1) != manager.i_vague \
		or not stats_vague.get("active", false):
			_debut_vague()
	else:
		# fin de vague détectée
		if not stats_vague.is_empty() and stats_vague.get("active", false):
			_fin_vague()

func _start_vague_si_besoin() -> void:
	if is_instance_valid(manager) and not manager.en_interlude:
		_debut_vague()

func _debut_vague() -> void:
	stats_vague = {
		"index": manager.i_vague,                      # numéro de vague
		"cycle": manager.cycle_vagues,                 # cycle de boucle si vagues infinies
		"t_debut": float(Time.get_ticks_msec()) * 0.001,
		"t_fin": 0.0,
		"duree": 0.0,

		"spawns": 0,                                   # ennemis apparus dans cette vague
		"kills": 0,                                    # ennemis tués dans cette vague
		"score": 0,                                    # score gagné dans cette vague

		"kills_par_type": {},                          # "C": combien tués de ce type
		"score_par_type": {},                          # "C": score gagné via ce type
		"morts_joueur_par_type": {},                   # "C": joueur tué par ce type

		"active": true,
	}
	_d("DEBUT VAGUE index=" + str(stats_vague["index"]) + " cycle=" + str(stats_vague["cycle"]))

func _fin_vague() -> void:
	stats_vague["t_fin"] = float(Time.get_ticks_msec()) * 0.001
	stats_vague["duree"] = stats_vague["t_fin"] - stats_vague["t_debut"]
	stats_vague["active"] = false

	historique.append(stats_vague.duplicate(true))
	_d("FIN VAGUE index=" + str(stats_vague["index"]) + " duree=" + str(stats_vague["duree"]))

func _on_ennemi_cree(e: Node2D) -> void:
	vivants += 1
	if stats_vague.get("active", false):
		stats_vague["spawns"] += 1

func _on_ennemi_tue(e: Node2D) -> void:
	vivants = max(0, vivants - 1)
	kills_total += 1

	var type_nom := "INCONNU"
	var score_e: int = 0

	if e is Enemy:
		var en := e as Enemy
		type_nom = str(en.get_type_nom())
		score_e = en.get_score()

	score_total += score_e

	# global par type
	if not par_type_global.has(type_nom):
		par_type_global[type_nom] = {"kills": 0, "score": 0}
	var bloc: Dictionary = par_type_global[type_nom]
	bloc["kills"] = int(bloc["kills"]) + 1
	bloc["score"] = int(bloc["score"]) + score_e
	par_type_global[type_nom] = bloc

	# vague en cours
	if stats_vague.get("active", false):
		stats_vague["kills"] += 1
		stats_vague["score"] += score_e

		var kpt: Dictionary = stats_vague["kills_par_type"]
		kpt[type_nom] = kpt.get(type_nom, 0) + 1
		stats_vague["kills_par_type"] = kpt

		var spt: Dictionary = stats_vague["score_par_type"]
		spt[type_nom] = spt.get(type_nom, 0) + score_e
		stats_vague["score_par_type"] = spt

	_d("ENNEMI TUE type=" + type_nom + " score=" + str(score_e))

# appel manuel quand le joueur meurt tué par un ennemi e
func ajouter_mort_joueur(e: Node2D) -> void:
	var type_nom := "INCONNU"
	if e is Enemy:
		type_nom = str((e as Enemy).get_type_nom())

	morts_joueur_global[type_nom] = morts_joueur_global.get(type_nom, 0) + 1

	if stats_vague.get("active", false):
		var mj: Dictionary = stats_vague["morts_joueur_par_type"]
		mj[type_nom] = mj.get(type_nom, 0) + 1
		stats_vague["morts_joueur_par_type"] = mj

	_d("JOUEUR MORT PAR type=" + type_nom)

func get_kills_total() -> int:
	return kills_total

func get_score_total() -> int:
	return score_total

func get_vivants() -> int:
	return vivants

func get_global_par_type() -> Dictionary:
	return par_type_global

func get_stats_vague() -> Dictionary:
	return stats_vague

func get_historique() -> Array:
	return historique

extends Node
class_name GestionnaireCoffre

signal contenu_change

@export_range(1, 99, 1) var nombre_emplacements: int = 27
@export_range(1, 999, 1) var quantite_maximale_par_pile: int = 99
@export var contenu_initial: Array[ContenuInitialCoffre] = []

var emplacements: Array[Dictionary] = []

func _ready() -> void:
	_initialiser_emplacements()
	_ajouter_contenu_initial()

func _ajouter_contenu_initial() -> void:
	for entree: ContenuInitialCoffre in contenu_initial:
		if entree == null:
			continue
		if entree.est_equipement():
			for _numero_exemplaire: int in entree.quantite:
				var equipement: Dictionary = entree.obtenir_objet()
				if not equipement.is_empty():
					ajouter_automatiquement(equipement, 1)
			continue
		var objet: Dictionary = entree.obtenir_objet()
		if objet.is_empty():
			continue
		ajouter_automatiquement(objet, entree.quantite)

func _initialiser_emplacements() -> void:
	if emplacements.size() == nombre_emplacements:
		return
	emplacements.clear()
	for index: int in nombre_emplacements:
		emplacements.append({})

func obtenir_emplacement(index_emplacement: int) -> Dictionary:
	if not _index_valide(index_emplacement):
		return {}
	return emplacements[index_emplacement].duplicate(true)

func obtenir_emplacements() -> Array[Dictionary]:
	var copie: Array[Dictionary] = []
	for emplacement: Dictionary in emplacements:
		copie.append(emplacement.duplicate(true))
	return copie

func obtenir_capacite_emplacement(index_emplacement: int, objet: Dictionary) -> int:
	if not _index_valide(index_emplacement):
		return 0
	var objet_normalise: Dictionary = _normaliser_objet(objet)
	if objet_normalise.is_empty():
		return 0
	var contenu: Dictionary = emplacements[index_emplacement]
	if contenu.is_empty():
		return 1 if _est_equipement_unique(objet_normalise) else quantite_maximale_par_pile
	if not _piles_compatibles(contenu, objet_normalise):
		return 0
	return maxi(quantite_maximale_par_pile - int(contenu.get("quantite", 0)), 0)

func obtenir_capacite_totale(objet: Dictionary) -> int:
	var objet_normalise: Dictionary = _normaliser_objet(objet)
	if objet_normalise.is_empty():
		return 0
	if _est_equipement_unique(objet_normalise):
		for emplacement: Dictionary in emplacements:
			if emplacement.is_empty():
				return 1
		return 0
	var capacite: int = 0
	for emplacement: Dictionary in emplacements:
		if emplacement.is_empty():
			capacite += quantite_maximale_par_pile
		elif _piles_compatibles(emplacement, objet_normalise):
			capacite += maxi(quantite_maximale_par_pile - int(emplacement.get("quantite", 0)), 0)
	return capacite

func ajouter_dans_emplacement(index_emplacement: int, objet: Dictionary, quantite: int) -> int:
	var quantite_acceptee: int = mini(maxi(quantite, 0), obtenir_capacite_emplacement(index_emplacement, objet))
	if quantite_acceptee <= 0:
		return 0
	var objet_normalise: Dictionary = _normaliser_objet(objet)
	var contenu: Dictionary = emplacements[index_emplacement]
	if contenu.is_empty():
		objet_normalise["quantite"] = quantite_acceptee
		emplacements[index_emplacement] = objet_normalise
	else:
		contenu["quantite"] = int(contenu.get("quantite", 0)) + quantite_acceptee
		emplacements[index_emplacement] = contenu
	contenu_change.emit()
	return quantite_acceptee

func ajouter_automatiquement(objet: Dictionary, quantite: int) -> int:
	var objet_normalise: Dictionary = _normaliser_objet(objet)
	var quantite_restante: int = mini(maxi(quantite, 0), obtenir_capacite_totale(objet_normalise))
	if objet_normalise.is_empty() or quantite_restante <= 0:
		return 0
	var quantite_initiale: int = quantite_restante
	if not _est_equipement_unique(objet_normalise):
		for index: int in emplacements.size():
			if quantite_restante <= 0:
				break
			var contenu: Dictionary = emplacements[index]
			if not _piles_compatibles(contenu, objet_normalise):
				continue
			var quantite_ajoutee_pile_existante: int = mini(quantite_restante, quantite_maximale_par_pile - int(contenu.get("quantite", 0)))
			contenu["quantite"] = int(contenu.get("quantite", 0)) + quantite_ajoutee_pile_existante
			emplacements[index] = contenu
			quantite_restante -= quantite_ajoutee_pile_existante
	for index: int in emplacements.size():
		if quantite_restante <= 0:
			break
		if not emplacements[index].is_empty():
			continue
		var quantite_nouvelle_pile: int = 1 if _est_equipement_unique(objet_normalise) else mini(quantite_restante, quantite_maximale_par_pile)
		var nouvelle_pile: Dictionary = objet_normalise.duplicate(true)
		nouvelle_pile["quantite"] = quantite_nouvelle_pile
		emplacements[index] = nouvelle_pile
		quantite_restante -= quantite_nouvelle_pile
	var quantite_totale_ajoutee: int = quantite_initiale - quantite_restante
	if quantite_totale_ajoutee > 0:
		contenu_change.emit()
	return quantite_totale_ajoutee

func retirer_emplacement(index_emplacement: int, quantite: int = -1) -> Dictionary:
	if not _index_valide(index_emplacement) or emplacements[index_emplacement].is_empty():
		return {}
	var contenu: Dictionary = emplacements[index_emplacement]
	var quantite_disponible: int = int(contenu.get("quantite", 0))
	var quantite_retiree: int = quantite_disponible if quantite < 0 else mini(maxi(quantite, 0), quantite_disponible)
	if quantite_retiree <= 0:
		return {}
	var objet_retire: Dictionary = contenu.duplicate(true)
	objet_retire["quantite"] = quantite_retiree
	if quantite_retiree >= quantite_disponible:
		emplacements[index_emplacement] = {}
	else:
		contenu["quantite"] = quantite_disponible - quantite_retiree
		emplacements[index_emplacement] = contenu
	contenu_change.emit()
	return objet_retire

func deplacer_emplacement(index_source: int, index_destination: int) -> bool:
	if not _index_valide(index_source) or not _index_valide(index_destination) or index_source == index_destination:
		return false
	var source: Dictionary = emplacements[index_source]
	if source.is_empty():
		return false
	var destination: Dictionary = emplacements[index_destination]
	if destination.is_empty():
		emplacements[index_destination] = source
		emplacements[index_source] = {}
	elif _piles_compatibles(source, destination):
		var quantite_deplacee: int = mini(int(source.get("quantite", 0)), quantite_maximale_par_pile - int(destination.get("quantite", 0)))
		if quantite_deplacee <= 0:
			return false
		destination["quantite"] = int(destination.get("quantite", 0)) + quantite_deplacee
		source["quantite"] = int(source.get("quantite", 0)) - quantite_deplacee
		emplacements[index_destination] = destination
		emplacements[index_source] = {} if int(source.get("quantite", 0)) <= 0 else source
	else:
		emplacements[index_destination] = source
		emplacements[index_source] = destination
	contenu_change.emit()
	return true

func _normaliser_objet(objet: Dictionary) -> Dictionary:
	var identifiant: StringName = objet.get("identifiant", objet.get("id", objet.get("item_id", &"")))
	if String(identifiant) == "":
		return {}
	return {
		"identifiant": identifiant,
		"nom": String(objet.get("nom", objet.get("nom_affiche", identifiant))),
		"icone": objet.get("icone", null),
		"quantite": maxi(int(objet.get("quantite", 1)), 1),
		"type_item": int(objet.get("type_item", -1)),
		"type_loot": int(objet.get("type_loot", -1)),
		"scene": objet.get("scene", null),
		"donnees": Dictionary(objet.get("donnees", {})).duplicate(true)
	}

func _piles_compatibles(premiere: Dictionary, deuxieme: Dictionary) -> bool:
	if premiere.is_empty() or deuxieme.is_empty() or _est_equipement_unique(premiere) or _est_equipement_unique(deuxieme):
		return false
	return premiere.get("identifiant", &"") == deuxieme.get("identifiant", &"") and int(premiere.get("type_item", -1)) == int(deuxieme.get("type_item", -1)) and Dictionary(premiere.get("donnees", {})) == Dictionary(deuxieme.get("donnees", {}))

func _est_equipement_unique(objet: Dictionary) -> bool:
	var donnees: Dictionary = objet.get("donnees", {})
	return int(objet.get("type_item", -1)) == Loot.TypeItem.EQUIPEMENT and String(donnees.get("identifiant_instance", &"")) != ""

func _index_valide(index_emplacement: int) -> bool:
	return index_emplacement >= 0 and index_emplacement < emplacements.size()

extends Node
class_name GestionnaireRecettesAssemblage

@export var recettes_disponibles: Array[RecetteEquipement] = []
@export var catalogue_recettes: CatalogueRecettesEquipement

func trouver_recette(table: TableForge) -> RecetteEquipement:
	if table == null:
		return null
	for recette: RecetteEquipement in obtenir_recettes_disponibles():
		if recette == null or not recette.est_valide():
			continue
		if _motif_correspond(recette, table, false):
			return recette
		if recette.autoriser_miroir and _motif_correspond(recette, table, true):
			return recette
	return null

func obtenir_recettes_disponibles() -> Array[RecetteEquipement]:
	return catalogue_recettes.recettes if catalogue_recettes != null else recettes_disponibles

func _motif_correspond(recette: RecetteEquipement, table: TableForge, miroir: bool) -> bool:
	var nombre_decalages_x: int = TableForge.LARGEUR_GRILLE - recette.largeur_motif + 1 if recette.autoriser_decalage else 1
	var nombre_decalages_y: int = TableForge.HAUTEUR_GRILLE - recette.hauteur_motif + 1 if recette.autoriser_decalage else 1
	for decalage_y: int in nombre_decalages_y:
		for decalage_x: int in nombre_decalages_x:
			if _correspond_au_decalage(recette, table, decalage_x, decalage_y, miroir):
				return true
	return false

func _correspond_au_decalage(recette: RecetteEquipement, table: TableForge, decalage_x: int, decalage_y: int, miroir: bool) -> bool:
	for y: int in TableForge.HAUTEUR_GRILLE:
		for x: int in TableForge.LARGEUR_GRILLE:
			var composant_attendu: LootItemEntry
			var dans_motif: bool = x >= decalage_x and x < decalage_x + recette.largeur_motif and y >= decalage_y and y < decalage_y + recette.hauteur_motif
			if dans_motif:
				var x_local: int = x - decalage_x
				var y_local: int = y - decalage_y
				var x_motif: int = recette.largeur_motif - 1 - x_local if miroir else x_local
				composant_attendu = recette.motif[y_local * recette.largeur_motif + x_motif]
			var objet_present: Dictionary = table.obtenir_objet_du_slot(y * TableForge.LARGEUR_GRILLE + x)
			var identifiant_present: StringName = objet_present.get("identifiant", &"")
			var identifiant_attendu: StringName = composant_attendu.item_id if composant_attendu != null else &""
			if identifiant_present != identifiant_attendu:
				return false
	return true

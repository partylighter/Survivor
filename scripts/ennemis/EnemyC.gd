extends Enemy
class_name EnemyC

@onready var deplacement_grille_ennemi: DeplacementGrilleEnnemi = get_node_or_null("DeplacementGrilleEnnemi") as DeplacementGrilleEnnemi

func _ready() -> void:
	super()
	type_ennemi = TypeEnnemi.C
	actualiser_mode_deplacement_grille()

func reactiver_apres_pool() -> void:
	super()
	actualiser_mode_deplacement_grille()

func set_combat_state(actif_moteur: bool, collision_joueur: bool) -> void:
	super(actif_moteur, collision_joueur)
	actualiser_activation_deplacement_grille(actif_moteur)

func set_poussee_foule(_poussee: Vector2) -> void:
	pass

func actualiser_activation_deplacement_grille(actif: bool) -> void:
	if deplacement_grille_ennemi == null:
		deplacement_grille_ennemi = get_node_or_null("DeplacementGrilleEnnemi") as DeplacementGrilleEnnemi
	if deplacement_grille_ennemi == null:
		return
	if actif and deplacement_grille_ennemi.est_actif_pour(self):
		deplacement_grille_ennemi.activer(self)
	else:
		deplacement_grille_ennemi.desactiver(self)

func actualiser_mode_deplacement_grille() -> void:
	actualiser_activation_deplacement_grille(is_physics_processing() and is_alive())

func _appliquer_deplacement(dt: float) -> void:
	if _state == State.DYING or _state == State.DEAD:
		velocity = Vector2.ZERO
		return
	if deplacement_grille_ennemi == null:
		velocity = Vector2.ZERO
		return
	if deplacement_grille_ennemi.traiter(self, target, dt, _state == State.ALIVE):
		return
	velocity = Vector2.ZERO

func _on_mort() -> void:
	if deplacement_grille_ennemi != null:
		deplacement_grille_ennemi.desactiver(self)
	super()

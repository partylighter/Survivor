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

func actualiser_activation_deplacement_grille(actif: bool) -> void:
	if deplacement_grille_ennemi == null:
		deplacement_grille_ennemi = get_node_or_null("DeplacementGrilleEnnemi") as DeplacementGrilleEnnemi
	var grille_active: bool = actif and deplacement_grille_ennemi != null and deplacement_grille_ennemi.est_actif_pour(self)
	if contact_damage != null:
		contact_damage.set_physics_process(actif and not grille_active)
	if deplacement_grille_ennemi == null:
		return
	if grille_active:
		deplacement_grille_ennemi.activer(self)
	else:
		deplacement_grille_ennemi.desactiver(self)

func actualiser_mode_deplacement_grille() -> void:
	actualiser_activation_deplacement_grille(is_physics_processing() and is_alive())

func _tick_ia_alterne(dt: float) -> void:
	_mettre_a_jour_etat_recul_grille(dt)

func _mettre_a_jour_etat_recul_grille(dt: float) -> void:
	_recul_lock_t = maxf(_recul_lock_t - dt, 0.0)
	_pousse_lock_t = maxf(_pousse_lock_t - dt, 0.0)
	var seuil_recul: float = maxf(recul_seuil_blocage_px, 1.0)
	var seuil_pousse: float = maxf(pousse_seuil_blocage_px, 1.0)
	var recul_actif: bool = recul_bloque_chase and (
		_recul_lock_t > 0.0 or recul.length_squared() >= seuil_recul * seuil_recul)
	var pousse_active: bool = _pousse_lock_t > 0.0 or pousse.length_squared() >= seuil_pousse * seuil_pousse
	var bloc_actif: bool = recul_actif or pousse_active
	_bloc_actif_prev = bloc_actif
	_vel_mouvement = Vector2.ZERO
	if bloc_actif:
		if _state == State.ALIVE:
			_state = State.STUNNED
	elif _state == State.STUNNED:
		_state = State.ALIVE

func _maj_base_vel(_dt: float) -> void:
	pass

func _bloquer_entree_base(_dt: float) -> void:
	pass

func _appliquer_deplacement(dt: float) -> void:
	_vel_mouvement = Vector2.ZERO
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

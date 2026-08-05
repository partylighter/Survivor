extends CharacterBody2D
class_name Enemy

signal mort
signal reapparu
signal pret_pour_pool

# ---------------------------------------------------------------------------
# Types
# ---------------------------------------------------------------------------

enum TypeEnnemi { C, B, A, S, BOSS }

enum State {
	ALIVE,    # IA active, peut être blessé
	STUNNED,  # recul / bousculade bloque la chasse (transitoire)
	DYING,    # mort déclenchée, délai avant pool
	DEAD      # hors jeu, en attente de réactivation
}

# ---------------------------------------------------------------------------
# Exports — Type & Score
# ---------------------------------------------------------------------------

@export_group("Type")
@export_enum("C","B","A","S","BOSS") var type_ennemi: int = TypeEnnemi.C
@export var valeur_score: int = 10

# ---------------------------------------------------------------------------
# Exports — Références
# ---------------------------------------------------------------------------

@export_group("Refs")
@export_node_path("Node")     var chemin_sante:  NodePath
@export_node_path("Sprite2D") var chemin_sprite: NodePath = NodePath()

# ---------------------------------------------------------------------------
# Exports — Collision
# ---------------------------------------------------------------------------

@export_group("Collision")
@export var rayon_collision_px: float = 14.0
@export var poids_collision:    float = 1.0

# ---------------------------------------------------------------------------
# Exports — Impact
# ---------------------------------------------------------------------------

@export_group("Impact")
@export var recul_force_par_degats:      float = 18.0
@export var recul_force_min:             float = 0.0
@export var recul_force_max:             float = 220.0
@export var recul_amorti:                float = 18.0
@export var recul_max:                   float = 500.0
@export var recul_bloque_chase:          bool  = true
@export var recul_bloque_chase_duree_s:  float = 0.12
@export var recul_seuil_blocage_px:      float = 8.0
@export var pousse_amorti:               float = 26.0
@export var pousse_max:                  float = 260.0
@export var pousse_bloque_chase_duree_s: float = 0.07
@export var pousse_seuil_blocage_px:     float = 14.0
@export var resistance_knockback_dash:   float = 0.0
@export var recul_knockback_dash_mult:   float = 1.0

# ---------------------------------------------------------------------------
# Exports — Effets visuels
# ---------------------------------------------------------------------------

@export_group("Effets visuels")
@export var secousse_force_px:      float   = 4.0
@export var secousse_duree_s:       float   = 0.12
@export var secousse_scale_impulse: Vector2 = Vector2(0.22, -0.18)
@export var secousse_scale_spring:  float   = 120.0
@export var secousse_scale_damping: float   = 18.0
@export var secousse_scale_max:     float   = 0.35
@export var flash_couleur:          Color   = Color(2.0, 0.5, 0.5)
@export var flash_duree_s:          float   = 0.08

# ---------------------------------------------------------------------------
# Exports — Mort / pool
# ---------------------------------------------------------------------------

@export_group("Mort")
@export var mort_delai_pool_s: float = 0.18
@export var recul_amorti_mort: float = 8.0

# ---------------------------------------------------------------------------
# État interne
# ---------------------------------------------------------------------------

var _state: State = State.ALIVE

# Recul & bousculade
var recul:          Vector2 = Vector2.ZERO
var pousse:         Vector2 = Vector2.ZERO
var _recul_lock_t:  float   = 0.0
var _pousse_lock_t: float   = 0.0

# Effets visuels
var _secousse_t:             float   = 0.0
var _sprite_pos_neutre:      Vector2 = Vector2.ZERO
var _sprite_scale_neutre:    Vector2 = Vector2.ONE
var _sprite_modulate_neutre: Color   = Color(1, 1, 1, 1)
var _scale_offset:           Vector2 = Vector2.ZERO
var _scale_vel:              Vector2 = Vector2.ZERO
var _scale_actif:            bool    = false
var _flash_t:                float   = 0.0

# Collision — sauvegarde pour restauration
var _layer_orig: int = -1
var _mask_orig:  int = -1

# Divers
var _doit_emit_reapparu_next_frame: bool  = false
var _mort_t:                        float = 0.0

# ---------------------------------------------------------------------------
# Nœuds @onready
# ---------------------------------------------------------------------------

@onready var sante:                    Sante                   = get_node_or_null(chemin_sante) as Sante
@onready var sprite:                   Sprite2D                = get_node_or_null(chemin_sprite) as Sprite2D
@onready var hurtbox:                  HurtBox                 = get_node_or_null("HurtBox") as HurtBox
@onready var contact_damage:           ContactDamage           = get_node_or_null("ContactDamage") as ContactDamage
@onready var deplacement_grille_ennemi: DeplacementGrilleEnnemi = get_node_or_null("DeplacementGrilleEnnemi") as DeplacementGrilleEnnemi
var target: Player = null

# ===========================================================================
# Initialisation
# ===========================================================================

func _ready() -> void:
	add_to_group("enemy")
	if target == null:
		target = get_tree().get_first_node_in_group("joueur_principal") as Player
	if sprite != null:
		_sprite_pos_neutre      = sprite.position
		_sprite_scale_neutre    = sprite.scale
		_sprite_modulate_neutre = sprite.modulate
	if sante != null:
		if not sante.died.is_connected(_on_mort):
			sante.died.connect(_on_mort)
		if not sante.damaged.is_connected(_on_damaged):
			sante.damaged.connect(_on_damaged)
	if contact_damage != null:
		contact_damage.set_physics_process(true)
	_layer_orig = collision_layer
	_mask_orig  = collision_mask
	actualiser_activation_deplacement_grille(true)

# ===========================================================================
# API publique
# ===========================================================================

func get_type_id()  -> int:        return type_ennemi
func get_type_nom() -> StringName: return StringName(TypeEnnemi.find_key(type_ennemi))
func get_score()    -> int:        return valeur_score
func hit_radius()   -> float:      return max(rayon_collision_px, 0.0)
func is_alive()     -> bool:       return _state == State.ALIVE or _state == State.STUNNED

func appliquer_pousse(v: Vector2, lock_s: float = -1.0) -> void:
	pousse += v
	var m: float = pousse.length()
	if m > pousse_max:
		pousse = pousse * (pousse_max / m)
	var ls: float = pousse_bloque_chase_duree_s if lock_s < 0.0 else lock_s
	_pousse_lock_t = max(_pousse_lock_t, max(ls, 0.0))

func appliquer_recul(direction: Vector2, force: float) -> void:
	recul += direction.normalized() * max(force, 0.0)
	var m: float = recul.length()
	if m > recul_max:
		recul = recul * (recul_max / m)
	_recul_lock_t = max(_recul_lock_t, max(recul_bloque_chase_duree_s, 0.0))
	_prendre_coup_visuel()

func appliquer_recul_dash(direction: Vector2, force: float) -> void:
	if direction.length_squared() <= 0.0001:
		return
	recul += direction.normalized() * max(force, 0.0)
	_recul_lock_t = max(_recul_lock_t, max(recul_bloque_chase_duree_s, 0.0))
	_prendre_coup_visuel()

func appliquer_recul_depuis(source: Node2D, force: float) -> void:
	appliquer_recul(global_position - source.global_position, force)

func set_combat_state(actif_moteur: bool, _collision_joueur: bool) -> void:
	if _state == State.DYING or _state == State.DEAD:
		return
	if actif_moteur:
		if hurtbox != null:
			hurtbox.set_actif(true)
		if contact_damage != null:
			contact_damage.set_physics_process(true)
		_restore_collision()
		_set_physics_and_process(true)
		actualiser_activation_deplacement_grille(true)
		return
	actualiser_activation_deplacement_grille(false)
	_set_physics_and_process(false)
	if hurtbox != null:
		hurtbox.set_actif(false)
	if contact_damage != null:
		contact_damage.set_physics_process(false)
	collision_layer = 0
	collision_mask  = 0

func reactiver_apres_pool() -> void:
	_set_state(State.ALIVE)

func definir_cible_joueur(nouveau_joueur: Node2D) -> void:
	target = nouveau_joueur as Player

func actualiser_activation_deplacement_grille(actif: bool) -> void:
	if deplacement_grille_ennemi == null:
		deplacement_grille_ennemi = get_node_or_null("DeplacementGrilleEnnemi") as DeplacementGrilleEnnemi
	if deplacement_grille_ennemi == null:
		return
	if actif and is_inside_tree() and is_alive() and deplacement_grille_ennemi.est_actif_pour(self):
		deplacement_grille_ennemi.activer(self)
	else:
		deplacement_grille_ennemi.desactiver(self)

# ===========================================================================
# Machine d'états — transition centrale
# ===========================================================================

func _set_state(new_state: State) -> void:
	_state = new_state
	match new_state:
		State.ALIVE:
			if not is_in_group("enemy"):
				add_to_group("enemy")
			if sante != null:
				sante.pv = float(sante.max_pv)
			if sprite != null:
				sprite.modulate = _sprite_modulate_neutre
			velocity       = Vector2.ZERO
			recul          = Vector2.ZERO
			pousse         = Vector2.ZERO
			_recul_lock_t  = 0.0
			_pousse_lock_t = 0.0
			if hurtbox != null:
				hurtbox.set_actif(true)
			if contact_damage != null:
				contact_damage.set_physics_process(true)
			_set_physics_and_process(true)
			_restore_collision()
			_reset_visual_state()
			if sprite != null:
				sprite.visible = true
			_doit_emit_reapparu_next_frame = true
			actualiser_activation_deplacement_grille(true)
		State.DYING:
			actualiser_activation_deplacement_grille(false)
			if is_in_group("enemy"):
				remove_from_group("enemy")
			if not has_meta("sl"):
				set_meta("sl", _layer_orig)
			if not has_meta("sm"):
				set_meta("sm", _mask_orig)
			if hurtbox != null:
				hurtbox.set_actif(false)
			if contact_damage != null:
				contact_damage.set_physics_process(false)
			velocity        = Vector2.ZERO
			recul           = Vector2.ZERO
			pousse          = Vector2.ZERO
			collision_layer = 0
			collision_mask  = 0
			set_process(false)
			set_physics_process(true)
			emit_signal("mort")
		State.DEAD:
			actualiser_activation_deplacement_grille(false)
			if sprite != null:
				sprite.visible = false
			velocity        = Vector2.ZERO
			recul           = Vector2.ZERO
			pousse          = Vector2.ZERO
			collision_layer = 0
			collision_mask  = 0
			_set_physics_and_process(false)
			emit_signal("pret_pour_pool")

# ===========================================================================
# Boucle physique principale
# ===========================================================================

func _physics_process(dt: float) -> void:
	if _doit_emit_reapparu_next_frame:
		_doit_emit_reapparu_next_frame = false
		emit_signal("reapparu")
	match _state:
		State.ALIVE, State.STUNNED:
			_traiter_logique(dt)
			_tick_physics_commun(dt)
		State.DYING:
			_tick_physics_commun(dt)
			if _mort_t <= 0.0:
				_set_state(State.DEAD)

func _traiter_logique(dt: float) -> void:
	_recul_lock_t  = max(_recul_lock_t - dt, 0.0)
	_pousse_lock_t = max(_pousse_lock_t - dt, 0.0)
	var recul_actif: bool = recul_bloque_chase and (
		_recul_lock_t > 0.0 or recul.length_squared() >= recul_seuil_blocage_px * recul_seuil_blocage_px)
	var pousse_actif: bool = (
		_pousse_lock_t > 0.0 or pousse.length_squared() >= pousse_seuil_blocage_px * pousse_seuil_blocage_px)
	if recul_actif or pousse_actif:
		if _state == State.ALIVE:
			_state = State.STUNNED
	elif _state == State.STUNNED:
		_state = State.ALIVE

# ===========================================================================
# Tick commun — recul, pousse, effets visuels, déplacement grille
# ===========================================================================

func _tick_physics_commun(dt: float) -> void:
	# Recul
	recul = recul.lerp(Vector2.ZERO, 1.0 - exp(-max(recul_amorti, 0.0) * dt))
	if recul.length_squared() < 1.0:
		recul = Vector2.ZERO
	# Bousculade
	pousse = pousse.lerp(Vector2.ZERO, 1.0 - exp(-max(pousse_amorti, 0.0) * dt))
	if pousse.length_squared() < 1.0:
		pousse = Vector2.ZERO
	# Effets sprite
	if sprite != null and _state != State.DYING:
		if _secousse_t > 0.0:
			_tick_sprite_secousse(dt)
		elif sprite.position != _sprite_pos_neutre:
			sprite.position = _sprite_pos_neutre
		if _scale_actif:
			_tick_scale_impact(dt)
		if _flash_t > 0.0:
			_tick_flash(dt)
	velocity = recul + pousse
	if _state == State.DYING:
		velocity = velocity.lerp(Vector2.ZERO, 1.0 - exp(-max(recul_amorti_mort, 0.0) * dt))
	_appliquer_deplacement(dt)
	if _state == State.DYING:
		_mort_t = max(_mort_t - dt, 0.0)

func _appliquer_deplacement(dt: float) -> void:
	if _state == State.DYING:
		global_position += velocity * dt
		return
	if deplacement_grille_ennemi == null:
		velocity = Vector2.ZERO
		return
	if deplacement_grille_ennemi.traiter(
		self,
		target,
		_obtenir_position_cible_deplacement(),
		dt,
		_autoriser_decision_deplacement(),
		_cible_deplacement_est_joueur()
	):
		return
	velocity = Vector2.ZERO

func _obtenir_position_cible_deplacement() -> Vector2:
	if target != null and is_instance_valid(target):
		return target.global_position
	return global_position

func _autoriser_decision_deplacement() -> bool:
	return _state == State.ALIVE

func _cible_deplacement_est_joueur() -> bool:
	return target != null and is_instance_valid(target)

# ===========================================================================
# Effets visuels
# ===========================================================================

func _prendre_coup_visuel() -> void:
	_secousse_t  = secousse_duree_s
	_scale_vel  += secousse_scale_impulse
	_scale_actif = true

func _declencher_flash() -> void:
	if sprite == null:
		return
	_flash_t = max(flash_duree_s, 0.0)
	sprite.modulate = flash_couleur

func _tick_flash(dt: float) -> void:
	_flash_t -= dt
	if _flash_t <= 0.0:
		_flash_t = 0.0
		sprite.modulate = _sprite_modulate_neutre

func _tick_sprite_secousse(dt: float) -> void:
	_secousse_t -= dt
	var ratio: float = clamp(_secousse_t / max(secousse_duree_s, 0.0001), 0.0, 1.0)
	sprite.position = _sprite_pos_neutre + Vector2(
		randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * secousse_force_px * ratio

func _tick_scale_impact(dt: float) -> void:
	var k: float = max(secousse_scale_spring, 0.0)
	if k <= 0.0:
		if sprite.scale != _sprite_scale_neutre:
			sprite.scale = _sprite_scale_neutre
		_scale_actif = false
		return
	if _scale_offset.length_squared() < 0.000001 and _scale_vel.length_squared() < 0.000001:
		_scale_offset = Vector2.ZERO
		_scale_vel    = Vector2.ZERO
		_scale_actif  = false
		if sprite.scale != _sprite_scale_neutre:
			sprite.scale = _sprite_scale_neutre
		return
	var d: float = max(secousse_scale_damping, 0.0)
	var denom: float = 1.0 + d * dt + k * dt * dt
	_scale_vel    = (_scale_vel - _scale_offset * k * dt) / denom
	_scale_offset += _scale_vel * dt
	var m: float = max(secousse_scale_max, 0.0)
	if m > 0.0:
		_scale_offset.x = clamp(_scale_offset.x, -m, m)
		_scale_offset.y = clamp(_scale_offset.y, -m, m)
	var s: Vector2 = _sprite_scale_neutre + _scale_offset
	sprite.scale = Vector2(max(s.x, 0.05), max(s.y, 0.05))

# ===========================================================================
# Callbacks dommages / mort
# ===========================================================================

func _on_damaged(amount: int, source: Node) -> void:
	_declencher_flash()
	if not (source is Node2D):
		return
	var f: float = clamp(
		float(amount) * max(recul_force_par_degats, 0.0),
		recul_force_min, recul_force_max)
	if f > 0.0:
		appliquer_recul_depuis(source as Node2D, f)

func _on_mort() -> void:
	if _state == State.DYING or _state == State.DEAD:
		return
	_mort_t = max(mort_delai_pool_s, 0.0)
	_set_state(State.DYING)

# ===========================================================================
# Utilitaires internes
# ===========================================================================

func _set_physics_and_process(active: bool) -> void:
	set_physics_process(active)
	set_process(active)

func _restore_collision() -> void:
	if has_meta("sl"):
		collision_layer = int(get_meta("sl"))
	elif _layer_orig >= 0:
		collision_layer = _layer_orig
	if has_meta("sm"):
		collision_mask = int(get_meta("sm"))
	elif _mask_orig >= 0:
		collision_mask = _mask_orig

func _reset_visual_state() -> void:
	_secousse_t   = 0.0
	_scale_offset = Vector2.ZERO
	_scale_vel    = Vector2.ZERO
	_scale_actif  = false
	_flash_t      = 0.0
	if sprite != null:
		sprite.scale    = _sprite_scale_neutre
		sprite.position = _sprite_pos_neutre
		sprite.modulate = _sprite_modulate_neutre

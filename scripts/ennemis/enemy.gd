extends CharacterBody2D
class_name Enemy

signal mort
signal reapparu
signal pret_pour_pool

enum TypeEnnemi { C, B, A, S, BOSS }

enum State {
	ALIVE,
	STUNNED,
	DYING,
	DEAD
}

@export_group("Type")
@export_enum("C", "B", "A", "S", "BOSS") var type_ennemi: int = TypeEnnemi.C
@export var valeur_score: int = 10

@export_group("Refs")
@export_node_path("Node") var chemin_sante: NodePath
@export_node_path("Sprite2D") var chemin_sprite: NodePath = NodePath()

@export_group("Collision")
@export var rayon_collision_px: float = 14.0
@export var poids_collision: float = 1.0

@export_group("Impact")
@export var recul_force_par_degats: float = 18.0
@export var recul_force_min: float = 0.0
@export var recul_force_max: float = 220.0
@export var recul_amorti: float = 18.0
@export var recul_max: float = 500.0
@export var recul_bloque_chase: bool = true
@export var recul_bloque_chase_duree_s: float = 0.12
@export var recul_seuil_blocage_px: float = 8.0
@export var pousse_amorti: float = 26.0
@export var pousse_max: float = 260.0
@export var pousse_bloque_chase_duree_s: float = 0.07
@export var pousse_seuil_blocage_px: float = 14.0
@export var resistance_knockback_dash: float = 0.0
@export var recul_knockback_dash_mult: float = 1.0

@export_group("Effets visuels")
@export var secousse_force_px: float = 4.0
@export var secousse_duree_s: float = 0.12
@export var secousse_scale_impulse: Vector2 = Vector2(0.22, -0.18)
@export var secousse_scale_spring: float = 120.0
@export var secousse_scale_damping: float = 18.0
@export var secousse_scale_max: float = 0.35
@export var flash_couleur: Color = Color(2.0, 0.5, 0.5)
@export var flash_duree_s: float = 0.08

@export_group("Mort")
@export var mort_delai_pool_s: float = 0.18
@export var recul_amorti_mort: float = 8.0

var _state: State = State.ALIVE
var recul: Vector2 = Vector2.ZERO
var pousse: Vector2 = Vector2.ZERO
var _recul_lock_t: float = 0.0
var _pousse_lock_t: float = 0.0
var _secousse_t: float = 0.0
var _sprite_pos_neutre: Vector2 = Vector2.ZERO
var _sprite_scale_neutre: Vector2 = Vector2.ONE
var _sprite_modulate_neutre: Color = Color(1, 1, 1, 1)
var _scale_offset: Vector2 = Vector2.ZERO
var _scale_vel: Vector2 = Vector2.ZERO
var _scale_actif: bool = false
var _flash_t: float = 0.0
var _layer_orig: int = -1
var _mask_orig: int = -1
var _doit_emit_reapparu_next_frame: bool = false
var _mort_t: float = 0.0

@onready var sante: Sante = get_node_or_null(chemin_sante) as Sante
@onready var sprite: Sprite2D = get_node_or_null(chemin_sprite) as Sprite2D
@onready var hurtbox: HurtBox = get_node_or_null("HurtBox") as HurtBox
@onready var contact_damage: ContactDamage = get_node_or_null("ContactDamage") as ContactDamage
@onready var deplacement_grille_ennemi: DeplacementGrilleEnnemi = get_node_or_null("DeplacementGrilleEnnemi") as DeplacementGrilleEnnemi
var target: Player = null

func _ready() -> void:
	add_to_group("enemy")
	if target == null:
		target = get_tree().get_first_node_in_group("joueur_principal") as Player
	if sprite != null:
		_sprite_pos_neutre = sprite.position
		_sprite_scale_neutre = sprite.scale
		_sprite_modulate_neutre = sprite.modulate
	if sante != null:
		if not sante.died.is_connected(_on_mort):
			sante.died.connect(_on_mort)
		if not sante.damaged.is_connected(_on_damaged):
			sante.damaged.connect(_on_damaged)
	_layer_orig = collision_layer
	_mask_orig = collision_mask
	_initialiser_comportement()
	actualiser_activation_deplacement_grille(true)

func get_type_id() -> int:
	return type_ennemi

func get_type_nom() -> StringName:
	return StringName(TypeEnnemi.find_key(type_ennemi))

func get_score() -> int:
	return valeur_score

func hit_radius() -> float:
	return maxf(rayon_collision_px, 0.0)

func is_alive() -> bool:
	return _state == State.ALIVE or _state == State.STUNNED

func set_poussee_foule(v: Vector2) -> void:
	if _state == State.DYING or _state == State.DEAD:
		return
	appliquer_pousse(v, 0.0)

func appliquer_pousse(v: Vector2, lock_s: float = -1.0) -> void:
	pousse += v
	var magnitude: float = pousse.length()
	if magnitude > pousse_max:
		pousse *= pousse_max / magnitude
	var duree_blocage: float = pousse_bloque_chase_duree_s if lock_s < 0.0 else lock_s
	_pousse_lock_t = maxf(_pousse_lock_t, maxf(duree_blocage, 0.0))
	_sur_poussee_appliquee()

func appliquer_recul(direction: Vector2, force: float) -> void:
	if direction.length_squared() <= 0.0001 or force <= 0.0:
		return
	recul += direction.normalized() * force
	var magnitude: float = recul.length()
	if magnitude > recul_max:
		recul *= recul_max / magnitude
	_recul_lock_t = maxf(_recul_lock_t, maxf(recul_bloque_chase_duree_s, 0.0))
	_sur_recul_applique()
	_prendre_coup_visuel()

func appliquer_recul_dash(direction: Vector2, force: float) -> void:
	if direction.length_squared() <= 0.0001 or force <= 0.0:
		return
	recul += direction.normalized() * force
	var magnitude: float = recul.length()
	if magnitude > recul_max:
		recul *= recul_max / magnitude
	_recul_lock_t = maxf(_recul_lock_t, maxf(recul_bloque_chase_duree_s, 0.0))
	_sur_recul_applique()
	_prendre_coup_visuel()

func appliquer_recul_depuis(source: Node2D, force: float) -> void:
	if source == null:
		return
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
	collision_mask = 0

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

func _set_state(nouvel_etat: State) -> void:
	_state = nouvel_etat
	match nouvel_etat:
		State.ALIVE:
			if not is_in_group("enemy"):
				add_to_group("enemy")
			if sante != null:
				sante.pv = float(sante.max_pv)
			if sprite != null:
				sprite.modulate = _sprite_modulate_neutre
			velocity = Vector2.ZERO
			recul = Vector2.ZERO
			pousse = Vector2.ZERO
			_recul_lock_t = 0.0
			_pousse_lock_t = 0.0
			if hurtbox != null:
				hurtbox.set_actif(true)
			if contact_damage != null:
				contact_damage.set_physics_process(true)
			_set_physics_and_process(true)
			_restore_collision()
			_reset_visual_state()
			_reinitialiser_comportement()
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
			velocity = Vector2.ZERO
			recul = Vector2.ZERO
			pousse = Vector2.ZERO
			_reinitialiser_comportement()
			collision_layer = 0
			collision_mask = 0
			set_process(false)
			set_physics_process(true)
			mort.emit()
		State.DEAD:
			actualiser_activation_deplacement_grille(false)
			if sprite != null:
				sprite.visible = false
			velocity = Vector2.ZERO
			recul = Vector2.ZERO
			pousse = Vector2.ZERO
			_reinitialiser_comportement()
			collision_layer = 0
			collision_mask = 0
			_set_physics_and_process(false)
			pret_pour_pool.emit()

func _physics_process(dt: float) -> void:
	if _doit_emit_reapparu_next_frame:
		_doit_emit_reapparu_next_frame = false
		reapparu.emit()
	match _state:
		State.ALIVE, State.STUNNED:
			_traiter_logique(dt)
			_tick_physics_commun(dt)
		State.DYING:
			_tick_physics_commun(dt)
			if _mort_t <= 0.0:
				_set_state(State.DEAD)

func _traiter_logique(dt: float) -> void:
	_recul_lock_t = maxf(_recul_lock_t - dt, 0.0)
	_pousse_lock_t = maxf(_pousse_lock_t - dt, 0.0)
	var seuil_recul: float = maxf(recul_seuil_blocage_px, 1.0)
	var seuil_pousse: float = maxf(pousse_seuil_blocage_px, 1.0)
	var recul_actif: bool = recul_bloque_chase and (_recul_lock_t > 0.0 or recul.length_squared() >= seuil_recul * seuil_recul)
	var pousse_active: bool = _pousse_lock_t > 0.0 or pousse.length_squared() >= seuil_pousse * seuil_pousse
	if recul_actif or pousse_active:
		if _state == State.ALIVE:
			_state = State.STUNNED
	elif _state == State.STUNNED:
		_state = State.ALIVE

func _tick_physics_commun(dt: float) -> void:
	recul = recul.lerp(Vector2.ZERO, 1.0 - exp(-maxf(recul_amorti, 0.0) * dt))
	if recul.length_squared() < 1.0:
		recul = Vector2.ZERO
	pousse = pousse.lerp(Vector2.ZERO, 1.0 - exp(-maxf(pousse_amorti, 0.0) * dt))
	if pousse.length_squared() < 1.0:
		pousse = Vector2.ZERO
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
		velocity = velocity.lerp(Vector2.ZERO, 1.0 - exp(-maxf(recul_amorti_mort, 0.0) * dt))
	_appliquer_deplacement(dt)
	if _state == State.DYING:
		_mort_t = maxf(_mort_t - dt, 0.0)

func _appliquer_deplacement(dt: float) -> void:
	if _state == State.DYING:
		global_position += velocity * dt
		return
	if deplacement_grille_ennemi == null:
		velocity = Vector2.ZERO
		return
	if deplacement_grille_ennemi.traiter(self, target, _obtenir_position_cible_deplacement(), dt, _autoriser_decision_deplacement(), _cible_deplacement_est_joueur()):
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

func _prendre_coup_visuel() -> void:
	_secousse_t = secousse_duree_s
	_scale_vel += secousse_scale_impulse
	_scale_actif = true

func _declencher_flash() -> void:
	if sprite == null:
		return
	_flash_t = maxf(flash_duree_s, 0.0)
	sprite.modulate = flash_couleur

func _tick_flash(dt: float) -> void:
	_flash_t -= dt
	if _flash_t <= 0.0:
		_flash_t = 0.0
		sprite.modulate = _sprite_modulate_neutre

func _tick_sprite_secousse(dt: float) -> void:
	_secousse_t -= dt
	var ratio: float = clampf(_secousse_t / maxf(secousse_duree_s, 0.0001), 0.0, 1.0)
	sprite.position = _sprite_pos_neutre + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * secousse_force_px * ratio

func _tick_scale_impact(dt: float) -> void:
	var raideur: float = maxf(secousse_scale_spring, 0.0)
	if raideur <= 0.0:
		if sprite.scale != _sprite_scale_neutre:
			sprite.scale = _sprite_scale_neutre
		_scale_actif = false
		return
	if _scale_offset.length_squared() < 0.000001 and _scale_vel.length_squared() < 0.000001:
		_scale_offset = Vector2.ZERO
		_scale_vel = Vector2.ZERO
		_scale_actif = false
		if sprite.scale != _sprite_scale_neutre:
			sprite.scale = _sprite_scale_neutre
		return
	var amortissement: float = maxf(secousse_scale_damping, 0.0)
	var denominateur: float = 1.0 + amortissement * dt + raideur * dt * dt
	_scale_vel = (_scale_vel - _scale_offset * raideur * dt) / denominateur
	_scale_offset += _scale_vel * dt
	var amplitude_max: float = maxf(secousse_scale_max, 0.0)
	if amplitude_max > 0.0:
		_scale_offset.x = clampf(_scale_offset.x, -amplitude_max, amplitude_max)
		_scale_offset.y = clampf(_scale_offset.y, -amplitude_max, amplitude_max)
	var nouvelle_echelle: Vector2 = _sprite_scale_neutre + _scale_offset
	sprite.scale = Vector2(maxf(nouvelle_echelle.x, 0.05), maxf(nouvelle_echelle.y, 0.05))

func _initialiser_comportement() -> void:
	pass

func _reinitialiser_comportement() -> void:
	pass

func _sur_recul_applique() -> void:
	pass

func _sur_poussee_appliquee() -> void:
	pass

func _on_damaged(amount: int, source: Node) -> void:
	_declencher_flash()
	if not (source is Node2D):
		return
	var force: float = clampf(float(amount) * maxf(recul_force_par_degats, 0.0), recul_force_min, recul_force_max)
	if force > 0.0:
		appliquer_recul_depuis(source as Node2D, force)

func _on_mort() -> void:
	if _state == State.DYING or _state == State.DEAD:
		return
	_mort_t = maxf(mort_delai_pool_s, 0.0)
	_set_state(State.DYING)

func _set_physics_and_process(actif: bool) -> void:
	set_physics_process(actif)
	set_process(actif)

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
	_secousse_t = 0.0
	_scale_offset = Vector2.ZERO
	_scale_vel = Vector2.ZERO
	_scale_actif = false
	_flash_t = 0.0
	if sprite != null:
		sprite.scale = _sprite_scale_neutre
		sprite.position = _sprite_pos_neutre
		sprite.modulate = _sprite_modulate_neutre

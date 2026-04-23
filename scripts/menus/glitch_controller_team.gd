extends Node
class_name GlitchTextureButtonGroupController

enum Etat { IDLE, HOVER, PRESSED }

@export var debug: bool = false
@export var groupe: StringName = &"glitch_buttons"

@export var live_update: bool = false
@export var live_hz: float = 12.0
@export var anim_duree_s: float = 0.10

@export_group("Transform")
@export var pivot_centre: bool = true
@export var anim_transform: bool = true

@export_group("IDLE Transform")
@export var idle_scale: Vector2 = Vector2(1.0, 1.0)
@export var idle_rot_deg: float = 0.0
@export var idle_offset_px: Vector2 = Vector2.ZERO

@export_group("HOVER Transform")
@export var hover_scale: Vector2 = Vector2(1.04, 1.04)
@export var hover_rot_deg: float = 0.6
@export var hover_offset_px: Vector2 = Vector2(0.0, -1.0)

@export_group("PRESSED Transform")
@export var pressed_scale: Vector2 = Vector2(0.97, 0.97)
@export var pressed_rot_deg: float = -0.8
@export var pressed_offset_px: Vector2 = Vector2(0.0, 1.0)

@export_group("IDLE")
@export var idle_glitch_amount: float = 23.16
@export var idle_glitch_speed: float = 1.34
@export var idle_band_count: float = 14.945
@export var idle_rgb_split_px: float = 2.0
@export var idle_max_shift: float = 2.58
@export var idle_jitter_px: float = 1.5
@export var idle_freeze_chance: float = 0.12
@export var idle_blockiness: float = -3.455
@export var idle_scan_strength: float = 0.05
@export var idle_noise_strength: float = 1.71

@export_group("HOVER")
@export var hover_glitch_amount: float = 26.50
@export var hover_glitch_speed: float = 1.55
@export var hover_band_count: float = 18.0
@export var hover_rgb_split_px: float = 2.6
@export var hover_max_shift: float = 3.10
@export var hover_jitter_px: float = 1.9
@export var hover_freeze_chance: float = 0.16
@export var hover_blockiness: float = -2.0
@export var hover_scan_strength: float = 0.065
@export var hover_noise_strength: float = 2.10

@export_group("PRESSED")
@export var pressed_glitch_amount: float = 30.0
@export var pressed_glitch_speed: float = 1.85
@export var pressed_band_count: float = 24.0
@export var pressed_rgb_split_px: float = 3.4
@export var pressed_max_shift: float = 3.75
@export var pressed_jitter_px: float = 2.6
@export var pressed_freeze_chance: float = 0.22
@export var pressed_blockiness: float = -0.5
@export var pressed_scan_strength: float = 0.085
@export var pressed_noise_strength: float = 2.60

class BtnData:
	var btn: TextureButton
	var mat: ShaderMaterial
	var etat: int = Etat.IDLE
	var hovered: bool = false
	var down: bool = false
	var tw_shader: Tween = null
	var tw_xform: Tween = null
	func _init(b: TextureButton, m: ShaderMaterial) -> void:
		btn = b
		mat = m

var _btns: Array[BtnData] = []
var _live_accum: float = 0.0

func _ready() -> void:
	call_deferred("_init_differe")

func _init_differe() -> void:
	_collect()
	_connect_all()
	_apply_all(true)

func _process(delta: float) -> void:
	if not live_update:
		return
	_live_accum += delta
	var step: float = 1.0 / max(live_hz, 1.0)
	if _live_accum < step:
		return
	_live_accum = 0.0
	_apply_all(true)

func refresh_now() -> void:
	_apply_all(true)

func _collect() -> void:
	_btns.clear()

	var nodes := get_tree().get_nodes_in_group(groupe)
	for n in nodes:
		var b := n as TextureButton
		if b == null:
			continue

		var sm := b.material as ShaderMaterial
		if sm == null:
			_log("SKIP: " + b.name + " (pas de ShaderMaterial sur material)")
			continue

		var dup := sm.duplicate(true) as ShaderMaterial
		b.material = dup

		if pivot_centre:
			b.pivot_offset = b.size * 0.5

		_btns.append(BtnData.new(b, dup))
		_log("OK: " + b.name)

func _connect_all() -> void:
	for d in _btns:
		var b := d.btn

		if not b.mouse_entered.is_connected(Callable(self, "_on_enter").bind(d)):
			b.mouse_entered.connect(Callable(self, "_on_enter").bind(d), Object.CONNECT_DEFERRED)
		if not b.mouse_exited.is_connected(Callable(self, "_on_exit").bind(d)):
			b.mouse_exited.connect(Callable(self, "_on_exit").bind(d), Object.CONNECT_DEFERRED)
		if not b.button_down.is_connected(Callable(self, "_on_down").bind(d)):
			b.button_down.connect(Callable(self, "_on_down").bind(d), Object.CONNECT_DEFERRED)
		if not b.button_up.is_connected(Callable(self, "_on_up").bind(d)):
			b.button_up.connect(Callable(self, "_on_up").bind(d), Object.CONNECT_DEFERRED)

func _on_enter(d: BtnData) -> void:
	d.hovered = true
	_update_state(d, false)

func _on_exit(d: BtnData) -> void:
	d.hovered = false
	_update_state(d, false)

func _on_down(d: BtnData) -> void:
	d.down = true
	_update_state(d, false)

func _on_up(d: BtnData) -> void:
	d.down = false
	_update_state(d, false)

func _update_state(d: BtnData, instant: bool) -> void:
	var next := Etat.IDLE
	if d.down:
		next = Etat.PRESSED
	elif d.hovered:
		next = Etat.HOVER

	if next == d.etat and not instant:
		return

	d.etat = next
	_apply_one(d, instant)

func _apply_all(instant: bool) -> void:
	for d in _btns:
		_update_state(d, instant)

func _apply_one(d: BtnData, instant: bool) -> void:
	var dur: float = 0.0 if instant else max(anim_duree_s, 0.01)
	_apply_shader(d, dur)
	_apply_transform(d, dur)

func _apply_shader(d: BtnData, dur: float) -> void:
	if d.tw_shader != null and d.tw_shader.is_running():
		d.tw_shader.kill()
	d.tw_shader = null

	var a: float
	var sp: float
	var bc: float
	var rgb: float
	var ms: float
	var jit: float
	var frz: float
	var blk: float
	var sc: float
	var ns: float

	if d.etat == Etat.PRESSED:
		a = pressed_glitch_amount
		sp = pressed_glitch_speed
		bc = pressed_band_count
		rgb = pressed_rgb_split_px
		ms = pressed_max_shift
		jit = pressed_jitter_px
		frz = pressed_freeze_chance
		blk = pressed_blockiness
		sc = pressed_scan_strength
		ns = pressed_noise_strength
	elif d.etat == Etat.HOVER:
		a = hover_glitch_amount
		sp = hover_glitch_speed
		bc = hover_band_count
		rgb = hover_rgb_split_px
		ms = hover_max_shift
		jit = hover_jitter_px
		frz = hover_freeze_chance
		blk = hover_blockiness
		sc = hover_scan_strength
		ns = hover_noise_strength
	else:
		a = idle_glitch_amount
		sp = idle_glitch_speed
		bc = idle_band_count
		rgb = idle_rgb_split_px
		ms = idle_max_shift
		jit = idle_jitter_px
		frz = idle_freeze_chance
		blk = idle_blockiness
		sc = idle_scan_strength
		ns = idle_noise_strength

	if dur <= 0.0:
		_set_params(d.mat, a, sp, bc, rgb, ms, jit, frz, blk, sc, ns)
		return

	var from_a: float = float(d.mat.get_shader_parameter("glitch_amount"))
	var from_sp: float = float(d.mat.get_shader_parameter("glitch_speed"))
	var from_bc: float = float(d.mat.get_shader_parameter("band_count"))
	var from_rgb: float = float(d.mat.get_shader_parameter("rgb_split_px"))
	var from_ms: float = float(d.mat.get_shader_parameter("max_shift"))
	var from_jit: float = float(d.mat.get_shader_parameter("jitter_px"))
	var from_frz: float = float(d.mat.get_shader_parameter("freeze_chance"))
	var from_blk: float = float(d.mat.get_shader_parameter("blockiness"))
	var from_sc: float = float(d.mat.get_shader_parameter("scan_strength"))
	var from_ns: float = float(d.mat.get_shader_parameter("noise_strength"))

	d.tw_shader = create_tween()
	d.tw_shader.set_trans(Tween.TRANS_QUAD)
	d.tw_shader.set_ease(Tween.EASE_OUT)
	d.tw_shader.tween_method(func(v: float) -> void:
		var k: float = clamp(v, 0.0, 1.0)
		_set_params(
			d.mat,
			lerp(from_a, a, k),
			lerp(from_sp, sp, k),
			lerp(from_bc, bc, k),
			lerp(from_rgb, rgb, k),
			lerp(from_ms, ms, k),
			lerp(from_jit, jit, k),
			lerp(from_frz, frz, k),
			lerp(from_blk, blk, k),
			lerp(from_sc, sc, k),
			lerp(from_ns, ns, k)
		)
	, 0.0, 1.0, dur)

func _apply_transform(d: BtnData, dur: float) -> void:
	if not anim_transform:
		return

	if d.tw_xform != null and d.tw_xform.is_running():
		d.tw_xform.kill()
	d.tw_xform = null

	var target_scale: Vector2 = idle_scale
	var target_rot: float = deg_to_rad(idle_rot_deg)

	if d.etat == Etat.HOVER:
		target_scale = hover_scale
		target_rot = deg_to_rad(hover_rot_deg)
	elif d.etat == Etat.PRESSED:
		target_scale = pressed_scale
		target_rot = deg_to_rad(pressed_rot_deg)

	if dur <= 0.0:
		d.btn.scale = target_scale
		d.btn.rotation = target_rot
		return

	var from_scale: Vector2 = d.btn.scale
	var from_rot: float = d.btn.rotation

	d.tw_xform = create_tween()
	d.tw_xform.set_trans(Tween.TRANS_QUAD)
	d.tw_xform.set_ease(Tween.EASE_OUT)
	d.tw_xform.tween_method(func(v: float) -> void:
		var k: float = clamp(v, 0.0, 1.0)
		d.btn.scale = from_scale.lerp(target_scale, k)
		d.btn.rotation = lerp(from_rot, target_rot, k)
	, 0.0, 1.0, dur)

func _set_params(mat: ShaderMaterial, a: float, sp: float, bc: float, rgb: float, ms: float, jit: float, frz: float, blk: float, sc: float, ns: float) -> void:
	mat.set_shader_parameter("glitch_amount", a)
	mat.set_shader_parameter("glitch_speed", sp)
	mat.set_shader_parameter("band_count", bc)
	mat.set_shader_parameter("rgb_split_px", rgb)
	mat.set_shader_parameter("max_shift", ms)
	mat.set_shader_parameter("jitter_px", jit)
	mat.set_shader_parameter("freeze_chance", frz)
	mat.set_shader_parameter("blockiness", blk)
	mat.set_shader_parameter("scan_strength", sc)
	mat.set_shader_parameter("noise_strength", ns)

func _log(s: String) -> void:
	if debug:
		print("[GlitchTextureButtonGroupController] " + s)

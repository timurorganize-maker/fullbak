class_name Player
extends CharacterBody3D
## Персонаж: CharacterBody3D + модель Kenney (CC0) с анимациями idle/walk/jump.
## Плавное смешивание делает AnimationTree: BlendSpace1D (idle↔walk) → TimeScale («бег» —
## ускоренная ходьба) → OneShot (прыжок). Отдельной run-анимации у модели нет.

signal jumped
signal landed

const MAX_SPEED := 5.2
const ACCEL := 30.0
const DECEL := 38.0
const AIR_CONTROL := 0.45
const GRAVITY := 22.0
const JUMP_VELOCITY := 7.0
const COYOTE := 0.12
const JUMP_BUFFER := 0.14
const MODEL_SCALE := 1.7
const RESPAWN_Y := -9.0

## Задаётся из main.gd каждый кадр.
var input_vec := Vector2.ZERO      # x — вправо, y — назад (как у Input.get_vector)
var cam_yaw := 0.0
var enabled := true

var _coyote := 0.0
var _jump_buf := 0.0
var _was_on_floor := true
var _air_time := 0.0
var _safe_pos := Vector3.ZERO
var _safe_timer := 0.0
var _tree: AnimationTree
var _steps: AudioStreamPlayer
var _sfx_jump: AudioStreamPlayer
var _sfx_land: AudioStreamPlayer
var _speed_smooth := 0.0

@onready var model: Node3D = $Model

func _ready() -> void:
	_safe_pos = global_position
	_load_model()
	_steps = _make_audio("res://assets/sounds/walking.ogg", -6.0, true)
	_sfx_jump = _make_audio("res://assets/sounds/jump.ogg", -8.0, false)
	_sfx_land = _make_audio("res://assets/sounds/land.ogg", -8.0, false)

func _make_audio(path: String, db: float, loop: bool) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var s: AudioStream = load(path)
	if loop and s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	p.stream = s
	p.volume_db = db
	add_child(p)
	return p

func _load_model() -> void:
	var scene: PackedScene = load("res://assets/models/character.glb")
	var inst := scene.instantiate() as Node3D
	inst.scale = Vector3.ONE * MODEL_SCALE
	model.add_child(inst)
	var ap := _find_anim_player(inst)
	if ap == null:
		push_warning("AnimationPlayer не найден в модели персонажа")
		return
	for n in ["idle", "walk"]:
		if ap.has_animation(n):
			ap.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	if ap.has_animation("jump"):
		ap.get_animation("jump").loop_mode = Animation.LOOP_NONE
	_build_tree(ap)

func _find_anim_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_anim_player(c)
		if r:
			return r
	return null

func _build_tree(ap: AnimationPlayer) -> void:
	var root := AnimationNodeBlendTree.new()
	var idle := AnimationNodeAnimation.new()
	idle.animation = &"idle"
	var walk := AnimationNodeAnimation.new()
	walk.animation = &"walk"
	var loco := AnimationNodeBlendSpace1D.new()
	loco.min_space = 0.0
	loco.max_space = 1.0
	loco.add_blend_point(idle, 0.0)
	loco.add_blend_point(walk, 1.0)
	var ts := AnimationNodeTimeScale.new()
	var jump := AnimationNodeAnimation.new()
	jump.animation = &"jump"
	var shot := AnimationNodeOneShot.new()
	shot.fadein_time = 0.08
	shot.fadeout_time = 0.2
	root.add_node(&"loco", loco, Vector2(0, 0))
	root.add_node(&"ts", ts, Vector2(250, 0))
	root.add_node(&"jump", jump, Vector2(250, 150))
	root.add_node(&"shot", shot, Vector2(500, 0))
	root.connect_node(&"ts", 0, &"loco")
	root.connect_node(&"shot", 0, &"ts")
	root.connect_node(&"shot", 1, &"jump")
	root.connect_node(&"output", 0, &"shot")
	_tree = AnimationTree.new()
	add_child(_tree)
	_tree.tree_root = root
	_tree.anim_player = _tree.get_path_to(ap)
	_tree.active = true

func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()
	if on_floor:
		_coyote = COYOTE
		if not _was_on_floor and _air_time > 0.25:
			_sfx_land.play()
			landed.emit()
		_air_time = 0.0
	else:
		_coyote -= delta
		_air_time += delta
		velocity.y -= GRAVITY * delta
	_jump_buf -= delta

	var iv := input_vec if enabled else Vector2.ZERO
	var dir := Basis(Vector3.UP, cam_yaw) * Vector3(iv.x, 0.0, iv.y)
	var target := dir * MAX_SPEED
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	var rate := ACCEL if target.length() > 0.05 else DECEL
	if not on_floor:
		rate *= AIR_CONTROL
	hv = hv.move_toward(target, rate * delta)
	velocity.x = hv.x
	velocity.z = hv.z

	if _jump_buf > 0.0 and _coyote > 0.0 and enabled:
		velocity.y = JUMP_VELOCITY
		_jump_buf = 0.0
		_coyote = 0.0
		_sfx_jump.play()
		if _tree:
			_tree.set("parameters/shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		jumped.emit()

	move_and_slide()

	on_floor = is_on_floor()
	_was_on_floor = on_floor

	var speed := Vector2(velocity.x, velocity.z).length()
	_speed_smooth = lerpf(_speed_smooth, speed, 1.0 - exp(-12.0 * delta))
	if speed > 0.4:
		var face := atan2(velocity.x, velocity.z)
		model.rotation.y = lerp_angle(model.rotation.y, face, 1.0 - exp(-14.0 * delta))

	_update_animation()
	_update_steps(on_floor, speed)

	# страховка: не выпасть из мира
	_safe_timer -= delta
	if on_floor and _safe_timer <= 0.0 and GameData.room_at(global_position) != "":
		_safe_pos = global_position
		_safe_timer = 0.5
	if global_position.y < RESPAWN_Y:
		global_position = _safe_pos + Vector3(0, 0.3, 0)
		velocity = Vector3.ZERO

func _update_animation() -> void:
	if _tree == null:
		return
	var walk_amt := clampf(_speed_smooth / 2.0, 0.0, 1.0)
	_tree.set("parameters/loco/blend_position", walk_amt)
	var run_amt := clampf((_speed_smooth - 2.0) / 3.2, 0.0, 1.0)
	_tree.set("parameters/ts/scale", lerpf(1.0, 1.9, run_amt))

func _update_steps(on_floor: bool, speed: float) -> void:
	if on_floor and speed > 1.0 and enabled:
		_steps.pitch_scale = lerpf(0.95, 1.4, clampf((speed - 1.0) / 4.2, 0.0, 1.0))
		if not _steps.playing:
			_steps.play()
	elif _steps.playing:
		_steps.stop()

func request_jump() -> void:
	_jump_buf = JUMP_BUFFER

func teleport(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	_safe_pos = pos

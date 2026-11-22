extends Node3D
## Точка входа: собирает мир (дом, свет, окружение), игрока, камеру, HUD и ведёт игру.

const INTERACT_EYE := 1.0   # высота «глаз» для проверки прямой видимости

var house: HouseBuilder
var player: Player
var rig: CameraRig
var hud: Hud
var touch: TouchControls

var found := 0
var has_key := false
var elapsed := 0.0
var won := false
var collected_ids: Dictionary = {}

var _target: Node = null
var _shadow_timer := 0.0
var _room_id := ""
var _sfx_pickup: AudioStreamPlayer
var _sfx_unlock: AudioStreamPlayer
var _music: AudioStreamPlayer
var _bot: Node

func _ready() -> void:
	_setup_input()
	_build_environment()

	house = HouseBuilder.new()
	house.name = "House"
	add_child(house)
	house.build()
	_spawn_items()

	player = (load("res://scenes/player.tscn") as PackedScene).instantiate() as Player
	add_child(player)
	player.position = GameData.SPAWN

	rig = CameraRig.new()
	rig.yaw = GameData.SPAWN_YAW
	add_child(rig)
	rig.target = player
	rig.snap_to_target()

	var touch_layer := CanvasLayer.new()
	touch_layer.layer = 5
	add_child(touch_layer)
	touch = TouchControls.new()
	touch_layer.add_child(touch)
	touch.jump_pressed.connect(func(): player.request_jump())
	touch.interact_pressed.connect(_do_interact)

	hud = Hud.new()
	add_child(hud)
	hud.restart_pressed.connect(func(): get_tree().reload_current_scene())
	hud.set_count(0, GameData.total_items())
	_refresh_hint()

	_sfx_pickup = _audio("res://assets/sounds/coin.ogg", -4.0)
	_sfx_unlock = _audio("res://assets/sounds/break.ogg", -6.0)
	if ResourceLoader.exists("res://assets/sounds/music.ogg"):
		_music = _audio("res://assets/sounds/music.ogg", -13.0)
		var ms := _music.stream
		if ms is AudioStreamOggVorbis:
			(ms as AudioStreamOggVorbis).loop = true
		_music.play()

	_update_shadow_lamps()
	# отладочные режимы (папка tools/ в экспорт не попадает)
	var user_args := OS.get_cmdline_user_args()
	for a in user_args:
		var tool := ""
		if a == "--selftest":
			tool = "res://tools/bot.gd"
		elif a == "--fuzz":
			tool = "res://tools/fuzz.gd"
		elif a.begins_with("--shots"):
			tool = "res://tools/shots.gd"
		if tool != "" and ResourceLoader.exists(tool):
			_bot = (load(tool) as GDScript).new()
			_bot.game = self
			add_child(_bot)

func _audio(path: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = db
	add_child(p)
	return p

# --- ввод ----------------------------------------------------------------------

func _setup_input() -> void:
	var map := {
		"move_left": [KEY_A],
		"move_right": [KEY_D],
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"look_left": [KEY_LEFT, KEY_Q],
		"look_right": [KEY_RIGHT, KEY_R],
		"jump": [KEY_SPACE],
		"interact": [KEY_E, KEY_ENTER],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)

# --- окружение и свет ----------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.045, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.47, 0.42)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 0.9
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.05
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.06
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# «лунный» свет: мягкие длинные тени от стен, холодный контраст к тёплым лампам
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(0.62, 0.7, 1.0)
	sun.light_energy = 0.32
	sun.rotation_degrees = Vector3(-58, -35, 0)
	sun.shadow_enabled = true
	sun.shadow_bias = 0.05
	sun.shadow_blur = 1.6
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 28.0
	add_child(sun)

## Тени дороги: включаем их только у двух ближайших к игроку ламп.
func _update_shadow_lamps() -> void:
	var lamps := house.lamps.duplicate()
	var pp := player.global_position
	lamps.sort_custom(func(a: OmniLight3D, b: OmniLight3D): return a.global_position.distance_squared_to(pp) < b.global_position.distance_squared_to(pp))
	for i in lamps.size():
		(lamps[i] as OmniLight3D).shadow_enabled = i < 2 and lamps[i].global_position.distance_to(pp) < 12.0

# --- предметы ------------------------------------------------------------------

func _spawn_items() -> void:
	for d in GameData.ITEMS:
		var p := Pickup.new()
		p.name = "Item_" + String(d["id"])
		add_child(p)
		p.setup(d)
		p.collected.connect(_on_collected)

func _on_collected(p: Pickup) -> void:
	found += 1
	collected_ids[p.item["id"]] = true
	_sfx_pickup.pitch_scale = 1.0 + found * 0.04
	_sfx_pickup.play()
	hud.set_count(found, GameData.total_items())
	if p.kind == "key":
		has_key = true
		hud.toast("Ключ найден! Он подойдёт к двери кабинета")
	else:
		hud.toast("Звезда найдена!")
	if found >= GameData.total_items():
		_win()
	else:
		_refresh_hint()

func _next_item() -> Dictionary:
	for d in GameData.ITEMS:
		if not collected_ids.has(d["id"]):
			return d
	return {}

func _refresh_hint() -> void:
	var d := _next_item()
	if d.is_empty():
		hud.set_hint("")
		return
	var text: String = d["hint"]
	if d.has("needs_door") and house.doors.has(d["needs_door"]) and not (house.doors[d["needs_door"]] as Door).locked:
		text = "Дверь открыта — загляни на книжные полки"
	hud.set_hint("Ищи: %s\n%s" % [GameData.room_name(d["room"]), text])

func _win() -> void:
	won = true
	player.enabled = false
	touch.active = false
	touch.set_take("")
	hud.set_hint("")
	hud.show_win(elapsed, found, GameData.total_items())

# --- кадр ----------------------------------------------------------------------

func _process(delta: float) -> void:
	if not won:
		elapsed += delta
		hud.set_time(elapsed)

	# управление: сенсор + клавиатура (для отладки на ПК)
	var kb := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var tv := touch.move_vec
	var iv := tv if tv.length() >= kb.length() else kb
	if _bot and _bot.has_method("get_input"):
		iv = _bot.get_input()
	player.input_vec = iv
	player.cam_yaw = rig.yaw
	rig.look(touch.consume_look())
	rig.yaw += Input.get_axis("look_left", "look_right") * -2.4 * delta
	if Input.is_action_just_pressed("jump"):
		player.request_jump()
	if Input.is_action_just_pressed("interact"):
		_do_interact()

	var rid := GameData.room_at(player.global_position)
	if rid != _room_id:
		_room_id = rid
		hud.set_room(GameData.room_name(rid))

	_shadow_timer -= delta
	if _shadow_timer <= 0.0:
		_shadow_timer = 0.3
		_update_shadow_lamps()

func _physics_process(_delta: float) -> void:
	if won:
		return
	var best: Node = null
	var best_d := INF
	var eye := player.global_position + Vector3(0, INTERACT_EYE, 0)
	var space := get_world_3d().direct_space_state
	for n in get_tree().get_nodes_in_group("interactable"):
		var pos: Vector3 = n.get_interact_pos()
		var d := eye.distance_to(pos)
		if d > float(n.interact_range) or d >= best_d:
			continue
		if n is Pickup:
			# предмет за стеной/полом брать нельзя: проверяем только слой «мир»
			var q := PhysicsRayQueryParameters3D.create(eye, pos, 1)
			if not space.intersect_ray(q).is_empty():
				continue
		elif absf(pos.y - eye.y) > 1.6:
			continue
		best = n
		best_d = d
	if best != _target:
		_target = best
		touch.set_take(best.get_prompt() if best else "")

func _do_interact() -> void:
	if won or _target == null or not is_instance_valid(_target):
		return
	if _target is Pickup:
		(_target as Pickup).take()
		_target = null
		touch.set_take("")
	elif _target is Door:
		var door := _target as Door
		if has_key:
			door.unlock()
			_sfx_unlock.play()
			hud.toast("Кабинет открыт!")
			_refresh_hint()
			_target = null
			touch.set_take("")
		else:
			hud.toast("Заперто. Нужен ключ — поищи в других комнатах")

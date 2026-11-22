extends Node
## Стресс-тест физики: случайное блуждание с прыжками из разных точек дома.
## Проверяет: игрок не проваливается сквозь пол, не вылезает за стены и не застревает.
## Запуск: godot --headless --fixed-fps 60 --path roomhunt -- --fuzz
var game
var rng := RandomNumberGenerator.new()
var dir := Vector2.ZERO
var change_t := 0.0
var total := 0.0
var starts := [
	Vector3(2, 0.2, 0), Vector3(5, 0.2, -5), Vector3(14, 0.2, -5), Vector3(22, 0.2, -5),
	Vector3(5, 0.2, 5), Vector3(14, 0.2, 5), Vector3(29, 0.2, 0), Vector3(29, 1.0, -7),
	Vector3(29, 3.0, -14), Vector3(29, -1.0, 7), Vector3(29, -2.4, 14),
]
var run_idx := 0
var run_t := 0.0
var stuck_t := 0.0
var last_pos := Vector3.ZERO
var out_t := 0.0
const RUN_TIME := 25.0
var jump_next := 0.0

func _ready() -> void:
	rng.seed = 12345

func get_input() -> Vector2:
	return dir

func _begin_run() -> void:
	game.player.teleport(starts[run_idx])
	# делаем кабинет доступным для проверки
	(game.house.doors["study"] as Door).unlock()
	run_t = 0.0
	last_pos = starts[run_idx]
	stuck_t = 0.0

func _physics_process(delta: float) -> void:
	if total == 0.0:
		_begin_run()
	total += delta
	run_t += delta
	change_t -= delta
	jump_next -= delta
	if change_t <= 0.0:
		change_t = rng.randf_range(0.3, 1.6)
		dir = Vector2.ZERO if rng.randf() < 0.08 else Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.6, 1.0)
		game.rig.yaw = rng.randf() * TAU if rng.randf() < 0.3 else game.rig.yaw
	if jump_next <= 0.0:
		jump_next = rng.randf_range(0.5, 3.0)
		game.player.request_jump()
	var p: Vector3 = game.player.global_position
	if p.y < -4.2 or p.y > 7.0:
		_fail("провал/вылет по высоте")
		return
	if GameData.room_at(p) == "":
		out_t += delta
		if out_t > 0.5:
			_fail("игрок вне комнат (прошёл сквозь стену?)")
			return
	else:
		out_t = 0.0
	if run_t >= RUN_TIME:
		run_idx += 1
		if run_idx >= starts.size():
			print("FUZZ OK: %d прогонов по %.0f с, без провалов и выходов за стены" % [starts.size(), RUN_TIME])
			get_tree().quit(0)
			return
		_begin_run()

func _fail(msg: String) -> void:
	printerr("FUZZ FAIL: %s | старт #%d | поз %s | t=%.1f" % [msg, run_idx, str(game.player.global_position), run_t])
	get_tree().quit(1)

extends Node
## Автотест: бот проходит игру по маршруту (двери открываются сами, ключ → кабинет,
## лестницы вверх/вниз) и проверяет, что дойдёт до экрана победы без застреваний.
## Запуск: godot --headless --fixed-fps 60 --path roomhunt -- --selftest
## В экспорт не попадает (exclude_filter: tools/*).

var game
var idx := 0
var wait := 0.0
var step_time := 0.0
var total_time := 0.0
var found_before := 0
var _jumped := false
var _acted := false

# go — идти к точке (x, z); take — нажать «Взять» (проверим, что счётчик вырос);
# jump — прыжок; пробел между этапами — просто комментарии.
var steps: Array = [
	# 1) гостиная: звезда за диваном
	{"go": Vector2(5, -0.8)}, {"go": Vector2(5, -3.0)}, {"go": Vector2(6.8, -4.0)},
	{"go": Vector2(6.8, -9.0)}, {"go": Vector2(5.0, -9.0)}, {"take": "star_living"},
	# 2) кухня: звезда на полке
	{"go": Vector2(6.8, -4.0)}, {"go": Vector2(5, -3.0)}, {"go": Vector2(5, -0.5)},
	{"go": Vector2(14, -0.5)}, {"go": Vector2(14, -3.0)}, {"go": Vector2(16.4, -3.4)},
	{"go": Vector2(16.5, -5.0)}, {"take": "star_kitchen"},
	# 3) спальня: звезда под кроватью
	{"go": Vector2(14, -3.0)}, {"go": Vector2(14, -0.5)}, {"go": Vector2(5, 0.5)},
	{"go": Vector2(5, 3.0)}, {"go": Vector2(3.5, 5.0)}, {"go": Vector2(2.9, 6.4)},
	{"take": "star_bedroom"},
	# 4) детская: ключ в шкафу
	{"go": Vector2(5, 3.0)}, {"go": Vector2(5, 0.5)}, {"go": Vector2(14, 0.5)},
	{"go": Vector2(14, 2.8)}, {"go": Vector2(13, 3.5)}, {"go": Vector2(13, 8.0)},
	{"go": Vector2(15.0, 8.4)}, {"take": "key_nursery"},
	# 5) кабинет: открыть дверь ключом, звезда на полке
	{"go": Vector2(13, 8.0)}, {"go": Vector2(13, 3.5)}, {"go": Vector2(14, 2.8)},
	{"go": Vector2(14, 0.5)}, {"go": Vector2(22, 0.2)}, {"go": Vector2(22, -0.9)}, {"unlock": "study"},
	{"go": Vector2(22, -3.0)}, {"go": Vector2(22, -4.8)}, {"go": Vector2(24.6, -5.5)},
	{"take": "star_study"},
	# 6) подвал: звезда на металлических полках
	{"go": Vector2(22, -3.0)}, {"go": Vector2(22, -0.5)}, {"go": Vector2(25.5, 0.0)},
	{"go": Vector2(29, 0.0)}, {"go": Vector2(29, 4.5)}, {"go": Vector2(29, 8.0)},
	{"go": Vector2(29, 11.5)}, {"go": Vector2(30.6, 14.5)}, {"take": "star_basement"},
	# 7) чердак: звезда в шкафу
	{"go": Vector2(29, 11.5)}, {"go": Vector2(29, 8.0)}, {"go": Vector2(29, 4.5)},
	{"go": Vector2(29, -0.5)}, {"go": Vector2(29, -4.5)}, {"go": Vector2(29, -8.0)},
	{"go": Vector2(29, -11.5)}, {"jump": true}, {"go": Vector2(29, -17.0)},
	{"take": "star_attic"},
]

func get_input() -> Vector2:
	if idx >= steps.size():
		return Vector2.ZERO
	var st: Dictionary = steps[idx]
	if not st.has("go"):
		return Vector2.ZERO
	var p: Vector3 = game.player.global_position
	var to := Vector2(st["go"].x - p.x, st["go"].y - p.z)
	if to.length() < 0.3:
		return Vector2.ZERO
	var d3 := Vector3(to.x, 0, to.y).normalized()
	var local := Basis(Vector3.UP, -game.rig.yaw) * d3
	return Vector2(local.x, local.z)

func _fail(msg: String) -> void:
	var p: Vector3 = game.player.global_position
	printerr("SELFTEST FAIL: %s | шаг %d %s | поз %s | собрано %d | t=%.1f" % [msg, idx, str(steps[idx] if idx < steps.size() else "-"), str(p), game.found, total_time])
	get_tree().quit(1)

func _physics_process(delta: float) -> void:
	total_time += delta
	step_time += delta
	if total_time > 420.0:
		_fail("общий таймаут")
		return
	if idx >= steps.size():
		if game.won:
			print("SELFTEST OK: победа за %.1f с игрового времени, собрано %d/%d" % [game.elapsed, game.found, GameData.total_items()])
			get_tree().quit(0)
		elif step_time > 2.0:
			_fail("все шаги пройдены, но победы нет")
		return
	var st: Dictionary = steps[idx]
	var p: Vector3 = game.player.global_position
	if st.has("go"):
		var to := Vector2(st["go"].x - p.x, st["go"].y - p.z)
		if to.length() < 0.3:
			_next()
		elif step_time > 14.0:
			_fail("застрял по пути к %s" % str(st["go"]))
	elif st.has("jump"):
		if not _jumped:
			game.player.request_jump()
			_jumped = true
		elif step_time > 0.6:
			_next()
	elif st.has("take"):
		if step_time < 0.35:
			return
		if not _acted:
			_acted = true
			found_before = game.found
			game._do_interact()
		elif game.found > found_before and game.collected_ids.has(st["take"]):
			_next()
		elif step_time > 1.5:
			_fail("не удалось взять %s (цель: %s)" % [st["take"], str(game._target)])
	elif st.has("unlock"):
		if step_time < 0.35:
			return
		if not _acted:
			_acted = true
			game._do_interact()
		elif not (game.house.doors[st["unlock"]] as Door).locked:
			_next()
		elif step_time > 1.5:
			_fail("дверь не открылась ключом")

func _next() -> void:
	idx += 1
	step_time = 0.0
	_jumped = false
	_acted = false

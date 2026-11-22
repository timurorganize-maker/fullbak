class_name TouchControls
extends Control
## Сенсорное управление: плавающий виртуальный джойстик слева, свайп справа — поворот
## камеры, кнопки «Прыжок» и «Взять». Каждый палец обрабатывается отдельно (мультитач).
## На ПК, где нет тачскрина, то же самое работает мышью.

signal jump_pressed
signal interact_pressed

const JOY_RADIUS := 95.0

var move_vec := Vector2.ZERO
var take_label := ""            # пусто — кнопка «Взять» скрыта
var active := true:
	set(v):
		active = v
		if not v:
			_release_all()
		queue_redraw()

var _look_accum := Vector2.ZERO
var _joy_id := -99
var _joy_center := Vector2.ZERO
var _joy_pos := Vector2.ZERO
var _look_id := -99
var _jump_id := -99
var _take_id := -99
var _use_mouse := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_use_mouse = not DisplayServer.is_touchscreen_available()
	# родитель — CanvasLayer, поэтому якоря не работают: растягиваем на видимую область сами
	_fit()
	get_viewport().size_changed.connect(_fit)

func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	queue_redraw()

func consume_look() -> Vector2:
	var v := _look_accum
	_look_accum = Vector2.ZERO
	return v

func set_take(label: String) -> void:
	if label != take_label:
		take_label = label
		queue_redraw()

# --- геометрия кнопок ----------------------------------------------------------

func _unit() -> float:
	return maxf(size.y, 1.0) / 576.0

func _jump_center() -> Vector2:
	return Vector2(size.x - 140.0 * _unit(), size.y - 125.0 * _unit())

func _jump_radius() -> float:
	return 66.0 * _unit()

func _take_center() -> Vector2:
	return Vector2(size.x - 310.0 * _unit(), size.y - 95.0 * _unit())

func _take_radius() -> float:
	return 58.0 * _unit()

func _joy_idle_center() -> Vector2:
	return Vector2(165.0 * _unit(), size.y - 140.0 * _unit())

# --- ввод ----------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			_down(e.index, e.position)
		else:
			_up(e.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		_move(d.index, d.position, d.relative)
	elif _use_mouse:
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var mb := event as InputEventMouseButton
			if mb.pressed:
				_down(-1, mb.position)
			else:
				_up(-1)
		elif event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
			var mm := event as InputEventMouseMotion
			_move(-1, mm.position, mm.relative)

func _down(id: int, pos: Vector2) -> void:
	if _jump_id == -99 and pos.distance_to(_jump_center()) <= _jump_radius() * 1.25:
		_jump_id = id
		jump_pressed.emit()
	elif take_label != "" and _take_id == -99 and pos.distance_to(_take_center()) <= _take_radius() * 1.3:
		_take_id = id
		interact_pressed.emit()
	elif pos.x < size.x * 0.45 and _joy_id == -99:
		_joy_id = id
		_joy_center = pos
		_joy_pos = pos
		move_vec = Vector2.ZERO
	elif pos.x >= size.x * 0.45 and _look_id == -99:
		_look_id = id
	queue_redraw()

func _move(id: int, pos: Vector2, rel: Vector2) -> void:
	if id == _joy_id:
		_joy_pos = pos
		var off := pos - _joy_center
		if off.length() > JOY_RADIUS * _unit():
			# «тянем» центр за пальцем, как в плавающем джойстике
			_joy_center = pos - off.normalized() * JOY_RADIUS * _unit()
			off = pos - _joy_center
		var v := off / (JOY_RADIUS * _unit())
		var m := v.length()
		if m < 0.12:
			move_vec = Vector2.ZERO
		else:
			move_vec = v.normalized() * clampf((m - 0.12) / 0.88, 0.0, 1.0)
		queue_redraw()
	elif id == _look_id:
		_look_accum += rel

func _up(id: int) -> void:
	if id == _joy_id:
		_joy_id = -99
		move_vec = Vector2.ZERO
	elif id == _look_id:
		_look_id = -99
	elif id == _jump_id:
		_jump_id = -99
	elif id == _take_id:
		_take_id = -99
	queue_redraw()

func _release_all() -> void:
	_joy_id = -99
	_look_id = -99
	_jump_id = -99
	_take_id = -99
	move_vec = Vector2.ZERO

# --- отрисовка -----------------------------------------------------------------

func _draw() -> void:
	if not active or size.y < 50.0:
		return
	var u := _unit()
	var font := ThemeDB.fallback_font
	# джойстик
	var base := _joy_center if _joy_id != -99 else _joy_idle_center()
	var knob := _joy_pos if _joy_id != -99 else base
	draw_circle(base, JOY_RADIUS * u, Color(1, 1, 1, 0.10))
	draw_arc(base, JOY_RADIUS * u, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 3.0 * u, true)
	draw_circle(knob, 40.0 * u, Color(1, 1, 1, 0.38 if _joy_id != -99 else 0.22))
	# прыжок
	var jc := _jump_center()
	var jp := _jump_id != -99
	draw_circle(jc, _jump_radius(), Color(0.3, 0.6, 1.0, 0.55 if jp else 0.32))
	draw_arc(jc, _jump_radius(), 0.0, TAU, 40, Color(1, 1, 1, 0.55), 3.0 * u, true)
	draw_string(font, jc + Vector2(-_jump_radius(), 9.0 * u), "Прыжок", HORIZONTAL_ALIGNMENT_CENTER,
		_jump_radius() * 2.0, int(24 * u), Color(1, 1, 1, 0.95))
	# взять
	if take_label != "":
		var tc := _take_center()
		var tp := _take_id != -99
		draw_circle(tc, _take_radius(), Color(1.0, 0.75, 0.2, 0.85 if tp else 0.62))
		draw_arc(tc, _take_radius(), 0.0, TAU, 40, Color(1, 1, 1, 0.9), 3.5 * u, true)
		draw_string(font, tc + Vector2(-_take_radius(), 9.0 * u), take_label, HORIZONTAL_ALIGNMENT_CENTER,
			_take_radius() * 2.0, int(26 * u), Color(0.12, 0.08, 0.02))

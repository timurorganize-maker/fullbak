class_name Hud
extends CanvasLayer
## HUD, собранный кодом: счётчик «найдено N из M», подсказка о следующей комнате,
## название текущей комнаты, таймер, всплывающие сообщения и экран победы.

signal restart_pressed

var _count: Label
var _hint: Label
var _room: Label
var _time: Label
var _toast: Label
var _toast_tween: Tween
var _win: Control
var _win_stats: Label
var _win_time: Label

func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# --- левый верхний угол: счётчик и подсказка
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color(0.06, 0.05, 0.1, 0.62), 16, 14))
	panel.position = Vector2(24, 18)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)
	_count = _label("", 30, Color(1.0, 0.86, 0.35))
	vb.add_child(_count)
	_hint = _label("", 20, Color(0.92, 0.92, 0.95))
	_hint.custom_minimum_size = Vector2(380, 0)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_hint)

	# --- центр сверху: комната
	_room = _label("", 24, Color(1, 1, 1))
	_room.add_theme_stylebox_override("normal", _box(Color(0.06, 0.05, 0.1, 0.5), 12, 8))
	_room.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_room.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_room.position.y = 18
	root.add_child(_room)

	# --- правый верхний угол: время
	_time = _label("00:00", 26, Color(1, 1, 1))
	_time.add_theme_stylebox_override("normal", _box(Color(0.06, 0.05, 0.1, 0.5), 12, 8))
	_time.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_time.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_time.position = Vector2(-24, 18)
	root.add_child(_time)

	# --- сообщение внизу по центру
	_toast = _label("", 26, Color(1, 1, 1))
	_toast.add_theme_stylebox_override("normal", _box(Color(0.1, 0.07, 0.15, 0.82), 16, 12))
	_toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast.position.y = -210
	_toast.modulate.a = 0.0
	root.add_child(_toast)

	_build_win(root)

func _label(t: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _box(c: Color, radius: int, pad: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad + 4
	sb.content_margin_right = pad + 4
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	return sb

func _build_win(root: Control) -> void:
	_win = Control.new()
	_win.set_anchors_preset(Control.PRESET_FULL_RECT)
	_win.visible = false
	root.add_child(_win)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.08, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_win.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_win.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color(0.16, 0.12, 0.26, 0.97), 28, 32))
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	panel.add_child(vb)
	vb.add_child(_label("Победа!", 56, Color(1.0, 0.86, 0.35)))
	_win_stats = _label("", 30, Color(1, 1, 1))
	vb.add_child(_win_stats)
	_win_time = _label("", 34, Color(0.75, 0.95, 1.0))
	vb.add_child(_win_time)
	var btn := Button.new()
	btn.text = "Играть снова"
	btn.custom_minimum_size = Vector2(340, 84)
	btn.add_theme_font_size_override("font_size", 34)
	btn.pressed.connect(func(): restart_pressed.emit())
	vb.add_child(btn)

# --- API ----------------------------------------------------------------------

func set_count(n: int, total: int) -> void:
	_count.text = "Найдено: %d из %d" % [n, total]

func set_hint(text: String) -> void:
	_hint.text = text

func set_room(text: String) -> void:
	_room.text = text
	_room.visible = text != ""

func set_time(seconds: float) -> void:
	_time.text = format_time(seconds)

static func format_time(seconds: float) -> String:
	var s := int(seconds)
	return "%02d:%02d" % [s / 60, s % 60]

func toast(text: String, duration := 2.6) -> void:
	_toast.text = text
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(duration)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)

func show_win(seconds: float, found: int, total: int) -> void:
	_win_stats.text = "Найдено: %d из %d" % [found, total]
	_win_time.text = "Время: %s" % format_time(seconds)
	_win.visible = true

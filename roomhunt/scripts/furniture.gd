class_name Furniture
extends RefCounted
## Мебель и декор из примитивов (коробки/цилиндры/сферы). Бесплатных 3D-моделей мебели
## из заблокированных источников скачать не удалось, поэтому интерьер собран кодом.
## Каждая комната — отдельная функция; координаты мировые (см. GameData.ROOMS).
## Мелкий декор делается без коллизии (collide = false), чтобы персонаж не застревал.

static func build(b: HouseBuilder) -> void:
	_hall(b)
	_living(b)
	_kitchen(b)
	_study(b)
	_bedroom(b)
	_nursery(b)
	_lobby(b)
	_attic(b)
	_basement(b)

# --- помощники ---------------------------------------------------------------

static func _dk(c: Color, f: float) -> Color:
	return Color(c.r * f, c.g * f, c.b * f)

static func _xf(p: Vector3, rot: float, local: Vector3) -> Vector3:
	return p + Basis(Vector3.UP, rot) * local

static func _rug(b: HouseBuilder, c: Vector3, size: Vector2, col: Color) -> void:
	b.box(c + Vector3(0, 0.012, 0), Vector3(size.x, 0.024, size.y), col, false)
	b.box(c + Vector3(0, 0.014, 0), Vector3(size.x - 0.3, 0.024, size.y - 0.3), _dk(col, 1.18), false)

static func _round_rug(b: HouseBuilder, c: Vector3, radius: float, col: Color) -> void:
	b.cyl(c, radius, 0.024, col, false)
	b.cyl(c + Vector3(0, 0.002, 0), radius * 0.7, 0.024, _dk(col, 1.2), false)

static func _picture(b: HouseBuilder, p: Vector3, size: Vector2, facing_x: bool, col: Color) -> void:
	var frame := Color(0.25, 0.17, 0.10)
	if facing_x:
		b.box(p, Vector3(0.05, size.y, size.x), frame, false)
		b.box(p, Vector3(0.06, size.y - 0.1, size.x - 0.1), col, false)
	else:
		b.box(p, Vector3(size.x, size.y, 0.05), frame, false)
		b.box(p, Vector3(size.x - 0.1, size.y - 0.1, 0.06), col, false)

## Стул. p — центр на полу, rot — поворот вокруг Y (спинка в локальном -Z).
static func _chair(b: HouseBuilder, p: Vector3, rot: float, col: Color) -> void:
	var leg := _dk(col, 0.7)
	b.box(_xf(p, rot, Vector3(0, 0.45, 0)), Vector3(0.45, 0.06, 0.45), col, false, 2, rot)
	b.box(_xf(p, rot, Vector3(0, 0.78, -0.2)), Vector3(0.45, 0.6, 0.06), col, false, 2, rot)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			b.box(_xf(p, rot, Vector3(sx * 0.19, 0.21, sz * 0.19)), Vector3(0.05, 0.42, 0.05), leg, false, 2, rot)
	b.collider(p + Vector3(0, 0.25, 0), Vector3(0.45, 0.5, 0.45))

static func _table(b: HouseBuilder, p: Vector3, size: Vector3, col: Color) -> void:
	# p — центр на полу; size.y — высота столешницы над полом
	var top_t := 0.06
	b.box(p + Vector3(0, size.y - top_t * 0.5, 0), Vector3(size.x, top_t, size.z), col, false)
	var leg := _dk(col, 0.75)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			b.box(p + Vector3(sx * (size.x * 0.5 - 0.07), (size.y - top_t) * 0.5, sz * (size.z * 0.5 - 0.07)),
				Vector3(0.07, size.y - top_t, 0.07), leg, false)
	b.collider(p + Vector3(0, size.y * 0.5, 0), size)

## Книжный шкаф у стены. p — центр на полу, size — (x, y, z). Ряды книг (случайные цвета).
## gap_z — полоса вдоль z (центр, ширина), где на ряду книги не ставятся.
static func _bookshelf(b: HouseBuilder, p: Vector3, size: Vector3, col: Color, rows: Array,
		books_along_z: bool, gap := Vector2(-999, 0), gap_row := -1) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(p.x * 100.0 + p.z * 10.0 + p.y)
	var t := 0.05
	# каркас: задняя стенка и боковины, доски полок
	if books_along_z:
		# стеллаж вдоль оси Z (стоит у стены X): глубина — size.x
		b.box(p + Vector3(0, size.y * 0.5, 0), Vector3(size.x, size.y, size.z), _dk(col, 0.78), false)
		for i in rows.size():
			var ry: float = rows[i]
			b.box(p + Vector3(0, ry, 0), Vector3(size.x, 0.05, size.z), col, false)
			var z := -size.z * 0.5 + 0.08
			while z < size.z * 0.5 - 0.1:
				var w := rng.randf_range(0.04, 0.09)
				var hgt := rng.randf_range(0.2, 0.34)
				var wz := p.z + z + w * 0.5
				if not (i == gap_row and absf(wz - gap.x) < gap.y):
					b.box(Vector3(p.x, p.y + ry + 0.025 + hgt * 0.5, wz),
						Vector3(size.x * 0.7, hgt, w), Color.from_hsv(rng.randf(), 0.45, rng.randf_range(0.45, 0.8)), false)
				z += w + 0.005
		b.collider(p + Vector3(0, size.y * 0.5, 0), size)
	else:
		b.box(p + Vector3(0, size.y * 0.5, 0), Vector3(size.x, size.y, size.z), _dk(col, 0.78), false)
		for i in rows.size():
			var ry: float = rows[i]
			b.box(p + Vector3(0, ry, 0), Vector3(size.x, 0.05, size.z), col, false)
			var x := -size.x * 0.5 + 0.08
			while x < size.x * 0.5 - 0.1:
				var w := rng.randf_range(0.04, 0.09)
				var hgt := rng.randf_range(0.2, 0.34)
				b.box(Vector3(p.x + x + w * 0.5, p.y + ry + 0.025 + hgt * 0.5, p.z),
					Vector3(w, hgt, size.z * 0.7), Color.from_hsv(rng.randf(), 0.45, rng.randf_range(0.45, 0.8)), false)
				x += w + 0.005
		b.collider(p + Vector3(0, size.y * 0.5, 0), size)
	# боковины и верх (чуть выступают, чтобы «рамка» читалась)
	if books_along_z:
		b.box(p + Vector3(0, size.y - 0.025, 0), Vector3(size.x + 0.04, 0.05, size.z + 0.04), col, false)
	else:
		b.box(p + Vector3(0, size.y - 0.025, 0), Vector3(size.x + 0.04, 0.05, size.z + 0.04), col, false)

static func _crate(b: HouseBuilder, p: Vector3, s: float, col: Color, rot := 0.0, collide := true) -> void:
	b.box(p + Vector3(0, s * 0.5, 0), Vector3.ONE * s, col, collide, 2, rot)
	var band := _dk(col, 0.7)
	b.box(p + Vector3(0, s * 0.5, 0), Vector3(s + 0.02, 0.07 * s / 0.8 * 0.5, s + 0.02), band, false, 2, rot)

static func _plant(b: HouseBuilder, p: Vector3, scale := 1.0) -> void:
	b.cyl(p, 0.2 * scale, 0.35 * scale, Color(0.65, 0.35, 0.22), true)
	b.sphere(p + Vector3(0, 0.75 * scale, 0), 0.38 * scale, Color(0.22, 0.5, 0.25), false)
	b.sphere(p + Vector3(0.1 * scale, 1.0 * scale, 0.05 * scale), 0.25 * scale, Color(0.28, 0.58, 0.28), false)

# --- коридор -----------------------------------------------------------------

static func _hall(b: HouseBuilder) -> void:
	_rug(b, Vector3(13.0, 0, 0), Vector2(23.0, 1.5), Color(0.55, 0.16, 0.18))
	_picture(b, Vector3(9.5, 1.6, -1.64), Vector2(1.0, 0.7), false, Color(0.45, 0.65, 0.8))
	_picture(b, Vector3(18.5, 1.6, -1.64), Vector2(0.8, 0.9), false, Color(0.8, 0.55, 0.4))
	_picture(b, Vector3(9.5, 1.6, 1.64), Vector2(1.2, 0.7), false, Color(0.55, 0.75, 0.5))
	_picture(b, Vector3(18.5, 1.6, 1.64), Vector2(0.7, 0.9), false, Color(0.75, 0.7, 0.4))
	_plant(b, Vector3(0.55, 0, 1.2), 0.9)
	_plant(b, Vector3(25.2, 0, -1.2), 0.9)
	# консоль у стены
	_table(b, Vector3(7.5, 0, -1.4), Vector3(1.2, 0.8, 0.4), Color(0.4, 0.27, 0.16))

# --- гостиная ----------------------------------------------------------------

static func _living(b: HouseBuilder) -> void:
	var fabric := Color(0.62, 0.27, 0.24)
	_rug(b, Vector3(5.0, 0, -5.6), Vector2(4.6, 3.2), Color(0.30, 0.34, 0.50))
	# диван: спинкой к северной стене, за ним остаётся проход ~1.2 м с предметом
	b.box(Vector3(4.0, 0.72, -8.31), Vector3(3.2, 0.55, 0.28), fabric, false)
	b.box(Vector3(4.0, 0.22, -7.75), Vector3(3.2, 0.44, 0.85), _dk(fabric, 1.1), false)
	b.box(Vector3(4.0, 0.5, -7.8), Vector3(2.6, 0.12, 0.7), _dk(fabric, 1.25), false)
	b.box(Vector3(2.54, 0.32, -7.89), Vector3(0.28, 0.64, 1.13), _dk(fabric, 0.85), false)
	b.box(Vector3(5.46, 0.32, -7.89), Vector3(0.28, 0.64, 1.13), _dk(fabric, 0.85), false)
	b.collider(Vector3(4.0, 0.5, -7.89), Vector3(3.2, 1.0, 1.13))
	for i in 2:
		b.box(Vector3(3.5 + i * 1.0, 0.7, -8.05), Vector3(0.4, 0.4, 0.14), Color(0.9, 0.72, 0.4), false, 2, 0.2)
	# журнальный столик
	_table(b, Vector3(4.0, 0, -5.8), Vector3(1.4, 0.42, 0.75), Color(0.35, 0.23, 0.14))
	# кресло
	b.box(Vector3(1.4, 0.25, -4.4), Vector3(0.95, 0.5, 0.95), _dk(fabric, 0.9), false)
	b.box(Vector3(0.98, 0.65, -4.4), Vector3(0.2, 0.8, 0.95), _dk(fabric, 0.8), false)
	b.collider(Vector3(1.3, 0.45, -4.4), Vector3(1.0, 0.9, 0.95))
	# ТВ-тумба
	b.box(Vector3(9.65, 0.25, -5.7), Vector3(0.5, 0.5, 2.0), Color(0.3, 0.2, 0.12), true)
	b.box(Vector3(9.72, 0.95, -5.7), Vector3(0.08, 0.8, 1.4), Color(0.05, 0.05, 0.07), false)
	b.box(Vector3(9.68, 0.95, -5.7), Vector3(0.04, 0.7, 1.3), Color(0.1, 0.16, 0.22), false, 2, 0.0, 0.5)
	# книжный шкаф у западной стены
	_bookshelf(b, Vector3(0.3, 0, -6.0), Vector3(0.4, 1.9, 2.2), Color(0.42, 0.28, 0.16),
		[0.0, 0.5, 0.95, 1.4, 1.85], true)
	_plant(b, Vector3(9.2, 0, -9.2))
	_picture(b, Vector3(4.0, 1.6, -9.62), Vector2(1.4, 0.9), false, Color(0.4, 0.55, 0.7))

# --- кухня -------------------------------------------------------------------

static func _kitchen(b: HouseBuilder) -> void:
	var cab := Color(0.88, 0.85, 0.78)
	var top := Color(0.25, 0.25, 0.28)
	# столешница с тумбами вдоль северной стены
	b.box(Vector3(13.45, 0.45, -9.38), Vector3(6.3, 0.9, 0.7), cab, true)
	b.box(Vector3(13.45, 0.93, -9.38), Vector3(6.34, 0.06, 0.74), top, false)
	b.box(Vector3(12.2, 0.94, -9.38), Vector3(0.9, 0.02, 0.5), Color(0.6, 0.62, 0.65), false)  # мойка
	# верхние шкафчики
	b.box(Vector3(12.9, 1.95, -9.52), Vector3(4.6, 0.7, 0.36), _dk(cab, 0.93), false)
	# холодильник
	b.box(Vector3(17.2, 0.95, -9.25), Vector3(0.9, 1.9, 0.8), Color(0.85, 0.88, 0.9), true)
	b.box(Vector3(17.2, 1.1, -8.84), Vector3(0.05, 0.6, 0.05), Color(0.5, 0.5, 0.55), false)
	# обеденный стол и стулья
	_table(b, Vector3(13.5, 0, -5.3), Vector3(1.8, 0.76, 1.1), Color(0.55, 0.38, 0.22))
	_chair(b, Vector3(13.0, 0, -6.3), 0.0, Color(0.7, 0.45, 0.3))
	_chair(b, Vector3(14.0, 0, -6.3), 0.0, Color(0.7, 0.45, 0.3))
	_chair(b, Vector3(13.0, 0, -4.3), PI, Color(0.7, 0.45, 0.3))
	_chair(b, Vector3(14.0, 0, -4.3), PI, Color(0.7, 0.45, 0.3))
	b.cyl(Vector3(13.5, 0.76, -5.3), 0.12, 0.15, Color(0.8, 0.3, 0.3), false)  # ваза
	# полка на восточной стене (на ней — звезда)
	var board := Color(0.45, 0.30, 0.18)
	b.box(Vector3(17.76, 1.5, -5.5), Vector3(0.36, 0.05, 2.4), board, false)
	b.box(Vector3(17.84, 1.38, -6.5), Vector3(0.2, 0.2, 0.05), _dk(board, 0.8), false)
	b.box(Vector3(17.84, 1.38, -4.5), Vector3(0.2, 0.2, 0.05), _dk(board, 0.8), false)
	b.cyl(Vector3(17.74, 1.525, -6.35), 0.09, 0.24, Color(0.7, 0.25, 0.2), false)
	b.cyl(Vector3(17.74, 1.525, -6.0), 0.07, 0.18, Color(0.35, 0.6, 0.35), false)
	b.cyl(Vector3(17.74, 1.525, -4.2), 0.1, 0.2, Color(0.9, 0.8, 0.45), false)
	_plant(b, Vector3(10.6, 0, -9.3), 0.8)
	_rug(b, Vector3(13.5, 0, -5.3), Vector2(3.0, 2.2), Color(0.75, 0.62, 0.45))

# --- кабинет (заперт) --------------------------------------------------------

static func _study(b: HouseBuilder) -> void:
	var wood := Color(0.45, 0.29, 0.17)
	_rug(b, Vector3(22.0, 0, -5.4), Vector2(4.4, 3.0), Color(0.5, 0.15, 0.15))
	# стол у северной стены
	_table(b, Vector3(22.0, 0, -9.2), Vector3(2.0, 0.76, 0.8), wood)
	b.box(Vector3(22.0, 0.78, -9.3), Vector3(0.5, 0.03, 0.35), Color(0.85, 0.85, 0.8), false)
	b.box(Vector3(22.7, 1.0, -9.35), Vector3(0.12, 0.45, 0.12), Color(0.2, 0.2, 0.22), false)
	b.box(Vector3(22.7, 1.22, -9.25), Vector3(0.26, 0.05, 0.26), Color(1.0, 0.85, 0.5), false, 2, 0.0, 1.4)
	_chair(b, Vector3(22.0, 0, -8.35), PI, Color(0.5, 0.2, 0.2))
	# книжный шкаф у восточной стены: на средней полке (y=1.2) лежит звезда
	_bookshelf(b, Vector3(25.7, 0, -5.5), Vector3(0.4, 2.0, 3.0), wood,
		[0.3, 0.75, 1.2, 1.65], true, Vector2(-5.5, 0.5), 2)
	# шкаф у западной стены
	_bookshelf(b, Vector3(18.3, 0, -6.0), Vector3(0.4, 2.0, 2.6), wood,
		[0.3, 0.75, 1.2, 1.65], true)
	# глобус
	b.cyl(Vector3(19.4, 0, -9.0), 0.2, 0.7, wood, true)
	b.sphere(Vector3(19.4, 0.95, -9.0), 0.28, Color(0.25, 0.45, 0.7), false)
	# кресло
	b.box(Vector3(24.4, 0.25, -3.3), Vector3(0.95, 0.5, 0.95), Color(0.2, 0.32, 0.25), false)
	b.box(Vector3(24.4, 0.65, -2.88), Vector3(0.95, 0.8, 0.2), Color(0.18, 0.28, 0.22), false)
	b.collider(Vector3(24.4, 0.45, -3.2), Vector3(1.0, 0.9, 1.0))

# --- спальня -----------------------------------------------------------------

static func _bedroom(b: HouseBuilder) -> void:
	var wood := Color(0.50, 0.33, 0.20)
	_rug(b, Vector3(5.0, 0, 5.8), Vector2(3.2, 2.4), Color(0.62, 0.45, 0.62))
	# кровать: изголовье у западной стены, ножки высокие — под кроватью лежит звезда
	for sx in [0.3, 2.3]:
		for sz in [5.55, 7.25]:
			b.box(Vector3(sx, 0.225, sz), Vector3(0.1, 0.45, 0.1), _dk(wood, 0.8), false)
	b.box(Vector3(1.3, 0.49, 6.4), Vector3(2.2, 0.08, 1.9), wood, false)
	b.box(Vector3(1.38, 0.66, 6.4), Vector3(2.0, 0.26, 1.8), Color(0.92, 0.9, 0.85), false)
	b.box(Vector3(1.85, 0.8, 6.4), Vector3(1.3, 0.08, 1.84), Color(0.35, 0.4, 0.7), false)
	b.box(Vector3(0.16, 0.55, 6.4), Vector3(0.1, 1.1, 1.95), wood, false)
	b.box(Vector3(0.66, 0.85, 5.95), Vector3(0.45, 0.14, 0.7), Color(0.95, 0.95, 0.98), false)
	b.box(Vector3(0.66, 0.85, 6.85), Vector3(0.45, 0.14, 0.7), Color(0.95, 0.95, 0.98), false)
	b.collider(Vector3(1.3, 0.4, 6.4), Vector3(2.2, 0.8, 1.95))
	# тумбочка с лампой
	b.box(Vector3(0.4, 0.25, 4.95), Vector3(0.5, 0.5, 0.5), wood, true)
	b.cyl(Vector3(0.4, 0.5, 4.95), 0.1, 0.25, Color(1.0, 0.85, 0.55), false, 1.3)
	# шкаф-купе у южной стены (декор, закрытый)
	b.box(Vector3(7.3, 1.05, 9.3), Vector3(1.9, 2.1, 0.65), Color(0.78, 0.7, 0.58), true)
	b.box(Vector3(7.3, 1.05, 8.96), Vector3(0.03, 1.9, 0.03), Color(0.4, 0.3, 0.2), false)
	b.box(Vector3(6.9, 1.0, 8.96), Vector3(0.05, 0.3, 0.04), Color(0.9, 0.75, 0.3), false)
	b.box(Vector3(7.7, 1.0, 8.96), Vector3(0.05, 0.3, 0.04), Color(0.9, 0.75, 0.3), false)
	# комод у восточной стены
	b.box(Vector3(9.65, 0.45, 6.0), Vector3(0.5, 0.9, 1.5), wood, true)
	for i in 3:
		b.box(Vector3(9.38, 0.2 + i * 0.28, 6.0), Vector3(0.03, 0.2, 1.3), _dk(wood, 1.15), false)
	_picture(b, Vector3(5.0, 1.7, 9.62), Vector2(1.3, 0.8), false, Color(0.85, 0.6, 0.5))
	_plant(b, Vector3(3.8, 0, 9.2), 0.9)

# --- детская -----------------------------------------------------------------

static func _nursery(b: HouseBuilder) -> void:
	_round_rug(b, Vector3(14.0, 0, 5.6), 1.6, Color(0.45, 0.7, 0.85))
	# шкаф с дверцами: внутри на полке лежит ключ
	b.cabinet(Vector3(15.6, 0, 9.3), Vector3(1.6, 2.0, 0.7), Color(0.55, 0.78, 0.55), -1.0, 0.9)
	# детская кроватка
	var wood := Color(0.85, 0.7, 0.5)
	b.box(Vector3(10.7, 0.3, 5.5), Vector3(1.0, 0.25, 1.9), wood, false)
	b.box(Vector3(10.7, 0.5, 5.5), Vector3(0.9, 0.2, 1.8), Color(0.95, 0.75, 0.8), false)
	b.box(Vector3(10.7, 0.55, 4.6), Vector3(1.0, 0.7, 0.06), wood, false)
	b.collider(Vector3(10.7, 0.4, 5.5), Vector3(1.0, 0.8, 1.9))
	# полка с игрушками у восточной стены
	b.box(Vector3(17.7, 0.6, 5.5), Vector3(0.4, 1.2, 1.8), Color(0.9, 0.55, 0.35), true)
	for i in 4:
		b.box(Vector3(17.5, 0.62 + (i % 2) * 0.5, 4.9 + i * 0.4), Vector3(0.15, 0.2, 0.25),
			Color.from_hsv(i * 0.22, 0.6, 0.95), false)
	# кубики и мяч
	var cols := [Color(0.9, 0.3, 0.3), Color(0.3, 0.6, 0.9), Color(0.95, 0.8, 0.2), Color(0.4, 0.8, 0.4)]
	var pos := [Vector3(13.2, 0, 6.2), Vector3(13.55, 0, 6.35), Vector3(13.4, 0.2, 6.25),
		Vector3(15.2, 0, 4.6)]
	for i in 4:
		b.box(pos[i] + Vector3(0, 0.1, 0), Vector3(0.2, 0.2, 0.2), cols[i], false, 2, i * 0.5)
	b.sphere(Vector3(12.4, 0.2, 4.2), 0.2, Color(0.95, 0.4, 0.5), false)
	# столик и стульчики
	_table(b, Vector3(14.6, 0, 3.6), Vector3(1.0, 0.5, 0.8), Color(0.9, 0.7, 0.4))
	_picture(b, Vector3(14.0, 1.7, 9.62), Vector2(1.0, 0.7), false, Color(0.5, 0.75, 0.9))
	_plant(b, Vector3(10.6, 0, 9.2), 0.7)

# --- холл и лестницы ---------------------------------------------------------

static func _lobby(b: HouseBuilder) -> void:
	_rug(b, Vector3(29.0, 0, 0), Vector2(3.2, 3.2), Color(0.5, 0.2, 0.18))
	_table(b, Vector3(31.4, 0, 0.0), Vector3(0.7, 0.8, 1.2), Color(0.38, 0.25, 0.15))
	b.cyl(Vector3(31.4, 0.8, 0.0), 0.12, 0.22, Color(0.3, 0.55, 0.8), false)
	b.add_sign("Чердак  ^", Vector3(26.12, 1.7, -2.9), PI / 2.0)
	b.add_sign("Подвал  v", Vector3(26.12, 1.7, 2.9), PI / 2.0)
	_picture(b, Vector3(31.88, 1.6, 0.0), Vector2(0.06, 0.7), true, Color(0.4, 0.4, 0.4))

# --- чердак ------------------------------------------------------------------

static func _attic(b: HouseBuilder) -> void:
	var y := 2.6
	_rug(b, Vector3(29.0, y, -14.5), Vector2(3.4, 2.6), Color(0.35, 0.22, 0.2))
	# старый шкаф: внутри на полке — звезда
	b.cabinet(Vector3(29.0, y, -18.05), Vector3(1.7, 2.2, 0.7), Color(0.45, 0.32, 0.22), 1.0, 0.9)
	# сундук
	b.box(Vector3(27.3, y + 0.25, -12.2), Vector3(1.1, 0.5, 0.6), Color(0.4, 0.26, 0.15), true)
	b.box(Vector3(27.3, y + 0.55, -12.2), Vector3(1.14, 0.12, 0.64), Color(0.33, 0.21, 0.12), false)
	b.box(Vector3(27.3, y + 0.35, -11.89), Vector3(0.12, 0.14, 0.04), Color(0.9, 0.75, 0.3), false)
	# ящики
	_crate(b, Vector3(31.2, y, -12.0), 0.8, Color(0.6, 0.45, 0.28), 0.2)
	_crate(b, Vector3(31.3, y + 0.8, -12.1), 0.55, Color(0.55, 0.4, 0.25), 0.5)
	_crate(b, Vector3(26.9, y, -17.4), 0.7, Color(0.58, 0.43, 0.27), 0.0)
	_crate(b, Vector3(27.7, y, -17.6), 0.6, Color(0.5, 0.38, 0.24), 0.3)
	# мебель под простынёй
	b.box(Vector3(31.0, y + 0.45, -16.4), Vector3(1.2, 0.9, 1.3), Color(0.88, 0.88, 0.85), true)
	b.sphere(Vector3(31.0, y + 0.95, -16.4), 0.45, Color(0.88, 0.88, 0.85), false)
	# манекен-швея
	b.cyl(Vector3(27.2, y, -14.8), 0.05, 1.1, Color(0.3, 0.2, 0.15), true)
	b.cyl(Vector3(27.2, y + 1.0, -14.8), 0.2, 0.5, Color(0.75, 0.6, 0.5), false)

# --- подвал ------------------------------------------------------------------

static func _basement(b: HouseBuilder) -> void:
	var y := -2.6
	var metal := Color(0.45, 0.48, 0.52)
	# металлический стеллаж у восточной стены: на средней полке — звезда
	for sz in [13.35, 15.65]:
		for sx in [31.45, 31.85]:
			b.box(Vector3(sx, y + 0.9, sz), Vector3(0.05, 1.8, 0.05), _dk(metal, 0.8), false)
	for sy in [0.5, 1.0, 1.5]:
		b.box(Vector3(31.65, y + sy, 14.5), Vector3(0.5, 0.05, 2.4), metal, false)
	b.collider(Vector3(31.65, y + 0.9, 14.5), Vector3(0.5, 1.8, 2.4))
	_crate(b, Vector3(31.65, y + 0.525, 13.7), 0.4, Color(0.6, 0.45, 0.28), 0.0, false)
	_crate(b, Vector3(31.65, y + 0.525, 15.4), 0.35, Color(0.5, 0.35, 0.22), 0.0, false)
	b.cyl(Vector3(31.65, y + 1.025, 15.3), 0.08, 0.2, Color(0.7, 0.2, 0.2), false)
	# бочки и ящики
	for p in [Vector3(27.0, y, 17.5), Vector3(27.8, y, 17.7), Vector3(27.4, y, 16.7)]:
		b.cyl(p, 0.36, 0.95, Color(0.45, 0.3, 0.18), true)
		b.cyl(p + Vector3(0, 0.3, 0), 0.375, 0.06, Color(0.3, 0.3, 0.32), false)
	_crate(b, Vector3(30.2, y, 17.4), 0.9, Color(0.55, 0.42, 0.27), 0.15)
	_crate(b, Vector3(30.4, y + 0.9, 17.3), 0.6, Color(0.5, 0.38, 0.24), 0.6)
	_crate(b, Vector3(31.1, y, 17.5), 0.7, Color(0.6, 0.45, 0.3), 0.0)
	# котёл
	b.cyl(Vector3(27.1, y, 11.7), 0.55, 1.7, Color(0.55, 0.57, 0.6), true)
	b.cyl(Vector3(27.1, y + 1.7, 11.7), 0.2, 0.4, Color(0.3, 0.3, 0.32), false)
	b.box(Vector3(27.1, y + 1.0, 12.27), Vector3(0.3, 0.2, 0.05), Color(0.9, 0.3, 0.2), false, 2, 0.0, 0.8)

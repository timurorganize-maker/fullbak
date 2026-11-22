class_name GameData
extends RefCounted
## Вся «карта» игры в виде данных: комнаты, стены с дверями, предметы.
## Чтобы поменять планировку или предметы — правь этот файл (мебель — в furniture.gd).
##
## Система координат: X — на восток, Z — на юг (вперёд при взгляде «сверху»), Y — вверх.
## Комната: rect = Rect2(x, z, ширина_по_x, глубина_по_z).

const WALL_T := 0.2        # толщина стен
const WALL_H := 2.8        # высота стен
const DOOR_W := 1.3        # ширина дверного проёма
const DOOR_H := 2.15       # высота двери
const FLOOR_T := 0.3       # толщина плиты пола

const SPAWN := Vector3(2.0, 0.15, 0.0)
const SPAWN_YAW := -PI / 2.0   # камера смотрит на восток вдоль коридора

# --- палитра -----------------------------------------------------------------
const C_WALL := Color(0.90, 0.83, 0.72)
const C_WALL_HALL := Color(0.86, 0.78, 0.66)
const C_WALL_LIVING := Color(0.93, 0.80, 0.62)
const C_WALL_KITCHEN := Color(0.74, 0.84, 0.74)
const C_WALL_STUDY := Color(0.42, 0.55, 0.47)
const C_WALL_BED := Color(0.80, 0.74, 0.88)
const C_WALL_NURSERY := Color(0.72, 0.85, 0.94)
const C_WALL_STAIRS := Color(0.78, 0.70, 0.60)
const C_WALL_ATTIC := Color(0.58, 0.46, 0.35)
const C_WALL_BASEMENT := Color(0.46, 0.50, 0.56)

# --- комнаты -----------------------------------------------------------------
# lamps: торшеры (x, y_пола, z) — тёплый свет OmniLight3D.
# ramp:  комната-лестница (пол — наклонный пандус из точки z0,y0 в точку z1,y1).
const ROOMS := {
	"hall": {
		"name": "Коридор", "rect": Rect2(0, -1.75, 26, 3.5), "y": 0.0,
		"floor": Color(0.62, 0.50, 0.38),
		"lamps": [Vector3(1.0, 0, -1.3), Vector3(9.5, 0, 1.3), Vector3(18.0, 0, -1.3), Vector3(24.5, 0, 1.3)],
	},
	"living": {
		"name": "Гостиная", "rect": Rect2(0, -9.75, 10, 8), "y": 0.0,
		"floor": Color(0.55, 0.37, 0.23),
		"lamps": [Vector3(9.3, 0, -2.4)],
	},
	"kitchen": {
		"name": "Кухня", "rect": Rect2(10, -9.75, 8, 8), "y": 0.0,
		"floor": Color(0.82, 0.80, 0.72),
		"lamps": [Vector3(10.6, 0, -2.4)],
	},
	"study": {
		"name": "Кабинет", "rect": Rect2(18, -9.75, 8, 8), "y": 0.0,
		"floor": Color(0.34, 0.23, 0.16),
		"lamps": [Vector3(19.0, 0, -2.5)],
	},
	"bedroom": {
		"name": "Спальня", "rect": Rect2(0, 1.75, 10, 8), "y": 0.0,
		"floor": Color(0.47, 0.37, 0.50),
		"lamps": [Vector3(9.3, 0, 2.5)],
	},
	"nursery": {
		"name": "Детская", "rect": Rect2(10, 1.75, 8, 8), "y": 0.0,
		"floor": Color(0.90, 0.80, 0.55),
		"lamps": [Vector3(17.3, 0, 2.5)],
	},
	"lobby": {
		"name": "Холл", "rect": Rect2(26, -4, 6, 8), "y": 0.0,
		"floor": Color(0.58, 0.44, 0.30),
		"lamps": [Vector3(31.3, 0, -3.3), Vector3(31.3, 0, 3.3)],
	},
	"stairs_up": {
		"name": "Лестница на чердак", "rect": Rect2(26, -10.5, 6, 6.5), "y": 1.3,
		"ramp": {"z0": -10.5, "y0": 2.6, "z1": -4.0, "y1": 0.0},
		"floor": Color(0.60, 0.42, 0.28),
		"lamps": [Vector3(26.7, 1.32, -7.3)],
	},
	"attic": {
		"name": "Чердак", "rect": Rect2(26, -18.5, 6, 8), "y": 2.6,
		"floor": Color(0.40, 0.30, 0.20),
		"lamps": [Vector3(31.2, 2.6, -15.5)],
	},
	"stairs_down": {
		"name": "Лестница в подвал", "rect": Rect2(26, 4, 6, 6.5), "y": -1.3,
		"ramp": {"z0": 4.0, "y0": 0.0, "z1": 10.5, "y1": -2.6},
		"floor": Color(0.50, 0.40, 0.32),
		"lamps": [Vector3(26.7, -1.32, 7.3)],
	},
	"basement": {
		"name": "Подвал", "rect": Rect2(26, 10.5, 6, 8), "y": -2.6,
		"floor": Color(0.42, 0.42, 0.45),
		"lamps": [Vector3(27.0, -2.6, 17.4)],
	},
}

# --- стены -------------------------------------------------------------------
# a, b — концы стены (она строго вдоль оси X или Z, толщина WALL_T по центру линии).
# y0/h — низ и высота (по умолчанию 0 и WALL_H).
# doors: at — координата центра проёма вдоль стены; w — ширина; locked — заперта;
#        open — просто проём без створки; id — имя.
const WALLS := [
	# коридор: север (двери в гостиную, кухню, кабинет — кабинет заперт)
	{"a": Vector2(0, -1.75), "b": Vector2(26, -1.75), "color": C_WALL_HALL, "doors": [
		{"at": 5.0, "id": "living"}, {"at": 14.0, "id": "kitchen"},
		{"at": 22.0, "id": "study", "locked": true}]},
	# коридор: юг (спальня, детская)
	{"a": Vector2(0, 1.75), "b": Vector2(26, 1.75), "color": C_WALL_HALL, "doors": [
		{"at": 5.0, "id": "bedroom"}, {"at": 14.0, "id": "nursery"}]},
	# внешние стены
	{"a": Vector2(0, -9.75), "b": Vector2(26, -9.75), "color": C_WALL},
	{"a": Vector2(0, 9.75), "b": Vector2(26, 9.75), "color": C_WALL},
	{"a": Vector2(0, -9.75), "b": Vector2(0, 9.75), "color": C_WALL},
	# перегородки между комнатами
	{"a": Vector2(10, -9.75), "b": Vector2(10, -1.75), "color": C_WALL},
	{"a": Vector2(18, -9.75), "b": Vector2(18, -1.75), "color": C_WALL},
	{"a": Vector2(10, 1.75), "b": Vector2(10, 9.75), "color": C_WALL},
	{"a": Vector2(18, 1.75), "b": Vector2(18, 9.75), "color": C_WALL},
	# холл
	{"a": Vector2(26, -4), "b": Vector2(26, -1.75), "color": C_WALL_HALL},
	{"a": Vector2(26, 1.75), "b": Vector2(26, 4), "color": C_WALL_HALL},
	{"a": Vector2(32, -4), "b": Vector2(32, 4), "color": C_WALL_HALL},
	# лестница на чердак
	{"a": Vector2(26, -10.5), "b": Vector2(26, -4), "y0": 0.0, "h": 5.4, "color": C_WALL_STAIRS},
	{"a": Vector2(32, -10.5), "b": Vector2(32, -4), "y0": 0.0, "h": 5.4, "color": C_WALL_STAIRS},
	# чердак
	{"a": Vector2(26, -18.5), "b": Vector2(32, -18.5), "y0": 2.3, "h": 3.1, "color": C_WALL_ATTIC},
	{"a": Vector2(26, -18.5), "b": Vector2(26, -10.5), "y0": 2.3, "h": 3.1, "color": C_WALL_ATTIC},
	{"a": Vector2(32, -18.5), "b": Vector2(32, -10.5), "y0": 2.3, "h": 3.1, "color": C_WALL_ATTIC},
	# лестница в подвал
	{"a": Vector2(26, 4), "b": Vector2(26, 10.5), "y0": -2.9, "h": 5.7, "color": C_WALL_STAIRS},
	{"a": Vector2(32, 4), "b": Vector2(32, 10.5), "y0": -2.9, "h": 5.7, "color": C_WALL_STAIRS},
	# подвал
	{"a": Vector2(26, 18.5), "b": Vector2(32, 18.5), "y0": -2.9, "h": 3.1, "color": C_WALL_BASEMENT},
	{"a": Vector2(26, 10.5), "b": Vector2(26, 18.5), "y0": -2.9, "h": 3.1, "color": C_WALL_BASEMENT},
	{"a": Vector2(32, 10.5), "b": Vector2(32, 18.5), "y0": -2.9, "h": 3.1, "color": C_WALL_BASEMENT},
]

# --- предметы ----------------------------------------------------------------
# kind: "star" или "key". Порядок в списке = порядок подсказок:
# ключ (детская) идёт раньше предмета в запертом кабинете.
# Чтобы переставить предмет — поменяй pos (мировые координаты) и room/hint.
const ITEMS := [
	{"id": "star_living", "kind": "star", "room": "living", "pos": Vector3(4.0, 0.34, -9.05),
		"hint": "Загляни за диван"},
	{"id": "star_kitchen", "kind": "star", "room": "kitchen", "pos": Vector3(17.72, 1.78, -5.0),
		"hint": "Посмотри на полках"},
	{"id": "star_bedroom", "kind": "star", "room": "bedroom", "pos": Vector3(1.3, 0.25, 6.4),
		"hint": "Что-то блестит под кроватью", "scale": 0.7},
	{"id": "key_nursery", "kind": "key", "room": "nursery", "pos": Vector3(15.6, 1.1, 9.28),
		"hint": "Ключ спрятан в шкафу"},
	{"id": "star_basement", "kind": "star", "room": "basement", "pos": Vector3(31.62, -1.33, 14.5),
		"hint": "Поищи на металлических полках"},
	{"id": "star_attic", "kind": "star", "room": "attic", "pos": Vector3(29.0, 3.78, -18.12),
		"hint": "Открой старый шкаф"},
	{"id": "star_study", "kind": "star", "room": "study", "pos": Vector3(25.58, 1.5, -5.5),
		"hint": "Запертая дверь в кабинет — нужен ключ", "needs_door": "study"},
]

static func total_items() -> int:
	return ITEMS.size()

## Какая комната под точкой p (по плану, этажи в плане не перекрываются).
static func room_at(p: Vector3) -> String:
	var pt := Vector2(p.x, p.z)
	for id in ROOMS:
		if (ROOMS[id]["rect"] as Rect2).has_point(pt):
			return id
	return ""

static func room_name(id: String) -> String:
	if ROOMS.has(id):
		return ROOMS[id]["name"]
	return ""

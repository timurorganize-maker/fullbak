class_name HouseBuilder
extends Node3D
## Строит дом из данных GameData: полы, стены с проёмами, двери, лестницы, мебель, торшеры.
##
## Для скорости на телефоне все статические «коробки» склеиваются в один ArrayMesh на
## (ячейку 4.5×4.5 м × материал), а коллизия — один StaticBody3D на (ячейку × слой).
## Слои физики: 1 = мир (стены/полы, их видит камера), 2 = мебель.

const CELL := 4.5          # размер ячейки склейки мешей
const MAX_TILE := 4.5      # длинные коробки режутся на тайлы, чтобы на меш влияло ≤ 8 ламп (лимит Mobile)
const LAYER_WORLD := 1
const LAYER_FURNITURE := 2

var _geo := {}   # "box"/"cyl"/"sphere" -> {v: PackedVector3Array, n: PackedVector3Array}
var _materials := {}
var _shapes := {}
var _batches := {}   # Vector3i(ячейка, этаж) -> { color_key -> {st, mat} }
var _bodies := {}    # Vector4i(ячейка x, z, этаж, слой) -> StaticBody3D
var lamps: Array[OmniLight3D] = []
var doors: Dictionary = {}       # id -> Door
var cabinet_doors: Array[Door] = []

func _init() -> void:
	_geo["box"] = _make_box()
	_geo["cyl"] = _make_cyl(14)
	_geo["sphere"] = _make_sphere(12, 6)

# --- единичная геометрия (своя: примитивы Mesh недоступны в headless-рендерере) -----

## Добавляет треугольник, при необходимости меняя порядок вершин так, чтобы лицевая
## сторона (по часовой стрелке в Godot) смотрела туда же, куда нормали.
static func _tri(g: Dictionary, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3) -> void:
	var face := (a - c).cross(a - b)
	if face.length_squared() < 1e-12:
		return
	var v: PackedVector3Array = g["v"]
	var n: PackedVector3Array = g["n"]
	if face.dot(na + nb + nc) >= 0.0:
		v.append_array([a, b, c])
		n.append_array([na, nb, nc])
	else:
		v.append_array([a, c, b])
		n.append_array([na, nc, nb])

static func _make_box() -> Dictionary:
	var g := {"v": PackedVector3Array(), "n": PackedVector3Array()}
	for d in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]:
		var u := Vector3(d.y, d.z, d.x)
		var w: Vector3 = d.cross(u)
		var c0: Vector3 = d * 0.5 - u * 0.5 - w * 0.5
		var c1: Vector3 = d * 0.5 + u * 0.5 - w * 0.5
		var c2: Vector3 = d * 0.5 + u * 0.5 + w * 0.5
		var c3: Vector3 = d * 0.5 - u * 0.5 + w * 0.5
		_tri(g, c0, c1, c2, d, d, d)
		_tri(g, c0, c2, c3, d, d, d)
	return g

static func _make_cyl(segs: int) -> Dictionary:
	var g := {"v": PackedVector3Array(), "n": PackedVector3Array()}
	for j in segs:
		var a0 := TAU * j / segs
		var a1 := TAU * (j + 1) / segs
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var b0 := d0 * 0.5 + Vector3(0, -0.5, 0)
		var b1 := d1 * 0.5 + Vector3(0, -0.5, 0)
		var t0 := d0 * 0.5 + Vector3(0, 0.5, 0)
		var t1 := d1 * 0.5 + Vector3(0, 0.5, 0)
		_tri(g, b0, b1, t1, d0, d1, d1)
		_tri(g, b0, t1, t0, d0, d1, d0)
		_tri(g, Vector3(0, 0.5, 0), t0, t1, Vector3.UP, Vector3.UP, Vector3.UP)
		_tri(g, Vector3(0, -0.5, 0), b0, b1, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN)
	return g

static func _make_sphere(segs: int, rings: int) -> Dictionary:
	var g := {"v": PackedVector3Array(), "n": PackedVector3Array()}
	for i in rings:
		var t0 := PI * i / rings
		var t1 := PI * (i + 1) / rings
		for j in segs:
			var p0 := TAU * j / segs
			var p1 := TAU * (j + 1) / segs
			var a := Vector3(sin(t0) * cos(p0), cos(t0), sin(t0) * sin(p0))
			var b := Vector3(sin(t0) * cos(p1), cos(t0), sin(t0) * sin(p1))
			var c := Vector3(sin(t1) * cos(p1), cos(t1), sin(t1) * sin(p1))
			var d := Vector3(sin(t1) * cos(p0), cos(t1), sin(t1) * sin(p0))
			_tri(g, a * 0.5, b * 0.5, c * 0.5, a, b, c)
			_tri(g, a * 0.5, c * 0.5, d * 0.5, a, c, d)
	return g

# --- материалы ---------------------------------------------------------------

func material(c: Color, emission := 0.0, rough := 0.85) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [c.to_html(false), emission, rough]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emission
	_materials[key] = m
	return m

# --- примитивы ---------------------------------------------------------------

## Коробка: center — центр, size — размеры. collide: нужна ли коллизия.
func box(center: Vector3, size: Vector3, color: Color, collide := true, layer := LAYER_FURNITURE,
		rot_y := 0.0, emission := 0.0) -> void:
	_add_visual("box", center, size, color, rot_y, emission)
	if collide:
		_add_collider(BoxShape3D, center, size, layer, rot_y)

## Коробка по углам: от (x0,y0,z0) до (x1,y1,z1).
func box_c(c0: Vector3, c1: Vector3, color: Color, collide := true, layer := LAYER_FURNITURE,
		emission := 0.0) -> void:
	box((c0 + c1) * 0.5, (c1 - c0).abs(), color, collide, layer, 0.0, emission)

## Цилиндр (вертикальный). base — центр основания.
func cyl(base: Vector3, radius: float, height: float, color: Color, collide := true,
		emission := 0.0) -> void:
	var center := base + Vector3(0, height * 0.5, 0)
	_add_visual("cyl", center, Vector3(radius * 2.0, height, radius * 2.0), color, 0.0, emission)
	if collide:
		_add_collider(CylinderShape3D, center, Vector3(radius, height, radius), LAYER_FURNITURE, 0.0)

func sphere(center: Vector3, radius: float, color: Color, collide := false, emission := 0.0) -> void:
	_add_visual("sphere", center, Vector3.ONE * radius * 2.0, color, 0.0, emission)
	if collide:
		_add_collider(SphereShape3D, center, Vector3.ONE * radius, LAYER_FURNITURE, 0.0)

## Только коллизия (невидимая).
func collider(center: Vector3, size: Vector3, layer := LAYER_FURNITURE) -> void:
	_add_collider(BoxShape3D, center, size, layer, 0.0)

func _cell_of(p: Vector3) -> Vector3i:
	# этаж: подвал / земля / чердак
	var level := 0
	if p.y < -1.2:
		level = -1
	elif p.y > 1.4:
		level = 1
	return Vector3i(floori(p.x / CELL), floori(p.z / CELL), level)

func _add_visual(kind: String, center: Vector3, size: Vector3, color: Color, rot_y: float,
		emission: float) -> void:
	if kind == "box" and is_zero_approx(rot_y) and (size.x > MAX_TILE or size.z > MAX_TILE):
		var nx := ceili(size.x / MAX_TILE)
		var nz := ceili(size.z / MAX_TILE)
		var piece := Vector3(size.x / nx, size.y, size.z / nz)
		for i in nx:
			for j in nz:
				var c := center + Vector3((i + 0.5) * piece.x - size.x * 0.5, 0.0, (j + 0.5) * piece.z - size.z * 0.5)
				_add_visual_piece(kind, c, piece, color, rot_y, emission)
		return
	_add_visual_piece(kind, center, size, color, rot_y, emission)

func _add_visual_piece(kind: String, center: Vector3, size: Vector3, color: Color, rot_y: float,
		emission: float) -> void:
	var cell := _cell_of(center)
	if not _batches.has(cell):
		_batches[cell] = {}
	var mat := material(color, emission)
	var key := str(mat.get_instance_id())
	var slot: Dictionary = _batches[cell].get(key, {})
	if slot.is_empty():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		slot = {"st": st, "mat": mat}
		_batches[cell][key] = slot
	var basis := Basis(Vector3.UP, rot_y) * Basis.from_scale(size)
	var nbasis := basis.inverse().transposed()
	var st: SurfaceTool = slot["st"]
	var g: Dictionary = _geo[kind]
	var gv: PackedVector3Array = g["v"]
	var gn: PackedVector3Array = g["n"]
	for i in gv.size():
		st.set_normal((nbasis * gn[i]).normalized())
		st.add_vertex(basis * gv[i] + center)

func _add_collider(shape_type, center: Vector3, size: Vector3, layer: int, rot_y: float) -> void:
	var shape: Shape3D
	var skey := "%s|%s" % [shape_type, size]
	if _shapes.has(skey):
		shape = _shapes[skey]
	else:
		if shape_type == BoxShape3D:
			shape = BoxShape3D.new()
			(shape as BoxShape3D).size = size
		elif shape_type == CylinderShape3D:
			shape = CylinderShape3D.new()
			(shape as CylinderShape3D).radius = size.x
			(shape as CylinderShape3D).height = size.y
		else:
			shape = SphereShape3D.new()
			(shape as SphereShape3D).radius = size.x
		_shapes[skey] = shape
	var cell := _cell_of(center)
	var bkey := Vector4i(cell.x, cell.y, cell.z, layer)
	var body: StaticBody3D = _bodies.get(bkey)
	if body == null:
		body = StaticBody3D.new()
		body.collision_layer = layer
		body.collision_mask = 0
		body.name = "Body_%d_%d_%d_L%d" % [cell.x, cell.y, cell.z, layer]
		add_child(body)
		_bodies[bkey] = body
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.transform = Transform3D(Basis(Vector3.UP, rot_y), center)
	body.add_child(cs)

func _finish_batches() -> void:
	for cell in _batches:
		var mesh := ArrayMesh.new()
		for key in _batches[cell]:
			var slot: Dictionary = _batches[cell][key]
			var st: SurfaceTool = slot["st"]
			st.set_material(slot["mat"])
			st.commit(mesh)
		var mi := MeshInstance3D.new()
		mi.name = "Mesh_%d_%d_%d" % [cell.x, cell.y, cell.z]
		mi.mesh = mesh
		add_child(mi)
	_batches.clear()

# --- сборка дома -------------------------------------------------------------

func build() -> void:
	for id in GameData.ROOMS:
		_build_floor(id)
	for w in GameData.WALLS:
		_build_wall(w)
	Furniture.build(self)
	for id in GameData.ROOMS:
		for lp in GameData.ROOMS[id]["lamps"]:
			add_floor_lamp(lp)
	_finish_batches()

func _build_floor(id: String) -> void:
	var r: Dictionary = GameData.ROOMS[id]
	var rect: Rect2 = r["rect"]
	var col: Color = r["floor"]
	if r.has("ramp"):
		_build_ramp(r["ramp"], rect, col)
		return
	var y: float = r["y"]
	var t := GameData.FLOOR_T
	var cx := rect.position.x + rect.size.x * 0.5
	var cz := rect.position.y + rect.size.y * 0.5
	# видимый пол — точно по границам комнаты, коллизия чуть шире (без щелей между плитами)
	_add_visual("box", Vector3(cx, y - t * 0.5, cz), Vector3(rect.size.x, t, rect.size.y), col, 0.0, 0.0)
	_add_collider(BoxShape3D, Vector3(cx, y - t * 0.5, cz),
		Vector3(rect.size.x + 0.1, t, rect.size.y + 0.1), LAYER_WORLD, 0.0)

func _build_ramp(rp: Dictionary, rect: Rect2, col: Color) -> void:
	var z0: float = rp["z0"]
	var y0: float = rp["y0"]
	var z1: float = rp["z1"]
	var y1: float = rp["y1"]
	# направление в плоскости (z, y); z0 < z1 всегда
	var dz := z1 - z0
	var dy := y1 - y0
	var length := sqrt(dz * dz + dy * dy)
	var alpha := atan2(-dy, dz)
	var up := Vector3(0, dz / length, -dy / length)
	var mid := Vector3(rect.position.x + rect.size.x * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5)
	var thick := 0.4
	var center := mid - up * (thick * 0.5)
	var basis := Basis(Vector3.RIGHT, alpha)
	# коллизия: невидимый наклонный блок
	var shape := BoxShape3D.new()
	shape.size = Vector3(rect.size.x, thick, length)
	var body := StaticBody3D.new()
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	body.name = "Ramp_%s" % str(rect.position)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.transform = Transform3D(basis, center)
	body.add_child(cs)
	add_child(body)
	# внешний вид: ступени по линии пандуса
	var tread := 0.3
	var n := int(round(absf(dz) / tread))
	var step_dz := dz / n
	var cx := rect.position.x + rect.size.x * 0.5
	for i in n:
		var zc := z0 + step_dz * (i + 0.5)
		var yc := y0 + dy * ((i + 0.5) / n)
		var shade := 1.0 if i % 2 == 0 else 0.88
		var top := yc
		var bottom := minf(y0, y1) - 0.3
		_add_visual("box", Vector3(cx, (top + bottom) * 0.5, zc),
			Vector3(rect.size.x, top - bottom, absf(step_dz) + 0.01), col * shade, 0.0, 0.0)

func _build_wall(w: Dictionary) -> void:
	var a: Vector2 = w["a"]
	var b: Vector2 = w["b"]
	var along_x := is_equal_approx(a.y, b.y)
	var y0: float = w.get("y0", 0.0)
	var h: float = w.get("h", GameData.WALL_H)
	var color: Color = w.get("color", GameData.C_WALL)
	var fixed := a.y if along_x else a.x
	var start := (minf(a.x, b.x) if along_x else minf(a.y, b.y)) - GameData.WALL_T * 0.5
	var end := (maxf(a.x, b.x) if along_x else maxf(a.y, b.y)) + GameData.WALL_T * 0.5
	var ds: Array = (w.get("doors", []) as Array).duplicate()
	ds.sort_custom(func(p, q): return p["at"] < q["at"])
	var cursor := start
	for d in ds:
		var dw: float = d.get("w", GameData.DOOR_W)
		var dh: float = d.get("h", GameData.DOOR_H)
		var d0: float = d["at"] - dw * 0.5
		var d1: float = d["at"] + dw * 0.5
		_wall_piece(along_x, fixed, cursor, d0, y0 - 0.3, y0 + h, color)
		if dh < h:
			_wall_piece(along_x, fixed, d0, d1, y0 + dh, y0 + h, color)
		if not d.get("open", false):
			_spawn_door(d, along_x, fixed, y0, dw, dh)
		cursor = d1
	_wall_piece(along_x, fixed, cursor, end, y0 - 0.3, y0 + h, color)

func _wall_piece(along_x: bool, fixed: float, u0: float, u1: float, ya: float, yb: float,
		color: Color) -> void:
	if u1 - u0 < 0.01:
		return
	var u := (u0 + u1) * 0.5
	var y := (ya + yb) * 0.5
	var t := GameData.WALL_T
	if along_x:
		box(Vector3(u, y, fixed), Vector3(u1 - u0, yb - ya, t), color, true, LAYER_WORLD)
	else:
		box(Vector3(fixed, y, u), Vector3(t, yb - ya, u1 - u0), color, true, LAYER_WORLD)

func _spawn_door(d: Dictionary, along_x: bool, fixed: float, y0: float, dw: float, dh: float) -> void:
	var door := Door.new()
	add_child(door)
	var pos := Vector3(d["at"], y0, fixed) if along_x else Vector3(fixed, y0, d["at"])
	var locked: bool = d.get("locked", false)
	door.setup(pos, along_x, dw, dh, locked, d.get("hinge", 1.0), true, self)
	if d.has("id"):
		doors[d["id"]] = door

# --- торшер ------------------------------------------------------------------

func add_floor_lamp(p: Vector3) -> void:
	var wood := Color(0.30, 0.20, 0.12)
	cyl(p, 0.18, 0.05, wood, false)
	box(p + Vector3(0, 0.8, 0), Vector3(0.05, 1.6, 0.05), wood, false)
	# коллизия только на столбик — чтобы не цепляться
	collider(p + Vector3(0, 0.8, 0), Vector3(0.3, 1.6, 0.3))
	var shade_c := Color(1.0, 0.78, 0.45)
	cyl(p + Vector3(0, 1.45, 0), 0.22, 0.3, shade_c, false, 1.6)
	var l := OmniLight3D.new()
	l.position = p + Vector3(0, 1.7, 0)
	l.light_color = Color(1.0, 0.76, 0.46)
	l.light_energy = 2.2
	l.omni_range = 6.5
	l.omni_attenuation = 1.0
	l.shadow_enabled = false
	# двойной параболоид дешевле куба; в Compatibility (нет RenderingDevice) он недоступен
	l.omni_shadow_mode = OmniLight3D.SHADOW_CUBE if RenderingServer.get_rendering_device() == null else OmniLight3D.SHADOW_DUAL_PARABOLOID
	l.shadow_bias = 0.05
	l.add_to_group("lamps")
	add_child(l)
	lamps.append(l)

# --- прочее ------------------------------------------------------------------

## Табличка-надпись на стене. facing_y — поворот вокруг Y.
func add_sign(text: String, pos: Vector3, facing_y: float, size := 0.24) -> void:
	var lab := Label3D.new()
	lab.text = text
	lab.font_size = 96
	lab.pixel_size = size / 96.0 * 2.0
	lab.modulate = Color(1.0, 0.95, 0.8)
	lab.outline_modulate = Color(0.1, 0.06, 0.03)
	lab.outline_size = 14
	lab.position = pos
	lab.rotation.y = facing_y
	lab.double_sided = false
	add_child(lab)

## Шкаф с распахивающимися дверцами (полый, внутри полка). front_dir: +1 фасад смотрит на +Z, -1 на -Z.
## center — центр шкафа у пола (y — пол), size — габариты (x ширина, y высота, z глубина).
func cabinet(base: Vector3, size: Vector3, color: Color, front_dir: float, shelf_y: float,
		doors_n := 2) -> void:
	var dark := color * 0.55
	dark.a = 1.0
	var t := 0.05
	var cx := base.x
	var cz := base.z
	var back_z := cz - front_dir * (size.z * 0.5 - t * 0.5)
	var wood := color
	box(Vector3(cx, base.y + size.y * 0.5, back_z), Vector3(size.x, size.y, t), dark, false)
	box(Vector3(cx - size.x * 0.5 + t * 0.5, base.y + size.y * 0.5, cz), Vector3(t, size.y, size.z), wood, false)
	box(Vector3(cx + size.x * 0.5 - t * 0.5, base.y + size.y * 0.5, cz), Vector3(t, size.y, size.z), wood, false)
	box(Vector3(cx, base.y + size.y - t * 0.5, cz), Vector3(size.x, t, size.z), wood, false)
	box(Vector3(cx, base.y + 0.06, cz), Vector3(size.x, 0.12, size.z), wood, false)
	box(Vector3(cx, base.y + shelf_y, cz), Vector3(size.x - 2.0 * t, 0.04, size.z - 0.1), wood, false)
	# одна коллизия на весь шкаф (мебель)
	collider(base + Vector3(0, size.y * 0.5, 0), size)
	# дверцы (только визуально, открываются при приближении)
	var leaf_w := (size.x - 0.04) / doors_n
	var front_z := cz + front_dir * (size.z * 0.5)
	for i in doors_n:
		var left_edge := cx - size.x * 0.5 + 0.02 + leaf_w * i
		var hinge_left := (i % 2 == 0)
		var hx := left_edge if hinge_left else left_edge + leaf_w
		var door := Door.new()
		add_child(door)
		door.setup_cabinet(Vector3(hx, base.y, front_z), front_dir, leaf_w, size.y - 0.1,
			1.0 if hinge_left else -1.0, wood * 1.15, self)
		cabinet_doors.append(door)

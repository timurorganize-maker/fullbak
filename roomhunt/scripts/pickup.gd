class_name Pickup
extends Node3D
## Спрятанный предмет: звезда или ключ. Крутится и покачивается, светится (эмиссия + bloom).

signal collected(pickup: Pickup)

var item: Dictionary = {}
var kind := "star"
var interact_range := 1.8
var _base_y := 0.0
var _t := randf() * TAU
var _visual: Node3D
var _taken := false
var _mat: StandardMaterial3D

func setup(data: Dictionary) -> void:
	item = data
	kind = data["kind"]
	position = data["pos"]
	_base_y = position.y
	add_to_group("interactable")
	add_to_group("pickups")
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(1.0, 0.82, 0.25)
	_mat.emission_enabled = true
	_mat.emission = Color(1.0, 0.72, 0.2)
	_mat.emission_energy_multiplier = 2.2
	_mat.metallic = 0.6
	_mat.roughness = 0.35
	_visual = Node3D.new()
	_visual.scale = Vector3.ONE * float(data.get("scale", 1.0))
	add_child(_visual)
	if kind == "key":
		_build_key()
	else:
		_build_star()

func _build_star() -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _star_mesh(0.27, 0.115, 0.07)
	mi.material_override = _mat
	_visual.add_child(mi)

func _build_key() -> void:
	# кольцо-ушко + стержень + бородка; ключ лежит «на боку» и вращается вокруг вертикали
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.06
	tm.outer_radius = 0.13
	tm.rings = 14
	tm.ring_segments = 8
	ring.mesh = tm
	ring.material_override = _mat
	ring.rotation.x = PI / 2.0
	ring.position = Vector3(-0.2, 0, 0)
	_visual.add_child(ring)
	var shaft := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.36, 0.06, 0.06)
	shaft.mesh = bm
	shaft.material_override = _mat
	shaft.position = Vector3(0.06, 0, 0)
	_visual.add_child(shaft)
	for i in 2:
		var tooth := MeshInstance3D.new()
		var tb := BoxMesh.new()
		tb.size = Vector3(0.06, 0.06, 0.12 - i * 0.02)
		tooth.mesh = tb
		tooth.material_override = _mat
		tooth.position = Vector3(0.16 + i * 0.09, 0, 0.07)
		_visual.add_child(tooth)

## Плоская звезда-призма: n лучей, R — внешний радиус, r — внутренний, depth — толщина.
static func _star_mesh(R: float, r: float, depth: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var pts: Array[Vector2] = []
	for i in 10:
		var ang := PI / 2.0 + i * PI / 5.0
		var rad := R if i % 2 == 0 else r
		pts.append(Vector2(cos(ang), sin(ang)) * rad)
	var zf := depth * 0.5
	var zb := -depth * 0.5
	for i in 10:
		var a := pts[i]
		var b := pts[(i + 1) % 10]
		# в Godot лицевая сторона — по часовой стрелке (если смотреть на грань снаружи)
		# перед (+Z)
		st.add_vertex(Vector3(0, 0, zf))
		st.add_vertex(Vector3(b.x, b.y, zf))
		st.add_vertex(Vector3(a.x, a.y, zf))
		# зад (-Z)
		st.add_vertex(Vector3(0, 0, zb))
		st.add_vertex(Vector3(a.x, a.y, zb))
		st.add_vertex(Vector3(b.x, b.y, zb))
		# бок: a_f, b_f, b_b / a_f, b_b, a_b
		st.add_vertex(Vector3(a.x, a.y, zf))
		st.add_vertex(Vector3(b.x, b.y, zf))
		st.add_vertex(Vector3(b.x, b.y, zb))
		st.add_vertex(Vector3(a.x, a.y, zf))
		st.add_vertex(Vector3(b.x, b.y, zb))
		st.add_vertex(Vector3(a.x, a.y, zb))
	st.generate_normals()
	return st.commit()

func _process(delta: float) -> void:
	if _taken:
		return
	_t += delta
	_visual.rotation.y += delta * 1.8
	position.y = _base_y + sin(_t * 2.2) * 0.04
	_mat.emission_energy_multiplier = 2.0 + sin(_t * 3.0) * 0.5

func get_prompt() -> String:
	return "Взять"

func get_interact_pos() -> Vector3:
	return global_position

func take() -> void:
	if _taken:
		return
	_taken = true
	remove_from_group("interactable")
	collected.emit(self)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_visual, "scale", Vector3.ZERO, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "position:y", position.y + 0.5, 0.3)
	tw.chain().tween_callback(queue_free)

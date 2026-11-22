class_name Door
extends Node3D
## Дверь на петле. Сама открывается с анимацией, когда игрок рядом, и закрывается, когда
## он отошёл. Заперта (locked) — не открывается, пока игрок не использует ключ.
## Этот же класс используется для дверок шкафов (solid = false, без коллизии).
##
## Локальная система узла: начало — ось петли, +X — от петли к свободному краю створки,
## +Z — нормаль к стене.

const OPEN_TIME := 0.45

var width := 1.3
var height := 2.15
var locked := false
var solid := true
var open_angle := deg_to_rad(100.0)
var open_dist := 2.3
var close_dist := 3.4
var is_open := false
var interact_range := 2.2

var _leaf: Node3D
var _mesh: MeshInstance3D
var _builder
var _tween: Tween
var _padlocks: Array[Node3D] = []
var _wood_mat: StandardMaterial3D
var _player: Node3D
var _center_world := Vector3.ZERO
var _cabinet := false

## Дверь в стене. pos — центр проёма у пола, hinge = ±1 — с какой стороны вдоль стены петля.
func setup(pos: Vector3, along_x: bool, w: float, h: float, p_locked: bool, hinge: float,
		p_solid: bool, builder) -> void:
	width = w
	height = h
	locked = p_locked
	solid = p_solid
	_builder = builder
	var along := Vector3.RIGHT if along_x else Vector3.BACK
	var pivot := pos + along * hinge * w * 0.5
	var axis := -along * hinge   # от петли к створке
	position = pivot
	rotation.y = atan2(-axis.z, axis.x)
	_center_world = pos + Vector3(0, h * 0.5, 0)
	_wood_mat = builder.material(Color(0.55, 0.36, 0.20), 0.0, 0.6)
	var mat: StandardMaterial3D = _wood_mat
	if locked:
		mat = builder.material(Color(0.42, 0.10, 0.10), 0.0, 0.6)
	_build_leaf(mat, 0.07)
	if locked:
		add_to_group("interactable")

## Дверка шкафа. pivot — ось петли на фасаде; front_dir = ±1 — куда смотрит фасад по Z;
## hinge_left = +1 — створка идёт от петли в +X, -1 — в -X.
func setup_cabinet(pivot: Vector3, front_dir: float, w: float, h: float, hinge_left: float,
		color: Color, builder) -> void:
	_cabinet = true
	width = w
	height = h
	solid = false
	_builder = builder
	open_angle = deg_to_rad(110.0)
	open_dist = 2.4
	close_dist = 3.5
	position = pivot
	var axis := Vector3.RIGHT * hinge_left
	rotation.y = atan2(-axis.z, axis.x)
	_center_world = pivot + Vector3(0, h * 0.5, 0)
	_wood_mat = builder.material(color, 0.0, 0.6)
	_build_leaf(_wood_mat, 0.04)

func _build_leaf(mat: Material, thick: float) -> void:
	_leaf = Node3D.new()
	add_child(_leaf)
	_mesh = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width - 0.02, height, thick)
	_mesh.mesh = bm
	_mesh.position = Vector3(width * 0.5, height * 0.5, 0)
	_mesh.material_override = mat
	_leaf.add_child(_mesh)
	var gold: StandardMaterial3D = _builder.material(Color(0.95, 0.78, 0.3), 0.0, 0.3)
	for side in [-1.0, 1.0]:
		var knob := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.045
		sm.height = 0.09
		sm.radial_segments = 8
		sm.rings = 4
		knob.mesh = sm
		knob.material_override = gold
		knob.position = Vector3(width - 0.14, height * 0.45, side * (thick * 0.5 + 0.03))
		_leaf.add_child(knob)
	if locked:
		for side in [-1.0, 1.0]:
			var lock := MeshInstance3D.new()
			var lb := BoxMesh.new()
			lb.size = Vector3(0.14, 0.16, 0.05)
			lock.mesh = lb
			lock.material_override = gold
			lock.position = Vector3(width - 0.32, height * 0.45, side * (thick * 0.5 + 0.03))
			_leaf.add_child(lock)
			_padlocks.append(lock)
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(width - 0.02, height, thick)
		cs.shape = shape
		cs.position = Vector3(width * 0.5, height * 0.5, 0)
		body.add_child(cs)
		_leaf.add_child(body)

# --- логика открывания --------------------------------------------------------

func _physics_process(_delta: float) -> void:
	if locked:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if _player == null:
			return
	var pp := _player.global_position
	if absf(pp.y - global_position.y) > 3.0:
		return
	var d := Vector2(pp.x - _center_world.x, pp.z - _center_world.z).length()
	if not is_open and d < open_dist:
		_open(pp)
	elif is_open and d > close_dist:
		_close()

func _open(player_pos: Vector3) -> void:
	is_open = true
	var lp := to_local(player_pos)
	var pz := 1.0 if lp.z >= 0.0 else -1.0
	# дверь — от игрока; дверка шкафа — к игроку (в комнату)
	var angle := pz * open_angle if not _cabinet else -pz * open_angle
	_animate(angle)

func _close() -> void:
	is_open = false
	_animate(0.0)

func _animate(angle: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_leaf, "rotation:y", angle, OPEN_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Открыть принудительно (после разблокировки).
func unlock() -> void:
	locked = false
	remove_from_group("interactable")
	_mesh.material_override = _wood_mat
	for p in _padlocks:
		p.queue_free()
	_padlocks.clear()

# --- интерфейс «interactable» --------------------------------------------------

func get_prompt() -> String:
	return "Открыть"

func get_interact_pos() -> Vector3:
	return _center_world

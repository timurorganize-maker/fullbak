class_name CameraRig
extends Node3D
## Камера от третьего лица: плавно следует за целью, поворот свайпом, SpringArm3D не даёт
## камере пройти сквозь стены (маска = слой 1, «мир»).

const SENSITIVITY := 0.0042
const MIN_PITCH := deg_to_rad(-72.0)
const MAX_PITCH := deg_to_rad(-6.0)

var target: Node3D
var yaw := 0.0
var pitch := deg_to_rad(-30.0)
var arm_length := 4.6
var height := 1.45

var _pitch_node: Node3D
var _arm: SpringArm3D
var camera: Camera3D

func _ready() -> void:
	top_level = true
	_pitch_node = Node3D.new()
	add_child(_pitch_node)
	_arm = SpringArm3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.28
	_arm.shape = sphere
	_arm.spring_length = arm_length
	_arm.collision_mask = 1
	_arm.margin = 0.15
	_pitch_node.add_child(_arm)
	camera = Camera3D.new()
	camera.fov = 66.0
	camera.near = 0.08
	camera.far = 90.0
	_arm.add_child(camera)
	camera.make_current()

func snap_to_target() -> void:
	if target:
		global_position = target.global_position + Vector3(0, height, 0)
		rotation = Vector3(0, yaw, 0)
		_pitch_node.rotation.x = pitch

func look(delta_px: Vector2) -> void:
	yaw -= delta_px.x * SENSITIVITY
	pitch = clampf(pitch - delta_px.y * SENSITIVITY, MIN_PITCH, MAX_PITCH)

func _process(delta: float) -> void:
	if target:
		var tp := target.global_position + Vector3(0, height, 0)
		global_position = global_position.lerp(tp, 1.0 - exp(-13.0 * delta))
		# если камера прижата к стене совсем близко — прячем модель, чтобы не «лезть в голову»
		var model := target.get("model") as Node3D
		if model:
			model.visible = _arm.get_hit_length() > 0.9
	rotation = Vector3(0.0, yaw, 0.0)
	_pitch_node.rotation.x = pitch

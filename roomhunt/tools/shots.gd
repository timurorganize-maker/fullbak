extends Node
## Делает скриншоты из разных точек дома (для визуальной проверки): --shots=<папка>
var game
var out_dir := "/tmp"
var frame := 0
var idx := 0
# [позиция игрока, yaw (рад), pitch (град), подпись]
var views := [
	[Vector3(3, 0.2, 0), -PI / 2, -25, "01_hall"],
	[Vector3(5, 0.2, -4), 0.0, -35, "02_living"],
	[Vector3(5.2, 0.2, -9.0), PI, -30, "03_behind_sofa"],
	[Vector3(15.5, 0.2, -4), -PI / 2, -35, "04_kitchen"],
	[Vector3(4, 0.2, 4.5), PI, -35, "05_bedroom"],
	[Vector3(14, 0.2, 6.5), 0.0, -35, "06_nursery_cabinet"],
	[Vector3(22, 0.2, -3), 0.0, -35, "07_study"],
	[Vector3(29, 0.0, 0), 0.0, -30, "08_lobby"],
	[Vector3(29, -1.3, 7.3), 0.0, -30, "09_stairs_down"],
	[Vector3(29, -2.5, 13), 0.0, -30, "10_basement"],
	[Vector3(29, 1.3, -7.3), PI, -30, "11_stairs_up"],
	[Vector3(29, 2.7, -14), PI, -30, "12_attic"],
	[Vector3(12, 0.2, 0), -PI / 2, -62, "13_overview"],
	[Vector3(5.0, 0.2, -9.0), PI, -30, "14_take_button"],
	[Vector3(5.0, 0.2, -9.0), PI, -30, "15_win"],
]

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			out_dir = a.substr(8)
	DirAccess.make_dir_recursive_absolute(out_dir)

func get_input() -> Vector2:
	return Vector2.ZERO

func _process(_d: float) -> void:
	frame += 1
	if idx >= views.size():
		get_tree().quit()
		return
	var v: Array = views[idx]
	if frame == 1:
		game.player.teleport(v[0])
		game.rig.yaw = v[1]
		game.rig.pitch = deg_to_rad(v[2])
		game.rig.snap_to_target()
	elif frame == 38 and v[3] == "15_win":
		game.found = 7
		game._win()
	elif frame == 39 and idx == 0:
		print("TOUCH size=", game.touch.size, " active=", game.touch.active, " vis=", game.touch.visible, " pos=", game.touch.global_position)
	elif frame == 40:
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/%s.png" % [out_dir, v[3]])
		idx += 1
		frame = 0

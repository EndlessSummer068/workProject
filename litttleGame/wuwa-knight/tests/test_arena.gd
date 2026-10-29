extends "res://tests/test_base.gd"
## L01-P0-02b Test Arena 验收测试（BUILD_PLAN.md）：headless 运行。
## 运行：Godot_v4.7.2 --headless --path <项目> --script res://tests/test_arena.gd



func _run() -> void:
	var arena: Node = (load("res://scenes/levels/test_arena.tscn") as PackedScene).instantiate()
	root.add_child(arena)
	await physics_frame
	await physics_frame
	var player := arena.get_node("Player") as CharacterBody2D
	var cam := player.get_node("Camera2D") as Camera2D

	# CHECK1: 玩家实例位于场景中心 (640,360)
	_check("CHECK1 center", player.global_position.distance_to(Vector2(640, 360)) < 0.5, "pos=%s" % player.global_position)

	# CHECK2: 相机平滑跟随收敛后，视口中心 = 玩家位置（(640,360)±192/108 在 Limits 内不被钳制）
	for i in 90:
		await physics_frame
	var center := cam.get_screen_center_position()
	_check("CHECK2 camera_follow", center.distance_to(player.global_position) < 2.0, "center=%s player=%s" % [center, player.global_position])

	# CHECK3: 贴墙阻挡：向右压 420 帧（>7s×160px/s）→ x 停在 ≈1274（墙内缘 1280 - 玩家半宽 6）
	Input.action_press("move_right")
	for i in 420:
		await physics_frame
	Input.action_release("move_right")
	_check("CHECK3 wall_block", absf(player.global_position.x - 1274.0) < 1.5, "x=%.2f (期望≈1274)" % player.global_position.x)

	# CHECK4: 相机 Limits 钳制：玩家贴右墙时视口中心 x = limit_right - 半视宽(192) = 1088
	for i in 90:
		await physics_frame
	center = cam.get_screen_center_position()
	_check("CHECK4 camera_limit", absf(center.x - 1088.0) < 2.0, "center=%s (期望 x≈1088)" % center)

	if _fail:
		print("RESULT: FAILED")
		quit(1)
	else:
		print("RESULT: ALL PASS")
		quit(0)


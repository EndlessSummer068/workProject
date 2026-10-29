extends "res://tests/test_base.gd"
## L01-P0-02 移动验收测试（BUILD_PLAN.md）：headless 运行。
## 运行：Godot_v4.7.2 --headless --path <项目> --script res://tests/test_movement.gd
## 输出 TEST1/2/3 结果；全部通过退出码 0，否则 1。

const SPEED := 160.0        # §4.1 玩家移速 160 px/s
const TOL := SPEED * 0.05   # ±5%
const FRAMES := 60          # 60 physics 帧 ≈ 1 秒



func _run() -> void:
	LevelGenerator.section_override = "### 6.2"  # 本测试跑道坐标绑定 L01 布局（§6.2），覆写生成器小节（L02-P0-03）
	var level: Node = (load("res://scenes/levels/level.tscn") as PackedScene).instantiate()
	root.add_child(level)
	await physics_frame
	await physics_frame
	var player := level.get_node("Player") as CharacterBody2D

	# TEST1: 按住 W 1 秒 → dy = -160 ±5%（§4.1 移速）
	# 出生点距 A1 顶墙不足 160px（07c 缩尺+08 走廊加长后），先传送到房间内保证跑道（不改变验收阈值）
	player.global_position = Vector2(256, 720)
	player.velocity = Vector2.ZERO
	var y0 := player.global_position.y
	Input.action_press("move_up")
	for i in FRAMES:
		await physics_frame
	Input.action_release("move_up")
	var dy := player.global_position.y - y0
	_check("TEST1 W 1s", absf(dy + SPEED) <= TOL, "dy=%.2f (期望 %.2f±%.2f)" % [dy, -SPEED, TOL])

	await physics_frame
	# TEST2: W+D 1 秒 → 合速度 160±5%、方向 45°（§3 八方向）
	player.global_position = Vector2(256, 720)
	player.velocity = Vector2.ZERO
	var x0 := player.global_position.x
	y0 = player.global_position.y
	Input.action_press("move_up")
	Input.action_press("move_right")
	for i in FRAMES:
		await physics_frame
	Input.action_release("move_up")
	Input.action_release("move_right")
	var dx := player.global_position.x - x0
	dy = player.global_position.y - y0
	var dist := Vector2(dx, dy).length()
	var expect := SPEED / sqrt(2.0)
	var ok2 := absf(dist - SPEED) <= TOL and absf(absf(dx) - expect) <= TOL and absf(absf(dy) - expect) <= TOL
	_check("TEST2 W+D", ok2, "dx=%.2f dy=%.2f dist=%.2f (期望 45°, dist=%.2f±%.2f)" % [dx, dy, dist, SPEED, TOL])

	# TEST3: 松开全部 → 停止（§3 不能跳跃、无惯性）
	await physics_frame
	var p0 := player.global_position
	for i in 10:
		await physics_frame
	var moved := (player.global_position - p0).length()
	_check("TEST3 stop", player.velocity.length() < 0.01 and moved < 0.5, "velocity=%.3f moved=%.3f" % [player.velocity.length(), moved])

	if _fail:
		print("RESULT: FAILED")
		quit(1)
	else:
		print("RESULT: ALL PASS")
		quit(0)

extends "res://tests/test_base.gd"
## L02-P1-01 传送点 T 验收测试（BUILD_PLAN.md）：headless 运行（看门狗基类=TECH §17）。
## 覆盖：T1 T 落位于商店区 A5；T2 进店记录（来路区域最近门向房中心内推 40px）；
## T3 靠近按 E 回传 + 速度清零；T4 每次进店刷新记录；T5 无进店记录不传送（打印提示）。
## 运行：Godot_v4.7.2 --headless --path <项目> --script res://tests/test_teleport.gd

func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame

func _run() -> void:
	LevelGenerator.section_override = ""
	var level: Node = (load("res://scenes/levels/level.tscn") as PackedScene).instantiate()
	root.add_child(level)
	await _wait(10)

	var tp: TeleportPoint = level._teleport
	var a5: Rect2 = level._room_rects["A5"]
	var player: Player = level.player

	# ---- T1: T 落位于商店区 A5 内（§5/§6.3）----
	_check("T1_teleport_in_shop", tp != null and a5.has_point(tp.global_position) and level._shop_area == "A5",
		"tp=%s pos=%s A5=%s 商店区=%s" % [tp, tp.global_position if tp != null else "无", a5, level._shop_area])

	# ---- T2: 进店记录（A4 → A5）：落点在来路区域内、距最近房门 40px（§4.5 提案）----
	player.global_position = level._room_rects["A4"].get_center()
	await _wait(2)
	player.global_position = a5.get_center()
	await _wait(2)
	var ret: Vector2 = level._return_point
	var gate: DoorGate = level._nearest_gate("A4")
	_check("T2_record_on_enter", level._has_return and level._room_rects["A4"].has_point(ret) \
		and ret.distance_to(gate.global_position) <= Balance.TELEPORT_RETURN_INSET + 0.5,
		"has_return=%s 落点=%s A4=%s 门=%s 距离=%.2f（期望≈40）" %
		[level._has_return, ret, level._room_rects["A4"], gate.global_position, ret.distance_to(gate.global_position)])

	# ---- T4: 每次进店刷新记录（A3 → A5）；先做再验证 T3 用新落点 ----
	player.global_position = level._room_rects["A3"].get_center()
	await _wait(2)
	player.global_position = a5.get_center()
	await _wait(2)
	var ret2: Vector2 = level._return_point
	_check("T4_record_refresh", level._room_rects["A3"].has_point(ret2) and ret2 != ret,
		"旧落点=%s 新落点=%s（A3=%s）" % [ret, ret2, level._room_rects["A3"]])

	# ---- T3: 靠近 T 按 E → 传送回落点、速度清零（§4.5）----
	player.global_position = tp.global_position  # 已位于 A5，不改变进店记录
	await _wait(2)
	player.velocity = Vector2(100, 0)
	Input.action_press("interact")
	await _wait(2)
	Input.action_release("interact")
	await _wait(1)
	_check("T3_teleport_back", player.global_position.is_equal_approx(ret2) and player.velocity == Vector2.ZERO,
		"pos=%s 期望=%s vel=%s" % [player.global_position, ret2, player.velocity])

	# ---- T5: 无进店记录（手摆直接生成于商店区）→ 不传送（§4.5）----
	var level2: Node = (load("res://scenes/levels/level.tscn") as PackedScene).instantiate()
	root.add_child(level2)
	level2.player.global_position = level2._teleport.global_position  # 首帧即处于商店区：prev="" → 无记录
	await _wait(4)
	var p2: Player = level2.player
	var p2_pos: Vector2 = p2.global_position
	var moved: bool = level2._teleport_back()
	_check("T5_no_record", not level2._has_return and not moved and p2.global_position.is_equal_approx(p2_pos),
		"has_return=%s moved=%s pos=%s（期望 false/false/原地）" % [level2._has_return, moved, p2.global_position])

	if _fail:
		print("RESULT: FAILED")
		quit(1)
	else:
		print("RESULT: ALL PASS")
		quit(0)

extends SceneTree
## L01-P0-07b 布局加载验收测试（BUILD_PLAN.md，范围=A1+A2）：headless 运行。
## 运行：Start-Process Godot --headless --path <项目> --script res://tests/test_level.gd

var _fail := false

func _initialize() -> void:
	_run.call_deferred()

func _check(name: String, ok: bool, detail: String) -> void:
	print("%s: %s (%s)" % [name, "PASS" if ok else "FAIL", detail])
	_fail = _fail or not ok

func _count_entities(data: Dictionary) -> Dictionary:
	var counts := {}
	for e: Dictionary in data["entities"]:
		counts[e["id"]] = int(counts.get(e["id"], 0)) + 1
	return counts

func _run() -> void:
	var doc := FileAccess.open("res://docs/GAME.md", FileAccess.READ)
	_check("T0 doc_readable", doc != null, "res://docs/GAME.md")
	var doc_text := doc.get_as_text()
	var d1 := LevelParser.parse(LevelParser.extract_area(doc_text, "A1"))
	var d2 := LevelParser.parse(LevelParser.extract_area(doc_text, "A2"))

	# T1: A1/A2 尺寸 = 32×20（§4.7 用户指令缩小值）
	var s1: Vector2i = d1["size"]
	var s2: Vector2i = d2["size"]
	_check("T1 sizes", s1 == Vector2i(32, 20) and s2 == Vector2i(32, 20), "A1=%s A2=%s" % [s1, s2])

	# T2: 实体多重集（§6.2）
	var c1 := _count_entities(d1)
	var c2 := _count_entities(d2)
	var ok1: bool = c1.get("P", 0) == 1 and c1.get("E01", 0) == 2 and c1.get("E02", 0) == 2 and c1.get("E03", 0) == 1 and c1.get("E04", 0) == 1 and c1.get("E05", 0) == 1 and c1.get("R02", 0) == 1 and c1.get("D", 0) == 4
	var ok2: bool = c2.get("E01", 0) == 2 and c2.get("E02", 0) == 2 and c2.get("E03", 0) == 1 and c2.get("E04", 0) == 1 and c2.get("E05", 0) == 1 and c2.get("R02", 0) == 1 and c2.get("D", 0) == 4 and not c2.has("P")
	_check("T2 entities", ok1 and ok2, "A1=%s A2=%s" % [c1, c2])

	# T3: 边界——A1 右缘门行 8-11 为 D、A2 左缘同行开口为地板、A2 右缘同行门通 A3；其余边界全墙（§6.2）
	var cells1: Dictionary = d1["cells"]
	var cells2: Dictionary = d2["cells"]
	var ok3 := true
	for y in 20:
		var is_door_row: bool = y >= 8 and y <= 11
		for x in 32:
			var t1: String = cells1[Vector2i(x, y)]
			var t2: String = cells2[Vector2i(x, y)]
			var border := x == 0 or x == 31 or y == 0 or y == 19
			if not border:
				continue
			if x == 31 and is_door_row:
				ok3 = ok3 and t1 == "D" and t2 == "D"
			elif x == 0 and is_door_row:
				ok3 = ok3 and t2 == "."
			else:
				ok3 = ok3 and t1 == "#" and t2 == "#"
	_check("T3 borders_door", ok3, "A1 右缘/A2 右缘 D(行8-11)、A2 左缘开口、其余全墙")

	# 生成阶段
	var level: Node = (load("res://scenes/levels/level.tscn") as PackedScene).instantiate()
	root.add_child(level)
	await physics_frame
	await physics_frame
	var player: CharacterBody2D = level.get("player")

	# T4: 玩家生成 + E01 共 4 个（A1×2 + A2×2）
	var e01_count := 0
	for c in level.get_children():
		var s: Script = c.get_script() if c is Node2D else null
		if s != null and str(s.resource_path).ends_with("e01.gd"):
			e01_count += 1
	_check("T4 player_e01", player != null and e01_count == 4, "player=%s e01=%d (期望 4)" % [player != null, e01_count])

	# T5: 两块区域 tile 总数 = 2×640=1280（§4.7 32×20）
	var tm: TileMapLayer = null
	for c in level.get_children():
		if c is TileMapLayer:
			tm = c
	_check("T5 tiles", tm != null and tm.get_used_cells().size() == 1280, "used=%d (期望 1280)" % (tm.get_used_cells().size() if tm != null else -1))

	# T6: 相机 Limits = 全 L01 已接入范围 1024×320 px（§6.2×§7）
	var cam: Camera2D = player.get_node("Camera2D")
	var ok6: bool = cam.limit_right == 1024 and cam.limit_bottom == 320 and cam.limit_left == 0 and cam.limit_top == 0
	_check("T6 camera_limits", ok6, "limits=(%d,%d,%d,%d) (期望 0,0,1024,320)" % [cam.limit_left, cam.limit_top, cam.limit_right, cam.limit_bottom])

	# T7: 围墙防撞——非门行向右推 7s → 被墙阻挡（A1 列31 墙 496..512，玩家半宽 6 → x≤490）
	var tdata: TileData = tm.get_cell_tile_data(Vector2i(31, 2))
	print("OBS physics_layers=%d polys_at_wall=%d" % [tm.tile_set.get_physics_layers_count(), tdata.get_collision_polygons_count(0) if tdata != null else -1])
	player.global_position = Vector2(104, 40)
	player.velocity = Vector2.ZERO
	Input.action_press("move_right")
	for i in 7 * 60:
		await physics_frame
	Input.action_release("move_right")
	var ok7: bool = player.global_position.x <= 492.0
	_check("T7 wall_block", ok7, "x=%.2f (期望 ≤492)" % player.global_position.x)

	# T8: 门可通行——门行（y=168）向右推 7s → 进入 A2（x>528）
	player.global_position = Vector2(104, 168)
	player.velocity = Vector2.ZERO
	Input.action_press("move_right")
	for i in 7 * 60:
		await physics_frame
	Input.action_release("move_right")
	var ok8: bool = player.global_position.x >= 528.0
	_check("T8 door_passable", ok8, "x=%.2f (期望 ≥528，已进入 A2)" % player.global_position.x)

	if _fail:
		print("RESULT: FAILED")
		quit(1)
	else:
		print("RESULT: ALL PASS")
		quit(0)

extends SceneTree
## L01-P0-07 布局加载验收测试（BUILD_PLAN.md，本次范围=A1）：headless 运行。
## 运行：Start-Process Godot --headless --path <项目> --script res://tests/test_level.gd

var _fail := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	# 解析阶段：直接以 docs/GAME.md 为源
	var doc := FileAccess.open("res://docs/GAME.md", FileAccess.READ)
	_check("T0 doc_readable", doc != null, "res://docs/GAME.md")
	var lines := LevelParser.extract_area(doc.get_as_text(), "A1")
	var data := LevelParser.parse(lines)

	# T1: A1 尺寸 = 48×32（§6.2 头部）
	var size: Vector2i = data["size"]
	_check("T1 size", size == Vector2i(48, 32), "size=%s" % size)

	# T2: 实体多重集 = 图例（P×1、E01×2、E02×2、E03/E04/E05/R02/D 各×1，§6.2 A1）
	var counts := {}
	for e: Dictionary in data["entities"]:
		counts[e["id"]] = int(counts.get(e["id"], 0)) + 1
	var expect := {"P": 1, "E01": 2, "E02": 2, "E03": 1, "E04": 1, "E05": 1, "R02": 1, "D": 1}
	var ok2: bool = counts.size() == expect.size()
	for k: String in expect:
		ok2 = ok2 and counts.get(k, 0) == expect[k]
	_check("T2 entities", ok2, "counts=%s" % counts)

	# T3: 边界为墙（行0 与 行31 全 #，§6.2）
	var cells: Dictionary = data["cells"]
	var border_ok := true
	for x in size.x:
		border_ok = border_ok and cells.get(Vector2i(x, 0), "?") == "#" and cells.get(Vector2i(x, size.y - 1), "?") == "#"
	_check("T3 border_walls", border_ok, "行0/行31 全墙")

	# 生成阶段：实例化 level.tscn
	var level: Node = (load("res://scenes/levels/level.tscn") as PackedScene).instantiate()
	root.add_child(level)
	await physics_frame
	await physics_frame

	# T4: 玩家生成于 P 格，E01 生成 2 个（鸭子类型访问，避免测试依赖 class_name 注册时序）
	var player: CharacterBody2D = level.get("player")
	_check("T4 player_spawned", player != null, "player=%s" % (player != null))
	var e01_count := 0
	for c in level.get_children():
		var s: Script = c.get_script() if c is Node2D else null
		if s != null and str(s.resource_path).ends_with("e01.gd"):
			e01_count += 1
	_check("T4b e01_count", e01_count == 2, "count=%d (期望 2)" % e01_count)

	# T5: TileMapLayer 覆盖 48×32=1536 格（§6.2）
	var tm: TileMapLayer = null
	for c in level.get_children():
		if c is TileMapLayer:
			tm = c
	_check("T5 tilemap", tm != null and tm.get_used_cells().size() == 1536, "used=%d (期望 1536)" % (tm.get_used_cells().size() if tm != null else -1))

	# T6: 相机 Limits = A1 像素尺寸 768×512（§6.2×§7 tile 16px）
	var cam: Camera2D = player.get_node("Camera2D")
	var ok6: bool = cam.limit_right == 768 and cam.limit_bottom == 512 and cam.limit_left == 0 and cam.limit_top == 0
	_check("T6 camera_limits", ok6, "limits=(%d,%d,%d,%d) (期望 0,0,768,512)" % [cam.limit_left, cam.limit_top, cam.limit_right, cam.limit_bottom])

	if _fail:
		print("RESULT: FAILED")
		quit(1)
	else:
		print("RESULT: ALL PASS")
		quit(0)

func _check(name: String, ok: bool, detail: String) -> void:
	print("%s: %s (%s)" % [name, "PASS" if ok else "FAIL", detail])
	_fail = _fail or not ok

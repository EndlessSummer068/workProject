extends SceneTree
## L02-P0-03 L02 地图解析与拼接加载验收测试（BUILD_PLAN.md）：headless 运行。
## 运行：Godot_v4.7.2 --headless --path <项目> --script res://tests/test_l02_map.gd
## 覆盖：§6.3 八区解析、全图 208×52、E01/E02 生成与文档计数一致、
##       S/T/E04/E05/B02/R02 打印跳过不报错、A8 B02 位置预留、门窗封禁机制（进未清区封门→清怪解锁）。

var _fail := false

func _initialize() -> void:
	_run.call_deferred()

func _check(name: String, ok: bool, detail: String) -> void:
	print("%s: %s (%s)" % [name, "PASS" if ok else "FAIL", detail])
	_fail = _fail or not ok

func _run() -> void:
	# 默认读 DOC_SECTION=§6.3（不设 override；L01 回归测试才覆写为 §6.2，见 test_level）
	var level: Node2D = (load("res://scenes/levels/level.tscn") as PackedScene).instantiate()
	root.add_child(level)
	await physics_frame
	await physics_frame
	await physics_frame  # 门/相机初始化稳定

	var doc := FileAccess.open("res://docs/GAME.md", FileAccess.READ)
	var section := LevelParser.extract_section(doc.get_as_text(), "### 6.3")

	# 文档侧统计（§6.3 全图实体）
	var doc_counts := {}
	var b02s: Array = []
	for area_id in ["A1", "A2", "A3", "A4", "A5", "A6", "A7", "A8"]:
		var data := LevelParser.parse(LevelParser.extract_area(section, area_id))
		for e: Dictionary in data["entities"]:
			var id: String = e["id"]
			doc_counts[id] = int(doc_counts.get(id, 0)) + 1
		if area_id == "A8":
			b02s = data["entities"].filter(func(e: Dictionary) -> bool: return e["id"] == "B02")

	# T1: 八区全部解析（§6.3 A1-A8；_room_rects 由生成器填充）
	_check("T1 areas_parsed", level._room_rects.size() == 8, "_room_rects=%s" % [level._room_rects.keys()])

	# T2: 全图 208×52 tile（§6.3：208×52；相机 Limits=尺寸×16px）
	var cam: Camera2D = level.player.get_node("Camera2D")
	var ok2: bool = cam.limit_right == 208 * 16 and cam.limit_bottom == 52 * 16
	_check("T2 map_208x52", ok2, "limit_right=%d(期望3328) limit_bottom=%d(期望832)" % [cam.limit_right, cam.limit_bottom])

	# T3: 场景敌人与文档计数一致（E01/E02 全部生成；类型正确）
	var e01_nodes: Array = []
	var e02_nodes: Array = []
	for child in level.get_children():
		if child is EnemyE01:
			e01_nodes.append(child)
		elif child is EnemyE02:
			e02_nodes.append(child)
	var ok3: bool = e01_nodes.size() == int(doc_counts.get("E01", 0)) and e02_nodes.size() == int(doc_counts.get("E02", 0)) \
		and e01_nodes.size() >= 8 and e02_nodes.size() >= 8
	_check("T3 enemies_spawned", ok3, "场景 E01=%d/E02=%d vs 文档 E01=%d/E02=%d（§6.3 各区小兵）" % [e01_nodes.size(), e02_nodes.size(), doc_counts.get("E01", 0), doc_counts.get("E02", 0)])

	# T4: 未实装实体在文档中存在（S/T/E04/E05/B02/R02 由 §6.3 布局声明）
	var ok4: bool = int(doc_counts.get("S", 0)) == 1 and int(doc_counts.get("T", 0)) == 1 \
		and int(doc_counts.get("B02", 0)) == 1 and int(doc_counts.get("E04", 0)) >= 1 \
		and int(doc_counts.get("E05", 0)) >= 1 and int(doc_counts.get("R02", 0)) >= 1
	_check("T4 pending_entities_in_doc", ok4, "文档计数=%s（S/T/B02=1，E04/E05/R02≥1）" % [doc_counts])

	# T5: 未实装实体未生成节点（打印跳过、不报错）：S 已随 L02-P0-02a 实装（ShopPoint 合法）；
	# 传送点 T/精英/Boss 仍未实装，场景不应出现其节点
	var unknown := []
	for child in level.get_children():
		if child is CharacterBody2D and not (child is EnemyE01) and not (child is EnemyE02) and child != level.player:
			unknown.append(child.name)
		elif child is Area2D and not (child is ShopPoint) and not (child is Chest):
			unknown.append(child.name)  # S/R02 已随 L02-P0-02a/02b 实装（ShopPoint/Chest 合法）；T 若误生成多为 Area2D
	_check("T5 skip_no_nodes", unknown.is_empty(), "未知实体节点=%s（期望空=仅打印跳过）" % [unknown])

	# T6: A8 B02 位置预留（§6.3 A8 中心 B02；解析格位在 A8 房间内部且非边缘）
	var a8_rect: Rect2 = level._room_rects["A8"]
	var b02_entry: Dictionary = b02s[0]
	var b02_px: Vector2 = Vector2(b02_entry["cell"] + level._area_grid["A8"] * Vector2i(44, 32)) * 16 + Vector2(8, 8)
	var ok6: bool = not b02s.is_empty() and a8_rect.grow(-16).has_point(b02_px)
	_check("T6 b02_reserved", ok6, "B02 格位=%s → px=%s A8=%s（房间内部）" % [b02_entry["cell"], b02_px, a8_rect])

	# T7: 门=16 扇（§6.3 门格分布：A1S/A2NE/A3WNE/A4SE/A5WS/A6WNE/A7WE/A8W）
	var ok7: bool = level.doors.size() == 16
	_check("T7 door_count", ok7, "doors=%d（期望 16）" % level.doors.size())

	# T8: 封禁机制：进未清 A2 → 除入口门外 A2 门锁定；清空 A2 敌人 → 解锁
	var a2_rect: Rect2 = level._room_rects["A2"]
	level.player.global_position = a2_rect.get_center()
	for i in 4:
		await physics_frame
	var entry: DoorGate = level._entry_gates.get("A2")
	var a2_gates: Array = level.doors.filter(func(g: DoorGate) -> bool: return String(g.get_meta("edge")).split("|")[1] == "A2")
	var locked_ok := true
	for g in a2_gates:
		if g == entry:
			if not g.unlocked:
				locked_ok = false
		elif g.unlocked:
			locked_ok = false  # 非入口门应锁定
	var ok8a: bool = level._player_area == "A2" and entry != null and locked_ok
	_check("T8a enter_locks", ok8a, "区=%s 入口门=%s A2 门锁态=%s" % [level._player_area, entry != null, a2_gates.map(func(g: DoorGate) -> bool: return g.unlocked)])

	for e in level._area_enemies["A2"]:
		if is_instance_valid(e):
			e.take_damage(999)
	for i in 4:
		await physics_frame
	var a2_gates2: Array = level.doors.filter(func(g: DoorGate) -> bool: return String(g.get_meta("edge")).split("|")[1] == "A2")
	var all_unlocked := true
	for g in a2_gates2:
		if not g.unlocked:
			all_unlocked = false
	var ok8b: bool = level._areas_cleared.get("A2", false) and all_unlocked
	_check("T8b clear_unlocks", ok8b, "A2 已清=%s 门全解锁=%s" % [level._areas_cleared.get("A2", false), all_unlocked])

	# T9: 大招特效色与 K 分离（§4.3 用户指令 2026-10-28 前置改动回归确认）
	var ok9: bool = not Balance.ULTIMATE_COLOR.is_equal_approx(Balance.SKILL_K_COLOR)
	_check("T9 ult_color_distinct", ok9, "ULTIMATE=%s K=%s" % [Balance.ULTIMATE_COLOR, Balance.SKILL_K_COLOR])

	if _fail:
		print("RESULT: FAILED")
		quit(1)
	else:
		print("RESULT: ALL PASS")
		quit(0)

extends SceneTree
## L01-P0-07c/07d 验收测试（BUILD_PLAN.md，范围=A1–A8+走廊+房门机制+门常开）：headless 运行。
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
		if e["id"] == "D":
			continue  # 门格实体由 T3 按扇数验收，此处只统计玩法实体
		counts[e["id"]] = int(counts.get(e["id"], 0)) + 1
	return counts

func _gate(level: Node, edge_meta: String) -> Node2D:
	var gates: Array = level.get("doors")
	for g in gates:
		if String(g.get_meta("edge")) == edge_meta:
			return g
	return null

func _push(dir: String, frames: int) -> void:
	Input.action_press(dir)
	for i in frames:
		await physics_frame
	Input.action_release(dir)

func _run() -> void:
	var doc := FileAccess.open("res://docs/GAME.md", FileAccess.READ)
	_check("T0 doc_readable", doc != null, "res://docs/GAME.md")
	var doc_text: String = doc.get_as_text()
	var ids := ["A1", "A2", "A3", "A4", "A5", "A6", "A7", "A8"]
	var datas := {}
	for id in ids:
		datas[id] = LevelParser.parse(LevelParser.extract_area(doc_text, id))

	# T1: 8 区域，各 32×20，格位与 §6.2 拓扑一致
	var grids := {"A1": Vector2i(0, 1), "A2": Vector2i(1, 1), "A3": Vector2i(1, 0), "A4": Vector2i(2, 0),
		"A5": Vector2i(2, 1), "A6": Vector2i(3, 1), "A7": Vector2i(3, 0), "A8": Vector2i(4, 0)}
	var ok1 := true
	for id in ids:
		ok1 = ok1 and datas[id]["size"] == Vector2i(32, 20) and LevelParser.extract_grid(LevelParser.extract_area(doc_text, id)) == grids[id]
	_check("T1 sizes_grids", ok1, "8×(32×20)+格位")

	# T2: 实体多重集（§6.1/§6.2）：A1 出生房只有 P；战斗区 ×5 同配；A4 商店；A8 Boss
	var combat := {"E01": 2, "E02": 2, "E03": 1, "E04": 1, "E05": 1, "R02": 1}
	var ok2 := _count_entities(datas["A1"]) == {"P": 1}
	for id in ["A2", "A3", "A5", "A6", "A7"]:
		ok2 = ok2 and _count_entities(datas[id]) == combat
	ok2 = ok2 and _count_entities(datas["A4"]) == {"S": 1} and _count_entities(datas["A8"]) == {"B01": 1}
	_check("T2 entities", ok2, "A1={P} 战斗区×5 A4={S} A8={B01}")

	# 生成阶段
	var level: Node = (load("res://scenes/levels/level.tscn") as PackedScene).instantiate()
	root.add_child(level)
	await physics_frame
	await physics_frame
	var player: CharacterBody2D = level.get("player")

	# T3: 门=18 扇（A1:1 A2:3 A3:2 A4:3 A5:3 A6:2 A7:3 A8:1，§6.2 拓扑表门方向列）
	_check("T3 gate_count", level.get("doors").size() == 18, "gates=%d (期望 18)" % level.get("doors").size())

	# T4: 相机 Limits = 184×46 tile（2944×736 px，§6.2 校验）
	var cam: Camera2D = player.get_node("Camera2D")
	var ok4: bool = cam.limit_right == 2944 and cam.limit_bottom == 736 and cam.limit_left == 0 and cam.limit_top == 0
	_check("T4 camera_limits", ok4, "limits=(%d,%d,%d,%d)" % [cam.limit_left, cam.limit_top, cam.limit_right, cam.limit_bottom])

	# T5: tile 总数 = 8×640 + 9×36 = 5444（§6.2 校验）
	var tm: TileMapLayer = null
	for c in level.get_children():
		if c is TileMapLayer:
			tm = c
	_check("T5 tiles", tm != null and tm.get_used_cells().size() == 5444, "used=%d (期望 5444)" % (tm.get_used_cells().size() if tm != null else -1))

	# T6: 玩家在 A1 出生房 (6,10)（A1 格位 (0,1) → origin tile (0,26)）
	var ok6: bool = player != null and player.global_position.distance_to(Vector2(104, 584)) < 1.0
	_check("T6 player_spawn", ok6, "pos=%s" % (player.global_position if player != null else Vector2.INF))

	# T7: A1 东门已解锁未开（碰撞在）→ 靠近 ≤2 tile 自动开（蓝）→ 可穿过进走廊（§2）
	var g_a1e := _gate(level, "E|A1|A2")
	var ok7a: bool = g_a1e != null and not g_a1e.open and g_a1e.unlocked
	_check("T7a a1e_unlocked_closed", ok7a, "gate=%s unlocked=%s open=%s" % [g_a1e != null, g_a1e.unlocked if g_a1e else "-", g_a1e.open if g_a1e else "-"])
	player.global_position = Vector2(476, 576)  # 门中心 (504,576) 距离 28px ≤32（§4.7）
	await physics_frame
	await physics_frame
	var ok7b: bool = g_a1e.open
	_check("T7b a1e_auto_open", ok7b, "open=%s (期望 靠近自动开)" % g_a1e.open)
	player.velocity = Vector2.ZERO
	await _push("move_right", 2 * 60)
	var ok7c: bool = player.global_position.x >= 560.0  # 已穿门进入走廊（走廊 512..608）
	_check("T7c a1e_passable", ok7c, "x=%.2f (期望 ≥560)" % player.global_position.x)
	# T7d: 门首次开启后常开不回关（§2 房门规则，L01-P0-07d）：穿门走远（≥56px>32）仍开+无碰撞
	var shape: CollisionShape2D = g_a1e.get_node("Body/Shape")
	var ok7d: bool = g_a1e.open and shape.disabled
	_check("T7d a1e_stays_open", ok7d, "open=%s no_collision=%s (期望 常开)" % [g_a1e.open, shape.disabled])

	# T8: A2 北门锁定 → 靠近不开、碰撞阻挡（§2：清怪前四周门锁）
	var g_a2n := _gate(level, "N|A2|A3")
	var ok8a: bool = g_a2n != null and not g_a2n.unlocked and not g_a2n.open
	_check("T8a a2n_locked", ok8a, "gate=%s unlocked=%s" % [g_a2n != null, g_a2n.unlocked if g_a2n else "-"])
	player.global_position = Vector2(864, 450)  # A2 北门 (864,424) 下方
	player.velocity = Vector2.ZERO
	await _push("move_up", 1 * 60)
	var ok8b: bool = player.global_position.y >= 436.0  # 门体 416..432+半宽 → 被阻挡
	_check("T8b a2n_blocks", ok8b, "y=%.2f (期望 ≥436 被阻挡)" % player.global_position.y)

	# T9: 清空 A2（击杀其 2 只 E01）→ 区域已清 → 北门解锁 → 靠近自动开 → 穿门
	var a2_killed := 0
	for c in level.get_children():
		var s: Script = c.get_script() if c is Node2D else null
		if s != null and str(s.resource_path).ends_with("e01.gd") and is_instance_valid(c) and c.hp > 0:
			var p: Vector2 = c.global_position
			if p.x >= 608.0 and p.x <= 1120.0 and p.y >= 416.0 and p.y <= 736.0:  # A2 范围（origin 608,416）
				c.take_damage(999)
				a2_killed += 1
	await physics_frame
	await physics_frame
	var ok9a: bool = a2_killed == 2 and g_a2n.unlocked \
		and _gate(level, "E|A2|A5").unlocked and _gate(level, "W|A5|A2").unlocked  # 已清区域两端门均解锁（§2）
	_check("T9a a2_clear_unlock", ok9a, "killed=%d a2n=%s a2e=%s a5w=%s" % [a2_killed, g_a2n.unlocked, _gate(level, "E|A2|A5").unlocked, _gate(level, "W|A5|A2").unlocked])
	player.global_position = Vector2(864, 450)
	player.velocity = Vector2.ZERO
	await physics_frame
	await physics_frame
	var ok9b: bool = g_a2n.open
	_check("T9b a2n_auto_open", ok9b, "open=%s" % g_a2n.open)
	await _push("move_up", 2 * 60)
	var ok9c: bool = player.global_position.y <= 380.0  # 已穿门进入北走廊（走廊 y 320..416）
	_check("T9c a2n_passable", ok9c, "y=%.2f (期望 ≤380)" % player.global_position.y)

	if _fail:
		print("RESULT: FAILED")
		quit(1)
	else:
		print("RESULT: ALL PASS")
		quit(0)

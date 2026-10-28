extends SceneTree
## L01-P0-07c/07d/07e/08 验收测试（BUILD_PLAN.md）：A1–A8+走廊+房门机制+门常开+未清区域封禁+死亡流程。headless 运行。
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
	LevelGenerator.section_override = "### 6.2"  # 本测试绑定 L01 布局（§6.2 断言），覆写生成器小节（L02-P0-03）
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

	# T4: 相机 Limits = 208×52 tile（3328×832 px，§6.2 校验，走廊 12 tile）
	var cam: Camera2D = player.get_node("Camera2D")
	var ok4: bool = cam.limit_right == 3328 and cam.limit_bottom == 832 and cam.limit_left == 0 and cam.limit_top == 0
	_check("T4 camera_limits", ok4, "limits=(%d,%d,%d,%d)" % [cam.limit_left, cam.limit_top, cam.limit_right, cam.limit_bottom])

	# T5: tile 总数 = 8×640 + 9×72 = 5768（§6.2 校验）
	var tm: TileMapLayer = null
	for c in level.get_children():
		if c is TileMapLayer:
			tm = c
	_check("T5 tiles", tm != null and tm.get_used_cells().size() == 5768, "used=%d (期望 5768)" % (tm.get_used_cells().size() if tm != null else -1))

	# T6: 玩家在 A1 出生房 (6,10)（A1 格位 (0,1) → origin tile (0,32)）
	var ok6: bool = player != null and player.global_position.distance_to(Vector2(104, 680)) < 1.0
	_check("T6 player_spawn", ok6, "pos=%s" % (player.global_position if player != null else Vector2.INF))

	# T7: A1 东门已解锁未开（碰撞在）→ 靠近 ≤2 tile 自动开（蓝）→ 可穿过进走廊（§2）
	var g_a1e := _gate(level, "E|A1|A2")
	var ok7a: bool = g_a1e != null and not g_a1e.open and g_a1e.unlocked
	_check("T7a a1e_unlocked_closed", ok7a, "gate=%s unlocked=%s open=%s" % [g_a1e != null, g_a1e.unlocked if g_a1e else "-", g_a1e.open if g_a1e else "-"])
	player.global_position = Vector2(476, 672)  # 门中心 (504,672) 距离 28px ≤32（§4.7）
	await physics_frame
	await physics_frame
	var ok7b: bool = g_a1e.open
	_check("T7b a1e_auto_open", ok7b, "open=%s (期望 靠近自动开)" % g_a1e.open)
	player.velocity = Vector2.ZERO
	await _push("move_right", 2 * 60)
	var ok7c: bool = player.global_position.x >= 704.0  # 已穿门+12 tile 走廊（走廊 512..704）
	_check("T7c a1e_passable", ok7c, "x=%.2f (期望 ≥704)" % player.global_position.x)
	# T7d: 门首次开启后常开不回关（§2 房门规则，L01-P0-07d）：穿门走远（≥56px>32）仍开+无碰撞
	var shape: CollisionShape2D = g_a1e.get_node("Body/Shape")
	var ok7d: bool = g_a1e.open and shape.disabled
	_check("T7d a1e_stays_open", ok7d, "open=%s no_collision=%s (期望 常开)" % [g_a1e.open, shape.disabled])

	# T8: A2 北门锁定 → 靠近不开、碰撞阻挡（§2：清怪前四周门锁）
	var g_a2n := _gate(level, "N|A2|A3")
	var ok8a: bool = g_a2n != null and not g_a2n.unlocked and not g_a2n.open
	_check("T8a a2n_locked", ok8a, "gate=%s unlocked=%s" % [g_a2n != null, g_a2n.unlocked if g_a2n else "-"])
	player.global_position = Vector2(960, 546)  # A2 北门 (960,520) 下方
	player.velocity = Vector2.ZERO
	await _push("move_up", 1 * 60)
	var ok8b: bool = player.global_position.y >= 532.0  # 门体 512..528+半宽 → 被阻挡
	_check("T8b a2n_blocks", ok8b, "y=%.2f (期望 ≥532 被阻挡)" % player.global_position.y)

	# T9: 清空 A2（击杀其全部敌人）→ 区域已清 → 北门解锁 → 靠近自动开 → 穿门
	# （L02-P0-01 起 E02 已实装：§6.2 战斗区敌人=E01×2+E02×2，清怪范围含 E02；验收语义不变=清空才解锁）
	var a2_killed := 0
	for c in level.get_children():
		var s: Script = c.get_script() if c is Node2D else null
		if s != null and (str(s.resource_path).ends_with("e01.gd") or str(s.resource_path).ends_with("e02.gd")) and is_instance_valid(c) and c.hp > 0:
			var p: Vector2 = c.global_position
			if p.x >= 704.0 and p.x <= 1216.0 and p.y >= 512.0 and p.y <= 832.0:  # A2 范围（origin 704,512）
				c.take_damage(999)
				a2_killed += 1
	await physics_frame
	await physics_frame
	var ok9a: bool = a2_killed == 4 and g_a2n.unlocked \
		and _gate(level, "E|A2|A5").unlocked and _gate(level, "W|A5|A2").unlocked  # 自身侧门解锁+W|A5|A2 区域外可进入（§2 L01-P0-07e）
	_check("T9a a2_clear_unlock", ok9a, "killed=%d a2n=%s a2e=%s a5w=%s" % [a2_killed, g_a2n.unlocked, _gate(level, "E|A2|A5").unlocked, _gate(level, "W|A5|A2").unlocked])
	player.global_position = Vector2(960, 546)
	player.velocity = Vector2.ZERO
	await physics_frame
	await physics_frame
	var ok9b: bool = g_a2n.open
	_check("T9b a2n_auto_open", ok9b, "open=%s" % g_a2n.open)
	await _push("move_up", 2 * 60)
	var ok9c: bool = player.global_position.y <= 480.0  # 已穿门进入北走廊（走廊 y 320..512）
	_check("T9c a2n_passable", ok9c, "y=%.2f (期望 ≤480)" % player.global_position.y)

	# T11: 未清区域封禁（§2 L01-P0-07e 用户指令）：区域内除入口门外重新锁定，走出恢复，重进可换入口
	var g_a5w := _gate(level, "W|A5|A2")   # A5 西门 (1416,672)
	var g_a5n := _gate(level, "N|A5|A4")   # A5 北门 (1664,520)
	var g_a5e := _gate(level, "E|A5|A6")   # A5 东门 (1912,672)
	player.global_position = Vector2(1664, 672)  # 直接传送进未清 A5（矩形 1408..1920 × 512..832）
	player.velocity = Vector2.ZERO
	await physics_frame
	await physics_frame
	# T11a: 入口门=最近门（北门 d=152）→ 其余门重新锁定
	var ok11a: bool = not g_a5w.unlocked and not g_a5e.unlocked and g_a5n.unlocked
	_check("T11a a5_seal", ok11a, "a5w=%s a5n=%s a5e=%s (期望 w锁 n=入口 e锁)" % [g_a5w.unlocked, g_a5n.unlocked, g_a5e.unlocked])
	await _push("move_left", 2 * 60)  # 朝西门走 2s（约 280px）→ 被锁定门阻挡
	var ok11b: bool = player.global_position.x >= 1424.0  # 门体 1408..1424 东缘 → 未穿出
	_check("T11b a5w_blocks", ok11b, "x=%.2f (期望 ≥1424 被阻挡)" % player.global_position.x)
	player.global_position = Vector2(960, 672)  # 走出 A5 → A2（已清）
	player.velocity = Vector2.ZERO
	await physics_frame
	await physics_frame
	var ok11c: bool = g_a5w.unlocked and g_a5e.unlocked  # 区域外恢复可通行（进入态）
	_check("T11c a5_exit_release", ok11c, "a5w=%s a5e=%s (期望 均解锁)" % [g_a5w.unlocked, g_a5e.unlocked])
	player.global_position = Vector2(1430, 672)  # 重进 A5（西门旁）→ 入口门=西门
	player.velocity = Vector2.ZERO
	await physics_frame
	await physics_frame
	var ok11d: bool = g_a5w.unlocked and not g_a5n.unlocked  # 入口换为西门，北门重新锁定
	_check("T11d a5_reentry_entry_swap", ok11d, "a5w=%s a5n=%s (期望 w=入口 n重锁)" % [g_a5w.unlocked, g_a5n.unlocked])

	# T10: 死亡弹窗与重开（§8/§9，L01-P0-08）
	player.take_damage(999)  # HP 归 0 → died 信号 → 弹窗（惰性实例化）+暂停
	await physics_frame
	var dialog: DeathDialog = null
	for c in level.get_children():
		if c is DeathDialog:  # 精确匹配（L01-P1-02：HUD 也是 CanvasLayer，不可泛匹配）
			dialog = c
	var ok10a: bool = dialog != null and dialog.visible and paused
	_check("T10a death_dialog", ok10a, "dialog=%s visible=%s paused=%s" % [dialog != null, dialog.visible if dialog != null else "-", paused])
	# T10b: 结算退出=占位（§9 用户指令）：点击仅打印，弹窗保持、游戏仍暂停
	current_scene = level  # --script 模式无主场景，手动指定供 reload_current_scene 使用
	(dialog.get_node("Panel/VBox/QuitBtn") as Button).pressed.emit()
	var ok10b: bool = dialog.visible and paused
	_check("T10b quit_placeholder", ok10b, "visible=%s paused=%s（占位无副作用）" % [dialog.visible, paused])
	# T10c: 重新挑战 → 重载场景：出生点+升级/金币清空（§9）
	(dialog.get_node("Panel/VBox/RetryBtn") as Button).pressed.emit()
	for i in 5:
		await process_frame
	var lvl2: Node = current_scene
	var p2: CharacterBody2D = lvl2.get("player") if lvl2 != null else null
	var ok10c: bool = lvl2 != null and lvl2 != level and p2 != null \
		and p2.global_position.distance_to(Vector2(104, 680)) < 1.0 \
		and p2.hp == 6 and p2.level == 1 and p2.coins == 0  # 出生点+升级/金币清空（§9）
	_check("T10c retry_reset", ok10c, "scene_swapped=%s pos=%s hp=%s lv=%s coins=%s" % [lvl2 != level, p2.global_position if p2 != null else "-", p2.hp if p2 != null else "-", p2.level if p2 != null else "-", p2.coins if p2 != null else "-"])
	# T10d: 区域怪物复活（§6.1：A2–A7 各 2 只 E01）
	var e01_count := 0
	for c in lvl2.get_children():
		var s: Script = c.get_script() if c is Node2D else null
		if s != null and str(s.resource_path).ends_with("e01.gd") and is_instance_valid(c) and c.hp > 0:
			e01_count += 1
	_check("T10d enemies_revived", e01_count == 10, "e01=%d (期望 10)" % e01_count)
	# T10e: 重载干净=无残留弹窗（未死亡不弹窗）、游戏未暂停
	var d2: DeathDialog = null
	for c in lvl2.get_children():
		if c is DeathDialog:  # 精确匹配（L01-P1-02：HUD 也是 CanvasLayer，不可泛匹配）
			d2 = c
	_check("T10e clean_reload", d2 == null and not paused, "leftover_dialog=%s paused=%s" % [d2 != null, paused])

	if _fail:
		print("RESULT: FAILED")
		quit(1)
	else:
		print("RESULT: ALL PASS")
		quit(0)

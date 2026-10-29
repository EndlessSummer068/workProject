extends "res://tests/test_base.gd"
## L02-P0-04b 敌人区域房钳制 + 宝箱区域清空解锁 验收测试（BUILD_PLAN.md）：headless 运行（看门狗基类=TECH §17）。
## 覆盖：E04/E05 追击房外玩家不越区域房界（钳制 margin=8px 实际贴边）；宝箱 provider=false 按 E 不开、=true 可开；
## L02 真实接线（全部敌人注入 room_rect、宝箱 provider 绑定且敌人存活时不可开）。
## 运行：Godot_v4.7.2 --headless --path <项目> --script res://tests/test_room_lock.gd

func _run() -> void:
	var player: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	var e04: EnemyE04 = (load("res://scenes/enemies/e04.tscn") as PackedScene).instantiate()
	var e05: EnemyE05 = (load("res://scenes/enemies/e05.tscn") as PackedScene).instantiate()
	var room := Rect2(0, 0, 512, 320)  # 模拟区域房矩形（px 含墙，同 A1 量级）
	var clamp_max := room.end.x - Balance.ENEMY_ROOM_MARGIN  # 504：钳制后中心 x 上限
	player.global_position = Vector2(640, 160)  # 房外右侧（>房右缘 512）
	e04.global_position = Vector2(490, 160)     # 房内：距玩家 150 <触发 160 → 追击
	e05.global_position = Vector2(500, 160)     # 距玩家 140 ∈(128,160) → 追近（贴右墙放置使钳制必绑定）
	e04.room_rect = room
	e05.room_rect = room
	root.add_child(player)
	root.add_child(e04)
	root.add_child(e05)
	await physics_frame
	await physics_frame
	var e5_x0 := e05.global_position.x  # 基线在摆位后立即取（T1 窗口内 E05 已开始追近，勿在 T1 后读）

	# ---- T1: E04 追击房外玩家 → 钳在房右缘内侧（margin=8），不出房 ----
	for i in 60:
		await physics_frame
	_check("T1_e04_room_lock", absf(e04.global_position.x - clamp_max) <= 0.5 \
		and e04.global_position.x < player.global_position.x,
		"x=%.2f (期望 ≈%.0f=房缘-8 贴边徘徊，未到玩家 x=%.0f)" % [e04.global_position.x, clamp_max, player.global_position.x])
	# ---- T2: E05 追近房外玩家 → 同样钳在房缘（移动过且不越界；位移含 T1 窗口）----
	for i in 60:
		await physics_frame
	_check("T2_e05_room_lock", e05.global_position.x > e5_x0 + 1.0 and e05.global_position.x <= clamp_max + 0.5,
		"x=%.0f→%.2f (期望移动且 ≤%.0f)" % [e5_x0, e05.global_position.x, clamp_max])
	e04.global_position = Vector2(-2000, -2000)  # 拉出止追/止伤
	e05.global_position = Vector2(-2000, -1000)
	player.hp = Balance.PLAYER_MAX_HP
	await physics_frame

	# ---- T3/T4: 宝箱区域清空门槛（§4.5，2026-10-29 用户指令）----
	var chest: Chest = (load("res://scenes/rewards/r02.tscn") as PackedScene).instantiate()
	var panel: ChestPanel = (load("res://scenes/ui/chest_panel.tscn") as PackedScene).instantiate()
	chest.global_position = player.global_position + Vector2(-16, 0)  # <交互半径 32
	root.add_child(panel)
	root.add_child(chest)
	chest.set_player(player)
	chest.set_panel(panel)
	chest.area_cleared_provider = func() -> bool: return false  # 模拟区域未清
	await physics_frame
	Input.action_press("interact")
	for i in 2:
		await physics_frame
	Input.action_release("interact")
	for i in 2:
		await physics_frame
	_check("T3_chest_locked", not panel.visible and not player.input_blocked,
		"visible=%s blocked=%s (期望 区域未清按 E 无效)" % [panel.visible, player.input_blocked])

	chest.area_cleared_provider = func() -> bool: return true  # 模拟区域已清
	Input.action_press("interact")
	for i in 2:
		await physics_frame
	Input.action_release("interact")
	for i in 2:
		await physics_frame
	_check("T4_chest_unlocked", panel.visible and player.input_blocked,
		"visible=%s blocked=%s (期望 区域已清按 E 开面板)" % [panel.visible, player.input_blocked])
	panel.close()

	# ---- T5: L02 真实接线（§6.3）：全部敌人注入 room_rect；宝箱 provider 绑定且未清 ----
	LevelGenerator.section_override = ""  # 默认 §6.3（L02 地图）
	var level: Node = (load("res://scenes/levels/level.tscn") as PackedScene).instantiate()
	root.add_child(level)
	for i in 10:
		await physics_frame
	var enemies_total := 0
	var enemies_roomed := 0
	var chest_found := 0
	var chest_ok := true
	for c in level.get_children():
		if c is EnemyE01 or c is EnemyE02 or c is EnemyE04 or c is EnemyE05:
			enemies_total += 1
			var rect: Rect2 = c.get("room_rect")
			if rect.size != Vector2.ZERO:
				enemies_roomed += 1
		elif c is Chest:
			chest_found += 1
			var prov: Callable = (c as Chest).area_cleared_provider
			if not prov.is_valid() or prov.call():
				chest_ok = false  # provider 缺失，或敌人存活区域被误判已清
	_check("T5_l02_wiring", enemies_total >= 10 and enemies_roomed == enemies_total \
		and chest_found >= 1 and chest_ok,
		"敌人房矩形 %d/%d；宝箱 %d 个 provider 有效且未清=%s" % [enemies_roomed, enemies_total, chest_found, chest_ok])

	if _fail:
		print("RESULT: FAILED")
		quit(1)
	else:
		print("RESULT: ALL PASS")
		quit(0)

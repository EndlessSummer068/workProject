extends "res://tests/test_base.gd"
## L02 全链路 headless 回归（BUILD_PLAN L02-P1-01）：单实例真实关卡串跑
## 地图解析 → 商店购买 → 宝箱区域解锁+3 选 1 → B02 击杀通关提示 → 传送回传。
## 运行：Godot_v4.7.2 --headless --path <项目> --script res://tests/test_l02_regression.gd

func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame

func _run() -> void:
	LevelGenerator.section_override = ""
	var level: Node = (load("res://scenes/levels/level.tscn") as PackedScene).instantiate()
	root.add_child(level)
	await _wait(10)
	var player: Player = level.player

	# ---- R1: 地图解析（§6.3：8 区域 32×20、敌人/宝箱/商店/传送点齐备）----
	var sizes_ok := true
	for id: String in level._room_rects:
		sizes_ok = sizes_ok and (level._room_rects[id] as Rect2).size == Vector2(32, 20) * LevelGenerator.TILE
	var enemy_total := 0
	for id: String in level._area_enemies:
		enemy_total += (level._area_enemies[id] as Array).size()
	_check("R1_map", level._room_rects.size() == 8 and sizes_ok and enemy_total > 0 \
		and level._chests.size() >= 3 and level._shop_point != null and level._teleport != null and level.doors.size() > 0,
		"区域=%d 尺寸ok=%s 敌人=%d 宝箱=%d 商店=%s 传送=%s 门=%d" % [level._room_rects.size(), sizes_ok, enemy_total,
		level._chests.size(), level._shop_point != null, level._teleport != null, level.doors.size()])

	# ---- R2: 商店购买（§4.5）：E 开面板、买 W02 扣 80、金币 100→20 ----
	player.hp = player.max_hp
	player.global_position = level._shop_point.global_position
	await _wait(2)
	Input.action_press("interact")
	await _wait(2)
	Input.action_release("interact")
	await _wait(1)
	var shop_panel: ShopPanel = level._shop_panel
	var opened: bool = shop_panel.visible
	player.coins = 100
	player.coins_changed.emit(player.coins)
	shop_panel._buttons["W02"].pressed.emit()
	await _wait(1)
	var buy_ok: bool = player.weapon_id == "W02" and player.coins == 20 and player.weapon_stacks["W02"] == 0
	shop_panel.close()
	await _wait(1)
	_check("R2_shop_buy", opened and buy_ok and not shop_panel.visible,
		"opened=%s weapon=%s coins=%d 层=%d 关闭=%s" % [opened, player.weapon_id, player.coins,
		player.weapon_stacks.get("W02", -1), not shop_panel.visible])

	# ---- R3: 宝箱区域解锁 + 3 选 1（§4.5）：未清区域按 E 无效；清空后可开并选卡 ----
	var chest: Chest = null
	var chest_area := ""
	for c: Chest in level._chests:
		for id: String in level._room_rects:
			if (level._room_rects[id] as Rect2).has_point(c.global_position) and not level._areas_cleared.get(id, false):
				chest = c
				chest_area = id
	player.hp = player.max_hp
	player.global_position = chest.global_position
	await _wait(2)
	Input.action_press("interact")
	await _wait(2)
	Input.action_release("interact")
	await _wait(1)
	var blocked_ok: bool = not level._chest_panel.visible
	for e: CharacterBody2D in level._area_enemies[chest_area]:
		if is_instance_valid(e) and e.hp > 0:
			e.take_damage(999)
	await _wait(3)
	player.hp = player.max_hp
	Input.action_press("interact")
	await _wait(2)
	Input.action_release("interact")
	await _wait(1)
	var panel: ChestPanel = level._chest_panel
	var open_ok: bool = panel.visible and level._areas_cleared.get(chest_area, false)
	var buff_before: int = player.buff_stacks[panel._buff_id]
	var picked_id: String = panel._buff_id
	panel._buttons["buff"].pressed.emit()
	await _wait(2)
	_check("R3_chest_unlock_choice", blocked_ok and open_ok and not is_instance_valid(chest) \
		and not panel.visible and player.buff_stacks[picked_id] == buff_before + 1,
		"未清拦截=%s 清后可开=%s 区域=%s 选=%s %d→%d 宝箱消失=%s" % [blocked_ok, open_ok, chest_area,
		picked_id, buff_before, player.buff_stacks[picked_id], not is_instance_valid(chest)])

	# ---- R4: B02 击杀 → 「L02 通关」占位提示（§9）+ 掉落 R01 金币+20 ----
	var boss: EnemyB02 = null
	for child in level.get_children():
		if child is EnemyB02:
			boss = child
	# R01 掉落挂在敌人父节点（=本关卡 level）：击杀前后快照差分（不依赖 child_entered_tree 时序）；
	# 同名节点被 add_child 自动改名为 @R01@N，故用脚本类型判定而非节点名。
	var r01_script := preload("res://scripts/rewards/r01.gd")
	var before_drops := {}
	for c in level.get_children():
		if c.get_script() == r01_script:
			before_drops[c.get_instance_id()] = true
	var coins_before := player.coins
	boss.take_damage(999)
	await _wait(3)
	var new_drops: Array = []
	for c in level.get_children():
		if c.get_script() == r01_script and not before_drops.has(c.get_instance_id()):
			new_drops.append(c)
	var banner: Label = level._hud.get_node("ClearLabel")
	var pickup_ok := false
	if not new_drops.is_empty():
		player.hp = player.max_hp
		player.global_position = (new_drops[-1] as Area2D).global_position
		await _wait(4)
		pickup_ok = not is_instance_valid(new_drops[-1]) or (new_drops[-1] as Area2D).is_queued_for_deletion()
	_check("R4_boss_clear", level._boss_defeated and banner.visible and banner.text.contains("L02 通关") \
		and new_drops.size() >= 1 and pickup_ok and player.coins >= coins_before + Balance.R01_COIN_BOSS,
		"boss_defeated=%s 横幅=%s/%s 掉落=%d 拾取=%s 金币=%d→%d（期望 +20）" % [level._boss_defeated,
		banner.visible, banner.text, new_drops.size(), pickup_ok, coins_before, player.coins])

	# ---- R5: 传送点回传（§4.5，L02-P1-01）：A6 → A5 记录，按 E 回过 A6 门内侧 ----
	player.hp = player.max_hp
	player.global_position = level._room_rects["A6"].get_center()
	await _wait(2)
	player.global_position = level._room_rects["A5"].get_center()
	await _wait(2)
	var ret: Vector2 = level._return_point
	player.global_position = level._teleport.global_position
	await _wait(2)
	Input.action_press("interact")
	await _wait(2)
	Input.action_release("interact")
	await _wait(1)
	_check("R5_teleport", level._has_return and level._room_rects["A6"].has_point(ret) \
		and player.global_position.is_equal_approx(ret),
		"has_return=%s 落点=%s（A6=%s）实际=%s" % [level._has_return, ret, level._room_rects["A6"], player.global_position])

	if _fail:
		print("RESULT: FAILED")
		quit(1)
	else:
		print("RESULT: ALL PASS")
		quit(0)

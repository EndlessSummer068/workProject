extends "res://tests/test_base.gd"
## L02-P0-02b 宝箱 3 选 1 鼠标化 验收测试（BUILD_PLAN.md）：headless 运行。
## 运行：Godot_v4.7.2 --headless --path <项目> --script res://tests/test_chest.gd
## 覆盖：E 开面板/武器获得与叠层/满层金币+10/buff 槽随机与刷新/R04 卡/Esc 保留/选择后消失/输入屏蔽。
## L02-P1-02 追加：宝箱刷新按钮（重抽 buff 槽，不重复、免费不限次）+ 3 槽（武器/buff/R04）。

const FRAME_WAIT := 2




func _spawn_chest() -> Chest:
	var chest: Chest = (load("res://scenes/rewards/r02.tscn") as PackedScene).instantiate()
	root.add_child(chest)
	chest.global_position = Vector2(0, 16)
	chest.set_player(player)
	chest.set_panel(panel)
	return chest

var player: Player
var panel: ChestPanel

func _run() -> void:
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	root.add_child(player)
	player.global_position = Vector2.ZERO
	panel = (load("res://scenes/ui/chest_panel.tscn") as PackedScene).instantiate()
	root.add_child(panel)
	await physics_frame
	await physics_frame

	var opened: Array = []
	var chosen: Array = []
	panel.chest_opened.connect(func(): opened.append(1))
	panel.chest_choice_made.connect(func(id: String): chosen.append(id))

	# ---- T0: 开局金币 200（§4.5）----
	_check("T0_start_coins", player.coins == Balance.PLAYER_START_COINS, "coins=%d" % player.coins)

	# ---- T1: 靠近按 E 开面板 + 输入屏蔽（§4.5/§8）----
	var chest := _spawn_chest()
	Input.action_press("interact")
	for i in FRAME_WAIT:
		await physics_frame
	Input.action_release("interact")
	await physics_frame
	var x_before := player.global_position.x
	Input.action_press("move_right")
	for i in 5:
		await physics_frame
	Input.action_release("move_right")
	_check("T1_open_block", panel.visible and player.input_blocked and opened.size() == 1
		and player.global_position.x == x_before,
		"visible=%s blocked=%s opened=%d dx=%.3f" % [panel.visible, player.input_blocked, opened.size(), player.global_position.x - x_before])

	# ---- T2: 点武器卡 → 获得 W02（免费+装备，金币不变）+宝箱消失（§4.5）----
	panel._buttons["weapon"].pressed.emit()
	await physics_frame
	_check("T2_chest_weapon_get", player.weapon_id == "W02" and player.weapon_stacks["W02"] == 0
		and player.weapon_buys["W02"] == 1 and player.coins == Balance.PLAYER_START_COINS
		and chosen.has("W02") and not is_instance_valid(chest) and not panel.visible,
		"weapon=%s 层=%d 金币=%d chest_freed=%s" % [player.weapon_id, player.weapon_stacks["W02"], player.coins, not is_instance_valid(chest)])

	# ---- T3: Esc 放弃 → 宝箱保留可再开（§4.5）----
	var chest2 := _spawn_chest()
	panel.open(player, chest2)
	var ev := InputEventAction.new()
	ev.action = "ui_cancel"
	ev.pressed = true
	Input.parse_input_event(ev)
	for i in FRAME_WAIT:
		await physics_frame
	_check("T3_esc_keep", not panel.visible and not player.input_blocked
		and is_instance_valid(chest2) and not chest2.is_queued_for_deletion(),
		"visible=%s blocked=%s chest_alive=%s" % [panel.visible, player.input_blocked, is_instance_valid(chest2)])

	# ---- T4: 已持有武器 → 叠层+1（免费）（§4.5）----
	panel.open(player, chest2)
	panel._buttons["weapon"].pressed.emit()
	await physics_frame
	_check("T4_chest_stack", player.weapon_stacks["W02"] == 1 and player.coins == Balance.PLAYER_START_COINS,
		"层=%d 金币=%d" % [player.weapon_stacks["W02"], player.coins])

	# ---- T5: 刷新按钮 → 重抽 buff 槽（不与当前重复、免费不限次、发 chest_rerolled）----
	var rerolled: Array = []
	panel.chest_rerolled.connect(func(id: String): rerolled.append(id))
	var chest3 := _spawn_chest()
	panel.open(player, chest3)
	var buff_before: String = panel._buff_id
	var changes: Array = []
	for i in 6:  # 连续刷新多次，每次都必须与上一次不同
		var prev: String = panel._buff_id
		panel._reroll.pressed.emit()
		changes.append(panel._buff_id != prev and panel._buff_id in ChestPanel.BUFF_POOL)
	_check("T5_reroll", buff_before in ChestPanel.BUFF_POOL and rerolled.size() == 6 and changes.all(func(ok: bool) -> bool: return ok)
		and player.coins == Balance.PLAYER_START_COINS,
		"初=%s 刷新=%d 每次变化=%s 金币=%d" % [buff_before, rerolled.size(), changes, player.coins])

	# ---- T5b: 点 buff 卡 → 当前 buff 槽 +1 张（§4.5/§4.6）----
	var buff_id: String = panel._buff_id
	panel._buttons["buff"].pressed.emit()
	await physics_frame
	_check("T5b_chest_buff", player.buff_stacks[buff_id] == 1 and not is_instance_valid(chest3),
		"%s=%d" % [buff_id, player.buff_stacks[buff_id]])

	# ---- T6: R04 卡 → +1（§4.5）----
	var chest4 := _spawn_chest()
	panel.open(player, chest4)
	panel._buttons["r04"].pressed.emit()
	await physics_frame
	_check("T6_chest_r04", player.r04_count == 1 and not is_instance_valid(chest4),
		"R04=%d" % player.r04_count)

	# ---- T7: 满层武器卡 → 金币+10（§4.5 提案）----
	player.weapon_stacks["W02"] = Balance.WEAPON_MAX_STACKS  # 直接置满层
	var chest5 := _spawn_chest()
	panel.open(player, chest5)
	var coins_before := player.coins
	panel._buttons["weapon"].pressed.emit()
	await physics_frame
	_check("T7_chest_full_stack_coin", player.coins == coins_before + Balance.CHEST_MAX_STACK_COIN
		and player.weapon_stacks["W02"] == Balance.WEAPON_MAX_STACKS,
		"金币=%d→%d（+%d）层=%d" % [coins_before, player.coins, Balance.CHEST_MAX_STACK_COIN, player.weapon_stacks["W02"]])

	if _fail:
		print("RESULT: FAILED")
		quit(1)
	else:
		print("RESULT: ALL PASS")
		quit(0)
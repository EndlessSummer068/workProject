extends SceneTree
## L02-P0-02a 商店 S 与金币消费逻辑 验收测试（BUILD_PLAN.md）：headless 运行。
## 运行：Godot_v4.7.2 --headless --path <项目> --script res://tests/test_shop.gd
## 覆盖：E 开面板/输入屏蔽/再按 E 不重复/Esc 关闭/R04 购买+H 使用/U01 无敌/U02 回蓝
## /U03 命中回蓝/武器购买装备切换/已持有拦截/金币不足拦截/不限购。

const FRAME_WAIT := 2  # 输入注入后的等待帧数

var _fail := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	# ---- 场景搭建：先摆位再 add_child（防出生重叠假触发，L02-P0-01 教训）----
	var player: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	root.add_child(player)
	player.global_position = Vector2.ZERO
	var point: ShopPoint = (load("res://scenes/levels/shop_point.tscn") as PackedScene).instantiate()
	root.add_child(point)
	point.global_position = Vector2(0, 16)  # 距玩家 16px < 交互半径 32px（§4.5）
	var panel: ShopPanel = (load("res://scenes/ui/shop_panel.tscn") as PackedScene).instantiate()
	root.add_child(panel)
	point.set_player(player)
	point.set_panel(panel)
	# 假目标（U03 命中回蓝用）：StaticBody2D 碰撞层 4（同 test_arena Dummy），置于 W01 扇形内
	# 注意：必须挂 CollisionShape2D，否则物理引擎不配对（Area2D 检测不到裸 StaticBody2D）
	var dummy := StaticBody2D.new()
	dummy.collision_layer = 4
	dummy.set_script(load("res://scripts/levels/test_dummy.gd"))
	var dummy_shape := CollisionShape2D.new()
	var dummy_rect := RectangleShape2D.new()
	dummy_rect.size = Vector2(16, 16)
	dummy_shape.shape = dummy_rect
	dummy.add_child(dummy_shape)
	root.add_child(dummy)
	dummy.global_position = Vector2(40, 0)
	await physics_frame
	await physics_frame

	var opened: Array = []   # lambda 按值捕获标量不可靠 → 数组引用（L02-P0-07 教训）
	var closed: Array = []
	var bought: Array = []
	var attacks: Array = []
	panel.shop_opened.connect(func(): opened.append(1))
	panel.shop_closed.connect(func(): closed.append(1))
	panel.item_purchased.connect(func(id: String): bought.append(id))
	player.attacked.connect(func(_f: Vector2): attacks.append(1))

	# ---- T0: 开局金币=200（§4.5 正式规则，2026-10-29 用户指令）----
	_check("T0_start_coins", player.coins == Balance.PLAYER_START_COINS
		and player.weapon_stacks.has("W01") and player.weapon_buys["W01"] == 1,
		"coins=%d stacks=%s buys=%s" % [player.coins, player.weapon_stacks, player.weapon_buys])

	# ---- T1: 靠近按 E 打开面板（§4.5/§8）----
	Input.action_press("interact")
	for i in FRAME_WAIT:
		await physics_frame
	Input.action_release("interact")
	await physics_frame
	_check("T1 open_by_E", panel.visible and player.input_blocked and opened.size() == 1,
		"visible=%s blocked=%s opened=%d" % [panel.visible, player.input_blocked, opened.size()])

	# ---- T2: 面板打开期间移动/攻击被屏蔽（§8/TECH §16）----
	var x_before := player.global_position.x
	Input.action_press("move_right")
	Input.action_press("attack")
	for i in 20:
		await physics_frame
	Input.action_release("move_right")
	Input.action_release("attack")
	_check("T2 input_blocked", player.global_position.x == x_before and attacks.is_empty(),
		"dx=%.3f attacks=%d" % [player.global_position.x - x_before, attacks.size()])

	# ---- T3: 面板打开期间再按 E 不重复触发（TECH §16）----
	Input.action_press("interact")
	for i in FRAME_WAIT:
		await physics_frame
	Input.action_release("interact")
	await physics_frame
	_check("T3 no_reopen", opened.size() == 1, "opened=%d" % opened.size())

	# ---- T4: Esc 关闭 → 输入恢复（§8）----
	var ev := InputEventAction.new()
	ev.action = "ui_cancel"
	ev.pressed = true
	Input.parse_input_event(ev)
	for i in FRAME_WAIT:
		await physics_frame
	Input.action_press("move_right")
	for i in 5:
		await physics_frame
	Input.action_release("move_right")
	_check("T4 esc_close_resume", not panel.visible and not player.input_blocked
		and closed.size() == 1 and player.global_position.x > x_before,
		"visible=%s blocked=%s closed=%d dx=%.1f" % [panel.visible, player.input_blocked, closed.size(), player.global_position.x - x_before])

	# ---- T5: R04 购买扣费 + H 使用回血（§4.5）----
	# 注：面板打开期间 H 被屏蔽（§8）——先关面板再按 H，符合实际操作序列
	panel.open(player)
	player.coins = 100
	player.coins_changed.emit(player.coins)
	panel._buttons["R04"].pressed.emit()  # 模拟鼠标点击卡片（按钮 pressed 驱动=TECH §16）
	await physics_frame
	var ok_r04: bool = player.coins == 70 and player.r04_count == 1 and bought.has("R04")
	panel.close()
	player.take_damage(4)  # 防御 0 → HP 6→2
	for i in FRAME_WAIT:
		await physics_frame
	Input.action_press("use_item")
	for i in FRAME_WAIT:
		await physics_frame
	Input.action_release("use_item")
	await physics_frame
	_check("T5_r04_buy_use", ok_r04 and player.hp == 4 and player.r04_count == 0,
		"coins=%d r04=%d hp=%d" % [player.coins, player.r04_count, player.hp])
	panel.open(player)  # 重开面板继续购买类测试

	# ---- T6: U01 购买 → 受击无敌 1.0s（§4.6）----
	panel._buttons["U01"].pressed.emit()  # -60 → coins=10
	await physics_frame
	var hp0 := player.hp
	player.take_damage(1)  # 触发无敌窗口
	var after_first := player.hp
	player.take_damage(1)  # 无敌窗口内 → 无效
	for i in 66:  # 1.1s（60 物理 fps 折算）
		await physics_frame
	player.take_damage(1)  # 窗口结束 → 生效
	_check("T6_u01_invuln", player.buff_stacks["U01"] == 1 and after_first == hp0 - 1 and player.hp == hp0 - 2,
		"stacks=%d hp=%d→%d→%d" % [player.buff_stacks["U01"], hp0, after_first, player.hp])

	# ---- T7: U02 购买 → MP 恢复 +1/s（§4.6）----
	player.coins = 200
	player.coins_changed.emit(player.coins)
	panel._buttons["U02"].pressed.emit()
	await physics_frame
	player.mp = 50
	for i in 63:  # ≈1.05s × (1 基础+1 U02)=2.1 → +2
		await physics_frame
	_check("T7_u02_regen", player.buff_stacks["U02"] == 1 and player.mp >= 52,
		"stacks=%d mp=%d" % [player.buff_stacks["U02"], player.mp])

	# ---- T8: U03 购买 → 普攻命中 +2 MP（§4.6）----
	# 注：面板打开期间攻击被屏蔽（§8）——先关面板再攻击
	panel._buttons["U03"].pressed.emit()
	await physics_frame
	panel.close()
	player.mp = 0
	Input.action_press("attack")
	for i in FRAME_WAIT:
		await physics_frame
	Input.action_release("attack")
	for i in 10:
		await physics_frame
	_check("T8_u03_on_hit", player.buff_stacks["U03"] == 1 and player.mp == 2,
		"stacks=%d mp=%d（命中+2，自然恢复<1 不干扰）" % [player.buff_stacks["U03"], player.mp])
	panel.open(player)  # 重开面板继续购买类测试

	# ---- T9: 武器首购=获得+装备；同款再买=叠层+1 攻击+10%（§4.2/§4.5，L02-P0-02b）----
	player.coins = 600
	player.coins_changed.emit(player.coins)
	panel._buttons["W02"].pressed.emit()  # 首购 -80 → 520 层0 atk=18
	await physics_frame
	var atk_first := player.attack_power()
	panel._buttons["W02"].pressed.emit()  # 叠1 -80 → 440 层1 atk=round(18×1.1)=20
	await physics_frame
	var atk_s1 := player.attack_power()
	panel._buttons["W02"].pressed.emit()  # 叠2 -80 → 360 层2 atk=round(18×1.2)=22
	await physics_frame
	var atk_s2 := player.attack_power()
	_check("T9_weapon_stack_buy", player.weapon_id == "W02" and atk_first == 18 and atk_s1 == 20 and atk_s2 == 22
		and player.weapon_stacks["W02"] == 2 and player.weapon_buys["W02"] == 3 and player.coins == 360,
		"weapon=%s atk=%d→%d→%d 层=%d 笔=%d 金币=%d" % [player.weapon_id, atk_first, atk_s1, atk_s2,
		player.weapon_stacks["W02"], player.weapon_buys["W02"], player.coins])

	# ---- T14: 武器叠层上限 5 层（§4.2）：叠满后卡片灰+拦截不扣费 ----
	for i in 3:  # 层3/4/5 → -240 → 120
		panel._buttons["W02"].pressed.emit()
		await physics_frame
	var coins_at_full := player.coins  # 120
	panel._buttons["W02"].pressed.emit()  # 满层 → 拦截
	await physics_frame
	_check("T14_max_stack", player.weapon_stacks["W02"] == 5 and player.coins == coins_at_full
		and panel._msg.text.contains("叠层已满"),
		"层=%d 金币=%d→%d msg=%s" % [player.weapon_stacks["W02"], coins_at_full, player.coins, panel._msg.text])

	# ---- T10: 金币不足拦截（§8：提示不扣费）----
	player.coins = 10
	player.coins_changed.emit(player.coins)
	panel._buttons["W03"].pressed.emit()  # 40 金币 > 10
	await physics_frame
	_check("T10_insufficient", player.coins == 10 and not player.weapon_stacks.has("W03")
		and panel._msg.text.contains("金币不足"),
		"coins=%d owned_W03=%s msg=%s" % [player.coins, player.weapon_stacks.has("W03"), panel._msg.text])

	# ---- T11: 不限购（2026-10-29 用户指令）：R04 连买、buff 连买叠加 ----
	player.coins = 300
	player.coins_changed.emit(player.coins)
	for i in 3:
		panel._buttons["R04"].pressed.emit()
		await physics_frame
	panel._buttons["U03"].pressed.emit()
	await physics_frame
	_check("T11_no_limit", player.r04_count == 3 and player.buff_stacks["U03"] == 2
		and player.coins == 300 - 3 * Balance.SHOP_PRICE_R04 - Balance.SHOP_PRICE_BUFF,
		"r04=%d u03=%d coins=%d" % [player.r04_count, player.buff_stacks["U03"], player.coins])

	# ---- T12: 背包区「装备」切换武器（§4.2，L02-P0-02b）----
	panel._buttons["W03"].pressed.emit()  # 买 W03 -40 → 260 层0 装备 W03
	await physics_frame
	var atk_w03 := player.attack_power()  # 6×(1+0.1×(0+0))=6
	panel.close()
	player.equip_weapon("W01")  # 背包区「装备」按钮=直接调 equip（按钮接线在 _refresh_owner）
	var atk_w01 := player.attack_power()  # 10×(1+0.1×(0+0))=10
	panel.open(player)
	_check("T12_equip_switch", player.weapon_id == "W01" and atk_w03 == 6 and atk_w01 == 10,
		"weapon=%s atk_w03=%d atk_w01=%d" % [player.weapon_id, atk_w03, atk_w01])

	# ---- T13: 卖出（§4.5）：装备中不可卖；武器=40×笔数、buff=30/张、R04=15/个 ----
	var coins_sell0 := player.coins  # 260
	var sell_eq: int = player.sell_weapon("W01")  # 装备中 → 0
	var sold_w02: int = player.sell_weapon("W02")  # 6 笔 → 240
	var sold_w03: int = player.sell_weapon("W03")  # 1 笔 → 40
	var sold_u01: int = player.sell_buff("U01")    # 1 张 → 30（T6 买过）
	var sold_r04: int = player.sell_r04()          # 1 个 → 15（T11 剩 3）
	var coins_sell1 := player.coins
	_check("T13_sell", sell_eq == 0 and sold_w02 == 240 and sold_w03 == 40 and sold_u01 == 30 and sold_r04 == 15
		and coins_sell1 == coins_sell0 + 325 and not player.weapon_stacks.has("W02")
		and player.weapon_stacks.has("W01") and player.buff_stacks["U01"] == 0 and player.r04_count == 2,
		"装备卖=%d W02=%d W03=%d U01=%d R04=%d 金币=%d→%d 持有=%s" % [sell_eq, sold_w02, sold_w03, sold_u01, sold_r04, coins_sell0, coins_sell1, player.weapon_stacks.keys()])

	panel.close()
	if _fail:
		print("RESULT: FAILED")
		quit(1)
	else:
		print("RESULT: ALL PASS")
		quit(0)

func _check(name: String, ok: bool, detail: String) -> void:
	print("%s: %s (%s)" % [name, "PASS" if ok else "FAIL", detail])
	_fail = _fail or not ok

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

	# ---- T9: 武器购买=扣 80+装备切换+攻击力生效；已持有拦截（§4.2/§4.5 02a 过渡）----
	player.coins = 200
	player.coins_changed.emit(player.coins)
	panel._buttons["W02"].pressed.emit()
	await physics_frame
	var atk_after := player.attack_power()
	panel._buttons["W02"].pressed.emit()  # 已持有 → 拦截
	await physics_frame
	var coins_after_dup := player.coins
	panel._buttons["W01"].pressed.emit()  # W01 初始已持有 → 拦截
	await physics_frame
	_check("T9_weapon_buy_equip", player.weapon_id == "W02" and atk_after == 18
		and player.coins == 120 and coins_after_dup == 120 and player.owned_weapons.has("W02"),
		"weapon=%s atk=%d coins=%d/%d owned=%s" % [player.weapon_id, atk_after, player.coins, coins_after_dup, player.owned_weapons])

	# ---- T10: 金币不足拦截（§8：提示不扣费）----
	player.coins = 10
	player.coins_changed.emit(player.coins)
	panel._buttons["W03"].pressed.emit()  # 40 金币 > 10
	await physics_frame
	_check("T10_insufficient", player.coins == 10 and not player.owned_weapons.has("W03")
		and panel._msg.text.contains("金币不足"),
		"coins=%d owned_W03=%s msg=%s" % [player.coins, player.owned_weapons.has("W03"), panel._msg.text])

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

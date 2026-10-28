extends SceneTree
## L01-P1-02 HUD 验收测试（BUILD_PLAN.md）：headless 运行。
## L01-P2-01 起含 K 冷却图标真实化验收（TEST5/TEST7/TEST8，§8）。
## 运行：Godot_v4.7.2 --headless --path <项目> --script res://tests/test_hud.gd

var _fail := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var hud_scene: PackedScene = load("res://scenes/ui/hud.tscn")
	var player_scene: PackedScene = load("res://scenes/player/player.tscn")
	var hud: CanvasLayer = hud_scene.instantiate()
	var player: Player = player_scene.instantiate()
	root.add_child(player)
	root.add_child(hud)
	await physics_frame
	await physics_frame
	hud.bind_player(player)

	var hp_label: Label = hud.get_node("HPLabel")
	var coins_label: Label = hud.get_node("CoinsLabel")
	var k_slot: ColorRect = hud.get_node("KSlot")
	var k_label: Label = hud.get_node("KSlot/KLabel")
	var k_ready := Color("f2d57e")   # §7.2 P01 主色调（就绪高亮）
	var k_gray := Color("4a4a55")    # 冷却中灰块（§8）

	# TEST1: 绑定后初始显示（§8 左上=HP/等级、右上=金币）
	var ok1: bool = hp_label.text == "HP 6/6  Lv 1" and coins_label.text == "金币 0"
	_check("TEST1 initial", ok1, "hp='%s' coins='%s'" % [hp_label.text, coins_label.text])

	# TEST2: 玩家受击 → 左上 HP 数字同步变化（验收①，§8 左上=HP/等级）
	player.take_damage(1)
	var ok2: bool = hp_label.text == "HP 5/6  Lv 1"
	_check("TEST2 hp_sync", ok2, "hp='%s'" % hp_label.text)

	# TEST3: 金币入账 → 右上金币变化（验收②，§8 右上=金币）
	player.gain_reward(0, 2)
	var ok3: bool = coins_label.text == "金币 2"
	_check("TEST3 coin_sync", ok3, "coins='%s'" % coins_label.text)

	# TEST4: 升级 → 等级与 HP 上限同步（§8 左上=HP/等级；升级不改当前 HP）
	player.gain_reward(20, 0)
	var ok4: bool = hp_label.text == "HP 5/7  Lv 2"
	_check("TEST4 level_sync", ok4, "hp='%s'" % hp_label.text)

	# TEST5: K 就绪图标=「K」+#F2D57E 高亮（L01-P2-01 真实化，§8）
	var ok5: bool = k_slot.visible and k_slot.color.is_equal_approx(k_ready) and k_label.text == "K"
	_check("TEST5 k_ready_icon", ok5, "visible=%s color=%s text='%s'" % [k_slot.visible, k_slot.color, k_label.text])

	# TEST6: 安全区与字号（§7.4：视口四边内缩 8 px、字号 12/16/24）
	var ok6: bool = hp_label.position.x >= 8.0 and hp_label.position.y >= 8.0 \
		and coins_label.position.x + coins_label.size.x <= 1152.0 - 8.0 \
		and k_slot.position.y + k_slot.size.y <= 648.0 - 8.0 \
		and hp_label.get_theme_font_size("font_size") == 16
	_check("TEST6 safe_area", ok6,
		"hp_pos=%s coins_right=%.0f k_bottom=%.0f" % [hp_label.position, coins_label.position.x + coins_label.size.x, k_slot.position.y + k_slot.size.y])

	# TEST7: 按 K 释放技能 → 图标变灰+剩余秒数（L01-P2-01，§8 冷却中=灰 #4A4A55+向上取整 s）
	Input.action_press("skill")
	await physics_frame
	await physics_frame
	Input.action_release("skill")
	for i in 4:
		await physics_frame
	var ok7: bool = k_slot.color.is_equal_approx(k_gray) and k_label.text == "10"
	_check("TEST7 k_cooldown_icon", ok7, "color=%s text='%s' (期望灰+10)" % [k_slot.color, k_label.text])

	# TEST8: 冷却结束（>10s）→ 图标回就绪（「K」+#F2D57E，§8）
	for i in 620:
		await physics_frame
	var ok8: bool = k_slot.color.is_equal_approx(k_ready) and k_label.text == "K"
	_check("TEST8 k_ready_again", ok8, "color=%s text='%s' (期望回就绪)" % [k_slot.color, k_label.text])

	if _fail:
		print("RESULT: FAILED")
		quit(1)
	else:
		print("RESULT: ALL PASS")
		quit(0)

func _check(name: String, ok: bool, detail: String) -> void:
	print("%s: %s (%s)" % [name, "PASS" if ok else "FAIL", detail])
	_fail = _fail or not ok

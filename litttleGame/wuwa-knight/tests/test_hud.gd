extends "res://tests/test_base.gd"
## L01-P1-02 HUD 验收测试（BUILD_PLAN.md）：headless 运行。
## L01-P2-01 起含 K 冷却图标真实化验收（TEST5/TEST7/TEST8，§8）。
## L02-P0-06 起左上改为四项竖排：等级/HP/防御/MP（§8 用户指令 2026-10-28），TEST1–4/6 同步更新。
## 运行：Godot_v4.7.2 --headless --path <项目> --script res://tests/test_hud.gd



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

	var lv_label: RichTextLabel = hud.get_node("LvLabel")
	var hp_label: RichTextLabel = hud.get_node("HPLabel")
	var def_label: RichTextLabel = hud.get_node("DefLabel")
	var mp_label: RichTextLabel = hud.get_node("MPLabel")
	var coins_label: Label = hud.get_node("CoinsLabel")
	var k_slot: ColorRect = hud.get_node("KSlot")
	var k_label: Label = hud.get_node("KSlot/KLabel")
	var k_ready := Color("f2d57e")   # §7.2 P01 主色调（就绪高亮）
	var k_gray := Color("4a4a55")    # 冷却中灰块（§8）

	# TEST1: 绑定后初始显示（§8 左上=等级/HP/防御/MP 四项竖排、右上=金币）
	var ok1: bool = lv_label.get_parsed_text() == "Lv 1" \
		and hp_label.get_parsed_text() == "HP 6/6" \
		and def_label.get_parsed_text() == "防御 %d" % Balance.PLAYER_DEFENSE \
		and mp_label.get_parsed_text() == "MP 100/100" \
		and coins_label.text == "金币 %d" % Balance.PLAYER_START_COINS  # 开局 200（§4.5，2026-10-29 用户指令）
	_check("TEST1 initial", ok1, "lv='%s' hp='%s' def='%s' mp='%s' coins='%s'" % [lv_label.get_parsed_text(), hp_label.get_parsed_text(), def_label.get_parsed_text(), mp_label.get_parsed_text(), coins_label.text])

	# TEST2: 玩家受击 → 左上 HP 同步（§8；take_damage(1) 在防御 0/1 下均扣 1=保底输出）
	player.take_damage(1)
	var ok2: bool = hp_label.get_parsed_text() == "HP 5/6"
	_check("TEST2 hp_sync", ok2, "hp='%s'" % hp_label.get_parsed_text())

	# TEST2b: HP 数值红 #C0392B、MP 数值蓝 #58C4DD（§8 借 §7.2 现有色，bbcode 染色）
	var ok2b: bool = hp_label.text.contains("#c0392b") and mp_label.text.contains("#58c4dd")
	_check("TEST2b hp_mp_colors", ok2b, "hp='%s' mp='%s'" % [hp_label.text, mp_label.text])

	# TEST3: 金币入账 → 右上金币变化（§8 右上=金币；开局 200 基线，L02-P0-02b）
	player.gain_reward(0, 2)
	var ok3: bool = coins_label.text == "金币 %d" % (Balance.PLAYER_START_COINS + 2)
	_check("TEST3 coin_sync", ok3, "coins='%s'" % coins_label.text)

	# TEST4: 升级 → 等级/HP/防御同步（§8 左上；升级回满血至新上限+防御+1，用户指令 2026-10-29）
	player.gain_reward(20, 0)
	# 升级回满血至新上限+防御+1（§4.1 用户指令 2026-10-29）：HP 7/7、防御行同步刷 1
	var ok4: bool = lv_label.get_parsed_text() == "Lv 2" and hp_label.get_parsed_text() == "HP 7/7" \
		and def_label.get_parsed_text() == "防御 1"
	_check("TEST4 level_sync", ok4, "lv='%s' hp='%s' def='%s'" % [lv_label.get_parsed_text(), hp_label.get_parsed_text(), def_label.get_parsed_text()])

	# TEST4b: 击杀回蓝 → MP 行同步（§8 左上=…MP；TECH §12 mp_changed）
	player.mp = 50
	player.gain_mp(3)
	var ok4b: bool = mp_label.get_parsed_text() == "MP 53/100"
	_check("TEST4b mp_sync", ok4b, "mp='%s'" % mp_label.get_parsed_text())

	# TEST5: K 就绪图标=「K」+#F2D57E 高亮（L01-P2-01 真实化，§8）
	var ok5: bool = k_slot.visible and k_slot.color.is_equal_approx(k_ready) and k_label.text == "K"
	_check("TEST5 k_ready_icon", ok5, "visible=%s color=%s text='%s'" % [k_slot.visible, k_slot.color, k_label.text])

	# TEST6: 安全区与字号（§7.4：视口四边内缩 8 px、字号 12/16/24）
	var ok6: bool = lv_label.position.x >= 8.0 and lv_label.position.y >= 8.0 \
		and mp_label.position.y + mp_label.size.y <= 648.0 - 8.0 \
		and coins_label.position.x + coins_label.size.x <= 1152.0 - 8.0 \
		and k_slot.position.y + k_slot.size.y <= 648.0 - 8.0 \
		and lv_label.get_theme_font_size("normal_font_size") == 16
	_check("TEST6 safe_area", ok6,
		"lv_pos=%s mp_bottom=%.0f coins_right=%.0f k_bottom=%.0f" % [lv_label.position, mp_label.position.y + mp_label.size.y, coins_label.position.x + coins_label.size.x, k_slot.position.y + k_slot.size.y])

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

	# TEST9: buff 图标排（§8 底部中间，L02-P1-02）：生效张数>0 才显示，文案含编号+张数
	var buff_bar: HBoxContainer = hud.get_node("BuffBar")
	var u02_icon: ColorRect = buff_bar.get_node("BuffU02")
	var ok9a: bool = not u02_icon.visible and not buff_bar.get_node("BuffU01").visible
	player.gain_chest_buff("U02")
	player.gain_chest_buff("U02")
	var ok9b: bool = u02_icon.visible and (u02_icon.get_node("Label") as Label).text == "U02 ×2" \
		and not buff_bar.get_node("BuffU03").visible
	player.sell_buff("U02")
	player.sell_buff("U02")
	var ok9c: bool = not u02_icon.visible
	_check("TEST9 buff_icons", ok9a and ok9b and ok9c,
		"初始隐藏=%s 显示=%s 文本='%s' 归零隐藏=%s" % [ok9a, ok9b,
		(u02_icon.get_node("Label") as Label).text, ok9c])

	# TEST10: 通关占位提示（§9，L02-P0-05）：默认隐藏，调用后居中显示
	var clear_label: Label = hud.get_node("ClearLabel")
	var ok10a: bool = not clear_label.visible
	hud.show_clear_banner("L02 通关")
	_check("TEST10 clear_banner", ok10a and clear_label.visible and clear_label.text == "L02 通关",
		"初始隐藏=%s 显示=%s 文本='%s'" % [ok10a, clear_label.visible, clear_label.text])

	if _fail:
		print("RESULT: FAILED")
		quit(1)
	else:
		print("RESULT: ALL PASS")
		quit(0)


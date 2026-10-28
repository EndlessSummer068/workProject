extends SceneTree
## L02-P0-07 大招 L「湮灭·终式」验收测试（BUILD_PLAN.md）：headless 运行。
## 运行：Godot_v4.7.2 --headless --path <项目> --script res://tests/test_ultimate.gd
## 覆盖：MP≥60 且冷却完按 L 释放（扣 60、120°/200px/5×伤害扇形、冷却 30s 信号）、
##       冷却中/MP 不足无效、HUD 右下 K/L 横排与 L 三态、冲击环 0.3s 消散、真实伤害结算。

var _fail := false
var _log: FileAccess = null

func _initialize() -> void:
	_log = FileAccess.open("res://tests/_ult_debug.log", FileAccess.WRITE)
	create_timer(30.0).timeout.connect(func() -> void:
		_lprint("TIMEOUT force quit")
		quit(2))
	_run.call_deferred()

func _lprint(msg: String) -> void:
	print(msg)
	if _log != null:
		_log.store_line(msg)
		_log.flush()

func _check(name: String, ok: bool, detail: String) -> void:
	_lprint("%s: %s (%s)" % [name, "PASS" if ok else "FAIL", detail])
	_fail = _fail or not ok

func _press_l() -> void:
	Input.action_press("ultimate")
	await physics_frame
	await physics_frame
	Input.action_release("ultimate")
	await physics_frame

func _run() -> void:
	_lprint("step: begin")
	var player: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	var hud: CanvasLayer = (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate()
	var e01: CharacterBody2D = (load("res://scenes/enemies/e01.tscn") as PackedScene).instantiate()
	player.global_position = Vector2(400, 300)
	e01.global_position = Vector2(500, 300)  # 玩家右侧 100px：在 120°/200px 扇形内
	root.add_child(player)
	root.add_child(hud)
	root.add_child(e01)
	await physics_frame
	await physics_frame
	_lprint("step: scene ready")
	hud.bind_player(player)

	var l_slot: ColorRect = hud.get_node("LSlot")
	var l_label: Label = hud.get_node("LSlot/LLabel")
	var ult_hint: Label = hud.get_node("UltHint")
	var k_slot: ColorRect = hud.get_node("KSlot")
	var ready_purple := Balance.ULTIMATE_COLOR  # L 就绪色 #9B59D0（§8，2026-10-29 用户指令：与 K 金黄区分）
	var cooldown_gray := Color("4a4a55")
	var uses_arr: Array[int] = []  # lambda 按值捕获标量不可增改，用数组（引用）计数
	player.ultimate_used.connect(func(_f: Vector2) -> void: uses_arr.append(1))
	var cooldowns: Array[float] = []
	player.ultimate_cooldown_changed.connect(func(r: float) -> void: cooldowns.append(r))

	# T1: 就绪态=「L」+高亮 #9B59D0 紫（§8，2026-10-29 用户指令：与 K 金黄区分）；K/L 右下横排（K 左 L 右、间距、右下安全区 8px）
	var ok1: bool = l_slot.color.is_equal_approx(ready_purple) and not l_slot.color.is_equal_approx(k_slot.color) and l_label.text == "L" and not ult_hint.visible \
		and k_slot.position.x < l_slot.position.x \
		and absf(k_slot.position.y - l_slot.position.y) < 0.5 \
		and l_slot.position.x + l_slot.size.x <= 1152.0 - 8.0 + 0.5 \
		and l_slot.position.y + l_slot.size.y <= 648.0 - 8.0 + 0.5
	_check("T1 l_ready_icon", ok1, "color=%s text='%s' K.x=%.0f<L.x=%.0f 右缘=%.0f 下缘=%.0f" % [l_slot.color, l_label.text, k_slot.position.x, l_slot.position.x, l_slot.position.x + l_slot.size.x, l_slot.position.y + l_slot.size.y])

	# T2: MP=100 按 L → 扣 60 剩 40、ultimate_used、冷却信号 ≈30、图标灰+「30」
	_lprint("step: T2 begin")
	var ring0 := _count_rings(player)
	await _press_l()
	var ok2: bool = player.mp == 40 and uses_arr.size() == 1 \
		and cooldowns.size() > 0 and absf(cooldowns[0] - 30.0) < 1.0 \
		and l_slot.color.is_equal_approx(cooldown_gray) and l_label.text == "30"
	_check("T2 cast_success", ok2, "MP=%d(期望40) uses=%d 冷却首信号=%.1f 图标=%s/'%s'" % [player.mp, uses_arr.size(), cooldowns[0] if cooldowns.size() > 0 else -1.0, l_slot.color, l_label.text])

	# T3: 扇形实体伤害=5×攻击力=50 → E01(8HP) 被秒；冲击环生成
	var arc_dmg := player.ultimate_power()
	var ok3: bool = arc_dmg == 50 and not is_instance_valid(e01) and _count_rings(player) > ring0
	_check("T3 damage_and_ring", ok3, "ultimate_power=%d(期望50) E01 已死亡=%s 冲击环生成=%s" % [arc_dmg, not is_instance_valid(e01), _count_rings(player) > ring0])

	# T4: 冷却中再按 L 无效（MP 40 不变、uses 仍 1）；随后冷却复位（置 0 → 物理帧 emit 0.0）
	_lprint("step: T4 begin")
	await _press_l()
	var ok4: bool = player.mp == 40 and uses_arr.size() == 1
	_check("T4 cooldown_blocks", ok4, "MP=%d uses=%d（期望不变）" % [player.mp, uses_arr.size()])
	player._ultimate_timer = 0.0  # 保留 _ultimate_cooling=true：下一物理帧复位并 emit 0.0（T7 依赖）
	await physics_frame
	await physics_frame
	_lprint("step: cooldown reset, remaining signals=%s" % [cooldowns.has(0.0)])

	# T5: MP=40（<60）冷却已过按 L 无效 + 图标缺 MP 态（半透明+「缺 MP」）
	await _press_l()
	var ok5: bool = player.mp == 40 and uses_arr.size() == 1 \
		and l_slot.modulate.a < 0.9 and ult_hint.visible and ult_hint.text == "缺 MP"
	_check("T5 mp_shortage_blocks", ok5, "MP=%d uses=%d 透明度=%.1f hint可见=%s" % [player.mp, uses_arr.size(), l_slot.modulate.a, ult_hint.visible])

	# T6: MP 回到 ≥60 → 缺 MP 态解除回就绪（mp_changed 驱动刷新）
	player.gain_mp(20)  # 40+20=60 ≥60
	await physics_frame
	var ok6: bool = l_slot.modulate.a > 0.9 and not ult_hint.visible and l_label.text == "L"
	_check("T6 mp_recovered_ready", ok6, "MP=%d 透明度=%.1f hint可见=%s" % [player.mp, l_slot.modulate.a, ult_hint.visible])

	# T7: 冷却归零信号后 MP=60 仍可再释放（30s 冷却时长由 T2 信号值验证，不真等 30s）
	_lprint("step: T7 begin")
	var ok7a: bool = cooldowns.has(0.0) and l_slot.color.is_equal_approx(ready_purple) and l_label.text == "L"
	await _press_l()
	var ok7b: bool = player.mp == 0 and uses_arr.size() == 2
	_check("T7 cooldown_reset_recast", ok7a and ok7b, "冷却归零信号=%s 图标就绪=%s；MP=%d(期望60-60=0) uses=%d" % [cooldowns.has(0.0), ok7a, player.mp, uses_arr.size()])

	# T8: 冲击环 0.3s 消散自毁（T7 释放时生成的环）
	_lprint("step: T8 begin")
	var ring_before := _count_rings(player)
	for i in 25:  # 25帧≈0.42s > 0.3s
		await physics_frame
	var ok8: bool = ring_before > 0 and _count_rings(player) == 0
	_check("T8 ring_dissipates", ok8, "释放后环=%d → 0.42s后环=%d（期望 0，0.3s 消散）" % [ring_before, _count_rings(player)])

	# T9: 大招特效色与 K 分离（§4.3 用户指令 2026-10-28：紫 #9B59D0 vs K 金黄 #F2D57E）
	var arc_scene := load("res://scenes/bullets/ultimate_arc.tscn") as PackedScene
	var ring_scene := load("res://scenes/bullets/ultimate_ring.tscn") as PackedScene
	var arc_visual: Polygon2D = (arc_scene.instantiate() as Node2D).get_node("Visual")
	var ring_line: Line2D = (ring_scene.instantiate() as Node2D).get_node("Ring")
	var ok9: bool = not Balance.ULTIMATE_COLOR.is_equal_approx(Balance.SKILL_K_COLOR) \
		and arc_visual.color.is_equal_approx(Color(Balance.ULTIMATE_COLOR, 0.6)) \
		and ring_line.default_color.is_equal_approx(Balance.ULTIMATE_COLOR)
	_check("T9 ultimate_color_distinct", ok9, "ULTIMATE_COLOR=%s K_COLOR=%s arc=%s ring=%s" % [Balance.ULTIMATE_COLOR, Balance.SKILL_K_COLOR, arc_visual.color, ring_line.default_color])

	if _fail:
		print("RESULT: FAILED")
		quit(1)
	else:
		print("RESULT: ALL PASS")
		quit(0)

func _count_rings(player: Player) -> int:
	var n := 0
	var parent := player.get_parent()
	if parent == null:
		return 0
	for child in parent.get_children():
		if child.scene_file_path == "res://scenes/bullets/ultimate_ring.tscn":
			n += 1
	return n

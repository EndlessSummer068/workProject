extends SceneTree
## L01-P2-01 技能 K「湮灭」验收测试（BUILD_PLAN.md）：headless 运行。
## 运行：Godot_v4.7.2 --headless --path <项目> --script res://tests/test_skill.gd

var _fail := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var arena: Node = (load("res://scenes/levels/test_arena.tscn") as PackedScene).instantiate()
	root.add_child(arena)
	await physics_frame
	await physics_frame
	var player := arena.get_node("Player") as Player
	var d4 := arena.get_node("Dummy4")   # 弧内：右侧 44px < 100px（§4.3 半径），夹角 0° < 45°
	var d5 := arena.get_node("Dummy5")   # 弧外同距：正上方 44px，夹角 90° > 45°（§4.3 扇形 90°）
	var d2 := arena.get_node("Dummy2")   # 远距：128px > 100px
	var hp4: Array[int] = []
	var hp5: Array[int] = []
	d4.hp_changed.connect(func(cur: int, _m: int) -> void: hp4.append(cur))
	d5.hp_changed.connect(func(cur: int, _m: int) -> void: hp5.append(cur))
	var used_count := [0]
	var cooldown_values: Array[float] = []
	player.skill_used.connect(func(_f: Vector2) -> void: used_count[0] += 1)
	player.skill_cooldown_changed.connect(func(r: float) -> void: cooldown_values.append(r))
	var arc_script: Script = load("res://scripts/bullets/skill_arc.gd")

	# TEST0: 审计——碰撞掩码相配 + 弧参数（§4.3 90°/100px）+ 特效色（§7.2 #F2D57E）
	var arc_ref: Area2D = (load("res://scenes/bullets/skill_arc.tscn") as PackedScene).instantiate()
	print("AUDIT skill_arc layer=0x%x mask=0x%x dummy4 layer=0x%x" % [arc_ref.collision_layer, arc_ref.collision_mask, d4.collision_layer])
	_check("TEST0a mask_audit", (arc_ref.collision_mask & d4.collision_layer) != 0,
		"arc.mask=0x%x & dummy.layer=0x%x 须≠0" % [arc_ref.collision_mask, d4.collision_layer])
	var cmap: Dictionary = arc_script.get_script_constant_map()
	_check("TEST0b arc_params",
		is_equal_approx(cmap["ARC_RADIUS"], 100.0) and is_equal_approx(cmap["ARC_DEG"], 90.0),
		"radius=%s deg=%s (期望 100/90，§4.3)" % [cmap["ARC_RADIUS"], cmap["ARC_DEG"]])
	var vis: Polygon2D = arc_ref.get_node("Visual")
	var expect := Color("f2d57e")
	_check("TEST0c skill_color",
		is_equal_approx(vis.color.r, expect.r) and is_equal_approx(vis.color.g, expect.g) and is_equal_approx(vis.color.b, expect.b),
		"visual=%s (期望 #F2D57E，§7.2)" % vis.color)
	arc_ref.free()

	# TEST1: 按 K → 锁定朝向（右）立即释放：弧内 Dummy4 受 3×攻击力=30（Lv1 ATK 10）击杀；弧外同距/远距不受击
	Input.action_press("skill")
	await physics_frame
	await physics_frame
	Input.action_release("skill")
	for i in 4:
		await physics_frame
	var freed4 := (not is_instance_valid(d4)) or d4.is_queued_for_deletion()
	var ok1: bool = used_count[0] == 1 and player.skill_power() == 30 and hp4.size() == 1 and hp4[0] == 0 and freed4 and hp5.is_empty()
	_check("TEST1 cast_hit", ok1, "used=%d skill_power=%d hp4=%s freed4=%s hp5=%s (期望 used=1 power=30 hp4=[0] hp5=[])" % [used_count[0], player.skill_power(), hp4, freed4, hp5])

	# TEST2: 冷却中（§4.3 10s）再按 → 无效（不再释放）
	used_count[0] = 0
	Input.action_press("skill")
	await physics_frame
	await physics_frame
	Input.action_release("skill")
	for i in 4:
		await physics_frame
	_check("TEST2 cooldown_block", used_count[0] == 0, "used=%d (期望 0)" % used_count[0])

	# TEST3: 冷却结束（等待 >10s）→ 再按生效；弧内新假人 d6（右侧 80px）受击死亡
	var d6 := StaticBody2D.new()
	d6.name = "SkillDummy"
	d6.collision_layer = 4
	d6.set_script(load("res://scripts/levels/test_dummy.gd"))
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 16)
	shape.shape = rect
	d6.add_child(shape)
	arena.add_child(d6)
	d6.global_position = Vector2(720, 360)  # 玩家右侧 80px：弧内（<100px，0°）
	await physics_frame
	var hp6: Array[int] = []
	d6.hp_changed.connect(func(cur: int, _m: int) -> void: hp6.append(cur))
	for i in 620:  # >10s：冷却归零（末次 cooldown 信号=0.0）
		await physics_frame
	# 在 TEST3 再次释放前捕获冷却信号链（避免读到新一轮冷却值）
	var cd_first: float = cooldown_values[0] if not cooldown_values.is_empty() else -1.0
	var cd_last: float = cooldown_values[cooldown_values.size() - 1] if not cooldown_values.is_empty() else -1.0
	var cd_count := cooldown_values.size()
	used_count[0] = 0
	Input.action_press("skill")
	await physics_frame
	await physics_frame
	Input.action_release("skill")
	for i in 4:
		await physics_frame
	var freed6 := (not is_instance_valid(d6)) or d6.is_queued_for_deletion()
	var ok3: bool = used_count[0] == 1 and freed6 and hp6.size() == 1 and hp6[0] == 0
	_check("TEST3 ready_again", ok3, "used=%d freed6=%s hp6=%s (期望 used=1 freed6=true hp6=[0])" % [used_count[0], freed6, hp6])

	# TEST4: 冷却信号链：首次释放=10.0、结束=0.0（HUD 图标据此驱动，§8）
	var ok4: bool = cd_first == 10.0 and cd_last == 0.0 and cd_count > 600
	_check("TEST4 cooldown_signal", ok4, "first=%s last=%s count=%d (期望 10.0/0.0/>600)" % [cd_first, cd_last, cd_count])

	# TEST5: 弧外同距 Dummy5 与远距 Dummy2 全程不受击
	_check("TEST5 out_of_arc", hp5.is_empty() and is_instance_valid(d5) and d5.hp == 20, "hp5=%s d5.hp=%s" % [hp5, d5.hp])
	_check("TEST6 far_no_hit", is_instance_valid(d2) and d2.hp == 20, "d2.hp=%s" % d2.hp)

	if _fail:
		print("RESULT: FAILED")
		quit(1)
	else:
		print("RESULT: ALL PASS")
		quit(0)

func _check(name: String, ok: bool, detail: String) -> void:
	print("%s: %s (%s)" % [name, "PASS" if ok else "FAIL", detail])
	_fail = _fail or not ok
